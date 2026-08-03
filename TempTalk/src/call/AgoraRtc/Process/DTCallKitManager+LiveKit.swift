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

    func acceptCall(calling: DSKProtoCallMessageCalling?) {
        guard let calling else {
            Logger.error("\(logTag) acceptCall - calling is nil (ObjC nil bridge)")
            return
        }
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
            if callType == .group, let gid = newCall.conversationId {
                SDSDatabaseStorage.shared.read { tx in
                    newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: gid,
                        fallbackName: roomName,
                        transaction: tx)
                }
            }
            if case .private = callType, let localNumber = TSAccountManager.localNumber() {
                newCall.callees = [localNumber]
            }
            newCall.createCallMsg = createCallMsg
            newCall.controlType = controlType
            newCall.inviteCallees = inviteCallees
            newCall.timestamp = timestamp
            newCall.callKitUUID = DTCallKitManager.shared().uuidString(fromRoomId: roomId)

            Logger.info("\(logTag) from callkit accepting call directly without blocking main thread, callKitUUID: \(newCall.callKitUUID ?? "nil")")

            await DTMeetingManager.shared.showAnswerFromCallKit(call: newCall)
        }

        let manager = DTMeetingManager.shared
        Task {
            if manager.hasMeeting, let oldRoomId = manager.currentCall.roomId, oldRoomId != roomId {
                Logger.info("CallKit: last call not ended, caller:\(manager.currentCall.caller ?? "no caller")")

                let oldCallKitUUID = DTCallKitManager.shared().uuidString(fromRoomId: oldRoomId)

                Logger.info("\(self.logTag) hangup last call meeting, oldUUID: \(oldCallKitUUID ?? "nil")")
                await DTMeetingManager.shared.hangupCall(needSyncCallKit: false,
                                                         isByLocal: true,
                                                         roomId: oldRoomId)

                if let oldCallKitUUID {
                    await MainActor.run {
                        DTCallKitManager.shared().endCallAction(oldCallKitUUID, onlyForCallKit: true)
                    }
                }

                Logger.info("\(self.logTag) remove alert view for old call: \(oldRoomId)")
                await MainActor.run {
                    DTMeetingManager.shared.callAlertManager.removeLiveKitAlertCall(oldRoomId)
                }

                let maxWaitIterations = 60 // 3 seconds max
                for i in 0..<maxWaitIterations {
                    let isReady = await MainActor.run {
                        manager.lifecycleState == .idle
                    }
                    if isReady {
                        Logger.info("[CALLKIT_DEBUG] acceptCall - state is idle after \(i * 50)ms")
                        break
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                // Minimum yield for RunLoop cleanup
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                Logger.info("[CALLKIT_DEBUG] acceptCall - switching to new call")
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

    // MARK: - Per-call Timeout Timer

    @objc func startTimeoutTimerForUUID(_ uuidString: String) {
        DispatchMainThreadSafe { [self] in
            stopTimeoutTimerForUUID(uuidString)
            let userInfo = ["uuidString": uuidString]
            let timer = Timer.weakTimer(withTimeInterval: 1,
                                         target: self,
                                         selector: #selector(checkCallAvailableForTimer),
                                         userInfo: userInfo,
                                         repeats: true)
            callerMapLock.lock()
            timeoutTimers[uuidString] = timer
            callerMapLock.unlock()
            RunLoop.current.add(timer, forMode: .common)
            checkCallAvailableForTimer(timer)
        }
    }

    @objc func stopTimeoutTimerForUUID(_ uuidString: String) {
        callerMapLock.lock()
        guard let timer = timeoutTimers[uuidString] as? Timer else {
            callerMapLock.unlock()
            return
        }
        timeoutTimers.removeObject(forKey: uuidString)
        callerMapLock.unlock()

        if Thread.isMainThread {
            timer.invalidate()
        } else {
            DispatchQueue.main.async {
                timer.invalidate()
            }
        }
    }

    @objc func stopAllTimeoutTimers() {
        callerMapLock.lock()
        let allTimers = (timeoutTimers.allValues as? [Timer]) ?? []
        timeoutTimers.removeAllObjects()
        callerMapLock.unlock()

        if Thread.isMainThread {
            for timer in allTimers {
                timer.invalidate()
            }
        } else {
            DispatchQueue.main.async {
                for timer in allTimers {
                    timer.invalidate()
                }
            }
        }
    }

    /// 超过48s超时挂断, 未超过每2s检查对方是否cancel
    @objc func checkCallAvailableForTimer(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: String],
              let uuidString = userInfo["uuidString"] else {
            return
        }

        guard let caller = caller(forUUID: uuidString) else {
            stopTimeoutTimerForUUID(uuidString)
            return
        }

        caller.timing += 1
        let currentTiming = caller.timing

        if currentTiming >= 48 {
            stopTimeoutTimerForUUID(uuidString)
            endCallAction(uuidString, onlyForCallKit: false)
            return
        }

        Logger.debug("\(logTag) timing[\(uuidString)]: \(currentTiming)")

        let remainder = currentTiming.truncatingRemainder(dividingBy: 2)
        guard remainder == 0 else { return }

        guard let calling = calling(fromUUID: uuidString),
              let roomId = calling.roomID else {
            stopTimeoutTimerForUUID(uuidString)
            endCallAction(uuidString, onlyForCallKit: false)
            return
        }

        guard !caller.isEnded else { return }

        // @MainActor: serialize invalidCheckCount across overlapping ticks when checkRoomIdValid is slow.
        Task { @MainActor in
            let result = await DTMeetingManager.checkRoomIdValid(roomId)
            guard let result else {
                // Dismiss only after 2 consecutive nils (a single nil may be a transient blip).
                caller.invalidCheckCount += 1
                Logger.info("\(logTag) roomId check returned nil (\(caller.invalidCheckCount) consecutive)")
                if caller.invalidCheckCount >= 2 {
                    stopTimeoutTimerForUUID(uuidString)
                    endCallAction(uuidString, onlyForCallKit: false)
                }
                return
            }
            caller.invalidCheckCount = 0

            let anotherDeviceJoined = result.anotherDeviceJoined
            let userStopped = result.userStopped

            if anotherDeviceJoined || userStopped {
                Logger.info("\(logTag) roomId valid, anotherDeviceJoined=\(anotherDeviceJoined), userStopped=\(userStopped)")
                stopTimeoutTimerForUUID(uuidString)
                endCallAction(uuidString, onlyForCallKit: false)
            }
        }
    }

    func hangupFromCallKit(_ roomId: String) {
        Task {
            Logger.info("\(self.logTag) hangup callkit trigger endcall action")
            await DTMeetingManager.shared.hangupCall(needSyncCallKit: false,
                                                     isByLocal: true,
                                                     roomId: roomId,
                                                     isFromCallKit: true)
            DTMeetingManager.shared.syncServerCalls()
        }
    }

    @objc(rejectCallFromCallKit:) func rejectCallFromCallKit(calling: DSKProtoCallMessageCalling) {
        guard let caller = calling.caller, let roomId = calling.roomID else {
            Logger.error("\(logTag) rejectCallFromCallKit: missing caller or roomId")
            return
        }
        let callType = calling.conversationID.map { $0.getCallInfo().callType } ?? .instant
        Task {
            Logger.info("\(self.logTag) rejectCallFromCallKit caller:\(caller) roomId:\(roomId)")
            let tempCall = DTLiveKitCallModel()
            tempCall.caller = caller
            tempCall.roomId = roomId
            tempCall.callType = callType
            if callType == .private, let localNumber = TSAccountManager.localNumber() {
                tempCall.callees = [localNumber]
            }
            await DTMeetingManager.shared.rejectIncomingCallSilently(with: tempCall)
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
