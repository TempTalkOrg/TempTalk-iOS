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
        
        if currentCall.isCaller {
            DTToastHelper.showCallToast(Localized("SINGLE_CALL_TIMEOUT"))
        }
        
        Task {
            Logger.info("\(logTag) call timeout need remoteCallHaveBeenCanceled")
            await remoteCallHaveBeenCanceled()
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
        guard inMeeting else {
            return
        }
        
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
            TimerDataManager.shared.duration = 1
        }
        guard let callDurationTimer else {
            return
        }
        
        callDurationTimer.invalidate()
        self.callDurationTimer = nil
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
}
