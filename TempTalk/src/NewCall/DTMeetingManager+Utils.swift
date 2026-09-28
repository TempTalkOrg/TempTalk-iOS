//
//  DTMeetingManager+Utils.swift
//  Difft
//
//  Created by Henry on 2025/4/16.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFAudio
import LiveKit
import QuartzCore

extension DTMeetingManager {
    func sampleBulletRtmCalls() -> [String] {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.chatPresets
    }

    func bubbleMessageConfig() -> BubbleMessageConfig {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.bubbleMessage
    }

    func quickMessagePresets() -> [String] {
        let config = bubbleMessageConfig()
        // 合并 emojiPresets 和 textPresets
        return config.emojiPresets + config.textPresets
    }

    func autoHideTimeoutDuration() -> Int {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.autoHideTimeoutResult / 1000
    }
    
    func fetchSharingItem() -> DTMultiChatItemModel? {
        if let room = roomContext?.room {
            let allParticipants = [room.localParticipant] + Array(room.remoteParticipants.values)
            for participant in allParticipants.compactMap({ $0 }) {
                if participant.videoTracks.contains(where: { $0.source == .screenShareVideo }) {
                    let chatModel = DTMultiChatItemModel()
                    chatModel.account = participant.identity?.stringValue.components(separatedBy: ".").first
                    chatModel.recipientId = participant.identity?.stringValue
                    chatModel.displayName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: chatModel.account)
                    chatModel.isSharing = true
                    chatModel.isSpeaking = participant.isSpeaking
                    chatModel.isMute = participant.audioTracks.first?.isMuted ?? true
                    chatModel.isHost = participant.metadata?.contains("host") ?? false
                    return chatModel
                }
            }
        }
        return nil
    }
    
    func fetchSpeakingItem() -> DTMultiChatItemModel? {
        if let room = roomContext?.room {
            let allParticipants = [room.localParticipant] + Array(room.remoteParticipants.values)
            for participant in allParticipants.compactMap({ $0 }) {
                if participant.isSpeaking {
                    let chatModel = DTMultiChatItemModel()
                    chatModel.account = participant.identity?.stringValue.components(separatedBy: ".").first
                    chatModel.recipientId = participant.identity?.stringValue
                    chatModel.displayName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: chatModel.account)
                    chatModel.isSharing = participant.videoTracks.contains(where: { $0.source == .screenShareVideo })
                    chatModel.isSpeaking = participant.isSpeaking
                    chatModel.isMute = participant.audioTracks.first?.isMuted ?? true
                    chatModel.isHost = participant.metadata?.contains("host") ?? false
                    return chatModel
                }
            }
        }
        return nil
    }
    
    func currentSpeakingParticipant() -> Participant? {
        roomContext?.currentActiveSpeaker
    }

    func micOnLineUp() -> [Participant] {
        guard let room = roomContext?.room else { return [] }
        let speaker = currentSpeakingParticipant()
        let allParticipants: [Participant] = [room.localParticipant] + Array(room.remoteParticipants.values)

        // speaker 已在 SpeakerFloatingView header 单独展示,这里过滤掉避免重复
        let candidates = allParticipants.filter {
            $0.isMicrophoneEnabled() && $0 !== speaker
        }

        // 候选列表原始位置,用于"视频组内保序"和最终 tiebreaker,避免抖动
        let positionOf: [ObjectIdentifier: Int] = Dictionary(
            uniqueKeysWithValues: candidates.enumerated().map { (ObjectIdentifier($0.element), $0.offset) }
        )

        // 排序规则对齐 Android sortParticipantsByPriority:
        // local > screenShare > camera > 视频组保持原顺序 > 说话音量分桶 > lastSpokeAt > 原顺序
        // 注: candidates 已预过滤 isMicrophoneEnabled, 所以省略 Android 中的 mic 档.
        let audioLevelThreshold: Float = 0.05
        let sorted = candidates.sorted { a, b in
            let aLocal = a is LocalParticipant
            let bLocal = b is LocalParticipant
            if aLocal != bLocal { return aLocal }

            let aShare = a.isScreenShareEnabled()
            let bShare = b.isScreenShareEnabled()
            if aShare != bShare { return aShare }

            let aCam = a.isCameraEnabled()
            let bCam = b.isCameraEnabled()
            if aCam != bCam { return aCam }

            if aShare || aCam {
                let pa = positionOf[ObjectIdentifier(a)] ?? .max
                let pb = positionOf[ObjectIdentifier(b)] ?? .max
                return pa < pb
            }

            let aBucket = a.isSpeaking ? -Int(a.audioLevel / audioLevelThreshold) : .max
            let bBucket = b.isSpeaking ? -Int(b.audioLevel / audioLevelThreshold) : .max
            if aBucket != bBucket { return aBucket < bBucket }

            if a.lastSpokeAt != b.lastSpokeAt { return a.lastSpokeAt > b.lastSpokeAt }

            let pa = positionOf[ObjectIdentifier(a)] ?? .max
            let pb = positionOf[ObjectIdentifier(b)] ?? .max
            return pa < pb
        }

        return Array(sorted.prefix(3))
    }

    func micOnLineUpDisplayNames() -> [String] {
        micOnLineUp().map { participant in
            let recipientId = participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
            return DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
        }
    }

    func openMuteOtherEnabled() -> Bool {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.muteOtherEnabled
    }

    func createCallMsgEnabled() -> Bool {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.createCallMsg
    }

    static func redactedCallLogIdentifier(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "nil" }
        return "***\(value.suffix(6))"
    }
    
    // MARK: - 参会人排序

    // Small-grid (≤2) ordering. Uses the same stable order as the multi-grid path so tiles don't
    // reshuffle when a 2-person call flips useMultiGrid → legacy after the collapse delay; this also
    // matches the pre-refactor "local first" ordering.
    func legacySortedMeetingParticipants() -> [Participant] {
        guard let room = roomContext?.room else { return [] }
        resetActiveSpeakerGridState()
        return stableMeetingOrder(participants: Array(room.allParticipants.values))
    }

    func sortedMeetingParticipants(visibleWindow: Int, now: TimeInterval = CACurrentMediaTime()) -> [Participant] {
        guard let room = roomContext?.room else { return [] }
        return sortedMeetings(
            participants: Array(room.allParticipants.values),
            visibleWindow: visibleWindow,
            now: now
        )
    }

    /// 计算多人宫格 + 剩余参会人排序列表。纯计算,无副作用;
    /// 调度器状态由 `computeSortedMeetings` 在主线程内就地维护(参见 issue 1f351e7d)。
    func sortedMeetings(
        participants: [Participant],
        visibleWindow: Int,
        now: TimeInterval
    ) -> [Participant] {
        let (visible, remaining) = computeSortedMeetings(
            participants: participants,
            visibleWindow: visibleWindow,
            now: now
        )
        return visible + remaining
    }

    /// Reset scheduler state. Main-thread only — see `activeSpeakerGridState` isolation note on `computeSortedMeetings`.
    func resetActiveSpeakerGridState() {
        AssertIsOnMainThread()
        activeSpeakerGridState = ActiveSpeakerScheduler.State()
    }

    /// Compute the new `(visible, remaining)` lists.
    ///
    /// Mutates `activeSpeakerGridState` in place, so this must run on the main thread only.
    /// It is currently reached solely from the SwiftUI body path (main thread); the assertion
    /// guards against any future off-main caller introducing a data race on the scheduler state.
    private func computeSortedMeetings(
        participants: [Participant],
        visibleWindow: Int,
        now: TimeInterval
    ) -> (visible: [Participant], remaining: [Participant]) {
        AssertIsOnMainThread()
        let orderedParticipants = stableMeetingOrder(participants: participants)
        guard orderedParticipants.count >= 7 else {
            resetActiveSpeakerGridStateIfNeeded()
            return (orderedParticipants, [])
        }

        let snapshots = orderedParticipants.map { participant in
            ActiveSpeakerParticipantSnapshot(
                id: Self.gridParticipantId(participant),
                isSpeaking: participant.isSpeaking,
                isScreenSharing: participant.isScreenShareEnabled(),
                isCameraEnabled: participant.isCameraEnabled(),
                isMicrophoneEnabled: participant.isMicrophoneEnabled(),
                audioLevel: participant.audioLevel,
                lastSpokeAt: UInt64(max(participant.lastSpokeAt, 0)),
                isLocal: participant is LocalParticipant
            )
        }
        let orderedIds = ActiveSpeakerScheduler.scheduledIds(
            participants: snapshots,
            visibleWindow: min(max(visibleWindow, 1), orderedParticipants.count),
            now: now,
            state: &activeSpeakerGridState
        )
        let byId = Dictionary(uniqueKeysWithValues: orderedParticipants.map { (Self.gridParticipantId($0), $0) })
        let scheduledParticipants = orderedIds.compactMap { byId[$0] }
        let effectiveWindow = min(max(visibleWindow, 1), scheduledParticipants.count)
        return (
            Array(scheduledParticipants.prefix(effectiveWindow)),
            Array(scheduledParticipants.dropFirst(effectiveWindow))
        )
    }

    private func stableMeetingOrder(participants: [Participant]) -> [Participant] {
        let localIdentity = roomContext?.room.localParticipant.identity?.stringValue
        return participants.sorted { a, b in
            func priority(_ p: Participant) -> (Int, Int, String) {
                let local = p.identity?.stringValue == localIdentity ? 0 : 1
                let sharing = p.isScreenShareEnabled() ? 0 : 1
                return (local, sharing, Self.gridParticipantId(p))
            }
            return priority(a) < priority(b)
        }
    }

    private func resetActiveSpeakerGridStateIfNeeded() {
        if activeSpeakerGridState != ActiveSpeakerScheduler.State() {
            activeSpeakerGridState = ActiveSpeakerScheduler.State()
        }
    }

    private static func gridParticipantId(_ participant: Participant) -> String {
        participant.identity?.stringValue ?? participant.sid?.stringValue ?? participant.id
    }

    // 小列表的规则
    @MainActor
    func sortedParticipants() -> [Participant] {
        if let room = roomContext?.room {
            return sorted(participants: Array(room.allParticipants.values))
        }
        return []
    }
    
    func sorted(participants: [Participant]) -> [Participant] {
        return participants.sorted(by: { a, b in
            // 优先排序 LocalParticipant 在前
            if let localA = a as? LocalParticipant, !(b is LocalParticipant) {
                return true
            }
            if !(a is LocalParticipant), let localB = b as? LocalParticipant {
                return false
            }
            
            // 接着排序开启屏幕共享的在前
            let screenShareA = a.isScreenShareEnabled() ? 1 : 2
            let screenShareB = b.isScreenShareEnabled() ? 1 : 2
            if screenShareA != screenShareB {
                return screenShareA < screenShareB
            }

            // 有视频的在前
            let cameraEnabledA = a.isCameraEnabled() ? 1 : 2
            let cameraEnabledB = b.isCameraEnabled() ? 1 : 2
            if cameraEnabledA != cameraEnabledB {
                return cameraEnabledA < cameraEnabledB
            }

            // 正在说话的在前(都在说话不比音量，避免抖动)
            if a.isSpeaking != b.isSpeaking {
                return a.isSpeaking
            }

            // 麦克风开启的在前
            let micEnabledA = a.isMicrophoneEnabled() ? 1 : 2
            let micEnabledB = b.isMicrophoneEnabled() ? 1 : 2
            if micEnabledA != micEnabledB {
                return micEnabledA < micEnabledB
            }

            // 按说话时间排序
            let aLastSpokeAt = a.lastSpokeAt
            let bLastSpokeAt = b.lastSpokeAt
            if aLastSpokeAt != bLastSpokeAt {
                return aLastSpokeAt > bLastSpokeAt
            }

            // 最后按加入会议时间排序(ios 闪动，改为id)
            return a.id < b.id
        })
    }
    
    // MARK: - 获取屏幕分享
    func showScreenShare() -> Bool {
        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()
        let className = String(describing: type(of: topVC))
        if className.contains("DTHostingController"),  className.contains("CallScreenShareView") {
            return true
        }
        return false
    }
    
    // MARK: - 获取当前的targetcall
    //获取当前会话的call对象
    public func currentThreadTargetCall(_ thread: TSThread) -> DTLiveKitCallModel? {
        if self.hasMeeting, OWSWindowManager.shared().hasCall() {
            Task { @MainActor [weak self] in
                self?.restoreFullScreenView()
            }
            return nil
        }
        Logger.info("\(logTag) ready receive targetCall")
        var targetCall: DTLiveKitCallModel?
        let allMeetings = DTMeetingManager.shared.allMeetings
        Logger.info("\(logTag) receive allMeetings count \(allMeetings.count)")
        if let virtualThread = thread as? DTVirtualThread {
            Logger.info("\(logTag) current is DTVirtualThread")
            targetCall = allMeetings.filter {
                guard let roomId = $0.roomId else {
                    return false
                }
                Logger.info("\(logTag) virtualThread sort by \(virtualThread.uniqueId == $0.roomId)")
                return virtualThread.uniqueId == roomId
            }.first
        } else if let contactThread = thread as? TSContactThread {
            Logger.info("\(logTag) current is TSContactThread")
            targetCall = allMeetings.filter {
                guard let conversationId = $0.conversationId else {
                    return false
                }
                Logger.info("\(logTag) contactThread sort by \(conversationId == contactThread.contactIdentifier())")
                return conversationId == contactThread.contactIdentifier()
            }.first
            if let targetCall, targetCall.roomName.isEmpty {
                targetCall.roomName = contactThread.name(with: nil)
            }
        } else if let groupThread = thread as? TSGroupThread {
            Logger.info("\(logTag) current is TSGroupThread")
            targetCall = allMeetings.filter {
                guard let conversationId = $0.conversationId else {
                    return false
                }

                Logger.info("\(logTag) groupThread sort by \(conversationId == groupThread.serverThreadId)")
                return conversationId == groupThread.serverThreadId
            }.first
            
            if let targetCall, targetCall.roomName.isEmpty {
                SDSDatabaseStorage.shared.read { tx in
                    targetCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: groupThread.serverThreadId,
                        fallbackName: "",
                        transaction: tx)
                }
            }
        }
        Logger.info("\(logTag) targetCall")
        return targetCall
    }
    
    // MARK: - 本地消息合并
    func prepareForMeetingStart(isCaller: Bool = true,
                                call: DTLiveKitCallModel? = nil,
                                thread: TSThread? = nil,
                                timestamp: UInt64? = nil,
                                serverTimestamp: UInt64? = nil,
                                source: String? = nil) {
        // Resolve first so both the normal success path and the teardown fallback claim delivery
        // against the same call attempt.
        let call = call ?? currentCall
        // 处理开始会议的主叫和非主叫的逻辑
        prepareForMeetingCaller(isCaller: isCaller,
                                call: call,
                                thread: thread)
        // 处理开始和邀请的本地消息
        guard call.createCallMsg else { return }
        prepareForMeetingStartOrInvite(call: call,
                                       thread: thread,
                                       timestamp: timestamp,
                                       serverTimestamp: serverTimestamp,
                                       isOutgoing: source == "startCall")
    }
    
    private func prepareForMeetingCaller(isCaller: Bool = true,
                                         call: DTLiveKitCallModel,
                                         thread: TSThread? = nil,
                                         timestamp: UInt64? = nil) {
        if isCaller {
            if let startThread = thread {
                if startThread.isGroupThread() {
                    self.sendGroupCallMessage(
                        thread: startThread,
                        call: call,
                        acceptedRoomId: call.roomId,
                        trigger: "normal-success"
                    )
                } else {
                    self.send1on1CallMessage(thread: startThread)
                }
            }
            Logger.info("\(logTag) start meeting completion")
        } else {
            Task {
                // 1on1 callee入会后向其他端同步joined
                await self.joinedCall()
            }
        }
    }

    func prepareForMeetingStartOrInvite(call: DTLiveKitCallModel? = nil,
                                        thread: TSThread? = nil,
                                        timestamp: UInt64? = nil,
                                        serverTimestamp: UInt64? = nil,
                                        isOutgoing: Bool? = false) {
        // Resolve now so the deferred task reads this call, not a concurrently-reset currentCall.
        let call = call ?? currentCall
        Task { @MainActor in
            if isOutgoing ?? false  {
                if call.controlType == DTMeetingManager.sourceControlStart {
                    call.callType == .group
                        ? sendOutgoingLocalGroupStartCallMessage(call: call, thread: thread, serverTimestamp: serverTimestamp)
                        : sendOutgoingLocalPrivateStartCallMessage(call: call, thread: thread, serverTimestamp: serverTimestamp)
                }
            } else {
                maybeGenerateMeetingMessage(roomID: call.roomId ?? "") {
                    if call.controlType == DTMeetingManager.sourceControlStart {
                        call.callType == .group
                            ? receiveIncomingLocalGroupStartCallMessage(call: call, serverTimestamp: serverTimestamp)
                            : receiveIncomingLocalPrivateStartCallMessage(call: call, serverTimestamp: serverTimestamp)
                    }
                }
            }
        }
    }
    
    func maybeGenerateMeetingMessage(
        roomID: String,
        generateMessage: () -> Void
    ) {
        let lastRoomKey = "lastMeetingRoomID"
        let generatedKey = "hasGeneratedMessageForMeeting_\(roomID)"
        
        let lastRoomID = UserDefaults.standard.string(forKey: lastRoomKey)
        
        // 如果房间变了，表示新会议，清除状态
        if lastRoomID != roomID {
            UserDefaults.standard.set(roomID, forKey: lastRoomKey)
            UserDefaults.standard.set(false, forKey: generatedKey)
        }

        let alreadyGenerated = UserDefaults.standard.bool(forKey: generatedKey)
        
        if !alreadyGenerated {
            generateMessage()
            UserDefaults.standard.set(true, forKey: generatedKey)
        }
    }
    
    func handleMeetingEnded(meetingID: String) {
        let key = "hasGeneratedMessageForMeeting_\(meetingID)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func anyCodableToUInt64(_ value: AnyCodable) -> UInt64? {
        switch value.value {
        case let v as UInt64:
            return v
        case let v as Int:
            return UInt64(exactly: v)
        case let v as Double:
            return UInt64(exactly: v)
        case let v as String:
            return UInt64(v)
        case let v as NSNumber:
            return UInt64(exactly: v.uint64Value)
        default:
            return nil
        }
    }
    
    func dealMeetingCountDownView(currentTimeMs: UInt64, expiredTimeMs: UInt64, participantId: String, topic: String) {
        DispatchMainThreadSafe {
            TimerDataManager.shared.isShowCountDownView = true
            RoomDataManager.shared.pipCountDownUpdate()
            if topic == "set-countdown" {
                RoomDataManager.shared.sendRTMBarrageMessage(pid: participantId, message: "starts a countdown timer")
            }
            
            let diff = Int((expiredTimeMs - currentTimeMs) / 1000)
            if diff > 0 {
                TimerDataManager.shared.startCountdown(seconds: Int(diff))
            }
        }
    }
    
    func destroyMeetingCountDownView() {
        DispatchMainThreadSafe {
            TimerDataManager.shared.isShowCountDownView = false
            RoomDataManager.shared.pipCountDownUpdate()
        }
    }
    
    @discardableResult
    func muteAudio(
        _ muted: Bool,
        userInitiated: Bool = false,
        syncCallKitOnFailure: Bool = true
    ) async -> Bool {
        // Idempotency: skip when LiveKit's mic is already in the requested state.
        // Prevents redundant setMicrophone calls (each toggles the VPIO hardware
        // and is mirrored back by iOS as another CallKit action) from sustaining
        // a CallKit<->LiveKit feedback loop.
        if let room = roomContext?.room {
            let currentlyEnabled = room.localParticipant.isMicrophoneEnabled()
            if currentlyEnabled == !muted {
                Logger.info("\(logTag) call utils mute audio \(muted) skipped: mic already \(muted ? "muted" : "unmuted")")
                return true
            }
        }
        Logger.info("\(logTag) call utils mute audio \(muted)")
        guard let roomContext else { return false }
        let didApply = await roomContext.setLocalMicrophone(
            enable: !muted,
            userInitiated: userInitiated
        )
        if userInitiated, syncCallKitOnFailure, !didApply {
            // A direct native CallKit action already changed the system UI. If
            // LiveKit rejects it, restore the actual microphone state.
            await roomContext.syncLocalMicrophoneStateToCallKit(
                muted: !roomContext.room.localParticipant.isMicrophoneEnabled()
            )
        }
        return didApply
    }
    
    func syncLocalMicrophoneStateToCallKit(_ muted: Bool) {
        guard let callKitUUID = currentCall.callKitUUID else {
            Logger.error("\(self.logTag) no callKitUUID")
            return
        }

        DTCallKitManager.shared().muteCurrentCall(muted, uuidString: callKitUUID)
    }
    
    @MainActor func restoreFullScreenView() {
        guard self.hasMeeting, OWSWindowManager.shared().hasCall() else { return }

        let wasMinimize = isMinimize
        isMinimize = false
        removeFloatingView()
        OWSWindowManager.shared().showCallView()

        let callWindow = OWSWindowManager.shared().callViewWindow
        callAlertManager.bringLiveKitAlertCalls(to: callWindow)

        if wasMinimize {
            Logger.info("\(logTag) restored from minimize to full screen")
        }

        Task { @MainActor [weak self] in
            self?.roomContext?.checkAndPresentScreenShareIfNeeded()
        }
    }
    
    func presentRaiseHandVC() {
        let handVC = DTRaiseHandController()
        handVC.modalPresentationStyle = .popover
        let profileCardNav =  DTPanModalNavController.init()
        profileCardNav.navigationBar.isHidden = true
        profileCardNav.viewControllers = [handVC]
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.presentPanModal(profileCardNav)
    }
    
    func calculateRaiseHandsWidth() -> CGFloat {
        let raiseHandIconWidth: CGFloat = 55
        let maxControlWidth: CGFloat = 172
        let nameFontSize: CGFloat = 15
        let nameTextHeight: CGFloat = 20
        
        let participantIds = RoomDataManager.shared.handsData
        let contactsManager = Environment.shared.contactsManager
        let names = participantIds.compactMap { pid in
            contactsManager?.displayName(forPhoneIdentifier: pid)
        }
        let text = names.joined(separator: ", ")
        let font = UIFont.systemFont(ofSize: nameFontSize, weight: .medium)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: nameTextHeight),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size
        let iconWidth = raiseHandIconWidth
        var width = ceil(size.width) + iconWidth
        if width > maxControlWidth {
           width = maxControlWidth
        }
        return width
    }
    
    
    func presentMicNoiseVC() {
        let noiseVC = DTUpdateNoiseController()
        noiseVC.modalPresentationStyle = .popover
        let noiseNav = DTPanModalNavController(rootViewController: noiseVC,
                                                     defaultHeight: 344,
                                               ignorePanGestureInContent: false,
                                               forbidPanGesture: true)
        noiseNav.navigationBar.isHidden = true
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.presentPanModal(noiseNav)
    }

    func presentCriticalAlertConfirmVC() {
        let invitedUserIds = Array(currentCall.invitedCriticalAlertUsers)
        let confirmVC = DTCriticalAlertConfirmController(invitedUserIds: invitedUserIds, callType: currentCall.callType)
        confirmVC.modalPresentationStyle = .popover
        let confirmNav = DTPanModalNavController(rootViewController: confirmVC,
                                                       defaultHeight: 195,
                                                 ignorePanGestureInContent: false,
                                                 forbidPanGesture: true)
        confirmNav.navigationBar.isHidden = true
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.presentPanModal(confirmNav)
    }
    
    func updateVideoView(item: DTMultiChatItemModel, containView: UIView, aboveView: UIView) {
        if let allParticipants = roomContext?.room.allParticipants, let recipientId = item.recipientId {
            for (sid, participant) in allParticipants {
                if recipientId == sid.stringValue {
                    updateDisplayedParticipant(to: participant, in: containView, aboveView: aboveView)
                }
            }
        }
    }
    
    func getOrCreateVideoView(for participant: Participant) -> VideoView? {
        guard let identity = participant.identity?.stringValue else { return nil }

        // 没有就检查摄像头状态并创建
        if participant.isCameraEnabled(), let publication = participant.firstCameraPublication,
              let track = publication.track as? VideoTrack
        {
            // 创建新的视频视图。注意 track 需按对象身份判断是否变化：全量重连会用同一 sid 的新 track
            // 对象替换旧的，调用方（updateDisplayedParticipant）据此决定是否重建并重新绑定。
            let videoView = VideoView()
            videoView.track = track
            videoView.layoutMode = .fill
            videoView.clipsToBounds = true

            videoViewPool[identity] = videoView
            return videoView
            
        } else {
            if let videoView = videoViewPool[identity] {
                videoView.isHidden = true
                videoView.track = nil // 解绑 track，防止 LiveKit 报错
            }
            
            return nil
        }
    }
    
    func renderVideo(for participant: Participant, in containerView: UIView, aboveView: UIView) {
        guard let videoView = getOrCreateVideoView(for: participant) else {
            return
        }

        // 避免重复添加
        if videoView.superview != containerView {
            videoView.removeFromSuperview() // 先从旧容器移除（如果有）
            containerView.insertSubview(videoView, aboveSubview: aboveView)
            videoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }

        videoView.isHidden = false
    }
    
    func removeVideo(for identity: String, from containerView: UIView) {
        if let videoView = videoViewPool[identity] {
            if videoView.superview == containerView {
                videoView.removeFromSuperview()
            }
        }
    }
    
    func updateDisplayedParticipant(to participant: Participant, in containerView: UIView, aboveView: UIView) {

        let newIdentity = participant.identity?.stringValue
        let newSid = participant.sid?.stringValue
        let newCameraEnabled = participant.isCameraEnabled()

        // Also rebind when the underlying track OBJECT changed (e.g. a full reconnect re-subscribes a
        // new track with the SAME sid): comparing sid alone would keep the pooled VideoView bound to
        // the dead old track and freeze PiP video.
        let liveTrack = participant.firstCameraPublication?.track as? VideoTrack
        let boundTrack = currentlyDisplayedIdentity.flatMap { videoViewPool[$0]?.track }
        if newSid == currentlyDisplayedSid,
           newCameraEnabled == currentlyCameraEnabled,
           liveTrack === boundTrack {
            return
        }

        if let old = currentlyDisplayedIdentity {
            removeVideo(for: old, from: containerView)
        }

        if newCameraEnabled {
            renderVideo(for: participant, in: containerView, aboveView: aboveView)
            currentlyDisplayedIdentity = newIdentity
            currentlyDisplayedSid = newSid
            currentlyCameraEnabled = true
        } else {
            currentlyDisplayedIdentity = newIdentity
            currentlyDisplayedSid = newSid
            currentlyCameraEnabled = false
        }
    }
    
    func fetchClustersConfig(completion: @escaping ([[String: String]]) -> Void) {
        let callConfig = CallConfigManager.fetchCallConfig()
        completion(callConfig.clusters)
    }

    func denoiseNameRegex() -> String {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.excludedNameRegex
    }
    
    func isInputAirPods(portName: String) -> Bool {
        let denoiseNameRegex = denoiseNameRegex()

        // 如果没有配置排除规则，返回 false（不是 AirPods）
        guard !denoiseNameRegex.isEmpty else {
            return false
        }

        let pattern = "(?i)\(NSRegularExpression.escapedPattern(for: denoiseNameRegex))"
        let regex = try! NSRegularExpression(pattern: pattern)

        let range = NSRange(location: 0, length: portName.utf16.count)
        let contains = regex.firstMatch(in: portName, options: [], range: range) != nil
        return contains
    }
    
    func switchCamera() {
        guard let track = roomContext?.room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
              let cameraCapturer = track.capturer as? CameraCapturer else {
            return
        }
        Task {
            try await cameraCapturer.switchCameraPosition()
        }
    }
    
    func setCameraRotation(orientation newOrientation: UIInterfaceOrientation) {
        if let participant = DTMeetingManager.shared.roomContext?.room.localParticipant {
            participant.set(orientation: newOrientation)
        }
    }
    
    func callShowToast(message: String) {
        let rootWindow = OWSWindowManager.shared().rootWindow
        let topVC = rootWindow.findTopViewController()
        DTToastHelper.toast(withText: message, in: topVC.view, durationTime: 3, afterDelay: 1)
    }
    
    public func isPresentedShare() -> Bool {
        return currentCall.isPresentedShare
    }
    
    func requestAuthToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    let invalidError = NSError(domain: "com.temptalk.call.token",
                                      code: -10000,
                                      userInfo: [NSLocalizedDescriptionKey: "token invalid"])
                    continuation.resume(throwing: invalidError)
                }
            }
        }
    }

    func forceRefreshAuthToken() async throws -> String {
        try await DTTokenHelper.sharedInstance.forceRefreshGlobalAuthToken()
    }
    
    func getProfileInfo(
        uid: String,
        completion: @escaping (Bool) -> Void
    ) {
        TSAccountManager.shared.getContactMessage(byReceptid: uid, success: { [weak self] contact in
            guard let self = self else { return }
            self.databaseStorage.asyncWrite { writeTransaction in
                let contactsManager = Environment.shared.contactsManager
                var signalAccount = contactsManager?.signalAccount(forRecipientId: uid, transaction: writeTransaction)
                
                if signalAccount == nil {
                    signalAccount = SignalAccount(recipientId: uid)
                }
                
                signalAccount?.contact = contact
                
                if let newAccount = signalAccount?.copy() as? SignalAccount {
                    contactsManager?.updateSignalAccount(
                        withRecipientId: uid,
                        withNewSignalAccount: newAccount,
                        with: writeTransaction
                    )
                }
                
                writeTransaction.addAsyncCompletionOnMain {
                    if let publicConfigs = contact.publicConfigs {
                        completion(publicConfigs.criticalAlert)
                    }
                }
            }
        }, failure: { error in
            Logger.info("\(self.logTag) get profile critical error \(error.localizedDescription)")
            completion(false)
        })
    }
    
    func syncCriticalAlertNotificationSettingsIfNeeded() {
        guard let localNumber = TSAccountManager.localNumber() else {
            return
        }
        // 获取系统CriticalAlert状态
        let enabled = isCriticalAlertEnabled()
        //
        self.databaseStorage.asyncRead { transaction in
            guard let localNum = TSAccountManager.sharedInstance().localNumber() else {return}
            
            let contactsManager = Environment.shared.contactsManager;
            let account = contactsManager?.signalAccount(forRecipientId: localNum, transaction: transaction)
            if account?.contact?.publicConfigs?.criticalAlert != enabled {
                DTChatSetProfileApi().setProfileCriticalInfo(enabled) { entity in
                    if entity?.status == 0 {
                        Logger.info("\(self.logTag) set profile critical success enable\(enabled)")
                    }
                } failure: { error in
                    Logger.info("\(self.logTag) set profile critical error \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func isCriticalAlertEnabled() -> Bool {
        let center = UNUserNotificationCenter.current()
        var enabled = false
        let semaphore = DispatchSemaphore(value: 0)

        center.getNotificationSettings { settings in
            enabled = (settings.criticalAlertSetting == .enabled)
            semaphore.signal()
        }

        semaphore.wait()
        return enabled
    }
    
    func syncContactCriticallAlert(uid: String) {
        self.databaseStorage.asyncRead { transaction in
            let contactsManager = Environment.shared.contactsManager;
            let account = contactsManager?.signalAccount(forRecipientId: uid, transaction: transaction)
            self.otherCriticalAlert = account?.contact?.publicConfigs?.criticalAlert ?? false
            Logger.info("[newcall] update otherCriticalAlert \(self.otherCriticalAlert)")
        }
    }
    
    func isGid(_ gid: String) -> Bool {
        return gid.count == 32 &&
               gid.range(of: "^[a-zA-Z0-9]{32}$",
                         options: .regularExpression) != nil
    }
}

// DTMeetingManagerProtocol
extension DTMeetingManager {
    public func isInMeeting() -> Bool {
        return self.inMeeting
    }
}
