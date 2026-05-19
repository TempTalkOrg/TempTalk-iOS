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
}

// MARK: - Implementation

@objc
public final class DTGroupCryptoManager: NSObject, GroupCryptoManaging {

    private static let currentCryptoMode = 1

    @objc public static let shared = DTGroupCryptoManager(
        cryptoService: DTGroupCryptoServiceImpl(),
        keyStore: DTGroupCryptoKeyStoreImpl()
    )

    private let cryptoService: GroupCryptoService
    private let keyStore: GroupCryptoKeyStore

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
            Logger.info("[GroupCrypto] decryptedGroupName skip: empty encryptedName, gid: \(gid)")
            return nil
        }
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else { return nil }
        let result = cryptoService.decryptGroupName(kGroup: keys.kGroup, encryptedName: encryptedName)
        if result == nil {
            Logger.error("[GroupCrypto] Failed to decrypt group name for gid: \(gid)")
        }
        return result
    }

    @objc
    public func decryptedGroupAvatar(gid: String,
                                     encryptedAvatar: String?,
                                     transaction: SDSAnyReadTransaction) -> String? {
        guard let encryptedAvatar, !encryptedAvatar.isEmpty else {
            Logger.info("[GroupCrypto] decryptedGroupAvatar skip: empty ciphertext, gid: \(gid)")
            return nil
        }
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else {
            Logger.error("[GroupCrypto] decryptedGroupAvatar failed: no R_group or derive failed, gid: \(gid)")
            return nil
        }
        let result = cryptoService.decryptGroupAvatar(kGroup: keys.kGroup, encryptedAvatar: encryptedAvatar)
        if let result {
            Logger.info("[GroupCrypto] decryptedGroupAvatar ok, gid: \(gid), plaintextLen: \(result.count)")
        } else {
            Logger.error("[GroupCrypto] decryptedGroupAvatar failed: AES decrypt returned nil, gid: \(gid), cipherLen: \(encryptedAvatar.count)")
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
        let saved = keyStore.saveRGroupIfNeeded(gid: gid, rGroup: rGroupBase64, transaction: transaction)
        Logger.info("[GroupCrypto] saveRGroupIfNeeded gid: \(gid), saved: \(saved), rGroupLen: \(rGroup.count)")
        return saved
    }

    @objc
    public func getRGroupData(gid: String,
                              transaction: SDSAnyReadTransaction) -> Data? {
        guard let base64String = keyStore.fetchRGroup(forGid: gid, transaction: transaction) else {
            return nil
        }
        return Data(base64Encoded: base64String)
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

    // MARK: - Batch Member Verification

    @objc(verifyMembersForGid:members:transaction:)
    public func objc_verifyMembers(gid: String,
                                    members: [DTGroupMemberEntity],
                                    transaction: SDSAnyReadTransaction) {
        guard let keys = deriveKeysForGroup(gid: gid, transaction: transaction) else { return }
        var invalidUids: [String] = []
        for member in members {
            guard let uidSig = member.uidSignature, !uidSig.isEmpty else { continue }
            let valid = cryptoService.verifyUid(pkBind: keys.pkBind, uid: member.uid, uidSignature: uidSig)
            if !valid {
                Logger.error("[GroupCrypto] Batch verification failed for uid: \(member.uid) in gid: \(gid)")
                invalidUids.append(member.uid)
            }
        }
        guard !invalidUids.isEmpty else { return }
        Task {
            do {
                try await DTGroupCryptoAPIImpl().cryptoDispose(
                    groupId: gid,
                    request: CryptoDisposeRequest(members: invalidUids)
                )
            } catch {
                Logger.error("[GroupCrypto] cryptoDispose failed for gid: \(gid), members: \(invalidUids), error: \(error)")
            }
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

        Logger.info("[GroupCrypto] buildCreationParams ok, rGroupLen: \(rGroup.count), encryptedNameLen: \(encryptedName.count), encryptedAvatarLen: \(encryptedAvatar?.count ?? 0), memberCount: \(bindings.count)")
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
