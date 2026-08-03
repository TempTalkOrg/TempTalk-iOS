//
//  GroupCryptoManager.swift
//  TTServiceKit
//

import Foundation

// MARK: - Creation Params

public struct EncryptedGroupCreationParams {
    public let rGroup: Data
    public let groupCryptoMode: Int
    public let encryptedName: String
    public let encryptedAvatar: String?
    public let groupMemberVerifyPublicKey: String
    public let memberBindings: [GroupMemberBinding]

    public init(rGroup: Data,
                groupCryptoMode: Int,
                encryptedName: String,
                encryptedAvatar: String?,
                groupMemberVerifyPublicKey: String,
                memberBindings: [GroupMemberBinding]) {
        self.rGroup = rGroup
        self.groupCryptoMode = groupCryptoMode
        self.encryptedName = encryptedName
        self.encryptedAvatar = encryptedAvatar
        self.groupMemberVerifyPublicKey = groupMemberVerifyPublicKey
        self.memberBindings = memberBindings
    }

    public func toUpgradeRequest() -> UpgradeGroupCryptoRequest {
        UpgradeGroupCryptoRequest(
            groupCryptoMode: groupCryptoMode,
            encryptedName: encryptedName,
            encryptedAvatar: encryptedAvatar,
            groupMemberVerifyPublicKey: groupMemberVerifyPublicKey,
            memberBindings: memberBindings.map { $0.asDictionary }
        )
    }
}

// MARK: - ObjC Bridge

@objc
public class DTEncryptedGroupCreationParams: NSObject {
    @objc public let rGroup: Data
    @objc public let groupCryptoMode: Int
    @objc public let encryptedName: String
    @objc public let encryptedAvatar: String?
    @objc public let groupMemberVerifyPublicKey: String
    @objc public let memberBindingDicts: [[String: String]]

    init(_ params: EncryptedGroupCreationParams) {
        self.rGroup = params.rGroup
        self.groupCryptoMode = params.groupCryptoMode
        self.encryptedName = params.encryptedName
        self.encryptedAvatar = params.encryptedAvatar
        self.groupMemberVerifyPublicKey = params.groupMemberVerifyPublicKey
        self.memberBindingDicts = params.memberBindings.map { $0.asDictionary }
    }
}

// MARK: - Protocol

public protocol GroupCryptoManaging {
    func isEncryptedGroup(groupCryptoMode: Int) -> Bool
    func hasRGroup(gid: String, transaction: SDSAnyReadTransaction) -> Bool
    func decryptedGroupName(gid: String,
                            encryptedName: String?,
                            transaction: SDSAnyReadTransaction) -> String?
    func decryptedGroupName(rGroup: Data, encryptedName: String) -> String?
    func decryptedGroupAvatar(gid: String,
                              encryptedAvatar: String?,
                              transaction: SDSAnyReadTransaction) -> String?
    func prepareEncryptedGroupCreation(groupName: String,
                                       avatar: String?,
                                       memberUids: [String]) -> EncryptedGroupCreationParams?
    func prepareMemberBindings(gid: String,
                               newMemberUids: [String],
                               transaction: SDSAnyReadTransaction) -> [GroupMemberBinding]?
    func encryptGroupName(gid: String,
                          plainName: String,
                          transaction: SDSAnyReadTransaction) -> String?
    func encryptGroupAvatar(gid: String,
                            plainAvatar: String,
                            transaction: SDSAnyReadTransaction) -> String?
    @discardableResult
    func saveRGroupIfNeeded(gid: String,
                            rGroup: Data,
                            transaction: SDSAnyWriteTransaction) -> Bool
    func getRGroupData(gid: String,
                       transaction: SDSAnyReadTransaction) -> Data?
    func verifyMember(gid: String,
                      uid: String,
                      uidSignature: String,
                      transaction: SDSAnyReadTransaction) -> Bool?
    func prepareUpgradeToEncrypted(gid: String,
                                   groupName: String,
                                   avatar: String?,
                                   memberUids: [String],
                                   transaction: SDSAnyReadTransaction) -> EncryptedGroupCreationParams?
    @discardableResult
    func deleteRGroup(gid: String, transaction: SDSAnyWriteTransaction) -> Bool
    func verifyMembersClassified(gid: String,
                                 members: [DTGroupMemberEntity],
                                 transaction: SDSAnyReadTransaction) -> (passed: [String], failed: [String])
    func runFullSyncVerification(gid: String, members: [DTGroupMemberEntity]) async
}

// MARK: - Throttle Store

/// gid -> last-fired Date. Within `window` seconds, repeat triggers are skipped.
/// Process restart resets state; LRU caps memory growth.
final class ThrottleStore {
    private let window: TimeInterval
    private let now: () -> Date
    private let queue = DispatchQueue(label: "com.chative.DTGroupCrypto.throttle")
    private var state: [String: Date] = [:]
    private static let lruCap = 64

    init(window: TimeInterval, now: @escaping () -> Date = Date.init) {
        self.window = window
        self.now = now
    }

    func tryAcquire(gid: String) -> Bool {
        return queue.sync {
            let current = self.now()
            if let last = state[gid], current.timeIntervalSince(last) < window {
                return false
            }
            state[gid] = current
            while state.count > Self.lruCap {
                guard let oldest = state.min(by: { $0.value < $1.value }) else { break }
                state.removeValue(forKey: oldest.key)
            }
            return true
        }
    }

    func reset() {
        queue.sync { state.removeAll() }
    }
}

// MARK: - Implementation

@objc
public final class DTGroupCryptoManager: NSObject, GroupCryptoManaging {

    private static let currentCryptoMode = 1

    @objc public static let shared = DTGroupCryptoManager(
        cryptoService: DTGroupCryptoServiceImpl(),
        keyStore: DTGroupCryptoKeyStoreImpl()
    )

    /// Test-replaceable global seam. Production reads via this; tests can swap in setUp.
    public static var sharedManager: GroupCryptoManaging = DTGroupCryptoManager.shared

    private let cryptoService: GroupCryptoService
    private let keyStore: GroupCryptoKeyStore
    private let throttle = ThrottleStore(window: 5.0)

    public init(cryptoService: GroupCryptoService, keyStore: GroupCryptoKeyStore) {
        self.cryptoService = cryptoService
        self.keyStore = keyStore
    }

    // MARK: - Query

    @objc
    public func isEncryptedGroup(groupCryptoMode: Int) -> Bool {
        groupCryptoMode > 0
    }

    @objc
    public func hasRGroup(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        keyStore.fetchRGroup(forGid: gid, transaction: transaction) != nil
    }

    // MARK: - Decrypt Display Fields

    @objc
    public func decryptedGroupName(gid: String,
                                   encryptedName: String?,
                                   transaction: SDSAnyReadTransaction) -> String? {
        guard let encryptedName, !encryptedName.isEmpty else {
            return nil
        }
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else { return nil }
        let result = cryptoService.decryptGroupName(kGroup: keys.kGroup, encryptedName: encryptedName)
        if result == nil {
            Logger.error("[GroupCrypto] decryptedGroupName failed, gid: \(gid)")
        }
        return result
    }

    // Decrypt with a caller-supplied rGroup (no DB lookup). Used by NSE first-push path.
    @objc
    public func decryptedGroupName(rGroup: Data, encryptedName: String) -> String? {
        guard !encryptedName.isEmpty else { return nil }
        guard let keys = cryptoService.deriveKeys(rGroup: rGroup) else {
            Logger.error("[GroupCrypto] decryptedGroupName(rGroup:) deriveKeys nil")
            return nil
        }
        return cryptoService.decryptGroupName(kGroup: keys.kGroup, encryptedName: encryptedName)
    }

    /// 解析群显示名。加密群优先解密 → 失败保留本地旧名 → 兜底 serverName。
    @objc
    public func resolveGroupName(gid: String,
                                 cryptoMode: Int,
                                 encryptedName: String?,
                                 oldName: String?,
                                 serverName: String,
                                 transaction: SDSAnyReadTransaction) -> String {
        guard cryptoMode > 0 else { return serverName }

        if let encryptedName, !encryptedName.isEmpty,
           let decrypted = decryptedGroupName(gid: gid, encryptedName: encryptedName, transaction: transaction),
           !decrypted.isEmpty {
            Logger.info("[GroupCrypto] resolveName gid=...\(gid.suffix(6)) source=decrypted")
            return decrypted
        }
        if let oldName, !oldName.isEmpty {
            Logger.info("[GroupCrypto] resolveName gid=...\(gid.suffix(6)) source=keepOld")
            return oldName
        }
        Logger.info("[GroupCrypto] resolveName gid=...\(gid.suffix(6)) source=serverFallback")
        return serverName
    }

    @objc
    public func decryptedGroupAvatar(gid: String,
                                     encryptedAvatar: String?,
                                     transaction: SDSAnyReadTransaction) -> String? {
        guard let encryptedAvatar, !encryptedAvatar.isEmpty else {
            return nil
        }
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] decryptedGroupAvatar failed: no R_group, gid: \(gid)")
            return nil
        }
        let result = cryptoService.decryptGroupAvatar(kGroup: keys.kGroup, encryptedAvatar: encryptedAvatar)
        if result == nil {
            Logger.error("[GroupCrypto] decryptedGroupAvatar failed, gid: \(gid)")
        }
        return result
    }

    // MARK: - Create Encrypted Group

    public func prepareEncryptedGroupCreation(groupName: String,
                                              avatar: String?,
                                              memberUids: [String]) -> EncryptedGroupCreationParams? {
        let rGroup = cryptoService.generateRGroup()
        return buildCreationParams(rGroup: rGroup, groupName: groupName, avatar: avatar, memberUids: memberUids)
    }

    @objc(prepareEncryptedGroupCreationObjCWithGroupName:avatar:memberUids:)
    public func objc_prepareEncryptedGroupCreation(groupName: String,
                                                    avatar: String?,
                                                    memberUids: [String]) -> DTEncryptedGroupCreationParams? {
        guard let params = prepareEncryptedGroupCreation(groupName: groupName, avatar: avatar, memberUids: memberUids) else {
            return nil
        }
        return DTEncryptedGroupCreationParams(params)
    }

    // MARK: - Add Members

    public func prepareMemberBindings(gid: String,
                                      newMemberUids: [String],
                                      transaction: SDSAnyReadTransaction) -> [GroupMemberBinding]? {
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] No R_group found when preparing member bindings for gid: \(gid)")
            return nil
        }
        guard let bindings = cryptoService.signMembers(skBind: keys.skBind, uids: newMemberUids) else {
            Logger.error("[GroupCrypto] Failed to sign new members for gid: \(gid)")
            return nil
        }
        return bindings
    }

    @objc(prepareMemberBindingDictsForGid:newMemberUids:transaction:)
    public func objc_prepareMemberBindingDicts(gid: String,
                                                newMemberUids: [String],
                                                transaction: SDSAnyReadTransaction) -> [[String: String]]? {
        guard let bindings = prepareMemberBindings(gid: gid, newMemberUids: newMemberUids, transaction: transaction) else {
            return nil
        }
        return bindings.map { $0.asDictionary }
    }

    // MARK: - Encrypt Group Fields

    @objc
    public func encryptGroupName(gid: String,
                                 plainName: String,
                                 transaction: SDSAnyReadTransaction) -> String? {
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] No R_group found when encrypting group name for gid: \(gid)")
            return nil
        }
        return cryptoService.encryptGroupName(kGroup: keys.kGroup, plainName: plainName)
    }

    @objc
    public func encryptGroupAvatar(gid: String,
                                   plainAvatar: String,
                                   transaction: SDSAnyReadTransaction) -> String? {
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] No R_group found when encrypting group avatar for gid: \(gid)")
            return nil
        }
        return cryptoService.encryptGroupAvatar(kGroup: keys.kGroup, plainAvatar: plainAvatar)
    }

    // MARK: - Key Distribution

    @discardableResult
    @objc
    public func saveRGroupIfNeeded(gid: String,
                                   rGroup: Data,
                                   transaction: SDSAnyWriteTransaction) -> Bool {
        let rGroupBase64 = rGroup.base64EncodedString()
        return keyStore.saveRGroupIfNeeded(gid: gid, rGroup: rGroupBase64, transaction: transaction)
    }

    @objc
    public func currentKeyVersion(gid: String,
                                  transaction: SDSAnyReadTransaction) -> Int {
        keyStore.fetchKeyVersion(forGid: gid, transaction: transaction)
    }

    /// Version-aware write funnel for both receive paths and the rotate initiator.
    /// On a higher-version key the group's verified members are cleared so the new pk_bind is re-verified.
    @discardableResult
    @objc
    public func saveOrRotateRGroup(gid: String,
                                   rGroup: Data,
                                   version: Int,
                                   transaction: SDSAnyWriteTransaction) -> DTGroupKeyRotateOutcome {
        let outcome = keyStore.saveOrRotateRGroup(gid: gid,
                                                  rGroup: rGroup.base64EncodedString(),
                                                  version: version,
                                                  transaction: transaction)
        // Reset on any non-skipped outcome: an `.inserted` key (record was lost while the thread
        // persisted) can land alongside stale verifiedMemberUids that were verified against the old
        // pk_bind — those must be cleared too, not only on `.rotated`.
        if outcome != .skipped {
            Self.resetVerifiedMembers(gid: gid, transaction: transaction)
        }
        return outcome
    }

    /// Clear per-member signature-verify state so members re-verify under the new pk_bind.
    private static func resetVerifiedMembers(gid: String, transaction: SDSAnyWriteTransaction) {
        guard let localId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
              !localId.isEmpty,
              let thread = TSGroupThread.getWithGroupId(localId, transaction: transaction) else {
            return
        }
        thread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel.verifiedMemberUids = Set<String>()
        }
    }

    @objc
    public func getRGroupData(gid: String,
                              transaction: SDSAnyReadTransaction) -> Data? {
        guard let base64String = keyStore.fetchRGroup(forGid: gid, transaction: transaction) else {
            return nil
        }
        return Data(base64Encoded: base64String)
    }

    @objc
    @discardableResult
    public func deleteRGroup(gid: String, transaction: SDSAnyWriteTransaction) -> Bool {
        let existed = keyStore.fetchRGroup(forGid: gid, transaction: transaction) != nil
        keyStore.deleteRGroup(forGid: gid, transaction: transaction)
        DTGroupCryptoDisplayHelper.shared.clearAvatarFingerprint(gid: gid)
        Logger.info("[GroupCrypto] deleteRGroup gid=...\(gid.suffix(6)), existed: \(existed)")
        return existed
    }

    // MARK: - Member Verification

    public func verifyMember(gid: String,
                             uid: String,
                             uidSignature: String,
                             transaction: SDSAnyReadTransaction) -> Bool? {
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            return nil
        }
        return cryptoService.verifyUid(pkBind: keys.pkBind, uid: uid, uidSignature: uidSignature)
    }

    // MARK: - Batch Member Verification (Pure Classifier)

    /// Pure classifier: read-only transaction, no network, no DB write.
    /// Callers own throttling, verifiedMemberUids filtering, persistence, and dispose reporting.
    public func verifyMembersClassified(gid: String,
                                        members: [DTGroupMemberEntity],
                                        transaction: SDSAnyReadTransaction)
        -> (passed: [String], failed: [String])
    {
        guard !members.isEmpty else { return ([], []) }
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] verify skip: no rGroup")
            return ([], [])
        }
        var passed: [String] = []
        var failed: [String] = []
        passed.reserveCapacity(members.count)
        for member in members {
            guard let uidSig = member.uidSignature, !uidSig.isEmpty else {
                failed.append(member.uid)
                continue
            }
            if cryptoService.verifyUid(pkBind: keys.pkBind, uid: member.uid, uidSignature: uidSig) {
                passed.append(member.uid)
            } else {
                failed.append(member.uid)
            }
        }
        Logger.info("[GroupCrypto] verify done total=\(members.count) passed=\(passed.count) failed=\(failed.count)")
        return (passed, failed)
    }

    // MARK: - Full Sync Verification (Trigger A)

    /// Trigger A entry: throttle → encrypted-group short-circuit → filter verified → classify → persist passed → dispose failed.
    public func runFullSyncVerification(gid serverGid: String, members: [DTGroupMemberEntity]) async {
        guard !serverGid.isEmpty, !members.isEmpty else { return }
        guard throttle.tryAcquire(gid: serverGid) else { return }
        let readResult: (localId: Data, passed: [String], failed: [String])? = await withCheckedContinuation { continuation in
            self.databaseStorage.asyncRead { readTx in
                guard let localId = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGid),
                      !localId.isEmpty,
                      let thread = TSGroupThread.getWithGroupId(localId, transaction: readTx),
                      thread.groupModel.isEncryptedGroup else {
                    continuation.resume(returning: nil)
                    return
                }
                let alreadyVerified = thread.groupModel.verifiedMemberUids ?? []
                let candidates = members.filter { !alreadyVerified.contains($0.uid) }
                guard !candidates.isEmpty else {
                    continuation.resume(returning: (localId, [], []))
                    return
                }
                let (passed, failed) = self.verifyMembersClassified(gid: serverGid,
                                                                     members: candidates,
                                                                     transaction: readTx)
                continuation.resume(returning: (localId, passed, failed))
            }
        }
        guard let (localId, passed, failed) = readResult else { return }
        if !passed.isEmpty {
            self.databaseStorage.asyncWrite { writeTx in
                guard let thread = TSGroupThread.getWithGroupId(localId, transaction: writeTx) else { return }
                thread.anyUpdateGroupThread(transaction: writeTx) { instance in
                    var merged = instance.groupModel.verifiedMemberUids ?? Set<String>()
                    merged.formUnion(passed)
                    let memberSet = Set(instance.groupModel.groupMemberIds)
                    instance.groupModel.verifiedMemberUids = merged.intersection(memberSet)
                }
            }
        }
        if !failed.isEmpty {
            do {
                let response = try await DTGroupCryptoAPIImpl().cryptoDispose(
                    groupId: serverGid,
                    request: CryptoDisposeRequest(members: failed)
                )
                Logger.info("[GroupCrypto] dispose ok gid=...\(serverGid.suffix(6)) removed=\(response.removed.count) rejected=\(response.rejected.count)")
                if !response.removed.isEmpty {
                    Self.removeMembers(response.removed, fromGroupWithServerGid: serverGid)
                }
            } catch {
                Logger.error("[GroupCrypto] dispose failed gid=...\(serverGid.suffix(6)) error=\(error)")
            }
        }
    }

    /// ObjC bridge for Trigger A. Detaches into Task so callers (ObjC writer queues) don't block.
    @objc(runFullSyncVerificationForGid:members:)
    public func objc_runFullSyncVerification(gid: String, members: [DTGroupMemberEntity]) {
        Task.detached { [weak self] in
            await self?.runFullSyncVerification(gid: gid, members: members)
        }
    }

    // MARK: - Remove Disposed Members

    static func removeMembers(_ uids: [String], fromGroupWithServerGid serverGid: String) {
        guard !uids.isEmpty else { return }
        Self.databaseStorage.asyncWrite { writeTx in
            guard let localId = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGid),
                  !localId.isEmpty,
                  let thread = TSGroupThread.getWithGroupId(localId, transaction: writeTx) else { return }
            let removeSet = Set(uids)
            thread.anyUpdateGroupThread(transaction: writeTx) { instance in
                instance.groupModel.groupMemberIds = instance.groupModel.groupMemberIds.filter { !removeSet.contains($0) }
                instance.groupModel.groupAdmin = instance.groupModel.groupAdmin.filter { !removeSet.contains($0) }
                instance.groupModel.intersectVerifiedMembersWithCurrentGroupMembers()
            }
            Logger.info("[GroupCrypto] removedMembers count=\(uids.count) gid=...\(serverGid.suffix(6))")
        }
    }

    // MARK: - Upgrade Existing Group

    public func prepareUpgradeToEncrypted(gid: String,
                                          groupName: String,
                                          avatar: String?,
                                          memberUids: [String],
                                          transaction: SDSAnyReadTransaction) -> EncryptedGroupCreationParams? {
        let rGroup: Data
        if let existingData = getRGroupData(gid: gid, transaction: transaction) {
            rGroup = existingData
            Logger.info("[GroupCrypto] prepareUpgradeToEncrypted reuse existing R_group, gid: \(gid)")
        } else {
            rGroup = cryptoService.generateRGroup()
            Logger.info("[GroupCrypto] prepareUpgradeToEncrypted generated new R_group, gid: \(gid)")
        }
        return buildCreationParams(rGroup: rGroup, groupName: groupName, avatar: avatar, memberUids: memberUids)
    }

    // MARK: - Rotate Existing Encrypted Group

    /// Always generates a brand-new R_group (never reuses the old key) and re-signs all members
    /// under the new pk_bind. Mirrors `buildCreationParams`, which never reads the old key.
    public func prepareRotateCrypto(gid: String,
                                    groupName: String,
                                    avatar: String?,
                                    memberUids: [String],
                                    transaction: SDSAnyReadTransaction) -> EncryptedGroupCreationParams? {
        let rGroup = cryptoService.generateRGroup()
        Logger.info("[GroupCrypto] prepareRotateCrypto generated new R_group, gid: \(gid)")
        return buildCreationParams(rGroup: rGroup, groupName: groupName, avatar: avatar, memberUids: memberUids)
    }

    // MARK: - Private Helpers

    private func deriveKeysForGroup(gid: String, transaction: SDSAnyReadTransaction) -> GroupKeySet? {
        guard let rGroupData = getRGroupData(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] deriveKeysForGroup failed: no R_group, gid: \(gid)")
            return nil
        }
        guard let keys = cryptoService.deriveKeys(rGroup: rGroupData) else {
            Logger.error("[GroupCrypto] deriveKeysForGroup failed: deriveKeys returned nil, gid: \(gid), rGroupLen: \(rGroupData.count)")
            return nil
        }
        return keys
    }

    private func buildCreationParams(rGroup: Data,
                                     groupName: String,
                                     avatar: String?,
                                     memberUids: [String]) -> EncryptedGroupCreationParams? {
        guard let keys = cryptoService.deriveKeys(rGroup: rGroup) else {
            Logger.error("[GroupCrypto] Failed to derive keys from rGroup during creation")
            return nil
        }

        guard let encryptedName = cryptoService.encryptGroupName(kGroup: keys.kGroup, plainName: groupName) else {
            Logger.error("[GroupCrypto] Failed to encrypt group name during creation")
            return nil
        }

        var encryptedAvatar: String?
        if let avatar, !avatar.isEmpty {
            encryptedAvatar = cryptoService.encryptGroupAvatar(kGroup: keys.kGroup, plainAvatar: avatar)
            if encryptedAvatar == nil {
                Logger.error("[GroupCrypto] Failed to encrypt group avatar during creation")
                return nil
            }
        }
        guard let bindings = cryptoService.signMembers(skBind: keys.skBind, uids: memberUids) else {
            Logger.error("[GroupCrypto] Failed to sign members during creation")
            return nil
        }

        Logger.info("[GroupCrypto] buildCreationParams ok, memberCount: \(bindings.count)")
        return EncryptedGroupCreationParams(
            rGroup: rGroup,
            groupCryptoMode: Self.currentCryptoMode,
            encryptedName: encryptedName,
            encryptedAvatar: encryptedAvatar,
            groupMemberVerifyPublicKey: keys.pkBindSPKI,
            memberBindings: bindings
        )
    }
}

