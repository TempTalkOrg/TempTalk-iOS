//
//  DTTransferNavgationController.swift
//  Signal
//
//  Created by User on 2023/2/1.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTMessaging

@objc class DTTransferNavgationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setNavigationBarHidden(true, animated: false)
        
        refreshTheme()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    
        refreshTheme()
    }
    
    private func refreshTheme() {
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
}

enum DeviceTransferUI {
    static var qrInstructions: String {
        String(
            format: Localized("DEVICE_TRANSFER_QR_INSTRUCTIONS"),
            TSConstants.appDisplayName,
            TSConstants.appDisplayName
        )
    }

    static var inProgressInstructions: String {
        String(
            format: Localized("DEVICE_TRANSFER_IN_PROGRESS_INSTRUCTIONS"),
            TSConstants.appDisplayName
        )
    }

    static var localNetworkPermissionMessage: String {
        String(
            format: Localized("DEVICE_TRANSFER_LOCAL_NETWORK_BODY"),
            TSConstants.appDisplayName,
            TSConstants.appDisplayName
        )
    }

    static func localNetworkAlert(
        cancelHandler: @escaping () -> Void,
        settingsHandler: @escaping () -> Void
    ) -> UIAlertController {
        let alertController = UIAlertController(
            title: Localized("DEVICE_TRANSFER_LOCAL_NETWORK_TITLE"),
            message: localNetworkPermissionMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: Localized("Cancel"), style: .cancel) { _ in
            cancelHandler()
        })
        alertController.addAction(UIAlertAction(title: Localized("DEVICE_TRANSFER_SETTINGS_BUTTON"), style: .default) { _ in
            settingsHandler()
        })
        return alertController
    }

    static func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL, options: [:])
    }
}
