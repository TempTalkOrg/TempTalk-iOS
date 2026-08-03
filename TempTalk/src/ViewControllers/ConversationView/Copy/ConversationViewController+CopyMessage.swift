//
//  ConversationViewController+CopyMessage.swift
//  Difft
//
//  Multi-select copy + copy-notice insertion for all copy paths.
//

import Foundation
import TTServiceKit
import TTMessaging

// MARK: - Multi-select copy

extension ConversationViewController {

    /// Called from the multi-select toolbar when user taps the Copy button.
    func copySelectedMessages() {
        let selectedItems = viewState.selectedMessageItems
        guard !selectedItems.isEmpty else { return }

        var formattedText: String?
        databaseStorage.read { transaction in
            formattedText = DTMultiSelectCopyFormatter.format(
                viewItems: selectedItems,
                transaction: transaction
            )
        }

        guard let text = formattedText, !text.isEmpty else { return }

        DTSecurePasteboard.setString(text)
        DTToastHelper.toast(withText: Localized("COPY_SUCCESS_TOAST"), durationTime: 1)

        // A forwarded message (single forward / Chat History) copies only as the "[聊天记录]"
        // placeholder here, not its plaintext — no real content leaves, so it must not trigger
        // a trace and contributes no source author. But the count still reflects the full
        // selection (PRD §C: align with the selected count so it doesn't look off-by-one).
        let messages: [TSMessage] = selectedItems
            .compactMap { $0.interaction as? TSMessage }
            .filter { $0.combinedForwardingMessage == nil }
        sendCopyNotice(messages: messages, messageCount: UInt32(selectedItems.count))

        cancelMultiSelectMode()
    }
}

// MARK: - Copy notice (shared by all copy paths)

extension ConversationViewController {

    func sendCopyNotice(
        messages: [TSMessage],
        messageCount: UInt32,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode = .unknown
    ) {
        // "from" display uses the bubble senders; the trace decision may differ — a single
        // forwarded message gates on its original content author, not the bubble sender (PRD).
        let displayAuthorIds = CopyNoticeDispatcher.sourceAuthorIds(for: messages)
        let triggerAuthorIds = CopyNoticeDispatcher.triggerAuthorIds(for: messages)
        guard DTNoticeTraceEvaluator.shouldLeaveTrace(
            sourceThread: self.thread,
            targetThreads: nil,
            contentAuthorIds: triggerAuthorIds
        ) else { return }

        let fromAuthorIds = DTNoticeTraceEvaluator.orderForDisplay(displayAuthorIds)
        CopyNoticeDispatcher.sendNotice(
            sourceConversation: self.thread,
            sourceAuthorIds: fromAuthorIds,
            messageCount: messageCount,
            combinedForwardMode: combinedForwardMode
        )
    }

    func insertSingleCopyNotice(for message: TSMessage) {
        sendCopyNotice(messages: [message], messageCount: 1)
    }
}
