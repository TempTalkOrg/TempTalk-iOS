//
//  ConversationMessageRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/15.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

// MARK: - Message Render Item (Base Class)

class ConversationMessageRenderItem: ConversationCellRenderItem {
    
    static let msgVStackViewSpacing: CGFloat = 8
    
    var headerRenderItem: CVMessageHeaderRenderItem?
    var messageBubbleRenderItem: CVMessageBubbleRenderItem?
    var translateRenderItem: CVTranslateRenderItem?
    
    override func configure() {
        configureForHeaderView()
        configureForMessageBubbleView()
        configureForTranslateView()
    }
    
    private func configureForHeaderView() {
        if viewItem.hasCellHeader {
            self.headerRenderItem = CVMessageHeaderRenderItem(
                viewItem: viewItem,
                conversationStyle: conversationStyle
            )
        }
    }
    
    private func configureForMessageBubbleView() {
        messageBubbleRenderItem = CVMessageBubbleRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle
        )
    }
    
    private func configureForTranslateView() {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        guard message is TSIncomingMessage || message is TSOutgoingMessage else {
            return
        }
        guard viewItem.shouldShowTranslateView(), !viewItem.isUseForMessageList else {
            return
        }
        self.translateRenderItem = CVTranslateRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle
        )
    }
}

// MARK: - Incoming Message Render Item

class ConversationIncomingMessageRenderItem: ConversationMessageRenderItem {
    
    static let avatarSize: CGFloat = 36
    static let senderNameViewHeight: CGFloat = 20
    static let skipToOriginIconWidth: CGFloat = 15
    
    // senderNameView
    var isShowSenderNameView = false
    var senderName: NSAttributedString?
    var senderNameId: String = .empty
    var senderNameAuthorId: String = .empty
    
    let couldShowSkipToOriginIcon: Bool
    
    var recipientId: String? {
        if let incomingMessage = viewItem.interaction as? TSIncomingMessage {
            return incomingMessage.authorId
        }
        return TSAccountManager.sharedInstance().localNumber()
    }
    
    var authorId: String? {
        guard let incomingMessage = viewItem.interaction as? TSIncomingMessage else {
            return nil
        }
        return incomingMessage.authorId
    }
    
    var authorName: String? {
        guard let authorId else {
            return nil
        }
        return Environment.shared.contactsManager.nameFromSystemContacts(forRecipientId: authorId)
    }
    
    override init(viewItem: any ConversationViewItem, conversationStyle: ConversationStyle) {
        var newStyle = conversationStyle
        couldShowSkipToOriginIcon = viewItem.isUseForMessageList && viewItem.isPinned
        
        // 在需要展示 skip 按钮时，messageBubble 的最大宽度需要调整，
        // 在这里创建一个新的 conversationStyle 并修改 maxMessageWidth，方便后续各种文本高度计算
        // 注意这里使用了深拷贝，防止修改了全局 conversationStyle 的 maxMessageWidth
        if couldShowSkipToOriginIcon {
            let copyStyle = conversationStyle.deepCopy()
            newStyle = copyStyle
            newStyle.maxMessageWidth = floor(conversationStyle.contentWidth - Self.skipToOriginIconWidth - Self.msgVStackViewSpacing)
        }
        
        super.init(viewItem: viewItem, conversationStyle: newStyle)
    }
    
    override func configure() {
        super.configure()
        
        configureForSenderNameView()
        
        self.viewSize = measureSize()
    }
    
    override func dequeueCell(for collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: ConversationIncomingMessageCell.reuseIdentifier, for: indexPath)
    }
    
    func autoTranslateIfNeeded() {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let shouldTranslate: Bool = {
            // 过滤附件消息
            if (message.body?.count ?? 0) == 0, !message.attachmentIds.isEmpty {
                return false
            }
            // 过滤任务、投票、多人转发消息
            if message.isMultiForward() {
                return false
            }
            // 已经翻译过成功的的历史消息保持原状态，不自动处理
            if let translateMessage = message.translateMessage,
               !translateMessage.translateLanguageEqualTo(.unknow),
               translateMessage.translateStateEqualTo(.sucessed) {
                return false
            }
            // 附件类型的翻译失败不自动处理
            if !message.attachmentIds.isEmpty {
                return false
            }
            if viewItem.hasAutoRetryTranslate {
                return false
            }
            return true
        }()
        
        let thread = viewItem.thread
        if shouldTranslate {
            viewItem.hasAutoRetryTranslate = true
            databaseStorage.asyncWrite { transaction in
                DTTranslateProcessor.sharedInstance().handleMessageForPreTranslateAfterScroll(
                    with: thread,
                    message: message,
                    transaction: transaction
                )
                
                Logger.debug("[Translate] -1- add operation message: \(message.body ?? "")")
                
                DTTranslateProcessor.sharedInstance().handleMessageForTranslate(
                    with: thread,
                    message: message
                )
            }
        }
    }

    private func configureForSenderNameView() {
        guard let senderName = viewItem.senderName,
              !senderName.isEmpty,
              viewItem.isFirstInCluster,
              let incomingMessage = viewItem.interaction as? TSIncomingMessage else {
            
            self.isShowSenderNameView = false
            return
        }
        
        self.isShowSenderNameView = true
        self.senderName = senderName
        self.senderNameId = viewItem.thread.uniqueId
        self.senderNameAuthorId = incomingMessage.authorId
    }
    
    private func measureSize() -> CGSize {
        var height: CGFloat = .zero
        if let headerRenderItem {
            height += headerRenderItem.viewSize.height
        }
        
        if isShowSenderNameView {
            height += Self.avatarSize + Self.msgVStackViewSpacing
        }
        
        if let messageBubbleViewHeight = messageBubbleRenderItem?.viewSize.height {
            height += messageBubbleViewHeight
        }
        
        if let translateViewHeight = translateRenderItem?.viewSize.height, translateViewHeight > 0 {
            height += translateViewHeight + Self.msgVStackViewSpacing
        }
        
//        if let footerViewHeight = footerRenderItem?.viewSize.height, footerViewHeight > 0 {
//            height += footerViewHeight + Self.msgVStackViewSpacing
//        }
        
        return CGSizeCeil(CGSizeMake(conversationStyle.viewWidth, height))
    }
}

// MARK: - Outgoing Message Render Item

class ConversationOutgoingMessageRenderItem: ConversationMessageRenderItem {
    
    static let readStatusImageSize: CGFloat = 12
    
    var shouldDisplaySendFailedBadge = false
    
    var shouldDisplayReadStatusImageView = false
    var readStatusTitle: String?
    var readStatusImageName: String?
    var isReadStatusImageViewInteractionEnabled = false
    var isShowReadStatusSpinning = false
    
    override func configure() {
        super.configure()
        
        self.shouldDisplaySendFailedBadge = {
            guard let outgoingMessage = viewItem.interaction as? TSOutgoingMessage else {
                return false
            }
            return outgoingMessage.messageState == .failed
        }()
        
        configureForReadStatusImageView()
        
        self.viewSize = measureSize()
    }
    
    override func dequeueCell(for collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: ConversationOutgoingMessageCell.reuseIdentifier, for: indexPath)
    }
    
    private func configureForReadStatusImageView() {
        guard !shouldDisplaySendFailedBadge else {
            shouldDisplayReadStatusImageView = false
            return
        }
        guard !viewItem.isUseForMessageList else {
            shouldDisplayReadStatusImageView = false
            return
        }
        guard let outgoingMessage = viewItem.interaction as? TSOutgoingMessage else {
            shouldDisplayReadStatusImageView = false
            return
        }
        shouldDisplayReadStatusImageView = true
        
        let messageStatus = MessageRecipientStatusUtils.recipientStatus(outgoingMessage: outgoingMessage)
        switch messageStatus {
        case .uploading, .sending:
            readStatusImageName = "conversation_sending"
            readStatusTitle = ""
            isReadStatusImageViewInteractionEnabled = false
            isShowReadStatusSpinning = true
            
        case .sent, .skipped, .delivered:
            let thread = viewItem.thread
            if thread.isWithoutReadRecipt() {
                readStatusImageName = "message_status_sent"
                isReadStatusImageViewInteractionEnabled = false
            } else {
                if viewItem.isGroupThread {
                    readStatusImageName = "message_status_read_one"
                    isReadStatusImageViewInteractionEnabled = true
                    
                } else if let localNumber = TSAccountManager.localNumber(), outgoingMessage.recipientIds().contains(localNumber) {
                    readStatusImageName = "message_status_sent"
                    isReadStatusImageViewInteractionEnabled = false
                    
                } else {
                    readStatusImageName = "message_status_read_one"
                    isReadStatusImageViewInteractionEnabled = false
                }
            }
            readStatusTitle = ""
            isShowReadStatusSpinning = false
            
        case .read:
            let thread = viewItem.thread
            if thread.isWithoutReadRecipt() {
                readStatusImageName = "message_status_sent"
                readStatusTitle = ""
                isReadStatusImageViewInteractionEnabled = false
            } else {
                if viewItem.isGroupThread {
                    let hasReadCount = outgoingMessage.readRecipientIds().count
                    if hasReadCount == outgoingMessage.recipientIds().count {
                        readStatusImageName = "message_status_sent"
                        readStatusTitle = ""
                    } else if hasReadCount > 99 {
                        readStatusImageName = "message_status_read_more"
                        readStatusTitle = ""
                    } else {
                        readStatusImageName = "message_status_read_one"
                        readStatusTitle = "\(hasReadCount)"
                    }
                    isReadStatusImageViewInteractionEnabled = true
                    
                } else {
                    readStatusImageName = "message_status_sent"
                    readStatusTitle = ""
                    isReadStatusImageViewInteractionEnabled = false
                }
            }
            isShowReadStatusSpinning = false
            
        default:
            readStatusImageName = nil
            readStatusTitle = ""
            isReadStatusImageViewInteractionEnabled = false
            isShowReadStatusSpinning = false
        }
    }
    
    private func measureSize() -> CGSize {
        var height: CGFloat = .zero
        
        if let headerViewHeight = headerRenderItem?.viewSize.height {
            height += headerViewHeight
        }
        
        if let messageBubbleViewHeight = messageBubbleRenderItem?.viewSize.height {
            height += messageBubbleViewHeight
        }
        
        if let translateViewHeight = translateRenderItem?.viewSize.height, translateViewHeight > 0 {
            height += translateViewHeight + Self.msgVStackViewSpacing
        }
        
//        if let footerViewHeight = footerRenderItem?.viewSize.height, footerViewHeight > 0 {
//            height += footerViewHeight + Self.msgVStackViewSpacing
//        }
        
        return CGSizeCeil(CGSizeMake(conversationStyle.viewWidth, height))
    }
}
