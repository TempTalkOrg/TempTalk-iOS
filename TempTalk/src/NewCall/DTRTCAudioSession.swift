//
//  DTRTCAudioSession.swift
//  Difft
//
//  Created by luke on 2025/5/20.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFoundation
import LiveKit
internal import LiveKitWebRTC

@objc
public protocol DTRTCAudioSessionObserver: AnyObject {
    func audioSessionDidChangePortType(
        _ portType: AVAudioSession.Port,
        isExternalConnected: Bool
    )

    func audioSessionDidChangePortName(
        _ portName: String,
        isExternalConnected: Bool
    )
}

let kAudioEngineErrorFailedToConfigureAudioSession = -4100

struct RecordingPreparationRequestState: Sendable {
    struct Request: Equatable, Sendable {
        let enabled: Bool
        let revision: UInt
    }

    private var desiredEnabled = false
    private var revision: UInt = 0
    private var isApplying = false

    mutating func request(_ enabled: Bool) -> Request? {
        revision &+= 1
        desiredEnabled = enabled
        guard !isApplying else { return nil }
        isApplying = true
        return Request(enabled: enabled, revision: revision)
    }

    mutating func replacement(afterApplying request: Request) -> Request? {
        guard request.revision != revision else {
            isApplying = false
            return nil
        }
        return Request(enabled: desiredEnabled, revision: revision)
    }
}

@objc
public class DTRTCAudioSession: NSObject {
    // Force singleton access
    @objc public static let shared = DTRTCAudioSession()

    private static let callkitUseVideoMode = false

    private let session = AVAudioSession.sharedInstance()

    private weak var observer: DTRTCAudioSessionObserver?

    private weak var currentActiveObject: AnyObject?

    private let rtcConfVoice = AudioSessionConfiguration(
        category: OWSAudioSession.shared.rtcCategory,
        categoryOptions: OWSAudioSession.shared.rtcCategoryOptions,
        mode: OWSAudioSession.shared.rtcModeVoice
    )

    private let rtcConfVideo = AudioSessionConfiguration(
        category: OWSAudioSession.shared.rtcCategory,
        categoryOptions: OWSAudioSession.shared.rtcCategoryOptions,
        mode: OWSAudioSession.shared.rtcModeVideo
    )

    // Used in two situations:
    //   1) In-call "mic-off speakerphone" listening — Playback puts us on the media-volume path so
    //      remote audio plays at a comfortable level (PlayAndRecord+voiceChat/videoChat would route
    //      through the telephony path, which is noticeably quieter at the user's default volume).
    //   2) Right before deactivating the session — leaves the AVAudioSession in a neutral state so
    //      subsequent audio activity (incoming CallKit ring, push notification sound) can start
    //      cleanly without inheriting a stale PlayAndRecord+voiceChat configuration.
    // Options must stay [.mixWithOthers] only: see rtcCategoryPlaybackOptions for why BT/AirPlay
    // options can't be added here. Playback supports A2DP/AirPlay output implicitly.
    private let rtcConfPlayback = AudioSessionConfiguration(
        category: OWSAudioSession.shared.rtcCategoryPlayBack,
        categoryOptions: OWSAudioSession.shared.rtcCategoryPlaybackOptions,
        mode: OWSAudioSession.shared.rtcModeSpoken
    )

    private var timer: Timer?
    private var isObservering = false
    private var lastStatus: (AVAudioSession.Port, Bool)?
    private weak var currentStartTimerObj: AnyObject?

    let _state = StateSync(State())
    private var isForceSetConfig: Bool?

    private var routeChangeToken: NSObjectProtocol?
    private var hasInCalling: Bool { currentActiveObject != nil }
    private var prepareToProcessNewCallkitCall: Bool = false

    /// `true` from the moment `disconnectRoomConfig` runs until the next `connectRoomConfig`.
    /// Used by `engineDidDisable` to skip AVAudioSession reconfiguration during the hangup
    /// window — CallKit is deactivating the session in parallel and will reject our
    /// setCategory/setActive calls. Propagating the resulting -4100 back to WebRTC triggers
    /// an `ApplyDeviceEngineState` rollback that crashes the worker thread on the next
    /// `StopPlayout` (Crashlytics issue 75bb24b0856fdc4cdb8c27133e649317). Note that
    /// `RoomContext.disconnect()` calls `disconnectRoomConfig` *before* `room.disconnect()`,
    /// so this flag is already true by the time `engineDidDisable` fires during cleanUpRTC.
    private var hasCalledDisconnect: Bool = false
    private let reconnectStateLock = NSLock()
    private var _isRoomReconnecting: Bool = false
    private let recordingPreparationRequestState = StateSync(RecordingPreparationRequestState())

    override private init() {
        super.init()

        routeChangeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleRouteChange(note)
        }

        _state.onDidMutate = { new_, old_ in
            let forceSet: Bool = {
                defer { self.isForceSetConfig = nil }
                return self.isForceSetConfig ?? false
            }()

            _ = self.configureIfNeeded(oldState: old_, newState: new_, forceSet: forceSet)
        }

        AudioManager.shared.set(engineObservers: [self, AudioManager.shared.mixer])

        do {
            // .voiceProcessing: mute via VPIO hardware mute, so the mic indicator (orange dot)
            // turns off while muted (may trigger iOS mute sound). .inputMixer only zeroes the
            // input mixer volume, so VPIO keeps capturing and the dot stays on.
            try AudioManager.shared.set(microphoneMuteMode: .voiceProcessing)
            Logger.info("set microphoneMuteMode \".voiceProcessing\" success")
        } catch {
            Logger.error("set microphoneMuteMode failed with error: \(error)")
        }

        setAudioManagerEngineAvailability(.none, "RTC init")
    }

    deinit {
        if let routeChangeToken {
            NotificationCenter.default.removeObserver(routeChangeToken)
            self.routeChangeToken = nil
        }
    }

    @objc
    public func callkitReceiveCall(_ speaker: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("CallKit receive call audio prepare: speaker=\(speaker), inCalling=\(hasInCalling)")

        if hasInCalling {
            Logger.info("callkitReceiveCall: already in calling, ignore")
            return
        }

        isAutomaticConfigurationEnabled = false
        setAudioManagerEngineAvailability(.none, "callkit receive call")

        let config = if speaker, Self.callkitUseVideoMode {
            rtcConfVideo
        } else {
            rtcConfVoice
        }
        safeSetAudioSessionCategory(config, "callkit receive call")
    }

    @objc
    public func callkitStartCall(_ speaker: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("CallKit start call audio prepare: speaker=\(speaker), inCalling=\(hasInCalling)")

        if hasInCalling {
            return
        }

        isAutomaticConfigurationEnabled = false
        setAudioManagerEngineAvailability(.none, "callkit start call")

        let config = if speaker, Self.callkitUseVideoMode {
            rtcConfVideo
        } else {
            rtcConfVoice
        }
        safeSetAudioSessionCategory(config, "callkit start call")
    }

    @objc
    public func callkitHandleCall(_ answer: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        prepareToProcessNewCallkitCall = true
        isAutomaticConfigurationEnabled = false

        Logger.info("CallKit handle call audio prepare: answer=\(answer), inCalling=\(hasInCalling)")
        // do nothing
    }

    @objc
    func callkitDidActivateAudioSession(_: AVAudioSession, speaker: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("CallKit audio session activated: speaker=\(speaker), inCalling=\(hasInCalling)")

        isAutomaticConfigurationEnabled = false

        let config = if speaker, Self.callkitUseVideoMode {
            rtcConfVideo
        } else {
            rtcConfVoice
        }
        safeSetAudioSessionCategory(config, "callkit active audio session")

        if !Self.callkitUseVideoMode {
            safeAudioSessionOverrideOutputAudioPort(speaker, "callkit active audio session")
        }
    }

    @objc
    func callkitDidDeactivateAudioSession(_: AVAudioSession) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if prepareToProcessNewCallkitCall {
            Logger.info("CallKit audio session deactivation ignored: preparing new CallKit call")
        } else {
            // TODO: Temporary fallback for a no-audio issue after answering the first CallKit call. When returning to the foreground and receiving a new incoming call,
            // audio may fail to play because OWSAudioSession.inCalling is set to true too early. Remove this fallback after fixing the early state update.
            safeSetAudioSessionCategory(rtcConfPlayback, "callkit deactive audio session")

            setAudioManagerEngineAvailability(.none, "callkit deactive audio session")
        }
    }

    public func connectRoomConfig(_ obj: AnyObject, fromCallKit: Bool) async {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard currentActiveObject == nil else {
            let currentObj = currentActiveObject.map { Unmanaged.passUnretained($0).toOpaque() }
            Logger.info("connectRoomConfig ignored: currentObj=\(String(describing: currentObj)) newObj=\(Unmanaged.passUnretained(obj).toOpaque())")
            return
        }

        currentActiveObject = obj
        setRoomReconnecting(false, reason: "connect room")

        let speaker = shouldUseSpeakerInternal(DTMeetingManager.shared.currentCall.callType != .private)

        Logger.info("connectRoomConfig: fromCallKit=\(fromCallKit), speaker=\(speaker), inCalling=\(hasInCalling), obj=\(Unmanaged.passUnretained(obj).toOpaque())")

        _state.mutate {
            $0.isAutomaticConfigurationEnabled = !fromCallKit
            $0.isSpeakerOutputPreferred = speaker
            prepareToProcessNewCallkitCall = false
            hasCalledDisconnect = false
        }

        if fromCallKit { return }

        // TODO: implement the rest of the connectRoomConfig logic
    }

    public func disconnectRoomConfig(_ obj: AnyObject) async {
        let recordingPreparationRequest: RecordingPreparationRequestState.Request? = {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            guard let currentObj = currentActiveObject, currentObj === obj else {
                let currentObjPtr = currentActiveObject.map { Unmanaged.passUnretained($0).toOpaque() }
                Logger.info("disconnectRoomConfig ignored: currentObj=\(String(describing: currentObjPtr)) incomingObj=\(Unmanaged.passUnretained(obj).toOpaque())")
                return nil
            }

            currentActiveObject = nil
            hasCalledDisconnect = true
            setRoomReconnecting(false, reason: "disconnect room")
            Logger.info("disconnectRoomConfig: obj=\(Unmanaged.passUnretained(obj).toOpaque())")
            return recordingPreparationRequestState.mutate { $0.request(false) }
        }()

        guard let recordingPreparationRequest else { return }
        await applyAudioManagerRecordingPreparation(recordingPreparationRequest, reason: "disconnect room")
    }

    public func switchToSpeaker(_ speaker: Bool) {
        Logger.info("switchToSpeaker: speaker=\(speaker)")

        Task {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            let needOverride = _state.mutate {
                let fromCallKit = !$0.isAutomaticConfigurationEnabled

                isForceSetConfig = !fromCallKit
                $0.isSpeakerOutputPreferred = speaker

                return fromCallKit && !Self.callkitUseVideoMode
            }

            if needOverride {
                safeAudioSessionOverrideOutputAudioPort(speaker, "switchToSpeaker")
            }
        }
    }

    @objc
    func shouldUseSpeaker(_ speaker: Bool) -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        return shouldUseSpeakerInternal(speaker)
    }

    public func connectRoomSuccessConfig(_ obj: AnyObject) async {
        let requestResult: (isCurrentRoom: Bool, request: RecordingPreparationRequestState.Request?) = {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            guard let currentObj = currentActiveObject, currentObj === obj else {
                let currentObjPtr = currentActiveObject.map { Unmanaged.passUnretained($0).toOpaque() }
                Logger.info("connectRoomSuccessConfig ignored: currentObj=\(String(describing: currentObjPtr)) incomingObj=\(Unmanaged.passUnretained(obj).toOpaque())")
                return (false, nil)
            }

            let request = recordingPreparationRequestState.mutate { $0.request(true) }
            return (true, request)
        }()

        guard requestResult.isCurrentRoom else { return }
        setAudioManagerEngineAvailability(.default, "connect room success")
        guard let request = requestResult.request else { return }
        await applyAudioManagerRecordingPreparation(request, reason: "connect room success")
    }

    private func setAudioManagerEngineAvailability(_ availability: AudioEngineAvailability, _ reason: String) {
        do {
            try AudioManager.shared.setEngineAvailability(availability)
            Logger.info("setEngineAvailability success: \(availability.pretty), reason=\(reason)")
        } catch {
            Logger.error("setEngineAvailability failed with availability: \(availability.pretty), reason=\(reason), error=\(error)")
        }
    }

    private func applyAudioManagerRecordingPreparation(
        _ initialRequest: RecordingPreparationRequestState.Request,
        reason: String
    ) async {
        var request = initialRequest
        var requestReason = reason

        while true {
            do {
                Logger.info("setRecordingAlwaysPreparedMode beg: \(request.enabled), reason=\(requestReason)")
                try await AudioManager.shared.setRecordingAlwaysPreparedMode(request.enabled)
                Logger.info("setRecordingAlwaysPreparedMode end success: \(request.enabled), reason=\(requestReason)")
            } catch {
                Logger.error("setRecordingAlwaysPreparedMode end failed: \(request.enabled), reason=\(requestReason), error=\(error)")
            }

            guard let replacement = recordingPreparationRequestState.mutate({
                $0.replacement(afterApplying: request)
            }) else {
                return
            }

            Logger.info("setRecordingAlwaysPreparedMode reconciling stale request: \(request.enabled) -> \(replacement.enabled)")
            request = replacement
            requestReason = "reconcile latest request after \(reason)"
        }
    }

    private func safeSetAudioSessionCategory(_ config: AudioSessionConfiguration, _ reason: String) {
        do {
            Logger.info("setAudioSessionCategory(reason=\(reason)) to: \(config)")
            try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
        } catch {
            Logger.error("setAudioSessionCategory(reason=\(reason)) failed with error: \(error)")
        }
    }

    private func safeSetAudioSessionCategoryIfNeeded(_ config: AudioSessionConfiguration, _ reason: String) {
        guard session.category != config.category
            || session.mode != config.mode
            || session.categoryOptions != config.categoryOptions
        else {
            Logger.debug("setAudioSessionCategory(reason=\(reason)) skipped: unchanged")
            return
        }
        safeSetAudioSessionCategory(config, reason)
    }

    private func setAudioSessionCategoryOrThrow(_ config: AudioSessionConfiguration, _ reason: String) throws {
        Logger.info("setAudioSessionCategory(reason=\(reason)) to: \(config)")
        try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
    }

    private func safeAudioSessionOverrideOutputAudioPort(_ speaker: Bool, _ reason: String) {
        do {
            Logger.info("overrideOutputAudioPort(reason=\(reason)): \(speaker ? "speaker" : "none")")
            try session.overrideOutputAudioPort(speaker ? .speaker : .none)
        } catch {
            Logger.error("overrideOutputAudioPort(reason=\(reason)) failed with error: \(error)")
        }
    }

    private func safeSetAudioSessionActive(_ active: Bool, _ reason: String) {
        do {
            Logger.info("setAudioSessionActive(reason=\(reason)): \(active)")
            if active {
                try session.setActive(true)
            } else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            Logger.error("setAudioSessionActive(reason=\(reason)) failed with error: \(error)")
        }
    }

    private func setAudioSessionActiveOrThrow(_ active: Bool, _ reason: String) throws {
        Logger.info("setAudioSessionActive(reason=\(reason)): \(active)")
        if active {
            try session.setActive(true)
        } else {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: status

public extension DTRTCAudioSession {
    @objc
    func currentOutputType() -> AVAudioSession.Port {
        session.currentRoute.outputs.first?.portType ?? .builtInSpeaker
    }

    @objc
    func currentInputPortName() -> String {
        session.currentRoute.inputs.first?.portName ?? ""
    }

    @objc
    func isUsingExternalOutput() -> Bool {
        session.currentRoute.outputs.contains { (output: AVAudioSessionPortDescription) in
            switch output.portType {
            case .headphones,
                 .bluetoothHFP,
                 .bluetoothLE,
                 .bluetoothA2DP,
                 .airPlay,
                 .HDMI,
                 .usbAudio,
                 .carAudio,
                 .lineOut:
                true
            default:
                false
            }
        }
    }

    @objc
    func isExternalDeviceConnected() -> Bool {
        var isConnected = false

        if let availableInputs = session.availableInputs {
            isConnected = availableInputs.contains {
                (input: AVAudioSessionPortDescription) in
                switch input.portType {
                case .headsetMic,
                     .bluetoothHFP,
                     .bluetoothLE,
                     .usbAudio,
                     .carAudio,
                     .lineIn,
                     .AVB:
                    true
                default:
                    false
                }
            }
        }

        return isConnected
    }

    internal func isExternalConnected() -> Bool {
        if isUsingExternalOutput() {
            true
        } else {
            isExternalDeviceConnected()
        }
    }

    internal func shouldUseSpeakerInternal(_ speaker: Bool) -> Bool {
        speaker && !isExternalConnected()
    }

    internal func checkOutputStatus() {
        let portType = currentOutputType()
        let isExternalConnected = isExternalConnected()

        let currentStatus = (portType, isExternalConnected)
        if let lastStatus, lastStatus == currentStatus {
            return
        }

        lastStatus = currentStatus
        notifyObservers(portType, isExternalConnected: isExternalConnected)
    }

    internal func checkInputStatus() {
        let portName = currentInputPortName()
        let isExternalConnected = isExternalConnected()

        notifyObservers(portName, isExternalConnected: isExternalConnected)
    }
}

// MARK: Timer Observer

extension DTRTCAudioSession {
    func startObserving(_ obj: AnyObject) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard !isObservering else { return }

        Logger.info("timer start: obj=\(Unmanaged.passUnretained(obj).toOpaque())")

        currentStartTimerObj = obj
        timer = Timer.weakTimer(
            withTimeInterval: 1,
            target: self,
            selector: #selector(observingAction),
            userInfo: nil,
            repeats: true
        )
        RunLoop.current.add(timer!, forMode: .common)
    }

    @objc
    private func observingAction() {
        isObservering = true
        DispatchQueue.global().async { [weak self] in
            self?.checkOutputStatus()
            self?.checkInputStatus()
        }
    }

    func stopObserving(_ obj: AnyObject) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("timer stop: obj=\(Unmanaged.passUnretained(obj).toOpaque())")

        guard let currentStartTimerObj, currentStartTimerObj === obj else {
            Logger.info("timer stop: ignore")
            return
        }

        isObservering = false
        invalidate()
    }

    private func invalidate() {
        guard let timer else { return }

        currentStartTimerObj = nil
        timer.invalidate()
        self.timer = nil
    }
}

// MARK: Observer

public extension DTRTCAudioSession {
    @objc
    func addObserver(_ observer: DTRTCAudioSessionObserver) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        self.observer = observer
    }

    @objc
    func removeObserver(_ observer: DTRTCAudioSessionObserver) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if observer === self.observer {
            self.observer = nil
        }
    }

    @objc
    func checkRouterIsSpeaker() -> Bool {
        currentOutputType() == .builtInSpeaker
    }

    private func notifyObservers(_ portType: AVAudioSession.Port, isExternalConnected: Bool) {
        let observerTmp = {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            return observer
        }()

        guard let observerTmp else { return }

        observerTmp.audioSessionDidChangePortType(
            portType,
            isExternalConnected: isExternalConnected
        )
    }

    private func notifyObservers(_ portName: String, isExternalConnected: Bool) {
        let observerTmp = {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            return observer
        }()

        guard let observerTmp else { return }

        observerTmp.audioSessionDidChangePortName(portName, isExternalConnected: isExternalConnected)
    }
}

// MARK: AudioSessionEngineObserver

extension DTRTCAudioSession: AudioEngineObserver, @unchecked Sendable {
    struct State: Sendable {
        var next: (any AudioEngineObserver)?

        var isAutomaticConfigurationEnabled: Bool = true
        var isAutomaticDeactivationEnabled: Bool = true
        var usePlaybackWhenNotRecording: Bool = false
        var isPlayoutEnabled: Bool = false
        var isRecordingEnabled: Bool = false
        var isSpeakerOutputPreferred: Bool = true
        var isEngineWillEnable: Bool?
    }

    @objc
    public var isAutomaticConfigurationEnabled: Bool {
        get { _state.isAutomaticConfigurationEnabled }
        set { _state.mutate { $0.isAutomaticConfigurationEnabled = newValue } }
    }

    public var isAutomaticDeactivationEnabled: Bool {
        get { _state.isAutomaticDeactivationEnabled }
        set { _state.mutate { $0.isAutomaticDeactivationEnabled = newValue } }
    }

    @objc
    public var isSpeakerOutputPreferred: Bool {
        get { _state.isSpeakerOutputPreferred }
        set { _state.mutate { $0.isSpeakerOutputPreferred = newValue } }
    }

    public var next: (any AudioEngineObserver)? {
        get { _state.next }
        set { _state.mutate { $0.next = newValue } }
    }

    private func configureIfNeeded(oldState: State, newState: State, forceSet: Bool) -> Int {
        if (newState.isAutomaticConfigurationEnabled) || forceSet {
            do {
                try configureAudioSession(oldState: oldState, newState: newState, forceSet: forceSet)
                return 0
            } catch {
                return kAudioEngineErrorFailedToConfigureAudioSession
            }
        } else {
            return 0
        }
    }

    /// Returns true for OSStatus errors that mean "AVAudioSession is in the middle of being
    /// deactivated by another subsystem and is refusing configuration requests right now".
    ///
    /// These are observationally harmless to us: by the time we got here the session is
    /// already being released (typically because CallKit is deactivating it on hangup) and
    /// propagating the error to the WebRTC AudioEngineObserver via -4100 triggers a
    /// `ApplyDeviceEngineState` rollback that leaves the audio-device-buffer / fine-audio-buffer
    /// invariants broken — see Crashlytics issue 75bb24b0856fdc4cdb8c27133e649317.
    ///
    /// `AVAudioSessionErrorCodeCannotInterruptOthers` (`'!int'`, raw `560557684`) is what we
    /// observe in the wild during the hangup window. AVFoundation surfaces the underlying
    /// OSStatus via `NSOSStatusErrorDomain` rather than `AVAudioSessionErrorDomain`, but the
    /// numeric value is the same as the named enum case so we compare directly.
    static func isHarmlessDeactivatingError(_ nsErr: NSError) -> Bool {
        guard nsErr.domain == NSOSStatusErrorDomain else { return false }
        switch nsErr.code {
        case AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue:
            return true
        default:
            return false
        }
    }

    static func shouldPreserveAudioSessionOnEngineDisable(
        hasActiveRoom: Bool,
        isRoomReconnecting: Bool,
        hasCalledDisconnect: Bool
    ) -> Bool {
        hasActiveRoom && isRoomReconnecting && !hasCalledDisconnect
    }

    @Sendable func configureAudioSession(oldState: State, newState: State, forceSet: Bool) throws {
        if (!newState.isPlayoutEnabled && !newState.isRecordingEnabled)
            && (oldState.isPlayoutEnabled || oldState.isRecordingEnabled)
        {
            if Self.shouldPreserveAudioSessionOnEngineDisable(
                hasActiveRoom: hasInCalling,
                isRoomReconnecting: isRoomReconnecting,
                hasCalledDisconnect: hasCalledDisconnect
            ) {
                Logger.info("AudioSession reconfiguration skipped while reconnecting...")
                return
            }
            if newState.isAutomaticDeactivationEnabled {
                // Reset category to Playback before deactivating so that the AVAudioSession ends up
                // in a neutral, mix-friendly state. PlayAndRecord+voiceChat can otherwise leave
                // residual configuration that causes the next audio activity (incoming CallKit ring,
                // push notification sound, other apps' playback) to start with no audio or wrong
                // routing. We only do this when we're not already on Playback (usePlaybackWhenNotRecording
                // = true would have set Playback during the previous configure call).
                if !newState.usePlaybackWhenNotRecording {
                    try setAudioSessionCategoryOrThrow(rtcConfPlayback, "deactive configuring")
                }

                try setAudioSessionActiveOrThrow(false, "configuring")
            } else {
                Logger.info("AudioSession deactivation skipped...")
            }
        } else if newState.isRecordingEnabled || newState.isPlayoutEnabled {
            let playAndRecord = newState.isSpeakerOutputPreferred ? rtcConfVideo : rtcConfVoice
            // Mic-off branch uses a dual-track design (intentional trade-off):
            //   - speaker = true  -> Playback (media-volume path).
            //       PlayAndRecord+videoChat (the natural choice) routes audio through the iOS
            //       telephony path. The telephony volume slider is independent from the media
            //       volume slider and is often left at a low level by the user, which makes the
            //       remote audio sound very quiet during "listen-only" meeting participation.
            //       Switching to Playback puts us on the media-volume path so the audio level
            //       matches what the user expects when consuming media.
            //   - speaker = false -> PlayAndRecord+voiceChat.
            //       Receiver is a legal default output here, so the iOS daemon will not eject it
            //       back to Speaker during routine route re-evaluation (this was the root cause
            //       of the "suddenly switched to speaker" bug).
            // Trade-off: enabling the mic later forces a category switch (Playback -> PlayAndRecord)
            // and a brief audio-engine restart; the perceived volume also drops from media to call
            // volume for the duration of the user's own speaking turn.
            let config: AudioSessionConfiguration = if newState.isRecordingEnabled {
                playAndRecord
            } else if newState.usePlaybackWhenNotRecording {
                rtcConfPlayback
            } else {
                newState.isSpeakerOutputPreferred ? rtcConfPlayback : rtcConfVoice
            }

            do {
                try setAudioSessionCategoryOrThrow(config, "configuring")
                try session.setPreferredIOBufferDuration(LKRTCAudioSessionConfiguration.webRTC().ioBufferDuration)
            } catch let nsErr as NSError where Self.isHarmlessDeactivatingError(nsErr) {
                // AVAudioSession is in the middle of being deactivated by another subsystem
                // (typically CallKit during hangup, or another app temporarily seizing the
                // session). Our setCategory/setPreferredIOBufferDuration is harmless to drop
                // here — the session is about to be released anyway, and if we propagate the
                // error to the AudioEngineObserver as -4100 the WebRTC `ApplyDeviceEngineState`
                // triggers a rollback that leaves `fine_audio_buffer_` and `audio_device_buffer_`
                // out of sync and crashes on the next `StopPlayout`.
                Logger.info("AudioSession setCategory/setPreferredIOBufferDuration rejected by OS (\(nsErr.code)); session is being deactivated, treating as harmless")
            } catch {
                Logger.error("AudioSession failed to configure with error: \(error)")
                throw error
            }

            if !oldState.isPlayoutEnabled, !oldState.isRecordingEnabled {
                do {
                    try setAudioSessionActiveOrThrow(true, "configuring")
                } catch let nsErr as NSError where Self.isHarmlessDeactivatingError(nsErr) {
                    Logger.info("AudioSession setActive(true) rejected by OS (\(nsErr.code)); session is being deactivated, treating as harmless")
                } catch {
                    Logger.error("AudioSession failed to activate AudioSession with error: \(error)")
                    throw error
                }
            }

            // Fix route switching via AVRoutePickerView: setConfiguration alone may not apply the output route change.
            if config != rtcConfPlayback, newState.isEngineWillEnable == true, newState.isSpeakerOutputPreferred == oldState.isSpeakerOutputPreferred, forceSet {
                safeAudioSessionOverrideOutputAudioPort(newState.isSpeakerOutputPreferred, "configuring")
            }
        }
    }

    public func engineWillEnable(_ engine: AVAudioEngine, isPlayoutEnabled: Bool, isRecordingEnabled: Bool) -> Int {
        // The audio session must be configured before this method; otherwise it may cause no-audio issues.
        Logger.info("engineWillEnable beg: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled)")
        let result: Int = _state.mutate {
            let oldState = $0
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
            $0.isEngineWillEnable = true
            let result = configureIfNeeded(oldState: oldState, newState: $0, forceSet: false)
            if result != 0 {
                // Rollback state on failure so it stays consistent with WebRTC's rollback.
                $0 = oldState
            }
            return result
        }
        Logger.info("engineWillEnable end: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled) result=\(result)")

        guard result == 0 else { return result }

        // Call next last
        return _state.next?.engineWillEnable(engine, isPlayoutEnabled: isPlayoutEnabled, isRecordingEnabled: isRecordingEnabled) ?? 0
    }

    public func engineDidDisable(_ engine: AVAudioEngine, isPlayoutEnabled: Bool, isRecordingEnabled: Bool) -> Int {
        Logger.info("engineDidDisable beg: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled)")
        // Call next first
        let nextResult = _state.next?.engineDidDisable(engine, isPlayoutEnabled: isPlayoutEnabled, isRecordingEnabled: isRecordingEnabled)

        let isTearingDown = hasCalledDisconnect
        let shouldPreserveAudioSession = Self.shouldPreserveAudioSessionOnEngineDisable(
            hasActiveRoom: hasInCalling,
            isRoomReconnecting: isRoomReconnecting,
            hasCalledDisconnect: isTearingDown
        )
        let result: Int = _state.mutate {
            let oldState = $0
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
            $0.isEngineWillEnable = false
            if isTearingDown {
                // Hangup is in flight (disconnectRoomConfig already ran, room.disconnect()
                // is now cleaning up on a background task). CallKit is deactivating the
                // AVAudioSession in parallel and any setCategory/setActive we issue here
                // would be rejected. Skip the reconfig and return success so WebRTC's
                // `ApplyDeviceEngineState` doesn't rollback (which would leave
                // `fine_audio_buffer_` / `audio_device_buffer_` out of sync and crash on
                // the next `StopPlayout`).
                return 0
            }
            let result = configureIfNeeded(oldState: oldState, newState: $0, forceSet: false)
            if result != 0 {
                // Rollback state on failure so it stays consistent with WebRTC's rollback.
                $0 = oldState
            }
            return result
        }

        Logger.info("engineDidDisable end: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled) result=\(result) preserveAudioSession=\(shouldPreserveAudioSession) tearingDown=\(isTearingDown)")

        guard result == 0 else { return result }

        return nextResult ?? 0
    }

    func setRoomReconnecting(_ reconnecting: Bool, reason: String) {
        reconnectStateLock.lock()
        let oldValue = _isRoomReconnecting
        _isRoomReconnecting = reconnecting
        reconnectStateLock.unlock()
        if oldValue != reconnecting {
            Logger.info("room reconnect state: \(oldValue) -> \(reconnecting), reason=\(reason)")
        }
    }

    private var isRoomReconnecting: Bool {
        reconnectStateLock.lock()
        defer { reconnectStateLock.unlock() }
        return _isRoomReconnecting
    }

    public func engineWillStart(_ engine: AVAudioEngine, isPlayoutEnabled: Bool, isRecordingEnabled: Bool) -> Int {
        let nextResult = _state.next?.engineWillStart(engine, isPlayoutEnabled: isPlayoutEnabled, isRecordingEnabled: isRecordingEnabled) ?? 0

        let (speaker, fromCallKit) = _state.read {
            let speaker = lastStatus.map { $0.0 == .builtInSpeaker } ?? $0.isSpeakerOutputPreferred
            let fromCallKit = !$0.isAutomaticConfigurationEnabled

            return (speaker, fromCallKit)
        }

        if fromCallKit {
            let config = if speaker, Self.callkitUseVideoMode {
                rtcConfVideo
            } else {
                rtcConfVoice
            }
            safeSetAudioSessionCategoryIfNeeded(config, "engineWillStart restore")

            if !Self.callkitUseVideoMode {
                let isCurrentlySpeaker = currentOutputType() == .builtInSpeaker
                if isCurrentlySpeaker == speaker {
                    Logger.debug("engineWillStart restore skipped: route already \(speaker ? "speaker" : "non-speaker")")
                } else {
                    safeAudioSessionOverrideOutputAudioPort(speaker, "engineWillStart restore")
                }
            }
        }

        return nextResult
    }
}

// Mark for Notification
extension DTRTCAudioSession {
    private func handleRouteChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            Logger.info("route change (no reason info)")
            return
        }

        let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription

        if reason == .categoryChange {
            Logger.info("route change reason [\(reason.prettyWithRaw)]: \(session.category), pre:\(previousRoute.prettyOneLine), cur:\(session.currentRoute.prettyOneLine)")
        } else {
            Logger.info("route change reason [\(reason.prettyWithRaw)]: pre:\(previousRoute.prettyOneLine), cur:\(session.currentRoute.prettyOneLine)")
        }

        DispatchQueue.global().async { [weak self] in
            self?.checkOutputStatus()
            self?.checkInputStatus()
        }
    }
}

// Mark for AVAudioSession
extension AVAudioSessionDataSourceDescription {
    var pretty: String { dataSourceName }
}

extension AVAudioSessionPortDescription {
    var pretty: String {
        let ds = selectedDataSource?.pretty ?? "nil"
        return "\(portType.rawValue)(\(portName), ds=\(ds))"
    }
}

extension AVAudioSessionRouteDescription {
    var prettyOneLine: String {
        let ins = inputs.map(\.pretty).joined(separator: ", ")
        let outs = outputs.map(\.pretty).joined(separator: ", ")
        return "inputs=[\(ins)] outputs=[\(outs)]"
    }
}

extension AVAudioSessionRouteDescription? {
    var prettyOneLine: String { self?.prettyOneLine ?? "nil" }
}

extension AVAudioSession.RouteChangeReason {
    var pretty: String {
        switch self {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory:
            return "noSuitableRouteForCategory"
        case .routeConfigurationChange:
            return "routeConfigurationChange"
        @unknown default:
            return "unknownDefault"
        }
    }

    var prettyWithRaw: String { "\(pretty)(\(rawValue))" }
}

extension AudioEngineAvailability {
    static let onlyOutput = AudioEngineAvailability(isInputAvailable: false, isOutputAvailable: true)

    var pretty: String {
        let mode = switch (isInputAvailable, isOutputAvailable) {
        case (false, false):
            "none"
        case (true, true):
            "default"
        case (false, true):
            "onlyOutput"
        case (true, false):
            "onlyInput"
        }

        return mode
    }
}
