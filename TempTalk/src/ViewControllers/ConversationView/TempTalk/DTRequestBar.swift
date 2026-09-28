//
//  DTRequestBar.swift
//  Signal
//
//  Created by hornet on 2023/8/4.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UIKit
import PureLayout
import TTMessaging


@objc protocol DTRequestBarDelegate {
    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, ignoreSender: UIButton)
    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, acceptSender: UIButton)
}

class DTRequestBar : UIView {
    
    @objc
    public weak var delegate: DTRequestBarDelegate?
    var sourceLabelConstraint : NSLayoutConstraint?
    private lazy var sourceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()

    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0

        let fullText = Localized("REQUEST_BAR_WARNING", comment: "⚠️ DO NOT trust unknown users.")
        let boldText = Localized("REQUEST_BAR_WARNING_BOLD", comment: "DO NOT")

        let attributedString = NSMutableAttributedString(string: fullText)
        let regularFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let boldFont = UIFont.systemFont(ofSize: 14, weight: .bold)

        // Apply regular font to entire string first
        attributedString.addAttribute(.font, value: regularFont, range: NSRange(location: 0, length: fullText.count))

        // Find and apply bold font to the bold part
        if let range = fullText.range(of: boldText) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.font, value: boldFont, range: nsRange)
        }

        label.attributedText = attributedString
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        //        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    lazy var ignoreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.layer.cornerRadius = 8.0
        button.layer.borderWidth = 2
        button.layer.masksToBounds = true
        button.adjustsImageWhenHighlighted = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Localized("IGNORE", comment: "ignore user"), for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(ignore:)), for: .touchUpInside)
        return button
    }()
    
    
    lazy var acceptButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.layer.cornerRadius = 8.0
        button.layer.masksToBounds = true
        button.adjustsImageWhenHighlighted = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Localized("ACCEPT", comment: "accept user"), for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(accept:)), for: .touchUpInside)
        return button
    }()
    
    
    @objc func applyTheme() {
        self.backgroundColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x1C1C1C) : UIColor(rgbHex: 0xF5F5F5)

        warningLabel.textColor = Theme.tprimaryColor

        ignoreButton.setTitleColor(Theme.tprimaryColor, for: .normal)
        ignoreButton.setBackgroundColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF), for: .normal)
        ignoreButton.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57).cgColor : UIColor.color(rgbHex: 0xEAECEF).cgColor
        
        acceptButton.setTitleColor(UIColor.color(rgbHex: 0xFFFFFF), for: .normal)
        acceptButton.setBackgroundColor(UIColor.color(rgbHex: 0x056FFA), for: .normal)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initPropetry()
        initCommonUI()
        configUILayout()
        applyTheme()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initPropetry() {
        
    }
    
    func initCommonUI() {
        addSubview(sourceLabel)
        addSubview(warningLabel)
        addSubview(stackView)
        stackView.addArrangedSubview(ignoreButton)
        stackView.addArrangedSubview(acceptButton)
    }
    
    func configUILayout() {
        let root = OWSWindowManager.shared().rootWindow;
        let insets = root.safeAreaInsets
        
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabelConstraint = sourceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10)
        if let sourceLabelConstraint = sourceLabelConstraint {
            NSLayoutConstraint.activate([
                sourceLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                sourceLabelConstraint,
                sourceLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }

        // 设置warningLabel的Auto Layout约束
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            warningLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            warningLabel.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 10),
            warningLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])

        // 设置StackView的Auto Layout约束
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            stackView.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor,constant: -insets.bottom)
        ])
        
    }
    
    @objc func setLabelText(_ text: String?) {
        if DTParamsUtils.validateString(text).boolValue == true {
            sourceLabelConstraint?.constant = 10
            sourceLabel.text = text
            sourceLabel.isHidden = false
        } else {
            sourceLabelConstraint?.constant = 0
            sourceLabel.isHidden = true
            sourceLabel.text = nil
        }
        self.layoutIfNeeded()
    }
    // 动态调整控件高度
    override var intrinsicContentSize: CGSize {
        let labelHeight = sourceLabel.intrinsicContentSize.height
        let warningHeight = warningLabel.intrinsicContentSize.height
        let buttonHeight = 40.0
        let totalHeight = labelHeight + warningHeight + buttonHeight + 26

        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
    
    @objc private func buttonEvent(ignore sender: UIButton) {
        self.delegate?.didTapConversationRequestBarDelegate(self, ignoreSender: sender)
    }

    @objc private func buttonEvent(accept sender: UIButton) {
        self.delegate?.didTapConversationRequestBarDelegate(self, acceptSender: sender)
    }

}

// MARK: - DTConversationWarningHeaderView

enum DTConversationNoticeHeaderStyle {
    case stranger
    case endToEndEncryption
}

class DTConversationWarningHeaderView: UIView {

    var didTapEndToEndEncryption: (() -> Void)?

    private var style: DTConversationNoticeHeaderStyle

    private lazy var warningLabel: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textAlignment = .center
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let encryptionNoticeView: DTE2EENoticeTextView = {
        let noticeView = DTE2EENoticeTextView(style: .conversation)
        noticeView.translatesAutoresizingMaskIntoConstraints = false
        noticeView.contentInsets = UIEdgeInsets(top: 10, left: 50, bottom: 10, right: 50)
        return noticeView
    }()

    init(style: DTConversationNoticeHeaderStyle = .stranger) {
        self.style = style
        super.init(frame: .zero)
        initCommonUI()
        configUILayout()
        encryptionNoticeView.didTapLearnMore = { [weak self] in
            self?.didTapEndToEndEncryption?()
        }
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(style: DTConversationNoticeHeaderStyle) {
        guard self.style != style else { return }
        self.style = style
        applyTheme()
        invalidateIntrinsicContentSize()
    }

    private func updateAttributedText() {
        let fullText = Localized("CONVERSATION_WARNING_HEADER", comment: "Privacy first. Fully anonymous and end-to-end encrypted. DO NOT trust unknown users.")
        let boldText = Localized("REQUEST_BAR_WARNING_BOLD", comment: "DO NOT")
        let learnMoreText = Localized("CONVERSATION_E2EE_LEARN_MORE", comment: "Learn more")
        let attributedString = NSMutableAttributedString()

        // Same lock icon as the end-to-end encryption notice.
        if let icon = UIImage(named: "ic_e2ee_lock")?.withTintColor(
            Theme.tthirdColor,
            renderingMode: .alwaysOriginal
        ) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -2, width: 12, height: 12)
            attributedString.append(NSAttributedString(attachment: attachment))
            attributedString.append(NSAttributedString(string: " "))
        }

        let textStartLocation = attributedString.length
        attributedString.append(NSAttributedString(string: fullText, attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: Theme.tthirdColor
        ]))

        if let range = fullText.range(of: boldText) {
            let textRange = NSRange(range, in: fullText)
            attributedString.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: 12, weight: .bold),
                range: NSRange(
                    location: textStartLocation + textRange.location,
                    length: textRange.length
                )
            )
        }

        if let range = fullText.range(of: learnMoreText, options: .backwards) {
            let textRange = NSRange(range, in: fullText)
            attributedString.addAttributes([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: Theme.tinfoColor,
                .link: URL(string: "quicall-e2ee://info") as Any
            ], range: NSRange(
                location: textStartLocation + textRange.location,
                length: textRange.length
            ))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 16
        paragraphStyle.maximumLineHeight = 16
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedString.length)
        )

        warningLabel.attributedText = attributedString
    }

    func initCommonUI() {
        addSubview(warningLabel)
        addSubview(encryptionNoticeView)
    }

    func configUILayout() {
        NSLayoutConstraint.activate([
            warningLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            warningLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            warningLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            warningLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            encryptionNoticeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            encryptionNoticeView.topAnchor.constraint(equalTo: topAnchor),
            encryptionNoticeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            encryptionNoticeView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc func applyTheme() {
        self.backgroundColor = .clear
        warningLabel.backgroundColor = .clear
        warningLabel.linkTextAttributes = [
            .foregroundColor: Theme.tinfoColor,
            .underlineStyle: 0
        ]
        updateAttributedText()
        encryptionNoticeView.applyTheme()
        warningLabel.isHidden = style != .stranger
        encryptionNoticeView.isHidden = style != .endToEndEncryption
    }

    func height(fittingWidth width: CGFloat) -> CGFloat {
        switch style {
        case .stranger:
            let labelWidth = max(0, width - 100)
            let labelHeight = warningLabel.sizeThatFits(
                CGSize(width: labelWidth, height: .greatestFiniteMagnitude)
            ).height
            return ceil(labelHeight) + 20
        case .endToEndEncryption:
            return encryptionNoticeView.height(fittingWidth: width)
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: height(fittingWidth: width))
    }

}

extension DTConversationWarningHeaderView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard URL.scheme == "quicall-e2ee" else { return true }
        didTapEndToEndEncryption?()
        return false
    }
}
