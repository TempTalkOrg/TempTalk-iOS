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
                self.hostRoomContentVC?.dismissAutoLipView()
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
                        self.hostRoomContentVC?.showAutoLipView(self.checkSoloMember())
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
                self.hostRoomContentVC?.dismissAutoLipView()
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
        var timeoutResult = 300000
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                timeoutResult = 300000
                return
            }
            if self.checkSoloMember() {
                timeoutResult = callConfig.soloMemberTimeoutResult ?? 300000
            } else {
                timeoutResult = callConfig.silenceTimeoutResult ?? 300000
            }
        }
        return timeoutResult / 1000
    }
    
    func banMicAlertCountdownDuration() -> Int {
        var runAfterReminderTimeoutResult = 180000
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, _ in
            guard let raw = config as? [String: Any],
                  let callConfig = CallConfig(from: raw) else {
                runAfterReminderTimeoutResult = 180000
                return
            }
            runAfterReminderTimeoutResult = callConfig.runAfterReminderTimeoutResult ?? 180000
        }
        return Int(runAfterReminderTimeoutResult / 1000)
    }
}
