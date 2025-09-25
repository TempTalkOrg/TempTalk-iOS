//
//  DTHomeVirtualCell.swift
//  TempTalk
//
//  Created by Ethan on 18/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
extension DTHomeVirtualCell {
    
    func updateMeetingDuration() {
        let currentCall = DTMeetingManager.shared.currentCall
        guard let roomId = currentCall.roomId,
              roomId == virtualThread.uniqueId else {
            callDurationLabel.text = "Join"
            return
        }

        guard let duration = currentCall.duration else {
            callDurationLabel.text = "Join"
            return
        }
        
        callDurationLabel.text = DTLiveKitCallModel.stringDuration(duration)
    }
    
    func getMeetingName() -> String {
      
        let allMeetings = DTMeetingManager.shared.allMeetings
        guard let targetCall = allMeetings.filter({
            $0.roomId == virtualThread.uniqueId
        }).first else {
            return DTCallManager.defaultInstanceMeetingName()
        }
        
        var instanceName: String
        if let caller = DTMeetingManager.shared.currentCall.caller {
            let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: caller)
            if name == caller {
                instanceName = DTMeetingManager.shared.currentCall.roomName ?? DTCallManager.defaultInstanceMeetingName()
            } else {
                if name.contains("instant call") {
                    instanceName = name
                } else {
                    instanceName = "\(name)'s instant call"
                }
            }
        } else {
            let targetName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: targetCall.caller)
            if DTParamsUtils.validateString(targetName).boolValue {
                if targetName.contains("instant call") {
                    instanceName = targetName
                } else {
                    instanceName = "\(targetName)'s instant call"
                }
            } else {
                instanceName = "instant call"
            }
        }
    
        return instanceName
    }
    
}
