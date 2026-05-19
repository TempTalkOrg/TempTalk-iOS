//
//  ConversationOutgoingMessageCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

class ConversationOutgoingMessageCell: ConversationMessageCell {
    
    @objc
    static let reuseIdentifier = "ConversationOutgoingMessageCell"
    
    private var sendFailedBadgeView: UIImageView?
    private var sendFailedLeftView: UIImageView?
    private var audioControlButton: UIView?
    
    // MARK: - Override
    
    override func setupLayout() {
        messageContainerView.addSubview(readStatusImageView)
        
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
        
        msgVStackView.alignment = .trailing
        msgVStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview().offset(-8)
            make.leading.greaterThanOrEqualToSuperview().offset(fixedMsgVStackViewLeading(leading: 52))
        }
        
        messageBubbleView.snp.makeConstraints { make in
            make.height.equalTo(0)
        }
        
        readStatusImageView.snp.makeConstraints { make in
            make.width.height.equalTo(ConversationOutgoingMessageRenderItem.readStatusImageSize)
            make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
            make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
        }
        
        footerTimeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(readStatusImageView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace/2.0)
            make.centerY.equalTo(readStatusImageView.snp.centerY)
        }

        confidentialIconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
            make.trailing.equalTo(footerTimeLabel.snp.leading).offset(-5)
            make.centerY.equalTo(footerTimeLabel.snp.centerY)
        }
        
    }
    
    override func configure(renderItem: ConversationMessageRenderItem) {
        super.configure(renderItem: renderItem)

        footerViewApperanceCommon(renderItem: renderItem)

        updateViewLayout(viewItem: renderItem.viewItem)

        guard let outgoingRenderItem = renderItem as? ConversationOutgoingMessageRenderItem else {
            return
        }
//        configureSendFailureBadgeView(renderItem: outgoingRenderItem)
        configureReadStatusImageView(renderItem: outgoingRenderItem)
        configureAudioControlButton(renderItem: outgoingRenderItem)
        configureSendFailureLeftView(renderItem: outgoingRenderItem)

        // 关联 cell 到 viewItem，以便在音频播放状态改变时更新按钮
        renderItem.viewItem.associateAudioCell(self)
    }
    
    override func multiSelectModeDidChange() {
        contentView.isUserInteractionEnabled = !isMultiSelectMode
        checkButton.isHidden = !isMultiSelectMode
    }
    
    override func refreshTheme() {
        super.refreshTheme()
        if footerView.isHidden {
            readStatusImageView.tintColor = Theme.tthirdColor
            readStatusImageView.titleLable.textColor = Theme.tthirdColor
        } else {
            if renderItem?.viewItem.isConfidentialMessage == true {
                readStatusImageView.tintColor = Theme.tthirdColor
                readStatusImageView.titleLable.textColor = Theme.tthirdColor
            } else {
                readStatusImageView.tintColor = UIColor.white
                readStatusImageView.titleLable.textColor = UIColor.white
            }
        }
    }

    // MARK: - Public Methods

    @objc func refreshAudioControlButton() {
        guard let renderItem = renderItem as? ConversationOutgoingMessageRenderItem else {
            return
        }
        configureAudioControlButton(renderItem: renderItem)
        // 音频控制按钮状态改变后，需要更新失败标记的位置
        configureSendFailureLeftView(renderItem: renderItem)
    }
    
    // MARK: - Actions
    
    @objc private func readStatusImageViewDidClick() {
        guard let viewItem = renderItem?.viewItem else { return }
        delegate?.messageCell?(self, didTapReadStatusWith: viewItem)
    }
    
    @objc private func sendFailedBridgeViewDidClick() {
        guard let outgoingMessage = renderItem?.viewItem.interaction as? TSOutgoingMessage else {
            return
        }
        delegate?.messageCell?(self, didTapFailedOutgoingMessage: outgoingMessage)
    }
    
    // MARK: - Lazy Load
    
    private lazy var readStatusImageView: DTImageView = {
        let view = DTImageView()
        view.isHidden = true
        view.titleLable.font = .boldSystemFont(ofSize: 7)
        view.tapBlock = { [weak self] _ in
            guard let self else { return }
            self.readStatusImageViewDidClick()
        }
        return view
    }()
}

extension ConversationOutgoingMessageCell {
    
    private func updateViewLayout(viewItem: ConversationViewItem) {

        if footerView.isHidden {

            var readImageSize: CGFloat = 0
            if let outgoingRenderItem = renderItem as? ConversationOutgoingMessageRenderItem, outgoingRenderItem.shouldDisplaySendFailedBadge {
                readImageSize = 0
            } else {
                readImageSize = ConversationOutgoingMessageRenderItem.readStatusImageSize
            }

            readStatusImageView.snp.remakeConstraints { make in
                make.width.height.equalTo(readImageSize)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
            }

            if !footerTimeLabel.isHidden {
                footerTimeLabel.snp.remakeConstraints { make in
                    make.trailing.equalTo(readStatusImageView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace/2.0)
                    make.centerY.equalTo(readStatusImageView.snp.centerY)
                }
            }

            if !confidentialIconView.isHidden {
                let anchorView = footerTimeLabel.isHidden ? readStatusImageView : footerTimeLabel
                confidentialIconView.snp.remakeConstraints { make in
                    make.width.height.equalTo(20)
                    make.trailing.equalTo(anchorView.snp.leading).offset(-5)
                    make.centerY.equalTo(readStatusImageView.snp.centerY)
                }
            }

        } else {

            var leadingView: UIView = readStatusImageView
            if !footerTimeLabel.isHidden {
                leadingView = footerTimeLabel
            }

            footerView.snp.remakeConstraints { make in
                make.leading.equalTo(leadingView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.height.equalTo(CVMessageFooterRenderItem.footerViewHeight)
            }

            readStatusImageView.snp.remakeConstraints { make in
                make.width.height.equalTo(ConversationOutgoingMessageRenderItem.readStatusImageSize)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace*2.0)
                make.centerY.equalTo(footerView.snp.centerY)
            }

            if !footerTimeLabel.isHidden {
                footerTimeLabel.snp.remakeConstraints { make in
                    make.trailing.equalTo(readStatusImageView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace/2.0)
                    make.centerY.equalTo(footerView.snp.centerY)
                }
            }

            if !confidentialIconView.isHidden {
                confidentialIconView.snp.remakeConstraints { make in
                    make.width.height.equalTo(20)
                    make.trailing.equalTo(footerView.snp.leading).offset(-5)
                    make.centerY.equalTo(footerView.snp.centerY)
                }
            }

        }
    }
    
    private func configureSendFailureBadgeView(renderItem: ConversationOutgoingMessageRenderItem) {
        guard renderItem.shouldDisplaySendFailedBadge else {
            if let sendFailedBadgeView, !sendFailedBadgeView.isHidden {
                sendFailedBadgeView.isHidden = true
            }
            return
        }
        let badgeView: UIImageView = {
            guard let sendFailedBadgeView else {
                let imageView = UIImageView()
                let image = UIImage(named: "message_status_failed_red")?.withRenderingMode(.alwaysTemplate)
                imageView.image = image
                imageView.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(sendFailedBridgeViewDidClick))
                imageView.addGestureRecognizer(tap)
                messageContainerView.addSubview(imageView)
                if footerView.isHidden {
                    imageView.snp.remakeConstraints { make in
                        make.width.height.equalTo(ConversationOutgoingMessageRenderItem.readStatusImageSize)
                        make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
                        make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
                    }
                } else {
                    imageView.snp.remakeConstraints { make in
                        make.width.height.equalTo(ConversationOutgoingMessageRenderItem.readStatusImageSize)
                        make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace*2.0)
                        make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace*1.5)
                    }
                }
                
                self.sendFailedBadgeView = imageView
                return imageView
            }
            return sendFailedBadgeView
        }()
        badgeView.isHidden = false
        badgeView.tintColor = .ows_destructiveRed
    }
    
    private func configureSendFailureLeftView(renderItem: ConversationOutgoingMessageRenderItem) {
        guard renderItem.shouldDisplaySendFailedBadge else {
            if let sendFailedLeftView, !sendFailedLeftView.isHidden {
                sendFailedLeftView.isHidden = true
            }
            return
        }
        let badgeView: UIImageView = {
            guard let sendFailedLeftView else {
                let imageView = UIImageView()
                let image = UIImage(named: "Conversation_send_failed")?.withRenderingMode(.alwaysTemplate)
                imageView.image = image
                imageView.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(sendFailedBridgeViewDidClick))
                imageView.addGestureRecognizer(tap)
                contentView.addSubview(imageView)

                self.sendFailedLeftView = imageView
                return imageView
            }
            return sendFailedLeftView
        }()

        // 根据音频控制按钮的状态来调整失败标记的位置
        let viewItem = renderItem.viewItem
        let isAudioMessage = viewItem.messageCellType() == .audio
        let isAudioPlaying = viewItem.audioPlaybackState() == .playing

        badgeView.snp.remakeConstraints { make in
            make.size.width.height.equalTo(16)
            if isAudioMessage && isAudioPlaying, let audioControlButton = self.audioControlButton, !audioControlButton.isHidden {
                // 音频消息且控制按钮显示时，失败标记在控制按钮左边
                make.trailing.equalTo(audioControlButton.snp.leading).offset(-8)
            } else {
                // 其他情况，失败标记在气泡左边
                make.trailing.equalTo(messageBubbleView.snp.leading).offset(-8)
            }
            make.centerY.equalTo(messageBubbleView)
        }

        badgeView.isHidden = false
        badgeView.tintColor = .ows_destructiveRed
    }
    
    private func configureReadStatusImageView(renderItem: ConversationOutgoingMessageRenderItem) {
        guard renderItem.shouldDisplayReadStatusImageView, let statusImageName = renderItem.readStatusImageName else {
            readStatusImageView.isHidden = true
            return
        }

        readStatusImageView.isHidden = false
        readStatusImageView.image = .init(named: statusImageName)?.withRenderingMode(.alwaysTemplate)
        readStatusImageView.tintColor = Theme.tthirdColor
        readStatusImageView.titleLable.textColor = Theme.tinfoColor
        readStatusImageView.titleLable.text = renderItem.readStatusTitle
        readStatusImageView.isUserInteractionEnabled = renderItem.isReadStatusImageViewInteractionEnabled

        if renderItem.isShowReadStatusSpinning {
//            readStatusImageView.showSpinning()
        }
    }

    private func configureAudioControlButton(renderItem: ConversationOutgoingMessageRenderItem) {
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

                // Outgoing: 按钮在音频的左边（气泡左边），与 incoming 对称
                button.snp.makeConstraints { make in
                    make.width.equalTo(36)
                    make.height.equalTo(24)
                    make.trailing.equalTo(messageBubbleView.snp.leading).offset(-8)
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
    
    // Note: 需要保证气泡左边距 = leading，父容器左边距需要减去 readStatusImage 的距离
    private func fixedMsgVStackViewLeading(leading: CGFloat) -> CGFloat {
        min(0, leading - ConversationMessageRenderItem.msgVStackViewSpacing - ConversationOutgoingMessageRenderItem.readStatusImageSize)
    }
}

extension DTImageView {
    func showSpinning() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.toValue = NSNumber(value: Double.pi * 2.0)
        animation.duration = 1
        animation.isCumulative = true
        animation.repeatCount = Float.infinity
        layer.add(animation, forKey: "animation")
    }
}
