//
//  ConversationViewController+CellDelegate.swift
//  Signal
//
//  Created by Jaymin on 2024/1/26.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging
import TTServiceKit
import SVProgressHUD

// MARK: - ConversationMessageCellDelegate

extension ConversationViewController: ConversationMessageCellDelegate {
    func mediaCache(for cell: ConversationMessageCell) -> NSCache<AnyObject, AnyObject> {
        self.cellMediaCache
    }
    
    func contactsManager(for cell: ConversationMessageCell) -> OWSContactsManager {
        self.contactsManager
    }
    
    func messageCell(_ cell: ConversationMessageCell, didTapAvatarWith recipientId: String) {
        showPersonalInfoCard(recipientId: recipientId)
    }
    
    func messageCell(_ cell: ConversationMessageCell, didLongPressAvatarWith recipientId: String, senderName: String?) {
        owsAssertDebug(!recipientId.isEmpty)
        
        guard isGroupConversation else { return }
        
        let messageText = self.inputToolbar.messageBodyForSending ?? ""
        let targetName: String
        if let senderName, !senderName.isEmpty {
            targetName = senderName
        } else {
            targetName = recipientId
        }
        let atMember = "@\(targetName)\(kMentionEndChar)"
        if messageText.contains(atMember) {
            return
        }
        // TODO: Jaymin 待验证
        let atRange = NSMakeRange(messageText.count, atMember.count - 1)
        if self.inputToolbar.isInputViewFirstResponder {
            let selectRange = self.inputToolbar.selectRange
            var tmpMessageText = messageText
            tmpMessageText.insertAtNSRange(atMember, at: selectRange.location)
            let newRange = NSMakeRange(selectRange.location + atMember.count, 0)
            self.inputToolbar.setMessageBody(tmpMessageText, selectRange: newRange, animated: false)
        } else {
            let messageText = messageText + atMember
            self.inputToolbar.setMessageBody(messageText, animated: false)
        }
        
        self.inputToolbar.beginEditingMessage()
        
        guard let groupThread = self.thread as? TSGroupThread else {
            return
        }
        var type: DSKProtoDataMessageMentionType = .internal
        if !groupThread.groupModel.groupMemberIds.contains(recipientId) {
            type = .external
        }
        let item = DTInputAtItem()
        item.uid = recipientId
        item.name = targetName
        item.range = atRange
        item.type = type.rawValue
        self.inputToolbar.atCache.add(item)
    }
    
    func messageCell(_ cell: ConversationMessageCell, didTapFailedOutgoingMessage message: TSOutgoingMessage) {
        AssertIsOnMainThread()
        
        guard isCanSpeak else { return }
        
        let actionSheet = ActionSheetController(title: message.mostRecentFailureText)
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let delegateMessageAction = ActionSheetAction(
            title: Localized("TXT_DELETE_TITLE"),
            style: .destructive
        ) { action in
            self.databaseStorage.asyncWrite { transaction in
                message.anyRemove(transaction: transaction)
                OWSLogger.info("handleUnsentMessageTap delete message timestamp for sorting: \(message.timestampForSorting())")
            }
        }
        actionSheet.addAction(delegateMessageAction)
        
        let resendMessageAction = ActionSheetAction(
            title: Localized("SEND_AGAIN_BUTTON"),
            accessibilityIdentifier: "ConversationViewController.send_agin",
            style: .default
        ) { action in
            self.messageSender.enqueue(message) {
                OWSLogger.info("\(self.logTag) Successfully resent failed message.")
            } failure: { error in
                OWSLogger.info("\(self.logTag) Failed to send message with error: \(error.localizedDescription)")
            }
        }
        actionSheet.addAction(resendMessageAction)
        
        dismissKeyBoard()
        presentActionSheet(actionSheet)
    }
    
    func messageCell(_ cell: ConversationMessageCell, didTapTranslateIconWith viewItem: ConversationViewItem) {
        translateIncoming(conversationViewItem: viewItem)
    }
    
    /// 点击长文翻译消息，进入预览页面
    func messageCell(_ cell: ConversationMessageCell, didTapTranslateTruncatedTextMessageWith viewItem: any ConversationViewItem) {
        showMoreTranslateResult(conversationItem: viewItem)
    }
    
    /// 点击消息已读数量
    func messageCell(_ cell: ConversationMessageCell, didTapReadStatusWith viewItem: any ConversationViewItem) {
        AssertIsOnMainThread()
        
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let messageDetailVC = MessageDetailViewController(
            viewItem: viewItem,
            message: message,
            thread: self.thread,
            mode: .focusOnMetadata
        )
        navigationController?.pushViewController(messageDetailVC, animated: true)
    }
    
    func messageCell(
        _ cell: ConversationMessageCell,
        didLongPressBubbleViewWith messageType: ConversationMessageType,
        viewItem: any ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        handleActionMenu(messageType: messageType, viewItem: viewItem, bubbleView: bubbleView)
    }
    
    func messageCell(_ cell: ConversationMessageCell, shouldBeginPanToQuoteWith viewItem: any ConversationViewItem, bubbleView: ConversationMessageBubbleView) -> Bool {
        // 如果处于部分复制状态，禁止右滑引用
        if let _ = self.actionMenuController {
            return false
        }
        
        if viewItem.isConfidentialMessage {
            return false
        }
        
        return true
    }
    
    func messageCell(_ cell: ConversationMessageCell, didPanToQuoteWith viewItem: any ConversationViewItem, bubbleView: ConversationMessageBubbleView) {
        messageActionsQuoteToItem(viewItem)
    }
    
    func showConversationSettings() {
        showConversationSettings(showVerification: false)
    }
}

// MARK: - ConversationSystemMessageCellDelegate

extension ConversationViewController: ConversationSystemMessageCellDelegate {
    func systemMessageCell(_ cell: ConversationSystemMessageCell, didTappedNonBlockingIdentityChangeWith recipientId: String?) {
        if let recipientId {
            showFingerprint(withRecipientId: recipientId)
            return
        }
        
        guard !self.isGroupConversation else {
            // Before 2.13 we didn't track the recipient id in the identity change error.
            OWSLogger.warn("Ignoring tap on legacy nonblocking identity change since it has no signal id")
            return
        }
        guard let contactThread = self.thread as? TSContactThread else {
            return
        }
        let contactIdentifier = contactThread.contactIdentifier()
        OWSLogger.info("Assuming tap on legacy nonblocking identity change corresponds to current contact thread: \(contactIdentifier)")
        showFingerprint(withRecipientId: contactIdentifier)
    }
    
    func systemMessageCell(_ cell: ConversationSystemMessageCell, didTappedAttributedMessageWith message: TSInfoMessage) {
        switch message.messageType {
        case .recallMessage:
            handleTapRecallMessageEvent(message: message)
            
        case .pinMessage:
            if let realSource = message.realSource {
                scrollToOrigionMessage(realSource: realSource)
            }

        case .callEnd:
            handleTapCallEndMessageEvent()
            
        case .userPermissionForbidden:
            handleTapPermissionForbiddenMessageEvent()
            
        case .meetingReminder:
            handleTapMeetingReminderMessageEvent(message: message)
            
        case .groupRemoveMember:
            handleTapGroupRemoveMemberMessageEvent(message: message)
            
        case .groupMemberChangeMeetingAlert:
            navigateToMeeting(message: message)
            
//        case .groupAddMember:
//            handleTapGroupAddMemberMessageEvent()
        default:
            break
        }
    }
    
    // OC 旧版本中未实现该方法
    func systemMessageCell(_ cell: ConversationSystemMessageCell, resendGroupUpdateWith errorMessage: TSErrorMessage) {}
    
    func systemMessageCell(_ cell: ConversationSystemMessageCell, showFingerprintWith recipientId: String) {
        showFingerprint(withRecipientId: recipientId)
    }
    
    func systemMessageCell(_ cell: ConversationSystemMessageCell, didTappedReportedMessageWith message: TSInfoMessage) {
        let alert = UIAlertController(
            title: Localized("REPORT_INFO_TIPS_TITLE"),
            message: Localized("REPORT_INFO_TIPS_DESCRIPTION"),
            preferredStyle: .actionSheet
        )
        
        let titleString = Localized("REPORT_INFO_TIPS_TITLE")
        let attributedTitle = NSMutableAttributedString(string: titleString)
        attributedTitle.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: NSRange(location: 0, length: titleString.count))
        alert.setValue(attributedTitle, forKey: "attributedTitle")

        let cancelTitle = Localized("REPORT_INFO_TIPS_OK")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
        let buttonColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329)
        cancelAction.setValue(buttonColor, forKey: "_titleTextColor")

        alert.addAction(cancelAction)

        self.present(alert, animated: true, completion: nil)
    }
    
    func showFingerprint(withRecipientId recipientId: String) {
        // Ensure keyboard isn't hiding the "safety numbers changed" interaction when we
        // return from FingerprintViewController.
        dismissKeyBoard()
        FingerprintViewController.present(from: self, recipientId: recipientId)
    }
}

// MARK: - Private

private extension ConversationViewController {
    func handleTapRecallMessageEvent(message: TSInfoMessage) {
        guard let recallModel = message.recall, !recallModel.body.isEmpty else {
            return
        }
        var newText = recallModel.body
        let originMessageText = self.inputToolbar.messageBodyForSending
        if let originMessageText = originMessageText, !originMessageText.isEmpty {
            newText = originMessageText + recallModel.body
        }
        
        if let mentions = recallModel.mentions, !mentions.isEmpty {
            self.inputToolbar.atCache.setMentions(mentions, body: recallModel.body)
        } else {
            recallModel.atPersons.components(separatedBy: ";").filter {
                !$0.isEmpty
            }.forEach {
                let item = DTInputAtItem()
                if let account = self.contactsManager.signalAccount(forRecipientId: $0) {
                    item.uid = $0
                    item.name = "\(kMentionStartChar)\(account.contactFullName() ?? "")\(kMentionEndChar)"
                    self.inputToolbar.atCache.add(item)
                }
            }
        }
        
        self.inputToolbar.setMessageBody(newText, animated: true)
        self.inputToolbar.beginEditingMessage()
    }
    
    func handleTapCallEndMessageEvent() {
        self.inputToolbar.setMessageBody("Meeting Feedback:\n", animated: true)
        self.inputToolbar.beginEditingMessage()
    }
    
    func handleTapPermissionForbiddenMessageEvent() {
        let weaBotThread = TSContactThread.getOrCreateThread(contactId: TSConstants.officialBotId)
        let conversationVC = ConversationViewController(thread: weaBotThread, action: .none, viewMode: .normalPresent)
        let navigationController = OWSNavigationController(rootViewController: conversationVC)
        present(navigationController, animated: true)
    }
    
    func handleTapMeetingReminderMessageEvent(message: TSInfoMessage) {
        func showReminderAlert() {
            guard self.isGroupConversation, let meetingName = message.meetingName, !meetingName.isEmpty else {
                return
            }
            showAlert(
                .alert,
                title: Localized("GROUP_CALL_JOIN_MEETING_TIPS_TITLE"),
                msg: Localized("GROUP_CALL_JOIN_MEETING_TIPS_MSG"),
                cancelTitle: Localized("TXT_CANCEL_TITLE"),
                confirmTitle: Localized("TXT_CONFIRM_TITLE"),
                confirmStyle: .default
            ) {
                let channelName = DTCallManager.generateGroupChannelName(by: self.thread)
                // TODO：预约会议相关来源于meetingReminder
            }
        }
        
        switch message.meetingReminderType {
        case .remind:
            showReminderAlert()
        case .create:
            navigateToMeeting(message: message)
        default:
            break
        }
    }
    
    func navigateToMeeting(message: TSInfoMessage) {
        guard let meetingUrl = message.meetingDetailUrl, !meetingUrl.isEmpty else {
            OWSLogger.error("error no meetingDetailUrl")
            return
        }
        guard let url = URL(string: meetingUrl) else {
            OWSLogger.error("error meetingDetailUrl cannot init URL")
            return
        }
        UIApplication.shared.open(url) { isSuccess in
            if !isSuccess {
                OWSLogger.error("error meeting detail open URL fail")
            }
        }
    }
    
    func handleTapGroupRemoveMemberMessageEvent(message: TSInfoMessage) {
        guard let groupThread = self.thread as? TSGroupThread else {
            return
        }
        guard !groupThread.isLocalUserInGroup() else {
            SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_ALREADY_IN_GROUP"))
            return
        }
        
        showAlert(
            .alert,
            title: Localized("COMMON_NOTICE_TITLE"),
            msg: Localized("GROUP_REMOVE_MEMBER_REJOIN_TIPS"),
            cancelTitle: Localized("TXT_CANCEL_TITLE"),
            confirmTitle: Localized("CONFIRMATION_TITLE"),
            confirmStyle: .default
        ) {
            self.rejoinGroup(inviteCode: message.inviteCode)
        }
    }
    
    func rejoinGroup(inviteCode: String) {
        guard !inviteCode.isEmpty else { return }
        //0  成功
        //1  参数无效
        //2  无权限 （邀请人不再群中，或群组以更改邀请规则邀请人不再有权限加人）
        //3  群无效（不存在或状态非活跃）
        //5  token无效（token验证失败、token超时失效、token解析成功但无gid或inviter）
        //10 群已满员
        //11 邀请人无效（邀请人账号不可用）
        
        SVProgressHUD.show()
        rejoinGroupAPI.joinGroup(byInviteCode: inviteCode) { [weak self] entity, status in
            guard let self else { return }
            
            SVProgressHUD.dismiss(withDelay: 0.5) {
                self.databaseStorage.asyncWrite { transaction in
                    guard let groupThread = self.thread as? TSGroupThread else {
                        return
                    }
                    let newGroupThread = self.groupUpdateMessageProcessor.generateOrUpdateConveration(
                        withGroupId: groupThread.groupModel.groupId,
                        needSystemMessage: true,
                        generate: false,
                        envelope: nil,
                        groupInfo: entity,
                        groupNotifyEntity: nil,
                        transaction: transaction
                    )
                    transaction.addAsyncCompletionOnMain {
                        if let newGroupThread {
                            self.thread = newGroupThread
                        }
                        self.hideInputIfNeeded()
                    }
                }
            }
            // rejoin group 预约会议相关
            if let localNumber = TSAccountManager.localNumber() {
                DTCalendarManager.shared.groupChange(
                    gid: self.thread.serverThreadId,
                    actionCode: 1,
                    target: [localNumber]
                )
            }
            
        } failure: { error in
            SVProgressHUD.dismiss(withDelay: 0.5) {
                let errorCode = (error as NSError).code
                guard let responseStatus = DTAPIRequestResponseStatus(rawValue: errorCode) else {
                    SVProgressHUD.showInfo(withStatus: error.localizedDescription)
                    return
                }
                let info: String
                switch responseStatus {
                case .invalidParameter:
                    info = Localized("GROUP_COMMEN_ERROR_INVALID_ARGUMENT")
                case .noPermission:
                    info = Localized("GROUP_COMMEN_ERROR_INVITER_EXCEPTION")
                case .noSuchGroup:
                    info = Localized("GROUP_COMMEN_ERROR_GROUP_EXCEPTION")
                case .invalidToken:
                    info = Localized("GROUP_COMMEN_ERROR_INVITATION_EXCEPTION")
                case .groupIsFull:
                    info = Localized("GROUP_COMMEN_ERROR_GROUP_FULL")
                case .noSuchGroupTask:
                    info = Localized("GROUP_COMMEN_ERROR_INVITER_NOT_EXIST")
                default:
                    info = error.localizedDescription
                }
                SVProgressHUD.showInfo(withStatus: info)
            }
        }
    }
    
    func showConversationSettings(showVerification: Bool) {
        func viewControllersUpToSelf() -> [UIViewController] {
            AssertIsOnMainThread()
            owsAssertDebug(self.navigationController != nil)
            
            guard let navigationController else {
                return []
            }
            if navigationController.topViewController === self {
                return navigationController.viewControllers
            }
            
            let viewControllers = navigationController.viewControllers
            guard let index = viewControllers.firstIndex(of: self) else {
                owsFailDebug("Unexpectedly missing from view hierarhy")
                return viewControllers
            }
            return Array(viewControllers.prefix(upTo: index + 1))
        }
        
        let settingVC = OWSConversationSettingsViewController()
        settingVC.conversationSettingsViewDelegate = self
        settingVC.configure(with: self.thread)
        settingVC.showVerificationOnAppear = showVerification
        var viewControllers = viewControllersUpToSelf()
        viewControllers.append(settingVC)
        navigationController?.setViewControllers(viewControllers, animated: true)
    }
    
    func handleTapGroupAddMemberMessageEvent() {
        showAlert(
            .alert,
            title: nil,
            msg: Localized("GROUP_SEND_HISTORY_MESSAGE_TIPS"),
            cancelTitle: Localized("TXT_CANCEL_TITLE"),
            confirmTitle: Localized("CONFIRMATION_TITLE"),
            confirmStyle: .default
        ) {
//            self.sendHistoryMessage()
        }
    }
    
    func sendHistoryMessage() {
        var messages: [TSMessage] = []
        let interactionFinder = InteractionFinder(threadUniqueId: self.thread.uniqueId)
        databaseStorage.uiRead { transaction in
            try? interactionFinder.enumerateRecentInteractions(transaction: transaction) { interaction, stop in
                let interactionType = interaction.interactionType()
                guard interactionType == .incomingMessage || interactionType == .outgoingMessage else {
                    return
                }
                guard let message = interaction as? TSMessage else {
                    return
                }
                if let attachment = self.firstAttachmentOfMessage(message, transaction: transaction) as? TSAttachmentStream,
                   attachment.isAudio() {
                    return
                }
                messages.append(message)
                
                // 最多查询最近的 20 条数据
                if messages.count == 20 {
                    stop.pointee = true
                }
            }
        }
        
        if !messages.isEmpty {
            messages = messages.reversed()
            DTForwardMessageHelper.forwardMessageIs(
                fromGroup: self.thread.isGroupThread(),
                targetThread: self.thread,
                messages: messages,
                success: nil,
                failure: nil
            )
        }
    }
    
    func firstAttachmentOfMessage(_ message: TSMessage, transaction: SDSAnyReadTransaction) -> TSAttachment? {
        var attachmentId: String?
        if !message.attachmentIds.isEmpty {
            attachmentId = message.attachmentIds.first
        } else {
            attachmentId = message.combinedForwardingMessage?.subForwardingMessages.first?.forwardingAttachmentIds.first
        }
        guard let attachmentId, !attachmentId.isEmpty else {
            return nil
        }
        return TSAttachment.anyFetch(uniqueId: attachmentId, transaction: transaction)
    }
}

// MARK: - OWSConversationSettingsViewDelegate

extension ConversationViewController: OWSConversationSettingsViewDelegate {
    public func conversationColorWasUpdated() {
        self.conversationStyle.updateProperties()
        resetContentAndLayoutWithSneakyTransaction()
    }
    
    public func popAllConversationSettingsViews() {
        if let presentedViewController {
            presentedViewController.dismiss(animated: true) {
                self.navigationController?.popToViewController(self, animated: true)
            }
        } else {
            self.navigationController?.popToViewController(self, animated: true)
        }
    }
    
    public func sendEmergencyAlertMessage(_ messageText: String, atItems items: [DTInputAtItem]) {
        items.forEach { self.inputToolbar.atCache.add($0) }
        self.inputToolbar.setMessageBody(messageText, animated: false)
    }
}


extension String {
    /// 将 NSRange 转换为 Swift 的 Range<String.Index>
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
              let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
              let from = String.Index(from16, within: self),
              let to = String.Index(to16, within: self) else {
            return nil
        }
        return from..<to
    }

    /// 在 NSRange.location 指定位置安全插入字符串
    mutating func insertAtNSRange(_ newElement: String, at nsLocation: Int) {
        let nsRange = NSRange(location: nsLocation, length: 0)
        if let range = self.range(from: nsRange) {
            self.insert(contentsOf: newElement, at: range.lowerBound)
        } else {
            // fallback: 插入到结尾
            self.append(newElement)
        }
    }
}
