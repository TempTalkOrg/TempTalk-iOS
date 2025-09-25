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

@objc
public class DTRTCAudioSession: NSObject {
    // Force singleton access
    @objc public static let shared = DTRTCAudioSession()

    private let session = LKRTCAudioSession.sharedInstance()

    private let delegateHandler = InternalRTCDelegate()

    private weak var observer: DTRTCAudioSessionObserver?

    private var activeObjects = NSHashTable<AnyObject>.weakObjects()

    private let rtcConf = AudioSessionConfiguration(
        category: OWSAudioSession.shared.rtcCategory,
        categoryOptions: OWSAudioSession.shared.rtcCategoryOptions,
        mode: OWSAudioSession.shared.rtcMode
    )

    private var timer: Timer?
    private var isObservering = false
    private var lastStatus: (AVAudioSession.Port, Bool)?
    private weak var currentStartTimerObj: AnyObject?

    let _state = StateSync(State())

    private override init() {
        super.init()

        delegateHandler.addOutSession(self)
        session.add(delegateHandler)
        //        do {
        //            try AudioManager.set(audioDeviceModuleType: .platformDefault)
        //        } catch {
        //            Logger.error("set audio device type failed with error: \(error)")
        //        }
        //        AudioManager.shared.customConfigureAudioSessionFunc = configureLivekit

        _state.onDidMutate = { new_, old_ in
            if new_.isPlayoutEnabled != old_.isPlayoutEnabled
                || new_.isRecordingEnabled != old_.isRecordingEnabled
            {
                self.configure(oldState: old_, newState: new_)
            }
        }

        AudioManager.shared.set(engineObservers: [
            self, AudioManager.shared.mixer,
        ])
        do {
            try AudioManager.shared.set(microphoneMuteMode: .inputMixer)
        } catch {
            Logger.error("set microphoneMuteMode failed with error: \(error)")
        }
    }

    deinit {
        session.remove(delegateHandler)
    }

    @objc
    public func callkitConfig() {
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        Logger.info("step1: active: \(session.isActive)")

        do {
            try session.setCategory(rtcConf.category)
            //    try session.setConfiguration(
            //        rtcConf.toRTCType(),
            //        active: true
            //    )
            //    let speaker = !isExternalConnected()

            //    Logger.info("step2: overrideOutput speaker: \(speaker)")
            //    try session.overrideOutputAudioPort(speaker ? .speaker : .none)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    @objc
    func callkitDidActivateAudioSession(_ audioSession: AVAudioSession) {
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        Logger.info(
            "active: \(session.isActive)"
        )

        session.audioSessionDidActivate(audioSession)
    }

    @objc
    func callkitDidDeactivateAudioSession(_ audioSession: AVAudioSession) {
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        Logger.info(
            "active: \(session.isActive)"
        )

        do {
            //            try session.setActive(false)

            // TODO(webrtc?BUG): replace audioSessionDidDeactivate by setActive to false
            //session.audioSessionDidDeactivate(audioSession)
            try session.setActive(false)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    public func connectRoomConfig(_ obj: AnyObject) {
        objc_sync_enter(self)
        session.lockForConfiguration()

        defer {
            session.unlockForConfiguration()
            objc_sync_exit(self)
        }

        let hasObj = activeObjects.contains(obj)

        Logger.info(
            "step1: active: \(session.isActive) hasObj=\(hasObj) obj=\(Unmanaged.passUnretained(obj).toOpaque())"
        )

        if hasObj {
            return
        }
        activeObjects.add(obj)

        do {
            try session.setConfiguration(
                rtcConf.toRTCType(),
                active: true
            )
            var speaker = !isExternalConnected()

            if DTMeetingManager.shared.currentCall.callType == .private {
                speaker = false
            }

            Logger.info("step2: overrideOutput speaker: \(speaker)")
            try session.overrideOutputAudioPort(speaker ? .speaker : .none)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    public func disconnectRoomConfig(_ obj: AnyObject) {
        objc_sync_enter(self)
        session.lockForConfiguration()

        defer {
            session.unlockForConfiguration()
            objc_sync_exit(self)
        }

        let hasObj = activeObjects.contains(obj)

        Logger.info(
            "active: \(session.isActive) hasObj=\(hasObj) obj=\(Unmanaged.passUnretained(obj).toOpaque())"
        )

        if !hasObj {
            return
        }

        activeObjects.remove(obj)

        do {
            // 如果是活跃的才设置为false
            if session.isActive {
                try session.setActive(false)
            }
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    public func switchToSpeaker(_ speaker: Bool) {
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        Logger.info("speaker: \(speaker)")

        do {
            //            try session.setConfiguration(rtcConf.toRTCType())
            try session.overrideOutputAudioPort(speaker ? .speaker : .none)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }
}

// MARK status
extension DTRTCAudioSession {
    @objc
    public func currentOutputType() -> AVAudioSession.Port {
        return session.currentRoute.outputs.first?.portType ?? .builtInSpeaker
    }

    @objc
    public func currentInputPortName() -> String {
        return session.currentRoute.inputs.first?.portName ?? ""
    }

    @objc
    public func isUsingExternalOutput() -> Bool {
        return session.currentRoute.outputs.contains {
            (output: AVAudioSessionPortDescription) in
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
                return true
            default:
                return false
            }
        }
    }

    @objc
    public func isExternalDeviceConnected() -> Bool {
        var isConnected = false

        if let availableInputs = session.session.availableInputs {
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
                    return true
                default:
                    return false
                }
            }
        }

        return isConnected
    }

    func audioSessionDidChangeRoute(
        _ inSession: LKRTCAudioSession,
        reason: AVAudioSession.RouteChangeReason,
        previousRoute: AVAudioSessionRouteDescription
    ) {

        if inSession != session {
            return
        }

        Logger.info(
            "audioRouteChanged: reason=\(reason), previousRoute=\(previousRoute)"
        )

        DispatchQueue.global().async { [self] in
            checkOutputStatus()
            checkInputStatus()
        }
    }

    func isExternalConnected() -> Bool {
        if isUsingExternalOutput() {
            return true
        } else {
            return isExternalDeviceConnected()
        }
    }

    func checkOutputStatus() {
        let portType = currentOutputType()
        let isExternalConnected = isExternalConnected()

        let currentStatus = (portType, isExternalConnected)
        if let lastStatus, lastStatus == currentStatus {
            return
        }

        lastStatus = currentStatus

        notifyObservers(portType, isExternalConnected: isExternalConnected)
    }

    func checkInputStatus() {
        let portName = currentInputPortName()
        let isExternalConnected = isExternalConnected()
        notifyObservers(portName, isExternalConnected: isExternalConnected)
    }

}

// MARK Timer Observer
extension DTRTCAudioSession {
    func startObserving(_ obj: AnyObject) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard !isObservering else { return }

        Logger.info(
            "timer start: obj=\(Unmanaged.passUnretained(obj).toOpaque())"
        )

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
        DispatchQueue.global().async { [self] in
            checkOutputStatus()
            checkInputStatus()
        }
    }

    func stopObserving(_ obj: AnyObject) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info(
            "timer stop: obj=\(Unmanaged.passUnretained(obj).toOpaque())"
        )

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

// MARK Observer
extension DTRTCAudioSession {
    @objc
    public func addObserver(_ observer: DTRTCAudioSessionObserver) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        self.observer = observer
    }

    @objc
    public func removeObserver(_ observer: DTRTCAudioSessionObserver) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if observer === self.observer {
            self.observer = nil
        }
    }

    @objc
    public func checkRouterIsSpeaker() -> Bool {
        return currentOutputType() == .builtInSpeaker
    }

    private func notifyObservers(
        _ portType: AVAudioSession.Port,
        isExternalConnected: Bool
    ) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let observer = self.observer else { return }

        observer.audioSessionDidChangePortType(
            portType,
            isExternalConnected: isExternalConnected
        )
    }

    private func notifyObservers(
        _ portName: String,
        isExternalConnected: Bool
    ) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let observer = self.observer else { return }

        observer.audioSessionDidChangePortName(
            portName,
            isExternalConnected: isExternalConnected
        )
    }

    class InternalRTCDelegate: NSObject, LKRTCAudioSessionDelegate {
        private weak var parentRTCSession: DTRTCAudioSession?

        fileprivate func addOutSession(_ parentRTCSession: DTRTCAudioSession) {
            self.parentRTCSession = parentRTCSession
        }

        func audioSessionDidChangeRoute(
            _ session: LKRTCAudioSession,
            reason: AVAudioSession.RouteChangeReason,
            previousRoute: AVAudioSessionRouteDescription
        ) {
            parentRTCSession?.audioSessionDidChangeRoute(
                session,
                reason: reason,
                previousRoute: previousRoute
            )
        }
    }
}

// MARK AudioManager
extension DTRTCAudioSession {
    @Sendable
    func configureLivekit(
        newState: AudioManager.State,
        oldState: AudioManager.State
    ) {
        let configuration: AudioSessionConfiguration = {
            switch newState.trackState {
            case .none:
                return .soloAmbient
            default:
                return rtcConf
            }
        }()

        var setActive: Bool?
        if newState.trackState != .none, oldState.trackState == .none {
            setActive = true
        } else if newState.trackState == .none, oldState.trackState != .none {
            setActive = false
        }

        let session = LKRTCAudioSession.sharedInstance()
        guard configuration != session.toAudioSessionConfiguration() else {
            Logger.info(
                "Skipping configure audio session, no changes(sessionActive: \(session.isActive)): \(String(describing: configuration))"
            )
            return
        }

        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        do {
            Logger.info(
                "Configuring audio session(sessionActive: \(session.isActive)): active: \(String(describing: setActive)), \(String(describing: configuration))"
            )

            if let setActive {
                // 如果已经不活跃了，就不需要设置false
                if !setActive && !session.isActive {
                    try session.setConfiguration(configuration.toRTCType())
                } else {
                    try session.setConfiguration(
                        configuration.toRTCType(),
                        active: setActive
                    )
                }
            } else {
                try session.setConfiguration(configuration.toRTCType())
            }
        } catch {
            Logger.error(
                "Failed to configure audio session with error: \(error)"
            )
        }
    }
}

// MARK AudioSessionEngineObserver
extension DTRTCAudioSession: AudioEngineObserver, @unchecked Sendable {
    struct State: Sendable {
        var next: (any AudioEngineObserver)?

        var isPlayoutEnabled: Bool = false
        var isRecordingEnabled: Bool = false
    }

    public var next: (any AudioEngineObserver)? {
        get { _state.next }
        set { _state.mutate { $0.next = newValue } }
    }

    @Sendable func configure(oldState: State, newState: State) {
        let session = LKRTCAudioSession.sharedInstance()

        session.lockForConfiguration()
        defer {
            session.unlockForConfiguration()
            Logger.info(
                "AudioSession activationCount: \(session.activationCount), webRTCSessionCount: \(session.webRTCSessionCount)"
            )
        }

        if (!newState.isPlayoutEnabled && !newState.isRecordingEnabled)
            && (oldState.isPlayoutEnabled || oldState.isRecordingEnabled)
        {
            do {
                Logger.info("AudioSession deactivating...")
                try session.setActive(false)
            } catch {
                Logger.error(
                    "AudioSession failed to deactivate with error: \(error)"
                )
            }
        } else if newState.isRecordingEnabled || newState.isPlayoutEnabled {
            let config = rtcConf

            do {
                Logger.info(
                    "AudioSession configuring category to: \(config.category)"
                )
                try session.setConfiguration(config.toRTCType())
            } catch {
                Logger.error(
                    "AudioSession failed to configure with error: \(error)"
                )
            }

            if !oldState.isPlayoutEnabled, !oldState.isRecordingEnabled {
                do {
                    Logger.info("AudioSession activating...")
                    try session.setActive(true)
                } catch {
                    Logger.error(
                        "AudioSession failed to activate AudioSession with error: \(error)"
                    )
                }
            }
        }
    }

    public func engineWillEnable(
        _ engine: AVAudioEngine,
        isPlayoutEnabled: Bool,
        isRecordingEnabled: Bool
    ) -> Int {
        _state.mutate {
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
        }

        // Call next last
        return _state.next?.engineWillEnable(
            engine,
            isPlayoutEnabled: isPlayoutEnabled,
            isRecordingEnabled: isRecordingEnabled
        ) ?? 0
    }

    public func engineDidDisable(
        _ engine: AVAudioEngine,
        isPlayoutEnabled: Bool,
        isRecordingEnabled: Bool
    ) -> Int {
        // Call next first
        let nextResult = _state.next?.engineDidDisable(
            engine,
            isPlayoutEnabled: isPlayoutEnabled,
            isRecordingEnabled: isRecordingEnabled
        )

        _state.mutate {
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
        }

        return nextResult ?? 0
    }
}

// Mark for livekit
extension LKRTCAudioSession {
    fileprivate func toAudioSessionConfiguration() -> AudioSessionConfiguration
    {
        AudioSessionConfiguration(
            category: AVAudioSession.Category(rawValue: category),
            categoryOptions: categoryOptions,
            mode: AVAudioSession.Mode(rawValue: mode)
        )
    }
}

extension AudioSessionConfiguration {
    fileprivate func toRTCType() -> LKRTCAudioSessionConfiguration {
        let configuration = LKRTCAudioSessionConfiguration.webRTC()
        configuration.category = category.rawValue
        configuration.categoryOptions = categoryOptions
        configuration.mode = mode.rawValue
        return configuration
    }
}
