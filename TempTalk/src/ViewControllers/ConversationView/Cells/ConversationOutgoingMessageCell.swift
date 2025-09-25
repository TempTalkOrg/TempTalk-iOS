//
//  ConversationOutgoingMessageCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit

class ConversationOutgoingMessageCell: ConversationMessageCell {
    
    @objc
    static let reuseIdentifier = "ConversationOutgoingMessageCell"
    
    private var sendFailedBadgeView: UIImageView?
    private var sendFailedLeftView: UIImageView?
    
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
        configureSendFailureLeftView(renderItem: outgoingRenderItem)
    }
    
    override func multiSelectModeDidChange() {
        contentView.isUserInteractionEnabled = !isMultiSelectMode
        checkButton.isHidden = !isMultiSelectMode
    }
    
    override func refreshTheme() {
        super.refreshTheme()
        if footerView.isHidden {
            readStatusImageView.tintColor = Theme.ternaryTextColor
            readStatusImageView.titleLable.textColor = Theme.ternaryTextColor
        } else {
            readStatusImageView.tintColor = UIColor.white
            readStatusImageView.titleLable.textColor = UIColor.white
        }
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
            
            footerTimeLabel.snp.remakeConstraints { make in
                make.trailing.equalTo(readStatusImageView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace/2.0)
                make.centerY.equalTo(readStatusImageView.snp.centerY)
            }
            
        } else {
                        
            readStatusImageView.snp.remakeConstraints { make in
                make.width.height.equalTo(ConversationOutgoingMessageRenderItem.readStatusImageSize)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace*2.0)
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace*1.5)
            }
            
            var leadingView: UIView = readStatusImageView
            if !footerTimeLabel.isHidden {
                leadingView = footerTimeLabel
                footerTimeLabel.snp.remakeConstraints { make in
                    make.trailing.equalTo(readStatusImageView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace/2.0)
                    make.centerY.equalTo(readStatusImageView.snp.centerY)
                }
            }
            
            footerView.snp.remakeConstraints { make in
                make.leading.equalTo(leadingView.snp.leading).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.trailing.equalTo(messageBubbleView.snp.trailing).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.bottom.equalTo(messageBubbleView.snp.bottom).offset(-CVMessageFooterRenderItem.footerViewSpace)
                make.height.equalTo(CVMessageFooterRenderItem.footerViewHeight)
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
                
                imageView.snp.remakeConstraints { make in
                    make.size.width.height.equalTo(16)
                    make.trailing.equalTo(messageBubbleView.snp.leading).offset(-8)
                    make.centerY.equalTo(messageBubbleView)
                }
                
                self.sendFailedLeftView = imageView
                return imageView
            }
            return sendFailedLeftView
        }()
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
        readStatusImageView.tintColor = Theme.ternaryTextColor
        readStatusImageView.titleLable.textColor = Theme.themeBlueColor
        readStatusImageView.titleLable.text = renderItem.readStatusTitle
        readStatusImageView.isUserInteractionEnabled = renderItem.isReadStatusImageViewInteractionEnabled
        
        if renderItem.isShowReadStatusSpinning {
//            readStatusImageView.showSpinning()
        }
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
