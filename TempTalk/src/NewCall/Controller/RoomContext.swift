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
import DenoisePluginFilter
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

    private let denoiseFilter = DenoisePluginFilter()

    var serviceUrlManager: TTCallServiceUrlManager?

    // Published connection / config state
    @Published var url: String = ""
    @Published var token: String = ""
    @Published var e2eeKey: Data?

    // Room / Connect options
    @Published var simulcast: Bool = true
    @Published var autoSubscribe: Bool = true

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
    var errorHandlingState: ErrorHandlingState = .idle

    // ViewControllers held while presented
    var shareVC: UIViewController?
    var inviteVC: UIViewController?
    var noiseVC: UIViewController?

    private var genrateTokenTimeDuration = 0
    private var lkContext: LiveKitContext?

    var lastPortName: String?
    // 防说话人抖动
    var lastParticipants: [Participant] = []
    var activeSpeakerWorkItem: DispatchWorkItem?
    var resetToDefaultWorkItem: DispatchWorkItem?
    let activeSpeakerDelay: TimeInterval = 0.4
    let resetDelay: TimeInterval = 2.5
    // 连接超时任务
    var connectTimeoutTask: Task<Void, Never>?
    // 是否正在展示 screen share
    var isPresentingShareView = false
    // 是否存在待展示的UI
    private var pendingShowUI = false

    // MARK: - Init / Deinit

    init(url: String, token: String, lkContext: LiveKitContext?) {
        AudioManager.shared.capturePostProcessingDelegate = denoiseFilter

        room.add(delegate: self)

        self.url = url
        self.token = token
        e2eeKey = e2eeKey
        self.lkContext = lkContext
        autoSubscribe = true
        genrateTokenTimeDuration = Int(Date().timeIntervalSince1970)
        // callManager 不需要在 init 中赋 weak；使用计算属性访问单例

        #if os(iOS)
        DispatchMainThreadSafe {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #endif

        DTRTCAudioSession.shared.addObserver(self)

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if self.pendingShowUI {
                    Logger.info("\(self.logTag) RoomContext become active show share view")
                    self.pendingShowUI = false
                    self.presentShareViewVC()
                }

                // 检查是否存在屏幕共享但未展示，尝试弹出
                self.checkAndPresentScreenShareIfNeeded()
            }
        }
    }

    deinit {
        Logger.info("\(logTag) RoomContext deinit")

        // 清理资源
        _connectTask?.cancel()
        _connectTask = nil

        // 移除观察者
        DTRTCAudioSession.shared.removeObserver(self)
        NotificationCenter.default.removeObserver(self)

        // 清理音频处理, 由于deinit的触发时机不可控，这里避免清理新的降噪库导致降噪不生效
        if let currentDelegate = AudioManager.shared.capturePostProcessingDelegate as AnyObject?,
           currentDelegate === denoiseFilter
        {
            Logger.info("\(logTag) clear denoise filter from audio manager")
            AudioManager.shared.capturePostProcessingDelegate = nil
        } else {
            Logger.info("\(logTag) this denoise filter not same as audio manager's, skip clear")
        }

        // 清理可能存在的循环引用
        // 虽然disconnect()应该已经清理过，但如果有bug导致这里还有引用，必须清理
        DispatchMainThreadSafe {
            self.shareVC?.dismiss(animated: false)
            self.shareVC = nil

            self.inviteVC?.dismiss(animated: false)
            self.inviteVC = nil

            self.noiseVC?.dismiss(animated: false)
            self.noiseVC = nil
        }

        // 恢复设备状态
        #if os(iOS)
        DispatchMainThreadSafe {
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
        isConnecting = false
        // 取消连接时标记为已处理，防止后续 delegate 回调触发清理
        errorHandlingState = .handled
    }

    /// 重置错误处理状态，用于开始新的连接
    func resetErrorHandlingState() {
        errorHandlingState = .idle
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
        errorHandlingState = .idle
        // Ensure audio session observations and config are active
        DTRTCAudioSession.shared.addObserver(self)
        await DTRTCAudioSession.shared.connectRoomConfig(self, fromCallKit: fromCallKit)
        DTRTCAudioSession.shared.startObserving(self)

        let keyProvider = BaseKeyProvider(isSharedKey: true, sharedKey: nil as Data?)
        let e2eeOptions = E2EEOptions(keyProvider: keyProvider, ttEncryptor: self)

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: .init(dimensions: .h1080_169),
            defaultScreenShareCaptureOptions: .init(dimensions: .h1080_169, useBroadcastExtension: true),
            defaultVideoPublishOptions: .init(
                encoding: VideoEncoding(
                    maxBitrate: VideoParameters.presetH1080_169.encoding.maxBitrate,
                    maxFps: 30
                ),
                simulcast: simulcast
            ),
            adaptiveStream: true,
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
                // token 校验（短期校验策略）
                let currentTime = Int(Date().timeIntervalSince1970)
                guard currentTime - genrateTokenTimeDuration <= 30 else {
                    Logger.info("\(logTag) token timeout")
                    isConnecting = false
                    return
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
//                throw error
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
            errorHandlingState = .handled
            throw CancellationError()
        }
        // 连接失败就切换下一个url
        if needHangupError(error: error) {
            Logger.error("\(logTag): connect failed with \(error.localizedDescription)")
            isConnecting = false
            // 标记为已处理，防止 delegate 重复处理
            errorHandlingState = .handled
            DTMeetingManager.shared.showErrorTost = true
            await DTMeetingManager.shared.clearDisconnectErrorData()
            throw error
        } else {
            if let serviceUrlManager,
               serviceUrlManager.switchToNextUrl(),
               let nextUrl = await serviceUrlManager.getCurrentUrl()
            {
                url = nextUrl
                Logger.info("\(logTag): switched to next URL=\(nextUrl)")
                // 标记为重试中，delegate 收到错误时应忽略
                errorHandlingState = .retrying
                // 切换 URL 重试时，需要先重置 isConnecting，因为 connect 方法会再次检查
                isConnecting = false
                guard !shouldAbortConnect, !Task.isCancelled else {
                    Logger.info("\(logTag): aborting after URL switch due to disconnect request")
                    isConnecting = false
                    errorHandlingState = .handled
                    throw CancellationError()
                }
                _ = try await connect(fromCallKit: fromCallKit, connectOptions: connectOptions)
            } else {
                Logger.error("\(logTag): no more URLs to try")
                isConnecting = false
                // 标记为已处理，防止 delegate 重复处理
                errorHandlingState = .handled
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
        await room.disconnect()

        // 清理ViewController，打破循环引用
        // 这些ViewController的SwiftUI视图通过environmentObject持有self，必须清理
        await MainActor.run {
            shareVC?.dismiss(animated: false)
            shareVC = nil

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

    func presentShareView(completion: (() -> Void)? = nil) {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchMainThreadSafe { [weak self] in
                self?.presentShareView(completion: completion)
            }
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

    private func presentShareViewVC(completion: (() -> Void)? = nil) {
        let shareView = CallScreenShareView(minimizeAction: { [weak self] in
            guard let self else { return }
            toolbarMinimizeTaped()
        })
        .environmentObject(self)
        let shareVC = DTHostingController(rootView: shareView)
        self.shareVC = shareVC
        shareVC.modalPresentationStyle = .fullScreen
        presentOnTop(shareVC, animated: false, completion: completion)
    }

    /// 检查是否存在屏幕共享但未展示，如果存在则尝试弹出
    @MainActor
    private func checkAndPresentScreenShareIfNeeded() {
        // 防御性检查：如果屏幕共享已结束但视图仍存在，则 dismiss
        if screenSharePublication == nil, shareVC != nil {
            Logger.info("\(logTag) Screen share ended but view still exists, dismissing")
            shareVC?.dismiss(animated: false)
            shareVC = nil
            callManager.currentCall.isPresentedShare = false
            return
        }

        // 检查是否存在屏幕共享
        guard let publication = screenSharePublication,
              let participant = screenShareParticipant,
              publication.source == .screenShareVideo
        else {
            Logger.info("\(logTag) No active screen share found")
            return
        }

        // 检查参与者是否仍然启用屏幕共享
        guard participant.isScreenShareEnabled() else {
            Logger.info("\(logTag) Participant screen share is not enabled")
            return
        }

        // 如果已经展示，不需要重复弹出
        if shareVC != nil {
            Logger.info("\(logTag) Screen share view already presented")
            return
        }

        // 如果存在屏幕共享但未展示（可能是之前在后台时尝试失败），尝试弹出
        Logger.info("\(logTag) App became active, found screen share but view not presented - attempting to present")
        // 确保状态正确
        if !callManager.currentCall.isPresentedShare {
            callManager.currentCall.isPresentedShare = true
        }
        tryPresentShareView(maxRetryCount: 3)
    }

    func presentInviteView() {
        let inviteVC = DTCallInviteMemberVC()
        inviteVC.isLiveKitCall = true
        let inviteNav = OWSNavigationController(rootViewController: inviteVC)
        self.inviteVC = inviteNav
        presentOnTop(inviteNav, animated: false)
    }

    func presentMuteActionSheet(_ participant: Participant) {
        guard DTMeetingManager.shared.openMuteOtherEnabled() else {
            Logger.info("\(logTag) remoteConfig not open muteOtherEnabled")
            return
        }

        var actions = [ActionSheetAction]()
        let muteAction = ActionSheetAction(title: "Mute", style: .default) { _ in
            Task { @MainActor in
                await DTMeetingManager.shared.sendRemoteMicOffRoom(targetParticentId: participant.identity?.stringValue ?? "")
            }
        }
        actions.append(muteAction)

        let actionSheet = ActionSheetController()
        actionSheet.isDarkThemeOnly = true
        actionSheet.addAction(OWSActionSheets.cancelAction)
        actions.forEach { actionSheet.addAction($0) }
        presentOnTop(actionSheet, animated: true)
    }

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

    func presentHangupActionSheet() {
        if DTMeetingManager.shared.isPresentedShare() || DTMeetingManager.shared.showScreenShare() {
            var alertActions: [UIAlertAction] = []
            let endMeetingAction = UIAlertAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { _ in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }
            endMeetingAction.setValue(UIColor.color(rgbHex: 0xD9271E), forKey: "_titleTextColor")
            alertActions.append(endMeetingAction)

            let leaveMeetingAction = UIAlertAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { _ in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: false)
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

            let endMeetingAction = ActionSheetAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { _ in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }

            let leaveMeetingAction = ActionSheetAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { _ in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
            }

            actionSheet.addAction(OWSActionSheets.cancelAction)
            actionSheet.addAction(endMeetingAction)
            actionSheet.addAction(leaveMeetingAction)
            presentOnTop(actionSheet, animated: true)
        }
    }

    func setDenoiseFilter(enabled: Bool) {
        denoiseFilter.isEnabled = enabled
    }

    func isDenoiseFilterEnabled() -> Bool {
        denoiseFilter.isEnabled
    }
}

// MARK: - toolbar action

extension RoomContext {
    func toolbarEndCallTaped(forceEndGroupMeeting: Bool = false) async {
        Logger.info("\(logTag) click end call button")
        DispatchMainThreadSafe {
            let callWindow = OWSWindowManager.shared().callViewWindow
            let callVC = callWindow.findTopViewController()
            DTToastHelper.show01LoadingHudIsDark(true, in: callVC.view)
        }
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
                DispatchMainThreadSafe {
                    self.currentCall.mKey = k_e2eeKey
                }
            } catch {
                // 捕获当前 roomContext（即 self），避免清理新创建的 roomContext
                let roomContextToClean = self
                DispatchMainThreadSafe {
                    Task {
                        await self.callManager.performCompleteCleanup(roomContextToClean: roomContextToClean)
                        DTToastHelper.showCallToast(Localized("MEETING_JOINED_FAILURE_TIPS"))
                        Logger.error("\(self.logTag) decrypt error: \(error.localizedDescription)")
                    }
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
