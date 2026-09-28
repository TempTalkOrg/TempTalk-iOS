//
//  DTMeetingManager+Timer.swift
//  TempTalk
//
//  Created by Ethan on 10/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

extension DTMeetingManager {
    
    private struct AssociatedKeys {
        static var callTimeoutTimerKey: Int = 0
        static var callDurationTimerKey: Int = 1
        static var participantDisTimerKey: Int = 2
    }
    
    func releaseAllTimer() {
        stopCallTimeoutTimer()
        stopCallDurationTimer()
        stopParticipantDisTimer()
        stopConnectionPhaseTimer()
        stopCallDurationGate()
    }
    
    // MARK: 通话超时
    func startCallTimeoutTimer() {
        stopCallTimeoutTimer()
        // 通话超时三端改为固定值
        let interval: TimeInterval = currentCall.isCaller ? 60 : 56
        callTimeoutTimer = Timer.weakTimer(
            withTimeInterval: interval,
            target: self,
            selector: #selector(callTimeoutAction),
            userInfo: nil,
            repeats: false
        )
        
        if let callTimeoutTimer {
            RunLoop.current.add(callTimeoutTimer, forMode: .common)
        }
    }
    
    @objc
    private func callTimeoutAction(_ timer: Timer) {
        guard hasMeeting else { return }
        guard !inMeeting else { return }
        
        if currentCall.isCaller {
            DTToastHelper.showCallToast(Localized("SINGLE_CALL_TIMEOUT"))
            Task {
                Logger.info("\(logTag) caller timeout, canceling local call")
                await cancelLocalCall()
            }
        } else {
            Task {
                Logger.info("\(logTag) callee timeout, remoteCallHaveBeenCanceled")
                await remoteCallHaveBeenCanceled()
            }
        }
    }
    
    func stopCallTimeoutTimer() {
        guard let callTimeoutTimer else {
            return
        }
        
        callTimeoutTimer.invalidate()
        self.callTimeoutTimer = nil
    }
    
    // MARK: 会议计时器
    func startCallDurationTimer() {
        stopCallDurationTimer()
        DispatchMainThreadSafe {
            TimerDataManager.shared.duration = 0
        }

        callDurationTimer = Timer.weakTimer(
            withTimeInterval: 1,
            target: self,
            selector: #selector(callDurationTimerAction),
            userInfo: nil,
            repeats: true
        )
                
        if let callDurationTimer {
            RunLoop.current.add(callDurationTimer, forMode: .common)
        }
    }
    
    @objc
    private func callDurationTimerAction(_ timer: Timer) {
        guard inMeeting else { return }

        if var duration = TimerDataManager.shared.duration {
            duration += 1
            TimerDataManager.shared.duration = duration
        } else {
            TimerDataManager.shared.duration = 1
        }
        
        NotificationCenter.default.postNotificationNameAsync(
            DTStickMeetingManager.kMeetingDurationUpdateNotification,
            object: nil
        )
        
        currentCall.duration = TimerDataManager.shared.duration
        
    }
    
    func stopCallDurationTimer() {
        DispatchMainThreadSafe {
            TimerDataManager.shared.duration = nil
        }
        guard let callDurationTimer else {
            return
        }
        
        callDurationTimer.invalidate()
        self.callDurationTimer = nil
    }

    
    // MARK: 1v1 麦克风订阅门控
    //
    // 1v1 进入 `.connected` 后，等待服务端确认对端已订阅本端麦克风轨道。该事件可能早于门控装载，
    // 因此订阅状态必须保持；5 秒兜底避免无麦克风权限或事件缺失时一直显示「连接中」。

    @MainActor
    func armCallDurationGate() {
        guard !didStartCallDurationTimer else { return }
        guard inMeeting,
              let room = roomContext?.room,
              room.connectionState == .connected,
              !room.remoteParticipants.isEmpty
        else {
            return
        }
        isCallDurationGateArmed = true

        startCallDurationTimerIfTrackSubscribed()
        // 已经放行就不必再起兜底。
        guard !didStartCallDurationTimer else { return }

        guard callDurationGateTimer == nil else { return }
        callDurationGateTimer = Timer.weakTimer(
            withTimeInterval: 5,
            target: self,
            selector: #selector(callDurationGateTimeoutAction),
            userInfo: nil,
            repeats: false
        )

        if let callDurationGateTimer {
            RunLoop.current.add(callDurationGateTimer, forMode: .common)
        }
    }

    @nonobjc
    static func shouldHandleCallDurationGateTimeout(
        firedTimer: Timer,
        activeTimer: Timer?,
        isGateArmed: Bool,
        isInMeeting: Bool
    ) -> Bool {
        isGateArmed && isInMeeting && activeTimer === firedTimer
    }

    @objc
    private func callDurationGateTimeoutAction(_ timer: Timer) {
        Task { @MainActor [weak self, weak timer] in
            guard let self, let timer,
                  Self.shouldHandleCallDurationGateTimeout(
                      firedTimer: timer,
                      activeTimer: callDurationGateTimer,
                      isGateArmed: isCallDurationGateArmed,
                      isInMeeting: inMeeting
                  )
            else {
                return
            }
            startCallDurationTimerIfNeeded(reason: "fallbackTimeout")
        }
    }

    /// 本端麦克风轨道被对端订阅。门控尚未装载时也要保持该瞬时信号。
    @MainActor
    func notifyLocalMicTrackSubscribed() {
        guard !isMicTrackSubscribed else { return }
        isMicTrackSubscribed = true
        startCallDurationTimerIfTrackSubscribed()
    }

    @nonobjc
    static func shouldStartCallDurationTimer(
        isGateArmed: Bool,
        isMicTrackSubscribed: Bool,
        didStartTimer: Bool
    ) -> Bool {
        isGateArmed && isMicTrackSubscribed && !didStartTimer
    }

    /// 唯一的订阅放行点。群会/instant 或 1v1 尚未进入 `.connected` 时只记录信号。
    @MainActor
    private func startCallDurationTimerIfTrackSubscribed() {
        guard Self.shouldStartCallDurationTimer(
            isGateArmed: isCallDurationGateArmed,
            isMicTrackSubscribed: isMicTrackSubscribed,
            didStartTimer: didStartCallDurationTimer
        ) else {
            return
        }
        startCallDurationTimerIfNeeded(reason: "trackSubscribed")
    }

    /// 幂等：重连与手动切换节点都不能重启计时，否则已走的时长会被清零。
    @MainActor
    func startCallDurationTimerIfNeeded(reason: String) {
        guard !didStartCallDurationTimer else { return }
        didStartCallDurationTimer = true
        invalidateCallDurationGateTimer()
        Logger.info(
            "\(logTag)[1v1Timing] stage=callTimerStarted reason=\(reason) " +
            "micTrackSubscribed=\(isMicTrackSubscribed)"
        )
        startCallDurationTimer()
    }

    /// 只取消兜底定时器，保留 `didStartCallDurationTimer` 的一次性语义。
    private func invalidateCallDurationGateTimer() {
        AssertIsOnMainThread()
        guard let callDurationGateTimer else {
            return
        }

        callDurationGateTimer.invalidate()
        self.callDurationGateTimer = nil
    }

    /// 通话结束清理：连同一次性标记一起复位，下一通电话重新走门控。
    func stopCallDurationGate() {
        DispatchMainThreadSafe { [weak self] in
            self?.resetCallDurationGateOnMain()
        }
    }

    private func resetCallDurationGateOnMain() {
        AssertIsOnMainThread()
        invalidateCallDurationGateTimer()
        isCallDurationGateArmed = false
        didStartCallDurationTimer = false
        isMicTrackSubscribed = false
    }

    // MARK: remote 参会人断开连接
    func startParticipantDisTimer(onTimeout: @escaping () -> Void) {
        stopParticipantDisTimer()
        
        participantDisconnectCallback = onTimeout
        // 远程参会人断开连接时间统一改为60
        let interval: TimeInterval = 60
        participantDisTimer = Timer.weakTimer(
            withTimeInterval: interval,
            target: self,
            selector: #selector(participantDisconnectAction),
            userInfo: nil,
            repeats: false
        )
        
        if let participantDisTimer {
            RunLoop.current.add(participantDisTimer, forMode: .common)
        }
    }
    
    @objc
    private func participantDisconnectAction(_ timer: Timer) {
        participantDisconnectCallback?()
        participantDisconnectCallback = nil  // 避免循环引用
    }
    
    func stopParticipantDisTimer() {
        guard let participantDisTimer else {
            return
        }

        participantDisTimer.invalidate()
        self.participantDisTimer = nil
        participantDisconnectCallback = nil
    }

    // MARK: 被叫连接阶段兜底
    func startConnectionPhaseTimer() {
        stopConnectionPhaseTimer()

        let interval: TimeInterval = 45
        connectionPhaseTimer = Timer.weakTimer(
            withTimeInterval: interval,
            target: self,
            selector: #selector(connectionPhaseTimeoutAction),
            userInfo: nil,
            repeats: false
        )

        if let connectionPhaseTimer {
            RunLoop.current.add(connectionPhaseTimer, forMode: .common)
        }
    }

    @objc
    private func connectionPhaseTimeoutAction(_ timer: Timer) {
        guard hasMeeting, !inMeeting else { return }
        Logger.error("[newcall] connection phase timeout, hanging up")
        Task {
            await self.hangupCall(needSyncCallKit: true, isByLocal: true, showErrorToast: true)
        }
    }

    func stopConnectionPhaseTimer() {
        guard let connectionPhaseTimer else {
            return
        }

        connectionPhaseTimer.invalidate()
        self.connectionPhaseTimer = nil
    }
}
