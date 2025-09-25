//
//  DTTransferWaitingDeviceViewController.swift
//  Wea
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import TTMessaging

@objc class DTTransferWaitingDeviceViewController: UIViewController {
    private let logintoken: String
    private var oldDevice: Bool
    
    @objc init(logintoken: String, oldDevice: Bool = false) {
        self.logintoken = logintoken
        self.oldDevice = oldDevice
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DeviceTransferService.shared.addObserver(self)
        generatorQRCode()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DeviceTransferService.shared.removeObserver(self)
//        DeviceTransferService.shared.cancelTransferFromOldDevice(complete: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        autolayout()
        refreshTheme()
    }
    
    private func setupUI() {
        view.addSubview(stackView)
        view.addSubview(cancelButton)
        
        qrCodeImageView.addSubview(logoImageView)
        
        stackView.addArrangedSubview(titleStackView)
        stackView.addArrangedSubview(qrCodeImageView)
        
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(subtitleLabel)
    }
    
    private func autolayout() {
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100)
//            stackView.topAnchor.constraint(equalToSystemSpacingBelow: stackView.bottomAnchor, multiplier: 100/226.0)
        ])
        
        NSLayoutConstraint.activate([
            qrCodeImageView.widthAnchor.constraint(equalToConstant: 200.0),
            qrCodeImageView.heightAnchor.constraint(equalToConstant: 200.0)
        ])
        
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 72.0),
            logoImageView.heightAnchor.constraint(equalToConstant: 72.0),
            logoImageView.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func generatorQRCode() {
        do {
            let url = try DeviceTransferService.shared.startAcceptingTransfersFromOldDevices(mode: .primary)
            let qrCode = try UIImage.qrCode(url.absoluteString)
            
            qrCodeImageView.image = qrCode
            logoImageView.isHidden = true
        } catch {
            owsFailDebug("error \(error)")
        }
    }
    
    
    @objc private func buttonEvent(cancel sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - lazy
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 40.0
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 16.0
        stackView.alignment = .fill
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = .init(named: "transfer-data-logo")
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var qrCodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 8
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = Localized("Waiting for the Old Device…")
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = .zero
        label.text = Localized("Open TempTalk on your old device, bring it nearby, and make sure Wi-Fi and Bluetooth are enabled on both devices. Then, Scan the following QR code with the old device.")
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(Localized("Cancel"), for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(cancel:)), for: .touchUpInside)
        return button
    }()
}

extension DTTransferWaitingDeviceViewController: DeviceTransferServiceObserver {
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String : String]?) {
        Logger.info("\(peerId.displayName)")
    }
    
    func deviceTransferServiceDidStartTransfer(progress: Progress) {
        let controller = DTTransferReceivingViewController(logintoken: self.logintoken, progress: progress, oldDevice: self.oldDevice)
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?) {
        Logger.info("[DeviceTransferModule -> func -> DidEndTransfer] error reason = \(String(describing: error?.localizedDescription))")
        guard let error = error else {
            Logger.info("[DeviceTransferModule -> func -> DidEndTransfer] error = nil)")
            return }
        let alertController = UIAlertController(
            title: Localized("Transfer Failed"),
            message: String(format: Localized("The transfer failed. %1$@.Please try again."), error.message),
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: Localized("OK"), style: .default) { action in
            
        }
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }
    
}

extension DTTransferWaitingDeviceViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    
        refreshTheme()
    }
    
    private func refreshTheme() {
        let textColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
        titleLabel.textColor = textColor
        subtitleLabel.textColor = textColor
        cancelButton.setTitleColor(UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x82C1FC : 0x056FFA), for: .normal)
        
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
}
