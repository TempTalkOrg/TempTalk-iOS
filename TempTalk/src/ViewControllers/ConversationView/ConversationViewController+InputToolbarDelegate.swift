//
//  ConversationViewController+InputToolbarDelegate.swift
//  Signal
//
//  Created by Jaymin on 2024/1/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import CoreServices
import TTMessaging
import TTServiceKit

// MARK: - ConversationInputTextViewDelegate

extension ConversationViewController: ConversationInputTextViewDelegate {
    public func didPaste(_ attachment: SignalAttachment?) {
        guard isFriend || thread.isGroupThread() else {
            DTToastHelper.toast(withText: Localized("NON_FRIEND_ONLY_TEXT_MESSAGE"))
            return
        }
        showApprovalDialog(forAttachment: attachment)
    }
    
    public func inputTextViewSendMessagePressed() {
        sendTextMessageIfWithoutSensitiveWords()
    }
    
    public func pasteMention(withJson jsonMention: String, range: NSRange) {
        guard !jsonMention.isEmpty else {
            return
        }
        guard let jsonData = jsonMention.data(using: .utf8) else {
            return
        }
        let dictionarys: [[AnyHashable: Any]]
        do {
            dictionarys = try JSONSerialization.jsonObject(
                with: jsonData,
                options: .mutableContainers
            ) as? [[AnyHashable: Any]] ?? []
        } catch {
            owsFailDebug(" copy mention error1: \(error)")
            return
        }
        let copyMentions: [DTMention]
        do {
            copyMentions = try MTLJSONAdapter.models(
                of: DTMention.self,
                fromJSONArray: dictionarys
            ) as? [DTMention] ?? []
        } catch {
            owsFailDebug(" copy mention error2: \(error)")
            return
        }
        
        guard !copyMentions.isEmpty else {
            return
        }
        
        
        guard let messageText = self.inputToolbar.messageBodyForSending as? NSString,
              messageText.length > 0 else {
            return
        }
        
        copyMentions.forEach {
            var isContainUid = false
            if self.isGroupConversation, let groupThread = self.thread as? TSGroupThread {
                isContainUid = groupThread.groupModel.groupMemberIds.contains($0.uid)
            } else {
                isContainUid = $0.uid == self.thread.contactIdentifier() || $0.uid == TSAccountManager.localNumber()
            }
            if isContainUid || $0.uid == MENTIONS_ALL {
                let nameRange = NSMakeRange(Int($0.start) + range.location + 1, Int($0.length) - 1)
                let name = messageText.substring(with: nameRange)
                let item = DTInputAtItem()
                item.uid = $0.uid
                item.type = $0.type
                item.name = name
                item.range = nameRange
                self.inputToolbar.atCache.add(item)
            }
        }
    }
}

// MARK: - ConversationInputToolbarDelegate

extension ConversationViewController: ConversationInputToolbarDelegate {
    func sendButtonPressed() {
        BenchManager.startEvent(title: "Send Message", eventId: "message-send")
        BenchManager.startEvent(
            title: "Send Message milestone: clearTextMessageAnimated completed",
            eventId: "fromSendUntil_clearTextMessageAnimated"
        )
        BenchManager.startEvent(
            title: "Send Message milestone: toggleDefaultKeyboard completed",
            eventId: "fromSendUntil_toggleDefaultKeyboard"
        )
        sendTextMessageIfWithoutSensitiveWords()
    }
    
    func isBlockedConversation() -> Bool {
        false
    }
    
    func isGroup() -> Bool {
        self.thread.isGroupThread()
    }
    
    // MARK: voice memo
    
    public func voiceMemoGestureDidStart() {
        AssertIsOnMainThread()
        
        let kIgnoreMessageSendDoubleTapDurationSeconds: TimeInterval = 2.0
        if let lastMessageSentDate = self.lastMessageSentDate,
           abs(lastMessageSentDate.timeIntervalSinceNow) < kIgnoreMessageSendDoubleTapDurationSeconds {
            // If users double-taps the message send button, the second tap can look like a
            // very short voice message gesture.  We want to ignore such gestures.
            cancelVoiceMemo()
            return
        }
        
        self.inputToolbar.showVoiceMemoUI()
//        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        requestRecordingVoiceMemo()
    }
    
    func voiceMemoGestureDidComplete() {
        AssertIsOnMainThread()
        
        self.inputToolbar.hideVoiceMemoUI(animated: true)
        endRecordingVoiceMemo()
//        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    public func voiceMemoGestureDidCancel() {
        AssertIsOnMainThread()
        
        self.inputToolbar.hideVoiceMemoUI(animated: false)
        cancelRecordingVoiceMemo()
//        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func voiceMemoGestureWasInterrupted() {
        
    }
    
    // MARK: Attachments
    
    func photosButtonPressed() {
        chooseFromLibraryAsMedia()
    }
    
    func cameraButtonPressed() {
        takePictureOrVideo()
    }
    
    /// unused
    func voiceCallButtonPressed() {
        didTapCallNavBtn()
    }
    
    func videoCallButtonPressed() {
        didTapCallNavBtn()
    }
    
    
    func contactButtonPressed() {
                
        self.atOrSendContacctVC = ChooseAtMembersViewController.present(
            from: self,
            pageType: ChooseMemberPageTypeSendContact,
            thread: self.thread,
            delegate: self
        )
    }
    
    func fileButtonPressed() {
        showDocumentPicker()
    }
    
    func confideButtonPressed() {
        performConfidentialModeToggleIfNeeded(completion: nil)
    }

    private func performConfidentialModeToggleIfNeeded(completion: (() -> Void)?) {
        let isEnabling: Bool
        let confidentialMode: Int
        let inputToolbarState: InputToolbarState

        if let conversationEntity = self.thread.conversationEntity, conversationEntity.confidentialMode == .confidential {
            confidentialMode = 0
            inputToolbarState = .normal
            isEnabling = false
        } else {
            confidentialMode = 1
            inputToolbarState = .confidential
            isEnabling = true
        }

        if isEnabling {
            var shouldShowAlert = false
            databaseStorage.read { transaction in
                shouldShowAlert = !SSKPreferences.hasShownConfidentialMessageAlert(transaction: transaction)
            }

            if shouldShowAlert {
                DTConfidentialMessageAlertController.present(from: self) {
                    self.performConfidentialModeToggle(confidentialMode: confidentialMode, inputToolbarState: inputToolbarState, completion: completion)
                }
            } else {
                performConfidentialModeToggle(confidentialMode: confidentialMode, inputToolbarState: inputToolbarState, completion: completion)
            }
        } else {
            performConfidentialModeToggle(confidentialMode: confidentialMode, inputToolbarState: inputToolbarState, completion: completion)
        }
    }

    private func performConfidentialModeToggle(confidentialMode: Int, inputToolbarState: InputToolbarState, completion: (() -> Void)? = nil) {
        let configApi = DTSetConversationApi()
        configApi.requestConfigConfidentialMode(withConversationID: self.thread.serverThreadId,
                                                confidentialMode: confidentialMode) { conversationEntity in
            self.inputToolbar.inputToolbarState = inputToolbarState
            self.thread.conversationEntity = conversationEntity
            self.databaseStorage.asyncWrite { wTransaction in
                self.thread.anyUpdate(transaction: wTransaction) { thread in
                    thread.conversationEntity = conversationEntity

                    DataUpdateUtil.shared.updateConversation(thread: thread,
                                                             expireTime: conversationEntity.messageExpiry,
                                                             messageClearAnchor: NSNumber(value: conversationEntity.messageClearAnchor),
                                                             transaction: wTransaction)
                }
                wTransaction.addAsyncCompletionOnMain {
                    NotificationCenter.default.post(name: .DTConversationDidChange, object: nil)
                    completion?()
                }
            }
        } failure: { error in
            let errorMsg = NSError.errorDesc((error as NSError), errResponse: nil)
            DTToastHelper.toast(withText: errorMsg)
        }
    }
    
    // MARK: mention
    
    func mentionButtonPressed() {
        inputToolbar.startGroupAt()
    }
    
    public func atIsActive(location: UInt) {
        
        if !self.thread.isGroupThread() { return }
        
        self.atLocation = location
        DispatchQueue.main.async {
            // UI更新代码
            self.atOrSendContacctVC = ChooseAtMembersViewController.present(
                from: self,
                pageType: ChooseMemberPageTypeMention,
                thread: self.thread,
                delegate: self
            )
        }
    }
    
    public func updateToolbarHeight() {
        updateInputAccessoryPlaceholderHeight()
        
        // Normally, the keyboard frame change triggered by updating
        // the bottom bar height will cause the content insets to reload.
        // However, if the toolbar updates while it's not the first
        // responder (e.g. dismissing a quoted reply) we need to preserve
        // our constraints here.
        if !self.inputToolbar.isInputViewFirstResponder, viewHasEverAppeared {
            updateContentInsets(animated: false)
        }
    }
    
    public func beginInput() {
        // 检查是否从搜索跳转且用户还未操作
        // 如果是，保护焦点消息不被清除（焦点会在键盘显示后自动清除）
        let hasFocusMessage = conversationViewModel.viewState.focusItemIndex != nil
        let justCompletedInitialScroll = viewState.hasCompletedInitialScroll && !viewState.userHasScrolled

        if hasFocusMessage && justCompletedInitialScroll {
            return
        }

        // 正常情况：清除焦点并滚动到底部
        if conversationViewModel.focusMessageIdOnOpen != nil {
            conversationViewModel.focusMessageIdOnOpen = nil
            conversationViewModel.clearFocusMessageIndex()
        }

        scrollToBottom(animated: true)
    }
    
    func expandButtonPressed(_ inputToolbar: ConversationInputToolbar) {
        let fullScreenVC = FullScreenInputViewController()
        fullScreenVC.delegate = self
        fullScreenVC.thread = thread
        fullScreenVC.text = inputToolbar.inputTextView.text
        fullScreenVC.onTextUpdated = { updatedText in
            inputToolbar.inputTextView.text = updatedText
            inputToolbar.textViewDidChange(inputToolbar.inputTextView)
        }
        present(fullScreenVC, animated: true)
    }
}

// MARK: - FullScreenInputViewDelegate

extension ConversationViewController: FullScreenInputViewDelegate {
    func fullScreenConfideButtonPressed() {
        confideButtonPressed()
    }
        
    func fullScreenCollapseButtonPressed() {
        //
    }
}

// MARK: - Send Message

extension ConversationViewController {
    private func sendTextMessageIfWithoutSensitiveWords() {
        guard let messageText = self.inputToolbar.messageBodyForSending else {
            Logger.error("Message text is nil")
            return
        }
        let maxTextBytes = 10 * 1024 * 1024
        let inputByteCount = messageText.lengthOfBytes(using: .utf8)
        if inputByteCount > maxTextBytes {
            showAlert(
                .alert,
                title: nil,
                msg: Localized("CONVERSATION_TOOLBAR_BYTE_LIMIT"),
                cancelTitle: nil,
                confirmTitle: Localized("TXT_CONFIRM_TITLE"),
                confirmStyle: .default
            )
            return
        }
        
        if let sensitiveWord = DTSensitiveWordsConfig.checkSensitiveWords(messageText) {
            let warning = String(format: Localized("SENSITIVE_WORDS_WARNING_TEXT"), sensitiveWord)
            showAlert(
                .alert,
                title: Localized("COMMON_WARNING_TITLE"),
                msg: warning,
                cancelTitle: Localized("TXT_CANCEL_TITLE"),
                confirmTitle: Localized("SEND_BUTTON_TITLE"),
                confirmStyle: .destructive
            ) {
                self.tryToSendTextMessage(messageText, updateKeyboardState: true)
            }
            return
        }
        
        tryToSendTextMessage(messageText, updateKeyboardState: true)
    }
    
    private func tryToSendTextMessage(_ text: String, updateKeyboardState: Bool) {
        asyncConfigBlockStatus()
        
        guard isCanSpeak else { return }
        AssertIsOnMainThread()
        
        let strippedText = text.stripped
        guard !strippedText.isEmpty else { return }
        
        // Limit outgoing text messages to 16kb.
        //
        // We convert large text messages to attachments
        // which are presented as normal text messages.
        let message: TSOutgoingMessage
        if strippedText.lengthOfBytes(using: .utf8) >= kOversizeTextMessageSizeThreshold {
            // 长文本消息 body
            let captionText = strippedText.substring(lengthOfBytes: Int(kOversizeTextMessageBodyLength))
            let dataSource = DataSourceValue.dataSource(withOversizeText: strippedText)
            let attachment = SignalAttachment.attachment(
                dataSource: dataSource,
                dataUTI: kOversizeTextAttachmentUTI,
                imageQuality: .original
            )
            attachment.captionText = captionText
            
            // TODO we should redundantly send the first n chars in the body field so it can be viewed
            // on clients that don't support oversized text messgaes, (and potentially generate a preview
            // before the attachment is downloaded)
            message = ThreadUtil.sendMessage(
                with: attachment,
                in: self.thread,
                quotedReplyModel: self.inputToolbar.quotedReplyDraft,
                preSendMessageCallBack: nil,
                messageSender: self.messageSender,
                completion: nil
            )
            
        } else {
            let mentions = self.inputToolbar.atCache.allMentions(strippedText)
            let atPersons = DTMention.atPersons(mentions)
            message = ThreadUtil.sendMessage(
                withText: strippedText,
                atPersons: atPersons,
                mentions: mentions,
                in: self.thread,
                quotedReplyModel: self.inputToolbar.quotedReplyDraft,
                messageSender: self.messageSender
            )
        }

        self.conversationViewModel.clearUnreadMessagesIndicator()
        self.conversationViewModel.appendUnsavedOutgoingTextMessage(message)
        messageWasSent(message)
        
        // Clearing the text message is a key part of the send animation.
        // It takes 10-15ms, but we do it inline rather than dispatch async
        // since the send can't feel "complete" without it.
        BenchManager.bench(title: "clearTextMessageAnimated") { [weak self] in
            guard let self = self else { return }
            self.inputToolbar.clearTextMessage(animated: true)
        }
        BenchManager.completeEvent(eventId: "fromSendUntil_clearTextMessageAnimated")
        
//        DispatchQueue.main.async {
//            // After sending we want to return from the numeric keyboard to the
//            // alphabetical one. Because this is so slow (40-50ms), we prefer it
//            // happens async, after any more essential send UI work is done.
//            BenchManager.bench(title: "toggleDefaultKeyboard") { [weak self] in
//                guard let self else { return }
//                self.inputToolbar.toggleDefaultKeyboard()
//            }
//            BenchManager.completeEvent(eventId: "fromSendUntil_toggleDefaultKeyboard")
//        }
        
        if let messageDraft = self.thread.messageDraft, !messageDraft.isEmpty {
            databaseStorage.asyncWrite { [weak self] transaction in
                guard let self else { return }
                self.thread.clearDraft(with: transaction)
            }
        }
        
        self.inputToolbar.clearTextMessage(animated: true)
        self.inputToolbar.atCache.clean()
    }
    
    func tryToSendAttachments(
        _ attachments: [SignalAttachment],
        preSendMessageCallBack: ((TSOutgoingMessage) -> Void)?,
        messageText: String?,
        completion: ((Error?) -> Void)?
    ) {
        guard isCanSpeak else { return }
        asyncConfigBlockStatus()
        
        DispatchMainThreadSafe { [weak self] in
            guard let self else { return }
            
            if let attachment = attachments.first(where: { $0.hasError }) {
                Logger.warn("Invalid attachment: \(attachment.errorName ?? "Missing data")")
                self.showErrorAlert(forAttachment: attachment)
                return
            }
            guard let firstAttachment = attachments.first else {
                return
            }
            
            var message: TSOutgoingMessage?
            message = ThreadUtil.sendMessage(
                with: firstAttachment,
                in: self.thread,
                quotedReplyModel: self.inputToolbar.quotedReplyDraft,
                preSendMessageCallBack: preSendMessageCallBack,
                messageSender: self.messageSender
            ) { error in
                if let err = error as? NSError, err.code == OWSErrorCode.attachmentExceedsLimit.rawValue {
                    self.databaseStorage.asyncWrite { transaction in
                        if let message {
                            message.anyRemove(transaction: transaction)
                            Logger.info("tryToSendAttachments delete message timestamp for sorting: \(message.timestampForSorting())")
                        }
                    }
                }
                if let completion {
                    completion(error)
                }
            }
            
            if let message {
                self.messageWasSent(message)
            }
        }
    }
    
    private func messageWasSent(_ message: TSOutgoingMessage) {
        AssertIsOnMainThread()
        
        self.lastMessageSentDate = Date()
        self.conversationViewModel.clearUnreadMessagesIndicator()
        resetQuotePreview()
        
        if Environment.shared.preferences.soundInForeground() {
            let soundId = OWSSounds.systemSoundID(for: .messageSent, quiet: true)
            AudioServicesPlaySystemSound(soundId)
        }
        
        handleAddFriendRequest(message: message,
                               sourceType: .inUserCard,
                               sourceConversationID: nil,
                               shareContactCardUId: nil,
                               action: nil)
    }
    
    private func resetQuotePreview() {
        if let _ = self.inputToolbar.quotedReplyDraft {
            self.inputToolbar.quotedReplyDraft = nil
        }
    }
}

// MARK: - Show dialog

@objc
extension ConversationViewController {
    func showErrorAlert(forAttachment attachment: SignalAttachment?) {
        owsAssertDebug(attachment == nil || attachment?.hasError == true)
        
        let errorMessage = (attachment?.localizedErrorDescription ?? SignalAttachment.missingDataErrorMessage)
        
        Logger.error("\(errorMessage)")
        
        let title = Localized("ATTACHMENT_ERROR_ALERT_TITLE", "The title of the 'attachment error' alert.")
        OWSActionSheets.showActionSheet(title: title, message: errorMessage)
    }
    
    func showApprovalDialog(forAttachment attachment: SignalAttachment?) {
        AssertIsOnMainThread()

        guard let attachment = attachment else {
            owsFailDebug("attachment was unexpectedly nil")
            showErrorAlert(forAttachment: attachment)
            return
        }
        showApprovalDialog(forAttachments: [ attachment ])
    }

    func showApprovalDialog(forAttachments attachments: [SignalAttachment]) {
        AssertIsOnMainThread()

        let isConfidential = thread.conversationEntity?.confidentialMode == .confidential
        let approvalVC = AttachmentApprovalViewController.wrappedInNavController(
            attachments: attachments,
            isConfidential: isConfidential,
            delegate: self
        )
        present(approvalVC, animated: true)
    }
}

// MARK: - AttachmentApprovalViewControllerDelegate

extension ConversationViewController: AttachmentApprovalViewControllerDelegate {
    public func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didCancelAttachments attachments: [SignalAttachment]) {
        dismiss(animated: true)
    }

    public func attachmentApprovalDidTapConfide(_ attachmentApproval: AttachmentApprovalViewController) {
        ImpactHapticFeedback.impactOccurred(style: .light)
        performConfidentialModeToggleIfNeeded { [weak self, weak attachmentApproval] in
            guard let self, let toolbar = attachmentApproval?.bottomToolbar as? CaptioningToolbar else { return }
            toolbar.isConfidential = self.thread.conversationEntity?.confidentialMode == .confidential
        }
    }

    public func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didApproveAttachments attachments: [SignalAttachment]) {
        let captionText = attachments.last?.captionText
        attachments.forEach { $0.captionText = nil }
        attachments.enumerated().forEach { index, attachment in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(index)) { [weak self] in
                guard let self else { return }
                self.tryToSendAttachments([attachment], preSendMessageCallBack: { _ in }, messageText: nil, completion: nil)
            }
        }

        if let text = captionText, !text.isEmpty {
            let textDelay = 0.1 * Double(attachments.count)
            DispatchQueue.main.asyncAfter(deadline: .now() + textDelay) { [weak self] in
                guard let self else { return }
                _ = ThreadUtil.sendMessage(
                    withText: text,
                    atPersons: nil,
                    mentions: nil,
                    in: self.thread,
                    quotedReplyModel: nil,
                    messageSender: self.messageSender
                )
            }
        }

        dismiss(animated: true)
        scrollToBottom(animated: false)
    }
}

// MARK: - ChooseAtMembersViewControllerDelegate

extension ConversationViewController: ChooseAtMembersViewControllerDelegate {
    
    func choose(atPeronsDidSelectRecipientId recipientId: String!, name: String!, mentionType: Int32, pageType: ChooseMemberPageType) {
        
        if ChooseMemberPageTypeMention == pageType {
            
            guard let mentionType = DSKProtoDataMessageMentionType(rawValue: mentionType) else {
                return
            }
            selectAtPerson(recipientId: recipientId, name: name, type: mentionType)
        } else if ChooseMemberPageTypeSendContact == pageType {
            
            let account = self.contactsManager.signalAccount(forRecipientId: recipientId)
            if let sendContact = OWSContacts.contact(forLocalContact: account?.contact, contactsManager: self.contactsManager) {
                ThreadUtil.sendMessage(withContactShare: sendContact, in: self.thread, messageSender: self.messageSender)
            } else {
                
                Logger.error("can't find local contact")
            }
            
            self.atOrSendContacctVC?.dismissVC()
        }
    }
    
    private var atOrSendContacctVC: ChooseAtMembersViewController? {
        get { viewState.atVC }
        set { viewState.atVC = newValue }
    }
    
    private var atLocation: UInt {
        get { viewState.atLocation }
        set { viewState.atLocation = newValue }
    }
    
    public func chooseAtPeronsCancel() {
        self.inputToolbar.beginEditingMessage()
    }
    
    private func selectAtPerson(
        recipientId: String,
        name: String,
        type: DSKProtoDataMessageMentionType
    ) {
        // 是否需要 * 后缀：
        // 1.在群组中 @自己 不带
        // 2.在私聊中 @自己 和对方不带，其他人带
        var needExternalSuffix = true
        if let localNumber = TSAccountManager.localNumber(), localNumber == recipientId {
            needExternalSuffix = false
        } else {
            if self.isGroupConversation {
                let isGroupMember = type == .internal
                needExternalSuffix = !isGroupMember
            } else {
                needExternalSuffix = self.thread.contactIdentifier() != recipientId
            }
        }
        
        var tmpMessageText = self.inputToolbar.messageBodyForSending ?? ""
        var atName = !name.isEmpty ? name : recipientId
        if needExternalSuffix {
            atName = atName + kMentionExternalSuffix
        }
        // TODO: Jaymin 待验证
        let availableLocation = min(Int(self.atLocation), tmpMessageText.count)
        let index = tmpMessageText.index(tmpMessageText.startIndex, offsetBy: availableLocation)
        tmpMessageText.insert(contentsOf: "\(atName)\(kMentionEndChar)", at: index)
        let finalMessageText = tmpMessageText
        
        let newLocation = availableLocation + atName.count + 1
        self.inputToolbar.setMessageBody(
            finalMessageText,
            selectRange: NSMakeRange(newLocation, 0),
            animated: false
        )
        
        let item = DTInputAtItem()
        item.uid = recipientId
        item.name = atName
        item.type = type.rawValue
        item.range = NSMakeRange(availableLocation - 1, atName.count + 1)
        self.inputToolbar.atCache.add(item)
        
        self.atOrSendContacctVC?.dismissVC()
        self.inputToolbar.beginEditingMessage()
    }
}

// MARK: - Substring

private extension String {
    // TODO: Jaymin 待验证
    /// truncate String contain emoji by byte size
    func substring(lengthOfBytes: Int) -> String? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        guard data.count >= lengthOfBytes else {
            return nil
        }
        let range: Range<Data.Index> = 0..<lengthOfBytes
        let subdata = data.subdata(in: range)
        var result: String?
        for i in 0..<10 {
            let newRange: Range<Data.Index> = 0..<(subdata.count - i)
            let newSubdata = subdata.subdata(in: newRange)
            if let substring = String(data: newSubdata, encoding: .utf8), !substring.isEmpty {
                result = substring
                break
            }
        }
        if let result {
            let range = result.startIndex..<result.endIndex
            let targetRange = rangeOfComposedCharacterSequences(for: range)
            return String(result[targetRange])
        }
        return result
    }
}
