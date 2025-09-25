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

    public func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldValue: ConnectionState) {
        Logger.info("\(logTag) Did update connectionState \(oldValue) -> \(connectionState)")

        if case .disconnected = connectionState,
           let error = room.disconnectError,
           error.type != .cancelled
        {
            latestError = room.disconnectError

            Task.detached { @MainActor [weak self] in
                guard let self else { return }
                self.shouldShowDisconnectReason = true
                // Reset state
                self.focusParticipant = nil
                self.textFieldString = ""
                // self.objectWillChange.send()
            }
        }
    }
    
    public func roomDidConnect(_ room: Room) {
        Logger.info("\(logTag) roomDidConnect")
        
        guard let roomId = currentCall.roomId, !roomId.isEmpty else {
            Logger.info("\(logTag) roomDidConnect:roomId is empty")
            return
        }
        
        // 默认开启 mic, 不推流
        Task {
            do {
                if case .private = currentCall.callType {
                    try await room.localParticipant.setMicrophone(enabled: default1on1MicphoneState)
                } else {
                    try await room.localParticipant.setMicrophone(enabled: true, publishMuted: !defaultGroupMicphoneState)
                }
            } catch {
                Logger.error("\(logTag) failed to set audio track: \(error)")
            }
        }
        
        // 连接成功之后给sid赋值
        currentCall.roomSid = room.sid?.stringValue
        currentCall.isConnecting = false
        
        // 多人会议自己进入后展示meeting bar
        if currentCall.callType != .private {
            // 展示meetingbar
            if currentCall.isCaller {
                callManager.handleMeetingBar(call: currentCall, action: .add)
            }
            // 超时计时停止
            callManager.stopCallTimeoutTimer()
            // 正在会议中
            callManager.inMeeting = true
            //非会议中的人，展示instant
            checkPartiantInRoom(room.localParticipant.identity?.stringValue ?? "")
        } else {
            //非会议中的人，展示instant
            if room.remoteParticipants.count > 1 {
                callManager.turnIntoInstantCall()
            }
            
            if currentCall.isCaller {
                // 1on1 callee比caller先进入频道
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
                Task {
                    // 1on1 callee入会后向其他端同步joined
                    await callManager.joinedCall()
                }
            }
        }
        
        // 自动离会处理
        DTMeetingManager.shared.currentCallTalkingPop()
        // 当前用户参会
        RoomDataManager.shared.connectParticipant(participant: room.localParticipant)
        // 开启距离传感器
        DispatchMainThreadSafe {
            UIDevice.current.isProximityMonitoringEnabled = true
        }
    }
    
    ///连接异常的时候
    public func room(_ room: Room, didFailToConnectWithError error: LiveKitError?) {
        if let error {
            Logger.error("\(logTag) didFailToConnectWithError error: \(error)")
            if callManager.inMeeting {
                // 会议中，不降级就会走这个错误
                Task {
                    await callManager.hangupCall(needSyncCallKit: true,
                                                 isByLocal: true,
                                                 roomId: currentCall.roomId,
                                                 removeMeetingBar: false,
                                                 showErrorToast: true)
                }
            }
        } else {
            Logger.error("\(logTag) didFailToConnectWithError error: nil")
        }
    }
    
    ///断开异常
    public func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task {
            if let error {
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
            
            DispatchMainThreadSafe {
                UIDevice.current.isProximityMonitoringEnabled = false
            }
        }
    }
    
    public func roomDidReconnect(_ room: Room) {
        Logger.info("\(logTag) room reconnected - canceling disconnect timer")
        DispatchMainThreadSafe {
            DTMeetingManager.shared.stopParticipantDisTimer()
        }
    }
    
    public func roomIsReconnecting(_ room: Room) {
        Logger.info("\(logTag) room is Reconencting")
        
        let local = room.localParticipant
        let isLocalValid = local.sid?.stringValue.isEmpty == false

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
            let sorteds = DTMeetingManager.shared.sortedMeetings(participants: remote)
            let snapshots: [ParticipantSnapshot] = sorteds.map { ParticipantSnapshot(from: $0) }
            DTMeetingManager.shared.reconnectingParticipants = snapshots
        }
    }

    // MARK: remote participant state
    // remote online
    public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Logger.info("\(logTag) remote connected")
        
        if case .private = currentCall.callType {
            // 1v1
            Logger.info("\(logTag) private cancel disconnect Timer")
            DTMeetingManager.shared.stopParticipantDisTimer()
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
            
            DispatchQueue.main.sync {
                self.othersideParticipantFor1on1 = participant
            }
        } else if case .group = currentCall.callType {
            //非会议中的人，展示instant
            checkPartiantInRoom(room.localParticipant.identity?.stringValue ?? "")
        }
        // 自动离会处理
        DTMeetingManager.shared.currentCallTalkingPop()
        // 远端入会人数发生变化
        RoomDataManager.shared.connectParticipant(participant: participant)
    }
    
    // remote offline
    public func room(_: Room, participantDidDisconnect participant: RemoteParticipant) {
        Logger.debug("\(logTag) remote disconnected")
        
        Task.detached { @MainActor [weak self] in
            guard let self else { return }
            if let focusParticipant = self.focusParticipant, focusParticipant.identity == participant.identity {
                self.focusParticipant = nil
            }
            
            if currentCall.callType == .private {
                Logger.info("\(logTag) private start disconnect Timer")
                DTMeetingManager.shared.startParticipantDisTimer { [weak self] in
                    guard let self else { return }
                    Logger.info("\(logTag) remote participant disconnected - initiating hangup")
                    Task {
                        Logger.info("\(self.logTag) hangup remote participant timeout")
                        await self.callManager.hangupCall(needSyncCallKit: true,
                                                          roomId: self.currentCall.roomId,
                                                          removeMeetingBar: true)
                    }
                }
            }
        }
        // 自动离会处理
        DTMeetingManager.shared.currentCallTalkingPop()
        // 远端入会人数发生变化
        RoomDataManager.shared.disconnectParticipant(participant: participant)
    }

    public func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String) {
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
                    DTMeetingManager.shared.decryptRemoteRoom(signature: signature, decryptData: payload, participantId: participantId)
                }
            } else {
                Logger.error("\(logTag) Failed to parse data for topic 'chat'")
            }

        case "mute-other":
            if let (signature, payload) = extractSignatureAndPayload(from: data) {
                DTMeetingManager.shared.decryptRemoteMicOffRoom(signature: signature, decryptData: payload)
            } else {
                Logger.error("\(logTag) Failed to parse data for topic 'mute-other'")
            }

        case "continue-call-after-silence":
            if let (signature, payload) = extractSignatureAndPayload(from: data) {
                DTMeetingManager.shared.decryptRemoteSyncContinueStatus(signature: signature, decryptData: payload)
            } else {
                Logger.error("\(logTag) Failed to parse data for topic 'continue-call-after-silence'")
            }

        case "set-countdown", "extend-countdown", "restart-countdown":
            if let result = parseCountdownPayload(from: data) {
                DTMeetingManager.shared.dealMeetingCountDownView(
                    currentTimeMs: result.currentTimeMs,
                    expiredTimeMs: result.expiredTimeMs,
                    participantId: result.operatorId,
                    topic: topic
                )
            }

        case "clear-countdown":
            DTMeetingManager.shared.destroyMeetingCountDownView()
            
        case "raise-hand", "cancel-hand":
            do {
                if let receiveConfig = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let payload = receiveConfig["payload"] as? String {
                    DTMeetingManager.shared.dealRemoteHandsStatus(topic: topic, payload: payload)
                }
            } catch {
                Logger.error("\(logTag) hand parse json \(error)")
            }
        case "end-call":
            if let sid = room.sid?.stringValue, sid == currentCall.roomSid {
                if let (signature, payload) = extractSignatureAndPayload(from: data) {
                    Task {
                        Logger.info("\(logTag) topic end call currentcall")
                        await DTMeetingManager.shared.meetingNotificationEndAllClearData(roomId: currentCall.roomId)
                    }
                } else {
                    Logger.error("\(logTag) Failed to parse data for topic 'end-call'")
                }
            }

        default:
            break
        }
    }

    public func room(_: Room, participant _: Participant, trackPublication _: TrackPublication, didReceiveTranscriptionSegments segments: [TranscriptionSegment]) {
        Logger.debug("\(logTag) didReceiveTranscriptionSegments: \(segments.map { "(\($0.id): \($0.text), \($0.firstReceivedTime)-\($0.lastReceivedTime), \($0.isFinal))" }.joined(separator: ", "))")
    }

    public func room(_: Room, trackPublication _: TrackPublication, didUpdateE2EEState state: E2EEState) {
        Logger.debug("\(logTag) didUpdateE2EEState: \(state)")
    }
    
    //MARK: 谁开始了分享
    public func room(_: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        if publication.kind == .video && publication.source == .screenShareVideo {
            RoomDataManager.shared.openScreenSharedParticipant(participant: participant)
        }
    }
    
    public func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        if participant.isScreenShareEnabled()
            && !callManager.currentCall.isPresentedShare
            && publication.source == .screenShareVideo {
            Logger.info("开始了屏幕共享")
            DispatchMainThreadSafe { [self] in
                screenSharePublication = publication
                screenShareParticipant = participant
                callManager.currentCall.isPresentedShare = true
                presentShareView()
            }
        }
    }
    
    //MARK: 谁结束了分享
    public func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        if publication.kind == .video && publication.source == .screenShareVideo {
            RoomDataManager.shared.closeScreenSharedParticipant(participant: participant)
        }
    }
    
    public func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        if !participant.isScreenShareEnabled()
            && publication.source == .screenShareVideo
            && screenShareParticipant == participant  {
            Logger.info("结束了屏幕共享")
            DispatchMainThreadSafe { [self] in
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
    public func room(_ room: Room, didUpdateSpeakingParticipants participants: [Participant]) {
        DTMeetingManager.shared.currentCallTalkingPop()
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
    
    // 检测remote麦克风关闭
    public func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        DTMeetingManager.shared.currentCallTalkingPop()
        if trackPublication.track is AudioTrack {
            // 只处理音频的弹幕
            RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: isMuted)
        } else if trackPublication.track is VideoTrack {
            // 视频
            RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
        }
    }
    
    public func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        DTMeetingManager.shared.currentCallTalkingPop()
        if publication.track is AudioTrack, !publication.isMuted {
            // 只处理开麦的弹幕
            RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: false)
        } else if publication.track is VideoTrack {
            // 视频
            RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
        }
    }

}

extension RoomContext {
    /// 有人说话：延迟 0.4 秒刷新说话人，取消还原共享人的任务
    private func handleActiveSpeakers() {
        // 取消待还原的任务
        resetToDefaultWorkItem?.cancel()
        resetToDefaultWorkItem = nil

        // 取消之前准备执行的刷新任务（节流）
        activeSpeakerWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateSpeakingUI()
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
            self?.restoreDefaultSharingView()
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
}
