//
//  RoomContext+RoomDelegate.swift
//  Difft
//
//  Created by Henry on 2025/4/21.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFAudio
import Foundation
import LiveKit
import SwiftUI
import TTMessaging

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

    public func room(_: Room, track _: TrackPublication, didUpdateE2EEState _: E2EEState) {
        Logger.debug("\(logTag) Did update e2eeState")
    }

    public nonisolated func room(_: Room, didUpdateConnectionState connectionState: ConnectionState, from oldValue: ConnectionState) {
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

    public nonisolated func roomDidConnect(_: Room) {
        Logger.info("\(logTag) roomDidConnect")

        Task { @MainActor [weak self] in
            guard let self else { return }

            callManager.stopConnectionPhaseTimer()

            let isPrivate = currentCall.callType == .private
            let needPublishSilenceAudio = currentCall.ttcalResponseOptions?.autoPublishSilenceAudio ?? false

            Task.detached {
                [weak self] in
                guard let self else { return }

                do {
                    await DTRTCAudioSession.shared.connectRoomSuccessConfig()
                    if isPrivate {
                        try await room.localParticipant.setMicrophone(enabled: default1on1MicphoneState)
                    } else {
                        if needPublishSilenceAudio {
                            await setLocalMicrophone(enable: true, publishMuted: true)
                        }
                    }
                } catch {
                    Logger.error("\(logTag) failed to set audio track: isPrivate=\(isPrivate), needPublishSilenceAudio=\(needPublishSilenceAudio), \(error)")
                }
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
            callManager.tryTransition(from: .connecting, to: .connected)
            // 非会议中的人，展示 instant
            Logger.info("\(logTag) check localParticipant \(room.localParticipant.identity?.stringValue)")
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
                    callManager.tryTransition(from: .connecting, to: .connected)
                }
            } else {
                currentCall.callState = .answering
                callManager.handleMeetingBar(call: currentCall, action: .add)
                callManager.tryTransition(from: .connecting, to: .connected)
                // 异步调用 joinedCall
                Task { await callManager.joinedCall() }
            }
        }
    }

    public nonisolated func roomDidSignalConnect(_: Room) {
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
                    Logger.error("\(logTag) response.body is empty, waiting for timeout")
                    return
                }
                connectTimeoutTask?.cancel()
                connectTimeoutTask = nil
                currentCall.ttcalResponseBody = response.body
                currentCall.ttcalResponseOptions = response.callOptions
                callManager.dealConnetedSuccess(with: response.body)
            }

            /// 超时处理
            func handleTimeout() {
                Logger.error("[newcall] ttCallResp is nil or body empty after 15s")
                let roomId = DTMeetingManager.shared.currentCall.roomId
                Task {
                    await DTMeetingManager.shared.hangupCall(
                        needSyncCallKit: true,
                        isByLocal: true,
                        roomId: roomId,
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
    public nonisolated func room(_: Room, didFailToConnectWithError error: LiveKitError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                updateStale(with: error)
                Logger.error("\(logTag) didFailToConnectWithError receive error: \(error)")
            } else {
                Logger.error("\(logTag) didFailToConnectWithError error: nil")
            }
        }
    }

    /// 断开异常
    /// 注意：此回调只处理「已连接后」的断开错误，连接阶段的错误由 didFailToConnectWithError 处理
    public nonisolated func room(_: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            // 当前用户离会（无论是否有错误都执行）
            RoomDataManager.shared.disconnectParticipant(participant: room.localParticipant)
            UIDevice.current.isProximityMonitoringEnabled = false

            if let error {
                // 检查是否是主动断开导致的（cancelled 类型不需要处理）
                if error.type == .cancelled {
                    Logger.info("\(logTag) didDisconnect cancelled - user initiated disconnect")
                    return
                }

                // 检查错误处理状态，避免重复处理
                if errorHandlingState == .handled {
                    Logger.info("\(logTag) didDisconnect ignored - already handled")
                    return
                }

                updateStale(with: error)
                Logger.info("\(logTag) didDisconnect error: \(error) errortype:\(error.type)")

                // 标记为已处理
                markHandled()

                await callManager.hangupCoordinator.terminate(
                    reason: .connectError,
                    options: TerminationOptions(
                        roomId: currentCall.roomId,
                        showErrorToast: true
                    )
                )
            } else {
                Logger.info("\(logTag): normal disconnect")
            }
        }
    }

    public nonisolated func roomDidReconnect(_: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) room reconnected - canceling disconnect timer")
            isRoomReconnecting = false
            callManager.stopParticipantDisTimer()
            // 重连后检查是否有屏幕共享未展示
            checkAndPresentScreenShareIfNeeded()
            callManager.setVisibleParticipants([])
            bumpVideoRefreshToken()
        }
    }

    public nonisolated func roomIsReconnecting(_: Room) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.info("\(logTag) room is Reconnecting")
            isRoomReconnecting = true

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

            if isLocalValid, isRemoteValid {
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
    public nonisolated func room(_: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor [weak self, weak participant] in
            guard let self, let participant else { return }
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

                    callManager.tryTransition(from: .connecting, to: .connected)
                }

                if case .answering = currentCall.callState, room.allParticipants.keys.count > 2 {
                    // 1on1 call进入更多人type转为instant
                    callManager.turnIntoInstantCall()
                }

                // 直接赋值主线程属性（extension 已为 @MainActor）
                othersideParticipantFor1on1 = participant
            } else if case .group = currentCall.callType {
                // 非会议中的人，展示instant
                checkPartiantInRoom(room.localParticipant.identity?.stringValue ?? "")
            } else if case .instant = currentCall.callType {
                // instant call
                callManager.stopCallTimeoutTimer()
                callManager.tryTransition(from: .connecting, to: .connected)
            }

            // 清理已入会用户的邀请记录
            if let participantId = participant.identity?.stringValue.components(separatedBy: ".").first {
                callManager.removeUserFromInvitedList(participantId)
            }

            // 自动离会处理
            callManager.currentCallTalkingPop()
            // 远端入会人数发生变化
            RoomDataManager.shared.connectParticipant(participant: participant)
        }
    }

    // remote offline
    public nonisolated func room(_: Room, participantDidDisconnect participant: RemoteParticipant) {
        let participantIdentity = participant.identity
        Task { @MainActor [weak self, weak participant] in
            guard let self else { return }
            let participantId = participantIdentity?.stringValue ?? "unknown"
            Logger.debug("\(logTag) remote disconnected, participantId: \(participantId), remaining participants: \(room.allParticipants.count)")

            if let focusParticipant, focusParticipant.identity == participantIdentity {
                self.focusParticipant = nil
            }

            if currentCall.callType == .private, room.allParticipants.count == 1 {
                Logger.info("\(logTag) private call - only local participant remains, start disconnect timer")
                callManager.startParticipantDisTimer {
                    let roomId = DTMeetingManager.shared.currentCall.roomId
                    Logger.info("[newcall] remote participant disconnected - initiating hangup")
                    Task {
                        Logger.info("[newcall] hangup remote participant timeout")
                        await DTMeetingManager.shared.hangupCall(needSyncCallKit: true,
                                                                  roomId: roomId)
                    }
                }
            }

            callManager.currentCallTalkingPop()
            if let participant {
                RoomDataManager.shared.disconnectParticipant(participant: participant)
            }
        }
    }

    public nonisolated func room(_: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType _: EncryptionType) {
        let participantId = participant?.identity?.stringValue.components(separatedBy: ".").first ?? ""
        Task { @MainActor [weak self] in
            guard let self else { return }

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
                       let payload = receiveConfig["payload"] as? String
                    {
                        callManager.dealRemoteHandsStatus(topic: topic, payload: payload)
                    }
                } catch {
                    Logger.error("\(logTag) hand parse json \(error)")
                }

            case "end-call":
                if let sid = room.sid?.stringValue, sid == currentCall.roomSid {
                    if let (signature, payload) = extractSignatureAndPayload(from: data) {
                        let roomId = currentCall.roomId
                        Task {
                            Logger.info("[newcall] topic end call currentcall")
                            await DTMeetingManager.shared.meetingNotificationEndAllClearData(roomId: roomId)
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

    public nonisolated func room(_: Room, participant _: Participant, trackPublication _: TrackPublication, didReceiveTranscriptionSegments segments: [TranscriptionSegment]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.debug("\(logTag) didReceiveTranscriptionSegments: \(segments.map { "(\($0.id): \($0.text), \($0.firstReceivedTime)-\($0.lastReceivedTime), \($0.isFinal))" }.joined(separator: ", "))")
        }
    }

    public nonisolated func room(_: Room, trackPublication _: TrackPublication, didUpdateE2EEState state: E2EEState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.debug("\(logTag) didUpdateE2EEState: \(state)")
        }
    }

    // MARK: 谁开始了分享

    public nonisolated func room(_: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        let kind = publication.kind
        let source = publication.source
        Task { @MainActor [weak self, weak participant] in
            guard let self else { return }
            if kind == .video, source == .screenShareVideo, let participant {
                RoomDataManager.shared.openScreenSharedParticipant(participant: participant)
            }
        }
    }

    public nonisolated func room(_: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        let source = publication.source
        Task { @MainActor [weak self, weak participant, weak publication] in
            guard let self, let participant, let publication else { return }
            guard participant.isScreenShareEnabled(),
                  source == .screenShareVideo else { return }

            screenSharePublication = publication
            screenShareParticipant = participant

            if !callManager.currentCall.isPresentedShare {
                Logger.info("[Livekit] start screen share")
                callManager.currentCall.isPresentedShare = true
                tryPresentShareView(maxRetryCount: 3)
            } else {
                Logger.info("[Livekit] screen share already presented, refreshed publication reference")
            }
        }
    }

    // MARK: 谁结束了分享

    public nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        let source = publication.source
        Task { @MainActor [weak self, weak participant] in
            guard let self else { return }
            guard source == .screenShareVideo else { return }

            if let participant {
                RoomDataManager.shared.closeScreenSharedParticipant(participant: participant)
            }

            unpublishScreenShareTask?.cancel()
            unpublishScreenShareTask = Task { @MainActor [weak self, weak room] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard let room, room.isScreenShareActive() else {
                    Logger.info("Screen share track unpublished and no active share, dismissing")
                    dismissShareViewIfNeeded()
                    return
                }

                Logger.info("Screen share track unpublished but room still has active share (reconnection), keeping share view")
            }
        }
    }

    public nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        let source = publication.source
        Task { @MainActor [weak self, weak room] in
            guard let self else { return }
            if source == .screenShareVideo {
                let isActive = room?.isScreenShareActive() ?? false
                Logger.info("Screen share track unsubscribed (local event, keeping share view). Published: \(isActive)")
            }
        }
    }

    public nonisolated func room(_: Room, didUpdateSpeakingParticipants participants: [Participant]) {
        let speakerIdentities = Set(participants.compactMap { $0.identity?.stringValue })
        let hasSpeakers = !participants.isEmpty
        Task { @MainActor [weak self] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            guard lastSpeakerIdentities != speakerIdentities else {
                return
            }

            lastSpeakerIdentities = speakerIdentities

            if hasSpeakers {
                currentActiveSpeaker = participants.max(by: { $0.audioLevel < $1.audioLevel })
            }
            RoomDataManager.shared.onMeetingUpdate?()

            if hasSpeakers {
                handleActiveSpeakers()
            } else {
                handleNoSpeakers()
            }
        }
    }

    public nonisolated func room(_: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        let isAudioTrack = trackPublication.track is AudioTrack
        let isVideoTrack = trackPublication.track is VideoTrack
        Task { @MainActor [weak self, weak participant] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            guard let participant else { return }
            if isAudioTrack {
                if let identity = participant.identity?.stringValue, let localNumber = TSAccountManager.localNumber() {
                    if identity != "\(localNumber).2" {
                        RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: isMuted)
                    } else {
                        RoomDataManager.shared.updateSeakingParticipant()
                    }
                }
            } else if isVideoTrack {
                RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
            }
        }
    }

    public nonisolated func room(_: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        let isAudioTrack = publication.track is AudioTrack
        let isVideoTrack = publication.track is VideoTrack
        let publicationIsMuted = publication.isMuted
        Task { @MainActor [weak self, weak participant] in
            guard let self else { return }
            callManager.currentCallTalkingPop()
            guard let participant else { return }
            if isAudioTrack, !publicationIsMuted {
                RoomDataManager.shared.updateMuteParticipant(participant: participant, isMuted: false)
            } else if isVideoTrack {
                RoomDataManager.shared.updateVideoMuteParticipant(participant: participant)
            }
        }
    }
}

// MARK: - Helper: speaker / share / stale handling

@MainActor
extension RoomContext {
    private func handleActiveSpeakers() {
        resetToDefaultWorkItem?.cancel()
        resetToDefaultWorkItem = nil
        activeSpeakerWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            RoomDataManager.shared.onPipUpdate?()
        }

        activeSpeakerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + activeSpeakerDelay, execute: workItem)
    }

    private func handleNoSpeakers() {
        activeSpeakerWorkItem?.cancel()
        activeSpeakerWorkItem = nil
        resetToDefaultWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.currentActiveSpeaker = nil
            RoomDataManager.shared.onMeetingUpdate?()
            RoomDataManager.shared.onPipUpdate?()
        }

        resetToDefaultWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resetDelay, execute: workItem)
    }

    func cleanup() {
        activeSpeakerWorkItem?.cancel()
        resetToDefaultWorkItem?.cancel()
    }

    /// 屏幕共享结束时统一清理状态和视图
    @MainActor
    func dismissShareViewIfNeeded() {
        screenSharePublication = nil
        screenShareParticipant = nil
        callManager.currentCall.isPresentedShare = false
        callManager.dismissAutoLeaveTipView()

        if let inviteVC {
            inviteVC.dismiss(animated: false)
            self.inviteVC = nil
        }
        dismissPresentedShareViewControllerIfNeeded()
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

    @MainActor
    func tryPresentShareView(delay: TimeInterval = 1.0, maxRetryCount: Int) {
        guard hasActiveScreenShareToPresent() else {
            Logger.info("[Livekit] No active screen share, skip presenting share view")
            resetSharePresentationState()
            return
        }

        syncShareViewReferenceIfNeeded()
        if isShareViewPresented {
            Logger.info("[Livekit] Share view already exists, skipping duplicate present")
            resetSharePresentationState()
            return
        }

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
                Logger.info("[Livekit] App still not active after delay, deferring to didBecomeActive")
                pendingShowUI = true
            }
            return
        }

        if OWSScreenLockUI.sharedManager().isShowingScreenLockUI {
            Logger.info("[Livekit] Screen lock is active, deferring screen share until unlock")
            pendingShowUI = true
            return
        }

        // 最小化（浮窗）状态下不展示屏幕共享，等用户点击浮窗回到会议后再展示
        if DTMeetingManager.shared.isMinimize {
            Logger.info("[Livekit] Call is minimized, deferring screen share presentation")
            pendingShowUI = true
            return
        }
        isPresentingShareView = true
        Logger.info("[Livekit] App active, presenting share view")

        presentShareView { [weak self] in
            Task { @MainActor in
                self?.isPresentingShareView = false
                Logger.info("[Livekit] Share view presented, reset presenting flag")
            }
        }
    }
}
