//
//  ConversationQuotedMessageView.swift
//  Difft
//
//  Created by Jaymin on 2024/8/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SnapKit
import TTMessaging

protocol ConversationQuotedMessageViewDelegate: AnyObject {
    func quotedMessageView(
        _ quotedMessageView: ConversationQuotedMessageView,
        didTapDownloadFailedThumbnailWith attachmentPointer: TSAttachmentPointer,
        replyModel: OWSQuotedReplyModel
    )
}

class ConversationQuotedMessageView: UIView, Themeable {
    
    private lazy var innerBubbleView = OWSLayerView(frame: .zero, layoutCallback: { _ in })
    
    private lazy var stripeView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 2
        view.layer.masksToBounds = true
        view.setContentHuggingHigh()
        view.setCompressionResistanceHigh()
        return view
    }()
    
    private lazy var hStackVeiw: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = CVQuotedMessageRenderItem.hSpacing
        stackView.layoutMargins = .init(top: 0, left: 4, bottom: 0, right: 4)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()

    private lazy var vStackVeiw: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.layoutMargins = .init(
            top: CVQuotedMessageRenderItem.textVMargin,
            left: 0,
            bottom: CVQuotedMessageRenderItem.textVMargin,
            right: 0
        )
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.spacing = CVQuotedMessageRenderItem.vSpacing
        return stackView
    }()
    
    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_dynamicTypeSubheadline.ows_italic()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingVerticalHigh()
        label.setContentHuggingHorizontalLow()
        label.setCompressionResistanceHorizontalLow()
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var quotedTextLabel: UILabel = {
        let label = UILabel()
        label.setContentHuggingLow()
        label.setCompressionResistanceLow()
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private lazy var attachmentContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.setContentHuggingHigh()
        view.setCompressionResistanceHigh()
        return view
    }()
    
    private lazy var backgroundContainerView: UIView = {
        let view = UIView()
        // 设置背景颜色和圆角
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        return view
    }()
    
    private var renderItem: CVQuotedMessageRenderItem?
    
    weak var delegate: ConversationQuotedMessageViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        isUserInteractionEnabled = true
        layoutMargins = .zero
        clipsToBounds = true
        
        addSubview(innerBubbleView)
        innerBubbleView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(CVQuotedMessageRenderItem.bubbleMargin)
            make.trailing.equalToSuperview().offset(-CVQuotedMessageRenderItem.bubbleMargin)
        }
        
        innerBubbleView.addSubview(hStackVeiw)
        hStackVeiw.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 添加 backgroundContainerView 到 hStackVeiw
        hStackVeiw.addArrangedSubview(backgroundContainerView)
        backgroundContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backgroundContainerView.addSubview(stripeView)
        stripeView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(CVQuotedMessageRenderItem.stripeThickness)
        }
        
        attachmentContainerView.isHidden = true
        backgroundContainerView.addSubview(attachmentContainerView)
        attachmentContainerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(CVQuotedMessageRenderItem.backgroundSubviewsPadding)
            make.width.equalTo(CVQuotedMessageRenderItem.attachmentSize)
        }
        
        backgroundContainerView.addSubview(vStackVeiw)
        vStackVeiw.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(stripeView.snp.right).offset(CVQuotedMessageRenderItem.backgroundSubviewsPadding)
            make.right.equalTo(attachmentContainerView.snp.left).offset(CVQuotedMessageRenderItem.backgroundSubviewsPadding)
            make.height.equalTo(CVQuotedMessageRenderItem.attachmentSize)
        }

        vStackVeiw.addArrangedSubview(authorLabel)
        authorLabel.snp.makeConstraints { make in
            make.height.equalTo(CVQuotedMessageRenderItem.quotedAuthorHeight)
        }
        vStackVeiw.addArrangedSubview(quotedTextLabel)
    }
    
    func configure(renderItem: CVQuotedMessageRenderItem) {
        self.renderItem = renderItem
        
        renderItem.authorTextConfig?.applyForRendering(label: authorLabel)
        renderItem.quotedMessageTextConfig?.applyForRendering(label: quotedTextLabel)
        configureAttachmentView(renderItem: renderItem)
        
        refreshTheme()
    }
    
    private func configureAttachmentView(renderItem: CVQuotedMessageRenderItem) {
        guard let attachmentType = renderItem.attachmentType else {
            attachmentContainerView.isHidden = true
            return
        }
        attachmentContainerView.removeAllSubviews()
        
        var attachmentView: UIView
        switch attachmentType {
        case let .thumbnail(image, isVideo):
            attachmentView = createThumbnailImageView(image: image, isVideo: isVideo)
        case let .downloadFailed(backgroundColor):
            attachmentView = createDownloadFailedView(backgroundColor: backgroundColor)
        case .generic:
            attachmentView = createGenericAttachmentView()
        }
        attachmentContainerView.addSubview(attachmentView)
        attachmentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        attachmentContainerView.isHidden = false
    }
    
    private func createThumbnailImageView(image: UIImage, isVideo: Bool) -> UIImageView {
        let imageView = createImageView(image: image)
        imageView.clipsToBounds = true
        imageView.backgroundColor = .white
        
        if isVideo {
            let icon = UIImage(named: "attachment_play_button")?.withRenderingMode(.alwaysTemplate)
            let iconImageView = createImageView(image: icon)
            iconImageView.tintColor = .white
            imageView.addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        return imageView
    }
    
    private func createDownloadFailedView(backgroundColor: UIColor) -> UIView {
        let containerView = UIView()
        containerView.layoutMargins = .zero
        containerView.backgroundColor = backgroundColor
        
        let refreshIcon = UIImage(named: "btnRefresh--white")?.withRenderingMode(.alwaysTemplate)
        let refreshImageView = createImageView(image: refreshIcon)
        refreshImageView.contentMode = .scaleAspectFit
        refreshImageView.tintColor = .white
        containerView.addSubview(refreshImageView)
        refreshImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(CVQuotedMessageRenderItem.attachmentSize * 0.5)
        }
        
        containerView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapDownloadFailedView))
        containerView.addGestureRecognizer(tap)
        
        return containerView
    }
    
    private func createGenericAttachmentView() -> UIView {
        let containerView = UIView()
        containerView.layoutMargins = .zero
        let icon: UIImage? = {
            guard let type = renderItem?.contentType else {
                return UIImage(named: "generic-attachment")
            }
            if MIMETypeUtil.isAudio(type) {
                return UIImage(named: renderItem?.isVoiceMessage == true
                               ? "voice_message_icon"
                               : "voice_attachment_icon")
            }
            return UIImage(named: "generic-attachment")
        }()
        
        let iconImageView = createImageView(image: icon)
        iconImageView.contentMode = .scaleAspectFit
        
        containerView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(CVQuotedMessageRenderItem.attachmentSize)
        }
        
        return containerView
    }
    
    private func createImageView(image: UIImage?) -> UIImageView {
        let imageView = UIImageView()
        imageView.image = image
        // We need to specify a contentMode since the size of the image
        // might not match the aspect ratio of the view.
        imageView.contentMode = .scaleAspectFill
        // Use trilinear filters for better scaling quality at
        // some performance cost.
        imageView.layer.minificationFilter = .linear
        imageView.layer.magnificationFilter = .linear
        
        return imageView
    }
    
    func refreshTheme() {
        stripeView.backgroundColor = Theme.themeBlueColor
        authorLabel.textColor = renderItem?.authorTextColor
        backgroundContainerView.backgroundColor = Theme.accentBlueColor.withAlphaComponent(0.1)
    }
    
    // MARK: Action
    
    @objc
    private func didTapDownloadFailedView() {
        guard let replyModel = renderItem?.viewItem.quotedReply else {
            return
        }
        guard replyModel.thumbnailDownloadFailed else {
            return
        }
        guard let attachmentPointer = replyModel.thumbnailAttachmentPointer else {
            return
        }
        delegate?.quotedMessageView(
            self,
            didTapDownloadFailedThumbnailWith: attachmentPointer,
            replyModel: replyModel
        )
    }
}
