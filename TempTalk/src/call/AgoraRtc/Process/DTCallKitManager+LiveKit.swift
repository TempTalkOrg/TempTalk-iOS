//
//  DTCallKitManager+LiveKit.swift
//  TempTalk
//
//  Created by Ethan on 12/27/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

private enum DTVoipIdentityEncoding {
    static func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }
}

private enum DTVoipEnvelopeIdentity {
    static func make(for envelope: DSKProtoEnvelope) -> String? {
        guard envelope.type == .etoee,
              envelope.msgType == .msgEncCall,
              let source = envelope.source,
              !source.isEmpty,
              envelope.hasTimestamp
        else {
            return nil
        }

        // Keep this aligned with MessageProcessor.EncryptedEnvelope.isDuplicateOf.
        // Numeric protobuf fields intentionally use their effective values: a
        // retransmission may be serialized with an omitted or explicit zero while
        // still representing the same call envelope.
        let encodedSource = DTVoipIdentityEncoding.encode(source)
        let components = [
            "v1",
            encodedSource,
            String(envelope.sourceDevice),
            String(envelope.timestamp),
            String(envelope.systemShowTimestamp),
            String(envelope.sequenceID),
            String(envelope.notifySequenceID),
            String(envelope.lastestMsgFlag),
            envelope.hasCriticalLevel ? String(envelope.unwrappedCriticalLevel.rawValue) : "-",
        ]
        return components.joined(separator: "|")
    }
}

/// Legacy pushes do not carry the encrypted envelope sequence fields. Require the
/// invitation's start time so a later invite to the same meeting is not suppressed.
@objc(DTVoipIdentityBuilder)
public final class DTVoipIdentityBuilder: NSObject {
    @objc(identityForLegacyCallInfo:)
    public static func identity(forLegacyCallInfo callInfo: NSDictionary) -> String? {
        guard let meetingId = normalizedString(callInfo["meetingId"]),
              let startAt = normalizedString(callInfo["startAt"])
        else {
            // Without an invitation-specific value, caller + meetingId is too coarse.
            // Prefer processing a possible duplicate over dropping a genuine re-invite.
            return nil
        }

        let caller = normalizedString(callInfo["caller"])
            ?? normalizedString(callInfo["host"])
            ?? "-"
        let channelName = normalizedString(callInfo["channelName"]) ?? "-"
        let eid = normalizedString(callInfo["eid"]) ?? "-"
        return ["legacy-v2", caller, meetingId, startAt, channelName, eid]
            .map(DTVoipIdentityEncoding.encode)
            .joined(separator: "|")
    }

    private static func normalizedString(_ value: Any?) -> String? {
        let result: String?
        switch value {
        case let value as String:
            result = value
        case let value as NSNumber:
            result = value.stringValue
        default:
            result = nil
        }

        guard let result, !result.isEmpty else { return nil }
        return result
    }
}

/// Atomic result for one PushKit delivery. Every delivery for the same identity
/// shares one UUID, so CallKit treats APNs retries as the same incoming call.
@objc(DTVoipReportClaim)
public final class DTVoipReportClaim: NSObject {
    @objc public let isFirstDelivery: Bool
    @objc public let callKitUUID: NSUUID

    fileprivate init(isFirstDelivery: Bool, callKitUUID: UUID) {
        self.isFirstDelivery = isFirstDelivery
        self.callKitUUID = callKitUUID as NSUUID
        super.init()
    }
}

/// Thread-safe, short-lived idempotency guard for incoming VoIP envelopes.
/// A lock is used here because separate PushKit callbacks may enter concurrently
/// before either callback reaches the serial CallKit queue.
@objc(DTVoipEnvelopeDeduplicator)
public final class DTVoipEnvelopeDeduplicator: NSObject {
    private struct Claim {
        let claimedAt: TimeInterval
        let callKitUUID: UUID
        var isTerminal: Bool
    }

    private static let timeToLive: TimeInterval = 120
    private let lock = NSLock()
    private var claimsByIdentity = [String: Claim]()

    @objc
    public override init() {
        super.init()
    }

    @objc(claimReportForIdentity:)
    public func claimReport(for identity: String) -> DTVoipReportClaim {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }

        claimsByIdentity = claimsByIdentity.filter { _, claim in
            claim.claimedAt <= now && now - claim.claimedAt < Self.timeToLive
        }

        if let claim = claimsByIdentity[identity], now - claim.claimedAt < Self.timeToLive {
            return DTVoipReportClaim(isFirstDelivery: false, callKitUUID: claim.callKitUUID)
        }

        let callKitUUID = UUID()
        claimsByIdentity[identity] = Claim(
            claimedAt: now,
            callKitUUID: callKitUUID,
            isTerminal: false
        )
        return DTVoipReportClaim(isFirstDelivery: true, callKitUUID: callKitUUID)
    }

    /// Returns true when an accepted duplicate report no longer has a live owner.
    /// A missing or replaced claim is terminal for the old delivery as well.
    @objc(shouldEndAcceptedDuplicateForIdentity:callKitUUID:)
    public func shouldEndAcceptedDuplicate(
        for identity: String,
        callKitUUID: NSUUID
    ) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let uuid = callKitUUID as UUID
        lock.lock()
        defer { lock.unlock() }

        guard let claim = claimsByIdentity[identity],
              claim.callKitUUID == uuid,
              claim.claimedAt <= now,
              now - claim.claimedAt < Self.timeToLive
        else {
            return true
        }
        return claim.isTerminal
    }

    /// Marks the claim before its CallKit UI is torn down. If a duplicate report
    /// completes later, it observes this terminal state and closes its placeholder.
    @objc(markTerminalCallKitUUID:)
    public func markTerminal(callKitUUID: NSUUID) {
        let uuid = callKitUUID as UUID
        lock.lock()
        defer { lock.unlock() }

        guard let identity = claimsByIdentity.first(where: {
            $0.value.callKitUUID == uuid
        })?.key else {
            return
        }
        claimsByIdentity[identity]?.isTerminal = true
    }

    @objc
    public func markAllTerminal() {
        lock.lock()
        claimsByIdentity = claimsByIdentity.mapValues { claim in
            var claim = claim
            claim.isTerminal = true
            return claim
        }
        lock.unlock()
    }

    /// Process-local opaque token for correlating logs without exposing any
    /// envelope fields. Swift's Hasher is randomly seeded for each process.
    @objc(fingerprintForIdentity:)
    public func fingerprint(for identity: String) -> String {
        var hasher = Hasher()
        hasher.combine(identity)
        return String(format: "%08x", UInt32(truncatingIfNeeded: hasher.finalize()))
    }

    @objc(forgetIdentity:)
    public func forget(_ identity: String) {
        lock.lock()
        claimsByIdentity.removeValue(forKey: identity)
        lock.unlock()
    }
}

@objc
public extension DTCallKitManager {
    func voipEnvelopeIdentity(forEncryptedMessage msg: String) -> String? {
        guard let (_, envelope) = appleEnvelope(from: msg) else {
            return nil
        }
        return DTVoipEnvelopeIdentity.make(for: envelope)
    }

    func decryptMsg(_ msg: String) -> DSKProtoCallMessageCalling? {
        guard let (decryptedPayload, envelope) = appleEnvelope(from: msg) else {
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

        guard let caller = calling.caller,
              caller.caseInsensitiveCompare(envelope.source ?? "") == .orderedSame else {
            Logger.error("decryptMsg error: caller does not match envelope source")
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
            if callType == .group, let gid = newCall.conversationId {
                SDSDatabaseStorage.shared.read { tx in
                    // Same early verdict as the calling-message path — without it, a CallKit answer
                    // rebuilds the model and re-derives group, undoing that verdict.
                    if DTMeetingManager.shared.shouldTreatGroupCallAsInstant(
                        serverGroupId: gid,
                        controlType: controlType,
                        transaction: tx
                    ) {
                        callType = .instant
                        return
                    }
                    newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: gid,
                        fallbackName: roomName,
                        transaction: tx)
                }
            }
            newCall.callType = callType
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

private extension DTCallKitManager {
    func appleEnvelope(from msg: String) -> (Data, DSKProtoEnvelope)? {
        guard let data = Data(base64Encoded: msg) else {
            Logger.error("decryptMsg error: 0")
            return nil
        }

        guard let signalingKey = TSAccountManager.signalingKey() else {
            Logger.error("decryptMsg error: 1")
            return nil
        }

        guard let decryptedPayload = SSKCryptography.decryptAppleMessagePayload(data, withSignalingKey: signalingKey) else {
            Logger.error("decryptMsg error: 2")
            return nil
        }

        guard let envelope = try? DSKProtoEnvelope(serializedData: decryptedPayload) else {
            Logger.error("decryptMsg error: 3")
            return nil
        }

        return (decryptedPayload, envelope)
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

        // @MainActor: serialize invalidCheckCount across overlapping ticks when the probe is slow.
        Task { @MainActor in
            switch await DTMeetingManager.checkRoomAvailability(roomId) {
            case .gone:
                // Server explicitly reports the room invalid; dismiss only after 2 consecutive hits.
                caller.invalidCheckCount += 1
                Logger.info("\(logTag) roomId reported gone (\(caller.invalidCheckCount) consecutive)")
                if caller.invalidCheckCount >= 2 {
                    stopTimeoutTimerForUUID(uuidString)
                    endCallAction(uuidString, onlyForCallKit: false)
                }
            case .unknown:
                // Probe failed (transport/decode); says nothing about the room. Do not count it,
                // let the overall timeout (timing >= 48) handle a genuinely stuck call.
                Logger.info("\(logTag) roomId probe transient failure, not counting")
            case .valid(let anotherDeviceJoined, let userStopped):
                caller.invalidCheckCount = 0
                if anotherDeviceJoined || userStopped {
                    Logger.info("\(logTag) roomId valid, anotherDeviceJoined=\(anotherDeviceJoined), userStopped=\(userStopped)")
                    stopTimeoutTimerForUUID(uuidString)
                    endCallAction(uuidString, onlyForCallKit: false)
                }
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
            await DTMeetingManager.shared.muteAudio(isMuted, userInitiated: true)
        }
    }
}
