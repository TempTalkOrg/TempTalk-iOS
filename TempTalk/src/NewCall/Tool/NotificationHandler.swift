//
//  NotificationHandler.swift
//  Difft
//
//  Created by Henry on 2025/5/20.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

class NotificationHandler {
    static let shared = NotificationHandler()

    func registerDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let notificationName = "com.temptalk.nseCallkitStop" as CFString

        CFNotificationCenterAddObserver(center,
                                        Unmanaged.passUnretained(self).toOpaque(), // 传递 self 的指针
                                        darwinCallback,
                                        notificationName,
                                        nil,
                                        .deliverImmediately)
    }

    // 真正的回调处理逻辑
    func handleDarwinNotification(name: CFString?) {
        if let roomId = UserDefaults.app().string(forKey: OWSPreferencesKeySystemEndCallKey) {
            Logger.info("[new call] receive background end call notification")
            if roomId == DTMeetingManager.shared.currentCall.roomId {
                Task {
                    Logger.info("[new call] receive background end othersideHungupCall")
                    await DTMeetingManager.shared.othersideHungupCall(roomId: roomId, isRemoveBar: true)
                }
            }
        }
    }
}

// 全局 C 风格回调函数（不能捕获 context，所以只传递 opaque pointer）
private let darwinCallback: CFNotificationCallback = { (_, observer, name, _, _) in
    if let observer = observer {
        let instance = Unmanaged<NotificationHandler>.fromOpaque(observer).takeUnretainedValue()
        instance.handleDarwinNotification(name: name?.rawValue)
    }
}
