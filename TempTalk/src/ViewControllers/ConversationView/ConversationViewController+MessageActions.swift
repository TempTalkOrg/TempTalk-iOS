//
//  ConversationViewController+MessageActions.swift
//  Signal
//
//  Created by Jaymin on 2024/1/17.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SignalCoreKit
import TTMessaging
import SVProgressHUD

// MARK: - Public

@objc
enum ConversationMessageType: Int {
    case text
    case media
    case quoted
    case combinedForwarding
    case contactShare
    case task
    case vote
    case card
    case info
}

// MARK: Action Menu

extension ConversationViewController {
    private var actionMessageType: ConversationMessageType? {
        get { viewState.actionMessageType }
        set { viewState.actionMessageType = newValue }
    }
    
    var actionMenuController: ConversationActionMenuController? {
        get { viewState.actionMenuController }
        set { viewState.actionMenuController = newValue }
    }
    
    func handleActionMenu(
        messageType: ConversationMessageType,
        viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        clearAllForwardMessages()
        self.inputToolbar.endEditing(true)
        
        // 防止非 TSIncomingMessage/TSOutgoingMessage 乱入造成 reaction crash
        let interaction = viewItem.interaction
        guard interaction.isKind(of: TSOutgoingMessage.self) || interaction.isKind(of: TSIncomingMessage.self) else {
            OWSLogger.error("interaction is \(type(of: interaction))")
            return
        }
        
        if let oldMenuController = actionMenuController {
            if messageType == actionMessageType {
                return
            }
            oldMenuController.dismissMenu(animation: true) {
                self.actionMenuController = nil
                self.presentMenu(messageType: messageType, viewItem: viewItem, bubbleView: bubbleView)
            }
        } else {
            self.presentMenu(messageType: messageType, viewItem: viewItem, bubbleView: bubbleView)
        }
    }
    
    private func presentMenu(
        messageType: ConversationMessageType,
        viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        // 需要支持部分复制文本，全选文本
        var textSelectionView: DTTextSelectionView?
        if messageType == .text || messageType == .card {
            bubbleView.textDelegate = self
            bubbleView.textViewSelectAll()
            textSelectionView = bubbleView.bodyTextSelectionView
        }
        self.actionMessageType = messageType
        
        // 默认使用 bubbleView 作为 sourceView (用于计算 menu 位置，和事件传递)
        var sourceView: UIView = bubbleView
        // 如果是图文混排的消息，sourceView 需要更精确，因为点击图片和点击文字展示的 menu 内容不同，避免用户误解
        if bubbleView.hasBodyMediaWithThumbnail, viewItem.hasBodyText {
            switch messageType {
            case .text:
                if let textView = bubbleView.bodyTextView.superview {
                    sourceView = textView
                }
            case .media:
                if let mediaView = bubbleView.bodyMediaView {
                    sourceView = mediaView
                }
            default:
                break
            }
        }
        
        let actions: [MenuAction]
        if viewItem.isConfidentialMessage {
            actions = messageType.confidentialActions(viewItem: viewItem, delegate: self)
        } else {
            actions = messageType.messageActions(viewItem: viewItem, delegate: self)
        }
        
        var emojiAction: MenuEmojiAction? = nil
        if viewItem.allowEmojiReaction() {
            emojiAction = ConversationViewItemActions.emojiReaction(conversationViewItem: viewItem, delegate: self)
        }
        let menuVC = ConversationActionMenuController(
            actions: actions,
            emojiAction: emojiAction,
            sourceView: sourceView,
            sourceViewController: self,
            textSelectionView: textSelectionView
        )
        menuVC.dismissHandler = { [weak self] in
            bubbleView.textDelegate = nil
            bubbleView.textViewCancelSelect()
            
            guard let self else { return }
            self.actionMenuController = nil
        }
        menuVC.isSelectedAll = true
        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.modalTransitionStyle = .crossDissolve
        navigationController?.present(menuVC, animated: true)
        
        actionMenuController = menuVC
    }
}

// MARK: - MessageActionsDelegate

extension ConversationViewController: MessageActionsDelegate {
    /// 更多信息
    func messageActionsShowDetailsForItem(_ conversationViewItem: ConversationViewItem) {
        AssertIsOnMainThread()
        owsAssertDebug(conversationViewItem.interaction.isKind(of: TSMessage.self))
        
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }
        let detailVC = MessageDetailViewController(
            viewItem: conversationViewItem,
            message: message,
            thread: self.thread,
            mode: .focusOnMetadata
        )
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    /// 引用
    func messageActionsQuoteToItem(_ conversationViewItem: ConversationViewItem) {
        OWSLogger.debug("user did tap quote")
        
        if conversationViewItem.isConfidentialMessage {
            return
        }
        
        var quotedReply: OWSQuotedReplyModel?
        databaseStorage.uiRead { transaction in
            quotedReply = OWSQuotedReplyModel(for: conversationViewItem, transaction: transaction)
            if let quotedReply {
                quotedReply.authorName = self.contactsManager.displayName(
                    forPhoneIdentifier: quotedReply.authorId,
                    transaction: transaction
                )
            }
        }
        
        guard let quotedReply, quotedReply.isKind(of: OWSQuotedReplyModel.self) else {
            owsFailDebug("unexpected quotedMessage: \(type(of: quotedReply))")
            return
        }
        quotedReply.viewMode = self.conversationViewModel.conversationMode.rawValue
        quotedReply.inputPreviewType = .quote
        quotedReply.replyItem = conversationViewItem
        
        self.inputToolbar.quotedReplyDraft = quotedReply
        self.inputToolbar.beginEditingMessage()
    }
    
    /// 转发
    func messageActionsForwardItem(_ conversationViewItem: ConversationViewItem) {
        forwardSingleMessage(conversationViewItem)
    }
    
    /// 撤回
    func messageActionsRecallItem(_ conversationViewItem: ConversationViewItem) {
        guard isCanSpeak else {
            return
        }
        guard let originalMessage = conversationViewItem.interaction as? TSOutgoingMessage else {
            OWSLogger.error("origionMessage is not TSOutgoingMessage -- \(type(of: conversationViewItem.interaction))")
            return
        }
        
        // 检查消息是否超过了可撤回的时间
        func checkIfTimeout() -> Bool {
            let timeoutInterval = DTRecallConfig.fetch().timeoutInterval
            let messageDuration = Double(Date.ows_millisecondTimestamp() - conversationViewItem.interaction.timestamp)
            if messageDuration <= (timeoutInterval * 1000) {
                return false
            }
            
            let title = String(format: Localized("RECALL_PASSED_TIME"), DateUtil.formatToMinuteHourDayWeek(withTimeInterval: timeoutInterval))
            let alertController = UIAlertController(
                title: title,
                message: nil,
                preferredStyle: .alert
            )
            alertController.addAction(OWSAlerts.doneAction)
            present(alertController, animated: true)
            return true
        }
        
        if checkIfTimeout() {
            return
        }
        
        let actionSheetController = ActionSheetController(title: Localized("RECALL_CONFIRM_TITLE"))
        actionSheetController.addAction(OWSActionSheets.cancelAction)
        
        let recallAction = ActionSheetAction(title: Localized("OK"), style: .destructive) { [weak self] action in
            guard let self else { return }
            if checkIfTimeout() {
                return
            }
            SVProgressHUD.show()
            ThreadUtil.sendRecallMessage(withOriginMessage: originalMessage, in: self.thread) {
                DispatchMainThreadSafe {
                    SVProgressHUD.dismiss()
                }
            } failure: { error in
                DispatchMainThreadSafe {
                    SVProgressHUD.dismiss()
                    DTToastHelper.toast(
                        withText: Localized("MESSAGE_STATUS_FAILED", "Sent"),
                        durationTime: 2
                    )
                }
            }
        }
        actionSheetController.addAction(recallAction)
        presentActionSheet(actionSheetController)
    }
    
    /// 转发至备忘录
    func messageActionsForwardItemToNote(_ conversationViewItem: ConversationViewItem) {
        forwardSingleMessageToNote(conversationViewItem)
    }
    
    /// 多选
    func messageActionsMultiSelectItem(_ conversationViewItem: ConversationViewItem) {
        enterMultiSelectMode(viewItem: conversationViewItem)
    }
    
    /// 翻译
    func messageActionsTranslateForItem(_ conversationViewItem: ConversationViewItem) {
        showTranslateLanguageAlert(conversationViewItem: conversationViewItem)
    }
    
    /// 关闭翻译，展示原文
    func messageActionsOriginalTranslateForItem(_ conversationViewItem: ConversationViewItem) {
        showOriginalLanguage(conversationViewItem: conversationViewItem)
    }
    
    /// pin 或 unpin
    func messageActionsPinItem(_ conversationViewItem: ConversationViewItem) {
        pinOrUnpinMessage(viewItem: conversationViewItem)
    }
    
    /// 删除
    func messageActionDeleteItem(_ conversationViewItem: ConversationViewItem) {
        let actionSheet = ActionSheetController(message: Localized("MESSAGE_ACTION_DELETE_MESSAGE_TIPS"))
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let confirmAction = ActionSheetAction(
            title: Localized("MESSAGE_ACTION_DELETE_MESSAGE_OK"),
            style: .destructive
        ) { action in
            conversationViewItem.deleteAction()
        }
        actionSheet.addAction(confirmAction)
        
        presentActionSheet(actionSheet)
    }
    
    /// 表情
    func messageEmojiReactionItem(_ conversationViewItem: ConversationViewItem, emoji: String) {
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }
        let selectedEmojiArray = DTReactionHelper.selectedEmojis(message)
        let isNeedRemove = selectedEmojiArray.contains(emoji)
      
        if !isNeedRemove {
            //MARK: 保存上次选择的emoji
            DTReactionHelper.shared.storeRecentlyUsed(emoji: emoji)
        }
        
        _ = ThreadUtil.sendReactionMessage(
            withEmoji: emoji,
            remove: isNeedRemove,
            targetMessage: message,
            in: self.thread,
            success: {},
            failure: { _ in }
        )
    }
}

// MARK: - MenuActionsViewControllerDelegate

extension ConversationViewController: MenuActionsViewControllerDelegate {
    /// 关闭 message actions 弹窗
    func menuActionsDidHide(_ menuActionsViewController: MenuActionsViewController) {
        
    }
}

// MARK: - ConversationMessageBubbleViewTextDelegate

extension ConversationViewController: ConversationMessageBubbleViewTextDelegate {
    var selectThreadTool: SelectThreadTool? {
        get { viewState.selectThreadTool }
        set { viewState.selectThreadTool = newValue }
    }
    
    func bubbleViewDidSingleTapSelectionView(_ bubbleView: ConversationMessageBubbleView) {
        bubbleView.textDelegate = nil
        bubbleView.textViewCancelSelect()
        actionMenuController?.dismiss(animated: true) {
            self.actionMenuController = nil
        }
    }
    
    func bubbleViewDidBeginSelectText(_ bubbleView: ConversationMessageBubbleView) {
        actionMenuController?.hideMenu(animation: false)
    }
    
    func bubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didEndSelectTextWith textView: UITextView,
        selectionView: DTTextSelectionView,
        viewItem: ConversationViewItem
    ) {
        guard let actionMenuController, let actionMessageType else {
            return
        }
        
        guard let currentRange = selectionView.getSelection(), currentRange.length > 0 else {
            bubbleView.textDelegate = nil
            bubbleView.textViewCancelSelect()
            actionMenuController.dismiss(animated: true) {
                self.actionMenuController = nil
            }
            return
        }
        
        // 避免不必要的更新
        let isSelectedAll = currentRange.length == textView.attributedText.length
        guard actionMenuController.isSelectedAll != isSelectedAll else {
            actionMenuController.showMenu(animation: true)
            return
        }
        actionMenuController.isSelectedAll = isSelectedAll
        
        var actions: [MenuAction] = []
        var emojiAction: MenuEmojiAction? = nil
        if isSelectedAll {
            actions = actionMessageType.messageActions(viewItem: viewItem, delegate: self)
            if viewItem.allowEmojiReaction() {
                emojiAction = ConversationViewItemActions.emojiReaction(conversationViewItem: viewItem, delegate: self)
            }
        } else {
            let copyAction = MenuAction(
                image: #imageLiteral(resourceName: "ic_longpress_copy"),
                title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: "Action sheet button title"),
                subtitle: nil,
                block: { _ in
                    if let selectedRange = selectionView.getSelection() {
                        let selectedString = textView.text.substring(withRange: selectedRange)
                        UIPasteboard.general.string = selectedString
                    }
                }
            )
            let forwardAction = MenuAction(
                image: #imageLiteral(resourceName: "ic_forward"),
                title: Localized("MESSAGE_ACTION_FORWARD", comment: "Action sheet button title"),
                subtitle: nil,
                block: { [weak self] _ in
                    guard let self else { return }
                    if let selectedRange = selectionView.getSelection() {
                        let selectedString = textView.text.substring(withRange: selectedRange)
                        self.forward(text: selectedString)
                    }
                }
            )
            let selectAllAction = MenuAction(
                image: #imageLiteral(resourceName: "ic_select_all"),
                title: Localized("MESSAGE_ACTION_SELECT_ALL", comment: "Action sheet button title"),
                subtitle: nil,
                dismissBeforePerformAction: false,
                block: { [weak self] _ in
                    guard let self, let menuVC = self.actionMenuController else { return }
                    
                    selectionView.selectAll(animated: true)
                    
                    let newActions = actionMessageType.messageActions(viewItem: viewItem, delegate: self)
                    var newEmojiAction: MenuEmojiAction? = nil
                    if viewItem.allowEmojiReaction() {
                        newEmojiAction = ConversationViewItemActions.emojiReaction(conversationViewItem: viewItem, delegate: self)
                    }
                    menuVC.update(actions: newActions, emojiAction: newEmojiAction)
                    menuVC.isSelectedAll = true
                }
            )
            actions = [copyAction, forwardAction, selectAllAction]
        }
        
        actionMenuController.update(actions: actions, emojiAction: emojiAction)
        actionMenuController.showMenu(animation: true)
    }
    
    private func forward(text: String) {
        guard !text.isEmpty else { return }
        
        let tool = SelectThreadTool()
        tool.isCanSelectThread = { thread in
            return TSThreadPermissionHelper.checkCanSpeakAndToastTipMessage(thread)
        }
        tool.didSelectedThreads = { threads in
            threads.forEach {
                _ = ThreadUtil.sendMessage(
                    withText: text,
                    atPersons: nil,
                    mentions: nil,
                    in: $0,
                    quotedReplyModel: nil,
                    messageSender: SSKEnvironment.shared.messageSenderRef,
                    success: {},
                    failure: { _ in }
                )
            }
        }
        tool.dismissHander = {
            DTToastHelper.toast(
                withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", "Sent"),
                durationTime: 1.5
            )
        }
        tool.showSelectThreadViewController(source: self)
        
        // 防止 SelectThreadTool 被释放，block 不会执行
        selectThreadTool = tool
    }
}

// MARK: - Private

private extension ConversationMessageType {
    func messageActions(viewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        switch self {
        case .text:
            return ConversationViewItemActions.textActions(conversationViewItem: viewItem, delegate: delegate)
        case .media:
            return ConversationViewItemActions.mediaActions(conversationViewItem: viewItem, delegate: delegate)
        case .quoted:
            return ConversationViewItemActions.quotedMessageActions(conversationViewItem: viewItem, delegate: delegate)
        case .combinedForwarding:
            return ConversationViewItemActions.combinedForwardingMessageActions(conversationViewItem: viewItem, delegate: delegate)
        case .contactShare:
            return ConversationViewItemActions.contactShareMessageActions(conversationViewItem: viewItem, delegate: delegate)
        case .task:
            return ConversationViewItemActions.taskMessageActions(conversationViewItem: viewItem, delegate: delegate)
        case .vote:
            return ConversationViewItemActions.voteMessageActions(conversationViewItem: viewItem, delegate: delegate)
        case .card:
            return ConversationViewItemActions.cardActions(conversationViewItem: viewItem, delegate: delegate)
        case .info:
            return ConversationViewItemActions.infoMessageActions(conversationViewItem: viewItem, delegate: delegate)
        }
    }
    
    func confidentialActions(viewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        return ConversationViewItemActions.confidentialActions(conversationViewItem: viewItem, delegate: delegate)
    }
}
