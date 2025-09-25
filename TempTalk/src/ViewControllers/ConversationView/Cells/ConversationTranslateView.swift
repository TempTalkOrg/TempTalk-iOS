//
//  ConversationTranslateView.swift
//  Difft
//
//  Created by Jaymin on 2024/7/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SnapKit
import TTMessaging
import TTServiceKit

protocol ConversationTranslateViewDelegate: AnyObject {
    func translateView(
        _ translateView: ConversationTranslateView,
        didTapMoreTranslateResultWith viewItem: ConversationViewItem
    )
}

class ConversationTranslateView: UIView, UIEditMenuInteractionDelegate {
    
    weak var delegate: ConversationTranslateViewDelegate?
    
    var renderItem: CVTranslateRenderItem {
        didSet {
            configureData()
        }
    }
    
    // MARK: Init & Deinit
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    init(renderItem: CVTranslateRenderItem) {
        self.renderItem = renderItem
        
        super.init(frame: .zero)
        
        registerNotification()
        setupView()
        configureData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addGestureRecognizer(tapGestureRecognizer)
        
        addSubview(translateContainView)
        translateContainView.addSubview(topRowStackView)
        translateContainView.addSubview(bottomRowStackView)
        
        topRowStackView.addArrangedSubviews([statusIndicatorImageView, translateLabel])
        bottomRowStackView.addArrangedSubviews([bottomSpacerView])
        translateContainView.addSubview(translateTipsImageView)
    }
    
    private func updateUILayout() {
        translateContainView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        topRowStackView.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(CVTranslateRenderItem.insetMargin)
            make.trailing.equalToSuperview().offset(-CVTranslateRenderItem.insetMargin)
        }
        
        bottomRowStackView.snp.remakeConstraints { make in
            make.top.equalTo(topRowStackView.snp.bottom)
            make.leading.trailing.equalTo(topRowStackView)
            make.height.equalTo(0)
            make.bottom.equalToSuperview()
        }
        
        statusIndicatorImageView.snp.remakeConstraints { make in
            make.width.height.equalTo(CVTranslateRenderItem.indicatorWidth)
        }
        
        if renderItem.viewItem.messageCellType() == .audio {
            translateLabel.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
            }
            
            if renderItem.translateState == .sucessed {
                showTips()
            } else {
                translateLabel.snp.remakeConstraints { make in
                    make.top.bottom.equalToSuperview()
                    make.leading.equalToSuperview().offset(30)
                }
                hideTips()
            }
        } else {
            translateLabel.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
            }
            hideTips()
        }
    }
    
    private func hideTips() {
        translateTipsImageView.snp.remakeConstraints { make in
            make.width.height.equalTo(0)
        }
    }

    private func showTips() {
        translateTipsImageView.snp.remakeConstraints { make in
            make.width.height.equalTo(12)
            make.bottom.equalToSuperview().offset(-5)
            make.trailing.equalToSuperview().offset(-5)
        }
    }
    
    private func configureData() {
        guard let message = self.renderItem.viewItem.interaction as? TSMessage else {
            return
        }
        guard let translateMessage = message.translateMessage else {
            return
        }
        guard let translateState = renderItem.translateState else {
            return
        }
        translateSourceLabel.text = renderItem.translateSourceText
        
        let translateText = {
            if translateState == .translating || translateState == .failed {
                return translateMessage.translateTipMessage
            }
            if translateMessage.translateLanguageEqualTo(.english), !translateMessage.tranEngLishResult.isEmpty {
                return self.renderItem.displayableText?.displayText ?? translateMessage.tranEngLishResult
            }
            if translateMessage.translateLanguageEqualTo(.chinese), !translateMessage.tranChinseResult.isEmpty {
                return self.renderItem.displayableText?.displayText ?? translateMessage.tranChinseResult
            }
            return ""
        }()

        updateTranslateState(translateState, translateAttributedText: renderItem.attributedString(for: translateText))
        showMoreButtonIfNeed()
        refreshTheme()
        updateUILayout()
    }
    
    private func updateTranslateState(_ state: DTTranslateMessageStateType, translateAttributedText: NSAttributedString?) {
        switch state {
        case .translating:
            startSpinning()
            statusIndicatorImageView.isHidden = false
            statusIndicatorImageView.image = .init(named: "message_status_sending")?.withRenderingMode(.alwaysTemplate)
            statusIndicatorImageView.tintColor = renderItem.textColor
            tapGestureRecognizer.isEnabled = false
            
        case .sucessed:
            stopSpinning()
            statusIndicatorImageView.isHidden = true
            tapGestureRecognizer.isEnabled = true
            
        default:
            stopSpinning()
            statusIndicatorImageView.isHidden = false
            statusIndicatorImageView.image = .init(named: "message_status_failed_red")?.withRenderingMode(.alwaysOriginal)
            tapGestureRecognizer.isEnabled = true
        }
        translateLabel.attributedText = translateAttributedText
        // fix: 这里必须在设置完 attributedText 后重新设置一次，否则会导致 emoji 不展示
        translateLabel.textInsets = UIEdgeInsets(
            top: CVTranslateRenderItem.insetTopMargin,
            left: 0,
            bottom: CVTranslateRenderItem.insetTopMargin,
            right: 2
        )
    }
    
    private func showMoreButtonIfNeed() {
        guard renderItem.isShowMoreButton else {
            moreButton?.isHidden = true
            return
        }
        if moreButton == nil {
            let button = UIButton()
            button.titleLabel?.font = .ows_dynamicTypeCaption1
            button.addTarget(self, action: #selector(didTapMoreButton(_:)), for: .touchUpInside)
            button.setCompressionResistanceHorizontalHigh()
            bottomRowStackView.addArrangedSubview(button)
            bottomRowStackView.setCustomSpacing(CVTranslateRenderItem.insetMargin, after: button)
            moreButton = button
        }
        moreButton?.setTitle(Localized("CONVERSATION_VIEW_OVERSIZE_TEXT_TAP_FOR_MORE"), for: .normal)
        moreButton?.isHidden = false
    }
    
    func refreshTheme() {
        translateContainView.backgroundColor = renderItem.containerColor
        translateLabel.textColor = renderItem.textColor
        translateSourceLabel.textColor = renderItem.sourceTextColor
        translateSucessImageView.tintColor = Theme.isDarkThemeEnabled ? .ows_gray65 : .ows_gray25
        translateTipsImageView.tintColor = Theme.isDarkThemeEnabled ? .ows_gray65 : .ows_gray25
        moreButton?.setTitleColor(renderItem.textColor, for: .normal)
    }
    
    // MARK: Actions
    
    @objc
    private func didTapTranslateView(_ sender: UITapGestureRecognizer) {
        if renderItem.isShowMoreButton {
            delegate?.translateView(self, didTapMoreTranslateResultWith: renderItem.viewItem)
        } else {
            if renderItem.translateState != .sucessed {
                tapGestureRecognizer.isEnabled = false
                updateTranslateState(.translating, translateAttributedText: renderItem.translatingAttributedText)
                
                renderItem.retryTranslateFailedMessage().done {
                    // do nothing
                }.catch { [weak self] error in
                    guard let self else { return }
                    updateTranslateState(.failed, translateAttributedText: renderItem.translateFailedAttributedText)
                }
            }
        }
    }
    
    @objc
    private func didTapMoreButton(_ sender: UIButton) {
        delegate?.translateView(self, didTapMoreTranslateResultWith: renderItem.viewItem)
    }
    
    private func startSpinning() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.toValue = NSNumber(value: Double.pi * 2.0)
        animation.duration = 1
        animation.isCumulative = true
        animation.repeatCount = Float.infinity
        statusIndicatorImageView.layer.add(animation, forKey: "animation_translateView")
    }
    
    private func stopSpinning() {
        statusIndicatorImageView.layer.removeAnimation(forKey: "animation_translateView")
    }
    
    private func handleTranslateTipsTap() {
        guard let window = self.window else { return }

        let bubble = BubbleTipView(text: Localized("CONVERT_SOURCE_TEXT"))
        bubble.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(bubble)
        window.bringSubviewToFront(bubble)

        // 将 translateTipsImageView 的坐标转换到 window
        let tipFrame = translateTipsImageView.convert(translateTipsImageView.bounds, to: window)

        NSLayoutConstraint.activate([
            bubble.trailingAnchor.constraint(equalTo: window.leadingAnchor, constant: tipFrame.maxX - 12),
            bubble.bottomAnchor.constraint(equalTo: window.topAnchor, constant: tipFrame.minY + 15)
        ])

        bubble.alpha = 0
        UIView.animate(withDuration: 0.25) {
            bubble.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.25, animations: {
                bubble.alpha = 0
            }) { _ in
                bubble.removeFromSuperview()
            }
        }
    }

    // MARK: Lazy Load
    
    private lazy var translateContainView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var topRowStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalCentering
        stackView.spacing = CVTranslateRenderItem.indicatorMargin
        return stackView
    }()
    
    private lazy var bottomRowStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .trailing
        stackView.spacing = 6
        return stackView
    }()
    
    private lazy var bottomSpacerView: UIView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }()
    
    private lazy var statusIndicatorImageView = DTImageView()
    
    private lazy var translateLabel: DTTextInsetsLabel = {
        let label = DTTextInsetsLabel()
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        label.textInsets = UIEdgeInsets(
            top: CVTranslateRenderItem.insetTopMargin,
            left: 0,
            bottom: CVTranslateRenderItem.insetTopMargin,
            right: 2
        )
        return label
    }()
    
    private lazy var translateSucessImageView: DTImageView = {
        let imageView = DTImageView()
        imageView.image = .init(named: "sucess_icon")?.withRenderingMode(.alwaysTemplate)
        return imageView
    }()
    
    private lazy var translateSourceLabel: UILabel = {
        let label = DTTextInsetsLabel()
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    private lazy var bubbleView: OWSBubbleView = {
        let view = OWSBubbleView()
        view.layoutMargins = .zero
        return view
    }()
    
    private lazy var translateTipsImageView: DTImageView = {
        let imageView = DTImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = .init(named: "translate_tips")?.withRenderingMode(.alwaysTemplate)
        imageView.tapBlock = { [weak self] _ in
            guard let self else { return }
            // 点击事件
            self.handleTranslateTipsTap()
        }
        return imageView
    }()
    
    private lazy var tapGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(didTapTranslateView(_:))
    )
    
    private var moreButton: UIButton?
}

// MARK: - Notification

extension ConversationTranslateView {
    private func registerNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc
    private func applicationWillTerminate() {
        renderItem.stopTranslatingMessage()
    }
}
