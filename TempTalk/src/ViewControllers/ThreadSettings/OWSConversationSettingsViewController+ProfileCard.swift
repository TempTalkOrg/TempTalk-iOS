//
//  OWSConversationSettingsViewController+ProfileCard.swift
//  Signal
//
//  Created by user on 2024/2/22.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
extension OWSConversationSettingsViewController {
    func showProfileCardInfo(_ recipientId: String) {
        assert(recipientId.count > 0)
        guard !recipientId.isEmpty ,
              let localNumber = TSAccountManager.shared.localNumber(),
              !localNumber.isEmpty else {
            
            DTToastHelper.toast(withText: Localized("SHOW_PERSONAL_CARD_FAILED", ""), durationTime: 2)
            
            return
        }
        
        DTToastHelper.showHud(in: self.view)
        DTPersonalCardController.preConfigure(withRecipientId: recipientId) { account in
            DTToastHelper.hide()
            var profileCardVC: DTPersonalCardController
            if recipientId == localNumber {
                profileCardVC = DTPersonalCardController(type: .selfNoneEdit, recipientId: recipientId, account: account)
            } else {
                profileCardVC = DTPersonalCardController(type: .other, recipientId: recipientId, account: account)
            }
            self.navigationController?.pushViewController(profileCardVC, animated: true)
        }
    }
}
