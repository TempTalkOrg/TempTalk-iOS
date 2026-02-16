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

    private var audioControlButton: UIView?
    
    // MARK: - Override
    
    override func setupLayout() {
        avatarAroundView = avatarView
        messageContainerView.addSubview(avatarView)
        messageContainerView.addSubview(senderNameView)
        
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
            // Bubble below avatar with 4pt spacing (to match accountViewHeight)
            make.top.equalTo(avatarView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(ConversationIncomingMessageRenderItem.leadingPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-ConversationIncomingMessageRenderItem.trailingPadding)
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
        autoTranslateIfNeeded(renderItem: incomingRenderItem)
        configureAudioControlButton(renderItem: incomingRenderItem)

        // 关联 cell 到 viewItem，以便在音频播放状态改变时更新按钮
        renderItem.viewItem.associateAudioCell(self)
    }
    
    override func multiSelectModeDidChange() {
        contentView.isUserInteractionEnabled = !isMultiSelectMode
        checkButton.isHidden = !isMultiSelectMode
        messageContainerView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(isMultiSelectMode ? 32 : 0)
            make.trailing.equalToSuperview().offset(isMultiSelectMode ? 32 : 0)
        }
    }
    
    override func refreshTheme() {
        super.refreshTheme()
        
        if !senderNameView.isHidden {
            senderNameView.nameColor = Theme.tthirdColor
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
        view.nameFont = .ows_dynamicTypeCaption1
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
            // Bubble below avatar with 4pt spacing (to match accountViewHeight)
            make.top.equalTo(avatarView.snp.bottom).offset(4)
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

// MARK: - Audio Control Button

extension ConversationIncomingMessageCell {
    @objc func refreshAudioControlButton() {
        guard let renderItem = renderItem as? ConversationIncomingMessageRenderItem else {
            return
        }
        configureAudioControlButton(renderItem: renderItem)
    }

    private func configureAudioControlButton(renderItem: ConversationIncomingMessageRenderItem) {
        // 检查是否是音频消息
        let viewItem = renderItem.viewItem
        guard viewItem.messageCellType() == .audio else {
            if let audioControlButton, !audioControlButton.isHidden {
                audioControlButton.isHidden = true
            }
            return
        }

        // 检查是否正在播放音频
        let isAudioPlaying = viewItem.audioPlaybackState() == .playing

        let controlButton: UIView = {
            guard let audioControlButton else {
                let button = UIView()
                button.layer.backgroundColor = Theme.bg4Color.cgColor
                button.layer.cornerRadius = 12
                button.translatesAutoresizingMaskIntoConstraints = false
                button.isUserInteractionEnabled = true
                contentView.addSubview(button)

                // 添加速度标签
                let label = UILabel()
                label.font = .systemFont(ofSize: 12, weight: .regular)
                label.textColor = Theme.tsecondaryColor
                label.textAlignment = .center
                label.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(label)
                label.snp.makeConstraints { make in
                    make.center.equalToSuperview()
                }

                // 添加点击手势
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(audioControlButtonTapped))
                button.addGestureRecognizer(tapGesture)

                // Incoming: 按钮在音频的右边（气泡右边）
                button.snp.makeConstraints { make in
                    make.width.equalTo(36)
                    make.height.equalTo(24)
                    make.leading.equalTo(messageBubbleView.snp.trailing).offset(8)
                    make.centerY.equalTo(messageBubbleView)
                }

                self.audioControlButton = button
                return button
            }
            return audioControlButton
        }()

        // 更新速度标签
        if let label = controlButton.subviews.first as? UILabel {
            let rate = (delegate as? ConversationViewController)?.audioPlaybackRate ?? 1.0
            if rate == 1.0 {
                label.text = "1x"
            } else if rate == 1.5 {
                label.text = "1.5x"
            } else {
                label.text = "2x"
            }
        }

        controlButton.isHidden = !isAudioPlaying
    }

    @objc private func audioControlButtonTapped() {
        guard let conversationVC = delegate as? ConversationViewController else {
            return
        }
        conversationVC.toggleAudioPlaybackRate()
    }
}

