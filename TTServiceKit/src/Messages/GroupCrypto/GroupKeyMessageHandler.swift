//
//  DTGroupKeyMessageHandler.swift
//  TTServiceKit
//

import Foundation

@objc public final class DTGroupKeyMessageHandler: NSObject {

    private let keyStore: GroupCryptoKeyStore

    public init(keyStore: GroupCryptoKeyStore) {
        self.keyStore = keyStore
        super.init()
    }

    @objc public static let shared = DTGroupKeyMessageHandler(keyStore: DTGroupCryptoKeyStoreImpl())

    // MARK: - Dedicated GroupKeyMessage

    @objc public func handleGroupKeyMessage(_ groupKeyMessage: DSKProtoGroupKeyMessage,
                                            transaction: SDSAnyWriteTransaction) {
        guard let gidData = groupKeyMessage.groupID, !gidData.isEmpty else {
            Logger.error("[GroupCrypto] GroupKeyMessage missing groupID")
            return
        }
        guard let rGroupData = groupKeyMessage.groupRootKey, !rGroupData.isEmpty else {
            Logger.error("[GroupCrypto] GroupKeyMessage missing groupRootKey")
            return
        }

        guard let gid = String(data: gidData, encoding: .utf8) else {
            Logger.error("[GroupCrypto] GroupKeyMessage groupID is not valid UTF-8")
            return
        }
        // Missing keyVersion maps to 0 via the proto getter.
        let keyVersion = Int(groupKeyMessage.keyVersion)

        Logger.info("[GroupCrypto] GroupKeyMessage received, gid: \(gid), version: \(keyVersion)")
        let outcome = DTGroupCryptoManager.shared.saveOrRotateRGroup(gid: gid,
                                                                     rGroup: rGroupData,
                                                                     version: keyVersion,
                                                                     transaction: transaction)
        guard outcome != .skipped else { return }
        postKeyArrivalNotification(gid: gid, transaction: transaction, shouldFetchGroupInfo: true)
    }


    // MARK: - Fallback R_group from GroupContext

    @objc public func handleFallbackGroupRootKey(groupContext: DSKProtoGroupContext,
                                                 transaction: SDSAnyWriteTransaction) {
        handleFallbackGroupRootKey(groupContext: groupContext,
                                    skipGroupInfoFetch: false,
                                    transaction: transaction)
    }

    /// - Parameter skipGroupInfoFetch: 传 true 时跳过内部 `refreshGroupInfoOnRGroupArrival`，
    ///   用于调用方已自行处理群信息拉取、避免重复请求的场景。
    @objc public func handleFallbackGroupRootKey(groupContext: DSKProtoGroupContext,
                                                 skipGroupInfoFetch: Bool,
                                                 transaction: SDSAnyWriteTransaction) {
        guard groupContext.hasGroupRootKey,
              let rGroupData = groupContext.groupRootKey, !rGroupData.isEmpty else {
            return
        }
        guard let gidData = groupContext.id, !gidData.isEmpty else {
            return
        }
        guard let gid = String(data: gidData, encoding: .utf8) else {
            return
        }
        // Missing keyVersion maps to 0 via the proto getter.
        let keyVersion = Int(groupContext.keyVersion)
        let outcome = DTGroupCryptoManager.shared.saveOrRotateRGroup(gid: gid,
                                                                     rGroup: rGroupData,
                                                                     version: keyVersion,
                                                                     transaction: transaction)
        let changed = outcome != .skipped
        // changed 不可靠时也看本地能否解出群名，ThrottleStore 已按 gid 节流。
        let needsFetch = !skipGroupInfoFetch
            && (changed || Self.localGroupNameUnresolved(gid: gid, transaction: transaction))
        postKeyArrivalNotification(gid: gid, transaction: transaction, shouldFetchGroupInfo: needsFetch)
    }

    // MARK: - Attach R_group for Sending

    @objc public func attachRGroupToGroupContext(builder: DSKProtoGroupContext.DSKProtoGroupContextBuilder,
                                                 gid: String,
                                                 transaction: SDSAnyReadTransaction) {
        guard let rGroupBase64 = keyStore.fetchRGroup(forGid: gid, transaction: transaction) else {
            return
        }
        guard let rGroupData = Data(base64Encoded: rGroupBase64) else {
            Logger.error("[GroupCrypto] attachRGroupToGroupContext skip: base64 decode failed, gid: \(gid)")
            return
        }
        builder.setGroupRootKey(rGroupData)
        // Carry the local key version so receivers can drop stale keys (0 = baseline, omit).
        let version = keyStore.fetchKeyVersion(forGid: gid, transaction: transaction)
        if version > 0 {
            builder.setKeyVersion(UInt32(version))
        }
    }

    // MARK: - Send GroupKeyMessage

    @objc public func sendGroupKeyMessage(thread: TSThread,
                                           groupId: Data,
                                           rGroup: Data) {
        // Always stamp the currently-stored key version (0 = baseline) so receivers can drop stale keys.
        let keyVersion = currentKeyVersion(forLocalGroupId: groupId)
        let message = TSOutgoingGroupKeyMessage(thread: thread,
                                                 groupId: groupId,
                                                 groupRootKey: rGroup,
                                                 keyVersion: keyVersion)
        Logger.info("[GroupCrypto] Sending GroupKeyMessage to thread: \(thread.uniqueId), version: \(keyVersion)")
        SSKEnvironment.shared.messageSender.enqueue(message, success: {
            Logger.info("[GroupCrypto] Sent GroupKeyMessage to thread: \(thread.uniqueId)")
        }, failure: { error in
            Logger.error("[GroupCrypto] Failed to send GroupKeyMessage to thread: \(thread.uniqueId), error: \(error)")
        })
    }

    private func currentKeyVersion(forLocalGroupId groupId: Data) -> Int {
        guard let serverGid = TSGroupThread.transformToServerGroupId(withLocalGroupId: groupId),
              !serverGid.isEmpty else {
            return 0
        }
        var version = 0
        SDSDatabaseStorage.shared.read { transaction in
            version = self.keyStore.fetchKeyVersion(forGid: serverGid, transaction: transaction)
        }
        return version
    }

    // MARK: - Unified Refresh Entry

    /// 刷新加密群群名，幂等。
    @objc public static func refreshEncryptedGroupNameIfNeeded(gid: String,
                                                                transaction: SDSAnyWriteTransaction) {
        guard !gid.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else {
            return
        }
        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        guard let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction),
              groupThread.groupModel.isEncryptedGroup else {
            return
        }
        let cachedEncryptedName = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedName
        let decryptedName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
            gid: gid,
            groupCryptoMode: groupThread.groupModel.groupCryptoMode,
            encryptedName: cachedEncryptedName,
            originalName: groupThread.groupModel.groupName,
            transaction: transaction)
        let placeholder = DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder
        guard !decryptedName.isEmpty,
              decryptedName != placeholder,
              groupThread.groupModel.groupName != decryptedName else {
            return
        }
        groupThread.anyUpdateGroupThread(transaction: transaction) { thread in
            thread.groupModel.groupName = decryptedName
        }
    }

    /// 同步刷新加密群群名 + 头像，保证更新时机一致。
    @objc public static func refreshEncryptedGroupDisplay(gid: String,
                                                           transaction: SDSAnyWriteTransaction) {
        refreshEncryptedGroupNameIfNeeded(gid: gid, transaction: transaction)
        downloadEncryptedAvatarIfNeeded(gid: gid, transaction: transaction)
    }

    // MARK: - Private

    private func postKeyArrivalNotification(gid: String,
                                             transaction: SDSAnyWriteTransaction,
                                             shouldFetchGroupInfo: Bool) {
        Self.refreshEncryptedGroupDisplay(gid: gid, transaction: transaction)

        transaction.addAsyncCompletionOnMain { [gid] in
            NotificationCenter.default.post(
                name: DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification,
                object: nil,
                userInfo: [DTGroupCryptoConstants.groupCryptoKeyGidKey: gid]
            )

            if shouldFetchGroupInfo {
                Self.refreshGroupInfoOnRGroupArrival(gid: gid)
            }
        }
    }

    private static let inFlightProcessorsLock = NSLock()
    private static var inFlightProcessors: [ObjectIdentifier: DTGroupUpdateMessageProcessor] = [:]
    private static let processorInFlightTTL: TimeInterval = 30

    /// 群信息拉取节流，避免失败重试风暴和同 gid 并发重叠。
    private static let groupInfoFetchThrottle = ThrottleStore(window: 5.0)

    private static func retainInFlight(_ processor: DTGroupUpdateMessageProcessor) {
        inFlightProcessorsLock.lock()
        inFlightProcessors[ObjectIdentifier(processor)] = processor
        inFlightProcessorsLock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + processorInFlightTTL) {
            inFlightProcessorsLock.lock()
            inFlightProcessors.removeValue(forKey: ObjectIdentifier(processor))
            inFlightProcessorsLock.unlock()
        }
    }

    private static func refreshGroupInfoOnRGroupArrival(gid: String) {
        guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else { return }
        guard groupInfoFetchThrottle.tryAcquire(gid: gid) else {
            return
        }

        Logger.info("[GroupCrypto] R_group arrived, refreshing group info for gid: \(gid)")

        let processor = DTGroupUpdateMessageProcessor()
        retainInFlight(processor)
        NSObject.databaseStorage.asyncWrite { writeTransaction in
            processor.requestGroupInfo(withGroupId: groupId,
                                        targetVersion: 0,
                                        needSystemMessage: false,
                                        generate: false,
                                        envelope: nil,
                                        transaction: writeTransaction,
                                        completion: { _ in })
        }
    }

    /// 加密群本地能否解出群名：encryptedName 缺失 / 解密失败都视为未解出，触发主动拉群补齐 encryptedName。
    fileprivate static func localGroupNameUnresolved(gid: String,
                                                      transaction: SDSAnyReadTransaction) -> Bool {
        guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
              let thread = TSGroupThread.anyFetchGroupThread(
                  uniqueId: TSGroupThread.threadId(fromGroupId: groupId),
                  transaction: transaction),
              thread.groupModel.isEncryptedGroup else {
            return false
        }
        // encryptedName 缺失直接视为未解出，避免在 write transaction 里多走一次 AES。
        guard let encryptedName = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedName,
              !encryptedName.isEmpty else {
            return true
        }
        let decrypted = DTGroupCryptoManager.shared.decryptedGroupName(
            gid: gid, encryptedName: encryptedName, transaction: transaction)
        return decrypted?.isEmpty != false
    }

    @objc public static func downloadEncryptedAvatarIfNeeded(gid: String, transaction: SDSAnyWriteTransaction) {
        guard let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction),
              baseInfo.groupCryptoMode > 0,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else {
            return
        }
        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        guard let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) else {
            return
        }

        guard let avatarURL = DTGroupCryptoDisplayHelper.shared.prepareAvatarUpdate(
            plainAvatar: baseInfo.avatar,
            encryptedAvatar: baseInfo.encryptedAvatar,
            groupCryptoMode: baseInfo.groupCryptoMode,
            gid: gid,
            transaction: transaction
        ) else {
            return
        }

        let capturedGroupId = groupId
        let capturedEncryptedAvatar = baseInfo.encryptedAvatar ?? ""
        // Can't decrypt -> avatarURL is the lock placeholder (plainFallback); don't mark it as "real
        // avatar downloaded", or it blocks the real avatar from restoring once the key arrives.
        let isLockPlaceholder = baseInfo.groupCryptoMode > 0
            && !DTGroupCryptoDisplayHelper.shared.canDecryptAvatar(gid: gid, transaction: transaction)
        transaction.addAsyncCompletionOnMain {
            let processor = DTGroupAvatarUpdateProcessor(groupThread: groupThread)
            processor.handleReceivedGroupAvatarUpdate(withAvatarUpdate: avatarURL, success: { attachmentStream in
                guard let image = attachmentStream.image() else {
                    Logger.error("[GroupCrypto] downloadEncryptedAvatar: image nil, gid: \(gid)")
                    return
                }
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    // Race guard 1 (stale): download is async; if encryptedAvatar changed mid-download
                    // this is an old image — only write it for the current ciphertext.
                    let currentEnc = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: writeTransaction)?.encryptedAvatar ?? ""
                    guard currentEnc == capturedEncryptedAvatar else {
                        return
                    }
                    // Race guard 2 (lock): lock & real avatar download concurrently; if the lock arrives
                    // late but we can already decrypt, don't let it overwrite the real avatar.
                    if isLockPlaceholder,
                       DTGroupCryptoDisplayHelper.shared.canDecryptAvatar(gid: gid, transaction: writeTransaction) {
                        return
                    }
                    let thread = TSGroupThread.getOrCreateThread(withGroupId: capturedGroupId, transaction: writeTransaction)
                    thread.anyUpdateGroupThread(transaction: writeTransaction) { t in
                        t.groupModel.groupImage = image
                        // Don't force groupAvatarVersion=0: that clears the avatarUpdate path's version
                        // and bypasses its guard. The key path only renders the current ciphertext's image.
                    }
                    thread.fireAvatarChangedNotification()
                    if !isLockPlaceholder {
                        DTGroupCryptoDisplayHelper.shared.markAvatarDownloaded(gid: gid, encryptedAvatar: capturedEncryptedAvatar)
                    }
                }
            }, failure: { error in
                Logger.error("[GroupCrypto] downloadEncryptedAvatar failed, gid: \(gid), error: \(error)")
            })
        }
    }

    // MARK: - Private Helpers

    private static func enumerateEncryptedGroupThreads(
        transaction: SDSAnyReadTransaction,
        body: (TSGroupThread) -> Void
    ) {
        guard let grdbTransaction = transaction.readTransaction as? GRDBReadTransaction else { return }
        let sql = """
            SELECT * FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .recordType) = ?
            """
        let cursor = TSThread.grdbFetchCursor(sql: sql,
                                               arguments: [SDSRecordType.groupThread.rawValue],
                                               transaction: grdbTransaction)
        do {
            while let thread = try cursor.next() {
                guard let groupThread = thread as? TSGroupThread,
                      groupThread.groupModel.isEncryptedGroup,
                      !groupThread.serverThreadId.isEmpty else { continue }
                body(groupThread)
            }
        } catch {
            Logger.error("[GroupCrypto] Failed to enumerate encrypted group threads: \(error)")
        }
    }
}
