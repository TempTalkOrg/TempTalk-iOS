//
//  DTMeetingManager+hangup.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

// MARK: call view related action, life cycle

extension DTMeetingManager {
    
    // disconnect 已在 RoomContext 中调用
    // caller
    func endCallAction(forceEndGroupMeeting: Bool = false) async {
        Logger.info("Actively end the call")
        
        // TODO: call 1. caller 增加判断会议中人只有自己了, 不发出去 cancel msg
        // 2. caller 如果对方已入过会议, 则需要发 hangup msg
        
        if currentCall.callType == .private && currentCall.isCaller && !inMeeting {
            if let roomContext, roomContext.room.connectionState != .disconnected {
                await roomContext.disconnect()
            }
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
                roomContext.room.connectionState == .connected {
                await hangupCall(needSyncCallKit: true,
                                 isByLocal: true,
                                 forceEndGroupMeeting: forceEndGroupMeeting,
                                 roomId: roomId,
                                 removeMeetingBar: true)
                Logger.info("endcall need remove join")
            } else {
                //无会议的时候删除
                if forceEndGroupMeeting {
                    await hangupCall(needSyncCallKit: true,
                                     isByLocal: true,
                                     forceEndGroupMeeting: forceEndGroupMeeting,
                                     roomId: currentCall.roomId,
                                     removeMeetingBar: true)
                } else {
                    await hangupCall(needSyncCallKit: true,
                                     isByLocal: true,
                                     forceEndGroupMeeting: forceEndGroupMeeting,
                                     roomId: currentCall.roomId,
                                     removeMeetingBar: false)
                }
                Logger.info("endcall hangup exception")
            }
        }
        
    }
    
    /// hangup
    /// - Parameter needSyncCallKit: YES-从 callkit 页面触发 NO-从应用内触发
    func hangupCall(needSyncCallKit: Bool,
                    isByLocal: Bool = false,
                    forceEndGroupMeeting: Bool = false,
                    roomId: String? = nil,
                    removeMeetingBar: Bool = false,
                    showErrorToast: Bool = false) async {
        
        guard (currentCall.isCaller && isByLocal) || !currentCall.isCaller else {
            Logger.error("\(logTag) hangup exception isByLocal:\(isByLocal)")
            hideToast()
            return
        }

        Logger.info("\(logTag) entry callType: \(currentCall.callType) isByLocal:\(isByLocal)")
        
        // 0). 移除meeting bar, 传入roomId才去移除，callModel在 3).时已经清空, 会找不到对应的call
        if let roomId = roomId {
            if removeMeetingBar {
                Logger.info("\(logTag) hangup remove meetingbar")
                handleMeetingBar(roomId: roomId, action: .remove)
            }
            
            if roomId != currentCall.roomId { // 如果多个会议中其它会议结束, 只移除 meetingbar
                Logger.info("\(logTag) roomId != currentCall.roomId")
                hideToast()
                return
            }
        }

        if currentCall.callType == .private && isByLocal {
            // 1on1
            Logger.info("\(logTag) hangup callType: \(currentCall.callType) isByLocal:\(isByLocal)")
            await sendCallMessage(.hangup)
        }
        
        if currentCall.callType != .private && forceEndGroupMeeting {
            Logger.info("\(logTag) hangup callType: \(currentCall.callType) forceEndGroupMeeting:\(forceEndGroupMeeting)")
            await sendCallMessage(.hangup, forceEndGroupMeeting: forceEndGroupMeeting)
        }
        
        if let roomContext {
            Logger.info("\(logTag) will disconnect")
            await roomContext.disconnect()
        }
        
        // 是否展示toast
        self.showErrorTost = showErrorToast
        // 同步callkit
        syncCallKitState(needSyncCallKit: needSyncCallKit)
        // 清理资源
        clearCallState()
    }
    
    func clearDisconnectErrorData() async {
        // 先清理资源再释放视图
        Logger.info("\(logTag) clearDisconnectErrorData trigger")
        if let roomContext {
            Logger.info("\(logTag) will disconnect")
            await roomContext.disconnect()
        }
        
        syncCallKitState(needSyncCallKit: true)
        
        clearCallState()
    }
    
    // 会议结束通知发起的结束会议
    func meetingNotificationEndAllClearData(roomId: String? = nil) async {
        Logger.info("\(logTag) meetingNotificationEndAllClearData trigger")
        // 0). 移除meeting bar, 传入roomId才去移除，callModel在 3).时已经清空, 会找不到对应的call
        if let roomId = roomId {
            DispatchMainThreadSafe {
                Logger.info("\(self.logTag) end meeting remove meetingbar")
                self.handleMeetingBar(roomId: roomId, action: .remove)
            }
        }
        
        if let roomContext {
            Logger.info("\(logTag) will disconnect")
            await roomContext.disconnect()
        }
            
        syncCallKitState(needSyncCallKit: true)
        
        clearCallState()
        
        DispatchMainThreadSafe {
            // 退出会议时候关闭倒计时
            TimerDataManager.shared.isShowCountDownView = false
        }
    }
    
    
    /// 1on1 对端挂断 call
    /// - Parameters:
    ///   - roomId: The ID of the meeting room
    ///   - isRemoveBar: Whether to remove the meeting bar, defaults to false
    func othersideHungupCall(roomId: String, isRemoveBar: Bool = false) async {
        
        Logger.info("\(logTag) otherside HungupCall needSyncCallKit \(!currentCall.isCaller)")
        
        if DTParamsUtils.validateString(roomId).boolValue, isRemoveBar {
            // 对端挂断，移除meetingBar
            handleMeetingBar(roomId: roomId, action: .remove)
        }
        
        // 1). trigger disconnect if needed
        if let roomContext = roomContext {
            await roomContext.disconnect()
        }
        
        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: !currentCall.isCaller)
        
        // 4). clear Call State
        // 响铃一声的，不需要停止
        clearCallState()
        
        DispatchMainThreadSafe {
            // 播放停会的声音
            DTToastHelper.show(withInfo: Localized("GROUP_MEETING_OTHER_END_CALL"))
            self.playSound(.callOff, isLoop: false, playMode: .playback)
        }
    }
    
    /// 本地主动拒接远端来的 call
    /// - Parameter needSyncCallKit: YES-从 callkit 页面触发 NO-从应用内触发
    func rejectRemoteCall() async {
        
        Logger.info("\(logTag) reject remote call needSyncCallKit \(true)")
        
        // 1). send reject msg (1on1时发给caller和自己其他端，多人时只发自己另外一端)
        await sendCallMessage(.reject)
        
        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: true)
        
        // 3). clear Call State
        clearCallState()
    }
    
    /// 本地 1on1 发出的 call 被拒接
    func localCallHaveBeenRejected() async {
        
        Logger.info("\(logTag) reject localCall needSyncCallKit \(false)")
        
        // 0). trigger disconnect if needed
        if let roomContext = roomContext {
            await roomContext.disconnect()
        }
        
        // 1). sync CallKit State
        syncCallKitState(needSyncCallKit: false)
        
        // 2). clear Call State
        clearCallState()
    }
    
    /// 主动取消本地发起的 call
    func cancelLocalCall() async {
        
        Logger.info("\(logTag) cancel localCall needSyncCallKit \(false)")
        
        // 1). send cancel msg
        if case .private = currentCall.callType { // 1on1
            Logger.info("\(logTag) local call cancel callApi")
            await sendCallMessage(.cancel)
        }
        
        // 2). sync CallKit State
        syncCallKitState(needSyncCallKit: false)
        
        // 3). clear Call State
        clearCallState()
    }
    
    func joinedCall() async {
        
        // 1). send joined msg
        await sendCallMessage(.joined)
        
        // 2). 停止响铃
        stopSound()
    }

    /// 远端发来的 call 被取消
    func remoteCallHaveBeenCanceled() async {
        
        Logger.info("\(logTag) cancel remote call needSyncCallKit \(true)")
        
        // 0). trigger disconnect if needed
        if let roomContext = roomContext {
            await roomContext.disconnect()
        }
        
        // 1). sync CallKit State
        syncCallKitState(needSyncCallKit: true)
        
        // 2). clear Call State
        clearCallState()
    }
    
    private func clearCallState() {
        // 先异步静音所有音轨
        if let roomContext = roomContext {
            Task {
                for track in roomContext.room.localParticipant.localAudioTracks {
                    do {
                        try await track.mute()
                        Logger.info("\(logTag) Successfully muted track")
                    } catch {
                        Logger.error("\(logTag) Failed to mute track: \(error)")
                    }
                }
            }
        }
        
        DispatchMainThreadSafe {
            self.appContext = nil
            self.roomContext = nil
            self.clearCurrentCall()
            self.stopCheckTalking()
            // 持续响应的铃声需要停止
            self.stopSound()
            DTToastHelper.hide()
            self.removeCallWindow()
            Logger.info("\(self.logTag) clear data remvoe call window")
            UIDevice.current.isProximityMonitoringEnabled = false
            self.isMinimize = false
            if self.showErrorTost {
                let rootWindow = OWSWindowManager.shared().rootWindow
                let topVC = rootWindow.findTopViewController()
                DTToastHelper.toast(withText: Localized("CALL_LIVEKIT_ERROR_TOAST"), in: topVC.view, durationTime: 3, afterDelay: 1)
                self.showErrorTost = false
                Logger.info("\(self.logTag) root window show error toast")
            }
        }
    }
    
    private func syncCallKitState(needSyncCallKit: Bool) {
        Logger.info("\(logTag) syncCallKitState needSyncCallKit: \(needSyncCallKit)")
        if needSyncCallKit, let caller = currentCall.caller { // 非 CallKit 页面操作, 需要同步状态
            Task { @MainActor in
                Logger.info("\(logTag) syncCallKitState")
                DTCallKitManager.shared().endCallAction(caller)
            }
        }
    }
    
    public func removeCallWindow() {
                
        Task { @MainActor in
            removeFloatingView()
            let rootWindow = OWSWindowManager.shared().rootWindow
            callAlertManager.bringLiveKitAlertCalls(to: rootWindow)

            await OWSWindowManager.shared().endCall(nil)
            answerVC = nil
        }
    }
    
    func removeFloatingView() {
        Task { @MainActor in
            if floatingView.superview != nil {
                floatingView.removeFromSuperview()
            }
        }
    }
    
    static func checkRoomIdValid(_ roomId: String) async -> (anotherDeviceJoined: Bool, userStopped: Bool)? {
        
        return await DTCallAPIManager().checkRoomIdValid(roomId)
    }
    
    private func hideToast() {
        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
        
}
