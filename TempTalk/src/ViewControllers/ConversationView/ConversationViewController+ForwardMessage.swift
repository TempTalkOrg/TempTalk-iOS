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

// MARK: - Public

@objc extension ConversationViewController {
    var forwardToolbar: DTMultiSelectToolbar {
        get {
            if let toolbar = viewState.forwardToolbar {
                return toolbar
            }
            let newToolbar = DTMultiSelectToolbar()
            newToolbar.delegate = self
            viewState.forwardToolbar = newToolbar
            return newToolbar
        }
        set {
            viewState.forwardToolbar = newValue
        }
    }
    
    var isMultiSelectMode: Bool {
        get {
            viewState.isMultiSelectMode
        }
        set {
            viewState.isMultiSelectMode = newValue
        }
    }
    
    /// 转发单条消息
    func forwardSingleMessage(_ viewItem: ConversationViewItem) {
        addForwardMessage(viewItem)
        viewState.forwardType = .oneByOne
        
        showSelectThreadViewController()
    }
    
    /// 转发单条信息至备忘录
    func forwardSingleMessageToNote(_ viewItem: ConversationViewItem) {
        guard let message = viewItem.interaction as? TSMessage else { return }
        guard let localNumber = TSAccountManager.localNumber() else { return }
        
        let noteThread = TSContactThread.getOrCreateThread(contactId: localNumber)
        if let attachmentStream = viewItem.attachmentStream(), attachmentStream.isVoiceMessage() {
            OWSAttachmentsProcessor.decryptVoiceAttachment(attachmentStream)
        }
        DTForwardMessageHelper.forwardMessageIs(
            fromGroup: self.thread.isGroupThread(),
            targetThread: noteThread,
            messages: [message]
        ) {
            DispatchMainThreadSafe {
                DTToastHelper.toast(
                    withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", "Sent"),
                    durationTime: 1.5
                )
            }
            if let attachmentStream = viewItem.attachmentStream(), attachmentStream.isVoiceMessage() {
                attachmentStream.removeVoicePlaintextFile()
            }
        } failure: { error in
            DispatchMainThreadSafe {
                DTToastHelper.toast(
                    withText: Localized("MESSAGE_STATUS_FAILED", "Sent"),
                    durationTime: 1.5
                )
            }
            if let attachmentStream = viewItem.attachmentStream(), attachmentStream.isVoiceMessage() {
                attachmentStream.removeVoicePlaintextFile()
            }
        }
    }
    
    /// 多选模式下，是否已经选中了 message
    func isSelectedViewItemInMultiSelectMode(_ viewItem: ConversationViewItem) -> Bool {
        guard isMultiSelectMode else {
            return false
        }
        return viewState.forwardMessageItems.first(where: { $0.isEqual(to: viewItem) }) != nil
    }
    
    /// 多选模式下，选中或取消选中 message
    func didSelectMessageInMultiSelectMode(indexPath: IndexPath) {
        guard isMultiSelectMode else {
            return
        }
        collectionView.deselectItem(at: indexPath, animated: false)
        
        let viewItems = self.viewItems
        guard let viewItem = viewItems[safe: indexPath.row] else {
            owsFailDebug("Invalid view item index: \(indexPath.row)")
            return
        }
        
        if viewItem.isConfidentialMessage {
            DTToastHelper.toast(withText: Localized("FORWARD_MESSAGE_CONFIDENTIAL"))
            return
        }
        
        // 超过最大转发数量
        let isSelected = isSelectedViewItemInMultiSelectMode(viewItem)
        let maxMsgCount = 50
        if viewState.forwardMessageItems.count == maxMsgCount, !isSelected {
            DTToastHelper.toast(
                withText: String(format: Localized("FORWARD_MESSAGE_SELECT_MESSAGE_MAX_COUNT"), maxMsgCount),
                durationTime: 1
            )
            return
        }
        // 不支持转发的消息类型
        if isUnsupportMessageType(viewItem.messageCellType()) {
            DTToastHelper.toast(
                withText: Localized("FORWARD_MESSAGE_FORBIDDEN_REMINDER", comment: "attachment unsupported"),
                durationTime: 1
            )
            return
        }
        
        if !isSelected {
            addForwardMessage(viewItem)
        } else {
            removeForwardMessage(viewItem)
        }
        forwardToolbar.updateActionItemsSelectedCount(
            UInt(viewState.forwardMessageItems.count),
            maxCount: 50,
            enableCounts: [1, 2, 1]
        )
        reloadItems(at: [indexPath])
    }
    
    func addForwardMessage(_ forwardMessage: ConversationViewItem) {
        viewState.forwardMessageItems.append(forwardMessage)
    }
    
    func removeForwardMessage(_ forwardMessage: ConversationViewItem) {
        let newForwardMessages = viewState.forwardMessageItems.filter { !$0.isEqual(to: forwardMessage) }
        viewState.forwardMessageItems = newForwardMessages
    }
    
    func clearAllForwardMessages() {
        viewState.forwardMessageItems.removeAll()
    }
    
    func applyThemeForForwardToolbar() {
        guard isMultiSelectMode else {
            return
        }
        guard let toolbar = viewState.forwardToolbar else {
            return
        }
        toolbar.applyTheme()
    }
}

// MARK: - DTMultiSelectToolbarDelegate

extension ConversationViewController: DTMultiSelectToolbarDelegate {
    func multiSelectToolbar(_: DTMultiSelectToolbar, didSelectIndex index: Int) {
        let forwardType: DTForwardMessageType = .init(rawValue: index) ?? .oneByOne
        forwardMessages(forwardType: forwardType)
    }
    
    func items(for multiSelectToolBar: DTMultiSelectToolbar) -> [DTMultiSelectToolbarItem] {
        [
            .init(
                imageName: "toolbar-forward",
                title: Localized("MESSAGE_ACTION_FORWARD")
            ),
            .init(
                imageName: "toolbar-combine-forward",
                title: Localized("MESSAGE_ACTION_COMBINE_FORWARD")
            ),
            .init(
                imageName: "toolbar-save",
                title: Localized("MESSAGE_ACTION_SAVE")
            )
        ]
    }
}

// MARK: - SelectThreadViewControllerDelegate

extension ConversationViewController: SelectThreadViewControllerDelegate {
    /// 会话是否允许转发消息
    public func forwordThreadCanBeSelested(_ thread: TSThread) -> Bool {
        TSThreadPermissionHelper.checkCanSpeakAndToastTipMessage(thread)
    }
    
    /// 是否允许选择被 block 的会话
    public func canSelectBlockedContact() -> Bool {
        false
    }
    
    /// 选择了需要转发到哪些会话，跳转到 preview 页面
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
    /// 转发到哪些会话
    func getThreadsToForwarding() -> [TSThread] {
        viewState.targetThreads
    }
    
    /// 点击预览弹窗上的发送按钮
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        
        forwardMultipleMessages(leaveMessage: leaveMessage)
        
        if isMultiSelectMode {
            cancelMultiSelectMode()
        }
        dismiss(animated: true) {
            DTToastHelper.toast(
                withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", "Sent"),
                durationTime: 1.5
            )
        }
    }
    
    /// 预览弹窗上展示的文字内容
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        DTForwardMessageHelper.previewOfMessageText(
            withForwardType: viewState.forwardType,
            thread: self.thread,
            viewItems: viewState.forwardMessageItems
        )
    }
}

// MARK: - Private

private extension ConversationViewController {
    func isUnsupportMessageType(_ type: OWSMessageCellType) -> Bool {
        let unsupportMessageTypes: [OWSMessageCellType] = [.audio]
        return unsupportMessageTypes.contains(type)
    }
    
    func forwardMessages(forwardType: DTForwardMessageType) {
        viewState.forwardType = forwardType
        
        // 按照时间增序排序
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
    
    /// 转发多条消息至备忘录（与转发单条信息至备忘录的区别是，全部按成功状态处理，待确认是否需要优化）
    func forwardMessagesToNode() {
        guard let contractId = TSAccountManager.localNumber() else {
            return
        }
        let forwardMessages = DTForwardMessageHelper.messages(from: viewState.forwardMessageItems)
        let noteThread = TSContactThread.getOrCreateThread(contactId: contractId)
        DTForwardMessageHelper.forwardMessageIs(
            fromGroup: self.thread.isGroupThread(),
            targetThread: noteThread,
            messages: forwardMessages,
            success: nil,
            failure: nil
        )
        if isMultiSelectMode {
            cancelMultiSelectMode()
        }
        DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", "Sent"), durationTime: 1.5)
    }
    
    /// 转发多条消息（一条一条转发或者聚合转发）
    func forwardMultipleMessages(leaveMessage: String?) {
        let forwardMessages = DTForwardMessageHelper.messages(from: viewState.forwardMessageItems)
        let finalLeaveMessage = leaveMessage?.ows_stripped()
        let targetThreads = viewState.targetThreads
        let forwardType = viewState.forwardType
        let isFromGroup = self.thread.isGroupThread()
        let messageSender = self.messageSender
        
        func forward(to targetThread: TSThread, messags: [TSMessage]) {
            // NOTE: 这里注意使用的是同步函数，确保队列执行结束再执行后续操作，否则可能会造成消息时间戳一致导致消息丢失问题
            DispatchQueue.main.sync {
                DTForwardMessageHelper.forwardMessageIs(
                    fromGroup: isFromGroup,
                    targetThread: targetThread,
                    messages: messags,
                    success: nil,
                    failure: nil
                )
            }
        }
        
        func send(to targetThread: TSThread, message: String) {
            // NOTE: 这里注意使用的是同步函数，确保队列执行结束再执行后续操作，否则可能会造成消息时间戳一致导致消息丢失问题
            DispatchQueue.main.sync {
                _ = ThreadUtil.sendMessage(
                    withText: message,
                    atPersons: nil,
                    mentions: nil,
                    in: targetThread,
                    quotedReplyModel: nil,
                    messageSender: messageSender,
                    success: {},
                    failure: { _ in }
                )
            }
        }
        
        // Note: 这里加延迟的目的是，若转发/发送消息的时间戳相同，消息会出现丢失情况
        DispatchQueue.global(qos: .default).async {
            targetThreads.forEach { targetThread in
                if forwardType == .oneByOne {
                    forwardMessages.forEach {
                        forward(to: targetThread, messags: [$0])
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                } else {
                    forward(to: targetThread, messags: forwardMessages)
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if let finalLeaveMessage, !finalLeaveMessage.isEmpty {
                    send(to: targetThread, message: finalLeaveMessage)
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
    }
    
    /// 展示选择会话页面
    func showSelectThreadViewController() {
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let navigationVC = OWSNavigationController(rootViewController: selectThreadVC)
        present(navigationVC, animated: true)
    }
}
