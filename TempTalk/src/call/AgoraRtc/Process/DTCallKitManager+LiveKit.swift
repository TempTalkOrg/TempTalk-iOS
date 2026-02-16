//
//  DTCallKitManager+LiveKit.swift
//  TempTalk
//
//  Created by Ethan on 12/27/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
public extension DTCallKitManager {
    func decryptMsg(_ msg: String) -> DSKProtoCallMessageCalling? {
        guard let data = Data(base64Encoded: msg) else {
            Logger.error("decryptMsg error: 0")
            return nil
        }

        guard let signalingKey = TSAccountManager.signalingKey() else {
            Logger.error("decryptMsg error: 1")
            return nil
        }

        guard let decryptedPayload = SSKCryptography.decryptAppleMessagePayload(data as Data, withSignalingKey: signalingKey) else {
            Logger.error("decryptMsg error: 2")
            return nil
        }

        guard let envelope = try? DSKProtoEnvelope(serializedData: decryptedPayload) else {
            Logger.error("decryptMsg error: 3")
            return nil
        }

        guard envelope.type == .etoee else {
            Logger.error("decryptMsg error: 4")
            return nil
        }

        guard envelope.hasContent else {
            Logger.error("decryptMsg error: 5")
            return nil
        }

        var plaintextData: Data?
        databaseStorage.write { writeTransaction in
            let result = Self.messageDecrypter.decryptEnvelope(
                envelope,
                envelopeData: decryptedPayload,
                transaction: writeTransaction
            )
            switch result {
            case let .success(result):
                if let resultData = result.plaintextData {
                    plaintextData = resultData
                }
            case .failure:
                return
            }
        }

        guard let plaintextData, let content = try? DSKProtoContent(serializedData: plaintextData) else {
            return nil
        }

        guard let callMessage = content.callMessage, let calling = callMessage.calling else {
            Logger.error("decryptMsg error: 7")
            return nil
        }

        if !calling.hasRoomID, let roomID = envelope.roomID {
            // 发起会议时候没有 roomId, 申请会议成功后才有
            let builder = calling.asBuilder()
            builder.setRoomID(roomID)
            let calling = try? builder.build()

            if let calling {
                return calling
            } else {
                Logger.error("decryptMsg error: 8")
                return nil
            }
        } else {
            return calling
        }
    }

    /// CallKit接听
    /// - Parameters:
    ///   - type: CallType, OC不支持swift String enum, 映射处理(0: unknown, 1: 1on1, 2: group, 3: instant)
    ///   - roomId: roomId
    ///   - timestamp: timestamp

    func acceptCall(calling: DSKProtoCallMessageCalling) {
        // Extract all data from protobuf object synchronously before async context
        guard let roomId = calling.roomID else {
            Logger.error("\(logTag) roomId is nil")
            return
        }

        let caller = calling.caller
        let roomName = calling.roomName ?? DTCallManager.defaultMeetingName()
        let publicKey = calling.publicKey
        let emk = calling.emk
        let conversationID = calling.conversationID
        let createCallMsg = calling.createCallMsg
        let controlType = calling.controlType
        let inviteCallees = calling.callees
        let timestamp = calling.timestamp

        func acceptCallAction() async {
            let newCall = DTLiveKitCallModel()
            newCall.callState = .alerting
            newCall.caller = caller
            newCall.roomId = roomId
            newCall.roomName = roomName
            newCall.publicKey = publicKey
            newCall.emk = emk

            var callType: CallType = .instant
            if let conversationId = conversationID {
                let callInfo = conversationId.getCallInfo()
                newCall.conversationId = callInfo.conversationId
                callType = callInfo.callType
            }
            newCall.callType = callType
            if case .private = callType, let localNumber = TSAccountManager.localNumber() {
                newCall.callees = [localNumber]
            }
            newCall.createCallMsg = createCallMsg
            newCall.controlType = controlType
            newCall.inviteCallees = inviteCallees
            newCall.timestamp = timestamp

            Logger.info("\(logTag) from callkit show Livekit answer")
            DispatchMainThreadSafe {
                DTMeetingManager.shared.showAnswer(call: newCall, fromCallKit: true)
            }
        }

        let manager = DTMeetingManager.shared
        Task {
            if manager.hasMeeting, let oldRoomId = manager.currentCall.roomId, oldRoomId != roomId {
                Logger.info("CallKit: last call not ended, caller:\(manager.currentCall.caller ?? "no caller")")
                if DTCallKitManager.shared().callsCount == 1 {
                    Logger.info("\(self.logTag) hangup last call meeting")
                    await DTMeetingManager.shared.hangupCall(needSyncCallKit: true,
                                                             isByLocal: true,
                                                             roomId: oldRoomId,
                                                             removeMeetingBar: true)

                    // 清理旧会议的 alert view，防止在接听新会议后显示
                    Logger.info("\(self.logTag) remove alert view for old call: \(oldRoomId)")
                    await MainActor.run {
                        DTMeetingManager.shared.callAlertManager.removeLiveKitAlertCall(oldRoomId)
                    }
                }

                Logger.info("CallKit: The last call is ended  - stared a new call")
                await acceptCallAction()
            } else {
                Logger.info("CallKit: normal accept.")
                await acceptCallAction()
            }
        }
    }
}

@objc
public extension DTCallKitManager {
    private enum AssociatedKeys {
        static var timingKey: Int8 = 0
        static var isCheckingKey: Int8 = 1
    }

    private var timing: TimeInterval {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.timingKey) as? TimeInterval {
                return value
            }
            return 0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.timingKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    /// 当前是否有checking roomId请求未返回
    private var isChecking: Bool {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.isCheckingKey) as? Bool {
                return value
            }
            return false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isCheckingKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    /// 监控超时 / 检查对方是否cancel
    /// - Parameter callerId: callerId
    @objc
    func startTimeoutTimer(callerId: String) {
        DispatchMainThreadSafe { [self] in
            stopTimeroutTimer()
            let userInfo = ["callerId": callerId]
            callKitTimeOutTimer = Timer.weakTimer(withTimeInterval: 1,
                                                  target: self,
                                                  selector: #selector(checkCallAvailable),
                                                  userInfo: userInfo,
                                                  repeats: true)
            if let callKitTimeOutTimer {
                RunLoop.current.add(callKitTimeOutTimer,
                                    forMode: .common)
                checkCallAvailable(callKitTimeOutTimer)
            }
        }
    }

    func stopTimeroutTimer() {
        timing = 0
        isChecking = false
        guard let callKitTimeOutTimer else {
            return
        }
        callKitTimeOutTimer.invalidate()
        self.callKitTimeOutTimer = nil
    }

    /// 超过48s超时挂断, 未超过检查对方是否cancel

    func checkCallAvailable(_ timer: Timer) {
        timing += 1
        guard let userInfo = timer.userInfo as? [String: String], let callerId = userInfo["callerId"] else {
            stopTimeroutTimer()
            return
        }

        if timing >= 48 {
            // miss call
            stopTimeroutTimer()
            endCallAction(callerId, onlyForCallKit: false)
            return
        }
        Logger.debug("\(logTag) timing: \(timing)")
        // 每2s检查一次roomId是否有效
        let remainder = timing.truncatingRemainder(dividingBy: 2)
        guard remainder == 0 else { return }

        guard let calling = calling(fromCallerId: callerId),
              let roomId = calling.roomID
        else {
            stopTimeroutTimer()
            endCallAction(callerId, onlyForCallKit: false)
            return
        }

        guard !isChecking else {
            return
        }
        isChecking = true

        Task {
            let result = await DTMeetingManager.checkRoomIdValid(roomId)
            isChecking = false
            guard let result else {
                Logger.info("\(logTag) roomId invalid")
                stopTimeroutTimer()
                // 只有48s超时
                //    endCallAction(callerId, onlyForCallKit: false)
                return
            }

            let anotherDeviceJoined = result.anotherDeviceJoined
            let userStopped = result.userStopped

            if anotherDeviceJoined || userStopped {
                Logger.info("\(logTag) roomId valid, anotherDeviceJoined = \(anotherDeviceJoined), userStopped = \(userStopped)")
                stopTimeroutTimer()
                endCallAction(callerId, onlyForCallKit: false)
                return
            }
        }
    }

    func hangupFromCallKit(_ roomId: String) {
        Task {
            Logger.info("\(self.logTag) hangup callkit trigger endcall action")
            await DTMeetingManager.shared.hangupCall(needSyncCallKit: false,
                                                     isByLocal: true,
                                                     roomId: roomId,
                                                     removeMeetingBar: true,
                                                     isFromCallKit: true)
            DTMeetingManager.shared.syncServerCalls()
        }
    }

    func muteAudioFromCallKit(_ isMuted: Bool) {
        Task {
            Logger.info("\(logTag) \(isMuted ? "mute" : "unmute") audio complete.")
            await DTMeetingManager.shared.muteAudio(isMuted)
        }
    }
}
