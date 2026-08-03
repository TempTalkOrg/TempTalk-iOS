//
//  DTMeetingManager+Notifications.swift
//  TempTalk
//
//  Created by Ethan on 11/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidTakeScreenshotInMeeting(_:)),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    /// Full-screen meeting screenshots: route to the call's conversation. Instant call has none, so skip.
    /// Minimized meetings are handled by the visible ConversationViewController.
    @objc func userDidTakeScreenshotInMeeting(_ notification: Notification) {
        guard hasMeeting else { return }
        // Minimized meeting is handled by the visible ConversationViewController.
        guard !isMinimize else { return }
        guard !OWSScreenLockUI.sharedManager().isShowingScreenLockUI else {
            Logger.info("\(logTag) screenshot while screen lock is showing, ignoring")
            return
        }

        let call = currentCall
        Logger.info("\(logTag) screenshot in meeting. callType=\(call.callType.rawValue), conversationId=\(call.conversationId ?? "nil"), isMinimize=\(isMinimize)")

        guard let conversationId = call.conversationId, !conversationId.isEmpty else {
            Logger.info("\(logTag) screenshot during instant call, skip sending system message")
            return
        }

        var targetThread: TSThread?
        SDSDatabaseStorage.shared.read { transaction in
            if call.callType == .private {
                targetThread = TSContactThread.getThread(contactId: conversationId, transaction: transaction)
            } else if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) {
                targetThread = TSGroupThread.getWithGroupId(localGroupId, transaction: transaction)
            }
        }

        guard let targetThread else {
            Logger.info("\(logTag) screenshot in meeting but thread not found for \(conversationId), skip")
            return
        }

        Logger.info("\(logTag) screenshot in meeting, send system message to \(targetThread.uniqueId)")
        ThreadUtil.sendScreenShotMessage(in: targetThread) {} failure: { _ in }
    }

    @objc func screenLockDidUnlock(_ notification: Notification) {
        // If the call was minimized while the screen was locked, the floating pill was
        // attached to a hidden root window and won't be visible after unlock. Re-attach
        // it to the now-visible root window. Deferred to the next runloop so it runs
        // after the root window has been shown and its root VC laid out.
        if hasMeeting, isMinimize {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.hasMeeting, self.isMinimize else { return }
                Logger.info("\(self.logTag) screenLockDidUnlock: re-attaching floating call pill to root window")
                OWSWindowManager.shared().showFloatingCall(self.floatingView)
            }
        }

        // Show deferred rating after screen unlock
        guard hasPendingRating else { return }

        Logger.info("\(logTag) screenLockDidUnlock: showing deferred rating controller")

        // Small delay to ensure UI transition completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showDeferredRatingController()
        }
    }

    @objc func appWillResignActive(_ notification: Notification) {
        guard hasMeeting else { return }
        suspendAutoLeaveForBackground()
    }

    @objc func appDidBecomeActive(_ notification: Notification) {
        // 恢复自动离会检测（sourceTimer 在后台已暂停，需要重新开始）
        resumeAutoLeaveIfNeeded()

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

        // 主线程 Thread.sleep 会阻塞 MainActor 调度，导致 Task 内的 await MainActor.run 永远无法执行。
        // 用 RunLoop + DispatchGroup 轮转等待：既给 Task 跑完的机会，也有 3 秒硬超时保护，
        // 避免超过 iOS willTerminate 窗口（约 5 秒）被强杀。
        let done = DispatchGroup()
        done.enter()
        Task { [weak self] in
            defer { done.leave() }
            guard let self else { return }
            await self.roomContext?.disconnect()
            if self.hasMeeting {
                Logger.info("\(self.logTag) hangup app Will Terminate")
                await self.hangupCoordinator.terminate(reason: .appWillTerminate)
            }
        }

        let deadline = Date(timeIntervalSinceNow: 3)
        while done.wait(timeout: .now() + 0.05) == .timedOut {
            if Date() >= deadline {
                Logger.warn("\(logTag) appWillTerminate: cleanup timed out after 3s")
                break
            }
            // Pumping the run loop may run leftover UIKit teardown work, which can
            // raise NSException on iOS 26. We're terminating anyway — catch and stop.
            do {
                try DTExceptionCatcher.catchException {
                    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
                }
            } catch {
                Logger.error("\(logTag) appWillTerminate: exception while pumping run loop: \(error)")
                break
            }
        }
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
        let fallbackRoomName = meetingName ?? ""
        callModel.roomName = fallbackRoomName
        callModel.callType = .instant
        if DTParamsUtils.validateString(groupId).boolValue {
            callModel.conversationId = groupId
            if callType == 1 {
                callModel.callType = .private
            } else if callType == 2 {
                callModel.callType = .group
                SDSDatabaseStorage.shared.read { tx in
                    callModel.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: groupId,
                        fallbackName: fallbackRoomName,
                        transaction: tx)
                }
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
