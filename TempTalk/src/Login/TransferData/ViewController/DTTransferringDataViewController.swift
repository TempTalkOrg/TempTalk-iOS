//
//  DTTransferringDataViewController.swift
//  Signal
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import TTServiceKit
import TTMessaging

@objc class DTTransferringDataViewController: UIViewController {
    private let urlComponent: DeviceTransferURLComponent
    private let logintoken: String?
    private let oldDevice: Bool
    
    private var progress: Progress? {
        willSet {
            progress.map {
                $0.removeObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted))
            }
        }
        didSet {
            progress.map {
                $0.addObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted), options: .initial, context: nil)
            }
        }
    }
    
    @objc init(logintoken: String?, urlComponent: DeviceTransferURLComponent, oldDevice : Bool = false) {
        self.urlComponent = urlComponent
        self.logintoken = logintoken
        self.oldDevice = oldDevice
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.progress = nil
    }
    
    override func loadView() {
        super.loadView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DeviceTransferService.shared.addObserver(self)
        DeviceTransferService.shared.startListeningForNewDevices()
        beginTransfer()
        Logger.info("DeviceTransferService:::: = \(DeviceTransferService.shared)");
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DeviceTransferService.shared.removeObserver(self)
        DeviceTransferService.shared.stopListeningForNewDevices()
        DeviceTransferService.shared.cancelTransferToNewDevice()
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
        
        stackView.addArrangedSubview(titleStackView)
        stackView.addArrangedSubview(progressStackView)
        
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(subtitleLabel)
        
        progressStackView.addArrangedSubview(progressLabel)
        progressStackView.addArrangedSubview(progressView)
        progressStackView.addArrangedSubview(timeLabel)
    }
    
    private func autolayout() {
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100.0)
//            stackView.topAnchor.constraint(equalToSystemSpacingBelow: stackView.bottomAnchor, multiplier: 100/362.0)
        ])
        
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: progressStackView.leadingAnchor, constant: 32.0),
            progressView.trailingAnchor.constraint(equalTo: progressStackView.trailingAnchor, constant: -32.0),
            progressView.heightAnchor.constraint(equalToConstant: 4.0)
        ])
        
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func beginTransfer() {
        //TODO:temptalk need handle
//        TSSocketManager.shared().deregisteredBrokenSocket()
        DispatchQueue.global().async {
            do {
                try DeviceTransferService.shared.transferAccountToNewDevice(with: self.urlComponent.peerId, certificateHash: self.urlComponent.certificateHash)
            } catch {
                // TODO: Error
                // Alert
            }
        }
    }
    @objc private func buttonEvent(cancel sender: UIButton) {
        DeviceTransferService.shared.stopTransfer()
        self.dismiss(animated: true)
    }
    
    // MARK: - lazy
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 80.0
        stackView.alignment = .fill
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "Transferring Data".localized
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = .zero
        label.text = "Keep both devices on and near each other.".localized
        return label
    }()
    
    private lazy var progressStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 22.0
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView()
        progress.layer.cornerRadius = 2.0
        progress.layer.masksToBounds = true
        return progress
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.text = "0%"
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.text = "--"
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Cancel".localized, for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(cancel:)), for: .touchUpInside)
        return button
    }()
}

extension DTTransferringDataViewController: DeviceTransferServiceObserver {
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String : String]?) {
        Logger.info("[DeviceTransferModule -> DTTransferringDataViewController -> func -> deviceTransferServiceDiscoveredNewDevice] peerId = \(peerId.displayName)")
    }
    
    func deviceTransferServiceDidStartTransfer(progress: Progress) {
        Logger.info("[DeviceTransferModule -> DTTransferringDataViewController -> func -> deviceTransferServiceDidStartTransfer (progress:)]")
        self.progress = progress
        //TODO:temptalk need handle
//        if TSSocketManager.shared().state != .closed {
//            TSSocketManager.shared().deregisteredBrokenSocket()
//        }
    }
    
    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?) {
        DTToastHelper.hide()
        guard let error = error  else {
            Logger.info("[DeviceTransferModule -> DTTransferringDataViewController -> func -> deviceTransferServiceDidEndTransfer] no error message")
            //TODO: 旧设备数据转移成功
            //TODO: 清理登陆密码,标记为未登陆状态
            if(self.oldDevice){
                TSAccountManager.shared.setIsDeregistered(true)
                TSAccountManager.shared.setTransferedSucess(true)
            }
            navigationController?.setViewControllers([DTTransferDataSuccessViewController(logintoken: self.logintoken, oldDevice: self.oldDevice)], animated: true)
            return
        }
        Logger.info("[DeviceTransferModule -> DTTransferringDataViewController -> func -> deviceTransferServiceDidEndTransfer] error.message: \(String(describing: error.message))")
        let alertController = UIAlertController(
            title: "Transfer Failed".localized,
            message: String(format: "The transfer failed. %1$@.Please try again.".localized, error.message),
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "OK".localized, style: .default) { _ in
            self.dismiss(animated: true)
        }
        alertController.addAction(okAction)
        navigationController?.present(alertController, animated: true)
    }
}

extension DTTransferringDataViewController {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(Progress.fractionCompleted) else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
        guard let progress = self.progress else { return }

        DispatchMainThreadSafe {
            self.progressLabel.text = "\(Int(progress.fractionCompleted * 100))%"
            self.progressView.setProgress(Float(progress.fractionCompleted), animated: true)
            if let estimatedTime = progress.estimatedTimeRemaining, estimatedTime.isFinite {
                self.timeLabel.text = String(format: "About %1$@ second remaining".localized, "\(Int(estimatedTime))")
            } else {
                self.timeLabel.text = "--"
            }
        }
    }
}

extension DTTransferringDataViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    
        refreshTheme()
    }
    
    private func refreshTheme() {
        let textColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
        titleLabel.textColor = textColor
        subtitleLabel.textColor = textColor
        progressLabel.textColor = textColor
        timeLabel.textColor = textColor
        progressView.trackTintColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x474D57 : 0xEAECEF)
        progressView.progressTintColor = UIColor(rgbHex: 0x056FFA)
        cancelButton.setTitleColor(UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x82C1FC : 0x056FFA), for: .normal)
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
}

