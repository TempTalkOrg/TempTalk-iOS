//
//  ConversationIncomingMessageCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

class ConversationIncomingMessageCell: ConversationMessageCell {
    
    @objc
    static let reuseIdentifier = "ConversationIncomingMessageCell"
    
    // MARK: - Override
    
    override func setupLayout() {
        avatarAroundView = avatarView
        messageContainerView.addSubview(avatarView)
        messageContainerView.addSubview(senderNameView)
        
        msgMiddleHStackView.addArrangedSubviews([
            skipToOrigionIcon
        ])
        
        contentVStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        messageContainerView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        
        quoteImageView.snp.makeConstraints { make in
            make.size.width.equalTo(25)
            make.size.height.equalTo(25)
            make.left.equalToSuperview().offset(-45)
            make.centerY.equalToSuperview()
        }
        
        checkButton.snp.makeConstraints { make in
            make.width.height.equalTo(16)
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalTo(messageBubbleView)
        }
        
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview()
            make.width.height.equalTo(ConversationIncomingMessageRenderItem.avatarSize)
        }
        
        msgVStackView.alignment = .leading
        msgVStackView.snp.makeConstraints { make in
            make.top.equalTo(avatarView)
            make.leading.equalToSuperview().offset(52)
            make.trailing.lessThanOrEqualToSuperview().offset(-8)
        }
        
        let maxNameWidth = UIScreen.main.bounds.size.width * 3.0 / 4.0
        senderNameView.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.centerY.equalTo(avatarView)
            make.height.equalTo(ConversationIncomingMessageRenderItem.senderNameViewHeight)
            make.width.lessThanOrEqualTo(maxNameWidth)
        }
        
        messageBubbleView.snp.makeConstraints { make in
            make.height.equalTo(0)
        }
        
        footerTimeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
            make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
        }
    }
    
    override func configure(renderItem: ConversationMessageRenderItem) {
        super.configure(renderItem: renderItem)
        
        configureMsgVStackViewMargin(style: renderItem.conversationStyle)
        
        if footerTimeLabel.isHidden {
            footerViewApperanceCommon(isHidden: true)
        } else {
            footerViewApperanceCommon(renderItem: renderItem)
        }
                
        updateViewLayout(renderItem: renderItem)
        
        guard let incomingRenderItem = renderItem as? ConversationIncomingMessageRenderItem else {
            return
        }
        configureAvatarView(viewItem: incomingRenderItem.viewItem)
        configureSenderNameView(renderItem: incomingRenderItem)
        configureSkipToOrigionIcon(renderItem: incomingRenderItem)
        autoTranslateIfNeeded(renderItem: incomingRenderItem)
    }
    
    override func multiSelectModeDidChange() {
        contentView.isUserInteractionEnabled = !isMultiSelectMode
        checkButton.isHidden = !isMultiSelectMode
        messageContainerView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(isMultiSelectMode ? 32 : 0)
            make.trailing.equalToSuperview().offset(isMultiSelectMode ? 32 : 0)
        }
        
        if let renderItem, let incomingRenderItem = renderItem as? ConversationIncomingMessageRenderItem {
            configureSkipToOrigionIcon(renderItem: incomingRenderItem)
        }
    }
    
    override func refreshTheme() {
        super.refreshTheme()
        
        if !senderNameView.isHidden {
            senderNameView.nameColor = Theme.ternaryTextColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        avatarView.resetForReuse()
        senderNameView.prepareForReuse()
    }
    
    // MARK: - Actions
    
    @objc private func avatarViewDidClick(_ sender: UITapGestureRecognizer) {
        guard let renderItem, let incomingRenderItem = renderItem as? ConversationIncomingMessageRenderItem else {
            return
        }
        guard let recipientId = incomingRenderItem.recipientId else {
            return
        }
        guard !isTouchInHeaderView(gesture: sender) else {
            return
        }
        delegate?.messageCell?(self, didTapAvatarWith: recipientId)
    }
    
    @objc private func avatarViewDidLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }
        guard !isTouchInHeaderView(gesture: sender) else {
            return
        }
        guard let renderItem, let incomingRenderItem = renderItem as? ConversationIncomingMessageRenderItem else {
            return
        }
        guard let authorId = incomingRenderItem.authorId else {
            return
        }
        let name = incomingRenderItem.authorName
        delegate?.messageCell?(self, didLongPressAvatarWith: authorId, senderName: name)
    }
    
    @objc private func skipToOrigionIconDidClick() {
        guard let viewItem = renderItem?.viewItem else { return }
        delegate?.messageCell?(self, didTapSkipToOrigionWith: viewItem)
    }
    
    // MARK: - Lazy Load
    
    private lazy var avatarView: DTAvatarImageView = {
        let view = DTAvatarImageView()
        view.imageForSelfType = .original
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarViewDidClick(_:)))
        view.addGestureRecognizer(tap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(avatarViewDidLongPress(_:)))
        view.addGestureRecognizer(longPress)
        return view
    }()
    
    private lazy var senderNameView: DTConversationNameView = {
        let view = DTConversationNameView()
        view.nameFont = .ows_dynamicTypeCaption2
        return view
    }()
    
    private lazy var skipToOrigionIcon: DTImageView = {
        let view = DTImageView()
        view.alpha = 0
        view.image = .init(named: "ic_pin_skip")
        view.tapBlock = { [weak self] _ in
            guard let self else { return }
            self.skipToOrigionIconDidClick()
        }
        return view
    }()
}

extension ConversationIncomingMessageCell {
    
    private func updateViewLayout(renderItem: ConversationMessageRenderItem) {
                
        if renderItem.viewItem.shouldShowSenderAvatar {
            avatarView.snp.updateConstraints { make in
                make.top.equalToSuperview()
                make.width.height.equalTo(ConversationIncomingMessageRenderItem.avatarSize)
            }
        } else {
            avatarView.snp.updateConstraints { make in
                make.top.equalToSuperview().offset(-8)
                make.width.height.equalTo(0)
            }
        }
        
        
        if footerView.isHidden {
            footerTimeLabel.snp.remakeConstraints { make in
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
            }
        } else {
            
            footerTimeLabel.snp.remakeConstraints { make in
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace*1.5)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace*2)
            }
            footerView.snp.remakeConstraints { make in
                make.leading.equalTo(footerTimeLabel.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.height.equalTo(CVMessageFooterRenderItem.footerViewHeight)
            }
        }
        
    }
    
    private func configureMsgVStackViewMargin(style: ConversationStyle) {
        msgVStackView.snp.remakeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom)
            make.leading.equalToSuperview().offset(style.gutterLeading)
            make.trailing.lessThanOrEqualToSuperview().offset(-style.gutterTrailing)
        }
    }
    
    func configureAvatarView(viewItem: ConversationViewItem) {
        guard viewItem.shouldShowSenderAvatar else {
            avatarView.isHidden = true
            return
        }
        let contactId: String? = {
            if let incomingMessage = viewItem.interaction as? TSIncomingMessage {
                return incomingMessage.authorId
            } else {
                return TSAccountManager.sharedInstance().localNumber()
            }
        }()
        let avatar = viewItem.avatar as? [String: Any]
        avatarView.isHidden = false
        avatarView.setImage(
            avatar: avatar,
            recipientId: contactId,
            displayName: viewItem.displayName,
            completion: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(otherUserProfileDidChange(_:)),
            name: .DTOtherUsersProfileDidChange,
            object: nil
        )
    }
    
    // TODO: Jaymin 待优化
    private func configureSenderNameView(renderItem: ConversationIncomingMessageRenderItem) {
        guard renderItem.isShowSenderNameView else {
            senderNameView.isHidden = true
            return
        }
        senderNameView.isHidden = false
        senderNameView.attributeName = renderItem.senderName
        senderNameView.identifier = renderItem.senderNameId
        
        let authorId = renderItem.senderNameAuthorId
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let thread = renderItem.viewItem.thread
            if thread.isGroupThread() {
                var groupThread: TSGroupThread?
                self.databaseStorage.read { transaction in
                    groupThread = TSGroupThread.anyFetchGroupThread(
                        uniqueId: thread.uniqueId,
                        transaction: transaction
                    )
                }
                self.senderNameView.identifier = authorId
                if let groupThread {
                    self.senderNameView.rapidRole = groupThread.groupModel.rapidRole(for: authorId)
                }
            }
            self.senderNameView.isExternal = SignalAccount.isExt(authorId)
        }
    }
    
    private func configureSkipToOrigionIcon(renderItem: ConversationIncomingMessageRenderItem) {
        let canShow = renderItem.couldShowSkipToOriginIcon
        if canShow {
            skipToOrigionIcon.isHidden = false
            skipToOrigionIcon.alpha = isMultiSelectMode ? 0 : 1
        } else {
            skipToOrigionIcon.isHidden = true
        }
    }
    
    private func autoTranslateIfNeeded(renderItem: ConversationIncomingMessageRenderItem) {
        renderItem.autoTranslateIfNeeded()
    }
}

// MARK: - Notification

extension ConversationIncomingMessageCell {
    @objc func otherUserProfileDidChange(_ notification: Notification) {
        guard let renderItem else { return }
        let viewItem = renderItem.viewItem
        guard viewItem.shouldShowSenderAvatar, viewItem.isGroupThread else {
            return
        }
        guard let incomingMessage = viewItem.interaction as? TSIncomingMessage else {
            return
        }
        guard let recipientId = notification.userInfo?[kNSNotificationKey_ProfileRecipientId] as? String, !recipientId.isEmpty else {
            return
        }
        guard recipientId == incomingMessage.authorId else {
            return
        }
        configureAvatarView(viewItem: viewItem)
    }
}
