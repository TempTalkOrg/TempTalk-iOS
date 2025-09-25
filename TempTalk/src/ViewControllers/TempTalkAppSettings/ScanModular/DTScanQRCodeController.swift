//
//  DTScanQRCodeController.swift
//  Signal
//
//  Created by hornet on 2022/10/28.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import SafariServices
import MultipeerConnectivity

class DTScanQRCodeController: OWSViewController, QRCodeScanDelegate {
    let qrCodeScanViewController = QRCodeScanViewController.init(appearance: .framed, showUploadPhotoButton: false)
    @objc var linkDeviceSucess: ((Error?) -> Void)?
    @objc var didReceiveHandler: ((URL) -> Void)?
    
    override func viewDidLoad() {
        self.qrCodeScanViewController.delegate = self;
        view.backgroundColor = UIColor.white
        view.addSubview(self.qrCodeScanViewController.view)
        self.qrCodeScanViewController.view.autoPinEdge(toSuperviewEdge: ALEdge.leading)
        self.qrCodeScanViewController.view.autoPinEdge(toSuperviewEdge: ALEdge.trailing)
        self.qrCodeScanViewController.view.autoPinEdge(toSuperviewSafeArea: ALEdge.top)
        self.qrCodeScanViewController.view.autoPinEdge(ALEdge.bottom, to: ALEdge.bottom, of: view)
        self.qrCodeScanViewController.view.autoPinToSquareAspectRatio()
        self.addChild(self.qrCodeScanViewController)
        applyTheme()
    }
    
    override func applyTheme() {
        super.applyTheme()
        self.view.backgroundColor = Theme.defaultBackgroundColor
    }
    
    func qrCodeScanViewScanned(
        qrCodeData: Data?,
        qrCodeString: String?
    ) -> QRCodeScanOutcome {

        guard let qrCodeString = qrCodeString else { return .continueScanning }
        guard let url = URL.init(string: qrCodeString) else { return .continueScanning}
        
        if(AppLinkManager.handle(url: url, fromExternal: true)) {
            return .stopScanning
        } else if (DataTransferHandler.canHandle(url: url)) {
            self.goBack { self.didReceiveHandler?(url) }
            return .stopScanning
        } else if(url.scheme == "https") {
            let options = [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false]
            UIApplication.shared.open(url, options: options)
            self.navigationController?.popViewController(animated: true)
            return .stopScanning
        } else if (DTLinkDeviceURLParser.shared.isValidLink(qrCodeString)) {
            guard let (deviceId, pubKey) = DTLinkDeviceURLParser.shared.parse(qrCodeString) else {
                return .continueScanning
            }
            let alertController = UIAlertController(title: Localized("Link this device?", comment: .empty),
                                                    message: Localized("This device will be able to see your groups and contacts, read all your messages, and send messages in your name.",
                                                                               comment: .empty),
                                                    preferredStyle: .alert
            )
            let cancelAction = UIAlertAction(title: Localized(CommonStrings.cancelButton(), comment: .empty), style: .cancel) { _ in
                self.navigationController?.popViewController(animated: true)
            }
            let linkAction = UIAlertAction(title: Localized("Link New Device", comment: .empty), style: .default) { _ in
                DTLinkDeviceURLParser.shared.linkDevice(deviceId: deviceId, pubKey: pubKey)
                    .done { [weak self] _ in
                        if let linkDeviceSucess = self?.linkDeviceSucess {
                            linkDeviceSucess(nil)
                        }
                        self?.navigationController?.popViewController(animated: true, completion: nil)
                    }.catch { [weak self] in
                        self?.qrCodeScanViewController.tryToStartScanning()
                        DTToastHelper._showError($0.localizedDescription)
                    }
            }
            alertController.addAction(cancelAction)
            alertController.addAction(linkAction)
            
            present(alertController, animated: true)
            return .stopScanning
        } else {
            DTToastHelper.toast(withText: "Invalid code")
            if((self.navigationController?.viewControllers.first as? DTInviteCodeViewController) != nil){
                self.navigationController?.dismiss(animated: true)
            } else{
                self.navigationController?.popViewController(animated: true)
            }
            return .stopScanning
        }
    }
    
    func qrCodeScanViewDismiss(_ qrCodeScanViewController: QRCodeScanViewController) {
        
    }
    
    
    private func goBack(with completion: (() -> Void)? = nil) {
        guard let viewControllers = self.navigationController?.viewControllers, viewControllers.count > 1 else {
            self.dismiss(animated: true, completion: completion)
            return
        }
        if((self.navigationController?.viewControllers.first as? DTInviteCodeViewController) != nil){
            self.navigationController?.dismiss(animated: true, completion: completion)
        } else {
            self.navigationController?.popViewController(animated: true, completion: completion)
        }
    }
}

