//
//  DTMeetingManagerProtocol.swift
//  Difft
//
//  Created by Henry on 2025/4/11.
//  Copyright © 2025 Difft. All rights reserved.
//


import Foundation

@objc public protocol DTMeetingManagerProtocol: NSObjectProtocol {
    
    @objc func isInMeeting() -> Bool
    
    @objc func criticalAlertIncomingLocalMessage(entity: DTServerNotifyCriticalAlertEntity,
                                                 transation: SDSAnyWriteTransaction)
}
