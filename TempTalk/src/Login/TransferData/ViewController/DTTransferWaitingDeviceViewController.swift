//
//  DTTransferWaitingDeviceViewController.swift
//  Wea
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import QuartzCore
import MultipeerConnectivity
import TTMessaging

@objc class DTTransferWaitingDeviceViewController: UIViewController {
    private enum ReceiverScreenState {
        case inactive
        case generatingQRCode
        case displayingQRCode
        case waitingForForeground
        case retryRequired
    }

    private let logintoken: String
    private var oldDevice: Bool
    private var qrCodeGenerationWorkItem: DispatchWorkItem?
    private var receiverScreenState: ReceiverScreenState = .inactive
    /// Held weakly and checked via `presentingViewController` rather than latched on a Bool:
    /// if presentation is pre-empted (a system prompt is up, or the previous alert is still
    /// animating away) the next failure can present again instead of being swallowed forever.
    private weak var transferFailureAlert: UIAlertController?

    @objc init(logintoken: String, oldDevice: Bool = false) {
        self.logintoken = logintoken
        self.oldDevice = oldDevice
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The user sets this device down and picks up the old one to scan. Keep the QR
        // receiver alive while this screen is visible so auto-lock cannot interrupt it.
        DeviceSleepManager.shared.addBlock(blockObject: self)
        DeviceTransferService.shared.addObserver(self)
        restartReceiverAttempt()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        cancelQRCodeGeneration()
        qrCodeActivityIndicator.stopAnimating()
        DeviceSleepManager.shared.removeBlock(blockObject: self)
        DeviceTransferService.shared.removeObserver(self)
        receiverScreenState = .inactive
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            DeviceTransferService.shared.cancelTransferFromOldDevice()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        autolayout()
        refreshTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func setupUI() {
        view.addSubview(stackView)
        view.addSubview(cancelButton)
        view.addSubview(qrCodeActivityIndicator)
        
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
            qrCodeActivityIndicator.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor),
            qrCodeActivityIndicator.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    /// The single entry point for creating a usable receiver attempt. Repeated lifecycle and
    /// recovery callbacks coalesce while generation is already in progress.
    private func restartReceiverAttempt() {
        AssertIsOnMainThread()

        guard UIApplication.shared.applicationState == .active else {
            prepareToRestartWhenActive()
            return
        }
        guard receiverScreenState != .generatingQRCode else { return }

        cancelQRCodeGeneration()
        DeviceTransferService.shared.stopTransfer()
        transferFailureAlert = nil
        receiverScreenState = .generatingQRCode
        renderWaitingState()
        // Fade rather than hide: this is an arranged subview of `stackView` with required
        // 200pt constraints, so `isHidden` makes the stack collapse it to zero and the
        // activity indicator — which is centred on it — lands under the subtitle.
        qrCodeImageView.alpha = 0
        qrCodeActivityIndicator.startAnimating()
        view.layoutIfNeeded()
        // `DispatchQueue.main.async` only defers generation to the next queue drain; it does
        // not guarantee that Core Animation submits the loading frame first. Flush the pending
        // transaction so the spinner is visible while receiver setup occupies the main thread.
        CATransaction.flush()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.qrCodeGenerationWorkItem = nil
            // The screen can leave the window between scheduling and running. `viewWillAppear`
            // regenerates on return, so stop the spinner rather than leaving it turning over
            // a hidden QR code with nothing scheduled to replace it.
            guard self.viewIfLoaded?.window != nil else {
                self.qrCodeActivityIndicator.stopAnimating()
                self.receiverScreenState = .inactive
                return
            }
            self.generateQRCodeNow()
        }
        qrCodeGenerationWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func generateQRCodeNow() {
        AssertIsOnMainThread()

        do {
            let receiverStartTime = ProcessInfo.processInfo.systemUptime
            let url = try DeviceTransferService.shared.startAcceptingTransfersFromOldDevices(mode: .primary)
            let receiverReadyTime = ProcessInfo.processInfo.systemUptime
            let qrCode = try UIImage.qrCode(url.absoluteString)
            let qrCodeReadyTime = ProcessInfo.processInfo.systemUptime

            qrCodeActivityIndicator.stopAnimating()
            qrCodeImageView.image = qrCode
            qrCodeImageView.alpha = 1
            logoImageView.isHidden = true
            receiverScreenState = .displayingQRCode
            Logger.info(
                "[DeviceTransfer][NewDevice] QR code displayed; receiver is waiting for invitation; " +
                "receiverMs=\(Int((receiverReadyTime - receiverStartTime) * 1_000)), " +
                "imageMs=\(Int((qrCodeReadyTime - receiverReadyTime) * 1_000))"
            )
        } catch {
            let nsError = error as NSError
            Logger.error(
                "[DeviceTransfer][NewDevice] Failed to prepare QR screen; " +
                "domain=\(nsError.domain), code=\(nsError.code), " +
                "description=\(nsError.localizedDescription)"
            )
            owsFailDebug("error \(error)")
            DeviceTransferService.shared.stopTransfer()
            renderRetryRequired(
                title: Localized("Transfer Failed"),
                message: Localized("DEVICE_TRANSFER_QR_GENERATION_FAILED_BODY")
            )
        }
    }

    private func renderWaitingState() {
        titleLabel.text = Localized("Waiting for the Old Device…")
        subtitleLabel.text = DeviceTransferUI.qrInstructions
        cancelButton.setTitle(Localized("Cancel"), for: .normal)
    }

    private func renderRetryRequired(title: String, message: String) {
        AssertIsOnMainThread()

        receiverScreenState = .retryRequired
        qrCodeActivityIndicator.stopAnimating()
        qrCodeImageView.alpha = 0
        titleLabel.text = title
        subtitleLabel.text = message
        cancelButton.setTitle(Localized("RETRY_BUTTON_TEXT"), for: .normal)
    }

    private func cancelQRCodeGeneration() {
        qrCodeGenerationWorkItem?.cancel()
        qrCodeGenerationWorkItem = nil
    }

    @objc private func applicationDidBecomeActive() {
        guard receiverScreenState == .waitingForForeground else { return }
        restartReceiverAttempt()
    }

    private func prepareToRestartWhenActive() {
        receiverScreenState = .waitingForForeground
        cancelQRCodeGeneration()
        DeviceTransferService.shared.stopTransfer()
        renderWaitingState()
        qrCodeImageView.alpha = 0
        qrCodeActivityIndicator.stopAnimating()
    }
    
    
    @objc private func buttonEvent(cancel sender: UIButton) {
        if receiverScreenState == .retryRequired {
            restartReceiverAttempt()
            return
        }

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

    private lazy var qrCodeActivityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
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
        label.text = DeviceTransferUI.qrInstructions
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
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String : String]?) {}
    
    func deviceTransferServiceDidStartTransfer(progress: Progress) {
        let controller = DTTransferReceivingViewController(logintoken: self.logintoken, progress: progress, oldDevice: self.oldDevice)
        navigationController?.pushViewController(controller, animated: true)
    }

    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?) {
        guard let error = error else { return }

        if case .cancel = error {
            return
        }

        if case .backgroundedDevice = error {
            if UIApplication.shared.applicationState == .active {
                restartReceiverAttempt()
            } else {
                prepareToRestartWhenActive()
            }
            return
        }

        if case .localNetworkPermissionDeniedAfterSystemPrompt = error {
            guard viewIfLoaded?.window != nil,
                  navigationController?.topViewController === self else { return }
            DeviceTransferService.shared.stopTransfer()
            navigationController?.popViewController(animated: true)
            return
        }

        if case .localNetworkPermissionDenied = error {
            guard transferFailureAlert?.presentingViewController == nil else { return }
            DeviceTransferService.shared.stopTransfer()
            let alertController = DeviceTransferUI.localNetworkAlert(
                cancelHandler: { [weak self] in
                    guard let self else { return }
                    self.transferFailureAlert = nil
                    self.navigationController?.popViewController(animated: true)
                },
                settingsHandler: { [weak self] in
                    guard let self else { return }
                    self.transferFailureAlert = nil
                    self.prepareToRestartWhenActive()
                    DeviceTransferUI.openAppSettings()
                }
            )
            transferFailureAlert = alertController
            present(alertController, animated: true)
            return
        }

        guard transferFailureAlert?.presentingViewController == nil else { return }
        DeviceTransferService.shared.stopTransfer()

        let alertController = UIAlertController(
            title: "Transfer Failed".localized,
            message: error.message,
            preferredStyle: .alert
        )
        let confirmAction = UIAlertAction(title: "OK".localized, style: .default) { [weak self] _ in
            guard let self else { return }
            self.transferFailureAlert = nil
            self.restartReceiverAttempt()
        }
        alertController.addAction(confirmAction)
        transferFailureAlert = alertController
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
        qrCodeActivityIndicator.color = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x82C1FC : 0x056FFA)
        
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
}
