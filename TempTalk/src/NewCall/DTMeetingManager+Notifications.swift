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

        // Observer for showing deferred rating when app enters foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Observer for showing deferred rating after screen unlock completes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLockDidUnlock),
            name: .ScreenLockDidUnlock,
            object: nil
        )
    }

    @objc func screenLockDidUnlock(_ notification: Notification) {
        // Show deferred rating after screen unlock
        guard hasPendingRating else { return }

        Logger.info("\(logTag) screenLockDidUnlock: showing deferred rating controller")

        // Small delay to ensure UI transition completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showDeferredRatingController()
        }
    }

    @objc func appDidBecomeActive(_ notification: Notification) {
        // Show deferred rating controller if pending
        // PanModal can't present properly in background, so we defer to foreground
        guard hasPendingRating else { return }

        Logger.info("\(logTag) appDidBecomeActive: has pending rating, will show after delay")

        // Delay to ensure UI is fully ready and screen unlock has completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showDeferredRatingController()
        }
    }

    private func showDeferredRatingController() {
        guard hasPendingRating else { return }

        // Check if screen lock is currently active (blocking window is above background level)
        // If so, don't show rating now - it will be shown when user unlocks
        let screenBlockingWindow = OWSScreenLockUI.sharedManager().screenBlockingWindow
        let isScreenLockActive = screenBlockingWindow.windowLevel > UIWindow.Level(rawValue: -1) // UIWindowLevel_Background = -1

        if isScreenLockActive {
            Logger.info("\(logTag) showDeferredRatingController: screen lock active, keeping pending")
            // Keep hasPendingRating = true, will retry when unlock completes
            return
        }

        hasPendingRating = false
        showRatingController()
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
            // 如果不是当前会议，仍然需要根据 roomId 移除对应的 join/meeting bar，防止 UI 残留
            handleMeetingBar(roomId: roomId, action: .remove)
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
    
    
    @objc public func handleRemoteCallNotify(apnsInfo: DTApnsInfo) {
        guard let callInfo = apnsInfo.passthroughInfo["callInfo"] as? [String: Any] else {
            return
        }

        let caller = callInfo["caller"] as? String
        let meetingName = callInfo["meetingName"] as? String
        let groupId = callInfo["groupId"] as? String
        let callType = callInfo["callType"] as? NSNumber
        let meetingId = callInfo["meetingId"] as? String
        
        let callModel = DTLiveKitCallModel()
        callModel.callState = .alerting
        callModel.caller = caller
        callModel.roomId = meetingId
        callModel.roomName = meetingName ?? ""
        callModel.callType = .instant
        if DTParamsUtils.validateString(groupId).boolValue {
            callModel.conversationId = groupId
            if callType == 1 {
                callModel.callType = .private
            } else if callType == 2 {
                callModel.callType = .group
            }
        }
        if let localNumber = TSAccountManager.localNumber(), callType == 1 {
            callModel.callees = [localNumber]
        }
        DTMeetingManager.shared.acceptCall(call: callModel)
    }
    
    public func criticalAlertIncomingLocalMessage(entity: DTServerNotifyCriticalAlertEntity,
                                                  transation: SDSAnyWriteTransaction) {
        // 转换参数
        let conversationId = entity.conversation
        let deviceId = UInt32(entity.sourceDevice)
        let ts = entity.timestamp
        let serverTs = entity.serverTimestamp
        let source = entity.source
        let showCriticalAlert = entity.showCriticalAlert

        func process(thread: TSThread) {
            Logger.info("[newCall] should show critical highlight showCriticalAlert \(showCriticalAlert)")
            if showCriticalAlert {
                // 添加高亮文本
                let timestampForSorting = serverTs > 0 ? serverTs : ts
                let messageId = "criticalAlert_\(conversationId)_\(timestampForSorting)"
                thread.updateCriticalAlertMsg(withMessageId: messageId, timestampForSorting: timestampForSorting, transaction: transation)
            }
            
            createCriticalAlertLocalMessage(thread: thread,
                                            contactId: source,
                                            sourceDeviceId: deviceId,
                                            timestamp: ts,
                                            serverTimestamp: serverTs,
                                            transation: transation)
        }
        
        if isGid(conversationId) {
            if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) {
                let groupThread = TSGroupThread.getOrCreateThread(withGroupId: localGroupId, transaction: transation)
                process(thread: groupThread)
            }
        } else {
            let contactThread = TSContactThread.getOrCreateThread(withContactId: conversationId, transaction: transation)
            process(thread: contactThread)
        }
    }
}
