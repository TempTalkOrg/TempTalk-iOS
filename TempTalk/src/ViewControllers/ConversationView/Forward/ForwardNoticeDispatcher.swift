//
//  ForwardNoticeDispatcher.swift
//  Difft
//

import Foundation
import TTServiceKit

enum ForwardNoticeDispatcher {

    static func sendNotice(
        sourceConversation: TSThread,
        scene: DTForwardNoticeScene,
        sourceAuthorIds: [String],
        messageCount: UInt32,
        messageSender: MessageSender,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode = .unknown
    ) async throws {
        let noticeScope = makeNoticeConversation(for: sourceConversation)
        Logger.info("[ForwardNotice] send thread=\(sourceConversation.uniqueId) scope=\(noticeScope.scope.rawValue) scene=\(scene.rawValue) count=\(messageCount) authors=\(sourceAuthorIds.count) mode=\(combinedForwardMode.rawValue)")

        let messageTimestamp = try await sendPrimary(
            primaryThread: sourceConversation,
            scope: noticeScope,
            scene: scene,
            sourceAuthorIds: sourceAuthorIds,
            messageCount: messageCount,
            messageSender: messageSender,
            combinedForwardMode: combinedForwardMode
        )

        insertLocalNotice(
            sourceConversation: sourceConversation,
            sourceAuthorIds: sourceAuthorIds,
            messageCount: messageCount,
            combinedForwardMode: combinedForwardMode,
            timestamp: messageTimestamp
        )
    }

    private static func insertLocalNotice(
        sourceConversation: TSThread,
        sourceAuthorIds: [String],
        messageCount: UInt32,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode,
        timestamp: UInt64
    ) {
        let operatorId = TSAccountManager.localNumber()
        SSKEnvironment.shared.databaseStorageRef.asyncWrite { transaction in
            let text = DTForwardNoticeTextFormatter.text(
                operatorId: operatorId,
                messageCount: messageCount,
                sourceAuthorIds: sourceAuthorIds,
                combinedForwardMode: combinedForwardMode,
                transaction: transaction
            )
            let info = TSInfoMessage(
                timestamp: timestamp,
                in: sourceConversation,
                messageType: .forwardNotice,
                customMessage: text
            )
            info.serverTimestamp = timestamp
            info.authorId = operatorId ?? ""
            info.isShouldAffectThreadSorting = true
            info.anyInsert(transaction: transaction)
            Logger.info("[ForwardNotice] local inserted thread=\(sourceConversation.uniqueId) ts=\(timestamp)")
        }
    }

    // MARK: - Private

    @discardableResult
    private static func sendPrimary(
        primaryThread: TSThread,
        scope: DTForwardNoticeConversation,
        scene: DTForwardNoticeScene,
        sourceAuthorIds: [String],
        messageCount: UInt32,
        messageSender: MessageSender,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode
    ) async throws -> UInt64 {
        let notice = TSOutgoingForwardNoticeMessage(
            thread: primaryThread,
            scene: scene,
            sourceAuthorIds: sourceAuthorIds,
            messageCount: messageCount,
            sourceConversation: scope,
            combinedForwardMode: combinedForwardMode
        )
        let messageTimestamp = notice.timestamp

        try await withCheckedThrowingContinuation { (raw: CheckedContinuation<Void, Error>) in
            let gate = SingleShotContinuation(raw)
            messageSender.enqueue(notice, success: {
                Logger.info("[ForwardNotice] primary sent thread=\(primaryThread.uniqueId) scene=\(scene.rawValue)")
                gate.resume()
            }, failure: { error in
                Logger.error("[ForwardNotice] primary failed thread=\(primaryThread.uniqueId) scene=\(scene.rawValue) error=\(error)")
                gate.resume(throwing: error)
            })
        }

        return messageTimestamp
    }

    private static func makeNoticeConversation(for thread: TSThread) -> DTForwardNoticeConversation {
        if let group = thread as? TSGroupThread {
            return .group(groupId: group.groupModel.groupId)
        }
        if let contact = thread as? TSContactThread {
            let peer = contact.contactIdentifier()
            if let localNumber = TSAccountManager.localNumber(), peer == localNumber {
                return .noteToSelf(localNumber: localNumber)
            }
            return .oneOnOne(number: peer)
        }
        return .oneOnOne(number: thread.contactIdentifier ?? "")
    }

}

private extension TSThread {
    var contactIdentifier: String? {
        (self as? TSContactThread)?.contactIdentifier()
    }
}
