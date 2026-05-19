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
        let rGroupBase64 = rGroupData.base64EncodedString()

        Logger.info("[GroupCrypto] GroupKeyMessage received, gid: \(gid)")
        keyStore.updateRGroup(gid: gid, rGroup: rGroupBase64, transaction: transaction)
        postKeyArrivalNotification(gid: gid, transaction: transaction)
    }


    // MARK: - Fallback R_group from GroupContext

    @objc public func handleFallbackGroupRootKey(groupContext: DSKProtoGroupContext,
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
        let rGroupBase64 = rGroupData.base64EncodedString()
        let saved = keyStore.saveRGroupIfNeeded(gid: gid, rGroup: rGroupBase64, transaction: transaction)
        Logger.info("[GroupCrypto] Fallback R_group piggybacked, gid: \(gid), saved: \(saved)")
        if saved {
            postKeyArrivalNotification(gid: gid, transaction: transaction)
        }
    }

    // MARK: - Attach R_group for Sending

    @objc public func attachRGroupToGroupContext(builder: DSKProtoGroupContext.DSKProtoGroupContextBuilder,
                                                 gid: String,
                                                 transaction: SDSAnyReadTransaction) {
        guard let rGroupBase64 = keyStore.fetchRGroup(forGid: gid, transaction: transaction) else {
            Logger.warn("[GroupCrypto] attachRGroupToGroupContext skip: no R_group in store, gid: \(gid)")
            return
        }
        guard let rGroupData = Data(base64Encoded: rGroupBase64) else {
            Logger.error("[GroupCrypto] attachRGroupToGroupContext skip: R_group base64 decode failed, gid: \(gid), storedLen: \(rGroupBase64.count)")
            return
        }
        builder.setGroupRootKey(rGroupData)
    }

    // MARK: - Send GroupKeyMessage

    @objc public func sendGroupKeyMessage(thread: TSThread,
                                           groupId: Data,
                                           rGroup: Data) {
        let message = TSOutgoingGroupKeyMessage(thread: thread,
                                                 groupId: groupId,
                                                 groupRootKey: rGroup)
        Logger.info("[GroupCrypto] Sending GroupKeyMessage to thread: \(thread.uniqueId)")
        SSKEnvironment.shared.messageSender.enqueue(message, success: {
            Logger.info("[GroupCrypto] Sent GroupKeyMessage to thread: \(thread.uniqueId)")
        }, failure: { error in
            Logger.error("[GroupCrypto] Failed to send GroupKeyMessage to thread: \(thread.uniqueId), error: \(error)")
        })
    }

    // MARK: - Private

    private func postKeyArrivalNotification(gid: String, transaction: SDSAnyWriteTransaction) {
        if let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) {
            let threadId = TSGroupThread.threadId(fromGroupId: groupId)
            if let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction),
               groupThread.groupModel.isEncryptedGroup {
                let decryptedName = DTGroupCryptoDisplayHelper.shared.displayGroupName(
                    gid: gid,
                    groupCryptoMode: groupThread.groupModel.groupCryptoMode,
                    encryptedName: nil,
                    originalName: groupThread.groupModel.groupName,
                    transaction: transaction)
                groupThread.anyUpdateGroupThread(transaction: transaction) { thread in
                    if thread.groupModel.groupName != decryptedName {
                        thread.groupModel.groupName = decryptedName
                    }
                }
            }
        }

        tryDownloadEncryptedAvatarIfNeeded(gid: gid, transaction: transaction)

        let needsRefresh = Self.needsGroupInfoRefreshForAvatar(gid: gid, transaction: transaction)

        transaction.addAsyncCompletionOnMain { [gid] in
            NotificationCenter.default.post(
                name: DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification,
                object: nil,
                userInfo: [DTGroupCryptoConstants.groupCryptoKeyGidKey: gid]
            )

            if needsRefresh {
                Self.refreshGroupInfoForEncryptedAvatar(gid: gid)
            }
        }
    }

    private static func needsGroupInfoRefreshForAvatar(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        guard let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction),
              baseInfo.groupCryptoMode > 0 else {
            return true
        }
        return baseInfo.encryptedAvatar == nil || baseInfo.encryptedAvatar?.isEmpty == true
    }

    private static func refreshGroupInfoForEncryptedAvatar(gid: String) {
        guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else { return }

        Logger.info("[GroupCrypto] R_group arrived but encryptedAvatar missing, refreshing group info for gid: \(gid)")

        NSObject.databaseStorage.asyncWrite { writeTransaction in
            let processor = DTGroupUpdateMessageProcessor()
            processor.requestGroupInfo(withGroupId: groupId,
                                        targetVersion: 0,
                                        needSystemMessage: false,
                                        generate: false,
                                        envelope: nil,
                                        transaction: writeTransaction,
                                        completion: { _ in })
        }
    }

    private func tryDownloadEncryptedAvatarIfNeeded(gid: String, transaction: SDSAnyWriteTransaction) {
        Self.downloadEncryptedAvatarIfNeeded(gid: gid, transaction: transaction)
    }

    @objc public static func downloadEncryptedAvatarIfNeeded(gid: String, transaction: SDSAnyWriteTransaction) {
        guard let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction) else {
            Logger.info("[GroupCrypto] downloadEncryptedAvatar skip: baseInfo missing, gid: \(gid)")
            return
        }
        guard baseInfo.groupCryptoMode > 0 else {
            Logger.info("[GroupCrypto] downloadEncryptedAvatar skip: not encrypted group, gid: \(gid)")
            return
        }

        guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else {
            Logger.info("[GroupCrypto] downloadEncryptedAvatar skip: invalid groupId, gid: \(gid)")
            return
        }
        let threadId = TSGroupThread.threadId(fromGroupId: groupId)
        guard let groupThread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction) else {
            Logger.info("[GroupCrypto] downloadEncryptedAvatar skip: groupThread missing, gid: \(gid)")
            return
        }

        guard let avatarURL = DTGroupCryptoDisplayHelper.shared.prepareAvatarUpdate(
            plainAvatar: baseInfo.avatar,
            encryptedAvatar: baseInfo.encryptedAvatar,
            groupCryptoMode: baseInfo.groupCryptoMode,
            gid: gid,
            transaction: transaction
        ) else {
            // prepareAvatarUpdate 里已按分支打了 keep/clear 的 info 日志
            return
        }

        let capturedGroupId = groupId
        // capture 发起下载时的密文作为指纹。异步期间 DB 若被新密文覆盖，
        // 不能用 DB 最新值回填指纹，否则会污染判定导致新头像被跳过。
        let capturedEncryptedAvatar = baseInfo.encryptedAvatar ?? ""

        transaction.addAsyncCompletionOnMain {
            let processor = DTGroupAvatarUpdateProcessor(groupThread: groupThread)
            processor.handleReceivedGroupAvatarUpdate(withAvatarUpdate: avatarURL, success: { attachmentStream in
                guard let image = attachmentStream.image() else {
                    Logger.error("[GroupCrypto] downloadEncryptedAvatar: attachmentStream.image() nil, gid: \(gid)")
                    return
                }
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    let thread = TSGroupThread.getOrCreateThread(withGroupId: capturedGroupId, transaction: writeTransaction)
                    thread.anyUpdateGroupThread(transaction: writeTransaction) { t in
                        t.groupModel.groupImage = image
                        t.groupModel.groupAvatarVersion = 0
                    }
                    thread.fireAvatarChangedNotification()
                    Logger.info("[GroupCrypto] downloadEncryptedAvatar success, gid: \(gid)")
                    DTGroupCryptoDisplayHelper.shared.markAvatarDownloaded(gid: gid, encryptedAvatar: capturedEncryptedAvatar)
                }
            }, failure: { error in
                Logger.error("[GroupCrypto] downloadEncryptedAvatar failed, gid: \(gid), error: \(error)")
            })
        }
    }

    @objc public static func repairMissingGroupCryptoKeys() {
        let keyStore = DTGroupCryptoKeyStoreImpl()
        NSObject.databaseStorage.asyncRead { transaction in
            var missingGids: [(gid: String, localGroupId: Data)] = []
            Self.enumerateEncryptedGroupThreads(transaction: transaction) { groupThread in
                let gid = groupThread.serverThreadId
                if keyStore.fetchRGroup(forGid: gid, transaction: transaction) != nil { return }
                Logger.warn("[GroupCrypto] Missing R_group for gid: \(gid), will refresh baseInfo")
                missingGids.append((gid, groupThread.groupModel.groupId))
            }

            for item in missingGids {
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    let processor = DTGroupUpdateMessageProcessor()
                    processor.requestGroupInfo(withGroupId: item.localGroupId,
                                                targetVersion: 0,
                                                needSystemMessage: false,
                                                generate: false,
                                                envelope: nil,
                                                groupNotifyEntity: nil,
                                                transaction: writeTransaction,
                                                completion: { _ in })
                }
            }
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
