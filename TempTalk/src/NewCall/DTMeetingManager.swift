//
//  DTMeetingManager.swift
//  Signal
//
//  Created by Ethan on 25/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import SwiftUI
import LiveKit
import DTProto

@objcMembers open class DTMeetingManager: NSObject, ObservableObject, DTMeetingManagerProtocol {
    
    open override var logTag: String { "[newcall]" }
    
    static let shared = DTMeetingManager()
    static let meetingVersion: Int32 = 10
    static let sourceControlStart: String = "start-call"
    static let sourceControlInvite: String = "invite-members"
    
    private let contactsManager: OWSContactsManager = Environment.shared.contactsManager
    let callAlertManager: DTAlertCallViewManager = DTAlertCallViewManager.shared()
    //自动退出会议的定时器
    var sourceTimer: DispatchSourceTimer?
    static var countDownInterval: Int32 = 0;
    var hostRoomContentVC: DTHostingController<AnyView>?
    var lastParticipantsCount: Int32 = 0;
    // Timer
    var callTimeoutTimer: Timer?
    var callDurationTimer: Timer?
    var participantDisTimer: Timer?
    // 会议重连的时候记录的参会人数据
    var reconnectingParticipants: [ParticipantSnapshot]?
    // 会议的model
    lazy var currentCall: DTLiveKitCallModel = DTLiveKitCallModel()
    // 排序八宫格参会人
    var visibleParticipants: [Participant] = []
    // 自动退回的保护锁
    let timerLock = NSLock()
    // livesdk的错误状态
    var showErrorTost: Bool = false
    // answer的视图
    var answerVC: DTHostingController<CallAnswerView>?
    // startcall 优化
    var startCallThread: TSThread?
    // startcall 优化
    var startCallRecipientIds: [String]? = nil
    // 区分start还是accept
    var fromSource: String?
    
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
    
    /// 当前是否在会议中
    var inMeeting: Bool = false {
        willSet {
            if newValue {
                hasMeeting = true
            }
            OWSAudioSession.shared.inCalling = newValue
            if newValue {
                DispatchMainThreadSafe { [self] in
                    startCallDurationTimer()
                }
            }
        }
    }
        
    /// 当前是否有会议(包含正在连接中的)
    var hasMeeting: Bool = false {
        didSet {
            if hasMeeting {
                DeviceSleepManager.shared.addBlock(blockObject: self)
                OWSAudioSession.shared.inCalling = true
            } else {
                DeviceSleepManager.shared.removeBlock(blockObject: self)
                OWSAudioSession.shared.inCalling = false
            }
        }
    }
    
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
    
    override init() {
        super.init()
        
        let callMessageManager = DTCallMessageManager.shared
        callMessageManager.delegate = self
        registerNotifications()
        
        NotificationHandler.shared.registerDarwinNotification()
        LiveKitSDK.setLogger(OSLogger())
    }
    
    func clearCurrentCall(roomId: String? = nil) {
        
        // 多人会议自己退出但会议未结束时, 通知cell计时更新为Join
        if currentCall.callType != .private {
            NotificationCenter.default.postNotificationNameAsync(
                DTStickMeetingManager.kMeetingDurationUpdateNotification,
                object: nil
            )
        }
        
        if let rid = currentCall.roomId {
            Logger.info("\(self.logTag) clear lcoal message condition")
            handleMeetingEnded(meetingID: rid)
        }
        
        Logger.info("\(self.logTag) clear current call room data nil")
        currentCall.isPresentedShare = false
        currentCall = DTLiveKitCallModel()
        inMeeting = false
        hasMeeting = false
        
        visibleParticipants.removeAll()
        startCallThread = nil
        startCallRecipientIds = nil
        fromSource = nil
        answerVC = nil
        releaseAllTimer()
        TimerDataManager.shared.clearTimerDataSource()
        RoomDataManager.shared.clearRoomDataSource()
        videoViewPool.removeAll()
        currentlyDisplayedIdentity = nil
        currentlyDisplayedSid = nil
        currentlyCameraEnabled = false
        DTCallKitManager.shared().isLocalEndCall = false
    }
    
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
    
    /// 发起call - 重构版本，直接使用 LiveKit SDK 连接
    /// - Parameters:
    ///   - thread: 发起1on1/group时传入
    ///   - recipientIds: 发起instant会议时需要
    ///   - displayLoading: 是否展示loading
    func startCall(thread: TSThread?,
                   recipientIds: [String]? = nil,
                   displayLoading: Bool = false) {
        
        // 防抖：已有会议或正在连接中直接返回
        guard !hasMeeting else {
            Logger.info("\(logTag) already in meeting or connecting, ignore duplicate startCall")
            return
        }
        hasMeeting = true

        if let thread = thread {
            startCallThread = thread
        }
        
        if let recipientIds = recipientIds {
            startCallRecipientIds = recipientIds
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("\(logTag) No local number.")
            return
        }
        
        if let body = currentCall.ttcalResponseBody {
            Logger.info("\(logTag) the call has exist")
            DispatchMainThreadSafe {
                DTToastHelper.show(withInfo: Localized("MEETING_DOING_FREQUENTLY_TIPS"))
            }
            return
        }
        
        Logger.info("\(logTag) start call with direct LiveKit connection")
                 
        var callType: CallType = .instant
        var conversationId: String?
        var roomName = ""
        var recipientIdentifiers = [String]()
        if let thread {
            if thread.isGroupThread(),
               let groupThread = thread as? TSGroupThread {
                Logger.info("\(logTag) currentThread is groupThread")
                callType = .group
                conversationId = groupThread.serverThreadId
                roomName = thread.name(with: nil)
            } else if let contactThread = thread as? TSContactThread {
                Logger.info("\(logTag) currentThread is TSContactThread")
                let contactIdentifier = contactThread.contactIdentifier().components(separatedBy: ".").first ?? ""
                callType = .private
                conversationId = contactIdentifier
                
                if let signalAccount = contactsManager.signalAccount(forRecipientId: contactIdentifier),
                   let contact = signalAccount.contact {

                    if let remark = contact.remark {
                        roomName = remark
                    } else {
                        roomName = contact.fullName
                    }
                }
            }
            
            recipientIdentifiers = thread.recipientIdentifiers
            recipientIdentifiers.append(localNumber)
            
            let filteredIdentifiers = recipientIdentifiers.map { recipient in
                return recipient.split(separator: ".").first.map { String($0) } ?? recipient
            }
            
            recipientIdentifiers = filteredIdentifiers

        } else {
            if let recipientIds {
                recipientIdentifiers = recipientIds
            }
            
            let localName = contactsManager.displayName(forPhoneIdentifier: localNumber)
            roomName = "\(localName)'s Meeting"
        }
        
        if displayLoading {
            DispatchMainThreadSafe {
                DTToastHelper.show01LoadingHudIsDark(Theme.isDarkThemeEnabled, in: nil)
            }
        }
        
        let newCall = DTLiveKitCallModel()
        newCall.caller = localNumber
        newCall.roomName = roomName
        newCall.callType = callType
        newCall.callState = .outgoing
        newCall.conversationId = conversationId
        Logger.info("\(logTag) currentCall callType is \(callType)")

        if newCall.callType == .private {
            newCall.callees = recipientIdentifiers.filter({
                $0 != localNumber
            })
        }
        
        let timestamp = Date.ows_millisecondTimestamp()
        newCall.timestamp = timestamp
        newCall.createCallMsg = createCallMsgEnabled()
        newCall.controlType = DTMeetingManager.sourceControlStart
        newCall.inviteCallees = recipientIdentifiers
        
        currentCall = newCall
        
        // 重置评分触发标志，为新通话做准备
        hasTriggeredRating = false
        
        // 直接使用 LiveKit SDK 连接，不再依赖 v1/call/start 接口
        Task {
            let mKey = DTProtoAdapter().generateKey(version: Self.meetingVersion)
            
            guard let callMessage = await createCallMessage(
                localNumber: localNumber,
                callType: newCall.callType,
                conversationId: conversationId,
                caller: newCall.caller,
                recipientIds: recipientIdentifiers,
                roomId: nil,
                roomName: newCall.roomName,
                mKey: mKey,
                createCallMsg: createCallMsgEnabled(),
                controlType: DTMeetingManager.sourceControlStart,
                callees: [],
                timestamp: timestamp) else {
                return
            }
            let stringPublicKey = callMessage.keyResult.eKey.base64EncodedString()
            
            let protoMessages: [Livekit_TTCipherMessages] = parseCipherMessages(callMessage.cipherMessages)
            let protoEncInfos: [Livekit_TTEncInfo] = parseEncInfoArray(callMessage.encInfos)
            
            fromSource = "startCall"
            
            await connectDirectlyToLiveKit(
                callType: callType,
                conversationId: conversationId,
                timestamp: timestamp,
                cipherMessages: protoMessages,
                encInfos: protoEncInfos,
                publicKey: stringPublicKey
            )
        }
    }
    
    private func connectDirectlyToLiveKit(
        callType: CallType,
        roomId: String? = nil,
        conversationId: String?,
        timestamp: UInt64,
        isCaller: Bool = true,
        fromCallKit: Bool = false,
        cipherMessages: [Livekit_TTCipherMessages]?,
        encInfos: [Livekit_TTEncInfo]?,
        publicKey: String?
    ) async {
        Logger.info("\(logTag) connecting directly to LiveKit with ttCallRequest")
        
        do {
            currentCall.timestamp = timestamp
            // 1. 获取 token
            let token = try await requestAuthToken()
            let collapseId = collapseId(timestamp: timestamp)

            
            // 2. 构建请求
            let connectOptions = buildConnectOptions(
                callType: callType,
                roomId: roomId,
                conversationId: conversationId,
                timestamp: timestamp,
                publicKey: publicKey,
                cipherMessages: cipherMessages,
                encInfos: encInfos,
                collapseId: collapseId,
                token: token
            )
            
            // 3. 初始化房间
            guard await setupRoomContextIfNeeded(token: token, publicKey: publicKey ?? "") else {
                await MainActor.run {
                    DTToastHelper.hide()
                    DTToastHelper.dismiss(withInfo: "roomContext connect room failed")
                }
                return
            }
            await MainActor.run {
                DTToastHelper.hide()
                presentCallUI(callType: callType, isCaller: isCaller, fromCallKit: fromCallKit)
            }
            
            // 4. 连接
            await connectRoomSafely(fromCallKit: fromCallKit, connectOptions: connectOptions)
        } catch {
            Logger.error("\(logTag) request token error: \(error)")
            // 失败时回滚状态，避免卡住
            await hangupCall(needSyncCallKit: false,
                             isByLocal: true,
                             forceEndGroupMeeting: false,
                             roomId: currentCall.roomId,
                             removeMeetingBar: false,
                             showErrorToast: true)
        }
    }
    
    /// 构建 Protobuf 请求
    private func buildConnectOptions(
        callType: CallType,
        roomId: String?,
        conversationId: String?,
        timestamp: UInt64,
        publicKey: String? = nil,
        cipherMessages: [Livekit_TTCipherMessages]? = nil,
        encInfos: [Livekit_TTEncInfo]? = nil,
        collapseId: String,
        token: String
    ) -> ConnectOptions {
        var connectOptions = ConnectOptions()
        if let cipherMessages = cipherMessages,
            let encInfos = encInfos,
            let publicKey = publicKey {
            connectOptions = ConnectOptions(
                reconnectAttempts: 20,
                reconnectAttemptDelay: 2,
                ttCallRequest: Livekit_TTCallRequest.with {
                    $0.token = token
                    $0.startCall = Livekit_TTStartCall.with {
                        $0.type = callType.rawValue
                        $0.version = Self.meetingVersion
                        $0.timestamp = Int64(timestamp)
                        $0.conversationID = conversationId ?? ""
                        $0.publicKey = publicKey
                        $0.cipherMessages = cipherMessages
                        $0.encInfos = encInfos
                        $0.notification = Livekit_TTNotification.with {
                            $0.type = Int32(DTApnsMessageType.ENC_CALL.rawValue)
                            $0.args = .with { $0.collapseID = collapseId }
                        }
                    }
                    $0.userAgent = TSConstants.appUserAgent
                },
                userAgent: TSConstants.appUserAgent
            )
        } else if let roomId = roomId {
            connectOptions = ConnectOptions(
                reconnectAttempts: 20,
                reconnectAttemptDelay: 2,
                ttCallRequest: Livekit_TTCallRequest.with {
                    $0.token = token
                    $0.startCall = Livekit_TTStartCall.with {
                        $0.type = callType.rawValue
                        $0.roomID = roomId
                        $0.version = Self.meetingVersion
                        $0.timestamp = Int64(timestamp)
                    }
                    $0.userAgent = TSConstants.appUserAgent
                },
                userAgent: TSConstants.appUserAgent
            )
        }
        
        return connectOptions
    }
    
    /// 初始化房间上下文
    @MainActor
    private func setupRoomContextIfNeeded(token: String, publicKey: String) async -> Bool {
        if roomContext != nil {
            Logger.info("\(logTag) roomContext not nil")
            DTToastHelper.hide()
            return false
        }
        let serviceUrlManager = TTCallServiceUrlManager()
        guard let url = await serviceUrlManager.getCurrentUrl() else { return false }
        
        roomContext = RoomContext(url: url, token: token, lkContext: appContext)
        roomContext?.serviceUrlManager = serviceUrlManager
        return true
    }
    
    /// 展示通话 UI
    @MainActor
    private func presentCallUI(callType: CallType, isCaller: Bool, fromCallKit: Bool) {
        let contextView = RoomContextView()
            .environmentObject(appContext!)
            .environmentObject(roomContext!)
        
        let callVC = DTHostingController(rootView: AnyView(contextView))
        self.hostRoomContentVC = callVC
        hasMeeting = true
        
        if isCaller {
            OWSWindowManager.shared().startCall(callVC, animated: true)
            if case .private = callType {
                // 仅 1v1 主叫启动超时计时器
                startCallTimeoutTimer()
                if !fromCallKit {
                    playSound(.callOutgoing1v1, playMode: .playback)
                }
            }
        } else {
            OWSWindowManager.shared().startCall(callVC, animated: false)
            dismissAnswerVCIfNeeded()
        }
    }
    
    /// 处理被叫时的 answerVC
    @MainActor
    private func dismissAnswerVCIfNeeded() {
        guard let answerVC else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if answerVC.presentingViewController != nil {
                answerVC.dismiss(animated: false) { self.answerVC = nil }
            } else if let nav = answerVC.navigationController {
                nav.popViewController(animated: false)
                self.answerVC = nil
            } else {
                self.answerVC = nil
            }
        }
    }
    
    /// 安全发起连接
    private func connectRoomSafely(fromCallKit: Bool, connectOptions: ConnectOptions) async {
        Logger.info("\(logTag) starting direct LiveKit connection with ttCallRequest")
        do {
            let _ = try await roomContext?.connect(connectOptions: connectOptions)
        } catch {
            Logger.info("\(self.logTag) hangup callkit room connect failed")
            await hangupCall(needSyncCallKit: fromCallKit)
            await DTToastHelper.dismiss(withInfo: "connect room failed")
        }
    }
    
    func showAnswer(call: DTLiveKitCallModel, fromCallKit: Bool = false, onPlaySound: (() -> Void)? = nil) {

        hasMeeting = true
        currentCall = call
        
        // 重置评分触发标志，为新通话做准备
        hasTriggeredRating = false
        
        Logger.info("\(logTag) show answer controller: fromCallKit=\(fromCallKit)")
        
        guard let publicKey = call.publicKey, let emk = call.emk else {
            Logger.error("\(logTag) publicKey or emk is nil.")
            DTToastHelper.showCallToast("Unkonwn caller information")
            return
        }
        
        guard let caller = call.caller else {
            Logger.error("\(logTag) No caller information.")
            DTToastHelper.showCallToast("Unkonwn caller information")
            return
        }
        
        guard let roomId = call.roomId else {
            Logger.error("\(logTag) No roomId information.")
            DTToastHelper.showCallToast("Unkonwn call information")
            return
        }
              
        Task {
            if let result = await DTMeetingManager.checkRoomIdValid(roomId) {
                if result.anotherDeviceJoined || result.userStopped {
                    Logger.info("\(logTag) checkRoomIdValid anotherDeviceJoined\(result.anotherDeviceJoined) userStopped\(result.userStopped)")
                    return
                }
                
                onPlaySound?()
                
                if fromCallKit { // 点击 callkit answer, 应用内同步接听
                    Logger.info("\(logTag) answer from CallKit")
                    handleMeetingBar(call: call, action: .add)
                    answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: true)
                } else {
                    DispatchMainThreadSafe {
                        self.startCallTimeoutTimer()
                    }
                }
                
                DispatchMainThreadSafe {
                    let answerVC = DTHostingController(rootView:
                                                        CallAnswerView(
                                                            currentCall: call,
                                                            autoAccept: fromCallKit,
                                                            isConnecting: fromCallKit,
                                                            onAnswer: { [weak self] in
                        guard let self else { return }
                        Logger.info("\(logTag) answer from alertView")
                        self.answerVC = nil
                        stopCallTimeoutTimer()
                        answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: false)
                                                            },
                                                            onDecline: { [weak self] in
                        guard let self else { return }
                        
                        Logger.info("\(logTag) reject from alertView")
                        self.answerVC = nil
                        stopCallTimeoutTimer()
                        if currentCall.callType != .private {
                            // 多人会议拒接时需要展示bar
                            handleMeetingBar(call: call, action: .add)
                        }
                        Task {
                            // reject
                            await self.rejectRemoteCall()
                            Logger.info("\(self.logTag) reject remote call")
                        }
                    }))
                            
                    OWSWindowManager.shared().startCall(answerVC, animated: !fromCallKit)
                    self.answerVC = answerVC
                }
            }
        }
    }
    
    private func answerCall(caller: String, roomId: String, publicKey: Data, emk: Data, fromCallKit: Bool) {
        
        stopSound()
        
        Logger.info("\(logTag) answer meeting")
        
        acceptCall(type: currentCall.callType,
                   roomId: roomId,
                   publicKey: publicKey,
                   emk:emk,
                   fromCallKit: fromCallKit)
        if !fromCallKit {
            DTCallKitManager.shared().answerCallAction(caller)
        }
    }
    
    func acceptCall(call: DTLiveKitCallModel) {
        
        currentCall = call
        guard let roomId = call.roomId else {
            Logger.error("\(logTag) accept call roomid nil")
            return
        }
        
        Logger.info("\(logTag) accept meeting")

        DTMeetingManager.shared.acceptCall(
            type: call.callType,
            roomId: roomId,
            publicKey: nil,
            emk: nil,
            fromCallKit: false
        )
    }
        
    func acceptCall(type: CallType,
                    roomId: String,
                    version: Int32 = DTMeetingManager.meetingVersion,
                    publicKey: Data?,
                    emk: Data?,
                    fromCallKit: Bool) {
        
        Logger.info("\(logTag) accept call with direct LiveKit connection")
        
        // 直接使用 LiveKit SDK 连接，不再依赖 v1/call/start 接口
        Task {
            fromSource = "acceptCall"
            
            await connectDirectlyToLiveKit(
                callType: type,
                roomId: roomId,
                conversationId: currentCall.conversationId,
                timestamp: Date.ows_millisecondTimestamp(),
                isCaller: false,
                fromCallKit: fromCallKit,
                cipherMessages: nil,
                encInfos: nil,
                publicKey: nil
            )
        }
    }
    
    private var audioPlayer: OWSAudioPlayer?
    func playSound(_ sound: OWSSound, isLoop: Bool = true, playMode: AudioPlayMode) {
        
        Logger.info("play sound: --\(OWSSounds.displayName(for: sound))")
        stopSound()

        let player = OWSSounds.audioPlayer(for: sound)
        player?.isLooping = isLoop
        
        if playMode == .playback {
            player?.playWithPlaybackAudioCategory()
        } else if playMode == .playAndRecord {
            player?.playWithPlayAndRecordAudioCategory()
        } else {
            player?.playWithCurrentAudioCategory()
        }
        
        self.audioPlayer = player
    }
        
    func stopSound() {
        DispatchMainThreadSafe { [self] in
            if let audioPlayer {
                audioPlayer.stop()
                self.audioPlayer = nil
            }
        }
    }
    
    public func startLiveKitCall(thread: TSThread,
                                 startCall: @escaping () -> Void,
                                 joinCall: @escaping (DTLiveKitCallModel) -> Void ) {
        if let targetCall = currentThreadTargetCall(thread) {
            var inMeeting = false;
            for liveKitModel in allMeetings {
                if (liveKitModel.conversationId == targetCall.conversationId) {
                    inMeeting = true
                }
            }
            if inMeeting {
                joinCall(targetCall)
            } else {
                startCall()
            }
        } else {
            startCall()
        }
    }
    
    func minimizeAction() {
        minimizeCallWindow()
    }
    
    func inviteAction() {
        let inviteVC = DTCallInviteMemberVC()
        inviteVC.isLiveKitCall = true
        let inviteNav = OWSNavigationController(rootViewController: inviteVC)
        guard let rootNav = OWSWindowManager.shared().callViewWindow.rootViewController as? UINavigationController else {
            return
        }
        
        rootNav.present(inviteNav, animated: true)
    }
    
    func dealConnetedSuccess(with body: Livekit_TTCallResponseBody) {
        
        if DTParamsUtils.validateString(body.roomID).boolValue {
            currentCall.roomId = body.roomID
        }
        
        if DTParamsUtils.validateArray(body.stale).boolValue {
            var tempStales: [[String: Any]] = []
            let stales: [Livekit_TTExceptionRecipient] = body.stale
        
            for stale in stales {
                var dict: [String: Any] = [:]
                dict["uid"] = stale.uid
                dict["identityKey"] = stale.identityKey
                dict["registrationId"] = stale.registrationID
                
                tempStales.append(dict)
            }
            
            storeFreshPrekeys(tempStales) { [weak self] in
                guard let self else { return }
                startCall(thread: startCallThread, recipientIds: startCallRecipientIds)
            }
            
            DTToastHelper.hide()
            return
        }
        
        if DTParamsUtils.validateNumber(body.systemShowTimestamp as NSNumber).boolValue {
            currentCall.serverTimestamp = UInt64(body.systemShowTimestamp)
        }
        
        let isCaller = fromSource == "startCall"
        // 开始会议前的前置处理
        prepareForMeetingStart(isCaller: isCaller,
                                 thread: startCallThread,
                               timestamp: currentCall.timestamp,
                                 source: fromSource)
        
        DispatchMainThreadSafe {
            DTToastHelper.hide()
        }
    }
}

extension DTMeetingManager {
    func parseCipherMessages(_ dictArray: [[String: Any]]) -> [Livekit_TTCipherMessages] {
        return dictArray.compactMap { dict in
            var msg = Livekit_TTCipherMessages()
            
            if let content = dict["content"] as? String {
                msg.content = content
            }
            if let uid = dict["uid"] as? String {
                msg.uid = uid
            }
            if let regID = dict["registrationId"] as? Int {
                msg.registrationID = Int32(regID)
            } else if let regID = dict["registrationId"] as? Int32 {
                msg.registrationID = regID
            } else if let regID = dict["registrationId"] as? String, let intVal = Int32(regID) {
                msg.registrationID = intVal
            }
            
            return msg
        }
    }
    
    func parseEncInfoArray(_ dictArray: [[String: Any]]) -> [Livekit_TTEncInfo] {
        return dictArray.compactMap { dict in
            var info = Livekit_TTEncInfo()
            
            if let uid = dict["uid"] as? String {
                info.uid = uid
            }
            if let emk = dict["emk"] as? String {
                info.emk = emk
            }
            
            return info
        }
    }
    
    func requestAuthToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    let invalidError = NSError(domain: "com.temptalk.call.token",
                                      code: -10000,
                                      userInfo: [NSLocalizedDescriptionKey: "token invalid"])
                    continuation.resume(throwing: invalidError)
                }
            }
        }
    }
    
    func isPresentedShare() -> Bool {
        return currentCall.isPresentedShare
    }
    
}
