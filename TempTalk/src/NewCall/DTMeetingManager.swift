//
//  DTMeetingManager.swift
//  Signal
//
//  Created by Ethan on 25/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Combine
import TTServiceKit
import TTMessaging
import SwiftUI
import LiveKit
import DTProto

@objcMembers open class DTMeetingManager: NSObject, ObservableObject, DTMeetingManagerProtocol, DTCallKitManagerDelegate {
    
    open override var logTag: String { "[newcall]" }
    
    static let shared = DTMeetingManager()
    static let meetingVersion: Int32 = 10
    static let sourceControlStart: String = "start-call"
    static let sourceControlInvite: String = "invite-members"

    /// Tracks whether a voice message is actively being recorded.
    /// Set by ConversationViewController when recording starts/stops.
    static var isVoiceRecordingActive: Bool = false
    
    let contactsManager: OWSContactsManager = Environment.shared.contactsManager
    let callAlertManager: DTAlertCallViewManager = DTAlertCallViewManager.shared()
    //自动退出会议的定时器
    var sourceTimer: DispatchSourceTimer?
    static var countDownInterval: Int32 = 0;
    var hostRoomContentVC: DTHostingController<AnyView>?
    var lastParticipantsCount: Int32 = 0;
    var autoLeaveTipView: DTAutoLeaveTipView?
    var hasShowLeaveTipView: Bool = false
    // Timer
    var callTimeoutTimer: Timer?
    var callDurationTimer: Timer?
    var participantDisTimer: Timer?
    var connectionPhaseTimer: Timer?
    
    // 会议的model
    lazy var currentCall: DTLiveKitCallModel = DTLiveKitCallModel()
    // 排序八宫格参会人。写入必须走 `setVisibleParticipants(_:)`，以保证主线程串行化。
    var visibleParticipants: [Participant] = []
    // `scheduleVisibleParticipantsUpdate(_:)` 用于合并同一帧内的多次异步 commit，避免 SwiftUI body 重入时反复触发 state 更新。
    var isVisibleParticipantsUpdateScheduled: Bool = false
    // 自动退回的保护锁
    let timerLock = NSLock()
    // livesdk的错误状态
    var showErrorToast: Bool = false
    // answer的视图
    var answerVC: DTHostingController<CallAnswerView>?
    // 录音中来电时的顶部横幅 window
    var incomingCallBannerWindow: UIWindow?
    // 录音结束后需要展示的来电信息
    var deferredIncomingCall: (call: DTLiveKitCallModel, caller: String, roomId: String, publicKey: Data, emk: Data)?
    var voiceRecordingEndObserver: NSObjectProtocol?
    // startcall 优化
    var startCallThread: TSThread?
    // startcall 优化
    var startCallRecipientIds: [String]? = nil
    // 区分start还是accept
    var fromSource: String?
    // 1v1的另一端是否开启CriticalAlert
    var otherCriticalAlert: Bool = false
    // 是否开启摄像头
    var openCallCamera: Bool = false
    // 是否来自于callkit
    var isFromCallkit: Bool = false
    /// roomIds rejected via CallKit before handleCallingMessage could process them.
    /// Prevents the incoming-call UI from appearing after the user already declined via the lock-screen.
    /// Lock-protected: writes from CallKit delegate thread, reads from message-handling Task.
    private let callKitRejectedRoomIdsLock = NSLock()
    private var _callKitRejectedRoomIds: Set<String> = []

    /// CallKit mute-echo suppression window.
    ///
    /// Under `.voiceProcessing`, muting/unmuting toggles the real VPIO hardware
    /// mic. iOS mirrors that state back into CallKit and dispatches
    /// `performSetMutedCallAction`. When the app itself drives the mic (join
    /// auto-mute, in-app mic toggle), those echoes are not user intent — honoring
    /// them creates a CallKit<->LiveKit feedback loop (mic flapping / joining
    /// unmuted). We ignore CallKit mute actions for a short window after any
    /// app-initiated mic change.
    private let callKitMuteSuppressLock = NSLock()
    private var _callKitMuteSuppressUntil: Date?
    private var _callKitMuteSuppressionTarget: Bool?
    private var _pendingCallKitMuteState: Bool?
    /// True while a single post-reconnect replay waiter is running. Accessed only
    /// on the main actor. Prevents spawning duplicate waiters when intent is
    /// parked repeatedly during one reconnect/republish window.
    private var _isCallKitMuteReplayWaiterArmed = false
    private var _isReconnectStateCleanupWaiterArmed = false
    private var _isCurrentCallKitAudioSessionActive = false
    private var _initialRoomAudioSetupExpectedCallKitEchoMuted: Bool?
    private var _initialRoomAudioSetupOppositeCallKitMuteCandidate: Bool?
    /// Set for the entire duration of a muted in-call voice-message recording.
    /// `startLocalRecording()` keeps the VPIO mic active so our own tap can
    /// capture, which iOS mirrors back as CallKit mute echoes; we must not let
    /// those unmute LiveKit for the whole (variable-length) recording.
    private var _isInCallLocalRecordingActive = false

    /// Suppress CallKit-driven mute changes for `duration` seconds. When
    /// `mutedTarget` is set, only the matching CallKit echo is suppressed.
    func beginCallKitMuteSuppression(_ duration: TimeInterval, mutedTarget: Bool? = nil) {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        let until = Date().addingTimeInterval(duration)
        if let existing = _callKitMuteSuppressUntil, existing > until { return }
        _callKitMuteSuppressUntil = until
        _callKitMuteSuppressionTarget = mutedTarget
    }

    /// During initial room audio setup, the app may start or stop the mic before
    /// the user's CallKit intent can be applied. iOS can mirror that app-side
    /// hardware change back as one `performSetMutedCallAction`; consume exactly
    /// that expected echo so it does not overwrite the queued user intent.
    func armInitialRoomAudioSetupCallKitEchoGuard(expectedMuted muted: Bool, reason: String) {
        callKitMuteSuppressLock.lock()
        _initialRoomAudioSetupExpectedCallKitEchoMuted = muted
        _initialRoomAudioSetupOppositeCallKitMuteCandidate = nil
        callKitMuteSuppressLock.unlock()
        Logger.debug("\(logTag) CallKit mute echo guard armed: muted=\(muted), reason=\(reason)")
    }

    func clearInitialRoomAudioSetupCallKitEchoGuard(reason: String) {
        callKitMuteSuppressLock.lock()
        let hadExpectedEcho = _initialRoomAudioSetupExpectedCallKitEchoMuted != nil
        let oppositeCandidate = _initialRoomAudioSetupOppositeCallKitMuteCandidate
        _initialRoomAudioSetupExpectedCallKitEchoMuted = nil
        _initialRoomAudioSetupOppositeCallKitMuteCandidate = nil
        callKitMuteSuppressLock.unlock()
        if let oppositeCandidate {
            Logger.info("\(logTag) CallKit mute candidate promoted: muted=\(oppositeCandidate), reason=\(reason)")
            setPendingCallKitMuteState(oppositeCandidate, reason: "CallKit mute candidate during initial room audio setup")
            return
        }
        if hadExpectedEcho {
            Logger.debug("\(logTag) CallKit mute echo guard cleared: reason=\(reason)")
        }
    }

    private func consumeInitialRoomAudioSetupCallKitEchoIfMatched(_ muted: Bool) -> Bool {
        callKitMuteSuppressLock.lock()
        guard _initialRoomAudioSetupExpectedCallKitEchoMuted == muted else {
            callKitMuteSuppressLock.unlock()
            return false
        }
        _initialRoomAudioSetupExpectedCallKitEchoMuted = nil
        let oppositeCandidate = _initialRoomAudioSetupOppositeCallKitMuteCandidate
        _initialRoomAudioSetupOppositeCallKitMuteCandidate = nil
        callKitMuteSuppressLock.unlock()
        Logger.info("\(logTag) CallKit mute echo ignored: muted=\(muted), scope=initial-audio-setup")
        if let oppositeCandidate {
            Logger.info("\(logTag) CallKit mute candidate discarded: muted=\(oppositeCandidate), matchedExpected=\(muted)")
        }
        return true
    }

    private func deferInitialRoomAudioSetupCallKitOppositeEchoIfNeeded(_ muted: Bool) -> Bool {
        callKitMuteSuppressLock.lock()
        guard let expected = _initialRoomAudioSetupExpectedCallKitEchoMuted, expected != muted else {
            callKitMuteSuppressLock.unlock()
            return false
        }
        let previousCandidate = _initialRoomAudioSetupOppositeCallKitMuteCandidate
        _initialRoomAudioSetupOppositeCallKitMuteCandidate = muted
        callKitMuteSuppressLock.unlock()
        if previousCandidate != Optional(muted) {
            Logger.info("\(logTag) CallKit mute candidate deferred: muted=\(muted), expected=\(expected), scope=initial-audio-setup")
        }
        return true
    }

    /// Keep only a short tail of an existing suppression window. The initial
    /// group-mute path needs a long window while LiveKit/ADM starts, but keeping
    /// it after setup completes can swallow real CallKit button taps.
    func shortenCallKitMuteSuppressionTail(_ duration: TimeInterval, mutedTarget: Bool? = nil, reason: String) {
        callKitMuteSuppressLock.lock()
        guard _callKitMuteSuppressUntil != nil else {
            callKitMuteSuppressLock.unlock()
            return
        }
        _callKitMuteSuppressUntil = Date().addingTimeInterval(duration)
        _callKitMuteSuppressionTarget = mutedTarget
        callKitMuteSuppressLock.unlock()
        Logger.info("\(logTag) CallKit mute suppression shortened: duration=\(duration), target=\(String(describing: mutedTarget)), reason=\(reason)")
    }

    /// Suppress CallKit-driven mute changes for as long as a muted in-call voice
    /// recording is running.
    func setInCallLocalRecordingActive(_ active: Bool) {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        _isInCallLocalRecordingActive = active
    }

    private func currentCallKitMuteSuppression() -> (isSuppressed: Bool, mutedTarget: Bool?) {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        if _isInCallLocalRecordingActive { return (true, nil) }
        guard let until = _callKitMuteSuppressUntil else { return (false, nil) }
        if Date() >= until {
            _callKitMuteSuppressUntil = nil
            _callKitMuteSuppressionTarget = nil
            return (false, nil)
        }
        return (true, _callKitMuteSuppressionTarget)
    }

    func pendingCallKitMuteState() -> Bool? {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        return _pendingCallKitMuteState
    }

    private func setPendingCallKitMuteState(_ muted: Bool, reason: String) {
        callKitMuteSuppressLock.lock()
        if _pendingCallKitMuteState == muted {
            callKitMuteSuppressLock.unlock()
            return
        }
        _pendingCallKitMuteState = muted
        callKitMuteSuppressLock.unlock()
        Logger.info("\(logTag) CallKit mute intent queued: muted=\(muted), reason=\(reason)")
    }

    func seedPendingCallKitMuteIntentIfAvailable(uuidString: String?, reason: String) {
        guard let uuidString,
              let muted = DTCallKitManager.shared().callKitMuteIntent(forUUID: uuidString)?.boolValue else {
            return
        }
        setPendingCallKitMuteState(muted, reason: reason)
    }

    private func consumePendingCallKitMuteState() -> Bool? {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        let muted = _pendingCallKitMuteState
        _pendingCallKitMuteState = nil
        return muted
    }

    @discardableResult
    func consumePendingCallKitMuteStateIfMatched(_ muted: Bool, reason: String) -> Bool {
        callKitMuteSuppressLock.lock()
        guard _pendingCallKitMuteState == muted else {
            callKitMuteSuppressLock.unlock()
            return false
        }
        _pendingCallKitMuteState = nil
        callKitMuteSuppressLock.unlock()
        Logger.info("\(logTag) CallKit mute intent consumed: muted=\(muted), reason=\(reason)")
        return true
    }

    private func clearPendingCallKitAudioState(reason: String) {
        callKitMuteSuppressLock.lock()
        let hadPendingState = _pendingCallKitMuteState != nil ||
            _callKitMuteSuppressionTarget != nil ||
            _initialRoomAudioSetupExpectedCallKitEchoMuted != nil ||
            _initialRoomAudioSetupOppositeCallKitMuteCandidate != nil ||
            _isCurrentCallKitAudioSessionActive
        _pendingCallKitMuteState = nil
        _callKitMuteSuppressionTarget = nil
        _initialRoomAudioSetupExpectedCallKitEchoMuted = nil
        _initialRoomAudioSetupOppositeCallKitMuteCandidate = nil
        _isCurrentCallKitAudioSessionActive = false
        callKitMuteSuppressLock.unlock()
        if hadPendingState {
            Logger.info("\(logTag) CallKit audio pending state cleared: reason=\(reason)")
        }
    }

    private var isCurrentCallKitAudioSessionActive: Bool {
        callKitMuteSuppressLock.lock()
        defer { callKitMuteSuppressLock.unlock() }
        return _isCurrentCallKitAudioSessionActive
    }

    private func markCurrentCallKitAudioSessionActive() {
        callKitMuteSuppressLock.lock()
        _isCurrentCallKitAudioSessionActive = true
        callKitMuteSuppressLock.unlock()
    }

    @MainActor
    func deferMicrophoneChangeIfConnecting(enable: Bool, reason: String) -> Bool {
        guard shouldDeferMicrophoneChangeForCallKit else { return false }
        setPendingCallKitMuteState(!enable, reason: reason)
        // If we parked because a reconnect/republish is in flight, ensure a
        // replay waiter exists. `didCompleteReconnect` may have already fired
        // (with nothing pending) before this intent arrived, so there would
        // otherwise be no trigger to re-apply it once the window closes.
        if isReconnectingOrRepublishingTracks {
            armCallKitMuteReplayWaiter(reason: reason)
        }
        return true
    }

    @MainActor
    private var shouldDeferMicrophoneChangeForCallKit: Bool {
        // Queue CallKit intent until the audio setup task starts applying local
        // audio state. During that applying phase, LiveKit/ADM can emit
        // indistinguishable prewarm mute echoes that must remain suppressed.
        let isWaitingForInitialRoomAudioSetup = isFromCallkit &&
            roomContext?.didCompleteInitialRoomAudioSetup == false &&
            roomContext?.isApplyingInitialRoomAudioSetup != true

        return lifecycleState == .connecting ||
            roomContext?.room.connectionState != .connected ||
            (isFromCallkit && !isCurrentCallKitAudioSessionActive) ||
            isWaitingForInitialRoomAudioSetup ||
            isReconnectingOrRepublishingTracks
    }

    /// True while the room is reconnecting, or the SDK is in its post-reconnect
    /// `republishAllTracks` window. During this time the WebRTC audio engine
    /// restarts and iOS mirrors that back as CallKit `performSetMutedCallAction`
    /// echoes that are not real user intent: the SDK already restores the
    /// microphone publication to its pre-reconnect mute state on republish.
    /// Both deferring new CallKit mute intent AND replaying pending intent must
    /// wait out this window, otherwise we race the republish and drive a
    /// redundant `setMicrophone`.
    @MainActor
    private var isReconnectingOrRepublishingTracks: Bool {
        roomContext?.isRoomReconnecting == true ||
            roomContext?.room.localParticipant.isRepublishingTracks == true
    }

    func shouldDeferInitialRoomAudioSetupForCallKit() -> Bool {
        isFromCallkit && !isCurrentCallKitAudioSessionActive
    }

    @objc public func callKitAudioSessionDidActivate() {
        markCurrentCallKitAudioSessionActive()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.roomContext?.handleCallKitAudioSessionActivated()
            await self.applyPendingCallKitMuteStateIfReady(reason: "CallKit audio session activated")
        }
    }

    @MainActor
    func applyPendingCallKitMuteStateIfReady(reason: String) async {
        guard pendingCallKitMuteState() != nil else { return }
        guard lifecycleState == .connected else {
            Logger.info("\(logTag) CallKit mute intent pending: state=\(lifecycleState), reason=\(reason)")
            return
        }
        guard !isFromCallkit || isCurrentCallKitAudioSessionActive else {
            Logger.info("\(logTag) CallKit mute intent pending: waitingForAudioSession=true, reason=\(reason)")
            return
        }
        // Keep the intent parked while reconnecting/republishing (mirror the
        // deferral in `shouldDeferMicrophoneChangeForCallKit`). Consuming it now
        // would race the SDK's `republishAllTracks`. It is replayed once the
        // republish window closes.
        guard !isReconnectingOrRepublishingTracks else {
            Logger.info("\(logTag) CallKit mute intent pending: reconnecting/republishing, reason=\(reason)")
            return
        }
        guard let muted = consumePendingCallKitMuteState() else { return }
        Logger.info("\(logTag) CallKit mute intent applying: muted=\(muted), reason=\(reason)")
        beginCallKitMuteSuppression(1.0, mutedTarget: muted)
        await muteAudio(muted)
    }

    /// Called from `didCompleteReconnect`. A `.full` reconnect re-publishes local
    /// tracks via the SDK's `republishAllTracks` (which restores the microphone
    /// to its *pre-reconnect* mute state), so any parked mute intent must be
    /// replayed only after that window closes — otherwise republish clobbers it.
    /// `.quick` reconnects don't republish, so replay right away.
    @MainActor
    func replayPendingCallKitMuteAfterReconnect(mode: ReconnectMode) async {
        if case .full = mode {
            armCallKitMuteReplayWaiter(reason: "post-reconnect(full)")
        } else {
            await applyPendingCallKitMuteStateIfReady(reason: "post-reconnect(\(mode)) replay")
        }
    }

    /// Arms a single waiter that replays parked CallKit/toolbar mute intent once
    /// the reconnect + `republishAllTracks` window closes.
    ///
    /// Why a waiter (not a one-shot check): `republishAllTracks` is dispatched
    /// *concurrently* with `didCompleteReconnect`, and the app reconnect flag and
    /// the SDK republish flag flip on different threads. A one-shot check at
    /// reconnect-complete could (a) see `pending == nil` and return before the
    /// user's intent even arrives, or (b) run before the republish window opens.
    /// The waiter instead: gives the window a moment to (re)open, waits for it to
    /// close, then applies whatever is parked — so intent that arrives *any* time
    /// during the window (via `deferMicrophoneChangeIfConnecting`) is covered.
    /// Idempotent: only one waiter runs at a time.
    @MainActor
    func armCallKitMuteReplayWaiter(reason: String, giveUpAt: Date? = nil) {
        guard !_isCallKitMuteReplayWaiterArmed else { return }
        _isCallKitMuteReplayWaiterArmed = true
        // Absolute upper bound across all re-arms so a genuinely stuck reconnect
        // can't spin a background waiter forever.
        let overallDeadline = giveUpAt ?? Date().addingTimeInterval(30.0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Whether we hand off to a fresh waiter instead of finishing here.
            var rearm = false
            var shouldClearReconnectState = true
            defer {
                if rearm {
                    // Hand off: clear first so the re-arm passes its idempotency
                    // guard, then arm a fresh waiter carrying the same deadline.
                    self._isCallKitMuteReplayWaiterArmed = false
                    self.armCallKitMuteReplayWaiter(reason: reason, giveUpAt: overallDeadline)
                } else {
                    self._isCallKitMuteReplayWaiterArmed = false
                    if shouldClearReconnectState {
                        DTRTCAudioSession.shared.setRoomReconnecting(
                            false,
                            reason: "reconnect/republish replay completed"
                        )
                    }
                }
            }

            // Let the republish window (re)open — it is dispatched concurrently
            // and the reconnect/republish flags flip on different threads.
            let openDeadline = Date().addingTimeInterval(1.5)
            while Date() < openDeadline, !self.isReconnectingOrRepublishingTracks {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
            }
            // Wait for it to close. Cap this slice at 8s so we don't hold a task
            // indefinitely, but if the window is still open re-arm (below) rather
            // than dropping the parked intent on a slow republish.
            let closeDeadline = min(Date().addingTimeInterval(8.0), overallDeadline)
            while Date() < closeDeadline, self.isReconnectingOrRepublishingTracks {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
            }
            if self.isReconnectingOrRepublishingTracks {
                if Date() < overallDeadline {
                    Logger.warn("\(self.logTag) CallKit mute replay waiter slice timed out while still reconnecting/republishing; re-arming (\(reason))")
                    rearm = true
                } else {
                    Logger.warn("\(self.logTag) CallKit mute replay waiter gave up: still reconnecting/republishing past overall deadline (\(reason))")
                    shouldClearReconnectState = false
                    self.armReconnectStateCleanupWaiter(reason: reason)
                }
                return
            }
            await self.applyPendingCallKitMuteStateIfReady(reason: "reconnect/republish replay (\(reason))")
            if self.roomContext?.room.localParticipant.isMicrophoneEnabled() == true {
                self.roomContext?.restartLocalAudioDiagnostics(
                    reason: "full reconnect media restore completed"
                )
            }
        }
    }

    @MainActor
    private func armReconnectStateCleanupWaiter(reason: String) {
        guard !_isReconnectStateCleanupWaiterArmed else { return }
        _isReconnectStateCleanupWaiterArmed = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self._isReconnectStateCleanupWaiterArmed = false }
            let cleanupDeadline = Date().addingTimeInterval(60.0)
            while self.isReconnectingOrRepublishingTracks, Date() < cleanupDeadline {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            let didTimeOut = self.isReconnectingOrRepublishingTracks
            if didTimeOut {
                Logger.error(
                    "\(self.logTag) reconnect state cleanup timed out after mute replay waiter deadline; clearing stale reconnect flag (\(reason))"
                )
            }
            DTRTCAudioSession.shared.setRoomReconnecting(
                false,
                reason: didTimeOut
                    ? "reconnect/republish cleanup fail-safe timeout (\(reason))"
                    : "reconnect/republish cleanup completed after waiter timeout (\(reason))"
            )
        }
    }

    func markRoomIdRejectedByCallKit(_ roomId: String) {
        callKitRejectedRoomIdsLock.lock()
        defer { callKitRejectedRoomIdsLock.unlock() }
        _callKitRejectedRoomIds.insert(roomId)
    }

    /// Atomic check-and-remove. Returns true if the roomId was rejected and consumed it.
    func consumeRoomIdRejectionByCallKit(_ roomId: String) -> Bool {
        callKitRejectedRoomIdsLock.lock()
        defer { callKitRejectedRoomIdsLock.unlock() }
        return _callKitRejectedRoomIds.remove(roomId) != nil
    }
    
    var allParticipantIds: [String] {
        guard let roomContext else {
            return []
        }
        return roomContext.room.allParticipants.keys.map({ identity in
            let stringIdentity = identity.stringValue
            guard let participantId = stringIdentity.components(separatedBy: ".").first else {
                return stringIdentity
            }

            return participantId
        })
    }
    
    /// 会议生命周期状态枚举
    /// idle -> connecting -> connected -> disconnecting -> idle
    enum MeetingLifecycleState: String, CustomStringConvertible {
        case idle           // 空闲，无会议
        case connecting     // 正在连接（发起或接听中）
        case connected      // 已连接，会议进行中
        case disconnecting  // 正在断开连接

        var description: String { rawValue }

        /// 是否允许发起新会议
        var canStartNewMeeting: Bool {
            self == .idle
        }

        /// 是否允许接听新来电
        var canAcceptNewCall: Bool {
            self == .idle
        }

        /// 是否处于活跃状态（非空闲）
        var isActive: Bool {
            self != .idle
        }
    }

    /// 通话错误枚举
    enum CallError: Error, LocalizedError {
        case messageCreationFailed
        case connectionFailed
        case tokenExpired
        case roomContextCreationFailed
        case invalidState
        case alreadyInMeeting

        var errorDescription: String? {
            switch self {
            case .messageCreationFailed:
                return "Failed to create call message"
            case .connectionFailed:
                return "Failed to connect to call"
            case .tokenExpired:
                return "Call token expired before connection established"
            case .roomContextCreationFailed:
                return "Failed to create room context"
            case .invalidState:
                return "Invalid call state"
            case .alreadyInMeeting:
                return "Already in a meeting"
            }
        }
    }

    private let stateMachine = CallStateMachine()
    private var stateSubscription: AnyCancellable?

    var lifecycleState: MeetingLifecycleState {
        stateMachine.state.legacyValue
    }

    @discardableResult
    func tryTransition(from expectedState: MeetingLifecycleState, to newState: MeetingLifecycleState) -> Bool {
        stateMachine.dispatchLegacy(from: expectedState, to: newState)
    }

    func forceTransition(to newState: MeetingLifecycleState) {
        stateMachine.forceReset(reason: "legacy forceTransition(to: \(newState))")
    }

    /// Side-effects triggered by state transitions (via statePublisher subscription).
    /// Preserves identical behavior to the old lock-internal handleStateChange.
    private func handleStateChange(_ transition: StateTransition) {
        let newState = transition.to.legacyValue
        let isActive = newState.isActive
        DispatchQueue.main.async {
            CurrentAppContext().appUserDefaults().set(isActive, forKey: TSConstants.kSharedMeetingActiveKey)
        }

        switch newState {
        case .idle:
            clearPendingCallKitAudioState(reason: "state idle")
            DispatchQueue.main.async {
                DeviceSleepManager.shared.removeBlock(blockObject: self)
                OWSAudioSession.shared.inCalling = false
            }
        case .connecting:
            DispatchQueue.main.async {
                DeviceSleepManager.shared.addBlock(blockObject: self)
                OWSAudioSession.shared.inCalling = true
            }
        case .connected:
            hasEverConnectedToRoom = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.startCallDurationTimer()
                // Room media is now connected: flip the CallKit system UI from
                // "Connecting…" to answered in sync with real audio. No-op when no
                // answer action is held (caller side / non-CallKit answer).
                if let uuid = self.currentCall.callKitUUID {
                    DTCallKitManager.shared().fulfillPendingAnswerAction(uuid)
                }
                if !self.isFromCallkit || self.isCurrentCallKitAudioSessionActive {
                    await self.applyPendingCallKitMuteStateIfReady(reason: "state connected")
                }
            }
        case .disconnecting:
            break
        }

        if newState == .connecting || newState == .connected {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    let rid = self.currentCall.roomId,
                    !rid.isEmpty
                else { return }
                self.handleMeetingBar(roomId: rid, action: .add)
            }
        }
    }

    @objc public internal(set) var hasEverConnectedToRoom: Bool = false

    var inMeeting: Bool { lifecycleState == .connected }

    public var hasMeeting: Bool { lifecycleState.isActive }

    private(set) lazy var hangupCoordinator = HangupCoordinator(dependencies: self)
    
    ///会议超时的时间
    lazy var meetingTimeoutResult: Int = {
        return banMicCountdownDuration()
    }()
    
    ///弹窗超时的时间
    lazy var reminderTimeoutResult: Int = {
        return banMicAlertCountdownDuration()
    }()
        
    var allMeetings = [DTLiveKitCallModel]()
    
    /// 参会人的回调
    var participantDisconnectCallback: (() -> Void)?
    // 视频
    var videoViewPool: [String: VideoView] = [:]
    var currentlyDisplayedIdentity: String?
    var currentlyDisplayedSid: String?
    var currentlyCameraEnabled: Bool?
    
    // 评价
    var feedbackUserSid: String?
    var feedbackRoomSid: String?
    var feedbackRoomId: String?
    
    // 评分触发保护，防止多次消费评分逻辑
    var hasTriggeredRating: Bool = false
    var feedbackIsNetworkPoor: Bool? = false
    // Deferred rating: PanModal can't present in background, defer to foreground
    var hasPendingRating: Bool = false
    /// 最近一次会议时长，用于在清理资源后决定是否展示评分弹窗
    var lastMeetingDuration: TimeInterval?
    
    // 防止重复执行answerCall的标志
    var isAnswering: Bool = false
    
    var audioPlayer: OWSAudioPlayer?
    
    // 每个 call 对应一个 RoomContext, call 结束后需要清理
    var roomContext: RoomContext?
    // 每个 call 对应的 RoomContext 可能不同, 每次需要初始化, 每次 call 结束后需要清理
    var appContext: LiveKitContext? {
        get {
            if _appContext == nil {
                _appContext = LiveKitContext()
            }
            return _appContext
        }
        set {
            _appContext = newValue
        }
    }
    
    private var _appContext: LiveKitContext?
    
    override init() {
        super.init()
        
        LiveKitSDK.setLogger(OSLogger(minLevel: .debug))

        stateSubscription = stateMachine.statePublisher
            .sink { [weak self] transition in
                self?.handleStateChange(transition)
            }

        let callMessageManager = DTCallMessageManager.shared
        callMessageManager.delegate = self
        DTCallKitManager.shared().delegate = self
        registerNotifications()

        // Darwin notification is registered in DTCallKitManager.init
        // No need to register here to avoid duplicate registration
    }

    // MARK: - DTCallKitManagerDelegate

    public func refreshCurrentCallStatus(_ status: CallStatus, uuidString: String?) {
        guard let uuidString else {
            Logger.warn("\(logTag) refreshCurrentCallStatus - uuidString is nil, status: \(status.rawValue)")
            return
        }

        Logger.info("\(logTag) refreshCurrentCallStatus - status: \(status.rawValue), uuid: \(uuidString)")

        switch status {
        case .accept:
            handleCallKitAccept(uuidString: uuidString)
        case .end:
            handleCallKitEnd(uuidString: uuidString)
        case .readyStart:
            currentCall.callKitUUID = uuidString
        case .buildCallerFail, .busy:
            Logger.warn("\(logTag) refreshCurrentCallStatus - error status: \(status.rawValue), uuid: \(uuidString)")
        case .none:
            break
        @unknown default:
            break
        }
    }

    // MARK: - CallKit Report Rejected Fallback
    @objc public func handleIncomingCallRejectedByCallKit(_ calling: DSKProtoCallMessageCalling) {
        Logger.warn("\(logTag) handleIncomingCallRejectedByCallKit - routing to in-app UI")

        guard let roomId = calling.roomID else {
            Logger.error("\(logTag) handleIncomingCallRejectedByCallKit - no roomId")
            return
        }

        let newCall = DTLiveKitCallModel()
        newCall.callState = .alerting
        newCall.caller = calling.caller
        newCall.roomId = roomId
        // Bind UUID if CallKit still has this roomId in callerMap (best-effort:
        // the placeholder may already be ended on this fallback path).
        newCall.callKitUUID = DTCallKitManager.shared().uuidString(fromRoomId: roomId)
        let fallbackRoomName = calling.roomName ?? DTCallManager.defaultMeetingName()
        newCall.roomName = fallbackRoomName
        newCall.publicKey = calling.publicKey
        newCall.emk = calling.emk

        var callType: CallType = .instant
        if let conversationId = calling.conversationID {
            let callInfo = conversationId.getCallInfo()
            newCall.conversationId = callInfo.conversationId
            callType = callInfo.callType
        }
        newCall.callType = callType
        if callType == .group, let gid = newCall.conversationId {
            SDSDatabaseStorage.shared.read { tx in
                newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupCallDisplayName(
                    trustedPlaintextName: calling.roomName,
                    serverGroupId: gid,
                    transaction: tx)
            }
        }
        if case .private = callType, let localNumber = TSAccountManager.localNumber() {
            newCall.callees = [localNumber]
        }
        newCall.createCallMsg = calling.createCallMsg
        newCall.controlType = calling.controlType
        newCall.inviteCallees = calling.callees
        newCall.timestamp = calling.timestamp

        let isPrivateCall = callType == .private
        let sound: OWSSound = isPrivateCall ? .callIncomming1v1 : .callIncommingGroup
        showAnswer(call: newCall) { [self] in
            DispatchMainThreadSafe { [self] in
                if UIApplication.shared.applicationState == .active {
                    playSound(sound, isLoop: isPrivateCall, playMode: .playback)
                }
            }
        }
    }


    public func refreshCurrentCallMuteState(_ isMute: Bool, uuidString: String?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let suppression = self.currentCallKitMuteSuppression()
            guard self.hasMeeting else {
                if suppression.isSuppressed {
                    if let mutedTarget = suppression.mutedTarget, isMute == mutedTarget {
                        Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=pre-meeting, target=\(mutedTarget)")
                        return
                    }
                    if suppression.mutedTarget == nil {
                        Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=pre-meeting, target=nil")
                        return
                    }
                }
                if self.isFromCallkit || uuidString == self.currentCall.callKitUUID {
                    self.setPendingCallKitMuteState(isMute, reason: "CallKit mute action before active meeting")
                }
                Logger.warn("\(self.logTag) refreshCurrentCallMuteState - no active meeting")
                return
            }
            if self.isFromCallkit, self.roomContext?.isApplyingInitialRoomAudioSetup == true {
                if self.consumeInitialRoomAudioSetupCallKitEchoIfMatched(isMute) {
                    return
                }
                if self.deferInitialRoomAudioSetupCallKitOppositeEchoIfNeeded(isMute) {
                    return
                }
                if suppression.isSuppressed {
                    if let mutedTarget = suppression.mutedTarget {
                        if isMute == mutedTarget {
                            Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=initial-audio-setup, target=\(mutedTarget)")
                            return
                        }
                        Logger.info("\(self.logTag) CallKit mute ignored during initial audio setup: muted=\(isMute), target=\(mutedTarget)")
                        return
                    }
                    Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=initial-audio-setup, target=nil")
                    return
                }
                self.setPendingCallKitMuteState(isMute, reason: "CallKit mute action during initial room audio setup")
                return
            }
            if suppression.isSuppressed {
                if let mutedTarget = suppression.mutedTarget {
                    if isMute == mutedTarget {
                        Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=suppression, target=\(mutedTarget)")
                        return
                    }
                    if self.deferMicrophoneChangeIfConnecting(enable: !isMute, reason: "CallKit mute action during targeted suppression before audio ready") {
                        return
                    }
                    Logger.info("\(self.logTag) CallKit mute accepted despite suppression: muted=\(isMute), target=\(mutedTarget)")
                } else {
                    if self.deferMicrophoneChangeIfConnecting(enable: !isMute, reason: "suppressed CallKit mute action before audio ready") {
                        return
                    }
                    Logger.info("\(self.logTag) CallKit mute echo ignored: muted=\(isMute), scope=suppression, target=nil")
                    return
                }
            }
            if self.deferMicrophoneChangeIfConnecting(enable: !isMute, reason: "CallKit mute action while connecting") {
                return
            }
            self.beginCallKitMuteSuppression(1.0, mutedTarget: isMute)
            Task {
                await self.muteAudio(isMute)
            }
        }
    }

    // MARK: - CallKit Accept

    private func handleCallKitAccept(uuidString: String) {
        Logger.info("\(logTag) handleCallKitAccept - uuid: \(uuidString)")

        clearPendingCallKitAudioState(reason: "CallKit accept")

        currentCall.callKitUUID = uuidString

        stopCallTimeoutTimer()

        let ckManager = DTCallKitManager.shared()
        guard let calling = ckManager.calling(fromUUID: uuidString) else {
            Logger.error("\(logTag) handleCallKitAccept - calling proto not found for: \(uuidString)")
            return
        }

        let is1on1Call = calling.conversationID?.hasNumber ?? false
        if !is1on1Call {
            if let callKitMuteIntent = ckManager.callKitMuteIntent(forUUID: uuidString)?.boolValue {
                setPendingCallKitMuteState(callKitMuteIntent, reason: "CallKit mute intent before accept")
                beginCallKitMuteSuppression(3.0, mutedTarget: callKitMuteIntent)
                if callKitMuteIntent {
                    ckManager.muteCurrentCall(true, uuidString: uuidString)
                } else {
                    Logger.info("\(logTag) handleCallKitAccept preserves pre-answer CallKit unmute intent")
                }
            } else {
                beginCallKitMuteSuppression(3.0, mutedTarget: true)
                ckManager.muteCurrentCall(true, uuidString: uuidString)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            ckManager.acceptCall(calling: calling)
        }
    }

    // MARK: - CallKit End

    private func handleCallKitEnd(uuidString: String) {
        Logger.info("\(logTag) handleCallKitEnd - uuid: \(uuidString)")

        // Runs on callKitQueue; capture `calling` now before performEndCallAction clears it.
        let ckManager = DTCallKitManager.shared()
        guard let calling = ckManager.calling(fromUUID: uuidString) else {
            Logger.warn("\(logTag) handleCallKitEnd - calling proto not found, call may already be cleaned up")
            return
        }

        // Classify + tear down on the main actor so currentCall reads aren't raced.
        DispatchMainThreadSafe { [weak self] in
            self?.handleCallKitEndOnMain(uuidString: uuidString, calling: calling)
        }
    }

    // Main-thread only (from handleCallKitEnd) so currentCall reads stay serialized.
    private func handleCallKitEndOnMain(uuidString: String, calling: DSKProtoCallMessageCalling) {
        let targetRoomId = calling.roomID
        let currentRoomId = currentCall.roomId
        let isCurrentCall = (targetRoomId != nil && targetRoomId == currentRoomId)

        Logger.info("\(logTag) handleCallKitEnd - isCurrentCall: \(isCurrentCall)")

        // nil tracked UUID = unanswered incoming call; let the reject path run.
        if isCurrentCall, hasMeeting,
           let trackedUUID = currentCall.callKitUUID,
           trackedUUID != uuidString {
            Logger.info("\(logTag) handleCallKitEnd - stale CallKit end ignored, state: \(lifecycleState), tracked: \(trackedUUID), event: \(uuidString)")
            return
        }

        // Connected meeting, but this end targets a UUID we didn't join through (e.g. bar-join
        // leaves callKitUUID == nil and a duplicate VoIP push made an extra placeholder). Only
        // skip our meeting teardown; the CallKit end action that invoked this dismisses its own UI.
        if isCurrentCall, hasMeeting, hasEverConnectedToRoom,
           currentCall.callKitUUID != uuidString {
            Logger.info("\(logTag) handleCallKitEnd - redundant CallKit end for live meeting ignored, tracked: \(currentCall.callKitUUID ?? "nil"), event: \(uuidString)")
            return
        }

        if let targetRoomId {
            markRoomIdRejectedByCallKit(targetRoomId)
            Logger.info("\(logTag) handleCallKitEnd - marked roomId as CallKit-rejected: \(targetRoomId)")
        }

        if isCurrentCall {
            stopCallTimeoutTimer()

            let localNumber = TSAccountManager.localNumber()
            let isCallee = localNumber != nil && calling.caller != nil && calling.caller != localNumber
            let neverJoinedRoom = !hasEverConnectedToRoom

            if isCallee && neverJoinedRoom {
                Logger.info("\(logTag) handleCallKitEnd - rejecting current call (callee, never joined)")
                let callType = calling.conversationID.map { $0.getCallInfo().callType } ?? .instant
                let tempCall = DTLiveKitCallModel()
                tempCall.caller = calling.caller
                tempCall.roomId = calling.roomID
                tempCall.callType = callType
                if callType == .private, let localNumber = TSAccountManager.localNumber() {
                    tempCall.callees = [localNumber]
                }
                Task {
                    await rejectIncomingCallSilently(with: tempCall)
                    await hangupCoordinator.terminate(reason: .remoteCancel, options: TerminationOptions(needSyncCallKit: false))
                    syncServerCalls()
                }
            } else {
                Logger.info("\(logTag) handleCallKitEnd - hanging up current call")
                guard let roomId = targetRoomId else { return }
                Task {
                    await hangupCall(needSyncCallKit: false, isByLocal: true, roomId: roomId, isFromCallKit: true)
                    syncServerCalls()
                }
            }
        } else {
            Logger.info("\(logTag) handleCallKitEnd - ending non-current call, sending reject only")
            if let targetRoomId {
                let callType = calling.conversationID.map { $0.getCallInfo().callType } ?? .instant
                let tempCall = DTLiveKitCallModel()
                tempCall.caller = calling.caller
                tempCall.roomId = targetRoomId
                tempCall.callType = callType
                if callType == .private, let localNumber = TSAccountManager.localNumber() {
                    tempCall.callees = [localNumber]
                }
                Task {
                    await rejectIncomingCallSilently(with: tempCall)
                    syncServerCalls()
                }
                callAlertManager.removeLiveKitAlertCall(targetRoomId)
                handleMeetingBar(roomId: targetRoomId, action: .remove)
            }
        }
    }
}

// MARK: - HangupCoordinatorDependencies

extension DTMeetingManager: HangupCoordinatorDependencies {

    func forceTransitionToIdle() {
        forceTransition(to: .idle)
    }

    func performResourceCleanup(roomContextToClean: RoomContext?, roomIdToClean: String?) async {
        if let roomId = roomIdToClean ?? currentCall.roomId {
            RoomIdManager.shared.removeRoomId(roomId)
        }

        let contextToClean = roomContextToClean ?? self.roomContext

        if let contextToClean {
            for track in contextToClean.room.localParticipant.localAudioTracks {
                do {
                    try await track.mute()
                } catch {
                    Logger.error("\(logTag) Failed to mute track: \(error)")
                }
            }
        }

        let latestDuration = currentCall.duration ?? TimerDataManager.shared.duration
        lastMeetingDuration = latestDuration

        stopSound()
        audioPlayer = nil
        currentCall.isPresentedShare = false

        dismissAutoLeaveTipView()
        clearCurrentCall()
        await removeCallWindow()
        hostRoomContentVC = nil
        appContext = nil
        roomContext = nil
        Logger.info("\(logTag) roomContext cleaned up")

        isMinimize = false
        showErrorToast = false
        otherCriticalAlert = false
        openCallCamera = false
        UIDevice.current.isProximityMonitoringEnabled = false
    }

    func showErrorToastIfNeeded(_ message: String) {
        let rootWindow = OWSWindowManager.shared().rootWindow
        let topVC = rootWindow.findTopViewController()
        DTToastHelper.toast(withText: message, in: topVC.view, durationTime: 3, afterDelay: 1)
    }

    func onTerminationCompleted() {
        ensurePortraitOrientationBeforeShowingRating()
    }

    func sendCallMessage(_ type: DTCallMessageType, forceEndGroupMeeting: Bool) async {
        await sendCallMessage(type, forceEndGroupMeeting: forceEndGroupMeeting, currentCall)
    }
}
