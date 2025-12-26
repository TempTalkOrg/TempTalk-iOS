//
//  DTMeetingManager+Utils.swift
//  Difft
//
//  Created by Henry on 2025/4/16.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFAudio
import LiveKit

extension DTMeetingManager {
    func sampleBulletRtmCalls() -> [String] {
        var rtmCalls: [String] = ["Good 👍",
                                  "Bad 😝",
                                  "Agree ✅",
                                  "Disagree ❌",
                                  "Gotta go, bye",
                                  "Please go faster",
                                  "Please make screen bigger",
                                  "Can't hear you. Bad Signal",
                                  "Can't hear you. Your voice is too low"]
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                return
            }
            rtmCalls = callConfig.chatPresets
        }
        return rtmCalls
    }
    
    func autoHideTimeoutDuration() -> Int {
        var timeoutResult = 9000
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                return
            }
            timeoutResult = callConfig.autoHideTimeoutResult ?? 9000
        }
        return Int(timeoutResult / 1000)
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
    
    func openMuteOtherEnabled() -> Bool {
        var muteOtherEnabled: Bool = false
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                return
            }
            muteOtherEnabled = callConfig.muteOtherEnabled
        }
        return muteOtherEnabled
    }
    
    func createCallMsgEnabled() -> Bool {
        var createCallMsg: Bool = false
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                return
            }
            createCallMsg = callConfig.createCallMsg
        }
        return createCallMsg
    }
    
    // MARK: - 参会人排序
    // 重连的缓存策略
    func sortedReconnectingParticipants() -> [ParticipantSnapshot] {
        return reconnectingParticipants ?? []
    }
    
    func sortedMeetingParticipants() -> [Participant] {
        if let room = roomContext?.room {
            return sortedMeetings(participants: Array(room.allParticipants.values))
        }
        return []
    }
    
    func sortedMeetings(participants: [Participant]) -> [Participant] {

        let maxParticipantCount = 8

        // 获取当前所有参会人和他们的 identity
        let allIdentities = Set(participants.compactMap { $0.identity?.stringValue })

        // Step 1: 清理 visibleParticipants 中离会的人
        visibleParticipants.removeAll { participant in
            guard let id = participant.identity?.stringValue else { return true }
            return !allIdentities.contains(id)
        }

        // Step 2: 补充 visibleParticipants 不满时的数据（按 host > 视频 > 麦）
        if visibleParticipants.count < maxParticipantCount {
            fillVisibleParticipantsIfBelowLimit(maxParticipantCount, participants: participants)
        } else {
            // Step 3: 替换逻辑（visible 人满时，根据最久未发言替换）
            fillVisibleParticipantsIfUpperLimit(participants: participants)
        }

        // Step 4: 按 host > 视频 > 其他 重排 visibleParticipants
        sortVisibleParticipants()

        // Step 5: 处理剩余参会人，按权重排序
        let visibleIds = Set(visibleParticipants.compactMap { $0.identity?.stringValue })
        let remaining = participants.filter {
            guard let id = $0.identity?.stringValue else { return false }
            return !visibleIds.contains(id)
        }.sorted { a, b in
            let ca = a.isCameraEnabled() ? 1 : 2
            let cb = b.isCameraEnabled() ? 1 : 2
            if ca != cb { return ca < cb }

            if a.isSpeaking && b.isSpeaking {
                return a.audioLevel > b.audioLevel
            } else if a.isSpeaking {
                return true
            } else if b.isSpeaking {
                return false
            }

            let ma = a.isMicrophoneEnabled() ? 1 : 2
            let mb = b.isMicrophoneEnabled() ? 1 : 2
            if ma != mb { return ma < mb }

            return a.id < b.id
        }

        return visibleParticipants + remaining
    }
    
    private func fillVisibleParticipantsIfBelowLimit(_ limit: Int, participants: [Participant]) {
        guard let room = roomContext?.room else {
            return
        }
        
        var addedIdentities = Set(visibleParticipants.compactMap { $0.identity?.stringValue })

        func tryAppend(_ participant: Participant) {
            guard let id = participant.identity?.stringValue, !addedIdentities.contains(id) else { return }
            visibleParticipants.append(participant)
            addedIdentities.insert(id)
        }

        if !addedIdentities.contains(room.localParticipant.identity?.stringValue ?? "") {
            visibleParticipants.insert(room.localParticipant, at: 0)
            addedIdentities.insert(room.localParticipant.identity?.stringValue ?? "")
        }

        for participant in participants where participant.isCameraEnabled() {
            tryAppend(participant)
            if visibleParticipants.count >= limit { break }
        }
        
        if visibleParticipants.count < limit {
            for participant in participants where participant.isMicrophoneEnabled() {
                tryAppend(participant)
                if visibleParticipants.count >= limit { break }
            }
        }
    }
    
    
    private func fillVisibleParticipantsIfUpperLimit(participants: [Participant]) {
        
        let visibleIdentities = Set(visibleParticipants.compactMap { $0.identity?.stringValue })
        let otherParticipants = participants.filter {
            guard let id = $0.identity?.stringValue else { return false }
            return !visibleIdentities.contains(id)
        }

        if !otherParticipants.isEmpty {
            let minSpokeIndex = visibleParticipants.enumerated().dropFirst().min(by: { $0.element.lastSpokeAt < $1.element.lastSpokeAt })?.offset
            
            let now = Date().ows_millisecondsSince1970
            let timeThreshold: UInt64 = 10000
            let others = visibleParticipants.dropFirst().enumerated()
            let inactiveParticipants = others.filter { _, participant in
                return now - UInt64(participant.lastSpokeAt) > timeThreshold
            }

            let silentAndInvisible = inactiveParticipants.filter {
                !$0.element.isMicrophoneEnabled() && !$0.element.isCameraEnabled()
            }
            let speakingInvisible = inactiveParticipants.filter {
                $0.element.isMicrophoneEnabled() && !$0.element.isCameraEnabled()
            }
            let candidates: [(offset: Int, element: Participant)] =
                !silentAndInvisible.isEmpty ? silentAndInvisible :
                (!speakingInvisible.isEmpty ? speakingInvisible : [])

            if let target = candidates.max(by: {
                (now - UInt64($0.element.lastSpokeAt)) < (now - UInt64($1.element.lastSpokeAt))
            }) {
                let replaceableIndex = target.offset + 1
                // 你可以在这里进行替换逻辑
                for participant in otherParticipants {
                    if participant.isCameraEnabled(){
                        visibleParticipants[replaceableIndex] = participant
                        break
                    }
                }
            }
            
            for participant in otherParticipants where participant.isSpeaking {
                if let idx = minSpokeIndex {
                    visibleParticipants[idx] = participant
                }
                break
            }
        }
    }
    
    private func sortVisibleParticipants() {
        guard let room = roomContext?.room else {
            return
        }
        let localIdentity = room.localParticipant.identity?.stringValue
        visibleParticipants.sort { a, b in
            func priority(_ p: Participant) -> Int {
                if p.identity?.stringValue == localIdentity { return 0 }
                if p.isCameraEnabled() { return 1 }
                return 2
            }
            return priority(a) < priority(b)
        }
    }
    
    // 小列表的规则
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
            
            // 如果都在说话，按音频级别排序
            let isSpeakingA = a.isSpeaking
            let isSpeakingB = b.isSpeaking
            if isSpeakingA && isSpeakingB {
                return a.audioLevel < b.audioLevel
            } else if isSpeakingA {
                return true
            } else if isSpeakingB {
                return false
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
            OWSWindowManager.shared().showCallView()
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
                targetCall.roomName = groupThread.name(with: nil)
            }
        }
        Logger.info("\(logTag) targetCall")
        return targetCall
    }
    
    // MARK: - 本地消息合并
    func prepareForMeetingStart(isCaller: Bool = true,
                                thread: TSThread? = nil,
                                timestamp: UInt64? = nil,
                                source: String? = nil) {
        // 处理开始会议的主叫和非主叫的逻辑
        prepareForMeetingCaller(isCaller: isCaller,
                                thread: thread)
        // 处理开始和邀请的本地消息
        guard currentCall.createCallMsg else { return }
        prepareForMeetingStartOrInvite(thread: thread,
                                       timestamp: timestamp,
                                       isOutgoing: source == "startCall")
    }
    
    private func prepareForMeetingCaller(isCaller: Bool = true,
                                         thread: TSThread? = nil,
                                         timestamp: UInt64? = nil) {
        if isCaller {
            if let startThread = thread {
                if startThread.isGroupThread() {
                    self.sendGroupCallMessage(thread: startThread)
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

    func prepareForMeetingStartOrInvite(thread: TSThread? = nil,
                                        timestamp: UInt64? = nil,
                                        serverTimestamp: UInt64? = nil,
                                        isOutgoing: Bool? = false) {
        Task { @MainActor in
            if isOutgoing ?? false  {
                if currentCall.controlType == DTMeetingManager.sourceControlStart {
                    currentCall.callType == .group ? sendOutgoingLocalGroupStartCallMessage(thread: thread)
                    : sendOutgoingLocalPrivateStartCallMessage(thread: thread)
                }
            } else {
                maybeGenerateMeetingMessage(roomID: currentCall.roomId ?? "") {
                    if currentCall.controlType == DTMeetingManager.sourceControlStart {
                        currentCall.callType == .group
                        ? receiveIncomingLocalGroupStartCallMessage()
                        : receiveIncomingLocalPrivateStartCallMessage()
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
    
    func muteAudio(_ muted: Bool) async {
        Logger.info("\(logTag) call utils mute audio \(muted)")
        await roomContext?.setLocalMicrophone(enable: !muted)
    }
    
    func syncLocalMicrophoneStateToCallKit(_ muted: Bool) {
        guard let callerId = currentCall.caller else {
            Logger.error("\(self.logTag) no callerId")
            return
        }
        
        DTCallKitManager.shared().muteCurrentCall(muted, callerId:callerId)
    }
    
    func restoreFullScreenView() {
        if self.hasMeeting, OWSWindowManager.shared().hasCall() {
            OWSWindowManager.shared().showCallView()
            floatingView.removeFromSuperview()
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
                                                     defaultHeight: 210,
                                               ignorePanGestureInContent: false,
                                               forbidPanGesture: true)
        noiseNav.navigationBar.isHidden = true
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.presentPanModal(noiseNav)
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
            // 创建新的视频视图
            let videoView = VideoView()
            videoView.track = track   // 一次绑定，不能频繁切换
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

        if newSid == currentlyDisplayedSid,
           newCameraEnabled == currentlyCameraEnabled {
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
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
            let callConfig = CallConfig(from: raw) else {
                completion([])
                return
            }
            completion(callConfig.clusters)
        }
    }
    
    func denoiseNameRegex() -> String {
        var denoiseNameRegex = "airpods"
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                return
            }
            denoiseNameRegex = callConfig.excludedNameRegex
        }
        return denoiseNameRegex
    }
    
    func startSpeedTest() {
        clusterSpeedTester.start()
    }
    
    func isInputAirPods(portName: String) -> Bool {
        let denoiseNameRegex = denoiseNameRegex()
        let pattern = "(?i)\(NSRegularExpression.escapedPattern(for: denoiseNameRegex))"
        let regex = try! NSRegularExpression(pattern: pattern)

        let range = NSRange(location: 0, length: portName.utf16.count)
        let contains = regex.firstMatch(in: portName, options: [], range: range) != nil
        return contains
    }
    
    func switchCamera() {
        Task {
            guard let track = DTMeetingManager.shared.roomContext?.room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
                  let cameraCapturer = track.capturer as? CameraCapturer else {
                return
            }
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
    
    func isPresentedShare() -> Bool {
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
