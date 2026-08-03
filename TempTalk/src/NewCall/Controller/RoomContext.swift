/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import AVFoundation
import AudioPipelineProcessor
import DTProto
import Foundation
import LiveKit
import SwiftUI
import UIKit

/// 错误处理状态，用于协调 connect() 和 delegate 回调之间的错误处理
enum ErrorHandlingState {
    case idle // 空闲，可以处理新错误
    case retrying // 正在重试连接（切换域名）
    case handled // 错误已被处理，不需要重复处理
}

@MainActor
final class RoomContext: ObservableObject, DTRTCAudioSessionObserver, TTEncryptor {
    // MARK: - Constants / Utilities

    let logTag: String = "[newcall]"

    // JSON encoders/decoders — these are used only on main actor in this class
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    // Default states
    let default1on1MicphoneState: Bool = true
    let defaultGroupMicphoneState: Bool = false
    let defaultCameraState: Bool = false

    // Use singleton computed property (avoids weak-init issues)
    var callManager: DTMeetingManager { DTMeetingManager.shared }

    // Computed currentCall (falls back to empty model)
    var currentCall: DTLiveKitCallModel {
        callManager.currentCall
    }

    // Used to show connection error dialog
    @Published var shouldShowDisconnectReason: Bool = false
    var latestError: LiveKitError?

    let room = Room()

    private let audioProcessor = CallAudioDiagnosticsProcessor()
    private var _denoiseEnabled: Bool = true

    @Published var currentAttempt: ConnectionAttempt?

    /// 仅日志/调试用；TLS 校验请用 `currentAttempt?.serverHost`。
    var url: String { currentAttempt?.connectUrl ?? "" }

    @Published var token: String = ""
    @Published var e2eeKey: Data?

    // UI / participants
    @Published var focusParticipant: Participant?
    @Published var othersideParticipantFor1on1: Participant?

    @Published var textFieldString: String = ""
    @Published var screenSharePublication: TrackPublication? = nil
    var screenShareParticipant: RemoteParticipant?

    // Tasks
    private var _connectTask: Task<Void, Error>?
    // 是否已经请求断开，防止换域名重连在挂断后继续执行
    private var shouldAbortConnect: Bool = false

    // 连接互斥锁，确保 room.connect 调用是互斥的
    private var isConnecting: Bool = false

    // 错误处理状态，用于协调 connect() 和 delegate 回调
    private(set) var errorHandlingState: ErrorHandlingState = .idle

    // ViewControllers held while presented
    var shareVC: UIViewController? {
        didSet { _shareVCWeakRef = shareVC }
    }
    private weak var _shareVCWeakRef: UIViewController?
    var inviteVC: UIViewController?
    var noiseVC: UIViewController?

    private var lkContext: LiveKitContext?

    var lastPortName: String?

    // Active speaker: set immediately, cleared after resetDelay
    nonisolated(unsafe) weak var currentActiveSpeaker: Participant?
    var lastSpeakerIdentities: Set<String> = []
    var activeSpeakerWorkItem: DispatchWorkItem?
    var resetToDefaultWorkItem: DispatchWorkItem?
    let activeSpeakerDelay: TimeInterval = 0.4
    let resetDelay: TimeInterval = 2.5

    var connectTimeoutTask: Task<Void, Never>?
    var unpublishScreenShareTask: Task<Void, Never>?
    // 是否正在展示 screen share
    var isPresentingShareView = false
    // 是否存在待展示的UI
    var pendingShowUI = false
    var didHandleInitialRoomDidConnect = false
    var didHandleInitialRoomAudioSetup = false
    var didCompleteInitialRoomAudioSetup = false
    var isApplyingInitialRoomAudioSetup = false
    var deferredInitialRoomAudioSetupForCallKit = false
    @Published var isRoomReconnecting: Bool = false

    /// Remote identities we've already surfaced a "mic on" bullet for, until they mute
    /// or genuinely leave. Deduplicates the mic-on bullet across its two triggers
    /// (first subscribe of an already-unmuted track, and the mute→unmute transition)
    /// and — crucially — across every reconnect variant: a `isRoomReconnecting` guard is
    /// unreliable (a full reconnect clears it before staggered re-subscribes land, and a
    /// server switch re-subscribes existing unmuted tracks with no mute transition), which
    /// would otherwise re-bullet every remote. Only mutated on the MainActor.
    var micOnBulletedRemoteIdentities: Set<String> = []

    // MARK: - Init / Deinit

    init(token: String, lkContext: LiveKitContext?) {
        AudioManager.shared.capturePostProcessingDelegate = audioProcessor

        if let cachedMode = CallSettingsManager.shared.getDenoiseMode() {
            audioProcessor.activeModule = cachedMode == "enhanced" ? .deepfilternet : .rnnoise
        } else {
            let callConfig = CallConfigManager.fetchCallConfig()
            audioProcessor.activeModule = callConfig.denoiseMode == "enhanced" ? .deepfilternet : .rnnoise
        }

        loadDefaultVoicePresetFromSettings()

        room.add(delegate: self)

        self.token = token
        e2eeKey = e2eeKey
        self.lkContext = lkContext
        // callManager 不需要在 init 中赋 weak；使用计算属性访问单例

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        DTRTCAudioSession.shared.addObserver(self)

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Cancel any pending delayed dismiss so it won't race with the
                // present logic below and cause a flash (present → delayed dismiss).
                self.unpublishScreenShareTask?.cancel()
                self.unpublishScreenShareTask = nil

                let hadPendingShareUI = self.pendingShowUI
                self.pendingShowUI = false

                // Use room's actual state as the single source of truth to avoid
                // acting on stale pendingShowUI / screenSharePublication references.
                let roomHasActiveShare = self.room.isScreenShareActive()

                if hadPendingShareUI, roomHasActiveShare {
                    Logger.info("\(self.logTag) RoomContext become active retry show share view")
                    self.tryPresentShareView(maxRetryCount: 0)
                } else if hadPendingShareUI, !roomHasActiveShare {
                    Logger.info("\(self.logTag) RoomContext become active but screen share already ended, skip present")
                    self.screenSharePublication = nil
                    self.screenShareParticipant = nil
                }

                self.checkAndPresentScreenShareIfNeeded()

                if #available(iOS 16, *) {
                    if self.isShareViewPresented {
                        let callWindow = OWSWindowManager.shared().callViewWindow
                        callWindow.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                    }
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .ScreenLockDidUnlock,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hadPendingShareUI = self.pendingShowUI
                self.pendingShowUI = false

                if hadPendingShareUI {
                    Logger.info("\(self.logTag) Screen unlocked, presenting deferred share view")
                    self.tryPresentShareView(maxRetryCount: 3)
                }
            }
        }
    }

    deinit {
        Logger.info("\(logTag) RoomContext deinit")

        // 清理资源
        _connectTask?.cancel()
        _connectTask = nil
        unpublishScreenShareTask?.cancel()
        unpublishScreenShareTask = nil

        // 移除观察者
        DTRTCAudioSession.shared.removeObserver(self)
        NotificationCenter.default.removeObserver(self)

        // 清理音频处理, 由于deinit的触发时机不可控，这里避免清理新的降噪库导致降噪不生效
        if let currentDelegate = AudioManager.shared.capturePostProcessingDelegate as AnyObject?,
           currentDelegate === audioProcessor
        {
            Logger.info("\(logTag) clear audio processor from audio manager")
            AudioManager.shared.capturePostProcessingDelegate = nil
        } else {
            Logger.info("\(logTag) this audio processor not same as audio manager's, skip clear")
        }

        let strongShareVC = shareVC
        let weakShareVC = _shareVCWeakRef
        let capturedShareVC = strongShareVC ?? weakShareVC
        let capturedInviteVC = inviteVC
        let capturedNoiseVC = noiseVC

        DispatchQueue.main.async {
            capturedInviteVC?.view.endEditing(true)
            capturedShareVC?.dismiss(animated: false)
            capturedInviteVC?.dismiss(animated: false)
            capturedNoiseVC?.dismiss(animated: false)
        }

        // 恢复设备状态
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif

        Logger.info("\(logTag) RoomContext deinit completed")
    }

    // MARK: - Public API

    func cancelConnect() {
        shouldAbortConnect = true
        _connectTask?.cancel()
        _connectTask = nil
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        unpublishScreenShareTask?.cancel()
        unpublishScreenShareTask = nil
        isConnecting = false
        // 取消连接时标记为已处理，防止后续 delegate 回调触发清理
        markHandled()
    }

    func resetErrorHandlingState() {
        errorHandlingState = .idle
    }

    func markHandled() {
        errorHandlingState = .handled
    }

    func markRetrying() {
        errorHandlingState = .retrying
    }

    /// 单次建链。多 attempt 切换 / 重试由 `CallConnectionCoordinator` 接管。
    @MainActor
    func connect(fromCallKit: Bool,
                 attempt: ConnectionAttempt,
                 baseConnectOptions: ConnectOptions) async throws -> Room {
        guard !shouldAbortConnect else {
            Logger.info("\(logTag) room.connect aborted because disconnect was requested")
            throw CancellationError()
        }
        guard !isConnecting else {
            Logger.info("\(logTag) room.connect already in progress, skipping duplicate call")
            return room
        }
        Logger.info("\(logTag) room.connect fromCallKit: \(fromCallKit) url=\(attempt.connectUrl) serverHost=\(attempt.serverHost) quic=\(attempt.useQuic)")
        // Build connect options before mutating any state: withConnectionAttempt can throw (proxy
        // tunnel unavailable → fail closed). Doing it here means a throw exits with the room
        // untouched — no stuck isConnecting, no leaked audio-session observers.
        let cidTag = DTMeetingManager.quicCidTag(for: TSAccountManager.localNumber())
        let connectOptions = try baseConnectOptions.withConnectionAttempt(attempt, quicCidTag: cidTag)
        isConnecting = true
        currentAttempt = attempt
        // 开始新连接时重置错误处理状态
        resetErrorHandlingState()
        // Ensure audio session observations and config are active
        DTRTCAudioSession.shared.addObserver(self)
        await DTRTCAudioSession.shared.connectRoomConfig(self, fromCallKit: fromCallKit)
        DTRTCAudioSession.shared.startObserving(self)

        let keyProvider = BaseKeyProvider(isSharedKey: true, sharedKey: nil as Data?)
        let e2eeOptions = E2EEOptions(keyProvider: keyProvider, ttEncryptor: self)

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: .init(dimensions: .h720_169, fps: 30),
            defaultVideoPublishOptions: .init(
                encoding: VideoParameters.presetH1080_169.encoding,
                simulcast: true,
                preferredCodec: VideoCodec.vp8
            ),
            adaptiveStream: true,
            dynacast: true,
            stopLocalTrackOnUnpublish: false,
            e2eeOptions: e2eeOptions
        )

        let connectTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                guard !shouldAbortConnect else {
                    isConnecting = false
                    throw CancellationError()
                }

                try await room.connect(
                    url: attempt.connectUrl,
                    token: "",
                    connectOptions: connectOptions,
                    roomOptions: roomOptions
                )
                if shouldAbortConnect || Task.isCancelled {
                    isConnecting = false
                    await room.disconnect()
                    throw CancellationError()
                }
                isConnecting = false
            } catch is CancellationError {
                isConnecting = false
                throw CancellationError()
            } catch {
                isConnecting = false
                guard !shouldAbortConnect, !Task.isCancelled else {
                    throw CancellationError()
                }
                // 错误分类 / 切下一个 attempt 由 coordinator 处理
                throw error
            }
        }

        _connectTask = connectTask
        defer { _connectTask = nil }
        try await connectTask.value
        await handleInitialRoomDidConnect(source: "connectTask.value")
        return room
    }

    func disconnect(_ reason: String = #function) async {
        Logger.info("\(logTag): room disconnect by \"\(reason)\"")

        DTRTCAudioSession.shared.removeObserver(self)
        await DTRTCAudioSession.shared.disconnectRoomConfig(self)
        DTRTCAudioSession.shared.stopObserving(self)

        cancelConnect()

        // detached: 不在主线程 await room.disconnect()，防止 LiveKit SDK 内部 DispatchQueue.main.sync 与主线程 await 形成死锁
        await Task.detached { [room, logTag] in
            Logger.info("\(logTag): room.disconnect() started on background")
            await room.disconnect()
            Logger.info("\(logTag): room.disconnect() completed on background")
        }.value

        await MainActor.run {
            screenSharePublication = nil
            screenShareParticipant = nil

            dismissPresentedShareViewControllerIfNeeded()

            inviteVC?.dismiss(animated: false)
            inviteVC = nil

            noiseVC?.dismiss(animated: false)
            noiseVC = nil
        }

        Logger.info("\(logTag): room disconnect completed, cleared all view controllers")
    }

    func setLocalMicrophone(enable: Bool, publishMuted: Bool = false) async {
        _ = try? await room.localParticipant.setMicrophone(enabled: enable, publishMuted: publishMuted)
    }

    func syncLocalMicrophoneStateToCallKit(muted: Bool) {
        callManager.syncLocalMicrophoneStateToCallKit(muted)
    }

    func sendMessage() {
        // Make sure the message is not empty
        guard !textFieldString.isEmpty else { return }

        let roomMessage = ExampleRoomMessage(messageId: UUID().uuidString,
                                             senderSid: room.localParticipant.sid,
                                             senderIdentity: room.localParticipant.identity,
                                             text: textFieldString)
        textFieldString = ""

        Task { [weak self] in
            guard let self else { return }
            do {
                let json = try jsonEncoder.encode(roomMessage)
                try await room.localParticipant.publish(data: json)
            } catch {
                Logger.debug("Failed to encode data \(error)")
            }
        }
    }

    // MARK: - Present helpers

    @MainActor
    private func presentOnTop(_ vc: UIViewController, animated: Bool = false, completion: (() -> Void)? = nil) {
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.present(vc, animated: animated, completion: completion)
    }

    @MainActor
    func isShareViewController(_ viewController: UIViewController?) -> Bool {
        guard let viewController, let tracked = _shareVCWeakRef else { return false }
        return viewController === tracked
    }

    @MainActor
    func findPresentedShareViewController() -> UIViewController? {
        guard let vc = _shareVCWeakRef, vc.presentingViewController != nil else { return nil }
        return vc
    }

    @MainActor
    @discardableResult
    func syncShareViewReferenceIfNeeded() -> Bool {
        guard let existingShareVC = _shareVCWeakRef,
              existingShareVC.presentingViewController != nil else {
            return false
        }

        if shareVC !== existingShareVC {
            Logger.info("\(logTag) found existing screen share view controller, syncing reference")
            shareVC = existingShareVC
        }

        pendingShowUI = false
        return true
    }

    @MainActor
    var isShareViewPresented: Bool {
        if let vc = shareVC ?? _shareVCWeakRef {
            return vc.presentingViewController != nil
        }
        return false
    }

    @MainActor
    func hasActiveScreenShareToPresent() -> Bool {
        let roomActive = room.isScreenShareActive()
        if !roomActive {
            if screenSharePublication != nil {
                Logger.info("\(logTag) hasActiveScreenShareToPresent: false (stale publication cleared, roomActive: false)")
                screenSharePublication = nil
                screenShareParticipant = nil
            }
            return false
        }
        return true
    }

    @MainActor
    func resetSharePresentationState() {
        isPresentingShareView = false
        pendingShowUI = false
    }

    @MainActor
    func dismissPresentedShareViewControllerIfNeeded() {
        (shareVC ?? _shareVCWeakRef)?.dismiss(animated: false)
        shareVC = nil
        resetSharePresentationState()
    }

    @MainActor
    func presentShareView(completion: (() -> Void)? = nil) {
        syncShareViewReferenceIfNeeded()
        if isShareViewPresented {
            Logger.info("\(logTag) screen share view already exists, skipping present")
            completion?()
            return
        }

        // 检查应用状态，确保在前台
        guard CurrentAppContext().isMainAppAndActive else {
            Logger.info("\(logTag) app is not active")
            pendingShowUI = true
            return
        }

        presentShareViewVC(completion: completion)
    }

    @MainActor
    private func presentShareViewVC(completion: (() -> Void)? = nil) {
        if syncShareViewReferenceIfNeeded() {
            Logger.info("\(logTag) screen share view already presented, skip creating a new controller")
            completion?()
            return
        }

        let shareView = CallScreenShareView(minimizeAction: { [weak self] in
            guard let self else { return }
            toolbarMinimizeTaped()
        })
        .environmentObject(self)
        .environmentObject(self.room)
        let shareVC = DTHostingController(rootView: shareView)
        self.shareVC = shareVC
        shareVC.modalPresentationStyle = .fullScreen
        callManager.currentCall.isPresentedShare = true
        presentOnTop(shareVC, animated: false, completion: completion)
    }

    @MainActor
    func checkAndPresentScreenShareIfNeeded() {
        syncShareViewReferenceIfNeeded()

        // 先尝试从 room 恢复引用（返回前台后本地引用可能与 room 状态不同步）
        if screenSharePublication == nil || screenShareParticipant == nil {
            recoverScreenShareReferenceFromRoom()
        }

        // 防御性检查：恢复后仍判断屏幕共享已结束但视图仍存在，则 dismiss
        if !hasActiveScreenShareToPresent(), isShareViewPresented {
            if isRoomReconnecting {
                Logger.info("\(logTag) No active tracks but room is reconnecting - skipping premature dismiss")
            } else {
                Logger.info("\(logTag) Screen share ended but view still exists, dismissing")
                dismissShareViewIfNeeded()
                return
            }
        }

        guard let publication = screenSharePublication,
              let participant = screenShareParticipant,
              publication.source == .screenShareVideo
        else {
            Logger.info("\(logTag) No active screen share found")
            return
        }

        if !participant.isScreenShareEnabled() {
            Logger.info("\(logTag) Participant screen share not yet enabled (track may be resubscribing), still presenting share view")
        }

        if isShareViewPresented {
            refreshScreenShareReference()
            Logger.info("\(logTag) Screen share view already presented, refreshed reference")
            return
        }

        Logger.info("\(logTag) App became active, found screen share but view not presented - attempting to present")
        if !callManager.currentCall.isPresentedShare {
            callManager.currentCall.isPresentedShare = true
        }
        tryPresentShareView(maxRetryCount: 3)
    }

    /// 从 room 的远端参与者中恢复屏幕共享的 publication/participant 引用
    @MainActor
    private func recoverScreenShareReferenceFromRoom() {
        for participant in room.remoteParticipants.values {
            guard participant.isScreenShareEnabled() else { continue }
            for pub in participant.videoTracks where pub.source == .screenShareVideo {
                screenSharePublication = pub
                screenShareParticipant = participant
                Logger.info("\(logTag) Recovered screen share reference from room participant")
                return
            }
        }
    }

    @MainActor
    func refreshScreenShareReference() {
        recoverScreenShareReferenceFromRoom()
    }

    @MainActor
    func presentInviteView() {
        let inviteVC = DTCallInviteMemberVC()
        inviteVC.isLiveKitCall = true
        let inviteNav = OWSNavigationController(rootViewController: inviteVC)
        self.inviteVC = inviteNav
        presentOnTop(inviteNav, animated: false)
    }

    @MainActor
    func presentMuteActionSheet(_ participant: Participant) {
        guard DTMeetingManager.shared.openMuteOtherEnabled() else {
            Logger.info("\(logTag) remoteConfig not open muteOtherEnabled")
            return
        }

        let participantId = participant.identity?.stringValue ?? ""
        var actions = [ActionSheetAction]()
        let muteAction = ActionSheetAction(title: "Mute", style: .default) { _ in
            Task { @MainActor in
                await DTMeetingManager.shared.sendRemoteMicOffRoom(targetParticentId: participantId)
            }
        }
        actions.append(muteAction)

        let actionSheet = ActionSheetController()
        actionSheet.isDarkThemeOnly = true
        actionSheet.addAction(OWSActionSheets.cancelAction)
        actions.forEach { actionSheet.addAction($0) }
        presentOnTop(actionSheet, animated: true)
    }

    @MainActor
    func presentMuteAlertVC(_ participantId: String) {
        guard DTMeetingManager.shared.openMuteOtherEnabled() else {
            Logger.info("\(logTag) remoteConfig not open muteOtherEnabled")
            return
        }

        let muteAction = UIAlertAction(title: "Mute", style: .default) { _ in
            Task { @MainActor in
                await DTMeetingManager.shared.sendRemoteMicOffRoom(targetParticentId: participantId)
            }
        }

        var alertActions: [UIAlertAction] = []
        alertActions.append(muteAction)

        let alertVC = DTAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for action in alertActions {
            action.setValue(Theme.tinfoColor, forKey: "_titleTextColor")
            alertVC.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        cancelAction.setValue(Theme.tprimaryColor, forKey: "_titleTextColor")
        alertVC.addAction(cancelAction)

        presentOnTop(alertVC, animated: true)
    }

    @MainActor
    func presentHangupActionSheet() {
        if DTMeetingManager.shared.isPresentedShare() || DTMeetingManager.shared.showScreenShare() {
            var alertActions: [UIAlertAction] = []
            let endMeetingAction = UIAlertAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { [weak self] _ in
                Task { @MainActor in
                    await self?.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }
            endMeetingAction.setValue(UIColor.color(rgbHex: 0xD9271E), forKey: "_titleTextColor")
            alertActions.append(endMeetingAction)

            let leaveMeetingAction = UIAlertAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { [weak self] _ in
                Task { @MainActor in
                    await self?.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
            }
            leaveMeetingAction.setValue(UIColor.color(rgbHex: 0xEAECEF), forKey: "_titleTextColor")
            alertActions.append(leaveMeetingAction)

            let alertVC = DTAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            for action in alertActions {
                alertVC.addAction(action)
            }

            let cancelAction = UIAlertAction(title: Localized("HANGUP_CANCEL_MEETING"), style: .cancel) { _ in }
            cancelAction.setValue(UIColor.color(rgbHex: 0xEAECEF), forKey: "_titleTextColor")
            alertVC.addAction(cancelAction)

            presentOnTop(alertVC, animated: true)

        } else {
            let actionSheet = ActionSheetController()
            actionSheet.isDarkThemeOnly = true

            let endMeetingAction = ActionSheetAction(title: Localized("HANGUP_END_MEETING"), accessibilityIdentifier: DTCallAccessibilityID.endForAll, style: .destructive) { [weak self] _ in
                Task { @MainActor in
                    await self?.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }

            let leaveMeetingAction = ActionSheetAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { [weak self] _ in
                Task { @MainActor in
                    await self?.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
            }

            actionSheet.addAction(OWSActionSheets.cancelAction)
            actionSheet.addAction(endMeetingAction)
            actionSheet.addAction(leaveMeetingAction)
            presentOnTop(actionSheet, animated: true)
        }
    }

    func setDenoiseFilter(enabled: Bool) {
        _denoiseEnabled = enabled
        audioProcessor.setDenoiseEnabled(enabled)
    }

    func isDenoiseFilterEnabled() -> Bool {
        _denoiseEnabled
    }

    func setAudioModule(_ module: AudioModule) {
        audioProcessor.activeModule = module
        CallSettingsManager.shared.updateDenoiseMode(module == .deepfilternet ? "enhanced" : "standard")
        NotificationCenter.default.post(name: .denoiseModeDidChange, object: nil)
    }

    func currentAudioModule() -> AudioModule {
        audioProcessor.activeModule
    }

    func beginLocalAudioDiagnostics(reason: String) {
        audioProcessor.beginLoggingWindow(reason: reason)
    }

    func endLocalAudioDiagnostics(reason: String) {
        audioProcessor.endLoggingWindow(reason: reason)
    }

    func restartLocalAudioDiagnostics(reason: String) {
        audioProcessor.endLoggingWindow(reason: reason)
        audioProcessor.beginLoggingWindow(reason: reason)
    }

    // MARK: - Voice Changer

    private var _currentVoicePreset: String = "original"

    func setVoiceChangerPreset(_ preset: String) {
        _currentVoicePreset = preset
        audioProcessor.setSoundTouchPreset(preset)
        NotificationCenter.default.post(name: .voiceChangerPresetDidChange, object: nil)
    }

    func currentVoicePreset() -> String {
        _currentVoicePreset
    }

    // 进入会议时优先读取设置里的默认变声预设；未设置则回退到 CallSettingsManager.defaultVoicePreset
    fileprivate func loadDefaultVoicePresetFromSettings() {
        let savedPreset = CallSettingsManager.shared.getVoicePreset() ?? CallSettingsManager.defaultVoicePreset
        _currentVoicePreset = savedPreset
        audioProcessor.setSoundTouchPreset(savedPreset)
    }
}

// MARK: - toolbar action

extension RoomContext {
    func toolbarEndCallTaped(forceEndGroupMeeting: Bool = false) async {
        Logger.info("\(logTag) click end call button")
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        DTToastHelper.show01LoadingHudIsDark(true, in: callVC.view)
        await callManager.endCallAction(forceEndGroupMeeting: forceEndGroupMeeting)
    }

    func toolbarMinimizeTaped() {
        Logger.info("\(logTag) click floating view")
        callManager.minimizeAction()
    }

    func inviteUsersToCall() {
        Logger.info("\(logTag) invite other users")
        callManager.inviteAction()
    }

    func checkPartiantInRoom(_: String) {
        // 获取群信息
        Logger.info("\(logTag) check is in room with conversationId \(currentCall.conversationId ?? "empty")")
        if let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: currentCall.conversationId ?? ""),
           let groupThread = TSGroupThread.getWithGroupId(groupId)
        {
            // 如果参会人不是群成员
            Logger.error("\(logTag) current call is Group")
            if !TSGroupThread.isLocalUserInGroup(groupThread)() {
                Logger.error("\(logTag) current call is not in Group")
                callManager.turnIntoInstantCall()
            }
        } else {
            // 如果群不存在
            Logger.error("\(logTag) current call is Instant")
            callManager.turnIntoInstantCall()
        }
    }
}

// MARK: - Audio session observer

extension RoomContext {
    func audioSessionDidChangePortType(_ portType: AVAudioSession.Port, isExternalConnected: Bool) {
        Logger.info("\(logTag) portType: \(lkContext?.portType ?? .builtInSpeaker) => \(portType) isExternalConnected: \(lkContext?.isExternalConnected ?? false) => \(isExternalConnected)")

        lkContext?.setPortTypeAndExternal(portType, isExternalConnected: isExternalConnected)
    }

    func audioSessionDidChangePortName(_ portName: String, isExternalConnected _: Bool) {
        guard portName != lastPortName else { return }
        Logger.info("\(logTag) audiosession change portName: \(portName)")
        lastPortName = portName
        setDenoiseFilter(enabled: !DTMeetingManager.shared.isInputAirPods(portName: portName))
    }
}

// MARK: - Encryption helper (nonisolated as original)

extension RoomContext {
    nonisolated func decryptCallKey(eKey: String, eMKey: String) -> Data? {
        var k_e2eeKey: Data?
        if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
           let publicKey = Data(base64Encoded: eKey),
           let emk = Data(base64Encoded: eMKey)
        {
            do {
                let result = try DTProtoAdapter().decryptKey(version: 2,
                                                             eKey: publicKey,
                                                             localPriKey: localPriKey,
                                                             eMKey: emk)
                k_e2eeKey = result.mKey
                Task { @MainActor [weak self] in
                    self?.currentCall.mKey = k_e2eeKey
                }
            } catch {
                let errorDesc = error.localizedDescription
                Task { @MainActor in
                    await DTMeetingManager.shared.hangupCoordinator.terminate(
                        reason: .callError
                    )
                    DTToastHelper.showCallToast(Localized("MEETING_JOINED_FAILURE_TIPS"))
                    Logger.error("[newcall] decrypt error: \(errorDesc)")
                }
            }
        }
        return k_e2eeKey
    }
}

extension Room {
    func isScreenShareActive() -> Bool {
        for participant in allParticipants.values {
            for pub in participant.videoTracks {
                if pub.source == .screenShareVideo {
                    return true
                }
            }
        }
        return false
    }
}

private final class CallAudioDiagnosticsProcessor: AudioCustomProcessingDelegate, @unchecked Sendable {
    private static let logWindowNanoseconds: UInt64 = 30_000_000_000
    private static let logIntervalNanoseconds: UInt64 = 1_000_000_000
    private static let int16Scale = Double(Int16.max) + 1
    private static let suspiciousInputDbFS = -45.0
    private static let suspiciousOutputDbFS = -75.0

    private struct LevelAccumulator {
        var sumSquares: Double = 0
        var peak: Double = 0
        var sampleCount = 0

        mutating func append(_ stats: FrameLevelStats) {
            sumSquares += stats.sumSquares
            peak = max(peak, stats.peak)
            sampleCount += stats.sampleCount
        }

        mutating func take() -> LevelAccumulator {
            let snapshot = self
            self = LevelAccumulator()
            return snapshot
        }

        var rms: Double {
            sampleCount > 0 ? sqrt(sumSquares / Double(sampleCount)) : 0
        }

        var dbFS: Double {
            rms > 0 ? 20 * log10(rms) : -160
        }
    }

    private struct FrameLevelStats {
        let sumSquares: Double
        let peak: Double
        let sampleCount: Int
    }

    private struct State {
        var generation = 0
        var isWindowActive = false
        var windowStart: UInt64 = 0
        var deadline: UInt64 = 0
        var nextLogTime: UInt64 = 0
        var pre = LevelAccumulator()
        var post = LevelAccumulator()
        var didLogSuppressionAlert = false
        var denoiseEnabled = true
        var voicePreset = "original"
    }

    private struct LogSnapshot: Sendable {
        let elapsedSeconds: Double
        let pre: LevelAccumulator
        let post: LevelAccumulator
        let shouldLogSuppressionAlert: Bool
        let denoiseEnabled: Bool
        let module: String
        let voicePreset: String
        let isWindowComplete: Bool
    }

    private let processor = AudioPipelineProcessor()
    private let lock = NSLock()
    private let logQueue = DispatchQueue(label: "org.difft.chative.call-audio-diagnostics")
    private var state = State()

    var audioProcessingName: String { processor.audioProcessingName }

    var activeModule: AudioModule {
        get { processor.activeModule }
        set { processor.activeModule = newValue }
    }

    func setDenoiseEnabled(_ enabled: Bool) {
        withLock { state.denoiseEnabled = enabled }
        processor.setDenoiseEnabled(enabled)
    }

    func setSoundTouchPreset(_ preset: String) {
        withLock { state.voicePreset = preset }
        processor.setSoundTouchPreset(preset)
    }

    func beginLoggingWindow(reason: String) {
        let now = DispatchTime.now().uptimeNanoseconds
        let generation = withLock { () -> Int? in
            guard !state.isWindowActive else { return nil }
            state.generation += 1
            state.isWindowActive = true
            state.windowStart = now
            state.deadline = now + Self.logWindowNanoseconds
            state.nextLogTime = now + Self.logIntervalNanoseconds
            state.pre = LevelAccumulator()
            state.post = LevelAccumulator()
            state.didLogSuppressionAlert = false
            return state.generation
        }
        guard let generation else { return }
        Logger.info(
            "[AudioDenoiseLevel] window begin generation=\(generation) duration=30s module=\(activeModule.rawValue) reason=\(reason)"
        )
    }

    func endLoggingWindow(reason: String) {
        let didEnd = withLock { () -> Bool in
            guard state.isWindowActive else { return false }
            state.generation += 1
            state.isWindowActive = false
            state.pre = LevelAccumulator()
            state.post = LevelAccumulator()
            return true
        }
        if didEnd {
            Logger.info("[AudioDenoiseLevel] window end reason=\(reason)")
        }
    }

    func audioProcessingInitialize(sampleRate sampleRateHz: Int, channels: Int) {
        processor.audioProcessingInitialize(sampleRate: sampleRateHz, channels: channels)
    }

    func audioProcessingProcess(audioBuffer: LKAudioBuffer) {
        let now = DispatchTime.now().uptimeNanoseconds
        let windowState = withLock { () -> (generation: Int?, expiredSnapshot: LogSnapshot?, didExpire: Bool) in
            guard state.isWindowActive else { return (nil, nil, false) }
            guard now <= state.deadline else {
                let snapshot = makeSnapshotLocked(
                    elapsedTime: state.deadline,
                    isWindowComplete: true
                )
                state.isWindowActive = false
                return (nil, snapshot, true)
            }
            return (state.generation, nil, false)
        }

        if let snapshot = windowState.expiredSnapshot {
            logQueue.async { Self.log(snapshot) }
        } else if windowState.didExpire {
            logQueue.async {
                Logger.info("[AudioDenoiseLevel] window complete duration=30s samples=0")
            }
        }

        guard let generation = windowState.generation else {
            processor.audioProcessingProcess(audioBuffer: audioBuffer)
            return
        }

        let pre = Self.measure(audioBuffer)
        processor.audioProcessingProcess(audioBuffer: audioBuffer)
        let post = Self.measure(audioBuffer)

        let snapshot = withLock { () -> LogSnapshot? in
            guard state.isWindowActive, state.generation == generation else { return nil }
            state.pre.append(pre)
            state.post.append(post)
            guard now >= state.nextLogTime else { return nil }

            repeat {
                state.nextLogTime += Self.logIntervalNanoseconds
            } while state.nextLogTime <= now

            let isWindowComplete = now >= state.deadline
            let result = makeSnapshotLocked(
                elapsedTime: min(now, state.deadline),
                isWindowComplete: isWindowComplete
            )
            if isWindowComplete {
                state.isWindowActive = false
            }
            return result
        }

        if let snapshot {
            logQueue.async { Self.log(snapshot) }
        }
    }

    func audioProcessingRelease() {
        endLoggingWindow(reason: "audio processing released")
        processor.audioProcessingRelease()
    }

    private static func measure(_ audioBuffer: LKAudioBuffer) -> FrameLevelStats {
        var sumSquares: Double = 0
        var peak: Double = 0
        let sampleCount = audioBuffer.channels * audioBuffer.frames
        guard sampleCount > 0 else {
            return FrameLevelStats(sumSquares: 0, peak: 0, sampleCount: 0)
        }

        for channel in 0 ..< audioBuffer.channels {
            let samples = audioBuffer.rawBuffer(forChannel: channel)
            for frame in 0 ..< audioBuffer.frames {
                let sample = Double(samples[frame]) / int16Scale
                sumSquares += sample * sample
                peak = max(peak, abs(sample))
            }
        }

        return FrameLevelStats(
            sumSquares: sumSquares,
            peak: peak,
            sampleCount: sampleCount
        )
    }

    private func makeSnapshotLocked(
        elapsedTime: UInt64,
        isWindowComplete: Bool
    ) -> LogSnapshot? {
        guard state.pre.sampleCount > 0, state.post.sampleCount > 0 else { return nil }
        let preSnapshot = state.pre.take()
        let postSnapshot = state.post.take()
        let isSuppressed = state.denoiseEnabled
            && state.voicePreset == "original"
            && preSnapshot.dbFS >= Self.suspiciousInputDbFS
            && postSnapshot.dbFS <= Self.suspiciousOutputDbFS
        let shouldAlert = isSuppressed && !state.didLogSuppressionAlert
        if shouldAlert {
            state.didLogSuppressionAlert = true
        }

        return LogSnapshot(
            elapsedSeconds: Double(elapsedTime - state.windowStart) / 1_000_000_000,
            pre: preSnapshot,
            post: postSnapshot,
            shouldLogSuppressionAlert: shouldAlert,
            denoiseEnabled: state.denoiseEnabled,
            module: activeModule.rawValue,
            voicePreset: state.voicePreset,
            isWindowComplete: isWindowComplete
        )
    }

    private static func log(_ snapshot: LogSnapshot) {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs.map(\.portType.rawValue).joined(separator: ",")
        let outputs = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        let deltaDb = snapshot.post.dbFS - snapshot.pre.dbFS
        let values = String(
            format: "elapsed=%.1fs prePipelineRms=%.6f prePipelinePeak=%.6f prePipelineDbFS=%.1f postPipelineRms=%.6f postPipelinePeak=%.6f postPipelineDbFS=%.1f deltaDb=%.1f",
            snapshot.elapsedSeconds,
            snapshot.pre.rms,
            snapshot.pre.peak,
            snapshot.pre.dbFS,
            snapshot.post.rms,
            snapshot.post.peak,
            snapshot.post.dbFS,
            deltaDb
        )
        Logger.info(
            "[AudioDenoiseLevel] \(values) samples=\(snapshot.pre.sampleCount) module=\(snapshot.module) denoiseEnabled=\(snapshot.denoiseEnabled) voicePreset=\(snapshot.voicePreset) admMuted=\(AudioManager.shared.isMicrophoneMuted) engineRunning=\(AudioManager.shared.isEngineRunning) route=in:[\(inputs)] out:[\(outputs)]"
        )
        if snapshot.shouldLogSuppressionAlert {
            Logger.warn(
                "[AudioDenoiseLevel] POSSIBLE_DENOISE_SUPPRESSION prePipelineDbFS=\(snapshot.pre.dbFS) postPipelineDbFS=\(snapshot.post.dbFS) module=\(snapshot.module)"
            )
        }
        if snapshot.isWindowComplete {
            Logger.info("[AudioDenoiseLevel] window complete duration=30s")
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
