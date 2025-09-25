//
//  DTTransferDataSuccessViewController.swift
//  Wea
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging

@objc class DTTransferDataSuccessViewController: UIViewController {

    private let resetAuthPasswordApi =  DTResetAuthPasswordApi()
    private let logintoken: String?
    private var oldDevice: Bool
    
    @objc init(logintoken: String? ,oldDevice: Bool = false) {
        self.logintoken = logintoken
        self.oldDevice = oldDevice
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
//
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        autolayout()
        refreshTheme()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deregistrationStateDidChange),
                                               name: NSNotification.Name.deregistrationStateDidChange,
                                               object: nil)
        
    }
    
   
    @objc func deregistrationStateDidChange() {
//        if(TSAccountManager.shared.isDeregistered()){
//            TSSocketManager.shared().deregisteredBrokenSocket()
//            exit(0)
//        }
        guard let navigationController = self.navigationController else {
            return
        }
        navigationController.dismiss(animated: true)
    }

    
    private func setupUI() {
        view.addSubview(stackView)
        
        stackView.addArrangedSubview(successImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(okButton)
    }
    
    private func autolayout() {
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 188.0)
//            stackView.topAnchor.constraint(equalToSystemSpacingBelow: stackView.bottomAnchor, multiplier: 188/342.0)
        ])
        
        NSLayoutConstraint.activate([
            successImageView.widthAnchor.constraint(equalToConstant: 96.0),
            successImageView.heightAnchor.constraint(equalToConstant: 96.0)
        ])
        
        NSLayoutConstraint.activate([
            okButton.heightAnchor.constraint(equalToConstant: 48.0),
            okButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)
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
        okButton.setBackgroundColor(UIColor(rgbHex: 0x056FFA), for: .normal)
        okButton.setTitleColor(UIColor(rgbHex: 0xFFFFFF), for: .normal)
        
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
    
    @objc private func buttonEvent(ok sender: UIButton) {
        if(self.oldDevice){
            showDeleteDatabaseAlert()
        } else {
            showExitForReloadDatabaseAlert()
        }
    }
    
    func showExitForReloadDatabaseAlert()  {
        let alertController = UIAlertController(
            title: nil,
            message: Localized("Please restart TempTalk"),
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: Localized("TXT_OK_TITLE"), style: .cancel) { _ in
                //新设备直接退出重新进入
                exit(0)
        }
        alertController.addAction(okAction)
        navigationController?.present(alertController, animated: true)
    }
    
    func showDeleteDatabaseAlert()  {
        let alertController = UIAlertController(
            title: nil,
            message: Localized("Do you want to clear old data"),
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: Localized("TXT_CANCEL_TITLE"), style: .default) { _ in
            self.navigationController?.popViewController(animated: true, completion: nil)
            exit(0)
        }
        let okAction = UIAlertAction(title: Localized("TXT_CONFIRM_TITLE"), style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true, completion: nil)
            if(self.oldDevice){
                SignalApp.resetAppData()
                exit(0)
            } else {
                //新设备直接退出重新进入
                exit(0)
            }
        }
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        navigationController?.present(alertController, animated: true)
    }
    
    func showHomeViewController() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate;
        appDelegate?.switchToTabbarVC(fromRegistration: true)
    }
    
    func resetPassword() {
        guard let logintoken = self.logintoken else {
//            OWSLogger.info("logintoken == nil")
            return}
        let password = TSAccountManager.generateNewAccountAuthenticationToken()
        self.resetAuthPasswordApi.resetAuthPassword(logintoken, password: password) { entity in
            TSAccountManager.shared.storeServerAuthToken(password);
            self.navigationController?.popViewController(animated: true)
        } failure: { error, entity in
            //TODO:  需要和产品确认如何提示用户 （需要考虑用户杀进程之后这个password 没有重置成功如何处理）
        }
    }
    
    // MARK: - lazy
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 16.0
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var successImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "transfer-data-success")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = Localized("Transfer Success")
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = .zero
        label.text = Localized("Successfully Transferred All Your Data")
        return label
    }()
    
    private lazy var okButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 8.0
        button.adjustsImageWhenHighlighted = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Localized("OK"), for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(ok:)), for: .touchUpInside)
        return button
    }()
}
