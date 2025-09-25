//
//  DTMeetingManager+CallAlert.swift
//  TempTalk
//
//  Created by Ethan on 14/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

extension DTMeetingManager {
    func showScreenShareAlertVC(_ participantId: String) {
        roomContext?.presentMuteAlertVC(participantId)
    }
    
}
