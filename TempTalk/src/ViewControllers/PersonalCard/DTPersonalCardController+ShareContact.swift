//
//  DTPersonalCardController+ShareContact.swift
//  Signal
//
//  Created by user on 2024/2/20.
//  Copyright © 2024 Difft. All rights reserved.
//


import TTServiceKit

private var DTShareContactThreadsKey: UInt8 = 0

extension DTPersonalCardController: SelectThreadViewControllerDelegate, DTForwardPreviewDelegate {
    
    var currentContact: Contact? {
        guard let recipientId = recipientId else { return nil}
        let contactsManager = Environment.shared.contactsManager
        if let account = contactsManager?.signalAccount(forRecipientId: recipientId ), 
            let contact = account.contact {
            return contact
        }
        return Contact(recipientId: recipientId)
    }
    
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        guard let recipientId = self.recipientId, let messageType = Localized("FORWARD_MESSAGE_CONTACT_TYPE", "") else {return ""}
        let shareContactName = Environment.shared.contactsManager.contactOrProfileName(forPhoneIdentifier: recipientId)
        let overviewMessage = "[\(messageType)] \(shareContactName)"
        return overviewMessage
    }
    
    @objc func showSelectThreadController() {
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
        self.present(selectThreadNav, animated: true, completion: nil)
    }
    
    func requestAddFriend() {
        AddFriendHandler.handleRequestAddFriend(identifier: account.recipientId,
                                                sourceType: .inUserCard,
                                                sourceConversationID: nil,
                                                shareContactCardUId: nil,
                                                action: nil,
                                                failure:  { errorString in
            OWSLogger.error("ask friend error in personal card error: \(errorString)")
        })
    }
    
    //MARK: SelectThreadViewControllerDelegate
    func threadsWasSelected(_ threads: [TSThread]) {
        assert(threads.count > 0)
        assert(self.presentedViewController != nil)
        self.targetThreads = threads
        let forwardPreviewVC = DTForwardPreviewViewController()
        forwardPreviewVC.modalPresentationStyle = .overFullScreen
        forwardPreviewVC.delegate = self
        self.presentedViewController?.present(forwardPreviewVC, animated: false, completion: nil)
    }
    
    func forwordThreadCanBeSelested(_ thread: TSThread) -> Bool {
        TSThreadPermissionHelper.checkCanSpeakAndToastTipMessage(thread)
    }
    
    func canSelectBlockedContact() -> Bool {
        return false
    }
    
    //MARK: DTForwardPreviewDelegate
    func getThreadsToForwarding() -> [TSThread] {
        if let targetThreads = self.targetThreads , !targetThreads.isEmpty {
            return targetThreads
        }
        return []
    }
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        guard let currentContact = currentContact else {return}
        guard let sendContact = OWSContacts.contact(forLocalContact: currentContact, contactsManager: Environment.shared.contactsManager) else {
            return
        }
        if let targetThreads = targetThreads {
            for thread in targetThreads {
                if let contactThread = thread as? TSContactThread {
                    ThreadUtil.addThread(toProfileWhitelistIfEmptyContactThread: contactThread)
                }
            }
        }

        let finalLeaveMessage = leaveMessage?.stripped
        
        let sendLeaveMessage = finalLeaveMessage != nil && finalLeaveMessage!.count > 0
        let messageSender = Environment.shared.messageSender
        let group = DispatchGroup()
        DispatchQueue.global().async {
            self.targetThreads?.forEach { thread in
                group.enter()
               let _ = DispatchQueue.main.sync {
                    ThreadUtil.sendMessage(withContactShare: sendContact, in: thread, messageSender: messageSender) { error in
                        if let error = error {
                            Logger.error("\(error.localizedDescription)")
                        }
                    }
                    
                }
                Thread.sleep(forTimeInterval: 0.05)
                group.leave()
                
                if sendLeaveMessage {
                    group.enter()
                    let _ = DispatchQueue.main.sync {
                        ThreadUtil.sendMessage(withText: finalLeaveMessage!, atPersons: nil, mentions: nil, in: thread, quotedReplyModel: nil, messageSender: messageSender) {
                            
                        } failure: { error in
                            Logger.error("\(error.localizedDescription)")
                        }
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                    group.leave()
                }
            }
            
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", "Sent"), durationTime: 1.5)
                }
            }
        }
    }
}
