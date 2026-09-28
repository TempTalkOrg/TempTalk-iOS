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
        let currentTimestamp = DTTrustedClock.now()

        return viewState.selectedMessageItems.filter { viewItem in
            isRecallableByTrustedTime(viewItem.interaction, now: currentTimestamp)
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

        for outgoingMessage in outgoingMessages {
            dispatchGroup.enter()
            ThreadUtil.sendRecallMessage(
                withOriginMessage: outgoingMessage,
                in: targetThread,
                explicitTimestamp: DTTrustedClock.clientStampMs()
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
