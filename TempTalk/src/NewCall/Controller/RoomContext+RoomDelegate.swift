//
//  RoomContext+RoomDelegate.swift
//  Difft
//
//  Created by Henry on 2025/4/21.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit
import SwiftUI
import TTMessaging
import AVFAudio
import Foundation

enum RoomDelegateType: String {
    case roomDefault = "default"
    case localPartConnect = "LocalParticipantConnect"
    case remotePartConnect = "RemotePartConnect"
    case startScreenShare = "StartScreenShare"
    case remoteMute = "RemoteMute"
    case RTMBarrage = "RTMBarrage"
}

extension RoomContext: RoomDelegate {
    
    // MARK: room state
    
    public func room(_: Room, track publication: TrackPublication, didUpdateE2EEState e2eeState: E2EEState) {
        Logger.debug("\(logTag) Did update e2eeState")
    }

    nonisolated public func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldValue: ConnectionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) Did update connectionState \(oldValue) -> \(connectionState)")

            if case .disconnected = connectionState,
               let error = room.disconnectError,
               error.type != .cancelled
            {
                latestError = room.disconnectError

                // 更新 UI 状态，保持在 main actor 内
                shouldShowDisconnectReason = true
                focusParticipant = nil
                textFieldString = ""
            }
        }
    }
    
    nonisolated public func roomDidConnect(_ room: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) roomDidConnect")
            
            do {
                if case .private = currentCall.callType {
                    try await room.localParticipant.setMicrophone(enabled: default1on1MicphoneState)
                } else {
                    try await room.localParticipant.setMicrophone(enabled: true, publishMuted: !defaultGroupMicphoneState)
                }
            } catch {
                Logger.error("\(logTag) failed to set audio track: \(error)")
            }
            
            // 连接成功之后给 sid 赋值
            currentCall.roomSid = room.sid?.stringValue

            // 使用 callManager（假设在 RoomContext 主文件里是计算属性）
            callManager.feedbackUserSid = room.localParticipant.sid?.stringValue
            callManager.feedbackRoomSid = room.sid?.stringValue
            callManager.feedbackRoomId = currentCall.roomId
            
            // 处理不同 callType 的连接后逻辑
            handlePostConnectState(for: room)
            
            // 自动离会处理（保持原行为）
            callManager.currentCallTalkingPop()
            // 当前用户参会
            RoomDataManager.shared.connectParticipant(participant: room.localParticipant)
            // 开启距离传感器
            UIDevice.current.isProximityMonitoringEnabled = true
        }
    }
    
    private func handlePostConnectState(for room: Room) {
        if currentCall.callType != .private {
            // 展示 meeting bar
            if currentCall.isCaller {
                callManager.handleMeetingBar(call: currentCall, action: .add)
            }
            // 超时计时停止
            callManager.stopCallTimeoutTimer()
            // 正在会议中
            callManager.inMeeting = true
            // 非会议中的人，展示 instant
            checkPartiantInRoom(room.localParticipant.identity?.stringValue ?? "")
        } else {
            // private call
            if room.remoteParticipants.count > 1 {
                callManager.turnIntoInstantCall()
            }
            
            if currentCall.isCaller {
                // 1on1 callee 比 caller 先进入频道
                if !room.remoteParticipants.isEmpty {
                    currentCall.callState = .answering
                    callManager.stopSound()
                    callManager.stopCallTimeoutTimer()
                    callManager.inMeeting = true
                }
            } else {
                currentCall.callState = .answering
                callManager.handleMeetingBar(call: currentCall, action: .add)
                callManager.inMeeting = true
                // 异步调用 joinedCall
                Task { await callManager.joinedCall() }
            }
        }
    }
    
    nonisolated public func roomDidSignalConnect(_ room: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) roomDidSignalConnect")
            
            guard !callManager.inMeeting else {
                Logger.info("\(logTag) same call has Multiple SignalConnect")
                return
            }

            /// 连接成功
            @MainActor func handleSuccess(with response: Livekit_TTCallResponse) {
                guard response.hasBody else {
                    Logger.warn("\(logTag) response.body is empty, waiting for timeout")
                    return
                }
                connectTimeoutTask?.cancel()
                connectTimeoutTask = nil
                currentCall.ttcalResponseBody = response.body
                callManager.dealConnetedSuccess(with: response.body)
            }

            /// 超时处理
            func handleTimeout() {
                Logger.error("\(logTag) ttCallResp is nil or body empty after 15s")
                Task {
                    await self.callManager.hangupCall(
                        needSyncCallKit: true,
                        isByLocal: true,
                        roomId: self.currentCall.roomId,
                        removeMeetingBar: false,
                        showErrorToast: true
                    )
                }
            }

            if let response = room.ttCallResp, response.hasBody {
                handleSuccess(with: response)
            } else {
                connectTimeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    if let response = room.ttCallResp, response.hasBody {
                        handleSuccess(with: response)
                    } else {
                        handleTimeout()
                    }
                }
            }
        }
    }
    
    /// 连接异常的时候
    nonisolated public func room(_ room: Room, didFailToConnectWithError error: LiveKitError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                updateStale(with: error)
                Logger.error("\(logTag) didFailToConnectWithError error: \(error)")
                if callManager.inMeeting {
                    await self.callManager.hangupCall(needSyncCallKit: true,
                                                 isByLocal: true,
                                                      roomId: self.currentCall.roomId,
                                                 removeMeetingBar: false,
                                                 showErrorToast: true)
                }
            } else {
                Logger.error("\(logTag) didFailToConnectWithError error: nil")
            }
        }
    }
    
    /// 断开异常
    nonisolated public func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                updateStale(with: error)
                Logger.info("\(logTag) didDisconnect error: \(error) errortype:\(error.type)")
                await callManager.hangupCall(needSyncCallKit: true,
                                             isByLocal: true,
                                             roomId: currentCall.roomId,
                                             removeMeetingBar: false,
                                             showErrorToast: true)
            } else {
                Logger.info("\(logTag): normal disconnect")
            }
            
            // 当前用户离会
            RoomDataManager.shared.disconnectParticipant(participant: room.localParticipant)
            UIDevice.current.isProximityMonitoringEnabled = false
        }
    }
    
    nonisolated public func roomDidReconnect(_ room: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) room reconnected - canceling disconnect timer")
            callManager.stopParticipantDisTimer()
        }
    }
    
    nonisolated public func roomIsReconnecting(_ room: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) room is Reconencting")
            
            let local = room.localParticipant
            let isLocalValid = local.sid?.stringValue.isEmpty == false
            callManager.feedbackIsNetworkPoor = true

            // 过滤 remoteParticipants 中 sid 有效的
            let remoteParticipants = Array(room.remoteParticipants.values)
            let validRemote = remoteParticipants.filter {
                if let sid = $0.sid, !sid.stringValue.isEmpty {
                    return true
                }
                return false
            }
            let isRemoteValid = !validRemote.isEmpty

            if isLocalValid && isRemoteValid {
                let local: Participant = room.localParticipant
                var remote: [Participant] = room.remoteParticipants.values.map { $0 as Participant }
                remote.append(local)
                let sorteds = callManager.sortedMeetings(participants: remote)
                let snapshots: [ParticipantSnapshot] = sorteds.map { ParticipantSnapshot(from: $0) }
                callManager.reconnectingParticipants = snapshots
            }
        }
    }

    // MARK: remote participant state
    // remote online
    nonisolated public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) remote connected")
            if case .private = currentCall.callType {
                // 1v1
                Logger.info("\(logTag) private cancel disconnect Timer")
                callManager.stopParticipantDisTimer()
                // 1on1 callee入会
                if case .outgoing = currentCall.callState, currentCall.isCaller {
                    callManager.handleMeetingBar(call: currentCall, action: .add)
                    currentCall.callState = .answering
                    callManager.stopSound()
                    callManager.stopCallTimeoutTimer()
                  
                    // callee入会双方均进入频道, 开始计时
                    callManager.inMeeting = true
                }
                
                if case .answering = currentCall.callState, room.allParticipants.keys.count > 2 {
                    // 1on1 call进入更多人type转为instant
                    callManager.turnIntoInstantCall()
                }
                
                // 直接赋值主线程属性（extension 已为 @MainActor）
                self.othersideParticipantFor1on1 = participant
            } else if case .group = currentCall.callType {
                //非会议中的人，展示instant
                checkPartiantInRoom(room.localParticipant.identity?.stringValue ?? "")
            }
            // 自动离会处理
            callManager.currentCallTalkingPop()
            // 远端入会人数发生变化
            RoomDataManager.shared.connectParticipant(participant: participant)
        }
    }
    
    // remote offline
    nonisolated public func room(_: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.debug("\(logTag) remote disconnected")
            
            // delegate 已在 main actor，直接执行
            if let focusParticipant = self.focusParticipant, focusParticipant.identity == participant.identity {
                self.focusParticipant = nil
            }
            
            if currentCall.callType == .private {
                Logger.info("\(logTag) private start disconnect Timer")
                callManager.startParticipantDisTimer { [weak self] in
                    guard let self else { return }
                    Logger.info("\(self.logTag) remote participant disconnected - initiating hangup")
                    Task {
                        Logger.info("\(self.logTag) hangup remote participant timeout")
                        await self.callManager.hangupCall(needSyncCallKit: true,
                                                          roomId: self.currentCall.roomId,
                                                          removeMeetingBar: true)
                    }
                }
            }
            
            // 自动离会处理
            callManager.currentCallTalkingPop()
            // 远端入会人数发生变化
            RoomDataManager.shared.disconnectParticipant(participant: participant)
        }
    }

    nonisolated public func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let participantId = participant?.identity?.stringValue.components(separatedBy: ".").first ?? ""

            // 统一解析 base64 结构数据
            func extractSignatureAndPayload(from data: Data) -> (signature: Data, payload: Data)? {
                guard
                    let receiveConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let signatureString = receiveConfig["signature"] as? String,
                    let payloadString = receiveConfig["payload"] as? String,
                    let signatureData = Data(base64Encoded: signatureString),
                    let payloadData = Data(base64Encoded: payloadString)
                else {
                    return nil
                }
                return (signatureData, payloadData)
            }

            // 倒计时类 topic，payload 是 UTF-8 string json
            func parseCountdownPayload(from data: Data) -> (currentTimeMs: UInt64, expiredTimeMs: UInt64, durationMs: UInt64, operatorId: String)? {
                guard
                    let receiveConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let payloadString = receiveConfig["payload"] as? String,
                    let payloadData = payloadString.data(using: .utf8),
                    let payloadDict = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                    let currentTimeMs = payloadDict["currentTimeMs"] as? UInt64,
                    let expiredTimeMs = payloadDict["expiredTimeMs"] as? UInt64,
                    let durationMs = payloadDict["durationMs"] as? UInt64,
                    let operatorIdentity = payloadDict["operatorIdentity"] as? String
                else {
                    return nil
                }

                return (currentTimeMs, expiredTimeMs, durationMs, operatorIdentity.components(separatedBy: ".").first ?? "")
            }

            switch topic {
            case "chat":
                if let (signature, payload) = extractSignatureAndPayload(from: data) {
                    if DTParamsUtils.validateString(participantId).boolValue {
                        callManager.decryptRemoteRoom(signature: signature, decryptData: payload, participantId: participantId)
                    }
                } else {
                    Logger.error("\(logTag) Failed to parse data for topic 'chat'")
                }

            case "mute-other":
                if let (signature, payload) = extractSignatureAndPayload(from: data) {
                    callManager.decryptRemoteMicOffRoom(signature: signature, decryptData: payload)
                } else {
                    Logger.error("\(logTag) Failed to parse data for topic 'mute-other'")
                }

            case "continue-call-after-silence":
                if let (signature, payload) = extractSignatureAndPayload(from: data) {
                    callManager.decryptRemoteSyncContinueStatus(signature: signature, decryptData: payload)
                } else {
                    Logger.error("\(logTag) Failed to parse data for topic 'continue-call-after-silence'")
                }

            case "set-countdown", "extend-countdown", "restart-countdown":
                if let result = parseCountdownPayload(from: data) {
                    callManager.dealMeetingCountDownView(
                        currentTimeMs: result.currentTimeMs,
                        expiredTimeMs: result.expiredTimeMs,
                        participantId: result.operatorId,
                        topic: topic
                    )
                }

            case "clear-countdown":
                callManager.destroyMeetingCountDownView()
                
            case "raise-hand", "cancel-hand":
                do {
                    if let receiveConfig = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let payload = receiveConfig["payload"] as? String {
                        callManager.dealRemoteHandsStatus(topic: topic, payload: payload)
                    }
                } catch {
                    Logger.error("\(logTag) hand parse json \(error)")
                }

            case "end-call":
                if let sid = room.sid?.stringValue, sid == currentCall.roomSid {
                    if let (signature, payload) = extractSignatureAndPayload(from: data) {
                        Task {
                            Logger.info("\(self.logTag) topic end call currentcall")
                            await self.callManager.meetingNotificationEndAllClearData(roomId: self.currentCall.roomId)
                        }
                    } else {
                        Logger.error("\(logTag) Failed to parse data for topic 'end-call'")
                    }
                }

            default:
                break
            }
        }
    }

    nonisolated public func room(_: Room, participant _: Participant, trackPublication _: TrackPublication, didReceiveTranscriptionSegments segments: [TranscriptionSegment]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.debug("\(logTag) didReceiveTranscriptionSegments: \(segments.map { "(\($0.id): \($0.text), \($0.firstReceivedTime)-\($0.lastReceivedTime), \($0.isFinal))" }.joined(separator: ", "))")
        }
    }

    nonisolated public func room(_: Room, trackPublication _: TrackPublication, didUpdateE2EEState state: E2EEState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.debug("\(logTag) didUpdateE2EEState: \(state)")
        }
    }
    
    // MARK: 谁开始了分享
    nonisolated public func room(_: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if publication.kind == .video && publication.source == .screenShareVideo {
                RoomDataManager.shared.openScreenSharedParticipant(participant: participant)
            }
        }
    }
    
    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if participant.isScreenShareEnabled()
                && !(callManager.currentCall.isPresentedShare)
                && publication.source == .screenShareVideo {
                Logger.info("[Livekit] start screen share")
                // extension 已是 main actor
                screenSharePublication = publication
                screenShareParticipant = participant
                callManager.currentCall.isPresentedShare = true
                tryPresentShareView(maxRetryCount: 8)
            }
        }
    }
    
    // MARK: 谁结束了分享
    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if publication.kind == .video && publication.source == .screenShareVideo {
                RoomDataManager.shared.closeScreenSharedParticipant(participant: participant)
            }
        }
    }
    
    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !participant.isScreenShareEnabled()
                && publication.source == .screenShareVideo
                && screenShareParticipant == participant {
                Logger.info("结束了屏幕共享")
                screenSharePublication = nil
                callManager.currentCall.isPresentedShare = false
                
                if let inviteVC {
                    inviteVC.dismiss(animated: false)
                }
                if let shareVC {
                    shareVC.dismiss(animated: false)
                }
            }
        }
    }
    
    // 检测是否有人发言
    nonisolated public func room(_ room: Room, didUpdateSpeakingParticipants participants: [Participant]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            // 若没有变化，则跳过
            guard lastParticipants != participants else {
                return
            }
            
            lastParticipants = participants
            
            if participants.isEmpty {
                handleNoSpeakers()
            } else {
                handleActiveSpeakers()
            }
        }
    }
    
    // 检测 remote 麦克风关闭
    nonisolated public func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            if trackPublication.track is AudioTrack {
                // 只处理音频的弹幕
                RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: isMuted)
            } else if trackPublication.track is VideoTrack {
                // 视频
                RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
            }
        }
    }
    
    nonisolated public func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            if publication.track is AudioTrack, !publication.isMuted {
                // 只处理开麦的弹幕
                RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: false)
            } else if publication.track is VideoTrack {
                // 视频
                RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
            }
        }
    }

}

// MARK: - Helper: speaker / share / stale handling
@MainActor
extension RoomContext {
    /// 有人说话：延迟 0.4 秒刷新说话人，取消还原共享人的任务
    private func handleActiveSpeakers() {
        // 取消待还原的任务
        resetToDefaultWorkItem?.cancel()
        resetToDefaultWorkItem = nil

        // 取消之前准备执行的刷新任务（节流）
        activeSpeakerWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.updateSpeakingUI()
            }
        }

        activeSpeakerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + activeSpeakerDelay, execute: workItem)
    }
    
    /// 没人说话：延迟 2.5 秒恢复共享人视图，取消刷新说话人的任务
    private func handleNoSpeakers() {
        // 取消刷新说话人的节流任务
        activeSpeakerWorkItem?.cancel()
        activeSpeakerWorkItem = nil

        // 取消之前待还原的任务（防止重复）
        resetToDefaultWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.restoreDefaultSharingView()
            }
        }

        resetToDefaultWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resetDelay, execute: workItem)
    }

    private func updateSpeakingUI() {
        RoomDataManager.shared.updateSeakingParticipant()
    }

    private func restoreDefaultSharingView() {
        RoomDataManager.shared.updateSeakingParticipant()
    }

    func cleanup() {
        activeSpeakerWorkItem?.cancel()
        resetToDefaultWorkItem?.cancel()
    }
    
    func updateStale(with error: LiveKitError) {
        if let body = error.response?.body {
            if DTParamsUtils.validateArray(body.stale).boolValue {
                Logger.info("\(logTag) error update stal data")
                var tempStales: [[String: Any]] = []
                let stales: [Livekit_TTExceptionRecipient] = body.stale
                
                for stale in stales {
                    var dict: [String: Any] = [:]
                    dict["uid"] = stale.uid
                    dict["identityKey"] = stale.identityKey
                    dict["registrationId"] = stale.registrationID
                    
                    tempStales.append(dict)
                }
                
                callManager.storeFreshPrekeys(tempStales) {}
            }
        }
    }
    
    private func tryPresentShareView(delay: TimeInterval = 0.5, maxRetryCount: Int = 1) {
        guard !isPresentingShareView else {
            Logger.info("[Livekit] Share view is already being presented, skipping duplicate call")
            return
        }

        guard CurrentAppContext().isMainAppAndActive else {
            if maxRetryCount > 0 {
                Logger.info("[Livekit] App not active, delaying \(delay)s before retry (\(maxRetryCount) retries left)")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    Task { @MainActor in
                        self?.tryPresentShareView(delay: delay, maxRetryCount: maxRetryCount - 1)
                    }
                }
            } else {
                Logger.info("[Livekit] App still not active after delay, cancel presenting share view")
            }
            return
        }
        isPresentingShareView = true
        Logger.info("[Livekit] App active, presenting share view")

        presentShareView { [weak self] in
            Task { @MainActor in
                self?.isPresentingShareView = false
                Logger.info("[Livekit] Share view dismissed, reset presenting state")
            }
        }
    }
}
