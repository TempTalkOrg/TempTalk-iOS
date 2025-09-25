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
        self.databaseStorage.write { writeTransaction in
            let result = Self.messageDecrypter.decryptEnvelope(
                envelope,
                envelopeData: decryptedPayload,
                transaction: writeTransaction
            )
            switch result {
            case .success(let result):
                if let resultData = result.plaintextData {
                    plaintextData = resultData
                }
            case .failure(_):
                return
            }
        }

        guard let plaintextData = plaintextData, let content = try? DSKProtoContent(serializedData: plaintextData) else {
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
    @objc
    func acceptCall(calling: DSKProtoCallMessageCalling) {
        
        func acceptCallAction(_ calling: DSKProtoCallMessageCalling) async {
            guard let roomId = calling.roomID else {
                Logger.error("\(logTag) roomId is nil")
                return
            }
            
            let newCall = DTLiveKitCallModel()
            newCall.callState = .alerting
            newCall.caller = calling.caller
            newCall.roomId = roomId
            newCall.roomName = calling.roomName ?? DTCallManager.defaultMeetingName()
            newCall.publicKey = calling.publicKey
            newCall.emk = calling.emk
            
            var callType: CallType = .instant
            if let conversationId = calling.conversationID {
                let callInfo = conversationId.getCallInfo()
                newCall.conversationId = callInfo.conversationId
                callType = callInfo.callType
            }
            newCall.callType = callType
            if case .private = callType, let localNumber = TSAccountManager.localNumber() {
                newCall.callees = [localNumber]
            }
            newCall.createCallMsg = calling.createCallMsg
            newCall.controlType = calling.controlType
            newCall.inviteCallees = calling.callees
            newCall.timestamp = calling.timestamp
            
            Logger.info("\(logTag) from callkit show Livekit answer")
            DTMeetingManager.shared.showAnswer(call: newCall, fromCallKit: true)
        }
        
        let manager = DTMeetingManager.shared
        Task {
            if manager.hasMeeting, let oldRoomId =  manager.currentCall.roomId, let roomID = calling.roomID, oldRoomId != roomID {
                Logger.info("CallKit: last call not ended, caller:\(manager.currentCall.caller ?? "no caller")")
                if (DTCallKitManager.shared().callsCount == 1) {
                    Logger.info("\(self.logTag) hangup last call meeting")
                    await DTMeetingManager.shared.hangupCall(needSyncCallKit: true,
                                                             isByLocal: true,
                                                             roomId: oldRoomId,
                                                             removeMeetingBar: true)
                }
                
                Logger.info("CallKit: The last call is ended  - stared a new call")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await acceptCallAction(calling)
            } else {
                Logger.info("CallKit: normal accept.")
                await acceptCallAction(calling)
            }
        }

    }
}

@objc
public extension DTCallKitManager {
    
    private struct AssociatedKeys {
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
    @objc
    func checkCallAvailable(_ timer: Timer) {
        
        timing += 1
        guard let userInfo = timer.userInfo as? [String: String], let callerId = userInfo["callerId"] else {
            stopTimeroutTimer()
            return
        }

        if timing >= 48 {
            // miss call
            stopTimeroutTimer()
            endCallAction(callerId)
            return
        }
        Logger.debug("\(logTag) timing: \(timing)")
        // 每2s检查一次roomId是否有效
        let remainder = timing.truncatingRemainder(dividingBy: 2)
        guard remainder == 0 else { return }
        
        guard let calling = calling(fromCallerId: callerId),
              let roomId = calling.roomID else {
            stopTimeroutTimer()
            endCallAction(callerId)
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
                endCallAction(callerId)
                return
            }
            
            let anotherDeviceJoined = result.anotherDeviceJoined
            let userStopped = result.userStopped

            if anotherDeviceJoined || userStopped {
                Logger.info("\(logTag) roomId valid, anotherDeviceJoined = \(anotherDeviceJoined), userStopped = \(userStopped)")
                stopTimeroutTimer()
                endCallAction(callerId)
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
                                                     removeMeetingBar: true)
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
