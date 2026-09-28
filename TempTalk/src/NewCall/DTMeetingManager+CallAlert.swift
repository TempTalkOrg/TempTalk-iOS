//
//  DTMeetingManager+CallAlert.swift
//  TempTalk
//
//  Created by Ethan on 14/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import LiveKit
import TTServiceKit

extension DTMeetingManager {
    static func shouldCommitGroupStartCallMessageDuringTeardown(
        call: DTLiveKitCallModel,
        source: String?,
        acceptedRoomId: String
    ) -> Bool {
        source == "startCall" &&
            !acceptedRoomId.isEmpty &&
            call.isInitiator &&
            call.callType == .group &&
            call.controlType == sourceControlStart &&
            !call.createCallMsg
    }

    /// A successful start-call can race with a local hangup. In teardown we must not resume the
    /// meeting flow, but the accepted call still needs the same ordinary-IM CallMsg as the normal
    /// `createCallMsg == false` success path.
    @MainActor
    func commitAcceptedGroupStartCallMessageDuringTeardown(
        call: DTLiveKitCallModel,
        thread: TSThread?,
        source: String?,
        body: Livekit_TTCallResponseBody
    ) {
        let shouldCommit = Self.shouldCommitGroupStartCallMessageDuringTeardown(
            call: call,
            source: source,
            acceptedRoomId: body.roomID
        )
        guard shouldCommit else {
            return
        }

        let redactedClientCallId = Self.redactedCallLogIdentifier(call.clientCallId)
        let redactedRoomId = Self.redactedCallLogIdentifier(body.roomID)
        Logger.info(
            "\(logTag)[callmsg-bind] accepted group start during teardown " +
                "clientCallId=\(redactedClientCallId) roomId=\(redactedRoomId)"
        )

        guard let thread else {
            Logger.error(
                "\(logTag)[callmsg-bind] cannot enqueue CallMsg: missing thread " +
                    "clientCallId=\(redactedClientCallId) roomId=\(redactedRoomId)"
            )
            return
        }

        sendGroupCallMessage(
            thread: thread,
            call: call,
            acceptedRoomId: body.roomID,
            trigger: "teardown-success"
        )
    }

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
    
    @MainActor
    func dealConnetedSuccess(with body: Livekit_TTCallResponseBody) {

        if DTParamsUtils.validateString(body.roomID).boolValue {
            Logger.info("\(logTag) current call add roomId = \(body.roomID)")
            currentCall.roomId = body.roomID

            if !(usesOneToOneConnectionFlow && currentCall.isCaller) {
                stopCallTimeoutTimer()
            }

            // 使用统一的 RoomIdManager 保存
            RoomIdManager.shared.saveRoomId(
                body.roomID,
                callType: currentCall.callType,
                conversationId: currentCall.conversationId,
                timestamp: currentCall.timestamp ?? DTTrustedClock.now()
            )
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

        // ✅ Fix: Extract timestamp and serverTimestamp from response body
        // systemShowTimestamp is the authoritative server timestamp that should be used for both
        let serverTimestamp: UInt64? = DTParamsUtils.validateNumber(body.systemShowTimestamp as NSNumber).boolValue
            ? UInt64(body.systemShowTimestamp)
            : nil

        let isCaller = fromSource == "startCall"
        // 开始会议前的前置处理
        prepareForMeetingStart(isCaller: isCaller,
                                 thread: startCallThread,
                               timestamp: currentCall.timestamp,
                               serverTimestamp: serverTimestamp,
                                 source: fromSource)

        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
}
