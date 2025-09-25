//
//  HomeViewController.swift
//  Difft
//
//  Created by Henry on 2025/4/11.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

@objc extension HomeViewController {
    func handleRemoteCallNotify(apnsInfo: DTApnsInfo) {
        guard let callInfo = apnsInfo.passthroughInfo["callInfo"] as? [String: Any] else {
            return
        }

        let isSchedule = (callInfo["type"] as? String) == "meeting-popups"
        let mode = callInfo["mode"] as? String
        let caller = callInfo["caller"] as? String
        let meetingName = callInfo["meetingName"] as? String
        let groupId = callInfo["groupId"] as? String
        let callType = callInfo["callType"] as? NSNumber
        let emk = callInfo["emk"] as? String
        let meetingVersion = callInfo["meetingVersion"] as? NSNumber
        let meetingId = callInfo["meetingId"] as? String
        let numberIsLiveStream = callInfo["isLiveStream"] as? NSNumber
        let eid = callInfo["eid"] as? String
        let isLiveStream = (numberIsLiveStream as? NSNumber)?.boolValue ?? false
        
        let callModel = DTLiveKitCallModel()
        callModel.callState = .alerting
        callModel.caller = caller
        callModel.roomId = meetingId
        callModel.roomName = meetingName ?? ""
        callModel.callType = .instant
        if DTParamsUtils.validateString(groupId).boolValue {
            callModel.conversationId = groupId
            if callType == 1 {
                callModel.callType = .private
            } else if callType == 2 {
                callModel.callType = .group
            }
        }
        if let localNumber = TSAccountManager.localNumber(), callType == 1 {
            callModel.callees = [localNumber]
        }
        DTMeetingManager.shared.acceptCall(call: callModel)
    }
}
