//
//  DTMeetingManager+Hangup.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

// MARK: call view related action, life cycle

extension DTMeetingManager {
    private enum RatingDisplayConfig {
        static let minimumMeetingDuration: TimeInterval = 60
    }

    /// 将状态转换到 disconnecting，防止在断开过程中有新的操作
    func transitionToDisconnecting() {
        let currentState = lifecycleState
        if currentState == .connected {
            tryTransition(from: .connected, to: .disconnecting)
        } else if currentState == .connecting {
            tryTransition(from: .connecting, to: .disconnecting)
        }
    }

    // disconnect 已在 RoomContext 中调用
    // caller
    func endCallAction(forceEndGroupMeeting: Bool = false) async {
        Logger.info("Actively end the call")

        // TODO: call 1. caller 增加判断会议中人只有自己了, 不发出去 cancel msg
        // 2. caller 如果对方已入过会议, 则需要发 hangup msg

        if currentCall.callType == .private, currentCall.isCaller, !inMeeting {
            // 先发送 cancel 消息，再断开 room，避免 room 断开后服务端无法处理 cancel 消息
            await cancelLocalCall()
        } else {
            var roomId: String?
            if currentCall.callType == .private {
                roomId = currentCall.roomId
            } else if let roomContext, roomContext.room.remoteParticipants.isEmpty {
                roomId = currentCall.roomId
            }

            if let roomContext,
               roomContext.room.remoteParticipants.isEmpty,
               roomContext.room.connectionState == .connected
            {
                await hangupCall(needSyncCallKit: true,
                                 isByLocal: true,
                                 forceEndGroupMeeting: forceEndGroupMeeting,
                                 roomId: roomId)
                Logger.info("endcall need remove join")
            } else {
                // 无会议的时候删除
                if forceEndGroupMeeting {
                    await hangupCall(needSyncCallKit: true,
                                     isByLocal: true,
                                     forceEndGroupMeeting: forceEndGroupMeeting,
                                     roomId: currentCall.roomId)
                } else {
                    await hangupCall(needSyncCallKit: true,
                                     isByLocal: true,
                                     forceEndGroupMeeting: forceEndGroupMeeting,
                                     roomId: currentCall.roomId)
                }
                Logger.info("endcall hangup exception")
            }
        }
    }

    /// hangup
    /// - Parameter needSyncCallKit: YES-从 callkit 页面触发 NO-从应用内触发
    /// - Parameter isFromCallKit: YES-来自 CallKit 的挂断请求，即使 roomId 不匹配也要执行完整流程
    func hangupCall(needSyncCallKit: Bool,
                    isByLocal: Bool = false,
                    forceEndGroupMeeting: Bool = false,
                    roomId: String? = nil,
                    showErrorToast: Bool = false,
                    isFromCallKit: Bool = false) async
    {
        guard (currentCall.isCaller && isByLocal) || !currentCall.isCaller else {
            Logger.error("\(logTag) hangup exception isByLocal:\(isByLocal)")
            hideToast()
            return
        }

        // 转换到 disconnecting 状态，防止在断开过程中有新的操作
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用（在状态转换后立即捕获）
        let roomContextToClean = self.roomContext

        Logger.info("\(logTag) hangupCall entry, callType: \(currentCall.callType), isByLocal:\(isByLocal), state: \(lifecycleState), isFromCallKit: \(isFromCallKit), roomId: \(roomId ?? "nil"), currentCall.roomId: \(currentCall.roomId ?? "nil")")

        // 0). 移除meeting bar, 传入roomId才去移除，callModel在 3).时已经清空, 会找不到对应的call
        // 规则：1on1 通话或强制结束群组会议时移除，否则保留（群组会议可能还在进行）
        if let roomId {
            let shouldRemoveMeetingBar = currentCall.callType == .private || forceEndGroupMeeting
            if shouldRemoveMeetingBar {
                Logger.info("\(logTag) hangup remove meetingbar (callType: \(currentCall.callType), forceEnd: \(forceEndGroupMeeting))")
                handleMeetingBar(roomId: roomId, action: .remove)
            } else {
                Logger.info("\(logTag) hangup keep meetingbar (group/instant call, not force ending)")
            }

            // 如果是 CallKit 触发的挂断，即使 roomId 不匹配也要执行完整流程
            // 只有当两个 roomId 都不为空且不相等时，才认为是挂断其他会议
            if !isFromCallKit, let currentRoomId = currentCall.roomId, roomId != currentRoomId {
                // 如果多个会议中其它会议结束, 只移除 meetingbar
                Logger.info("\(logTag) roomId != currentCall.roomId, skip hangup for other meeting. roomId: \(roomId), currentRoomId: \(currentRoomId)")
                hideToast()
                return
            }

            // 如果是 CallKit 挂断但 roomId 不匹配，记录警告但继续执行
            if isFromCallKit, let currentRoomId = currentCall.roomId, roomId != currentRoomId {
                Logger.warn("\(logTag) CallKit hangup with mismatched roomId, force execute. roomId: \(roomId), currentCall.roomId: \(currentRoomId)")
            }
        }

        if currentCall.callType == .private, isByLocal {
            // 1on1
            Logger.info("\(logTag) hangup callType: \(currentCall.callType) isByLocal:\(isByLocal)")
            await sendCallMessage(.hangup)
        }

        if currentCall.callType != .private, forceEndGroupMeeting {
            Logger.info("\(logTag) hangup callType: \(currentCall.callType) forceEndGroupMeeting:\(forceEndGroupMeeting)")
            await sendCallMessage(.hangup, forceEndGroupMeeting: forceEndGroupMeeting)
        }

        if let roomContextToClean {
            Logger.info("\(logTag) will disconnect")
            await roomContextToClean.disconnect()
        }

        // 是否展示toast
        showErrorTost = showErrorToast
        // 同步callkit
        syncCallKitState(needSyncCallKit: needSyncCallKit)
        // 清理资源（等待完成）
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: roomId)

        Logger.info("\(logTag) hangupCall completed, final state: \(lifecycleState)")
    }

    func clearDisconnectErrorData() async {
        // 先清理资源再释放视图
        Logger.info("\(logTag) clearDisconnectErrorData trigger")

        // 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext
        let currentRoomId = currentCall.roomId

        // 连接失败说明会议已不存在，无论 callType 都移除 meetingBar
        if let roomId = currentRoomId {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        if let roomContextToClean {
            Logger.info("\(logTag) will disconnect")
            await roomContextToClean.disconnect()
        }

        syncCallKitState(needSyncCallKit: true)

        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)
    }

    // 会议结束通知发起的结束会议
    func meetingNotificationEndAllClearData(roomId: String? = nil) async {
        Logger.info("\(logTag) meetingNotificationEndAllClearData trigger, current state: \(lifecycleState)")

        // 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用（在状态转换后、任何异步操作前）
        let roomContextToClean = self.roomContext

        // 0). 移除meeting bar, 传入roomId才去移除，callModel在 3).时已经清空, 会找不到对应的call
        if let roomId {
            DispatchMainThreadSafe {
                Logger.info("\(self.logTag) end meeting remove meetingbar")
                self.handleMeetingBar(roomId: roomId, action: .remove)
            }
        }

        if let roomContextToClean {
            Logger.info("\(logTag) will disconnect")
            await roomContextToClean.disconnect()
        }

        syncCallKitState(needSyncCallKit: true)

        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: roomId)

        DispatchMainThreadSafe {
            // 退出会议时候关闭倒计时
            TimerDataManager.shared.isShowCountDownView = false
        }
    }

    /// 1on1 对端挂断 call
    /// - Parameters:
    ///   - roomId: The ID of the meeting room
    func othersideHungupCall(roomId: String) async {
        Logger.info("\(logTag) otherside HungupCall needSyncCallKit \(!currentCall.isCaller), current state: \(lifecycleState), hasRoomContext: \(roomContext != nil)")

        let currentRoomId = currentCall.roomId

        // 仅在真正「接通」后才认定入会，避免未接通就重复提示/震动
        let wasInMeeting: Bool = {
            if currentCall.callType == .private {
                let remoteJoined = roomContext?.room.remoteParticipants.isEmpty == false
                let hasAnswered = currentCall.callState == .answering
                return lifecycleState == .connected || remoteJoined || hasAnswered
            } else {
                return lifecycleState == .connected || roomContext?.room.connectionState == .connected
            }
        }()

        // 0). 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext

        // 因此收到 hangup 时，无论 callType，都应该移除 meetingBar
        if DTParamsUtils.validateString(roomId).boolValue {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        // 1). trigger disconnect if needed
        if let roomContextToClean {
            await roomContextToClean.disconnect()
        }

        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: !currentCall.isCaller)

        // 3). clear Call State
        // 响铃一声的，不需要停止
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)

        // 只有真正入会的设备才播放挂断声音和提示
        if wasInMeeting {
            DispatchMainThreadSafe {
                // 播放停会的声音
                DTToastHelper.toast(withText: Localized("GROUP_MEETING_OTHER_END_CALL"), durationTime: 3, afterDelay: 1)
                self.playSound(.callOff, isLoop: false, playMode: .playback)
            }
        } else {
            Logger.info("\(logTag) otherside HungupCall skip sound and toast because device was not in meeting")
        }
    }

    /// 本地主动拒接远端来的 call
    /// - Parameter needSyncCallKit: YES-从 callkit 页面触发 NO-从应用内触发
    func rejectRemoteCall() async {
        Logger.info("\(logTag) reject remote call needSyncCallKit \(true), current state: \(lifecycleState)")

        // 0). 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext
        let currentRoomId = currentCall.roomId

        // 1). remove meeting bar (1on1 only; group/instant bar is managed by caller)
        if currentCall.callType == .private, let roomId = currentRoomId {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        // 2). send reject msg (1on1时发给caller和自己其他端，多人时只发自己另外一端)
        await sendCallMessage(.reject)

        // 3). sync CallKit State
        syncCallKitState(needSyncCallKit: true)

        // 4). clear Call State
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)
    }

    /// CallKit 拒接专用重载 — 使用显式 call model，避免依赖 currentCall（锁屏时可能尚未设置）
    /// 注意：此方法用于拒绝第二个来电（假通话），不应同步 CallKit 状态，否则会误挂第一个通话
    func rejectRemoteCall(with call: DTLiveKitCallModel) async {
        Logger.info("\(logTag) reject remote call (callkit) caller:\(call.caller ?? "") roomId:\(call.roomId ?? "")")

        await sendCallMessage(.reject, call)
    }

    /// 本地 1on1 发出的 call 被拒接
    func localCallHaveBeenRejected() async {
        Logger.info("\(logTag) reject localCall needSyncCallKit \(false), current state: \(lifecycleState)")

        // 0). 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext
        let currentRoomId = currentCall.roomId

        // 规则：1on1 通话移除 meetingBar；群组/即时通话保留（会议可能还在进行）
        if currentCall.callType == .private, let roomId = currentRoomId {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        // 1). trigger disconnect if needed
        if let roomContextToClean {
            await roomContextToClean.disconnect()
        }

        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: false)

        // 3). clear Call State
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)
    }

    /// 主动取消本地发起的 call
    func cancelLocalCall() async {
        Logger.info("\(logTag) cancel localCall needSyncCallKit \(false), current state: \(lifecycleState)")

        // 0). 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext
        let currentRoomId = currentCall.roomId

        // 规则：1on1 通话移除 meetingBar；群组/即时通话保留（会议可能还在进行）
        if currentCall.callType == .private, let roomId = currentRoomId {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        // 1). send cancel msg
        if case .private = currentCall.callType { // 1on1
            Logger.info("\(logTag) local call cancel callApi")
            await sendCallMessage(.cancel)
        }

        // 2). trigger disconnect if needed
        if let roomContextToClean, roomContextToClean.room.connectionState != .disconnected {
            await roomContextToClean.disconnect()
        }

        // 3). sync CallKit State
        syncCallKitState(needSyncCallKit: false)

        // 4). clear Call State
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)
    }

    func joinedCall() async {
        // 1). send joined msg
        await sendCallMessage(.joined)

        // 2). 停止响铃
        stopSound()
    }

    /// 远端发来的 call 被取消
    func remoteCallHaveBeenCanceled() async {
        Logger.info("\(logTag) cancel remote call needSyncCallKit \(true), current state: \(lifecycleState)")

        // 0). 转换到 disconnecting 状态
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用
        let roomContextToClean = self.roomContext
        let currentRoomId = currentCall.roomId

        // 规则：1on1 通话移除 meetingBar；群组/即时通话保留（会议可能还在进行）
        if currentCall.callType == .private, let roomId = currentRoomId {
            handleMeetingBar(roomId: roomId, action: .remove)
        }

        // 1). trigger disconnect if needed
        if let roomContextToClean {
            await roomContextToClean.disconnect()
        }

        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: true)

        // 3). clear Call State
        await clearCallState(roomContextToClean: roomContextToClean, roomIdToClean: currentRoomId)
    }

    /// 清理通话状态
    /// - Parameters:
    ///   - roomContextToClean: 要清理的 roomContext 引用，如果为 nil 则使用当前 self.roomContext
    ///   - roomIdToClean: 要清理的 roomId，如果为 nil 则清理当前存储的 roomId
    private func clearCallState(roomContextToClean: RoomContext? = nil, roomIdToClean: String? = nil) async {
        Logger.info("\(logTag) clearCallState entry, current state: \(lifecycleState)")

        // 使用统一的 RoomIdManager 清理
        if let roomIdToClean = roomIdToClean {
            RoomIdManager.shared.removeRoomId(roomIdToClean)
        } else if let currentRoomId = currentCall.roomId {
            RoomIdManager.shared.removeRoomId(currentRoomId)
        }

        // 使用传入的引用或当前的 roomContext
        let contextToClean = roomContextToClean ?? self.roomContext

        // 静音所有音轨（同步等待）
        if let contextToClean {
            for track in contextToClean.room.localParticipant.localAudioTracks {
                do {
                    try await track.mute()
                    Logger.info("\(logTag) Successfully muted track")
                } catch {
                    Logger.error("\(logTag) Failed to mute track: \(error)")
                }
            }
        }

        // 主线程执行完整清理（同步等待）
        await MainActor.run { [weak self] in
            guard let self else { return }
            let latestDuration = self.currentCall.duration ?? TimerDataManager.shared.duration
            self.lastMeetingDuration = latestDuration
        }

        // 执行完整清理（等待完成）
        await performCompleteCleanup(roomContextToClean: contextToClean)

        // 主线程处理后续操作
        await MainActor.run { [weak self] in
            guard let self else { return }

            // 处理错误提示
            if self.showErrorTost {
                let rootWindow = OWSWindowManager.shared().rootWindow
                let topVC = rootWindow.findTopViewController()
                DTToastHelper.toast(withText: Localized("CALL_LIVEKIT_ERROR_TOAST"), in: topVC.view, durationTime: 3, afterDelay: 1)
                self.showErrorTost = false
                Logger.info("\(self.logTag) root window show error toast")
            }

            self.ensurePortraitOrientationBeforeShowingRating()
        }

        Logger.info("\(logTag) clearCallState completed, final state: \(lifecycleState)")
    }

    /// 确保屏幕方向切换回竖屏后再展示评分弹窗，避免视图偏移问题
    private func ensurePortraitOrientationBeforeShowingRating() {
        defer { self.lastMeetingDuration = nil }

        // 防止多次调用导致评分逻辑被重复消费
        guard !hasTriggeredRating else {
            Logger.info("\(logTag) Rating already triggered, skipping")
            return
        }

        guard feedbackUserSid != nil else {
            Logger.info("\(logTag) Call never connected, skipping rating")
            return
        }

        guard meetsRatingDurationRequirement() else {
            return
        }

        let shouldShowRating = CallRatingTrigger.shared.shouldTriggerRating(hasSevereQualityIssue: feedbackIsNetworkPoor ?? false)

        if shouldShowRating {
            // 标记已经触发过评分，防止重复调用
            hasTriggeredRating = true
//            showRatingController()
        }
    }

    private func meetsRatingDurationRequirement() -> Bool {
        guard let duration = lastMeetingDuration ?? currentCall.duration ?? TimerDataManager.shared.duration else {
            Logger.info("\(logTag) Missing duration data, skipping rating")
            return false
        }

        guard duration >= RatingDisplayConfig.minimumMeetingDuration else {
            Logger.info("\(logTag) Call duration \(duration)s shorter than minimum \(RatingDisplayConfig.minimumMeetingDuration)s, skipping rating")
            return false
        }

        return true
    }

    /// 展示评分控制器
    func showRatingController() {
        // PanModal's custom presentation controller doesn't handle background presentation well.
        // When presented in background, its state machine becomes corrupted, creating a "zombie"
        // modal that breaks navigation lifecycle. Defer to foreground if app is not active.
        guard CurrentAppContext().isMainAppAndActive else {
            Logger.info("\(logTag) showRatingController: app not active, deferring to foreground")
            hasPendingRating = true
            return
        }

        let rootWindow = OWSWindowManager.shared().rootWindow
        let topVC = rootWindow.findTopViewController()

        Logger.info("\(self.logTag) ratingFeedbackController present from \(topVC)")

        DTRatingFeedbackController.present(from: topVC) { _ in
            Logger.info("\(self.logTag) ratingFeedbackController present success")
        }
    }

    private func syncCallKitState(needSyncCallKit: Bool) {
        Logger.info("\(logTag) syncCallKitState needSyncCallKit: \(needSyncCallKit)")
        if needSyncCallKit, let caller = currentCall.caller { // 非 CallKit 页面操作, 需要同步状态
            Task { @MainActor in
                Logger.info("\(logTag) syncCallKitState")
                DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: false)
            }
        }
    }

    @MainActor
    public func removeCallWindow() async {
        await dismissPresentedCallControllersIfNeeded()
        removeFloatingView()
        let rootWindow = OWSWindowManager.shared().rootWindow

        // 清理不在活跃会议列表中的 alert views，防止显示过期的 alert
        callAlertManager.cleanStaleAlertCalls()
        callAlertManager.bringLiveKitAlertCalls(to: rootWindow)

        await OWSWindowManager.shared().endCall(nil)
        answerVC = nil
    }

    @MainActor
    private func dismissPresentedCallControllersIfNeeded() async {
        let callWindow = OWSWindowManager.shared().callViewWindow
        // Clear any modals (e.g. pan modals) attached to the call window before tearing it down.
        guard let rootVC = callWindow.rootViewController,
              rootVC.presentedViewController != nil else { return }

        await withCheckedContinuation { continuation in
            rootVC.dismiss(animated: false) {
                continuation.resume()
            }
        }
    }

    @MainActor
    func removeFloatingView() {
        if floatingView.superview != nil {
            floatingView.removeFromSuperview()
        }
    }

    static func checkRoomIdValid(_ roomId: String) async -> (anotherDeviceJoined: Bool, userStopped: Bool)? {
        await DTCallAPIManager().checkRoomIdValid(roomId)
    }

    private func hideToast() {
        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
}
