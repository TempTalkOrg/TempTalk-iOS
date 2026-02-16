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

        // Try to get caller from targetCall first, then fallback to currentCall
        let caller: String? = targetCall.caller ?? DTMeetingManager.shared.currentCall.caller

        guard let validCaller = caller, !validCaller.isEmpty else {
            // No valid caller, return default name
            return DTCallManager.defaultInstanceMeetingName()
        }

        let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: validCaller)

        // Check if displayName returned a valid name (not the phone number itself and not nil/empty)
        if name == validCaller || name.isEmpty {
            // displayName failed, try roomName or return default
            return targetCall.roomName ?? DTMeetingManager.shared.currentCall.roomName ?? DTCallManager.defaultInstanceMeetingName()
        }

        // Valid name found
        if name.contains("instant call") {
            return name
        } else {
            return "\(name)'s instant call"
        }
    }
    
}
