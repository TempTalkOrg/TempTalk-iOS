//
//  DTCombinedMessageController.swift
//  Wea
//
//  Created by Ethan on 2022/3/15.
//

import UIKit
import PanModal

class DTCombinedMessageController: DTMessageListController {

    var currentCombinedMessage: TSMessage?

    var targetThreads: [TSThread]?

    var subForwardingMessages: [DTCombinedForwardingMessage]?

    var lbTitle: UILabel?

    // Store the message being forwarded
    private var forwardingMessage: TSMessage?

    // Store the text being forwarded (for partial text selection)
    private var forwardingText: String?

    // Store the inner item the forwarded text was selected from, so the trace can
    // attribute to that inner item's author (the text itself carries no source info).
    private var forwardingTextSourceMessage: TSMessage?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // PanModal 模式下不显示右侧按钮
        // navigationItem.rightBarButtonItem = nil

        // 设置背景图，和 ConversationViewController 保持一致
        setupBackgroundView()

        // 机密合并转发消息阅后即焚：查看时立即删除消息
        if let message = self.currentCombinedMessage as? TSIncomingMessage, message.messageModeType == .confidential {
            OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(message)
            self.databaseStorage.asyncWrite { wTransaction in
                message.anyRemove(transaction: wTransaction)
            }
        }
    }
    
    func selectMultiForwardTypeAction() {
        
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
        self.present(selectThreadNav, animated: true, completion: nil)
    }
    
    func createNavigationTitle(_ title: String) {
        // 在 PanModal 模式下，使用左对齐的标题
        let label = UILabel()
        label.text = title
        label.numberOfLines = 2
        label.textAlignment = .left
        label.font = .ows_monospacedDigitFont(withSize: 17)
        label.textColor = Theme.tprimaryColor
        label.preferredMaxLayoutWidth = UIScreen.main.bounds.size.width - 40

        lbTitle = label
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: label)
    }
    
    override func applyTheme() {
        super.applyTheme()
        lbTitle?.textColor = Theme.tprimaryColor
        // 主题切换时也更新背景
        setupBackgroundView()
    }

    // MARK: - Background Setup

    private func setupBackgroundView() {
        // 清除已有的背景视图
        collectionView.backgroundView = nil
        if let backgroundImage = UIImage(named: "conversation_background") {
            let backgroundImageView = UIImageView(image: backgroundImage)
            backgroundImageView.contentMode = .scaleAspectFill
            collectionView.backgroundView = backgroundImageView
        } else {
            Logger.warn("Warning: Background image 'conversation_background' not found!")
        }
    }

//    override func uiDatabaseWillUpdate(noti: Notification) {}
 
//    override func uiDatabaseDidupdate(noti: Notification) {}
    
    func configure(thread: TSThread, combinedMessage: TSMessage, isGroupChat: Bool) {
        owsAssertDebug(combinedMessage.combinedForwardingMessage != nil)
        
        currentThread = thread
        currentCombinedMessage = combinedMessage
        conversationStyle = ConversationStyle(thread: thread)
        conversationStyle?.viewWidth = view.width
        
        createNavigationTitle(DTForwardMessageHelper.combinedForwardingMessageTitle(withIsGroupThread: isGroupChat, combinedMessage: combinedMessage))
        
        subForwardingMessages = combinedMessage.combinedForwardingMessage?.subForwardingMessages

        kMessages.removeAll()
        subForwardingMessages?.forEach({ subForwardingMessage in
            if let incomingMessage = self.transitionCombinedSubMessage(subMessage: subForwardingMessage) {
                kMessages.append(incomingMessage)
            }
        })
        
        self.reloadViewItems()
        
        self.collectionView.layoutIfNeeded()
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
        
        guard let subForwardingMessages = subForwardingMessages else {
            return
        }
        self.databaseStorage.write { transaction in
            subForwardingMessages.forEach { subForwardingMessage in
                subForwardingMessage.handleForwardingAttachments(withOrigionMessage: combinedMessage, transaction: transaction)
            }
        }
    
    }
    
    func transitionCombinedSubMessage(subMessage: DTCombinedForwardingMessage?) -> TSIncomingMessage? {
        owsAssertDebug(subMessage != nil)

        guard let subMessage = subMessage else {
            return nil
        }
        
        var forwardingMessage: DTCombinedForwardingMessage?
        if  subMessage.subForwardingMessages.count > 0 {
            forwardingMessage = subMessage
        } else {
            forwardingMessage = nil
        }
        let incomingMessage = TSIncomingMessage(incomingMessageWithTimestamp: subMessage.timestamp, serverTimestamp: subMessage.serverTimestamp, sequenceId:0, notifySequenceId:0, in: currentThread, authorId:subMessage.authorId, sourceDeviceId: 0, messageBody: subMessage.body, atPersons: nil, mentions: nil, attachmentIds: subMessage.forwardingAttachmentIds, expiresInSeconds: OWSDisappearingMessagesConfiguration.maxDurationSeconds(), quotedMessage: nil, forwardingMessage: forwardingMessage, contactShare: nil)
        if let currentMessage = self.currentCombinedMessage {
            incomingMessage.uniqueId = "\(currentMessage.timestamp)" + "\(subMessage.timestamp)"
            incomingMessage.isPinnedMessage = currentMessage.isPinnedMessage
        }
        if let card = subMessage.card {
            incomingMessage.card = card
        }
        if let mentions = subMessage.forwardingMentions, mentions.count > 0 {
            incomingMessage.setValue(mentions, forKey: "mentions")
        }
        
        return incomingMessage
    }
    
    override func conversationViewItem(from message: TSMessage) -> ConversationViewItem? {

        var item: ConversationViewItem?
        self.databaseStorage.read { transaction in
            let style: ConversationStyle
            if let conversationStyle = self.conversationStyle {
                style = conversationStyle
            } else if let currentThread = self.currentThread {
                style = ConversationStyle(thread: currentThread)
            } else {
                owsFailDebug("Both conversationStyle and currentThread are nil")
                return
            }
            item = ConversationInteractionViewItem(sepcialInteraction: message, thread: nil, transaction: transaction, conversationStyle: style)
        }
        return item
    }
    
    override func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedAttachmentWith viewItem: any ConversationViewItem,
        autoRestart: Bool,
        attachmentPointer: TSAttachmentPointer
    ) {
        owsAssertDebug(Thread.isMainThread)
        guard viewItem.interaction is TSMessage else {
            return
        }
        
        if autoRestart == true {
            
            guard !attachmentDownloadFlag.contains(viewItem.interaction.timestamp) else {
                return
            }
            attachmentDownloadFlag.append(viewItem.interaction.timestamp)
            let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
            processor.fetchAttachments(for: self.currentCombinedMessage, forceDownload: false) { attachmentStream in
                OWSLogger.info("Successfully redownloaded attachment")
            } failure: { error in
                OWSLogger.warn("Failed to redownload message with error:\(error.localizedDescription)")
            }
        } else {
            //        var title: String?
            let retryActionText: String
            if (attachmentPointer.state == .enqueued) {
                retryActionText = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTION", comment: "Action sheet button text")
            } else {
                //            title = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTIONSHEET_TITLE", comment: "Action sheet title after tapping on failed download.")
                retryActionText = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_RETRY_ACTION", comment: "Action sheet button text")
            }

            let actionSheet = ActionSheetController(title: nil, message: nil)
            actionSheet.addAction(OWSActionSheets.cancelAction)

            let retryAction = ActionSheetAction(title: retryActionText, style: .default) { _ in
                let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
                processor.fetchAttachments(for: self.currentCombinedMessage, forceDownload: true) { attachmentStream in
                    OWSLogger.info("Successfully redownloaded attachment")
                } failure: { error in
                    OWSLogger.warn("Failed to redownload message with error:\(error.localizedDescription)")
                }
            }
            actionSheet.addAction(retryAction)
            presentActionSheet(actionSheet)
        }
    }

    /// Copy of an INNER item inside the Chat History detail view. The trace DECISION uses the
    /// inner item's own author (PRD §B), but the "from" display uses the outer Chat History
    /// bubble sender (PRD: CH's from = the combined-forward bubble sender, not inner authors).
    func sendCopyNoticeFromCombinedForwardDetail(thread: TSThread, sourceMessage: TSMessage) {
        let displayAuthorIds = currentCombinedMessage.map { CopyNoticeDispatcher.sourceAuthorIds(for: [$0]) } ?? []
        let triggerAuthorIds = CopyNoticeDispatcher.triggerAuthorIds(for: [sourceMessage])
        guard DTNoticeTraceEvaluator.shouldLeaveTrace(
            sourceThread: thread,
            targetThreads: nil,
            contentAuthorIds: triggerAuthorIds
        ) else { return }
        let fromAuthorIds = DTNoticeTraceEvaluator.orderForDisplay(displayAuthorIds)
        CopyNoticeDispatcher.sendNotice(
            sourceConversation: thread,
            sourceAuthorIds: fromAuthorIds,
            messageCount: 1,
            combinedForwardMode: .subCombinedForward
        )
    }

    /// Forward of INNER content inside the Chat History detail view. Attribute the trace to
    /// the inner content's author (the original content author), not the outer forwarder.
    /// `sourceMessage` is the resolved inner author source (text's origin item / single inner
    /// message / whole CH message); it must be captured BEFORE the async send clears state.
    func sendForwardNoticeFromCombinedForwardDetail(
        thread: TSThread,
        targetThreads: [TSThread],
        messageCount: UInt32,
        sourceMessage: TSMessage?
    ) {
        guard let sourceMessage else { return }
        // The trace DECISION recurses the inner content's original authors (PRD §B), but the
        // "from" display uses the outer Chat History bubble sender (PRD: CH's from = the
        // combined-forward bubble sender, not inner authors).
        let displayAuthorIds = currentCombinedMessage.map { ForwardNoticeBuilder.sourceAuthorIds(for: [$0]) } ?? []
        let triggerAuthorIds = ForwardNoticeBuilder.triggerAuthorIds(for: [sourceMessage])
        guard DTNoticeTraceEvaluator.shouldLeaveTrace(
            sourceThread: thread,
            targetThreads: targetThreads,
            contentAuthorIds: triggerAuthorIds
        ) else { return }
        let fromAuthorIds = DTNoticeTraceEvaluator.orderForDisplay(displayAuthorIds)
        Task {
            do {
                try await ForwardNoticeDispatcher.sendNotice(
                    sourceConversation: thread,
                    scene: messageCount <= 1 ? .single : .oneByOne,
                    sourceAuthorIds: fromAuthorIds,
                    messageCount: messageCount,
                    messageSender: SSKEnvironment.shared.messageSenderRef,
                    combinedForwardMode: .subCombinedForward
                )
            } catch {
                Logger.error("[ForwardNotice] combined forward detail notice failed: \(error)")
            }
        }
    }
}

extension DTCombinedMessageController: SelectThreadViewControllerDelegate {
    
    func threadsWasSelected(_ threads: [TSThread]) {
        
        owsAssertDebug(threads.count > 0)
        self.targetThreads = threads
        
        let previewVC = DTForwardPreviewViewController()
        previewVC.modalPresentationStyle = .overFullScreen
        previewVC.delegate = self
        self.presentedViewController?.present(previewVC, animated: false, completion: nil)
    }
    
    func canSelectBlockedContact() -> Bool {
        
        false
    }
    
}

extension DTCombinedMessageController: DTForwardPreviewDelegate {
    func getThreadsToForwarding() -> [TSThread] {
        return self.targetThreads ?? []
    }
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {

        guard let messageSender = Environment.shared?.messageSender else {
            OWSLogger.error("messageSender is nil")
            return
        }

        guard let targetThreads = self.targetThreads, !targetThreads.isEmpty else {
            OWSLogger.error("targetThreads is nil or empty")
            return
        }

        // Resolve the inner author source BEFORE the async send clears forwardingText /
        // forwardingMessage. Text path -> the item the text was selected from; single message
        // path -> that inner message; whole CH path -> the combined message (recurses).
        let noticeSourceMessage: TSMessage?
        if self.forwardingText != nil {
            noticeSourceMessage = self.forwardingTextSourceMessage
        } else if let forwardingMessage = self.forwardingMessage {
            noticeSourceMessage = forwardingMessage
        } else {
            noticeSourceMessage = self.currentCombinedMessage
        }

        // Check what we're forwarding: text, single message, or entire combined message
        if let forwardingText = self.forwardingText {
            // Forward selected text (without source info)
            DispatchQueue.global().async {
                targetThreads.forEach { targetThread in
                    DispatchQueue.main.sync {
                        _ = ThreadUtil.sendMessage(
                            withText: forwardingText,
                            atPersons: nil,
                            mentions: nil,
                            in: targetThread,
                            quotedReplyModel: nil,
                            messageSender: messageSender,
                            success: {},
                            failure: { _ in }
                        )
                    }
                    Thread.sleep(forTimeInterval: 0.05)

                    guard let leaveMsg = leaveMessage?.ows_stripped(), !leaveMsg.isEmpty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        _ = ThreadUtil.sendMessage(
                            withText: leaveMsg,
                            atPersons: nil,
                            mentions: nil,
                            in: targetThread,
                            quotedReplyModel: nil,
                            messageSender: messageSender,
                            success: {},
                            failure: { _ in }
                        )
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }

                // Clear the forwarding text after async operation completes
                DispatchQueue.main.async {
                    self.forwardingText = nil
                    self.forwardingTextSourceMessage = nil
                }
            }
        } else if let forwardingMessage = self.forwardingMessage {
            // Forward single message
            DispatchQueue.global().async {
                targetThreads.forEach { targetThread in
                    DispatchQueue.main.sync {
                        DTForwardMessageHelper.forwardMessageIs(
                            fromGroup: self.currentThread?.isGroupThread() ?? false,
                            targetThread: targetThread,
                            messages: [forwardingMessage],
                            success: nil,
                            failure: nil
                        )
                    }
                    Thread.sleep(forTimeInterval: 0.05)

                    guard let leaveMsg = leaveMessage?.ows_stripped(), !leaveMsg.isEmpty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        _ = ThreadUtil.sendMessage(withText: leaveMsg, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender)
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }

                // Clear the forwarding message after async operation completes
                DispatchQueue.main.async {
                    self.forwardingMessage = nil
                }
            }
        } else {
            // Forward entire combined message (existing behavior)
            DispatchQueue.global().async {
                targetThreads.forEach { targetThread in
                    var combinedForwardingMessage_: DTCombinedForwardingMessage?

                    DispatchQueue.main.sync {
                        self.databaseStorage.write { transaction in
                            guard let cfm = self.currentCombinedMessage?.combinedForwardingMessage,
                                  let combinedForwardingMessage = DTCombinedForwardingMessage.buildSingleForwardingMessage(with: cfm, transaction: transaction) else {
                                owsFailDebug("combinedForwardingMessage is empty")
                                return
                            }
                            combinedForwardingMessage_ = combinedForwardingMessage
                        }
                    }

                    guard let message = combinedForwardingMessage_ else {
                        OWSLogger.error("Failed to build combined forwarding message")
                        return
                    }

                    DispatchQueue.main.sync {
                        ThreadUtil.sendMessage(with: message, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender)
                    }
                    Thread.sleep(forTimeInterval: 0.05)

                    guard let leaveMsg = leaveMessage?.ows_stripped(), !leaveMsg.isEmpty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        ThreadUtil.sendMessage(withText: leaveMsg, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender)
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }

        // 发送转发留痕（Chat History 详情视图内转发）
        if let thread = self.currentThread {
            sendForwardNoticeFromCombinedForwardDetail(
                thread: thread,
                targetThreads: targetThreads,
                messageCount: 1,
                sourceMessage: noticeSourceMessage
            )
        }

        self.dismiss(animated: true) {
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: "Sent"), durationTime: 1.5)
        }

    }
    
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        // If forwarding selected text, show the text
        if let forwardingText = self.forwardingText {
            return forwardingText
        }
        // If forwarding a specific message, show its content
        if let forwardingMessage = self.forwardingMessage {
            if let messageBody = forwardingMessage.body, !messageBody.isEmpty {
                return messageBody
            }
            // Fallback for messages without body
            return "[\(Localized("FORWARD_MESSAGE_CHAT_HISTORY", comment: ""))]"
        }
        // Otherwise show combined message indicator
        return "[\(Localized("FORWARD_MESSAGE_CHAT_HISTORY", comment: ""))]"
    }

}

// MARK: - Action Menu

extension DTCombinedMessageController {
    private var actionMessageType: ConversationMessageType? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.actionMessageType) as? ConversationMessageType }
        set { objc_setAssociatedObject(self, &AssociatedKeys.actionMessageType, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var actionMenuController: ConversationActionMenuController? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.actionMenuController) as? ConversationActionMenuController }
        set { objc_setAssociatedObject(self, &AssociatedKeys.actionMenuController, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func handleActionMenu(
        messageType: ConversationMessageType,
        viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        // Confidential Chat History is view-only: forbid copy / forward of the whole
        // inner item AND of selected text. The inner items are rebuilt as plain
        // TSIncomingMessages (no confidential flag), so gate on the outer combined
        // message's confidential state. Returning here means no menu is presented and
        // text selection is never armed.
        if currentCombinedMessage?.isConfidentialMessage() == true { return }

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

        // 创建 Copy 和 Forward 按钮
        let copyAction = MenuAction(
            image: #imageLiteral(resourceName: "ic_longpress_copy"),
            title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: "Action sheet button title"),
            subtitle: nil,
            block: { [weak self] _ in
                guard let self else { return }
                if let message = viewItem.interaction as? TSMessage,
                   let messageBody = message.body, !messageBody.isEmpty {
                    DTSecurePasteboard.setString(messageBody)
                    DTToastHelper.show(withInfo: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""))
                    if let thread = self.currentThread {
                        self.sendCopyNoticeFromCombinedForwardDetail(thread: thread, sourceMessage: message)
                    }
                }
            }
        )

        let forwardAction = MenuAction(
            image: #imageLiteral(resourceName: "ic_forward"),
            title: Localized("MESSAGE_ACTION_FORWARD", comment: "Action sheet button title"),
            subtitle: nil,
            block: { [weak self] _ in
                guard let self else { return }
                self.messageActionsForwardItem(viewItem)
            }
        )

        // A nested Chat History item doesn't support copy — keep it consistent with the
        // outer level (forward only, no copy).
        let isNestedChatHistory = (viewItem.interaction as? TSMessage)?.combinedForwardingMessage != nil
        var actions: [MenuAction] = isNestedChatHistory ? [forwardAction] : [copyAction, forwardAction]

        // Animated images (GIF/animated-WebP/APNG) can be saved to favorites, same as the main conversation.
        if let stream = viewItem.attachmentStream(), stream.isAnimatedImageAttachment {
            actions.append(MenuActionBuilder.addToFavorite(conversationViewItem: viewItem, delegate: self))
        }

        // 不显示 emoji reaction
        let emojiAction: MenuEmojiAction? = nil

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
        // 关键修改：初始时文本已自动全选，所以标记为 true（不显示 Select All 按钮）
        menuVC.isSelectedAll = true
        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.modalTransitionStyle = .crossDissolve
        navigationController?.present(menuVC, animated: true)

        actionMenuController = menuVC
    }
}

// MARK: - AssociatedKeys

private struct AssociatedKeys {
    static var actionMessageType = "actionMessageType"
    static var actionMenuController = "actionMenuController"
}

// MARK: - Override ConversationMessageCellDelegate

extension DTCombinedMessageController {
    override func messageCell(
        _ cell: ConversationMessageCell,
        didLongPressBubbleViewWith messageType: ConversationMessageType,
        viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        handleActionMenu(messageType: messageType, viewItem: viewItem, bubbleView: bubbleView)
    }
}

// MARK: - ConversationMessageBubbleViewTextDelegate

extension DTCombinedMessageController: ConversationMessageBubbleViewTextDelegate {
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

        // 检查是否全选
        let isSelectedAll = currentRange.length == textView.attributedText.length

        // 避免不必要的更新
        guard actionMenuController.isSelectedAll != isSelectedAll else {
            actionMenuController.showMenu(animation: true)
            return
        }
        actionMenuController.isSelectedAll = isSelectedAll

        // 根据是否全选，动态生成菜单按钮
        var actions: [MenuAction] = []

        // Copy 按钮（始终显示）
        let copyAction = MenuAction(
            image: #imageLiteral(resourceName: "ic_longpress_copy"),
            title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: "Action sheet button title"),
            subtitle: nil,
            block: { [weak self] _ in
                guard let self else { return }
                if let selectedRange = selectionView.getSelection(), selectedRange.length > 0 {
                    let selectedString = textView.text.substring(withRange: selectedRange)
                    DTSecurePasteboard.setString(selectedString)
                    DTToastHelper.show(withInfo: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""))
                    if let thread = self.currentThread,
                       let sourceMessage = viewItem.interaction as? TSMessage {
                        self.sendCopyNoticeFromCombinedForwardDetail(thread: thread, sourceMessage: sourceMessage)
                    }
                }
            }
        )
        actions.append(copyAction)

        // Forward 按钮（始终显示）
        let forwardAction = MenuAction(
            image: #imageLiteral(resourceName: "ic_forward"),
            title: Localized("MESSAGE_ACTION_FORWARD", comment: "Action sheet button title"),
            subtitle: nil,
            block: { [weak self] _ in
                guard let self else { return }
                if let selectedRange = selectionView.getSelection() {
                    let selectedString = textView.text.substring(withRange: selectedRange)
                    // 转发选中的文本（不添加来源信息），但留痕归属到该内层条目作者
                    self.forwardSelectedText(selectedString, sourceMessage: viewItem.interaction as? TSMessage)
                }
            }
        )
        actions.append(forwardAction)

        // 如果不是全选，添加 Select All 按钮
        if !isSelectedAll {
            let selectAllAction = MenuAction(
                image: #imageLiteral(resourceName: "ic_select_all"),
                title: Localized("MESSAGE_ACTION_SELECT_ALL", comment: "Action sheet button title"),
                subtitle: nil,
                dismissBeforePerformAction: false,
                block: { [weak self] _ in
                    guard let self else { return }

                    selectionView.selectAll(animated: true)

                    // 更新菜单为全选时的菜单项
                    var newActions: [MenuAction] = []

                    // Copy 按钮
                    let copyAction = MenuAction(
                        image: #imageLiteral(resourceName: "ic_longpress_copy"),
                        title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: "Action sheet button title"),
                        subtitle: nil,
                        block: { [weak self] _ in
                            guard let self else { return }
                            if let selectedRange = selectionView.getSelection(), selectedRange.length > 0 {
                                let selectedString = textView.text.substring(withRange: selectedRange)
                                DTSecurePasteboard.setString(selectedString)
                                DTToastHelper.show(withInfo: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""))
                                if let thread = self.currentThread,
                                   let sourceMessage = viewItem.interaction as? TSMessage {
                                    self.sendCopyNoticeFromCombinedForwardDetail(thread: thread, sourceMessage: sourceMessage)
                                }
                            }
                        }
                    )
                    newActions.append(copyAction)

                    // Forward 按钮
                    let forwardAction = MenuAction(
                        image: #imageLiteral(resourceName: "ic_forward"),
                        title: Localized("MESSAGE_ACTION_FORWARD", comment: "Action sheet button title"),
                        subtitle: nil,
                        block: { [weak self] _ in
                            guard let self else { return }
                            self.messageActionsForwardItem(viewItem)
                        }
                    )
                    newActions.append(forwardAction)

                    actionMenuController.update(actions: newActions, emojiAction: nil)
                    actionMenuController.isSelectedAll = true
                }
            )
            actions.append(selectAllAction)
        }

        actionMenuController.update(actions: actions, emojiAction: nil)
        actionMenuController.showMenu(animation: true)
    }

    // 转发选中的文本
    private func forwardSelectedText(_ text: String, sourceMessage: TSMessage?) {
        guard !text.isEmpty else { return }

        // Store the text to be forwarded (without source info)
        self.forwardingText = text
        // Capture the inner item the text was selected from for trace attribution.
        self.forwardingTextSourceMessage = sourceMessage

        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
        self.present(selectThreadNav, animated: true, completion: nil)
    }
}

// MARK: - MessageActionsDelegate

extension DTCombinedMessageController: MessageActionsDelegate {
    func messageActionsShowDetailsForItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持查看详情
    }

    func messageActionsQuoteToItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持引用
    }

    func messageActionsForwardItem(_ conversationViewItem: ConversationViewItem) {
        // 转发整条消息
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }

        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        // 这里可以设置要转发的消息
        // 注意：需要查看 SelectThreadViewController 如何接收消息对象
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)

        // 临时存储要转发的消息
        self.forwardingMessage = message

        self.present(selectThreadNav, animated: true, completion: nil)
    }

    func messageActionsRecallItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持撤回
    }

    func messageActionsForwardItemToNote(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持转发到备忘录
    }

    func messageActionsAddToFavorite(_ conversationViewItem: ConversationViewItem) {
        DTGifFavoriteMessageAction.addToFavorite(conversationViewItem, presenter: self)
    }

    func messageActionsMultiSelectItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持多选
    }

    func messageActionsTranslateForItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持翻译
    }

    func messageActionsOriginalTranslateForItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持翻译
    }

    func messageActionDeleteItem(_ conversationViewItem: ConversationViewItem) {
        // Combined message controller 中不支持删除
    }

    func messageEmojiReactionItem(_ conversationViewItem: ConversationViewItem, emoji: String) {
        // Combined message controller 中不支持 emoji reaction
    }
}

// MARK: - PanModalPresentable
extension DTCombinedMessageController: PanModalPresentable {

    var panScrollable: UIScrollView? {
        return collectionView
    }

    var shortFormHeight: PanModalHeight {
        return .contentHeight(screenHeight * 0.5)
    }

    var longFormHeight: PanModalHeight {
        return .contentHeight(screenHeight * 0.75)
    }

    var anchorModalToLongForm: Bool {
        return false
    }

    var shouldRoundTopCorners: Bool {
        return true
    }

    var cornerRadius: CGFloat {
        return 16.0
    }

    var showDragIndicator: Bool {
        return true
    }
}
