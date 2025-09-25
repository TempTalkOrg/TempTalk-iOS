//
//  AppSettingsViewController+ProfileCard.swift
//  Signal
//
//  Created by user on 2024/2/22.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import PanModal

@objc
extension AppSettingsViewController {
    func showPersonCardViewController( ) {
        
        guard let localNumber = TSAccountManager.localNumber() else {
            DTToastHelper.toast(withText: Localized("SHOW_PERSONAL_CARD_FAILED", ""), durationTime: 3)
            return
        }
        
        DTToastHelper.showHud(in: self.view)
        DTPersonalCardController.preConfigure(withRecipientId: localNumber) { account in
            DTToastHelper.hide()
            let profileCardVc = DTPersonalCardController(type: .selfCanEdit, recipientId: localNumber, contact: account?.contact)
            profileCardVc.modalPresentationStyle = .popover
            
            let profileCardNav =  DTPanModalNavController.init()
            profileCardNav.isShortFormEnabled = false
            profileCardNav.viewControllers = [profileCardVc]
            self.presentPanModal(profileCardNav)
            
        }
    }
    
}
