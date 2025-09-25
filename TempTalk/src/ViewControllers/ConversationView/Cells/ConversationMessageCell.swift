//
//  ConversationMessageCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

@objc
protocol ConversationMessageCellDelegate: AnyObject {
    func mediaCache(for cell: ConversationMessageCell) -> NSCache<AnyObject, AnyObject>
    
    func contactsManager(for cell: ConversationMessageCell) -> OWSContactsManager
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapAvatarWith recipientId: String
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didLongPressAvatarWith recipientId: String,
        senderName: String?
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapFailedOutgoingMessage message: TSOutgoingMessage
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didLongPressBubbleViewWith messageType: ConversationMessageType,
        viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        shouldBeginPanToQuoteWith viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) -> Bool
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didPanToQuoteWith viewItem: ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapTranslateIconWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapTranslateTruncatedTextMessageWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapReadStatusWith viewItem: ConversationViewItem
    )
    
    @objc optional
    func messageCell(
        _ cell: ConversationMessageCell,
        didTapSkipToOrigionWith viewItem: ConversationViewItem
    )
}

class ConversationMessageCell: ConversationCell {
    
    var renderItem: ConversationMessageRenderItem?
    
    weak var delegate: ConversationMessageCellDelegate?
    
    var isMultiSelectMode = false {
        didSet {
            guard oldValue != isMultiSelectMode else {
                return
            }
            multiSelectModeDidChange()
        }
    }
    
    var isCellSelected = false {
        didSet {
            guard oldValue != isCellSelected else {
                return
            }
            checkButton.isSelected = isCellSelected
        }
    }
    
    override var isCellVisible: Bool {
        didSet {
            guard oldValue != isCellVisible else {
                return
            }
            if !isCellVisible {
                messageBubbleView.unloadContent()
            } else {
                messageBubbleView.loadContent()
            }
        }
    }
    
    var startPanLocation: CGPoint = CGPointZero
    var needFeedback: Bool = true
    var shouldHandle: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupView() {
        layoutMargins = .zero
        contentView.layoutMargins = .zero
        
        contentView.isUserInteractionEnabled = true
        contentView.addSubview(contentVStackView)
        //contentView
        //  |-----contentVStackView
        //             |-----bottomView
        //                     |-----messageContainerView
        //                             |------avatarView
        //                             |------senderNameView
        //                             |------msgVStackView
        //                                    |------msgMiddleHStackView
        //                                           |------messageBubbleView
        //                                           |------translateView
        //                             |------footerTimeLabel
        //                             |------readStatusImageView
        //
       
            
        // Note: 不是所有 cell 都有 headerView，放到真正需要展示时初始化
        // contentVStackView.addArrangedSubview(headerView)
        contentVStackView.addArrangedSubview(bottomView)
        
        contentView.addSubview(quoteImageView)
        
        bottomView.addSubview(checkButton)
        bottomView.addSubview(messageContainerView)
        // Note: 只有 incoming message 展示 avatarView senderNameView
        // Note: 只有 outgoing message 展示 readStatusImageView
        
        // Note: 只有 incoming message 展示
        // messageContainerView.addSubview(avatarView)
        messageContainerView.addSubview(msgVStackView)
        
        msgVStackView.addArrangedSubviews([
            // Note: 只有 incoming message 展示
            // senderNameView,
            msgMiddleHStackView,
            // Note: messageTranslateView 初始化存在一定耗时，放到真正需要展示时初始化
            // messageTranslateView,
        ])
        
        msgMiddleHStackView.addArrangedSubviews([
            // Note: 只有 outgoing message 展示
            // readStatusImageView,
            messageBubbleView,
            // Note: 只有 incoming message 展示
            // translateImageIcon,
            // skipToOrigionIcon
        ])
        messageContainerView.addSubview(footerView)
        messageContainerView.addSubview(footerTimeLabel)
        
    }
    
    func setupLayout() {
        fatalError("Subclass must override")
    }
    
    func configure(renderItem: ConversationMessageRenderItem) {
        self.renderItem = renderItem
        
        configureHeaderView(renderItem: renderItem)
        configureMessageBubbleView(renderItem: renderItem)
        configureTranslateView(renderItem: renderItem)
        configureMessageFooterView(renderItem: renderItem.messageBubbleRenderItem?.footerRenderItem)
        
    }
    
    // MARK: - Actions
    
    @objc private func bubbleViewDidClick(_ sender: UITapGestureRecognizer) {
        guard let viewItem = renderItem?.viewItem else { return }
        guard sender.state == .recognized else {
            Logger.debug("Ignoring tap on message: \(viewItem.interaction.debugDescription)")
            return
        }
        guard !isTouchInHeaderView(gesture: sender) else {
            return
        }
        
        if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage {
            if outgoingMessage.messageState == .failed {
                delegate?.messageCell?(self, didTapFailedOutgoingMessage: outgoingMessage)
            } else if outgoingMessage.messageState == .sending, !outgoingMessage.isPinnedMessage {
                // Ignore taps on outgoing messages being sent.
                return
            }
        }
        
        messageBubbleView.handleTapGesture(sender)
    }
    
    @objc private func bubbleViewDidLongPress(_ sender: UILongPressGestureRecognizer) {
        guard let viewItem = renderItem?.viewItem else {
            return
        }
        guard sender.state == .began else {
            return
        }
        guard !isTouchInHeaderView(gesture: sender) else {
            return
        }
        
        if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage {
            if outgoingMessage.messageState == .failed || outgoingMessage.messageState == .sending {
                // Ignore long press on unsent messages or being sent.
                return
            }
        }
        
        let locationInBubbleView = sender.location(in: messageBubbleView)
        let gestureLocation = messageBubbleView.gestureLocationForLocation(locationInBubbleView)
        let messageType: ConversationMessageType = {
            switch gestureLocation {
            case .default, .oversizeText:
                return .text
            case .media:
                return .media
            case .quotedReply:
                return .quoted
            case .combinedForwarding:
                return .combinedForwarding
            case .contactShare:
                return .contactShare
            case .card:
                return .card
            }
        }()
        delegate?.messageCell?(
            self,
            didLongPressBubbleViewWith: messageType,
            viewItem: viewItem,
            bubbleView: messageBubbleView
        )
    }
    
    @objc private func panToQuote(gestureRecognizer: UIPanGestureRecognizer) {
        if self.isMultiSelectMode {
            return
        }
        
        if let renderItem = self.renderItem, !renderItem.isIncomingMessage && !renderItem.isOutgoingMessage  {
            return
        }
        
//        if let outgoingRenderItem = renderItem as? ConversationOutgoingMessageRenderItem, outgoingRenderItem.shouldDisplaySendFailedBadge || outgoingRenderItemisShowReadStatusSpinning {
//            return
//        }
        
        guard let viewItem = renderItem?.viewItem, !viewItem.isConfidentialMessage else {
            return
        }
        
        if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage {
            if outgoingMessage.messageState == .failed || outgoingMessage.messageState == .sending {
                // Ignore pan to quote unsent messages or being sent.
                return
            }
        }
        
        if delegate?.messageCell?(self, shouldBeginPanToQuoteWith: viewItem, bubbleView: messageBubbleView) == false {
            return
        }
        
        let actionDistance = 100.0
        let currentLocation = gestureRecognizer.location(in: self.contentView)
        
        if gestureRecognizer.state == .began {
            self.startPanLocation = currentLocation
            self.quoteImageView.alpha = 0
            self.needFeedback = true
        } else if gestureRecognizer.state == .changed {
            let dx = currentLocation.x - self.startPanLocation.x
            let distance = abs(dx)
            if dx > 0 {
                let containerViewConstant = min(distance, 2*actionDistance)
                quoteImageView.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(min(distance, actionDistance) - 45)
                }
                messageContainerView.snp.updateConstraints { make in
                    make.leading.equalToSuperview().offset(containerViewConstant)
                    make.trailing.equalToSuperview().offset(containerViewConstant)
                }
                self.quoteImageView.alpha = distance/actionDistance
                if self.needFeedback && containerViewConstant > actionDistance {
                    let feedbackGenerator = UIImpactFeedbackGenerator.init(style: .medium)
                    feedbackGenerator.impactOccurred()
                    self.needFeedback = false;
                }
            }
        } else if gestureRecognizer.state == .ended {
            let dx = currentLocation.x - self.startPanLocation.x
            if dx >= actionDistance {
                delegate?.messageCell?(self,
                                       didPanToQuoteWith: viewItem,
                                       bubbleView: messageBubbleView)
            }
            
            UIView.animate(withDuration: 0.3) {
                self.quoteImageView.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(-45)
                }
                self.messageContainerView.snp.updateConstraints { make in
                    make.leading.equalToSuperview()
                    make.trailing.equalToSuperview()
                }
                self.startPanLocation = CGPointZero
                self.quoteImageView.alpha = 0
                self.contentView.layoutIfNeeded()
            }
            self.needFeedback = true
        }
        
        
    }
    
    // MARK: - Override
    
    override func refreshTheme() {
        if let headerView, !headerView.isHidden {
            headerView.refreshTheme()
        }
        
        refreshFooterTheme()
        
        messageBubbleView.refreshTheme()
        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        messageBubbleView.prepareForReuse()
        messageBubbleView.unloadContent()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func multiSelectModeDidChange() {
        fatalError("Subclass must override")
    }
    
    // MARK: - Lazy Load
    
    lazy var contentVStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        return stackView
    }()
    
    var headerView: ConversationMessageHeaderView?
    
    lazy var bottomView = UIView()
    
    lazy var checkButton: UIButton = {
        let button = UIButton(type: .custom)
        button.isHidden = true
        button.setImage(.init(named: "check-mark-unselected"), for: .normal)
        button.setImage(.init(named: "check-mark-selected"), for: .selected)
        return button
    }()
    
    lazy var messageContainerView: UIView = {
        let view = UIView()
        // DTMessageListController 中会根据 tag 找到 bubbleView 的父视图
        view.tag = 10000
        return view
    }()
    
    lazy var quoteImageView: UIImageView = {
        let imageView = UIImageView.init(image: UIImage.init(named: "ic_quote"))
        imageView.alpha = 0
        return imageView
    }()
    
    lazy var msgVStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ConversationMessageRenderItem.msgVStackViewSpacing
        return stackView
    }()
    
    lazy var msgMiddleHStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        // DTMessageListController 中会根据 tag 找到 bubbleView 的父视图
        stackView.tag = 10000
        stackView.alignment = .bottom
        return stackView
    }()
    
    lazy var messageBubbleView: ConversationMessageBubbleView = {
        let view = ConversationMessageBubbleView()
        let tap = UITapGestureRecognizer(target: self, action: #selector(bubbleViewDidClick(_:)))
        view.addGestureRecognizer(tap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(bubbleViewDidLongPress(_:)))
        longPress.delegate = self
        view.addGestureRecognizer(longPress)
        
        view.textViewLongPressLinkHandler = { [weak self] longPress in
            guard let self else { return }
            self.bubbleViewDidLongPress(longPress)
        }
        
        let pan = DTPanGestureRecognizer(target: self, action: #selector(panToQuote(gestureRecognizer:)))
        self.messageContainerView.addGestureRecognizer(pan)
        
        return view
    }()
    
    var avatarAroundView: UIView?
    
    var messageTranslateView: ConversationTranslateView?
    
    lazy var footerTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12.0)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    lazy var footerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(rgbHex: 0x1A1A1A, alpha: 0.3)
        view.clipsToBounds = true
        view.layer.cornerRadius = CVMessageFooterRenderItem.footerViewHeight/2.0
        return view
    }()
    
}

// MARK: - Configure Cell

extension ConversationMessageCell {
    
    func configureHeaderView(renderItem: ConversationMessageRenderItem) {
        guard let headerItem = renderItem.headerRenderItem else {
            if let headerView, !headerView.isHidden {
                headerView.isHidden = true
            }
            return
        }
        
        let headerView: ConversationMessageHeaderView = {
            guard let view = self.headerView else {
                let view = ConversationMessageHeaderView()
                self.headerView = view
                return view
            }
            return view
        }()
        headerView.isHidden = false
        headerView.configure(renderItem: headerItem)
        contentVStackView.insertArrangedSubview(headerView, at: 0)
    }
    
    func configureMessageBubbleView(renderItem: ConversationMessageRenderItem) {
        guard let bubbleItem = renderItem.messageBubbleRenderItem else {
            return
        }
        messageBubbleView.configure(
            renderItem: bubbleItem,
            mediaCache: delegate?.mediaCache(for: self)
        )
        messageBubbleView.loadContent()
    }
    
    func configureTranslateView(renderItem: ConversationMessageRenderItem) {
        guard let translateItem = renderItem.translateRenderItem  else {
            if let messageTranslateView, !messageTranslateView.isHidden {
                messageTranslateView.isHidden = true
            }
            return
        }
        
        if shouldHandle, translateItem.translateState == .translating {
            //处理视图Ui
            if let message = renderItem.viewItem.interaction as? TSMessage, let translateMessage = message.translateMessage {
                translateItem.translateState = .failed
                translateMessage.translateTipMessage = message.hasAttachments() ?
                    Localized("SPEECHTOTEXT_CONVERT_TIP_MESSAGE_FAILED") :
                    Localized("TRANSLATE_TIP_MESSAGE_FAILED")
            }
        }
        
        let translateView = {
            if let messageTranslateView {
                messageTranslateView.renderItem = translateItem
                return messageTranslateView
            } else {
                let view = ConversationTranslateView(renderItem: translateItem)
                self.messageTranslateView = view
                return view
            }
        }()
        translateView.delegate = self
        translateView.isHidden = false
        
        let size = translateItem.viewSize
        if translateView.superview == nil {
            if let index = msgVStackView.arrangedSubviews.firstIndex(of: msgMiddleHStackView) {
                msgVStackView.insertArrangedSubview(translateView, at: index + 1)
            } else {
                msgVStackView.addArrangedSubview(translateView)
            }
            translateView.snp.makeConstraints { make in
                make.width.equalTo(size.width)
                make.height.equalTo(size.height)
            }
        } else {
            translateView.snp.updateConstraints { make in
                make.width.equalTo(size.width)
                make.height.equalTo(size.height)
            }
        }
    }
    
    func configureMessageFooterView(renderItem: CVMessageFooterRenderItem?) {
        guard let footerItem = renderItem else {
            footerTimeLabel.isHidden = true
            return
        }
        footerTimeLabel.isHidden = false
        footerTimeLabel.text = footerItem.footerViewTitle
    }
    
    func footerViewApperanceCommon(renderItem: ConversationMessageRenderItem) {
        
        let viewItem = renderItem.viewItem
        if viewItem.isConfidentialMessage,
            (renderItem.messageBubbleRenderItem?.confidentialEnable ?? false),
            let message = viewItem.interaction as? TSMessage,
           !message.isTextMessage() {
            footerView.isHidden = false
        } else {
            footerView.isHidden = !(renderItem.messageBubbleRenderItem?.hasOnlyBodyMediaView ?? false)
        }
    }
    
    func footerViewApperanceCommon(isHidden: Bool) {
        footerView.isHidden = isHidden
        refreshFooterTheme()
    }
    
    func refreshFooterTheme() {
        if footerView.isHidden {
            if !footerTimeLabel.isHidden {
                footerTimeLabel.textColor = Theme.ternaryTextColor
            }
        } else {
            footerTimeLabel.textColor = UIColor.white
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ConversationMessageCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchView = touch.view else {
            return true
        }
        if let avatarAroundView, touchView.isDescendant(of: avatarAroundView) {
            return false
        }
        if touchView.isKind(of: UITextView.self) {
            return false
        }
        return true
    }
    
    func isTouchInHeaderView(gesture: UIGestureRecognizer) -> Bool {
        guard let headerView, !headerView.isHidden else {
            return false
        }
        let location = gesture.location(in: self)
        let headerBottom = self.convert(.init(x: 0, y: headerView.height), from: headerView)
        return location.y <= headerBottom.y
    }
}

// MARK: - ConversationTranslateViewDelegate

extension ConversationMessageCell: ConversationTranslateViewDelegate {
    func translateView(
        _ translateView: ConversationTranslateView,
        didTapMoreTranslateResultWith viewItem: any ConversationViewItem
    ) {
        delegate?.messageCell?(self, didTapTranslateTruncatedTextMessageWith: viewItem)
    }
}
