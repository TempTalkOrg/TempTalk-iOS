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

import LiveKit
import SwiftUI
import TTMessaging
import AVFAudio
import DenoisePluginFilter

// This class contains the logic to control behavior of the whole app.
public
final class RoomContext: ObservableObject, DTRTCAudioSessionObserver {
    
    let logTag: String = "[newcall]"
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    // 默认 mic/camera 状态
    let default1on1MicphoneState: Bool = true
    let defaultGroupMicphoneState: Bool = false
    let defaultCameraState: Bool = false
    
    var callManager = DTMeetingManager.shared
    var currentCall: DTLiveKitCallModel {
        get {
            callManager.currentCall
        }
    }

    // Used to show connection error dialog
    // private var didClose: Bool = false
    @Published var shouldShowDisconnectReason: Bool = false
    public var latestError: LiveKitError?

    public let room = Room()
    
    private let denoiseFilter = DenoisePluginFilter()
    
    public var serviceUrlManager: TTCallServiceUrlManager?

    @Published var url: String = ""
    @Published var token: String = ""
    @Published var e2eeKey: Data?

    // RoomOptions
    @Published var simulcast: Bool = true

    // ConnectOptions
    @Published var autoSubscribe: Bool = true

    @Published var focusParticipant: Participant?
    @Published var othersideParticipantFor1on1: Participant?

    @Published var textFieldString: String = ""
    @Published var screenSharePublication: TrackPublication? = nil
    var screenShareParticipant: RemoteParticipant? = nil

    var _connectTask: Task<Void, Error>?
    
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

    public init(url: String, token: String, e2eeKey: Data, lkContext: LiveKitContext?) {
        AudioManager.shared.capturePostProcessingDelegate = denoiseFilter
        
        room.add(delegate: self)

        self.url = url
        self.token = token
        self.e2eeKey = e2eeKey
        self.lkContext = lkContext
        autoSubscribe = true
        self.genrateTokenTimeDuration = Int(Date().timeIntervalSince1970)

        #if os(iOS)
        DispatchMainThreadSafe {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #endif
        
        DTRTCAudioSession.shared.addObserver(self)
//        DTRTCAudioSession.shared.startObserving(self)
    }

    deinit {
        #if os(iOS)
        DispatchMainThreadSafe {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        DTRTCAudioSession.shared.removeObserver(self)
        DTRTCAudioSession.shared.stopObserving(self)
        
        Logger.debug("RoomContext.deinit")
    }

    func cancelConnect() {
        _connectTask?.cancel()
    }

    @MainActor
    func connect() async throws -> Room {
        DTRTCAudioSession.shared.addObserver(self)
        DTRTCAudioSession.shared.connectRoomConfig(self)
        DTRTCAudioSession.shared.startObserving(self)
        
        let connectOptions = ConnectOptions(
            autoSubscribe: autoSubscribe,
            reconnectAttempts: 20,
            reconnectAttemptDelay: 2
        )

        let keyProvider = BaseKeyProvider(isSharedKey: true, sharedKey: e2eeKey)
        let e2eeOptions = E2EEOptions(keyProvider: keyProvider)

        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                dimensions: .h1080_169
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                useBroadcastExtension: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                encoding: VideoEncoding(maxBitrate: VideoParameters.presetH1080_169.encoding.maxBitrate, maxFps: 30),
                simulcast: simulcast
            ),
            adaptiveStream: true,
            e2eeOptions: e2eeOptions,
            reportRemoteTrackStatistics: true
        )

        let connectTask = Task.detached { [weak self] in
            guard let self else { return }
            do {
                let currentTime = Int(Date().timeIntervalSince1970)
                if currentTime - self.genrateTokenTimeDuration > 30 {
                    Logger.info("\(logTag) token timeout")
                    return
                }
                try await self.room.connect(url: self.url,
                                            token: self.token,
                                            connectOptions: connectOptions,
                                            roomOptions: roomOptions)
            } catch {
                Logger.error("\(logTag): connect error \(error)")
                if let httpError = error as? LiveKitError {
                    if httpError.type == .timedOut {
                        // TODO：超时时候会去做重连的操作
                        if let serviceUrlManager,
                           serviceUrlManager.switchToNextUrl(),
                           let currentUrl = serviceUrlManager.currentUrl {
                            await MainActor.run {
                                self.url = currentUrl
                                Task {
                                    _ = try await self.connect()
                                }
                            }
                        } else {
                            // 到这属于还是异常并且也不会再重试了
                            Task {
                                await DTMeetingManager.shared.clearDisconnectErrorData()
                            }
                            DispatchMainThreadSafe {
                                DTToastHelper.toast(withText: Localized("METTING_CONNECT_EXCEPTION_TIPS"))
                            }
                            
                            throw error
                        }
                    } else {
                        // 其他的错误类型，直接删除
                        Logger.error("\(logTag): connect other error dismissView \(error)")
                        Task {
                            await DTMeetingManager.shared.clearDisconnectErrorData()
                        }
                    }
                }
            }
        }

        _connectTask = connectTask
        try await connectTask.value

        return room
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
//        messages.append(roomMessage)

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let json = try self.jsonEncoder.encode(roomMessage)
                try await self.room.localParticipant.publish(data: json)
            } catch {
                Logger.debug("Failed to encode data \(error)")
            }
        }
    }
    
    func presentShareView() {
        let shareView = CallScreenShareView(minimizeAction: { [weak self] in
            guard let self else { return }
            toolbarMinimizeTaped()
        })
            .environmentObject(self)
        let shareVC = DTHostingController(rootView: shareView)
        self.shareVC = shareVC
        shareVC.modalPresentationStyle = .fullScreen
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.present(shareVC, animated: false)
    }
    
    func presentInviteView() {
        let inviteVC = DTCallInviteMemberVC()
        inviteVC.isLiveKitCall = true
        let inviteNav = OWSNavigationController(rootViewController: inviteVC)
        self.inviteVC = inviteNav
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.present(inviteNav, animated: false)
    }
    
    func presentMuteActionSheet(_ participant: Participant) {
        guard DTMeetingManager.shared.openMuteOtherEnabled() else {
            Logger.info("\(logTag) remoteConfig not open muteOtherEnabled")
            return
        }
        
        var actions = [ActionSheetAction]()
        let muteAction = ActionSheetAction(title: "Mute", style: .default) { action in
            Task {
                await DTMeetingManager.shared.sendRemoteMicOffRoom(targetParticentId: participant.identity?.stringValue ?? "")
            }
            
        }
        actions.append(muteAction)
        
        let actionSheet = ActionSheetController()
        actionSheet.isDarkThemeOnly = true
        actionSheet.addAction(OWSActionSheets.cancelAction)
        actions.forEach { actionSheet.addAction($0) }
        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.present(actionSheet, animated: true)
    }
    
    func presentMuteAlertVC(_ participantId: String) {
        
        guard DTMeetingManager.shared.openMuteOtherEnabled() else {
            Logger.info("\(logTag) remoteConfig not open muteOtherEnabled")
            return
        }
        
        let muteAction = UIAlertAction(title: "Mute", style: .default) { action in
            Task {
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

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
        }
        cancelAction.setValue(Theme.alertCancelColor, forKey: "_titleTextColor")
        alertVC.addAction(cancelAction)

        let callWindow = OWSWindowManager.shared().callViewWindow
        let callVC = callWindow.findTopViewController()
        callVC.present(alertVC, animated: true)
    }

    func presentHangupActionSheet() {
        if DTMeetingManager.shared.isPresentedShare() || DTMeetingManager.shared.showScreenShare() {
            var alertActions: [UIAlertAction] = []
            let endMeetingAction = UIAlertAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { action in
                Task {
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
            }
            endMeetingAction.setValue(UIColor.color(rgbHex: 0xD9271E), forKey: "_titleTextColor")
            alertActions.append(endMeetingAction)
        
            let leaveMeetingAction = UIAlertAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { action in
                Task {
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
            }
            leaveMeetingAction.setValue(UIColor.color(rgbHex: 0xEAECEF), forKey: "_titleTextColor")
            alertActions.append(leaveMeetingAction)
         
            let alertVC = DTAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
            for action in alertActions {
                alertVC.addAction(action)
            }
 
            let cancelAction = UIAlertAction(title: Localized("HANGUP_CANCEL_MEETING"), style: .cancel) { action in
            }
            cancelAction.setValue(UIColor.color(rgbHex: 0xEAECEF), forKey: "_titleTextColor")
            alertVC.addAction(cancelAction)
 
            let callWindow = OWSWindowManager.shared().callViewWindow
            let callVC = callWindow.findTopViewController()
            callVC.present(alertVC, animated: true)
                
        } else {
            var actions = [ActionSheetAction]()
            let endMeetingAction = ActionSheetAction(title: Localized("HANGUP_END_MEETING"), style: .destructive) { action in
                Task {
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: true)
                }
                
            }
            actions.append(endMeetingAction)
            
            let leaveMeetingAction = ActionSheetAction(title: Localized("HANGUP_LEAVE_MEETING"), style: .default) { action in
                Task {
                    await self.toolbarEndCallTaped(forceEndGroupMeeting: false)
                }
                
            }
            actions.append(leaveMeetingAction)
            
            let actionSheet = ActionSheetController()
            actionSheet.isDarkThemeOnly = true
            actionSheet.addAction(OWSActionSheets.cancelAction)
            actions.forEach { actionSheet.addAction($0) }
            let callWindow = OWSWindowManager.shared().callViewWindow
            let callVC = callWindow.findTopViewController()
            callVC.present(actionSheet, animated: true)
        }
    }
    
    func setDenoiseFilter(enabled: Bool) {
        denoiseFilter.isEnabled = enabled
    }

    func isDenoiseFilterEnabled() -> Bool {
        return denoiseFilter.isEnabled
    }
}

// MARK: toolbar action
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
        //获取群信息
        if let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: currentCall.conversationId ?? ""),
           let groupThread = TSGroupThread.getWithGroupId(groupId) {
            //如果参会人不是群成员
            if let pid = partiantId.components(separatedBy: ".").first,
                      !groupThread.groupModel.groupMemberIds.contains(pid) {
                callManager.turnIntoInstantCall()
            }
        } else {
            //如果群不存在
            callManager.turnIntoInstantCall()
        }
    }
}

extension RoomContext {
    public func audioSessionDidChangePortType(_ portType: AVAudioSession.Port, isExternalConnected: Bool) {
        Logger.debug("\(logTag) portType: \(String(describing: lkContext?.portType)) => \(portType) isExternalConnected: \(String(describing: lkContext?.isExternalConnected)) => \(isExternalConnected)")

        lkContext?.setPortTypeAndExternal(portType, isExternalConnected:isExternalConnected)
    }
    
    public func audioSessionDidChangePortName(_ portName: String, isExternalConnected: Bool) {
        guard portName != lastPortName else {
            return
        }
        Logger.info("\(logTag) audiosession change portName: \(portName)")
        lastPortName = portName
        self.setDenoiseFilter(enabled: !DTMeetingManager.shared.isInputAirPods(portName: portName))
    }
}
