//
//  DTMeetingManager+Hangup.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

// MARK: - Thin wrappers delegating to HangupCoordinator

extension DTMeetingManager {

    func transitionToDisconnecting() {
        let currentState = lifecycleState
        if currentState == .connected {
            tryTransition(from: .connected, to: .disconnecting)
        } else if currentState == .connecting {
            tryTransition(from: .connecting, to: .disconnecting)
        }
    }

    // MARK: - endCallAction (caller-side top-level exit)

    func endCallAction(forceEndGroupMeeting: Bool = false) async {
        Logger.info("Actively end the call")

        if currentCall.callType == .private, currentCall.isCaller, !inMeeting {
            await cancelLocalCall()
        } else {
            var roomId: String?
            if currentCall.callType == .private {
                roomId = currentCall.roomId
            } else if let roomContext, roomContext.room.remoteParticipants.isEmpty {
                roomId = currentCall.roomId
            }

            if let roomContext,
               roomContext.room.remoteParticipants.isEmpty,
               roomContext.room.connectionState == .connected
            {
                await hangupCall(needSyncCallKit: true,
                                 isByLocal: true,
                                 forceEndGroupMeeting: forceEndGroupMeeting,
                                 roomId: roomId)
                Logger.info("endcall need remove join")
            } else {
                await hangupCall(needSyncCallKit: true,
                                 isByLocal: true,
                                 forceEndGroupMeeting: forceEndGroupMeeting,
                                 roomId: currentCall.roomId)
                Logger.info("endcall hangup exception")
            }
        }
    }

    // MARK: - hangupCall

    func hangupCall(needSyncCallKit: Bool,
                    isByLocal: Bool = false,
                    forceEndGroupMeeting: Bool = false,
                    roomId: String? = nil,
                    showErrorToast: Bool = false,
                    isFromCallKit: Bool = false) async
    {
        guard (currentCall.isCaller && isByLocal) || !currentCall.isCaller else {
            Logger.error("\(logTag) hangup exception isByLocal:\(isByLocal)")
            hideToast()
            return
        }

        // roomId mismatch guard (non-CallKit: skip hangup for other meeting)
        if let roomId, !isFromCallKit, let currentRoomId = currentCall.roomId, roomId != currentRoomId {
            if currentCall.callType == .private || forceEndGroupMeeting {
                handleMeetingBar(roomId: roomId, action: .remove)
            }
            Logger.info("\(logTag) roomId != currentCall.roomId, skip hangup for other meeting. roomId: \(roomId), currentRoomId: \(currentRoomId)")
            hideToast()
            return
        }

        let reason: HangupReason = isByLocal ? .localHangup : .remoteHangup
        await hangupCoordinator.terminate(
            reason: reason,
            options: TerminationOptions(
                roomId: roomId,
                showErrorToast: showErrorToast,
                forceEndGroupMeeting: forceEndGroupMeeting,
                fromCallKit: isFromCallKit,
                needSyncCallKit: needSyncCallKit
            )
        )
    }

    // MARK: - meetingNotificationEndAllClearData

    func meetingNotificationEndAllClearData(roomId: String? = nil) async {
        Logger.info("\(logTag) meetingNotificationEndAllClearData trigger, current state: \(lifecycleState)")
        await hangupCoordinator.terminate(
            reason: .meetingEnded,
            options: TerminationOptions(roomId: roomId)
        )
        DispatchMainThreadSafe {
            TimerDataManager.shared.isShowCountDownView = false
        }
    }

    // MARK: - othersideHungupCall

    func othersideHungupCall(roomId: String) async {
        Logger.info("\(logTag) otherside HungupCall, current state: \(lifecycleState)")

        let wasInMeeting: Bool = {
            if currentCall.callType == .private {
                let remoteJoined = roomContext?.room.remoteParticipants.isEmpty == false
                let hasAnswered = currentCall.callState == .answering
                return lifecycleState == .connected || remoteJoined || hasAnswered
            } else {
                return lifecycleState == .connected || roomContext?.room.connectionState == .connected
            }
        }()

        await hangupCoordinator.terminate(
            reason: .remoteHangup,
            options: TerminationOptions(roomId: roomId)
        )

        if wasInMeeting {
            playSound(.callOff, isLoop: false, playMode: .playback)
        }
    }

    // MARK: - rejectRemoteCall

    func rejectRemoteCall() async {
        Logger.info("\(logTag) reject remote call, current state: \(lifecycleState)")
        await hangupCoordinator.terminate(reason: .localReject)
    }

    /// CallKit 拒接专用 — 静默拒绝第二个来电（假通话），不同步 CallKit 状态，避免误挂第一个通话
    func rejectIncomingCallSilently(with call: DTLiveKitCallModel) async {
        Logger.info("\(logTag) reject remote call (callkit) caller:\(call.caller ?? "") roomId:\(call.roomId ?? "")")
        await sendCallMessage(.reject, call)
    }

    // MARK: - localCallHaveBeenRejected

    func localCallHaveBeenRejected() async {
        Logger.info("\(logTag) reject localCall, current state: \(lifecycleState)")
        await hangupCoordinator.terminate(reason: .remoteReject)
    }

    // MARK: - cancelLocalCall

    func cancelLocalCall() async {
        Logger.info("\(logTag) cancel localCall, current state: \(lifecycleState)")
        await hangupCoordinator.terminate(reason: .localCancel)
    }

    // MARK: - joinedCall (unchanged)

    func joinedCall() async {
        await sendCallMessage(.joined)
        stopSound()
    }

    // MARK: - remoteCallHaveBeenCanceled

    func remoteCallHaveBeenCanceled() async {
        Logger.info("\(logTag) cancel remote call, current state: \(lifecycleState)")
        await hangupCoordinator.terminate(reason: .remoteCancel)
    }
}

// MARK: - Rating

extension DTMeetingManager {
    private enum RatingDisplayConfig {
        static let minimumMeetingDuration: TimeInterval = 60
    }

    func ensurePortraitOrientationBeforeShowingRating() {
        defer { self.lastMeetingDuration = nil }

        guard !hasTriggeredRating else {
            Logger.info("\(logTag) Rating already triggered, skipping")
            return
        }

        guard feedbackUserSid != nil else {
            Logger.info("\(logTag) Call never connected, skipping rating")
            return
        }

        guard meetsRatingDurationRequirement() else { return }

        let shouldShowRating = CallRatingTrigger.shared.shouldTriggerRating(hasSevereQualityIssue: feedbackIsNetworkPoor ?? false)
        if shouldShowRating {
            hasTriggeredRating = true
        }
    }

    private func meetsRatingDurationRequirement() -> Bool {
        guard let duration = lastMeetingDuration ?? currentCall.duration ?? TimerDataManager.shared.duration else {
            Logger.info("\(logTag) Missing duration data, skipping rating")
            return false
        }
        guard duration >= RatingDisplayConfig.minimumMeetingDuration else {
            Logger.info("\(logTag) Call duration \(duration)s shorter than minimum \(RatingDisplayConfig.minimumMeetingDuration)s, skipping rating")
            return false
        }
        return true
    }

    func showRatingController() {
        guard CurrentAppContext().isMainAppAndActive else {
            Logger.info("\(logTag) showRatingController: app not active, deferring to foreground")
            hasPendingRating = true
            return
        }

        let rootWindow = OWSWindowManager.shared().rootWindow
        let topVC = rootWindow.findTopViewController()
        Logger.info("\(self.logTag) ratingFeedbackController present from \(topVC)")

        DTRatingFeedbackController.present(from: topVC) { _ in
            Logger.info("\(self.logTag) ratingFeedbackController present success")
        }
    }

    func syncCallKitState(needSyncCallKit: Bool) {
        Logger.info("\(logTag) syncCallKitState needSyncCallKit: \(needSyncCallKit)")
        guard needSyncCallKit else { return }

        // Fallback to roomId lookup: for incoming calls not yet answered,
        // currentCall.callKitUUID is never bound (refreshCurrentCallStatus(.none) no-op),
        // so ask DTCallKitManager which UUID is active for this roomId.
        let ckManager = DTCallKitManager.shared()
        let resolvedUUID = currentCall.callKitUUID
            ?? currentCall.roomId.flatMap { ckManager.uuidString(fromRoomId: $0) }

        guard let callKitUUID = resolvedUUID else {
            Logger.warn("\(logTag) syncCallKitState no UUID, roomId: \(currentCall.roomId ?? "nil")")
            return
        }

        // Inline call: already on @MainActor; avoid Task hop so endCallAction
        // runs synchronously inside phase6 before phase7 cleanup proceeds.
        Logger.info("\(logTag) syncCallKitState uuid: \(callKitUUID)")
        ckManager.endCallAction(callKitUUID, onlyForCallKit: true)
    }

    // Single owner of CallKit-ring dismissal, keyed on the stable roomId (not currentCall). Idempotent.
    func endCallKitRing(roomId: String) {
        guard !roomId.isEmpty else { return }
        let ckManager = DTCallKitManager.shared()
        guard let uuidString = ckManager.uuidString(fromRoomId: roomId) else { return }
        ckManager.endCallAction(uuidString, onlyForCallKit: true)
    }
}

// MARK: - Call window management

extension DTMeetingManager {
    @MainActor
    public func removeCallWindow() async {
        await dismissPresentedCallControllersIfNeeded()
        removeFloatingView()
        let rootWindow = OWSWindowManager.shared().rootWindow
        callAlertManager.cleanStaleAlertCalls()
        callAlertManager.bringLiveKitAlertCalls(to: rootWindow)
        await OWSWindowManager.shared().endCall(nil)
        answerVC = nil
        deferredIncomingCall = nil
        dismissIncomingCallBanner()
    }

    @MainActor
    private func dismissPresentedCallControllersIfNeeded() async {
        let callWindow = OWSWindowManager.shared().callViewWindow
        guard let rootVC = callWindow.rootViewController,
              rootVC.presentedViewController != nil else { return }

        rootVC.presentedViewController?.view.endEditing(true)

        await withCheckedContinuation { continuation in
            rootVC.dismiss(animated: false) {
                continuation.resume()
            }
        }
    }

    @MainActor
    func removeFloatingView() {
        if floatingView.superview != nil {
            floatingView.removeFromSuperview()
        }
    }

    static func checkRoomIdValid(_ roomId: String) async -> (anotherDeviceJoined: Bool, userStopped: Bool)? {
        await DTCallAPIManager().checkRoomIdValid(roomId)
    }

    private func hideToast() {
        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
}
