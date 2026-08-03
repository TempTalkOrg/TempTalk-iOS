//
//  CopyNoticeDispatcher.swift
//  Difft
//

import Foundation
import TTServiceKit

enum CopyNoticeDispatcher {

    /// Gated single-message copy notice. Applies the leak-risk rules (skips note-to-self and
    /// self-only copies) so every copy entry stays consistent. "from" uses the bubble sender;
    /// a single forwarded message gates on its original content author.
    static func sendNotice(
        for message: TSMessage,
        in thread: TSThread,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode = .unknown
    ) {
        let displayAuthorIds = sourceAuthorIds(for: [message])
        let triggerAuthorIds = Self.triggerAuthorIds(for: [message])
        guard DTNoticeTraceEvaluator.shouldLeaveTrace(
            sourceThread: thread,
            targetThreads: nil,
            contentAuthorIds: triggerAuthorIds
        ) else { return }
        let fromAuthorIds = DTNoticeTraceEvaluator.orderForDisplay(displayAuthorIds)
        sendNotice(
            sourceConversation: thread,
            sourceAuthorIds: fromAuthorIds,
            messageCount: 1,
            combinedForwardMode: combinedForwardMode
        )
    }

    static func sendNotice(
        sourceConversation: TSThread,
        sourceAuthorIds: [String],
        messageCount: UInt32,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode = .unknown
    ) {
        let noticeScope = makeNoticeConversation(for: sourceConversation)

        Logger.info("[CopyNotice] send thread=\(sourceConversation.uniqueId) count=\(messageCount) authors=\(sourceAuthorIds.count) combinedForwardMode=\(combinedForwardMode.rawValue)")

        let notice = TSOutgoingActivityNoticeMessage(
            thread: sourceConversation,
            sourceAuthorIds: sourceAuthorIds,
            messageCount: messageCount,
            sourceConversation: noticeScope,
            combinedForwardMode: combinedForwardMode
        )
        let messageTimestamp = notice.timestamp

        let messageSender = SSKEnvironment.shared.messageSenderRef
        messageSender.enqueue(notice, success: {
            Logger.info("[CopyNotice] sent thread=\(sourceConversation.uniqueId)")
        }, failure: { error in
            Logger.error("[CopyNotice] send failed thread=\(sourceConversation.uniqueId) error=\(error)")
        })

        insertLocalNotice(
            sourceConversation: sourceConversation,
            sourceAuthorIds: sourceAuthorIds,
            messageCount: messageCount,
            combinedForwardMode: combinedForwardMode,
            timestamp: messageTimestamp
        )
    }

    static func sourceAuthorIds(for messages: [TSMessage]) -> [String] {
        DTNoticeAuthorListFormatter.sortedAuthorIds(for: messages)
    }

    /// Authors used for the trace DECISION (not the "from" display). See
    /// `DTNoticeAuthorListFormatter.triggerAuthorIds`: copying a single forwarded message
    /// gates on its original content author, not the bubble sender.
    static func triggerAuthorIds(for messages: [TSMessage]) -> [String] {
        DTNoticeAuthorListFormatter.triggerAuthorIds(for: messages)
    }

    // MARK: - Private

    private static func insertLocalNotice(
        sourceConversation: TSThread,
        sourceAuthorIds: [String],
        messageCount: UInt32,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode,
        timestamp: UInt64
    ) {
        let operatorId = TSAccountManager.localNumber()

        SSKEnvironment.shared.databaseStorageRef.asyncWrite { transaction in
            let text = DTCopyNoticeTextFormatter.text(
                operatorId: operatorId,
                messageCount: messageCount,
                sourceAuthorIds: sourceAuthorIds,
                combinedForwardMode: combinedForwardMode,
                transaction: transaction
            )
            let info = TSInfoMessage(
                timestamp: timestamp,
                in: sourceConversation,
                messageType: .copyNotice,
                customMessage: text
            )
            info.serverTimestamp = timestamp
            info.authorId = operatorId ?? ""
            info.isShouldAffectThreadSorting = true
            info.anyInsert(transaction: transaction)
            Logger.info("[CopyNotice] local inserted thread=\(sourceConversation.uniqueId) ts=\(timestamp)")
        }
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
        owsFailDebug("Unexpected thread type: \(type(of: thread))")
        return .oneOnOne(number: "")
    }
}
