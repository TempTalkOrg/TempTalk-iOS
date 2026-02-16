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

    private static let callkitUseVideoMode = false

    private let session = AVAudioSession.sharedInstance()

    private weak var observer: DTRTCAudioSessionObserver?

    private var activeObjects = NSHashTable<AnyObject>.weakObjects()

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

    private let rtcConfPlayback = AudioSessionConfiguration(
        category: OWSAudioSession.shared.rtcCategoryPlayBack,
        categoryOptions: OWSAudioSession.shared.rtcCategoryMixOnlyOptions,
        mode: OWSAudioSession.shared.rtcModeSpoken
    )

    private var timer: Timer?
    private var isObservering = false
    private var lastStatus: (AVAudioSession.Port, Bool)?
    private weak var currentStartTimerObj: AnyObject?

    let _state = StateSync(State())
    private var isForceSetConfig: Bool?

    private var routeChangeToken: NSObjectProtocol?
    private var hasCalledDisconnect: Bool = false
    private var hasInCalling: Bool = false

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

            let stateChanged = (new_.isPlayoutEnabled != old_.isPlayoutEnabled) ||
                (new_.isRecordingEnabled != old_.isRecordingEnabled) ||
                (new_.isSpeakerOutputPreferred != old_.isSpeakerOutputPreferred)

            if (new_.isAutomaticConfigurationEnabled && stateChanged) || forceSet {
                self.configure(oldState: old_, newState: new_, forceSet: forceSet)
            }
        }

        AudioManager.shared.set(engineObservers: [self, AudioManager.shared.mixer])

        do {
            try AudioManager.shared.set(microphoneMuteMode: .inputMixer)
            Logger.info("set microphoneMuteMode \".inputMixer\" success")
        } catch {
            Logger.error("set microphoneMuteMode failed with error: \(error)")
        }

        setAudioManagerEngineAvailability(false, "RTC init")
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

        Logger.info("step1: speaker: \(speaker), hasInCalling: \(hasInCalling), activeObjects.count: \(activeObjects.count)")

        isAutomaticConfigurationEnabled = false
        setAudioManagerEngineAvailability(false, "callkit receive call")

        do {
            let config = if speaker, Self.callkitUseVideoMode {
                rtcConfVideo
            } else {
                rtcConfVoice
            }
            Logger.info("AudioSession configuring category to: \(config)")
            try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    @objc
    public func callkitStartCall(_ speaker: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("step1: speaker: \(speaker), hasInCalling: \(hasInCalling), activeObjects.count: \(activeObjects.count)")

        isAutomaticConfigurationEnabled = false
        setAudioManagerEngineAvailability(false, "callkit start call")

        do {
            let config = if speaker, Self.callkitUseVideoMode {
                rtcConfVideo
            } else {
                rtcConfVoice
            }
            Logger.info("AudioSession configuring category to: \(config)")
            try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    @objc
    public func callkitHandleCall(_ answer: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.info("step2: answer: \(answer), hasInCalling: \(hasInCalling)")
        // do nothing
    }

    @objc
    func callkitDidActivateAudioSession(_: AVAudioSession, speaker: Bool) {
        Logger.info("step3: speaker: \(speaker), hasInCalling: \(hasInCalling), activeObjects.count: \(activeObjects.count)")

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        isAutomaticConfigurationEnabled = false

        do {
            let config = if speaker, Self.callkitUseVideoMode {
                rtcConfVideo
            } else {
                rtcConfVoice
            }
            Logger.info("AudioSession configuring category to: \(config)")
            try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
        } catch {
            Logger.error("failed with error: \(error)")
        }

        if !Self.callkitUseVideoMode {
            do {
                Logger.info("AudioSession overrideOutputAudioPort(\(speaker))...")
                try session.overrideOutputAudioPort(speaker ? .speaker : .none)
            } catch {
                Logger.error("AudioSession failed to overrideOutputAudioPort(\(speaker)) with error: \(error)")
            }
        }

        setAudioManagerEngineAvailability(true, "callkit active audio session")

        Task {
            // 解决没有本地没有开启mic采集的时候无法播放其他人声音， only for inputMixer
            await setAudioManagerRecordingAlwaysPreparedMode(true, "callkit active audio session")
        }

        Logger.info("step3: speaker: \(speaker) end")
    }

    @objc
    func callkitDidDeactivateAudioSession(_: AVAudioSession) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        setAudioManagerEngineAvailability(false, "callkit deactive audio session")
    }

    public func connectRoomConfig(_ obj: AnyObject, fromCallKit: Bool) async {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let hasObj = activeObjects.contains(obj)

        Logger.info("fromCallKit: \(fromCallKit) hasObj=\(hasObj) obj=\(Unmanaged.passUnretained(obj).toOpaque())")

        guard !hasObj else { return }

        activeObjects.add(obj)

        let speaker = DTMeetingManager.shared.currentCall.callType != .private

        Logger.info("speaker: \(speaker), hasInCalling: \(hasInCalling)")

        _state.mutate {
            $0.isAutomaticConfigurationEnabled = !fromCallKit
            $0.isSpeakerOutputPreferred = speaker
            hasCalledDisconnect = false
            // 这样可以正确处理多个会议同时存在的情况
            hasInCalling = (activeObjects.count > 0)
        }

        if fromCallKit { return }

        setAudioManagerEngineAvailability(true, "pre connect room")
        // 解决没有本地没有开启mic采集的时候无法播放其他人声音， only for inputMixer
        await setAudioManagerRecordingAlwaysPreparedMode(true, "pre connect room")
    }

    public func disconnectRoomConfig(_ obj: AnyObject) async {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let hasObj = activeObjects.contains(obj)

        Logger.info("hasObj=\(hasObj) obj=\(Unmanaged.passUnretained(obj).toOpaque())")

        guard hasObj else { return }

        activeObjects.remove(obj)

        hasCalledDisconnect = true

        let stillHasActiveCalls = (activeObjects.count > 0)
        hasInCalling = stillHasActiveCalls

        if !stillHasActiveCalls {
            await setAudioManagerRecordingAlwaysPreparedMode(false, "disconnect room - no more calls")
        }
    }

    public func switchToSpeaker(_ speaker: Bool) {
        Logger.info("speaker: \(speaker)")

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
                do {
                    Logger.info("switchToSpeaker overrideOutputAudioPort(\(speaker))...")
                    try session.overrideOutputAudioPort(speaker ? .speaker : .none)
                } catch {
                    Logger.error("switchToSpeaker failed to overrideOutputAudioPort(\(speaker)) with error: \(error)")
                }
            }
        }
    }

    private func setAudioManagerEngineAvailability(_ enable: Bool, _ reason: String) {
        do {
            try AudioManager.shared.setEngineAvailability(enable ? .default : .none)
            Logger.info("setEngineAvailability success: \(enable ? ".default" : ".none"), reason=\(reason)")
        } catch {
            Logger.error("setEngineAvailability failed with error: \(enable ? ".default" : ".none"), reason=\(reason), error=\(error)")
        }
    }

    private func setAudioManagerRecordingAlwaysPreparedMode(_ enable: Bool, _ reason: String) async {
        do {
            Logger.info("setRecordingAlwaysPreparedMode beg: \(enable), reason=\(reason)")
            try await AudioManager.shared.setRecordingAlwaysPreparedMode(enable)
            Logger.info("setRecordingAlwaysPreparedMode end success: \(enable), reason=\(reason)")
        } catch {
            Logger.error("setRecordingAlwaysPreparedMode end failed with error: \(enable), reason=\(reason), error=\(error)")
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
        var usePlaybackWhenNotRecording: Bool = true
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

    @Sendable func configure(oldState: State, newState: State, forceSet: Bool) {
        if (!newState.isPlayoutEnabled && !newState.isRecordingEnabled)
            && (oldState.isPlayoutEnabled || oldState.isRecordingEnabled)
        {
            if newState.isAutomaticDeactivationEnabled {
                do {
                    if hasCalledDisconnect {
                        do {
                            let config = rtcConfPlayback
                            Logger.info("AudioSession deactive configuring category to: \(config)")
                            try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
                        } catch {
                            Logger.error("AudioSession deactive failed to configure with error: \(error)")
                        }
                    }

                    Logger.info("AudioSession deactivating...")
                    try session.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    Logger.error("AudioSession failed to deactivate with error: \(error)")
                }
            } else {
                Logger.info("AudioSession deactivation skipped...")
            }
        } else if newState.isRecordingEnabled || newState.isPlayoutEnabled {
            let playAndRecord = newState.isSpeakerOutputPreferred ? rtcConfVideo : rtcConfVoice
            let config: AudioSessionConfiguration = if newState.isRecordingEnabled {
                playAndRecord
            } else if newState.usePlaybackWhenNotRecording {
                rtcConfPlayback
            } else {
                playAndRecord
            }

            do {
                Logger.info("AudioSession configuring category to: \(config)")
                try session.setCategory(config.category, mode: config.mode, options: config.categoryOptions)
            } catch {
                Logger.error("AudioSession failed to configure with error: \(error)")
            }

            if !oldState.isPlayoutEnabled, !oldState.isRecordingEnabled {
                do {
                    Logger.info("AudioSession activating...")
                    try session.setActive(true)
                } catch {
                    Logger.error("AudioSession failed to activate AudioSession with error: \(error)")
                }
            }

            // 修复使用了系统音频路由切换[AVRoutePickerView], 仅设置setConfiguration不会切换的问题
            if config != rtcConfPlayback, newState.isEngineWillEnable == true, newState.isSpeakerOutputPreferred == oldState.isSpeakerOutputPreferred, forceSet {
                do {
                    Logger.info("AudioSession overrideOutputAudioPort(\(newState.isSpeakerOutputPreferred))...")
                    try session.overrideOutputAudioPort(newState.isSpeakerOutputPreferred ? .speaker : .none)
                } catch {
                    Logger.error("AudioSession failed to overrideOutputAudioPort(\(newState.isSpeakerOutputPreferred)) with error: \(error)")
                }
            }
        }
    }

    public func engineWillEnable(_ engine: AVAudioEngine, isPlayoutEnabled: Bool, isRecordingEnabled: Bool) -> Int {
        // session 配置需要在这个方法之前完成，否则可能错误导致没有声音
        Logger.info("engineWillEnable beg: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled)")
        _state.mutate {
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
            $0.isEngineWillEnable = true
        }
        Logger.info("engineWillEnable end: isPlayoutEnabled=\(isPlayoutEnabled) isRecordingEnabled=\(isRecordingEnabled)")

        // Call next last
        return _state.next?.engineWillEnable(engine, isPlayoutEnabled: isPlayoutEnabled, isRecordingEnabled: isRecordingEnabled) ?? 0
    }

    public func engineDidDisable(_ engine: AVAudioEngine, isPlayoutEnabled: Bool, isRecordingEnabled: Bool) -> Int {
        // Call next first
        let nextResult = _state.next?.engineDidDisable(engine, isPlayoutEnabled: isPlayoutEnabled, isRecordingEnabled: isRecordingEnabled)

        _state.mutate {
            $0.isPlayoutEnabled = isPlayoutEnabled
            $0.isRecordingEnabled = isRecordingEnabled
            $0.isEngineWillEnable = false
        }

        return nextResult ?? 0
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
