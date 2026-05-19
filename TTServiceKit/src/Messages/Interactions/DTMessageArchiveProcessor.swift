//
//  DTConversationArchiveProcess.swift
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

import Foundation

/// 会话归档的处理类
@objc public class DTMessageArchiveProcessor: NSObject {

    // MARK: - Sync Message

    @objc public class func processIncomingSyncMessage(archiveMessage: DSKProtoSyncMessageConversationArchive?,
                                                       serverTimestamp: UInt64,
                                                       transaction: SDSAnyWriteTransaction) {
        guard let archiveMessage = archiveMessage else { return }
        guard let conversation = archiveMessage.conversation,
              archiveMessage.hasFlag,
              let flag = archiveMessage.flag else { return }

        if conversation.hasGroupID, let groupId = conversation.groupID {
            guard let gThread = TSGroupThread(groupId: groupId, transaction: transaction) else { return }
            if flag == .archive {
                gThread.anyUpdate(transaction: transaction) { $0.archiveThread(with: transaction) }
            } else if flag == .unarchive {
                gThread.anyUpdate(transaction: transaction) { $0.unarchiveThread() }
            }
        } else if conversation.hasNumber, let receiptId = conversation.number {
            let cThread = TSContactThread.getOrCreateThread(withContactId: receiptId, transaction: transaction)
            if flag == .archive {
                cThread.anyUpdate(transaction: transaction) { $0.archiveThread(with: transaction) }
            } else if flag == .unarchive {
                cThread.anyUpdate(transaction: transaction) { $0.unarchiveThread() }
            }
        } else {
            Logger.info("Conversation Archive error")
        }
    }

    // MARK: - Notify Archive Message
    @objc public class func processNotifyArchiveMessage(archiveMessage: DTMessageArchiveEntity?,
                                                        transaction: SDSAnyWriteTransaction) {
        guard let archiveMessage = archiveMessage else { return }

        if let groupId = archiveMessage.gid {
            processGroupArchive(serverGroupId: groupId,
                                endTimestamp: archiveMessage.endTimestamp,
                                transaction: transaction)
        } else if let concatNumbers = archiveMessage.concatNumbers {
            processContactArchive(concatNumbers: concatNumbers,
                                  endTimestamp: archiveMessage.endTimestamp,
                                  transaction: transaction)
        } else {
            Logger.error("[Archive] missing gid and concatNumbers")
        }
    }

    // MARK: - Group Archive

    private class func processGroupArchive(serverGroupId: String,
                                           endTimestamp: UInt64,
                                           transaction: SDSAnyWriteTransaction) {
        guard let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGroupId) else { return }

        let threadId = TSGroupThread.threadId(fromGroupId: localGroupId)
        let thread = TSGroupThread.anyFetchGroupThread(uniqueId: threadId, transaction: transaction)
            ?? TSGroupThread(groupId: localGroupId, transaction: transaction)

        guard let thread else { return }

        updateEndTimestamp(endTimestamp, for: thread, transaction: transaction)
        archiveInteractions(for: thread, beforeTimestamp: endTimestamp, transaction: transaction)
    }

    // MARK: - Contact Archive

    private class func processContactArchive(concatNumbers: String,
                                             endTimestamp: UInt64,
                                             transaction: SDSAnyWriteTransaction) {
        guard let receiptIds = splitString(input: concatNumbers, separator: ":"),
              let localNum = TSAccountManager.shared.localNumber(with: transaction) else {
            Logger.error("[Archive] localNum is nil")
            return
        }

        guard let contactId = receiptIds.first(where: { $0 != localNum }) else {
            Logger.error("[Archive] no valid receiptId found")
            return
        }

        Logger.info("[Archive] processing contact: \(contactId)")
        let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
        updateEndTimestamp(endTimestamp, for: thread, transaction: transaction)
        archiveInteractions(for: thread, beforeTimestamp: endTimestamp, transaction: transaction)
    }

    // MARK: - Helpers

    private class func updateEndTimestamp(_ endTimestamp: UInt64,
                                          for thread: TSThread,
                                          transaction: SDSAnyWriteTransaction) {
        let config = thread.threadConfig ?? DTThreadConfigEntity()
        guard let config else { return }
        thread.anyUpdate(transaction: transaction) { t in
            config.endTimestamp = endTimestamp
            t.threadConfig = config
        }
    }

    private class func archiveInteractions(for thread: TSThread,
                                           beforeTimestamp: UInt64,
                                           transaction: SDSAnyWriteTransaction) {
        let creationTimestamp = UInt64(thread.creationDate.timeIntervalSince1970 * 1000)
        if creationTimestamp > beforeTimestamp {
            Logger.info("[Archive] Skipping archive for recreated thread (creationDate > endTimestamp)")
            return
        }

        let interactions = InteractionFinder.fetch(uniqueId: thread.uniqueId,
                                                   beforeTimestamp: beforeTimestamp,
                                                   transaction: transaction)
        for interaction in interactions {
            guard let message = interaction as? TSMessage else { continue }
            OWSArchivedMessageJob.shared().archiveMessage(message, transaction: transaction)
        }
    }

    private class func splitString(input: String, separator: Character) -> [String]? {
        return input.split(separator: separator).map { String($0) }
    }
}
