//
//  UIViewController+ProfileCard.swift
//  Signal
//
//  Created by user on 2024/2/22.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging

@objc
extension UIViewController {
    func showProfileCardInfo(with recipientId: String, isFromSameThread : Bool = false, isPresent: Bool = true) {
        guard !recipientId.isEmpty , let localNumber = TSAccountManager.shared.localNumber(), !localNumber.isEmpty else {
            DTToastHelper.toast(withText: Localized("SHOW_PERSONAL_CARD_FAILED", ""), durationTime: 2)
            return
        }
        
        DTToastHelper.showHud(in: self.view)
        
        DTPersonalCardController.preConfigure(withRecipientId: recipientId) { (account) in
            DTToastHelper.hide()
            
            var profileCardVc: DTPersonalCardController
            if recipientId == localNumber {
                profileCardVc = DTPersonalCardController(type: .selfNoneEdit, recipientId: recipientId, account: account)
            } else {
                profileCardVc = DTPersonalCardController(type: .other, recipientId: recipientId, account: account)
            }
            profileCardVc.modalPresentationStyle = .popover
            profileCardVc.isFromSameThread = isFromSameThread
            if (isPresent){
                let profileCardNav =  DTPanModalNavController.init()
                profileCardNav.viewControllers = [profileCardVc]
                self.presentPanModal(profileCardNav)
            } else {
                self.navigationController?.pushViewController(profileCardVc, animated: true)
            }
            
        }
    }
}



