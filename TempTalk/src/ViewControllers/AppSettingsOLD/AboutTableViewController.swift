//
//  AboutTableViewController.swift
//  Signal
//
//  Created by user on 2024/3/18.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

extension  AboutTableViewController {
    @objc
    func openDesktopApp() {
        let guideUrlString = DTInstallationGuideConfig.serverDefaultInstallationGuideUrlString()
        if !guideUrlString.isEmpty {
            if DTMiniProgramManger.sharedManager().isMiniApplicationLink(guideUrlString),
                let url = URL.init(string: guideUrlString) {
                DTURLHandler.handleMiniProgram(url: url, sourceVC: self, showWarning: false)
            } else {
                if let url = URL(string: guideUrlString) {
                    let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [.universalLinksOnly: false]
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: options) { success in
                            if success {
                                Logger.info("open url success")
                            } else {
                                Logger.info("open url fail")
                            }
                        }
                    }
                }
            }
        }
    }
    
}
