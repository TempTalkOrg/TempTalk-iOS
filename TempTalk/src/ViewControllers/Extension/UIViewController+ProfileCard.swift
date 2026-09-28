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
    /// - Parameter addFriendSource: how the local user got here. Required, and deliberately without
    ///   a default: only the caller knows the answer, and a wrong guess is what the recipient ends
    ///   up reading under "How you met". Pass `.unspecified` when it is genuinely unknowable.
    func showProfileCardInfo(with recipientId: String, addFriendSource: AddFriendSource, isFromSameThread : Bool = false, isPresent: Bool = true, isFromContacts: Bool = false) {
        guard !recipientId.isEmpty , let localNumber = TSAccountManager.shared.localNumber(), !localNumber.isEmpty else {
            DTToastHelper.toast(withText: Localized("SHOW_PERSONAL_CARD_FAILED", ""), durationTime: 2)
            return
        }

        DTToastHelper.showHud(in: self.view)

        DTPersonalCardController.preConfigure(withRecipientId: recipientId) { (account) in
            DTToastHelper.hide()

            var profileCardVc: DTPersonalCardController
            if recipientId == localNumber {
                profileCardVc = DTPersonalCardController(type: .selfNoneEdit, recipientId: recipientId, account: account, addFriendSource: addFriendSource)
            } else {
                profileCardVc = DTPersonalCardController(type: .other, recipientId: recipientId, account: account, addFriendSource: addFriendSource)
            }
            profileCardVc.modalPresentationStyle = .popover
            profileCardVc.isFromSameThread = isFromSameThread
            profileCardVc.isFromContacts = isFromContacts  // 传递来源信息
            if (isPresent){
                let profileCardNav =  DTPanModalNavController.init()
                profileCardNav.viewControllers = [profileCardVc]
                // The conversation remains visible behind this half-height card.
                // Do not let PanModal drive its full disappear/appear lifecycle;
                // that path clears media and rebuilds visible conversation UI.
                profileCardNav.disableAppearanceTransition = true
                self.presentPanModal(profileCardNav)
            } else {
                self.navigationController?.pushViewController(profileCardVc, animated: true)
            }
            
        }
    }
}


