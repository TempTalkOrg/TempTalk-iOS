//
//  DTMeetingManager+Notifications.swift
//  TempTalk
//
//  Created by Ethan on 11/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

extension DTMeetingManager {
    
    func registerNotifications() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveCallEndNotify),
            name: .notifyCallEnd,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
    }
    
    // 1on1 | instant | group 兜底方案
    @objc func didReceiveCallEndNotify(_ notification: Notification) {
      
        guard let userInfo = notification.userInfo else { return }
        guard let roomId = userInfo[NotifyCallEndRoomIdKey] as? String else {
            return
        }
        Logger.info("\(logTag) didReceiveCallEndNotify roomId")
        //当前主call未退出
        if roomId == currentCall.roomId {
            Task {
                Logger.info("\(logTag) hangup Receive CallEnd Notify")
                await meetingNotificationEndAllClearData(roomId: roomId)
            }
        } else {
            callAlertManager.removeLiveKitAlertCall(roomId)
        }
        
        Task {
            // 这个通知会同时发给客户端和服务端，有概率服务端没删干净，就一句请求获取list
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            // 如果收到结束的通知的时候刷新一次首页列表
            DTMeetingManager.shared.syncServerCalls()
        }
    }
    
    @objc func appWillTerminate(_ noti: Notification) {
       
        guard hasMeeting || !allMeetings.isEmpty else {
            return
        }
        
        Task {
            await roomContext?.disconnect()
            if hasMeeting {
                Logger.info("\(logTag) hangup app Will Terminate")
                await hangupCall(needSyncCallKit: true,
                                 isByLocal: true)
            }
        }
        
        Thread.sleep(forTimeInterval: 3)
    }
    
}
