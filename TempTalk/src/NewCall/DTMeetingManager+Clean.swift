//
//  DTMeetingManager+Clean.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

extension DTMeetingManager {
    
    @MainActor
    func performCompleteCleanup(roomContextToClean: RoomContext? = nil) async {
        Logger.info("\(logTag) Starting complete cleanup, current state: \(lifecycleState)")

        let contextToDisconnect = roomContextToClean ?? self.roomContext

        // 判断是否应该执行完整清理：
        let shouldPerformFullCleanup = roomContextToClean == nil || self.roomContext === contextToDisconnect

        // 无论如何都要断开旧的连接
        if let contextToDisconnect {
            await contextToDisconnect.disconnect()
        }

        if shouldPerformFullCleanup {
            // 执行完整清理
            stopSound()
            audioPlayer = nil
            currentCall.isPresentedShare = false

            // 重要：必须先清理视图层次结构，再释放 roomContext
            dismissAutoLeaveTipView()
            clearCurrentCall()
            await removeCallWindow()
            hostRoomContentVC = nil

            appContext = nil
            roomContext = nil
            Logger.info("\(logTag) roomContext cleaned up")

            isMinimize = false
            showErrorTost = false
            otherCriticalAlert = false
            openCallCamera = false

            UIDevice.current.isProximityMonitoringEnabled = false

            // 完整清理后转到 idle 状态
            forceTransition(to: .idle)
            Logger.info("\(logTag) Complete cleanup finished, final state: \(lifecycleState)")
        } else {
            // 说明已经有新的 roomContext 被创建
            // 旧连接已断开，但需要确保旧的资源不会干扰新呼叫
            Logger.error("\(logTag) New call in progress, skipped full cleanup. This is unexpected - check call flow. current state: \(lifecycleState)")
        }
    }
    
    /// 清理当前通话的数据
    func clearCurrentCall(roomId: String? = nil) {
        Logger.info("\(self.logTag) clearCurrentCall, current state: \(lifecycleState)")

        if currentCall.callType != .private {
            NotificationCenter.default.postNotificationNameAsync(
                DTStickMeetingManager.kMeetingDurationUpdateNotification,
                object: nil
            )
        }

        if let rid = currentCall.roomId {
            Logger.info("\(self.logTag) clear local message condition")
            handleMeetingEnded(meetingID: rid)
        }

        // 重置 currentCall 数据
        currentCall.isPresentedShare = false
        currentCall = DTLiveKitCallModel()

        // 重置控制标志
        isAnswering = false

        // 清理参会人相关数据
        isFromCallkit = false
        
        visibleParticipants.removeAll()
        startCallThread = nil
        startCallRecipientIds = nil
        fromSource = nil
        answerVC = nil

        // 释放定时器
        releaseAllTimer()
        stopCheckTalking()

        // 清理数据管理器
        TimerDataManager.shared.clearTimerDataSource()
        RoomDataManager.shared.clearRoomDataSource()

        // 清理视频相关
        videoViewPool.removeAll()
        currentlyDisplayedIdentity = nil
        currentlyDisplayedSid = nil
        currentlyCameraEnabled = false

        // 清理缓存状态
        reconnectingParticipants = nil
        lastParticipantsCount = 0

        // 重置 CallKit 状态
        DTCallKitManager.shared().isLocalEndCall = false
    }
}
