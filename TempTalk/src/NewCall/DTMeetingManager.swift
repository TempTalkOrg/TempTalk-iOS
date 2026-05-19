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
    
    // 会议重连的时候记录的参会人数据
    var reconnectingParticipants: [ParticipantSnapshot]?
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
            DispatchQueue.main.async { [weak self] in
                self?.startCallDurationTimer()
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
    
    //测速文件
    let clusterSpeedTester = ClusterSpeedTester()
    
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
                newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                    serverGroupId: gid,
                    fallbackName: fallbackRoomName,
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
        guard hasMeeting else {
            Logger.warn("\(logTag) refreshCurrentCallMuteState - no active meeting")
            return
        }
        Task {
            await muteAudio(isMute)
        }
    }

    // MARK: - CallKit Accept

    private func handleCallKitAccept(uuidString: String) {
        Logger.info("\(logTag) handleCallKitAccept - uuid: \(uuidString)")

        currentCall.callKitUUID = uuidString

        stopCallTimeoutTimer()

        let ckManager = DTCallKitManager.shared()
        guard let calling = ckManager.calling(fromUUID: uuidString) else {
            Logger.error("\(logTag) handleCallKitAccept - calling proto not found for: \(uuidString)")
            return
        }

        let is1on1Call = calling.conversationID?.hasNumber ?? false
        if !is1on1Call {
            ckManager.muteCurrentCall(true, uuidString: uuidString)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            ckManager.acceptCall(calling: calling)
        }
    }

    // MARK: - CallKit End

    private func handleCallKitEnd(uuidString: String) {
        Logger.info("\(logTag) handleCallKitEnd - uuid: \(uuidString)")

        let ckManager = DTCallKitManager.shared()
        guard let calling = ckManager.calling(fromUUID: uuidString) else {
            Logger.warn("\(logTag) handleCallKitEnd - calling proto not found, call may already be cleaned up")
            return
        }

        let targetRoomId = calling.roomID
        let currentRoomId = currentCall.roomId
        let isCurrentCall = (targetRoomId != nil && targetRoomId == currentRoomId)

        Logger.info("\(logTag) handleCallKitEnd - targetRoomId: \(targetRoomId ?? "nil"), currentRoomId: \(currentRoomId ?? "nil"), isCurrentCall: \(isCurrentCall)")

        if isCurrentCall, hasMeeting, currentCall.callKitUUID != uuidString {
            Logger.info("\(logTag) handleCallKitEnd - stale CallKit end ignored, state: \(lifecycleState), tracked: \(currentCall.callKitUUID ?? "nil"), event: \(uuidString)")
            return
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
