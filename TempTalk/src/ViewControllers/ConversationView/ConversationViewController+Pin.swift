//
//  ConversationViewController+Pin.swift
//  Signal
//
//  Created by Jaymin on 2024/1/5.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
// MARK: - Public

@objc extension ConversationViewController {
    
    func pinOrUnpinMessage(viewItem: ConversationViewItem) {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        if viewItem.isPinned {
            message.pinId.map { unpinMessage(pinId: $0) }
        } else {
            pinMessage(message)
        }
    }
    
    func pinMessage(_ message: TSMessage) {
        let timestamp = Date.ows_millisecondTimestamp()
        let attachmentIds = NSMutableArray(array: message.attachmentIds)
        let quotedMessage = message.quotedMessage
        let forwardingMessage = message.combinedForwardingMessage
        let contractShare = message.contactShare
        
        let pinOutgoingMessage = TSPinOutgoingMessage(
            outgoingMessageWithTimestamp: timestamp,
            in: self.thread,
            messageBody: nil,
            atPersons: nil,
            mentions: nil,
            attachmentIds: attachmentIds,
            expiresInSeconds: 0,
            expireStartedAt: 0,
            isVoiceMessage: false,
            groupMetaMessage: .messageUnspecified,
            quotedMessage: quotedMessage,
            forwardingMessage: forwardingMessage,
            contactShare: contractShare
        )
        pinOutgoingMessage.pinMessages = [message]
        
        messageSender.enqueue(pinOutgoingMessage) {
        } failure: { error in
            DispatchMainThreadSafe {
                DTToastHelper.toast(withText: error.localizedDescription, durationTime: 1.5)
            }
        }
    }
    
    func unpinMessage(pinId: String) {
        guard let serverGroupId = self.serverGroupId else { return }
        
        pinAPI.unpinMessages([pinId], gid: serverGroupId) { [weak self] entity in
            
            guard let self else { return }
            self.databaseStorage.asyncWrite { transaction in
                let localPinned = DTPinnedMessage.anyFetch(uniqueId: pinId, transaction: transaction)
                localPinned?.removePinMessage(with: transaction)
            }
            
        } failure: { error in
            DTToastHelper.toast(withText: Localized("UNPIN_MESSAGE_FAILED", ""), durationTime: 1)
        }
    }
    
    func resetPinnedMappings(animated: Bool) {
        guard self.thread.isGroupThread() else {
            return
        }
        
        let localPinned = DTPinnedDataSource.shared().localPinnedMessages(withGroupId: self.serverGroupId)
        viewState.pinMessages = localPinned?.map { $0.contentMessage } ?? []
        
        if let localPinned, !localPinned.isEmpty {
            if !isShowingPinView {
                isShowingPinView = true
                addPinView(animated: animated)
            }
            pinView.reloadData()
        } else {
            if isShowingPinView {
                isShowingPinView = false
                removePinView()
            }
        }
    }
    
    func scrollToOrigionMessage(realSource: DTRealSourceEntity) {
        databaseStorage.uiRead { transaction in
            if let interaction = ThreadUtil.findInteractionInThread(
                byTimestamp: realSource.timestamp,
                authorId: realSource.source,
                threadUniqueId: self.thread.uniqueId,
                transaction: transaction
            ) {
                self.conversationViewModel.ensureLoadWindowContainsInteractionId(
                    interaction.uniqueId,
                    transaction: transaction
                ) { [weak self] indexPath in
                    guard let self else { return }
                    guard let indexPath, indexPath.row < self.dataSource.snapshot().numberOfItems else {
                        return
                    }
                    self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
                }
            }
        }
    }
    
    func applyThemeForPinView() {
        guard let pinView = viewState.pinView else {
            return
        }
        pinView.applyTheme()
    }
}

// MARK: - Private

private extension ConversationViewController {
    
    var pinView: DTConversationPinView {
        if let view = viewState.pinView {
            return view
        }
        let newView = DTConversationPinView()
        newView.delegate = self
        viewState.pinView = newView
        return newView
    }
    
    var pinAPI: DTGroupPinAPI {
        if let api = viewState.pinAPI {
            return api
        }
        let newAPI = DTGroupPinAPI()
        viewState.pinAPI = newAPI
        return newAPI
    }
    
    var isShowingPinView: Bool {
        get { viewState.isShowingPinView }
        set { viewState.isShowingPinView = newValue }
    }
    
    func addPinView(animated: Bool) {
        var edgeInsets = collectionView.contentInset
        edgeInsets.top += 50
        pinView.add(toSuperview: view, animated: animated) { [weak self] in
            guard let self else { return }
            self.collectionView.contentInset = edgeInsets
            self.collectionView.scrollIndicatorInsets = edgeInsets
        }
    }
    
    func removePinView() {
        var edgeInsets = collectionView.contentInset
        edgeInsets.top -= 50
        pinView.removeHandler { [weak self] in
            guard let self else { return }
            self.collectionView.contentInset = edgeInsets
            self.collectionView.scrollIndicatorInsets = edgeInsets
        }
    }
    
    func getAuthorId(from pinMessage: TSMessage) -> String? {
        var authorId: String?
        if pinMessage.isKind(of: TSOutgoingMessage.self) {
            authorId = TSAccountManager.localNumber()
        } else if let message = pinMessage as? TSIncomingMessage {
            authorId = message.authorId
        }
        return authorId
    }
    
    func shouldScrollToOrigionMessage(pinMessage: TSMessage) -> Bool {
        guard let authorId = getAuthorId(from: pinMessage) else {
            return false
        }
        var targetInteraction: TSInteraction?
        databaseStorage.read { readTransaction in
            targetInteraction = ThreadUtil.findInteractionInThread(
                byTimestamp: pinMessage.timestamp,
                authorId: authorId,
                threadUniqueId: self.thread.uniqueId,
                transaction: readTransaction
            )
        }
        guard let _ = targetInteraction else {
            return false
        }
        return true
    }
    
    func scrollToOrigionMessage(pinMessage: TSMessage) {
        guard let authorId = getAuthorId(from: pinMessage) else {
            return
        }
        let realSource = DTRealSourceEntity(
            sourceWithTimestamp: pinMessage.timestamp,
            sourceDevice: 0,
            source: authorId
        )
        scrollToOrigionMessage(realSource: realSource)
    }
}

// MARK: - DTConversationPinDelegate

extension ConversationViewController: DTConversationPinDelegate {
    public func pinnedMessagesForPreview() -> [TSMessage] {
        return viewState.pinMessages
    }
    
    public func pinView(_ pinView: DTConversationPinView, didSelect index: UInt) {
        guard index < viewState.pinMessages.count else {
            return
        }
        let pinMessage = viewState.pinMessages[Int(index)]
        if shouldScrollToOrigionMessage(pinMessage: pinMessage) {
            scrollToOrigionMessage(pinMessage: pinMessage)
        } else {
            rightItemAction(of: pinView)
        }
    }
    
    public func rightItemAction(of pinView: DTConversationPinView) {
        guard !viewState.pinMessages.isEmpty else {
            return
        }
        
        let pinnedMessageVC = DTPinnedMessageController()
        pinnedMessageVC.shouldUseTheme = true
        pinnedMessageVC.configure(thread: self.thread)
        pinnedMessageVC.skipToOrigionMessageHandler = { [weak self] message in
            guard let self else { return }
            if self.shouldScrollToOrigionMessage(pinMessage: message) {
                self.presentedViewController?.dismiss(animated: true, completion: {
                    self.scrollToOrigionMessage(pinMessage: message)
                })
            } else {
                DTToastHelper.toast(
                    withText: Localized("PIN_MESSAGE_ORIGION_NOT_EXIST", ""),
                    durationTime: 1
                )
            }
        }
        let nav = OWSNavigationController(rootViewController: pinnedMessageVC)
        present(nav, animated: true)
    }
}
