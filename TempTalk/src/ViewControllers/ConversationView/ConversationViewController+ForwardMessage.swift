//
//  ConversationViewController+ForwardMessage.swift
//  Signal
//
//  Created by Jaymin on 2024/1/11.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import SignalCoreKit

// MARK: - Public entry points

@objc extension ConversationViewController {

    /// 长按单条消息 → 转发到其他会话(走 select-thread 流程)
    func forwardSingleMessage(_ viewItem: ConversationViewItem) {
        addForwardMessage(viewItem)
        viewState.forwardType = .oneByOne

        showSelectThreadViewController()
    }

    /// 长按单条消息 → 保存到备忘录(跳过选择会话,直接发)
    func forwardSingleMessageToNote(_ viewItem: ConversationViewItem) {
        guard let message = viewItem.interaction as? TSMessage else { return }
        guard let localNumber = TSAccountManager.localNumber() else { return }

        let noteThread = TSContactThread.getOrCreateThread(contactId: localNumber)
        if let attachmentStream = viewItem.attachmentStream(), attachmentStream.isVoiceMessage() {
            OWSAttachmentsProcessor.decryptVoiceAttachment(attachmentStream)
        }

        let request = ForwardMessageService.Request(
            messages: [message],
            targets: [noteThread],
            type: .note,
            sourceConversation: self.thread,
            leaveMessage: nil
        )

        Task { [weak self] in
            let result = await ForwardMessageService.shared.forward(request)
            await MainActor.run {
                self?.handleForwardResult(result)
                if let stream = viewItem.attachmentStream(), stream.isVoiceMessage() {
                    stream.removeVoicePlaintextFile()
                }
            }
        }
    }
}

// MARK: - SelectThreadViewControllerDelegate

extension ConversationViewController: SelectThreadViewControllerDelegate {
    public func forwordThreadCanBeSelested(_ thread: TSThread) -> Bool {
        TSThreadPermissionHelper.checkCanSpeakAndToastTipMessage(thread)
    }

    public func canSelectBlockedContact() -> Bool {
        false
    }

    public func threadsWasSelected(_ threads: [TSThread]) {
        viewState.targetThreads = threads

        owsAssertDebug(!threads.isEmpty)
        owsAssertDebug(presentedViewController != nil)
        owsAssertDebug(!viewState.forwardMessageItems.isEmpty)

        if viewState.forwardMessageItems.isEmpty {
            Logger.info("forwardMessageItem is nil")
        }

        let forwardPreviewVC = DTForwardPreviewViewController()
        forwardPreviewVC.delegate = self
        forwardPreviewVC.modalPresentationStyle = .overFullScreen
        presentedViewController?.present(forwardPreviewVC, animated: false)
    }
}

// MARK: - DTForwardPreviewDelegate

extension ConversationViewController: DTForwardPreviewDelegate {
    func getThreadsToForwarding() -> [TSThread] {
        viewState.targetThreads
    }

    /// 点击预览弹窗上的发送按钮。
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        forwardMultipleMessages(leaveMessage: leaveMessage)
        dismiss(animated: true)
    }

    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        DTForwardMessageHelper.previewOfMessageText(
            withForwardType: viewState.forwardType,
            thread: self.thread,
            viewItems: viewState.forwardMessageItems
        )
    }
}

// MARK: - Internal (visible to MultiSelect / BatchRecall extensions)

extension ConversationViewController {
    /// 多选后从工具栏点击某种转发动作。由 MultiSelect extension 的 toolbar delegate 触发。
    func forwardMessages(forwardType: DTForwardMessageType) {
        viewState.forwardType = forwardType

        // 按时间增序,保证合并/逐条转发的顺序与用户选择时一致
        let sortedForwardMessages = viewState.forwardMessageItems.sorted(by: {
            $0.interaction.compare(forSorting: $1.interaction) != .orderedDescending
        })
        viewState.forwardMessageItems = sortedForwardMessages

        if forwardType == .note {
            forwardMessagesToNode()
        } else {
            showSelectThreadViewController()
        }
    }
}

// MARK: - Private

private extension ConversationViewController {

    /// 多选 → 保存到备忘录
    func forwardMessagesToNode() {
        guard let localNumber = TSAccountManager.localNumber() else { return }

        let messages = DTForwardMessageHelper.messages(from: viewState.forwardMessageItems)
        let noteThread = TSContactThread.getOrCreateThread(contactId: localNumber)

        let request = ForwardMessageService.Request(
            messages: messages,
            targets: [noteThread],
            type: .note,
            sourceConversation: self.thread,
            leaveMessage: nil
        )

        Task { [weak self] in
            let result = await ForwardMessageService.shared.forward(request)
            await MainActor.run {
                self?.handleForwardResult(result)
            }
        }
    }

    /// 多选 → 逐条/合并转发到若干目标会话(附 leaveMessage)
    func forwardMultipleMessages(leaveMessage: String?) {
        let messages = DTForwardMessageHelper.messages(from: viewState.forwardMessageItems)

        let request = ForwardMessageService.Request(
            messages: messages,
            targets: viewState.targetThreads,
            type: viewState.forwardType,
            sourceConversation: self.thread,
            leaveMessage: leaveMessage?.ows_stripped()
        )

        Task { [weak self] in
            let result = await ForwardMessageService.shared.forward(request)
            await MainActor.run {
                self?.handleForwardResult(result)
            }
        }
    }

    /// 统一 UI 反馈:取消多选 + Toast(成功/部分成功/失败根据结果)
    @MainActor
    func handleForwardResult(_ result: ForwardMessageService.Result) {
        if isMultiSelectMode {
            cancelMultiSelectMode()
        }
        let key: String
        let fallback: String
        if result.allSucceeded {
            key = "MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT"
            fallback = "Sent"
        } else if result.anySucceeded {
            key = "MESSAGE_STATUS_PARTIALLY_FAILED"
            fallback = "Partially sent"
        } else {
            key = "MESSAGE_STATUS_FAILED"
            fallback = "Send failed"
        }
        DTToastHelper.toast(withText: Localized(key, fallback), durationTime: 1.5)
    }

    /// 展示选择会话页面
    func showSelectThreadViewController() {
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let navigationVC = OWSNavigationController(rootViewController: selectThreadVC)
        present(navigationVC, animated: true)
    }
}
