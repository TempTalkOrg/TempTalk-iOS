//
//  HomeViewCell.swift
//  TempTalk
//
//  Created by Ethan on 18/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
extension HomeViewCell {
    
    func configCallReleted() {
        //TODO: 定时器控制的刷新
        guard thread.isCallingSticked else {
            rightCallView.isHidden = true
            dateTimeLabel.isHidden = false
            return
        }
        
        //无会议时候
        if !DTMeetingManager.shared.hasMeeting, DTMeetingManager.shared.allMeetings.count == 0 {
            rightCallView.isHidden = true
            dateTimeLabel.isHidden = false
            return
        }
        
        showMeetingBar()
        //当前会议
        let currentCall = DTMeetingManager.shared.currentCall
        
        guard let conversationId = currentCall.conversationId else {
            callDurationLabel.text = "Join"
            return
        }
        
        
        for model in DTMeetingManager.shared.allMeetings {
            if currentCall.roomId == model.roomId {
                guard let duration = currentCall.duration else {
                    Logger.info("\(logTag) currentThread \(thread.name) should show join")
                    callDurationLabel.text = "Join"
                    return
                }
                callDurationLabel.text = DTLiveKitCallModel.stringDuration(duration)
            } else {
                Logger.info("\(logTag) currentThread \(thread.name) should show join")
                if let groupThread = thread.threadRecord as? TSGroupThread {
                    guard case .group = currentCall.callType else {
                        callDurationLabel.text = "Join"
                        return
                    }
                    guard conversationId == groupThread.serverThreadId else {
                        callDurationLabel.text = "Join"
                        return
                    }
                } else if let contactThread = thread.threadRecord as? TSContactThread {
                    guard case .private = currentCall.callType else {
                        callDurationLabel.text = "Join"
                        return
                    }
                    guard conversationId == contactThread.serverThreadId else {
                        callDurationLabel.text = "Join"
                        return
                    }
                }
            }
        }
    }
}
