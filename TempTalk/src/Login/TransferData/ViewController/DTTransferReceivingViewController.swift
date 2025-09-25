//
//  DTTransferReceivingViewController.swift
//  Signal
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import MultipeerConnectivity

@objc class DTTransferReceivingViewController: UIViewController {
    
    private let progress: Progress
    private let logintoken: String
    private let oldDevice: Bool
    
    @objc init(logintoken: String, progress: Progress, oldDevice: Bool) {
        self.logintoken = logintoken
        self.progress = progress
        self.oldDevice = oldDevice
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        progress.addObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted), options: .initial, context: nil)
        
        DeviceTransferService.shared.addObserver(self)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        progress.removeObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted))
        DeviceTransferService.shared.removeObserver(self)
        DeviceTransferService.shared.stopAcceptingTransfersFromOldDevices()
        DeviceTransferService.shared.cancelTransferFromOldDevice()
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
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func buttonEvent(cancel sender: UIButton) {
//        navigationController?.popViewController(animated: true, completion: nil)
        self.dismiss(animated: true)
    }
    
    private func showTransferSuccess() {
        let controller = DTTransferDataSuccessViewController(logintoken: self.logintoken)
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .coverVertical
        navigationController?.present(controller, animated: true)
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
        label.text = "Receiving Data".localized
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
        label.text = String(format: "About %1$@ second remaining".localized, "0")
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

extension DTTransferReceivingViewController: DeviceTransferServiceObserver {
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String : String]?) {
        OWSLogger.info("[DeviceTransferModule -> func -> DiscoveredNewDevice] peerId = \(peerId.displayName)")
    }
    
    func deviceTransferServiceDidStartTransfer(progress: Progress) {
    }
    
    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?) {
        OWSLogger.info("[DeviceTransferModule -> func -> DidEndTransfer] error = \(String(describing: error?.message))")
        
        guard let error = error else {
            if(!self.oldDevice){
                TSAccountManager.shared.setTransferedSucess(false)
            }
            navigationController?.setViewControllers([DTTransferDataSuccessViewController(logintoken: self.logintoken, oldDevice: self.oldDevice)], animated: true )
            return
        }
        
        let alertController = UIAlertController(
            title: "Transfer Failed".localized,
            message: String(format: "The transfer failed. %1$@.Please try again.".localized, error.message),
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "OK".localized, style: .default) { _ in
            self.navigationController?.popViewController(animated: true, completion: nil)
        }
        alertController.addAction(okAction)
        navigationController?.present(alertController, animated: true)
    }
    
}

extension DTTransferReceivingViewController {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(Progress.fractionCompleted) else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
        
        DispatchMainThreadSafe {
            self.progressLabel.text = "\(Int(self.progress.fractionCompleted * 100))%"
            self.progressView.setProgress(Float(self.progress.fractionCompleted), animated: true)
            if let estimatedTime = self.progress.estimatedTimeRemaining, estimatedTime.isFinite {
                self.timeLabel.text = String(format: "About %1$@ second remaining".localized, "\(Int(estimatedTime))")
            } else {
                self.timeLabel.text = "--"
            }
        }
    }
}

extension DTTransferReceivingViewController {
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
