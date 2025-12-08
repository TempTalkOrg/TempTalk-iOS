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

import Foundation
import SwiftUI
import AVFoundation
import LiveKit
import UIKit
import DenoisePluginFilter
import DTProto

enum ErrorCategory {
    case networkIssue      // 可以切换域名重试
    case fatal             // 不要重试
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
    public var latestError: LiveKitError?

    public let room = Room()

    private let denoiseFilter = DenoisePluginFilter()

    public var serviceUrlManager: TTCallServiceUrlManager?

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
    var screenShareParticipant: RemoteParticipant? = nil

    // Tasks
    private var _connectTask: Task<Void, Error>?

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

    public init(url: String, token: String, lkContext: LiveKitContext?) {
        AudioManager.shared.capturePostProcessingDelegate = denoiseFilter

        room.add(delegate: self)

        self.url = url
        self.token = token
        self.e2eeKey = e2eeKey
        self.lkContext = lkContext
        self.autoSubscribe = true
        self.genrateTokenTimeDuration = Int(Date().timeIntervalSince1970)
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
        ) { notification in
            Task { @MainActor in
                if self.pendingShowUI {
                    Logger.info("\(self.logTag) RoomContext become active show share view")
                    self.pendingShowUI = false
                    self.presentShareViewVC()
                }
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

        // 清理音频处理
        AudioManager.shared.capturePostProcessingDelegate = nil

        // 恢复设备状态
        #if os(iOS)
        DispatchMainThreadSafe {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    // MARK: - Public API

    func cancelConnect() {
        _connectTask?.cancel()
        _connectTask = nil
    }

    @MainActor
    func connect(connectOptions: ConnectOptions) async throws -> Room {
        // Ensure audio session observations and config are active
        DTRTCAudioSession.shared.addObserver(self)
        DTRTCAudioSession.shared.connectRoomConfig(self)
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
            guard let self = self else { return }
            do {
                // token 校验（短期校验策略）
                let currentTime = Int(Date().timeIntervalSince1970)
                guard currentTime - self.genrateTokenTimeDuration <= 30 else {
                    Logger.info("\(self.logTag) token timeout")
                    return
                }

                try await self.room.connect(
                    url: self.url,
                    token: "",
                    connectOptions: connectOptions,
                    roomOptions: roomOptions
                )
            } catch {
                // handleConnectError 在 MainActor 中执行
                try await self.handleConnectError(error, connectOptions: connectOptions)
//                throw error
            }
        }

        _connectTask = connectTask
        try await connectTask.value
        return room
    }

    @MainActor
    private func handleConnectError(
        _ error: Error,
        connectOptions: ConnectOptions
    ) async throws {
        // 连接失败就切换下一个url
        if needHangupError(error: error) {
            Logger.error("\(logTag): connect failed with \(error.localizedDescription)")
            DTMeetingManager.shared.showErrorTost = true
            await DTMeetingManager.shared.clearDisconnectErrorData()
            throw error
        } else {
            if let serviceUrlManager,
               serviceUrlManager.switchToNextUrl(),
               let nextUrl = await serviceUrlManager.getCurrentUrl() {
                self.url = nextUrl
                Logger.info("\(logTag): switched to next URL=\(nextUrl)")
                _ = try await connect(connectOptions: connectOptions)
            } else {
                Logger.error("\(logTag): no more URLs to try")
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

    func disconnect() async {
        Logger.info("\(logTag): room disconnect")

        DTRTCAudioSession.shared.removeObserver(self)
        DTRTCAudioSession.shared.disconnectRoomConfig(self)
        DTRTCAudioSession.shared.stopObserving(self)

        await room.disconnect()
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
            guard let self = self else { return }
            do {
                let json = try self.jsonEncoder.encode(roomMessage)
                try await self.room.localParticipant.publish(data: json)
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
            self.pendingShowUI = true
            return
        }

        presentShareViewVC(completion: completion)
    }
    
    private func presentShareViewVC(completion: (() -> Void)? = nil) {
        let shareView = CallScreenShareView(minimizeAction: { [weak self] in
            guard let self = self else { return }
            self.toolbarMinimizeTaped()
        })
            .environmentObject(self)
        let shareVC = DTHostingController(rootView: shareView)
        self.shareVC = shareVC
        shareVC.modalPresentationStyle = .fullScreen
        presentOnTop(shareVC, animated: false, completion: completion)
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
        let muteAction = ActionSheetAction(title: "Mute", style: .default) { action in
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

        let muteAction = UIAlertAction(title: "Mute", style: .default) { action in
            Task { @MainActor in
                await DTMeetingManager.shared.sendRemoteMicOffRoom(targetParticentId: participantId)
            }
        }

        var alertActions: [UIAlertAction] = []
        alertActions.append(muteAction)

        let alertVC = DTAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for action in alertActions {
            action.setValue(Theme.alertConfirmColor, forKey: "_titleTextColor")
            alertVC.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in }
        cancelAction.setValue(Theme.alertCancelColor, forKey: "_titleTextColor")
        alertVC.addAction(cancelAction)

        presentOnTop(alertVC, animated: true)
    }

    func presentHangupActionSheet() {
        if DTMeetingManager.shared.isPresentedShare() || DTMeetingManager.shared.showScreenShare() {
            var alertActions: [UIAlertAction] = []
            let endMeetingAction = UIAlertAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { action in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }
            endMeetingAction.setValue(UIColor.color(rgbHex: 0xD9271E), forKey: "_titleTextColor")
            alertActions.append(endMeetingAction)

            let leaveMeetingAction = UIAlertAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { action in
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

            let cancelAction = UIAlertAction(title: Localized("HANGUP_CANCEL_MEETING"), style: .cancel) { action in }
            cancelAction.setValue(UIColor.color(rgbHex: 0xEAECEF), forKey: "_titleTextColor")
            alertVC.addAction(cancelAction)

            presentOnTop(alertVC, animated: true)

        } else {
            var actions = [ActionSheetAction]()
            let endMeetingAction = ActionSheetAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { action in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }
            actions.append(endMeetingAction)

            let leaveMeetingAction = ActionSheetAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { action in
                Task { @MainActor in
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
            }
            actions.append(leaveMeetingAction)

            let actionSheet = ActionSheetController()
            actionSheet.isDarkThemeOnly = true
            actionSheet.addAction(OWSActionSheets.cancelAction)
            actions.forEach { actionSheet.addAction($0) }
            presentOnTop(actionSheet, animated: true)
        }
    }

    func setDenoiseFilter(enabled: Bool) {
        denoiseFilter.isEnabled = enabled
    }

    func isDenoiseFilterEnabled() -> Bool {
        return denoiseFilter.isEnabled
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

    func checkPartiantInRoom(_ partiantId: String) {
        // 获取群信息
        if let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: currentCall.conversationId ?? ""),
           let groupThread = TSGroupThread.getWithGroupId(groupId) {
            // 如果参会人不是群成员
            if let pid = partiantId.components(separatedBy: ".").first,
               !groupThread.groupModel.groupMemberIds.contains(pid) {
                callManager.turnIntoInstantCall()
            }
        } else {
            // 如果群不存在
            callManager.turnIntoInstantCall()
        }
    }
}

// MARK: - Audio session observer
extension RoomContext {
    public func audioSessionDidChangePortType(_ portType: AVAudioSession.Port, isExternalConnected: Bool) {
        Logger.debug("\(logTag) portType: \(String(describing: lkContext?.portType)) => \(portType) isExternalConnected: \(String(describing: lkContext?.isExternalConnected)) => \(isExternalConnected)")

        lkContext?.setPortTypeAndExternal(portType, isExternalConnected:isExternalConnected)
    }

    public func audioSessionDidChangePortName(_ portName: String, isExternalConnected: Bool) {
        guard portName != lastPortName else { return }
        Logger.info("\(logTag) audiosession change portName: \(portName)")
        lastPortName = portName
        self.setDenoiseFilter(enabled: !DTMeetingManager.shared.isInputAirPods(portName: portName))
    }
}

// MARK: - Encryption helper (nonisolated as original)
extension RoomContext {
    nonisolated public func decryptCallKey(eKey: String, eMKey: String) -> Data? {
        var k_e2eeKey: Data?
        if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
           let publicKey = Data(base64Encoded: eKey),
           let emk = Data(base64Encoded: eMKey) {
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
                DispatchMainThreadSafe {
                    self.callManager.performCompleteCleanup()
                    DTToastHelper.showCallToast(Localized("MEETING_JOINED_FAILURE_TIPS"))
                    Logger.error("\(self.logTag) decrypt error: \(error.localizedDescription)")
                }
            }
        }
        return k_e2eeKey
    }
}

extension Room {
    func isScreenShareActive() -> Bool {
        for participant in self.allParticipants.values {
            for pub in participant.videoTracks {
                if pub.source == .screenShareVideo {
                    return true
                }
            }
        }
        return false
    }
}
