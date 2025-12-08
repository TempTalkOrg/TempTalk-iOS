//
//  DTMeetingManager+CallAlert.swift
//  TempTalk
//
//  Created by Ethan on 14/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import LiveKit

extension DTMeetingManager {
    @MainActor func showScreenShareAlertVC(_ participantId: String) {
        roomContext?.presentMuteAlertVC(participantId)
    }
    
    public func startLiveKitCall(thread: TSThread,
                                 startCall: @escaping () -> Void,
                                 joinCall: @escaping (DTLiveKitCallModel) -> Void ) {
        if let targetCall = currentThreadTargetCall(thread) {
            var inMeeting = false;
            for liveKitModel in allMeetings {
                if (liveKitModel.conversationId == targetCall.conversationId) {
                    inMeeting = true
                }
            }
            if inMeeting {
                joinCall(targetCall)
            } else {
                startCall()
            }
        } else {
            startCall()
        }
    }
    
    func minimizeAction() {
        minimizeCallWindow()
    }
    
    func inviteAction() {
        let inviteVC = DTCallInviteMemberVC()
        inviteVC.isLiveKitCall = true
        let inviteNav = OWSNavigationController(rootViewController: inviteVC)
        guard let rootNav = OWSWindowManager.shared().callViewWindow.rootViewController as? UINavigationController else {
            return
        }
        
        rootNav.present(inviteNav, animated: true)
    }
    
    func dealConnetedSuccess(with body: Livekit_TTCallResponseBody) {
        
        if DTParamsUtils.validateString(body.roomID).boolValue {
            currentCall.roomId = body.roomID
        }
        
        if DTParamsUtils.validateArray(body.stale).boolValue {
            var tempStales: [[String: Any]] = []
            let stales: [Livekit_TTExceptionRecipient] = body.stale
        
            for stale in stales {
                var dict: [String: Any] = [:]
                dict["uid"] = stale.uid
                dict["identityKey"] = stale.identityKey
                dict["registrationId"] = stale.registrationID
                
                tempStales.append(dict)
            }
            
            storeFreshPrekeys(tempStales) { [weak self] in
                guard let self else { return }
                startCall(thread: startCallThread, recipientIds: startCallRecipientIds)
            }
            
            DTToastHelper.hide()
            return
        }
        
        if DTParamsUtils.validateNumber(body.systemShowTimestamp as NSNumber).boolValue {
            currentCall.serverTimestamp = UInt64(body.systemShowTimestamp)
        }
        
        let isCaller = fromSource == "startCall"
        // 开始会议前的前置处理
        prepareForMeetingStart(isCaller: isCaller,
                                 thread: startCallThread,
                               timestamp: currentCall.timestamp,
                                 source: fromSource)
        
        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
}
