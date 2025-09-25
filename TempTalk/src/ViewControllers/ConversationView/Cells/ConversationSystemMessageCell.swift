//
//  ConversationSystemMessageCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/16.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

protocol ConversationSystemMessageCellDelegate: AnyObject {
    func systemMessageCell(
        _ cell: ConversationSystemMessageCell,
        didTappedNonBlockingIdentityChangeWith recipientId: String?
    )
    
    func systemMessageCell(
        _ cell: ConversationSystemMessageCell,
        didTappedAttributedMessageWith message: TSInfoMessage
    )
    
    func systemMessageCell(
        _ cell: ConversationSystemMessageCell,
        resendGroupUpdateWith errorMessage: TSErrorMessage
    )
    
    func systemMessageCell(
        _ cell: ConversationSystemMessageCell,
        showFingerprintWith recipientId: String
    )
    
    func systemMessageCell(
        _ cell: ConversationSystemMessageCell,
        didTappedReportedMessageWith message: TSInfoMessage
    )
}

class ConversationSystemMessageCell: ConversationCell {
    
    @objc
    static let reuserIdentifier = "ConversationSystemMessageCell"
    
    weak var delegate: ConversationSystemMessageCellDelegate?
    
    private var renderItem: ConversationSystemRenderItem?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        layoutMargins = .zero
        contentView.layoutMargins = .zero
        
        titleStackView.addArrangedSubviews([iconView, titleLabel])
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(ConversationSystemRenderItem.iconSize)
        }
        
        bottomStackView.addArrangedSubviews([lineView, titleStackView, actionButton])
        lineView.snp.makeConstraints { make in
            make.height.equalTo(ConversationSystemRenderItem.lineViewHeight)
            make.leading.equalToSuperview().offset(0)
            make.trailing.equalToSuperview().offset(0)
        }
        actionButton.snp.makeConstraints { make in
            make.width.height.equalTo(ConversationSystemRenderItem.buttonHeight)
        }
        
        containerStackView.addArrangedSubviews([headerView, bottomStackView])
        headerView.snp.makeConstraints { make in
            make.height.equalTo(0)
        }
        
        contentView.addSubview(containerStackView)
        containerStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func configure(renderItem: ConversationSystemRenderItem) {
        self.renderItem = renderItem
        
        if let infoMessage = renderItem.viewItem.interaction as? TSInfoMessage, infoMessage.messageType == .reportedMessage {
            configureReportedMessage(renderItem: renderItem)
        }
        
        configureHeaderView(renderItem: renderItem)
        configureLineView(renderItem: renderItem)
        configureIconView(renderItem: renderItem)
        configureTitleLabel(renderItem: renderItem)
        configureActionButton(renderItem: renderItem)
        
        bottomStackView.layoutMargins = renderItem.bottomStackViewLayoutMargins
    }
    
    private func configureReportedMessage(renderItem: ConversationSystemRenderItem) {
        bottomStackView.removeAllSubviews()
        reportedStackView.addArrangedSubviews([leftIconView, titleLabel])
        leftIconView.snp.makeConstraints { make in
            make.width.height.equalTo(ConversationSystemRenderItem.leftIconSize)
        }
        bottomStackView.addArrangedSubviews([lineView, reportedStackView, actionButton])
    }
    
    override func refreshTheme() {
        lineView.backgroundColor = Theme.secondaryTextAndIconColor
        iconView.tintColor = .ows_light60
        leftIconView.tintColor = .ows_light60
        actionButton.setTitleColor(.ows_darkSkyBlue, for: .normal)
        actionButton.backgroundColor = Theme.secondaryBackgroundColor
    }
    
    // MARK: - Action
    
    @objc func handleTapTitleLabel(_ sender: UITapGestureRecognizer) {
        guard let infoMessage = renderItem?.viewItem.interaction as? TSInfoMessage else {
            return
        }
        
        if infoMessage.messageType == .reportedMessage {
            delegate?.systemMessageCell(self, didTappedReportedMessageWith: infoMessage)
            return
        }
        
        guard let attrString = titleLabel.attributedText, !attrString.string.isEmpty else {
            return
        }
        
        var ranges: [NSValue] = []
        attrString.enumerateAttributes(
            in: NSRange(location: 0, length: attrString.length),
            options: .reverse,
            using: { attrs, range, stop in
                if !attrs.isEmpty {
                    ranges.append(.init(range: range))
                }
            }
        )
        
        let didTapLink = sender.didTapAttributedText(in: titleLabel, inRanges: ranges)
        if didTapLink {
            delegate?.systemMessageCell(self, didTappedAttributedMessageWith: infoMessage)
        }
    }
    
    @objc func handleTapActionButton() {
        guard let buttonAction = renderItem?.buttonAction else {
            return
        }
        switch buttonAction {
        case let .nonBlockingIdentityChange(recipientId):
            delegate?.systemMessageCell(self, didTappedNonBlockingIdentityChangeWith: recipientId)
        case let .groupCreationFailed(errorMessage):
            delegate?.systemMessageCell(self, resendGroupUpdateWith: errorMessage)
        case let .verificationStateChange(recipientId):
            delegate?.systemMessageCell(self, showFingerprintWith: recipientId)
        }
    }
    
    // MARK: - Lazy Load
    
    private lazy var containerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    private lazy var headerView = OWSMessageHeaderView()
    
    private lazy var bottomStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ConversationSystemRenderItem.bottomStackViewSpacing
        stackView.alignment = .center
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var lineView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    
    private lazy var titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ConversationSystemRenderItem.titleStackViewSpacing
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var reportedStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = ConversationSystemRenderItem.leftIconTitleStackViewSpacing
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var iconView = UIImageView()
    private lazy var leftIconView = UIImageView()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        label.textColor = .ows_lightGray01
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapTitleLabel))
        label.addGestureRecognizer(tap)
        
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 4
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(handleTapActionButton), for: .touchUpInside)
        return button
    }()
}

// MARK: - Private

private extension ConversationSystemMessageCell {
    
    func configureHeaderView(renderItem: ConversationSystemRenderItem) {
        if let headerItem = renderItem.headerRenderItem {
            headerView.isHidden = false
            headerView.loadForDisplay(with: headerItem.viewItem, conversationStyle: headerItem.conversationStyle)
            headerView.snp.updateConstraints { make in
                make.height.equalTo(headerItem.viewSize.height)
            }
        } else {
            headerView.isHidden = true
        }
    }
    
    func configureLineView(renderItem: ConversationSystemRenderItem) {
        if renderItem.isShowLineView {
            lineView.isHidden = false
            lineView.snp.updateConstraints { make in
                make.leading.equalToSuperview().offset(renderItem.lineViewMarginLeft)
                make.trailing.equalToSuperview().offset(-renderItem.lineViewMarginRight)
            }
        } else {
            lineView.isHidden = true
        }
    }
    
    func configureIconView(renderItem: ConversationSystemRenderItem) {
        if let icon = renderItem.icon {
            iconView.image = icon.withRenderingMode(.alwaysTemplate)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }
        
        if let leftIcon = renderItem.leftIcon {
            leftIconView.image = leftIcon.withRenderingMode(.alwaysTemplate)
            leftIconView.isHidden = false
        } else {
            leftIconView.isHidden = true
        }
    }
    
    func configureTitleLabel(renderItem: ConversationSystemRenderItem) {
        renderItem.titleConfig.applyForRendering(label: titleLabel)
        titleLabel.snp.updateConstraints { make in
            make.width.equalTo(renderItem.titleSize.width)
        }
    }
    
    func configureActionButton(renderItem: ConversationSystemRenderItem) {
        if let buttonAction = renderItem.buttonAction {
            actionButton.isHidden = false
            buttonAction.titleConfig.applyForRendering(button: actionButton)
            actionButton.snp.updateConstraints { make in
                make.width.equalTo(renderItem.actionButtonSize.width)
            }
        } else {
            actionButton.isHidden = true
        }
    }
}
