//
//  EnterCodeViewController.swift
//  TempTalk
//
//  Created by Kris.s on 2025/1/8.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging
import TTServiceKit

final class EnterCodeViewController: OWSViewController {

    static let stepTextFieldWidth = 180.0
    let disableAlpha = 0.4

    var scanButton: UIButton?

    var myCodeBarBtnItem: UIBarButtonItem {
        let button = UIButton(type: .custom)
        let image = UIImage(named: "add_contact_scan")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.addTarget(self, action: #selector(scanAction), for: .touchUpInside)

        self.scanButton = button

        let barButtonItem = UIBarButtonItem(customView: button)
        return barButtonItem
    }

    fileprivate lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.text = Localized("ENTER_CODE_TITLE")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        return titleLabel
    }()

    fileprivate lazy var tipsLabel: UILabel = {
        let tipsLabel = UILabel()
        tipsLabel.textAlignment = .center
        tipsLabel.text = Localized("ENTER_CODE_TIPS")
        tipsLabel.font = UIFont.systemFont(ofSize: 14)
        tipsLabel.textColor = Theme.terrorColor
        tipsLabel.isHidden = true
        return tipsLabel
    }()

    fileprivate lazy var codeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = Localized("ENTER_CODE_PLACEHOLDER")
        textField.borderStyle = .roundedRect
        textField.layer.borderWidth = 1
        textField.layer.borderColor = Theme.lineColor.cgColor
        textField.layer.cornerRadius = 8
        textField.backgroundColor = Theme.bg1Color
        textField.textColor = Theme.tprimaryColor
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.delegate = self
        textField.keyboardType = .default
        textField.returnKeyType = .done

        // Set placeholder color
        let placeholderColor = Theme.tdisableColor
        textField.attributedPlaceholder = NSAttributedString(
            string: Localized("ENTER_CODE_PLACEHOLDER"),
            attributes: [NSAttributedString.Key.foregroundColor: placeholderColor]
        )

        return textField
    }()

    fileprivate lazy var addButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(Localized("ENTER_CODE_ADD_BUTTON"), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.setTitleColor(Theme.twhiteColor, for: .normal)
        button.backgroundColor = Theme.primaryColor
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.isEnabled = false
        button.alpha = disableAlpha
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }()

    func generateLinkUrl(inviteCode: String) -> String? {


        let inviteUrl = "https://\(AppLinkNotificationHandler.kURLHostTempTalk)\(AppLinkNotificationHandler.kULinkPathInvite)?a=pi&pi=\(inviteCode)"

        return inviteUrl
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBackButton()
        DispatchQueue.main.async {
            self.setupView()
            self.setupLayout()
            self.applyTheme()
        }
    }

    deinit {
        OWSLogger.info("enter code view deinit.")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeTextField.becomeFirstResponder()
    }

    private func setupView() {
        self.navigationItem.rightBarButtonItem = myCodeBarBtnItem
        view.addSubview(titleLabel)
        view.addSubview(codeTextField)
        view.addSubview(tipsLabel)
        view.addSubview(addButton)
    }

    private func previousViewIsInviteCode() -> Bool {
        return self.navigationController?.viewControllers.first as? DTInviteCodeViewController != nil
    }

    private func setupLayout() {

        if previousViewIsInviteCode() {
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(20 + 44)
                make.centerX.equalToSuperview()
                make.height.equalTo(28)
            }
        } else {
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(20)
                make.centerX.equalToSuperview()
                make.height.equalTo(28)
            }
        }
        codeTextField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(48)
        }
        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(codeTextField.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(20)
        }
        addButton.snp.makeConstraints { make in
            make.top.equalTo(codeTextField.snp.bottom).offset(48)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(48)
        }
    }

    override func applyTheme() {
        super.applyTheme()
        self.view.backgroundColor = Theme.bgpageSecondaryColor
        codeTextField.backgroundColor = Theme.bg1Color
        tipsLabel.textColor = Theme.terrorColor
        titleLabel.textColor = Theme.tprimaryColor
        scanButton?.tintColor = Theme.iconColor
    }

    @objc func scanAction() {
        let scanController = DTScanQRCodeController()
        scanController.didReceiveHandler = { [weak self] url in
            self?.showDeviceTransfer(url)
        }
        self.navigationController?.pushViewController(scanController, animated: true)
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        backButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        let backBarButtonItem = UIBarButtonItem(customView: backButton)
        self.navigationItem.leftBarButtonItem = backBarButtonItem
    }

    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }

    private func showDeviceTransfer(_ url: URL) {
        do {
            let urlComponent = try DeviceTransferService.shared.parseTransferURL(url)

            let alertController = UIAlertController(
                title: Localized("Transfer Data", comment: ""),
                message: String(format: Localized("Are you sure to transfer all your data to this device: %1$@?", comment: ""), urlComponent.peerId.displayName),
                preferredStyle: .alert
            )

            let cancelAction = UIAlertAction(title: Localized("Cancel", comment: ""), style: .cancel)
            let confirmAction = UIAlertAction(title: Localized("Yes", comment: ""), style: .default) { [weak self] _ in
                if DeviceTransferService.shared.launchCleanup() {
                    self?.beginTransferData(urlComponent)
                } else {
                    OWSLogger.info("launchCleanup failed")
                }
            }

            alertController.addAction(cancelAction)
            alertController.addAction(confirmAction)
            self.navigationController?.present(alertController, animated: true)
        } catch {
            OWSLogger.error("Failed to parse transfer URL: \(error)")
        }
    }

    private func beginTransferData(_ urlComponent: DeviceTransferURLComponent) {
        // Implementation from HomeViewController.beginTransferData
        // This method handles the actual data transfer process
        OWSLogger.info("Beginning device transfer")
    }

    @objc func addButtonTapped() {
        guard let code = codeTextField.text, !code.isEmpty else {
            return
        }

        tipsLabel.isHidden = true

        if isFourDigitCode(code) {
            queryByInviteCode(code)
        } else {
            searchByContactName(code)
        }
    }

    private func queryByInviteCode(_ inviteCode: String) {
        DTToastHelper.show()
        let api = DTQueryUserIdApi()
        api.quertByInviteCode(inviteCode as NSString, sucess: { [weak self] response in
            guard let self = self else { return }
            DTToastHelper.hide()

            guard let responseJson = response.responseBodyJson as? [String: Any],
                  let data = responseJson["data"] as? [String: Any] else {
                self.tipsLabel.text = Localized("ENTER_CODE_ERRORTIPS")
                self.tipsLabel.isHidden = false
                return
            }

            guard let recipientId = data["uid"] as? String, !recipientId.isEmpty else {
                self.tipsLabel.text = Localized("ENTER_CODE_ERRORTIPS")
                self.tipsLabel.isHidden = false
                return
            }

            // Extract avatar and joinedAt if available
            var avatar: [String: Any]? = nil
            if let avatarJsonString = data["avatar"] as? String {
                avatar = NSObject.signal_dictionary(withJSON: avatarJsonString) as? [String: Any]
            }

            let joinedAt = data["joinedAt"] as? String

            // Pre-configure and show personal card
            DTToastHelper.show()
            DTPersonalCardController.preConfigure(withRecipientId: recipientId) { [weak self] account in
                DTToastHelper.hide()
                guard let self = self else { return }

                if let account = account {
                    account.contact?.avatar = avatar
                    if let joinedAt = joinedAt {
                        account.contact?.joinedAt = joinedAt
                    }
                }

                self.showPersonalCardView(recipientId: recipientId, account: account)
            }
        }, failure: { [weak self] error, entity in
            guard let self = self else { return }
            DTToastHelper.hide()

            // Show error in tips label
            self.tipsLabel.text = Localized("ENTER_CODE_ERRORTIPS")
            self.tipsLabel.isHidden = false
            OWSLogger.error("Query by invite code failed: \(error.localizedDescription)")
        })
    }

    private func isFourDigitCode(_ code: String) -> Bool {
        return code.count == 4 && code.allSatisfy { $0.isNumber }
    }

    private func searchByContactName(_ contactName: String) {
        // Hide tips before API call
        tipsLabel.isHidden = true

        DTToastHelper.show()
        let api = DTDirectorySearchApi()
        api.search(contactName, success: { [weak self] result in
            guard let self = self else { return }
            DTToastHelper.hide()

            guard let result = result, !result.uid.isEmpty else {
                // Show error in tips label instead of toast
                self.tipsLabel.text = Localized("ENTER_CODE_CONTACT_NAME_ERROR")
                self.tipsLabel.isHidden = false
                return
            }

            // Extract avatar and joinedAt if available
            var avatar: [String: Any]? = nil
            if let avatarJsonString = result.avatar {
                avatar = NSObject.signal_dictionary(withJSON: avatarJsonString) as? [String: Any]
            }

            // Pre-configure and show personal card
            DTToastHelper.show()
            DTPersonalCardController.preConfigure(withRecipientId: result.uid) { [weak self] account in
                DTToastHelper.hide()
                guard let self = self else { return }

                if let account = account {
                    account.contact?.avatar = avatar
                    if let joinedAt = result.joinedAt {
                        account.contact?.joinedAt = joinedAt
                    }
                }

                self.showPersonalCardView(recipientId: result.uid, account: account)
            }
        }, failure: { [weak self] error in
            guard let self = self else { return }
            DTToastHelper.hide()

            // Show error in tips label instead of toast
            self.tipsLabel.text = Localized("ENTER_CODE_CONTACT_NAME_ERROR")
            self.tipsLabel.isHidden = false
            OWSLogger.error("Search by contact name failed: \(error.localizedDescription)")
        })
    }

    private func showPersonalCardView(recipientId: String, account: SignalAccount?) {
        var cardType = DTPersonalCardType.other
        if recipientId == TSAccountManager.localNumber() {
            cardType = .selfNoneEdit
        }

        let cardVC = DTPersonalCardController(type: cardType, recipientId: recipientId, account: account)
        cardVC.isFromContacts = true
        if let navigationController = self.navigationController {
            navigationController.pushViewController(cardVC, animated: true)
        } else {
            self.present(cardVC, animated: true)
        }
    }

}

// MARK: - UITextFieldDelegate

extension EnterCodeViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Calculate the new text after the change
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

        // Update button state based on input
        updateButtonState(with: newText)

        return true
    }

    private func updateButtonState(with text: String) {
        if text.isEmpty {
            // Disable button if empty
            tipsLabel.isHidden = true
            addButton.isEnabled = false
            addButton.alpha = disableAlpha
        } else {
            // Enable button for any non-empty input
            tipsLabel.isHidden = true
            addButton.isEnabled = true
            addButton.alpha = 1.0
        }
    }
}

extension EnterCodeViewController: OWSNavigationChildController {

    public var navbarBackgroundColorOverride: UIColor? { Theme.bgpageSecondaryColor }

    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }

    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool {
        return false
    }

    public var shouldCancelNavigationBack: Bool { false }

}
