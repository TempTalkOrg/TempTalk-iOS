//
//  ConversationViewController+BatchRecall.swift
//  Difft
//
//  Batch-recall of selected multi-select messages, split out of
//  +ForwardMessage into its own focused extension.
//

import Foundation
import TTServiceKit
import TTMessaging

extension ConversationViewController {

    /// 从多选工具栏点击撤回 → 入口
    func batchRecallMessages() {
        let recallable = filterRecallableMessages()
        guard !recallable.isEmpty else { return }

        showRecallConfirmationDialog(messageCount: recallable.count) { [weak self] in
            self?.executeBatchRecall(recallableMessages: recallable)
        }
    }
}

// MARK: - Private

private extension ConversationViewController {

    /// 过滤出可被撤回的消息(必须是 outgoing + 未过撤回时限)
    func filterRecallableMessages() -> [ConversationViewItem] {
        let currentTimestamp = NSDate.ows_millisecondTimeStamp()
        let recallThreshold = DTRecallConfig.fetch().timeoutInterval

        return viewState.forwardMessageItems.filter { viewItem in
            guard viewItem.interaction is TSOutgoingMessage else { return false }
            let msgTimestamp = viewItem.interaction.timestamp
            guard currentTimestamp >= msgTimestamp else { return false }
            let messageDuration = Double(currentTimestamp - msgTimestamp)
            return messageDuration <= (recallThreshold * 1000)
        }
    }

    /// 撤回前的确认弹窗
    func showRecallConfirmationDialog(messageCount: Int, onConfirm: @escaping () -> Void) {
        let title = String(format: Localized("BATCH_RECALL_CONFIRM_TITLE"), messageCount)
        let actionSheetController = ActionSheetController(title: title)
        actionSheetController.addAction(OWSActionSheets.cancelAction)

        let recallAction = ActionSheetAction(
            title: Localized("OK"),
            style: .destructive
        ) { _ in
            onConfirm()
        }
        actionSheetController.addAction(recallAction)
        presentActionSheet(actionSheetController)
    }

    func executeBatchRecall(recallableMessages: [ConversationViewItem]) {
        cancelMultiSelectMode()

        let outgoingMessages = recallableMessages.compactMap { $0.interaction as? TSOutgoingMessage }
        guard !outgoingMessages.isEmpty else { return }

        DTToastHelper.show()
        let dispatchGroup = DispatchGroup()
        let targetThread = thread

        let baseTimestamp = NSDate.ows_millisecondTimeStamp()

        for (index, outgoingMessage) in outgoingMessages.enumerated() {
            dispatchGroup.enter()
            let explicitTimestamp = baseTimestamp + UInt64(index)
            ThreadUtil.sendRecallMessage(
                withOriginMessage: outgoingMessage,
                in: targetThread,
                explicitTimestamp: explicitTimestamp
            ) {
                dispatchGroup.leave()
            } failure: { _ in
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            DTToastHelper.hide()
        }
    }
}
