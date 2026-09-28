//
//  ConversationSendFailedTipView.swift
//  Difft
//
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

/// "Send failed · Tap to retry" hint shown below a failed outgoing bubble,
/// right-aligned to the bubble's trailing edge. Tapping the row retries the
/// send — the bubble itself no longer resends, to avoid accidental retries.
class ConversationSendFailedTipView: UIView {

    static let viewHeight: CGFloat = 23
    static let bubbleSpacing: CGFloat = 4

    private static let iconSize: CGFloat = 12
    private static let iconTextSpacing: CGFloat = 4

    var tapHandler: (() -> Void)?

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "Conversation_send_failed")?.withRenderingMode(.alwaysTemplate)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        label.text = Localized(
            "MESSAGE_STATUS_SEND_FAILED_TAP_TO_RETRY",
            comment: "Hint below a failed outgoing message, tapping it resends the message"
        )
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubviews()
        refreshTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(iconView)
        addSubview(titleLabel)

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.iconSize)
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextSpacing)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func refreshTheme() {
        iconView.tintColor = Theme.errorColor
        titleLabel.textColor = Theme.errorColor
    }

    @objc private func didTap() {
        tapHandler?()
    }
}
