//
//  DTMeetingManager+AutoLeave.swift
//  TempTalk
//
//  Created by Henry on 2025/3/21.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

extension DTMeetingManager {
    //处理会话弹窗逻辑
    func currentCallTalkingPop() {
        if checkCloseAutoLeaveTimer() {
            //如果有弹窗，弹窗就取消掉
            Task { @MainActor in
                self.dismissAutoLeaveTipView()
            }
            //有人在会 重置 倒计时等数据
            stopCheckTalking()
        } else {
            // 开始倒计时
            sourceTimer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.call.timerQueue"))
            sourceTimer?.schedule(deadline: .now(), repeating: 1)
            sourceTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                DTMeetingManager.countDownInterval += 1
                if DTMeetingManager.countDownInterval > self.meetingTimeoutResult {
                    //超过时间展示弹窗
                    Task { @MainActor in
                        self.showAutoLeaveTipView(self.checkSoloMember())
                    }
                    self.stopCheckTalking()
                }
            }
            sourceTimer?.resume()
        }
    }
    
    func stopCheckTalking() {
        timerLock.lock()
        defer { timerLock.unlock() }
        DTMeetingManager.countDownInterval = 0
        guard let timer = sourceTimer else { return }
        sourceTimer = nil
        timer.setEventHandler {}
        timer.cancel()
    }
    
    // 检测当前 call 中是否有认在说话
    func checkCloseAutoLeaveTimer() -> Bool {
        // 如果有人数变化的话都要取消一次定时器
        if checkUpdateParticipantsCount() {
            Logger.info("\(logTag) auto leave meeting Participants change")
            Task { @MainActor in
                self.dismissAutoLeaveTipView()
            }
            stopCheckTalking()
        }
        var closeTimer = false
        //1) Speaking优先级最低
        //多人会议的远程参与者
        if let participants = roomContext?.room.remoteParticipants {
            for (_, participant) in participants {
                //是否开关麦
                if participant.isSpeaking {
                    closeTimer = true
                    break
                }
                //开麦是否有音量
                if participant.audioLevel > 0.125 {
                    closeTimer = true
                    break
                }
            }
        }
        //多人会议的本人参与者
        if let localParticipant = roomContext?.room.localParticipant {
            //是否开关麦
            if localParticipant.isSpeaking {
                closeTimer = true
            }
            //开麦是否有音量
            if localParticipant.audioLevel > 0.125 {
                closeTimer = true
            }
        }
        
        //2）如果是一个人的话，不管开不开麦都关
        if checkSoloMember() {
            closeTimer = false
        }
        
        return closeTimer
    }
    
    func checkSoloMember() -> Bool {
        return roomContext?.room.remoteParticipants.count == 0
    }
    
    func checkUpdateParticipantsCount() -> Bool {
        guard let roomContext else {
            return false
        }
        if roomContext.room.allParticipants.count != self.lastParticipantsCount {
            self.lastParticipantsCount = Int32(roomContext.room.allParticipants.count)
            return true
        }
        return false
    }
    
    //MARK: global config
    func banMicCountdownDuration() -> Int {
        let callConfig = CallConfigManager.fetchCallConfig()
        let timeoutResult = checkSoloMember() ? callConfig.soloMemberTimeoutResult : callConfig.silenceTimeoutResult
        return timeoutResult / 1000
    }

    func banMicAlertCountdownDuration() -> Int {
        let callConfig = CallConfigManager.fetchCallConfig()
        return callConfig.runAfterReminderTimeoutResult / 1000
    }

    // MARK: - Background Lifecycle

    func suspendAutoLeaveForBackground() {
        Logger.info("\(logTag) suspending auto-leave for background")
        stopCheckTalking()
        Task { @MainActor in
            self.dismissAutoLeaveTipView()
        }
    }

    func resumeAutoLeaveIfNeeded() {
        guard hasMeeting, roomContext != nil else { return }
        Logger.info("\(logTag) resuming auto-leave check after foreground")
        currentCallTalkingPop()
    }

    // MARK: - Auto Leave Tip View

    @MainActor
    func showAutoLeaveTipView(_ isSoloMember: Bool) {
        guard !hasShowLeaveTipView else { return }
        guard CurrentAppContext().isMainAppAndActive else {
            Logger.info("\(logTag) skip showing auto-leave tip view in background")
            return
        }

        let tipView = DTAutoLeaveTipView(confirmBlock: { [weak self] in
            guard let self else { return }
            self.autoLeaveTipView?.removeFromSuperview()
            self.hasShowLeaveTipView = false
            self.autoLeaveTipView?.stopTimeoutTimer()
            self.autoLeaveTipView = nil
            self.stopCheckTalking()
            self.currentCallTalkingPop()
            if self.currentCall.callType == .private {
                Task { [weak self] in
                    await self?.sendRemoteSyncContinueStatus()
                }
            }
        }, timeoutBlock: { [weak self] in
            guard let self else { return }
            self.autoLeaveTipView?.removeFromSuperview()
            self.hasShowLeaveTipView = false
            self.autoLeaveTipView?.stopTimeoutTimer()
            self.autoLeaveTipView = nil
            self.stopCheckTalking()
            Task { [weak self] in
                guard let self else { return }
                Logger.info("\(self.logTag) hangup auto leave meeting")
                await self.hangupCall(needSyncCallKit: true, isByLocal: true)
            }
        })

        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()

        tipView.frame = topVC.view.bounds
        tipView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tipView.updateTipsLabel(isSoloMember)
        tipView.startTimeoutTimer(UInt(reminderTimeoutResult))
        topVC.view.addSubview(tipView)

        self.autoLeaveTipView = tipView
        hasShowLeaveTipView = true
    }

    @MainActor
    func dismissAutoLeaveTipView() {
        guard hasShowLeaveTipView else { return }
        autoLeaveTipView?.stopTimeoutTimer()
        autoLeaveTipView?.removeFromSuperview()
        autoLeaveTipView = nil
        hasShowLeaveTipView = false
    }
}
