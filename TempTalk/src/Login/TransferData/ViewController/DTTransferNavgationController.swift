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
