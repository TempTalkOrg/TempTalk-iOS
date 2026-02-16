//
//  DTConfidentialMessageContentViewController.swift
//  TempTalk
//
//  Created by henry on 2026/01/24.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import TTMessaging

/// 机密消息提示的内容视图控制器
@objc
public class DTConfidentialMessageContentViewController: UIViewController {

    // MARK: - Properties

    @objc public var confirmHandler: (() -> Void)?

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupContent()
    }

    // MARK: - UI Setup

    private func setupContent() {
        view.backgroundColor = .clear

        // Icon
        iconImageView.image = UIImage(named: "confident_alert_icon")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = Theme.tprimaryColor
        view.addSubview(iconImageView)

        // Title
        titleLabel.text = Localized("CONFIDENTIAL_MESSAGE_VIEW_ALERT_TITLE",
                                           comment: "Title for confidential message alert")
        titleLabel.textColor = Theme.tprimaryColor
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        // Message
        messageLabel.text = Localized("CONFIDENTIAL_MESSAGE_VIEW_ALERT_MESSAGE",
                                             comment: "Message for confidential message alert")
        messageLabel.textColor = Theme.tsecondaryColor
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        view.addSubview(messageLabel)

        // Button
        confirmButton.setTitle(CommonStrings.okButton(), for: .normal)
        confirmButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        confirmButton.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        view.addSubview(confirmButton)

        // SnapKit Layout
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-24)
            make.height.equalTo(48)
        }
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        // Mark as shown
        databaseStorage.asyncWrite { transaction in
            SSKPreferences.setHasShownConfidentialMessageAlert(true, transaction: transaction)
        }

        // Dismiss parent FloatingConversationViewController
        if let floatingVC = parent as? FloatingConversationViewController {
            floatingVC.dismiss(animated: true) { [weak self] in
                self?.confirmHandler?()
            }
        } else {
            // Fallback: dismiss presenting view controller
            presentingViewController?.dismiss(animated: true) { [weak self] in
                self?.confirmHandler?()
            }
        }
    }
}
