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

enum ErrorCategory {
    case networkIssue // 可以切换域名重试
    case fatal // 不要重试
}

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

    private let audioProcessor = AudioPipelineProcessor()
    private var _denoiseEnabled: Bool = true

    var serviceUrlManager: TTCallServiceUrlManager?

    // Published connection / config state
    @Published var url: String = ""
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

    private var connectRetryCount: Int = 0
    private let maxConnectRetry: Int = 5
    private var tokenGeneratedAt: TimeInterval = 0
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
    // 重连后递增，用于强制 SwiftUI 重建视频视图树以恢复 adaptive stream 订阅
    @Published var videoRefreshToken: UInt64 = 0
    @Published var isRoomReconnecting: Bool = false

    // MARK: - Init / Deinit

    init(url: String, token: String, lkContext: LiveKitContext?) {
        AudioManager.shared.capturePostProcessingDelegate = audioProcessor

        if let cachedMode = CallSettingsManager.shared.getDenoiseMode() {
            audioProcessor.activeModule = cachedMode == "enhanced" ? .deepfilternet : .rnnoise
        } else {
            let callConfig = CallConfigManager.fetchCallConfig()
            audioProcessor.activeModule = callConfig.denoiseMode == "enhanced" ? .deepfilternet : .rnnoise
        }

        loadDefaultVoicePresetFromSettings()

        room.add(delegate: self)

        self.url = url
        self.token = token
        e2eeKey = e2eeKey
        self.lkContext = lkContext
        tokenGeneratedAt = Date().timeIntervalSince1970
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
                let hadPendingShareUI = self.pendingShowUI
                self.pendingShowUI = false

                if hadPendingShareUI {
                    Logger.info("\(self.logTag) RoomContext become active retry show share view")
                    self.tryPresentShareView(maxRetryCount: 0)
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

    @MainActor
    func connect(fromCallKit: Bool, connectOptions: ConnectOptions) async throws -> Room {
        guard !shouldAbortConnect else {
            Logger.info("\(logTag) room.connect aborted because disconnect was requested")
            throw CancellationError()
        }
        guard !isConnecting else {
            Logger.info("\(logTag) room.connect already in progress, skipping duplicate call")
            return room
        }
        Logger.info("\(logTag) room.connect fromCallKit: \(fromCallKit)")
        isConnecting = true
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
                preferredCodec: VideoCodec.vp8,
                
            ),
            adaptiveStream: true,
            dynacast: true,
            e2eeOptions: e2eeOptions,
            reportRemoteTrackStatistics: true
        )

        // Use Task (not detached) so we stay in MainActor context for UI/livekit interactions
        let connectTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                guard !shouldAbortConnect else {
                    isConnecting = false
                    throw CancellationError()
                }
                let elapsed = Date().timeIntervalSince1970 - tokenGeneratedAt
                guard elapsed <= 30 else {
                    Logger.error("\(logTag) token expired after \(Int(elapsed))s, aborting connect")
                    isConnecting = false
                    markHandled()
                    throw DTMeetingManager.CallError.tokenExpired
                }
                Logger.info("\(logTag): room connect currentURL=\(url)")

                try await room.connect(
                    url: url,
                    token: "",
                    connectOptions: connectOptions,
                    roomOptions: roomOptions
                )
                // 挂断请求发生在连接成功后，立即断开并抛出取消
                if shouldAbortConnect || Task.isCancelled {
                    isConnecting = false
                    await room.disconnect()
                    throw CancellationError()
                }
                // 连接成功后重置标志
                isConnecting = false
            } catch is CancellationError {
                isConnecting = false
                throw CancellationError()
            } catch {
                guard !shouldAbortConnect, !Task.isCancelled else {
                    isConnecting = false
                    throw CancellationError()
                }
                // handleConnectError 在 MainActor 中执行
                try await handleConnectError(error, connectOptions: connectOptions, fromCallKit: fromCallKit)
            }
        }

        _connectTask = connectTask
        defer { _connectTask = nil }
        try await connectTask.value
        return room
    }

    @MainActor
    private func handleConnectError(
        _ error: Error,
        connectOptions: ConnectOptions,
        fromCallKit: Bool
    ) async throws {
        if shouldAbortConnect || Task.isCancelled {
            Logger.info("\(logTag): aborting connect retry due to disconnect request")
            isConnecting = false
            markHandled()
            throw CancellationError()
        }
        // 连接失败就切换下一个url
        if needHangupError(error: error) {
            Logger.error("\(logTag): connect failed with \(error.localizedDescription)")
            isConnecting = false
            // 标记为已处理，防止 delegate 重复处理
            markHandled()
            DTMeetingManager.shared.showErrorToast = true
            await DTMeetingManager.shared.clearDisconnectErrorData()
            throw error
        } else {
            if let serviceUrlManager,
               serviceUrlManager.switchToNextUrl(),
               let nextUrl = await serviceUrlManager.getCurrentUrl()
            {
                url = nextUrl
                tokenGeneratedAt = Date().timeIntervalSince1970
                connectRetryCount += 1
                guard connectRetryCount <= maxConnectRetry else {
                    Logger.error("\(logTag): retry count \(connectRetryCount) exceeded limit \(maxConnectRetry), aborting")
                    isConnecting = false
                    markHandled()
                    throw error
                }
                Logger.info("\(logTag): switched to next URL=\(nextUrl), refreshed token window")
                markRetrying()
                isConnecting = false
                guard !shouldAbortConnect, !Task.isCancelled else {
                    Logger.info("\(logTag): aborting after URL switch due to disconnect request")
                    markHandled()
                    throw CancellationError()
                }
                _ = try await connect(fromCallKit: fromCallKit, connectOptions: connectOptions)
            } else {
                Logger.error("\(logTag): no more URLs to try")
                isConnecting = false
                markHandled()
                await DTMeetingManager.shared.clearDisconnectErrorData()
                DTToastHelper.toast(withText: Localized("METTING_CONNECT_EXCEPTION_TIPS"))
                throw error
            }
        }
    }

    private func needHangupError(error: Error) -> Bool {
        let category = classifyLiveKitError(error)
        if category == .fatal {
            return true
        }
        return false
    }

    func classifyLiveKitError(_ error: Error) -> ErrorCategory {
        if let lkError = error as? LiveKitError {
            switch lkError.type {
            case .network,
                 .timedOut,
                 .serverPingTimedOut,
                 .reconnectFailure,
                 .validation,
                 .unknown:
                return .networkIssue

            default:
                return .fatal
            }
        }

        if (error as NSError).domain == NSURLErrorDomain { return .networkIssue }
        if (error as NSError).domain == NSPOSIXErrorDomain { return .networkIssue }
        if (error as NSError).domain == kCFErrorDomainCFNetwork as String { return .networkIssue }

        return .networkIssue
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

    func bumpVideoRefreshToken() {
        videoRefreshToken &+= 1
        Logger.info("\(logTag) videoRefreshToken bumped to \(videoRefreshToken)")
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
        if let publication = screenSharePublication, publication.source == .screenShareVideo {
            return true
        }

        let roomActive = room.isScreenShareActive()
        if !roomActive {
            Logger.info("\(logTag) hasActiveScreenShareToPresent: false (publication: \(screenSharePublication != nil), roomActive: \(roomActive))")
        }
        return roomActive
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
            if callManager.currentCall.isPresentedShare {
                Logger.info("\(logTag) No active tracks but isPresentedShare=true, room may be reconnecting - skipping premature dismiss")
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

            let endMeetingAction = ActionSheetAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { [weak self] _ in
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
