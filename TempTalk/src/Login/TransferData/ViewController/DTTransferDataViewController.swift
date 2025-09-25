//
//  DTTransferDataViewController.swift
//  Wea
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging

extension String {
    var localized: Self {
        localized(using: nil)
    }
}

@objc class DTTransferDataViewController: UIViewController {
    private let renewAccountApi = DTRenewAccountApi()
    private let loginType: DTLoginModeType
    private let email : String?
    private let phoneNumber: String?
    private let dialingCode: String?
    private let logintoken: String?
    private let tdtToken: String?
    
    @objc init(loginType: DTLoginModeType = DTLoginModeTypeLoginViaEmail, email: String?, phoneNumber: String?, dialingCode: String?, logintoken: String?, tdtToken: String?) {
        self.loginType = loginType
        self.email = email
        self.phoneNumber = phoneNumber
        self.dialingCode = dialingCode
        self.logintoken = logintoken
        self.tdtToken = tdtToken
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        autolayout()
        refreshTheme()
    }
    
    private func setupUI() {
        view.addSubview(stackView)
//        view.addSubview(withoutButton)
        
        stackView.addArrangedSubview(logoImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(continueButton)
        stackView.addArrangedSubview(withoutButton)
//        stackView.addArrangedSubview(continueLabel)
    }
    
    private func autolayout() {
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 188.0)
//            stackView.topAnchor.constraint(equalToSystemSpacingBelow: stackView.bottomAnchor, multiplier: 188/294.0)
        ])
        
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 88.0),
            logoImageView.heightAnchor.constraint(equalToConstant: 72.0)
        ])
        
        NSLayoutConstraint.activate([
            continueButton.heightAnchor.constraint(equalToConstant: 48.0),
            continueButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
        
        NSLayoutConstraint.activate([
            withoutButton.heightAnchor.constraint(equalToConstant: 48.0),
            withoutButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    
        refreshTheme()
    }
    
    private func refreshTheme() {
        let textColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
        titleLabel.textColor = textColor
        subtitleLabel.textColor = textColor
//        continueLabel.textColor = textColor
        continueButton.setBackgroundColor(UIColor(rgbHex: 0x056FFA), for: .normal)
        continueButton.setTitleColor(UIColor(rgbHex: 0xFFFFFF), for: .normal)
        withoutButton.setTitleColor(Theme.primaryTextColor, for: .normal)
        withoutButton.setBackgroundColor(Theme.backgroundColor, for: .normal)
        withoutButton.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57).cgColor : UIColor.color(rgbHex: 0xEAECEF).cgColor
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
    
    @objc private func buttonEvent(continue sender: UIButton) {
        if(self.loginType == DTLoginModeTypeLoginViaEmail) {
            self.saveEmailInKeyChain()
        } else if(self.loginType == DTLoginModeTypeLoginViaPhone) {
            self.savePhoneInKeyChain()
        }
        guard let token = self.logintoken else {
            OWSLogger.info("token == nil")
            return
        }
        let controller = DTTransferWaitingDeviceViewController(logintoken: token, oldDevice: false)
        navigationController?.pushViewController(controller, animated: true)
    }
    
    @objc private func buttonEvent(without sender: UIButton) {
        let alertController = UIAlertController(
            title: "Login without Transferring".localized,
            message: "All the messages on your old device will be deleted permanently. Are you sure to continue?".localized,
            preferredStyle: .alert
        )
        let deleteAction = UIAlertAction(title: "Delete and Login".localized, style: .destructive) { _ in
            self.deleteAndLogin()
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
    
    func deleteAndLogin() {
        guard let token = self.logintoken else {
            OWSLogger.info("token == nil")
            return
        }
        DTToastHelper.show()
        renewAccountApi.renewAccount(token) { entity in
            guard let data = entity?.data as? [String: Any] else {return}
            guard let verificationCode = data["verificationCode"] as? String else {return}
            guard let number = data["account"] as? String else {return}
            TSAccountManager.sharedInstance().phoneNumberAwaitingVerification = number
            TSAccountManager.sharedInstance().setTransferedSucess(false)
            TSAccountManager.sharedInstance().setIsDeregistered(false)
            do {
                let screenLockEntity = try MTLJSONAdapter.model(of: DTScreenLockEntity.self, fromJSONDictionary: data) as! DTScreenLockEntity
                self.registerWithVcode(vcode: verificationCode, screenlock: screenLockEntity)
            } catch {
                owsFailDebug("ScreenLockEntity error: \(error)")
            }
            
        } failure: { error, entity in
            DTToastHelper.hide()
            let errorMessage  = NSError.errorDesc(error, errResponse: entity)
            let validateErrMsg = DTParamsUtils.validateString(errorMessage)
            guard  validateErrMsg.boolValue == true  else {
                DTToastHelper.toast(withText: "Delete And Login failed, please try again".localized);
                return
            }
            DTToastHelper.toast(withText: errorMessage)
        }
    }
    
    
    func registerWithVcode(vcode: String, screenlock: DTScreenLockEntity) {
        DTLoginNeedUnlockScreen.checkIfNeedScreenlock(vcode: vcode,
                                                      screenlock: screenlock,
                                                      processedVc: self) {
            self.verificationWasCompleted();
        } errorBlock: { _ in
            
        }

    }
    
    func verificationWasCompleted() {
        if(self.loginType == DTLoginModeTypeLoginViaEmail) {
            self.saveEmailInKeyChain()
        } else if(self.loginType == DTLoginModeTypeLoginViaPhone) {
            self.savePhoneInKeyChain()
        }
        self.requestContactInfo()
        DTCallManager.sharedInstance().requestForConfigMeetingversion()
    }
    
    func saveEmailInKeyChain() {
        if(DTParamsUtils.validateString(self.email).boolValue == true){
            TSAccountManager.shared.storeUserEmail(self.email!)
        }
    }
    
    func savePhoneInKeyChain() {
        guard DTParamsUtils.validateString(self.phoneNumber).boolValue == true else {return}
        let plusPhoneNumber = DTPatternHelper.verificationTextInputNumer(withPlus: self.phoneNumber!)
        if(DTParamsUtils.validateString(self.phoneNumber).boolValue == true && DTParamsUtils.validateString(self.dialingCode).boolValue == true && DTParamsUtils.validateString(plusPhoneNumber).boolValue != true){
            let phoneNumber = self.dialingCode! + self.phoneNumber!
            TSAccountManager.shared.storeUserPhone(phoneNumber)
            return
        }
        TSAccountManager.shared.storeUserPhone(self.phoneNumber!)
        return
    }
    
    func requestContactInfo() {
        let localNumber = TSAccountManager.sharedInstance().localNumber()
        guard let localNum = localNumber else { return }
        TSAccountManager.sharedInstance().getContactMessage(byReceptid: localNum) {[weak self] c in
            DTToastHelper.hide()
            guard let self = self else { return}
            
            self.databaseStorage.asyncWrite { writeTransaction in
                let contact = c;
                let contactsManager = Environment.shared.contactsManager;
                var account = contactsManager?.signalAccount(forRecipientId: localNum, transaction: writeTransaction)
                if(account == nil){account = SignalAccount.init(recipientId: localNum)}
                guard let account = account else {return}
                account.contact = contact
                contactsManager?.updateSignalAccount(withRecipientId: localNum, withNewSignalAccount: account, with: writeTransaction)
                writeTransaction.addAsyncCompletionOnMain {
                    self.showHomeViewController()
                }
            }
            
        } failure: { error in
            DTToastHelper.hide()
            self.showHomeViewController()
        }
    }
    
    func showHomeViewController() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate;
        appDelegate?.switchToTabbarVC(fromRegistration: true)
    }
    
    
    // MARK: - lazy
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 24.0
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "transfer-data-devices")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "Transfer Data".localized
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = .zero
        label.text = "For security reasons, your data is only stored on your devices. If you have your old device, you can securely transfer it to this device.".localized
        return label
    }()
    
    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.layer.cornerRadius = 8.0
        button.layer.masksToBounds = true
        button.adjustsImageWhenHighlighted = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Transfer".localized, for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(continue:)), for: .touchUpInside)
        return button
    }()
    
//    private lazy var continueLabel: UILabel = {
//        let label = UILabel()
//        label.font = UIFont.systemFont(ofSize: 12)
//        label.numberOfLines = .zero
//        label.textAlignment = .center
//        label.text = Localized("Continuing will disable your account on other devices.")
//        return label
//    }()
    
    private lazy var withoutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.layer.cornerRadius = 8.0
        button.layer.masksToBounds = true
        button.layer.borderWidth = 1.0
        button.adjustsImageWhenHighlighted = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Localized("Login without Transferring"), for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(without:)), for: .touchUpInside)
        return button
    }()
}
