//
//  DTCombinedMessageController.swift
//  Wea
//
//  Created by Ethan on 2022/3/15.
//

import UIKit

class DTCombinedMessageController: DTMessageListController {

    var currentCombinedMessage: TSMessage!
    
    var targetThreads: [TSThread]!
    
    var subForwardingMessages: [DTCombinedForwardingMessage]!
    
    var lbTitle: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "ic_forward_large"), style: .plain, target: self, action: #selector(selectMultiForwardTypeAction))
        
        if let message = self.currentCombinedMessage as? TSIncomingMessage, message.messageModeType == .confidential {
            OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(message)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let message = self.currentCombinedMessage as? TSIncomingMessage, message.messageModeType == .confidential else {
            return
        }
        self.databaseStorage.asyncWrite { wTransaction in
            self.currentCombinedMessage.anyRemove(transaction: wTransaction)
        }
    }
    
    func selectMultiForwardTypeAction() {
        
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
        self.present(selectThreadNav, animated: true, completion: nil)
    }
    
    func createNavigationTitle(_ title: String) {

//        let attributeTitle = NSAttributedString(string: title, attributes: UINavigationBar.appearance().titleTextAttributes)
        
        lbTitle = UILabel()
        lbTitle.text = title
        lbTitle.numberOfLines = 2
        lbTitle.textAlignment = .center
        lbTitle.font = .ows_monospacedDigitFont(withSize: 17)
        lbTitle.textColor = Theme.navbarTitleColor
        lbTitle.preferredMaxLayoutWidth = UIScreen.main.bounds.size.width - 100
        
        navigationItem.titleView = lbTitle
    }
    
    override func applyTheme() {
        super.applyTheme()
        lbTitle.textColor = Theme.navbarTitleColor
    }
    
//    override func uiDatabaseWillUpdate(noti: Notification) {}
 
//    override func uiDatabaseDidupdate(noti: Notification) {}
    
    func configure(thread: TSThread, combinedMessage: TSMessage, isGroupChat: Bool) {
        owsAssertDebug(combinedMessage.combinedForwardingMessage != nil)
        
        currentThread = thread
        currentCombinedMessage = combinedMessage
        conversationStyle = ConversationStyle(thread: thread)
        conversationStyle.viewWidth = view.width
        
        createNavigationTitle(DTForwardMessageHelper.combinedForwardingMessageTitle(withIsGroupThread: isGroupChat, combinedMessage: combinedMessage))
        
        subForwardingMessages = combinedMessage.combinedForwardingMessage?.subForwardingMessages
        
        kMessages.removeAll()
        subForwardingMessages.forEach({ subForwardingMessage in
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
        incomingMessage.uniqueId = "\(self.currentCombinedMessage.timestamp)" + "\(subMessage.timestamp)"
        incomingMessage.isPinnedMessage = currentCombinedMessage.isPinnedMessage
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
            item = ConversationInteractionViewItem(sepcialInteraction: message, thread: nil, transaction: transaction, conversationStyle: self.conversationStyle)
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
            var retryActionText: String!
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
        
        self.targetThreads
    }
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        
        let messageSender = Environment.shared?.messageSender
        let group = DispatchGroup()
        var combinedForwardingMessage_: DTCombinedForwardingMessage?
        DispatchQueue.global().async {
            self.targetThreads.forEach { targetThread in
                self.databaseStorage.write { transaction in
                    guard let combinedForwardingMessage = DTCombinedForwardingMessage.buildSingleForwardingMessage(with: self.currentCombinedMessage.combinedForwardingMessage!, transaction: transaction) else {
                        owsFailDebug("combinedForwardingMessage is empty")
                        return
                    }
                    combinedForwardingMessage_ = combinedForwardingMessage
                }
                
                group.enter()
                _ = DispatchQueue.main.sync {
                    ThreadUtil.sendMessage(with: combinedForwardingMessage_!, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender!)
                }
                Thread.sleep(forTimeInterval: 0.05)
                group.leave()
                
                guard let leaveMsg = leaveMessage?.ows_stripped() else {
                    return
                }
                if leaveMsg.isEmpty {
                    return
                }
                group.enter()
                _ = DispatchQueue.main.sync {
                    ThreadUtil.sendMessage(withText: leaveMsg, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender!)
                }
                Thread.sleep(forTimeInterval: 0.05)
                group.leave()
            }
        }
        self.dismiss(animated: true) {
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: "Sent"), durationTime: 1.5)
        }
        
    }
    
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        
        "[\(Localized("FORWARD_MESSAGE_CHAT_HISTORY", comment: ""))]"
    }
    
}
