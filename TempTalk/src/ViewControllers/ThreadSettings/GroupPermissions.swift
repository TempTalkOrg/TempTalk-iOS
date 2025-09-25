//
//  GroupPermissions.swift
//  Signal
//
//  Created by Kris.s on 2024/11/25.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc(DTGroupPermissions)
class GroupPermissions: NSObject {
    
    @objc static func isGroupManger(groupModel: TSGroupModel) -> Bool {
        guard let localNumber = TSAccountManager.shared.localNumber() else {
            return false
        }
        return groupModel.groupOwner == localNumber || groupModel.groupAdmin.contains(localNumber)
    }
    
    @objc static func showAlert(viewController: UIViewController, title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: Localized("OK"), style: .default, handler: nil)
        alertController.addAction(okAction)
        viewController.present(alertController, animated: true)
    }
    
    @objc static func showGroupInvitePermission(viewController: UIViewController, groupModel: TSGroupModel) -> Bool {
        if isGroupManger(groupModel: groupModel) {
            if !groupModel.linkInviteSwitch {
                showAlert(viewController: viewController, title: "", message: Localized("INVITE_LINK_NEED_OPEN_GROUP_LINK_DESC"))
                return false
            } else {
                return true
            }
        } else {
            if !groupModel.linkInviteSwitch {
                showAlert(viewController: viewController, title: Localized("INVITE_LINK_FORBIDEN_DESC"), message: Localized("INVITE_LINK_NEED_OPEN_GROUP_LINK_DESC"))
                return false
            } else {
                return true
            }
        }
    }
    
    @objc static func hasPermissionToAddGroupMembers(groupModel: TSGroupModel) -> Bool {
        if groupModel.invitationRule == 2 {
            return true
        } else if groupModel.invitationRule == 1 {
            return groupModel.isSelfGroupOwner() || groupModel.isSelfGroupModerator()
        } else if groupModel.invitationRule == 0 {
            return groupModel.isSelfGroupOwner()
        }
        return false
    }
    
    @objc static func hasPermissionToRemoveGroupMembers(groupModel: TSGroupModel) -> Bool {
        if !groupModel.isSelfGroupOwner() && !groupModel.isSelfGroupModerator() {
            return false
        }
        return true
    }
    
    
   
}
