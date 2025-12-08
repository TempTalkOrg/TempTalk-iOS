//
//  DTMeetingManager+Clean.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

extension DTMeetingManager {
    /// 执行完整的资源清理，确保所有资源被正确释放
    func performCompleteCleanup() {
        Logger.info("\(logTag) Starting complete cleanup")
        stopSound()
        audioPlayer = nil
        
        Task { [weak self] in
            guard let self = self else { return }
            if let roomContext = self.roomContext {
                await roomContext.disconnect()
            }
        }

        appContext = nil
        roomContext = nil

        clearCurrentCall()

        removeCallWindow()
        hostRoomContentVC = nil

        isMinimize = false
        showErrorTost = false
        otherCriticalAlert = false
        hasTriggeredRating = false

        DispatchMainThreadSafe {
            UIDevice.current.isProximityMonitoringEnabled = false
        }
        
        Logger.info("\(logTag) Complete cleanup finished")
    }
    
    func clearCurrentCall(roomId: String? = nil) {
        Logger.info("\(self.logTag) clear current call room data nil")
        if currentCall.callType != .private {
            NotificationCenter.default.postNotificationNameAsync(
                DTStickMeetingManager.kMeetingDurationUpdateNotification,
                object: nil
            )
        }
        
        if let rid = currentCall.roomId {
            Logger.info("\(self.logTag) clear lcoal message condition")
            handleMeetingEnded(meetingID: rid)
        }
        
        currentCall.isPresentedShare = false
        currentCall = DTLiveKitCallModel()
        inMeeting = false
        hasMeeting = false
        isAnswering = false
        
        visibleParticipants.removeAll()
        startCallThread = nil
        startCallRecipientIds = nil
        fromSource = nil
        answerVC = nil
        releaseAllTimer()
        stopCheckTalking()
        TimerDataManager.shared.clearTimerDataSource()
        RoomDataManager.shared.clearRoomDataSource()
        videoViewPool.removeAll()
        currentlyDisplayedIdentity = nil
        currentlyDisplayedSid = nil
        currentlyCameraEnabled = false
        DTCallKitManager.shared().isLocalEndCall = false
    }
}
