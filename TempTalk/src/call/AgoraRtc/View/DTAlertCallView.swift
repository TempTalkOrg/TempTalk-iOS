//
//  DTAlertCallView.swift
//  TempTalk
//
//  Created by Ethan on 18/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTMessaging

@objc
extension DTAlertCallView {
    
    private struct AssociatedKeys {
        static var liveKitCallKey: Int8 = 0
    }
    
    @objc var liveKitCall: DTLiveKitCallModel {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.liveKitCallKey) as! DTLiveKitCallModel
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.liveKitCallKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func configLiveKitAlertCall(_ call: DTLiveKitCallModel) {
        self.liveKitCall = call
        
        guard let callerId = call.caller else {
            return
        }
        
        let contactsManager = Environment.shared.contactsManager!
        let callerName = contactsManager.displayName(forPhoneIdentifier: callerId)
        
        let leftTextColor = UIColor(rgbHex: 0xD9271E)
        leftButton.setTitleColor(leftTextColor, for: .normal)
        leftButton.setTitleColor(leftTextColor, for: .highlighted)
        
        if case .private = call.callType {
            titleLabel.text = callerName
            avatarView.setImageWithRecipientId(callerId)
            subTitleLabel.text = Localized("CALL_INCOMING_ALERT_INVITE_CALL")
            leftButton.setTitle(
                Localized("CALL_INCOMING_ALERT_REFUSE"),
                for: .normal
            )
            rightButton.setTitle(
                Localized("CALL_INCOMING_ALERT_ACCEPT"),
                for: .normal
            )
        } else {
            titleLabel.text = call.roomName
            subTitleLabel.text = "\(callerName) \(Localized("CALL_INCOMING_ALERT_INVITE_CALL"))"
            leftButton.setTitle(
                Localized("CALL_INCOMING_ALERT_IGNORE"),
                for: .normal
            )
            rightButton.setTitle(
                Localized("CALL_INCOMING_ALERT_ACCEPT"),
                for: .normal
            )
            
            if case .instant = call.callType {
                avatarView.image = UIImage(named: "ic_instant_meeting")
            } else {
                guard let gid = call.conversationId,
                   let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
                   let groupThread = TSGroupThread.getWithGroupId(groupId) else {
                    avatarView.image = UIImage(named: "empty-group-avatar")
                    return
                }
                
                avatarView.image = OWSAvatarBuilder.buildImage(
                    thread: groupThread,
                    diameter: 48,
                    contactsManager: contactsManager
                )
            }
        }
    }
    
    
}

