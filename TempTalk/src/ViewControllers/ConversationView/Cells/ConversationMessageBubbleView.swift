//
//  ConversationMessageBubbleView.swift
//  Signal
//
//  Created by Jaymin on 2024/4/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import YYImage
import TTMessaging
import TTServiceKit
import SDWebImage

@objc
protocol ConversationMessageBubbleViewDelegate: AnyObject {
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapLinkWith viewItem: ConversationViewItem,
        url: URL
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapReactionViewWith viewItem: ConversationViewItem,
        emoji: String
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didLongPressReactionViewWith viewItem: ConversationViewItem,
        emoji: String
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedThumbnailWith viewItem: ConversationViewItem,
        quotedReply: OWSQuotedReplyModel,
        attachmentPointer: TSAttachmentPointer
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedAttachmentWith viewItem: ConversationViewItem,
        autoRestart: Bool,
        attachmentPointer: TSAttachmentPointer
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapTruncatedTextMessageWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConfidentialTextMessageWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConfidentialSingleForward viewItem: ConversationViewItem
    )
        
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConversationItemWith viewItem: ConversationViewItem,
        quotedReply: OWSQuotedReplyModel
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapCombinedForwardingItemWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapContactShareViewWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapImageViewWith viewItem: ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapAudioViewWith viewItem: ConversationViewItem,
        attachmentStream: TSAttachmentStream
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapVideoViewWith viewItem: ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    )
    
    @objc optional
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapGenericAttachmentViewWith viewItem: ConversationViewItem,
        attachmentStream: TSAttachmentStream
    )
}

protocol ConversationMessageBubbleViewTextDelegate: AnyObject {
    func bubbleViewDidBeginSelectText(_ bubbleView: ConversationMessageBubbleView)
    
    func bubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didEndSelectTextWith textView: UITextView, 
        selectionView: DTTextSelectionView,
        viewItem: ConversationViewItem
    )
    
    func bubbleViewDidSingleTapSelectionView(_ bubbleView: ConversationMessageBubbleView)
}

class ConversationMessageBubbleView: UIView {
    
    var renderItem: CVMessageBubbleRenderItem?
    var mediaCache: NSCache<AnyObject, AnyObject>?
    
    var textViewLongPressLinkHandler: ((UILongPressGestureRecognizer) -> Void)?
    
    weak var delegate: ConversationMessageBubbleViewDelegate?
    weak var textDelegate: ConversationMessageBubbleViewTextDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        layoutMargins = .zero
        isUserInteractionEnabled = true
        
        addSubview(bubbleView)
        bubbleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        forwardSourceView.addSubview(forwardSourceLabel)
        forwardSourceLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(CVForwardSourceRenderItem.mediaQuotedReplyVSpacing)
            make.leading.equalToSuperview().offset(CVBodyMediaRenderItem.contactShareVSpacing - 2)
            make.trailing.equalToSuperview().offset(-(CVBodyMediaRenderItem.contactShareVSpacing - 5))
            make.bottom.equalToSuperview().offset(0)
        }
    }
    
    // MARK: - Public
    
    func configure(renderItem: CVMessageBubbleRenderItem, mediaCache: NSCache<AnyObject, AnyObject>?) {
        self.renderItem = renderItem
        self.mediaCache = mediaCache
        
        configureSubviews(renderItem: renderItem)
    }
    
    func loadContent() {
        if let loadCellContentBlock {
            loadCellContentBlock()
        }
    }
    
    func unloadContent() {
        if let unloadCellContentBlock {
            unloadCellContentBlock()
        }
    }
    
    func refreshTheme() {
        if pinMark.superview != nil {
            pinMark.tintColor = ConversationStyle.bubbleTextColorIncoming
        }
        
        if let renderItem,
            renderItem.viewItem.isConfidentialMessage,
            renderItem.confidentialEnable,
            let message = renderItem.viewItem.interaction as? TSMessage,
            message.isTextMessage() {
            bodyTextView.maskColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6)
        }
        
    }
    
    func prepareForReuse() {
        delegate = nil
        
        bodyTextView.removeFromSuperview()
        bodyTextView.attributedText = nil
        bodyTextView.text = nil
        bodyTextView.isHidden = true
        
        lineViews.forEach { $0.isHidden = true }
        
        markdownImageViews.forEach { $0.removeFromSuperview() }
        markdownImageViews.removeAll()
        
        bubbleView.bubbleColor = nil
        bubbleView.clearPartnerViews()
        bubbleView.subviews.forEach { $0.removeFromSuperview() }
        
        if let unloadCellContentBlock {
            unloadCellContentBlock()
        }
        loadCellContentBlock = nil
        unloadCellContentBlock = nil
        
        bodyMediaView?.subviews.forEach { $0.removeFromSuperview() }
        bodyMediaView?.removeFromSuperview()
        bodyMediaView = nil
        
        forwardSourceLabel.attributedText = nil
        forwardSourceView.removeFromSuperview()
        
        stackView.subviews.forEach { $0.removeFromSuperview() }
        quotedMessageView = nil
        
        self.subviews.forEach {
            if $0 !== bubbleView, $0 !== bodyTextSelectionView {
                $0.removeFromSuperview()
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view
    }
    
    // MARK: - Actions
    
    @objc private func bodyTextViewDidLongPress(_ sender: UILongPressGestureRecognizer) {
        if let textViewLongPressLinkHandler {
            textViewLongPressLinkHandler(sender)
        }
    }
    
    // MARK: - Lazy Load
    
    lazy var bubbleView: OWSBubbleView = {
        let view = OWSBubbleView()
        view.layoutMargins = .zero
        return view
    }()
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    private lazy var forwardSourceView = UIView()
    
    private lazy var forwardSourceLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        return label
    }()
    
    lazy var bodyTextView: MaskedTextView = {
        let textView = MaskedTextView()
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.contentInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .link
        textView.delegate = self
        textView.isHidden = true
        textView.adjustsFontForContentSizeCategory = true
        
        // Note: 虽然 cell 在 MessageBubbleView 上已经添加了 LongPress，但在某些 iOS 版本中（例如 iOS 17.5），
        // 当 textView 内容是链接或 @ 时外层的 LongPress 无法触发，通过在 TextView 上添加 LongPress 来解决这个问题
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(bodyTextViewDidLongPress(_:)))
        textView.addGestureRecognizer(longPress)

        return textView
    }()
    
    private lazy var pinMark: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .init(named: "ic_pin_mark")?.withRenderingMode(.alwaysTemplate)
        return imageView
    }()
        
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter
    }()
    
    private lazy var confidentialView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect.init(style: .light)
        let visualView = UIVisualEffectView.init(effect: blurEffect)
        visualView.layer.cornerRadius = 5
        visualView.layer.masksToBounds = true
        return visualView
    }()
    
    private lazy var tapToViewLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        return label
    }()
    
    var quotedMessageView: ConversationQuotedMessageView?
    var bodyMediaView: UIView?
    var downloadView: AttachmentPointerView?
    var bodyTextSelectionView: DTTextSelectionView?
    
    var markdownImageViews: [YYAnimatedImageView] = []
    var lineViews: [UIView] = []
    
    var loadCellContentBlock: (() -> Void)?
    var unloadCellContentBlock: (() -> Void)?
}


// MARK: - Configue

extension ConversationMessageBubbleView {
    struct TextViewEntity {
        let view: UIView
        let height: CGFloat?
    }
    
    private func configureSubviews(renderItem: CVMessageBubbleRenderItem) {
        bubbleView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        configurePinMark(renderItem: renderItem)
        configureForwardSourceView(renderItem: renderItem)
        configureQuotedMessageView(renderItem: renderItem)
        
        var textViews: [TextViewEntity] = []
        configureBodyMediaView(renderItem: renderItem, textViews: &textViews)
        configureBodyTextView(renderItem: renderItem, textViews: &textViews)
        configureMediaFooterOverlay(renderItem: renderItem)
        configureEmojiReactionView(renderItem: renderItem, textViews: &textViews)
        
        insertTextViewsOnStackView(textViews: textViews, style: renderItem.conversationStyle)
        
        if self.superview != nil {
            self.snp.remakeConstraints() { make in
                make.width.equalTo(renderItem.viewSize.width)
                make.height.equalTo(renderItem.viewSize.height)
            }
        }
        
        if let bodyMediaView, bodyMediaView.superview != nil,
           let bodyMediaSize = renderItem.bodyMediaRenderItem?.viewSize {
            bodyMediaView.snp.makeConstraints { make in
                make.height.equalTo(bodyMediaSize.height)
            }
        }
        
        configureBubbleView(renderItem: renderItem)
        
        configureConfidential(renderItem: renderItem)
    }
    
    private func configureConfidential(renderItem: CVMessageBubbleRenderItem) {
        let viewItem = renderItem.viewItem
        guard viewItem.isConfidentialMessage && renderItem.confidentialEnable,
              let message = viewItem.interaction as? TSMessage, !message.isTextMessage() else {
            confidentialView.isHidden = true
            return
        }
        
        confidentialView.isHidden = false
        if confidentialView.superview != nil {
            return
        }
        
        addSubview(confidentialView)
        confidentialView.autoPinEdgesToSuperviewEdges()
        confidentialView.contentView.addSubview(tapToViewLabel)
        tapToViewLabel.sizeToFit()
        tapToViewLabel.autoCenterInSuperview()
        tapToViewLabel.textColor = UIColor.white
        tapToViewLabel.backgroundColor = UIColor.color(rgbHex: 0x000000, alpha: 0.3)
        tapToViewLabel.text = Localized("CONVERSATION_VIEW_CONFIDETIAL_TAP_TO_VIEW")
    }
    
    private func configurePinMark(renderItem: CVMessageBubbleRenderItem) {
        guard renderItem.isShowPinMark else {
            return
        }
        
        bubbleView.addSubview(pinMark)
        pinMark.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(1)
            make.trailing.equalToSuperview().offset(-1)
        }
    }
    
    private func configureForwardSourceView(renderItem: CVMessageBubbleRenderItem) {
        guard let forwardSourceItem = renderItem.forwardSourceRenderItem else {
            return
        }
        // 文字控件顶部自带间隔，图片/视频顶部与source间隔太小，需要修正
        forwardSourceLabel.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(-forwardSourceItem.fixForwardSourceLabelHeight)
        }
        forwardSourceLabel.textColor = forwardSourceItem.textColor
        forwardSourceLabel.attributedText = forwardSourceItem.singleForwardTitle
        stackView.addArrangedSubview(forwardSourceView)
        forwardSourceView.snp.remakeConstraints { make in
            make.height.equalTo(forwardSourceItem.viewSize.height)
        }
    }
    
    private func configureQuotedMessageView(renderItem: CVMessageBubbleRenderItem) {
        guard let quotedMessageItem = renderItem.quotedMessageRenderItem else {
            return
        }
        
        // 添加顶部间距
        let spacingView = UIView.container()
        spacingView.setCompressionResistanceHigh()
        stackView.addArrangedSubview(spacingView)
        spacingView.snp.makeConstraints { make in
            make.height.equalTo(CVQuotedMessageRenderItem.topMargin)
        }
        
        let quotedMessageView = ConversationQuotedMessageView()
        quotedMessageView.delegate = self
        quotedMessageView.configure(renderItem: quotedMessageItem)
        stackView.addArrangedSubview(quotedMessageView)
        quotedMessageView.snp.makeConstraints { make in
            make.height.equalTo(quotedMessageItem.viewSize.height)
        }
        self.quotedMessageView = quotedMessageView
    }
    
    private func configureEmojiReactionView(
        renderItem: CVMessageBubbleRenderItem,
        textViews: inout [TextViewEntity]
    ) {
        guard let emojiItem = renderItem.emojiReactionRenderItem else {
            return
        }
        let reactionView = ConversationEmojiReactionView()
        reactionView.delegate = self
        reactionView.configure(renderItem: emojiItem)
        textViews.append(.init(view: reactionView, height: nil))
    }
    
    private func insertTextViewsOnStackView(textViews: [TextViewEntity], style: ConversationStyle) {
        guard !textViews.isEmpty else {
            return
        }
        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.spacing = CVMessageBubbleRenderItem.textViewSpacing
        textStackView.isLayoutMarginsRelativeArrangement = true
        textStackView.layoutMargins = .init(
            top: style.textInsetTop,
            left: style.textInsetHorizontal,
            bottom: style.textInsetBottom,
            right: style.textInsetHorizontal
        )
        textViews.forEach {
            textStackView.addArrangedSubview($0.view)
            if let height = $0.height {
                $0.view.snp.remakeConstraints { make in
                    make.height.equalTo(height)
                }
            }
        }
        stackView.addArrangedSubview(textStackView)
    }
    
    func configureBubbleView(renderItem: CVMessageBubbleRenderItem) {
        let hasOnlyBodyMediaView = renderItem.hasBodyMediaWithThumbnail && stackView.subviews.count == 1
        renderItem.hasOnlyBodyMediaView = hasOnlyBodyMediaView
        if !hasOnlyBodyMediaView {
            let viewItem = renderItem.viewItem
            switch viewItem.messageCellType() {
            case .card:
                bubbleView.bubbleColor = Theme.backgroundColor
                bubbleView.strokeColor = .ows_light35
            case .contactShare:
                bubbleView.bubbleColor = nil
                bubbleView.strokeColor = nil
            default:
                bubbleView.bubbleColor = {
                    let style = renderItem.conversationStyle
                    guard let message = viewItem.interaction as? TSMessage else {
                        return style.bubbleColorOutgoingSent
                    }
                    return style.bubbleColor(message: message)
                }()
                bubbleView.strokeColor = nil
            }
        } else {
            // Media-only messages should have no background color; they will fill the bubble's bounds
            // and we don't want artifacts at the edges.
            bubbleView.bubbleColor = nil
            bubbleView.strokeColor = nil
        }
        
        bubbleView.sharpCorners = renderItem.sharpCorners
    }

    func addSpacingViewOnStackView(spacing: CGFloat) {
        let spacingView = UIView.container()
        spacingView.setCompressionResistanceHigh()
        stackView.addArrangedSubview(spacingView)
        spacingView.snp.makeConstraints { make in
            make.height.equalTo(spacing)
        }
    }
}

// MARK: - UITextViewDelegate

extension ConversationMessageBubbleView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard let viewItem = renderItem?.viewItem, let delegate else { return true }
        
        let mentionsAll = "\(CVBodyTextRenderItem.kVisitingCardScheme)://\(MENTIONS_ALL)"
        guard !URL.absoluteString.contains(mentionsAll) else { return false }
        
        delegate.messageBubbleView?(self, didTapLinkWith: viewItem, url: URL)
        return false
    }
}

// MARK: - ConversationEmojiReactionViewDelegate

extension ConversationMessageBubbleView: ConversationEmojiReactionViewDelegate {
    func reactionView(_ reactionView: ConversationEmojiReactionView, didTapWith emoji: String) {
        guard let viewItem = renderItem?.viewItem else { return }
        delegate?.messageBubbleView?(self, didTapReactionViewWith: viewItem, emoji: emoji)
    }
    
    func reactionView(_ reactionView: ConversationEmojiReactionView, didLongPressWith emoji: String) {
        guard let viewItem = renderItem?.viewItem else { return }
        delegate?.messageBubbleView?(self, didLongPressReactionViewWith: viewItem, emoji: emoji)
    }
}

// MARK: - ConversationQuotedMessageViewDelegate

extension ConversationMessageBubbleView: ConversationQuotedMessageViewDelegate {
    func quotedMessageView(
        _ quotedMessageView: ConversationQuotedMessageView,
        didTapDownloadFailedThumbnailWith attachmentPointer: TSAttachmentPointer,
        replyModel: OWSQuotedReplyModel
    ) {
        guard let viewItem = renderItem?.viewItem else { return }
        delegate?.messageBubbleView?(
            self,
            didTapDownloadFailedThumbnailWith: viewItem,
            quotedReply: replyModel,
            attachmentPointer: attachmentPointer
        )
    }
}
