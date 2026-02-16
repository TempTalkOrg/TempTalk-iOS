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

class DTConversationWarningHeaderView: UIView {

    private let warningLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
        initCommonUI()
        configUILayout()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabel() {
        let fullText = Localized("CONVERSATION_WARNING_HEADER", comment: "🔒 Privacy first. Fully anonymous and end-to-end encrypted. DO NOT trust unknown users.")
        let boldText = Localized("REQUEST_BAR_WARNING_BOLD", comment: "DO NOT")

        let attributedString = NSMutableAttributedString(string: fullText)
        let regularFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let boldFont = UIFont.systemFont(ofSize: 12, weight: .bold)

        attributedString.addAttribute(.font, value: regularFont, range: NSRange(location: 0, length: fullText.count))

        if let range = fullText.range(of: boldText) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.font, value: boldFont, range: nsRange)
        }

        warningLabel.attributedText = attributedString
    }

    func initCommonUI() {
        addSubview(warningLabel)
    }

    func configUILayout() {
        NSLayoutConstraint.activate([
            warningLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            warningLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            warningLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            warningLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    @objc func applyTheme() {
        self.backgroundColor = .clear
        warningLabel.backgroundColor = .clear
        warningLabel.textColor = Theme.tthirdColor
    }

    override var intrinsicContentSize: CGSize {
        let labelHeight = warningLabel.intrinsicContentSize.height
        let totalHeight = labelHeight + 20 // 10 top + 10 bottom padding
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
}
