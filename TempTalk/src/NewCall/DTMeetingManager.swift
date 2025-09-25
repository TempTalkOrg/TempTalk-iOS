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
import Logging

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
        
    override init() {
        super.init()
        
        let callMessageManager = DTCallMessageManager.shared
        callMessageManager.delegate = self
        registerNotifications()
        
        NotificationHandler.shared.registerDarwinNotification()
        LoggingSystem.bootstrap {_ in
            return LivekitLoggerHandler()
        }
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
        currentCall.isConnecting = false
        currentCall = DTLiveKitCallModel()
        inMeeting = false
        hasMeeting = false
        
        visibleParticipants.removeAll()
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
    
    /// 发起call
    /// - Parameters:
    ///   - thread: 发起1on1/group时传入
    ///   - recipientIds: 发起instant会议时需要
    ///   - displayLoading: 是否展示loading
    func startCall(thread: TSThread?,
                   recipientIds: [String]? = nil,
                   displayLoading: Bool = false) {
        
        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("\(logTag) No local number.")
            return
        }
        
        if let roomId = currentCall.roomId {
            Logger.info("\(logTag) the call has exist")
            DispatchMainThreadSafe {
                DTToastHelper.show(withInfo: Localized("MEETING_DOING_FREQUENTLY_TIPS"))
            }
            return
        }
        
        Logger.info("\(logTag) start call")
                 
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
        
        hasMeeting = true
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
        let collapseId = collapseId(timestamp: timestamp)
        let notification: [String: Any] = [
            "type": DTApnsMessageType.ENC_CALL.rawValue,
            "args": ["collapseId": collapseId]
        ]
        
        newCall.createCallMsg = createCallMsgEnabled()
        newCall.controlType = DTMeetingManager.sourceControlStart
        newCall.inviteCallees = recipientIdentifiers
        newCall.timestamp = timestamp
        
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
            
            let encryptedKeyResult = callMessage.keyResult
            let publicKey = encryptedKeyResult.eKey
            let stringPublicKey = publicKey.base64EncodedString()
            currentCall = newCall
            
            let endpoint = .startMeeting(type: newCall.callType,
                                         version: Self.meetingVersion,
                                         roomId: nil,
                                         conversation: conversationId,
                                         publicKey: stringPublicKey,
                                         encInfos: callMessage.encInfos,
                                         encMeta: nil,
                                         timestamp: timestamp,
                                         notification: notification,
                                         cipherMessages: callMessage.cipherMessages) as DTCallEndpoint
            
            Logger.info("[Time-consuming] start call begin date \(Date.ows_millisecondTimestamp())")
            
            await processingMeeting(
                endpoint: endpoint,
                e2eeKey: nil,
                thread: thread,
                recipientIds: recipientIds,
                timestamp: timestamp,
                source: "startCall"
            )
        }
        
    }
    
    var answerVC: DTHostingController<CallAnswerView>?
    func showAnswer(call: DTLiveKitCallModel, fromCallKit: Bool = false, onPlaySound: (() -> Void)? = nil) {

        hasMeeting = true
        currentCall = call
        
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
        
        func acceptCallRequest(type: CallType,
                               version: Int32,
                               roomId: String,
                               e2eeKey: Data?) async {
            
            let timestamp = Date.ows_millisecondTimestamp()
            let endpoint = .startMeeting(type: type,
                                         version: version,
                                         roomId: roomId,
                                         conversation: nil,
                                         publicKey: nil,
                                         encInfos: nil,
                                         encMeta: nil,
                                         timestamp: timestamp,
                                         notification: nil,
                                         cipherMessages: nil) as DTCallEndpoint
            
            await processingMeeting(endpoint: endpoint,
                                    e2eeKey: e2eeKey,
                                    isCaller: false,
                                    fromCallKit: fromCallKit,
                                    timestamp: timestamp,
                                    source: "acceptCall")
        }
        
        if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data, let publicKey, let emk {
            
            do {
                let result = try DTProtoAdapter().decryptKey(version: 2,
                                                             eKey: publicKey,
                                                             localPriKey: localPriKey,
                                                             eMKey: emk)
                let e2eeKey = result.mKey
                
                Task {
                    await acceptCallRequest(
                        type: type,
                        version: version,
                        roomId: roomId,
                        e2eeKey: e2eeKey
                    )
                }
            } catch {
                clearCurrentCall()
                DTToastHelper.showCallToast(Localized("MEETING_JOINED_FAILURE_TIPS"))
                Logger.error("\(logTag) decrypt error: \(error.localizedDescription)")
            }
        } else {
            Task {
                DispatchMainThreadSafe {
                    DTToastHelper.show01LoadingHudIsDark(Theme.isDarkThemeEnabled, in: nil)
                }
                
                await acceptCallRequest(
                    type: type,
                    version: version,
                    roomId: roomId,
                    e2eeKey: nil
                )
            }
        }
    }
    
    func processingMeeting(endpoint: DTCallEndpoint,
                           e2eeKey: Data?,
                           isCaller: Bool = true,
                           thread: TSThread? = nil,
                           recipientIds: [String]? = nil,
                           fromCallKit: Bool = false,
                           timestamp: UInt64? = nil,
                           source: String? = nil) async {
        Logger.info("[Time-consuming] processing request time begin \(Date.ows_millisecondTimestamp())")
        let result = await DTCallAPIManager().sendRequest(endpoint: endpoint)
        Logger.info("[Time-consuming] processing request time end \(Date.ows_millisecondTimestamp())")
        
        await MainActor.run {
            if roomContext != nil {
                Logger.info("\(logTag) roomContext not nil")
                DTToastHelper.hide()
                return
            }
            switch result {
            case .success(let data):
                guard let data else { return }
                
                if let tmpStale = data["stale"],
                   let stale = tmpStale.value as? [[String: Any]],
                   !stale.isEmpty {
                    // callees identityKeys失效处理
                    Logger.warn("\(logTag) ⚠️ calling stale, need to resend message!!! ")
                                       
                    storeFreshPrekeys(stale) { [weak self] in
                        guard let self else { return }
                        startCall(thread: thread, recipientIds: recipientIds)
                    }
                    
                    DTToastHelper.hide()
                    return
                }
                
                if let serverShowTimestamp = data["systemShowTimestamp"] {
                    currentCall.serverTimestamp = anyCodableToUInt64(serverShowTimestamp)
                }
                
                // 开始会议前的前置处理
                prepareForMeetingStart(endpoint: endpoint,
                                       isCaller: isCaller,
                                         thread: thread,
                                      timestamp: timestamp,
                                         source: source)
                
                DTToastHelper.hide()
                
                let serviceUrlManager = TTCallServiceUrlManager()
                serviceUrlManager.update(with: data)
                 
                guard let url = serviceUrlManager.currentUrl,
                      let tmpToken = data["token"],
                      let token = tmpToken.value as? String,
                      let tmpRoomId = data["roomId"],
                      let roomId = tmpRoomId.value as? String
                else { return }
                
                currentCall.roomId = roomId

                var k_e2eeKey: Data!
                if let e2eeKey {
                    k_e2eeKey = e2eeKey
                } else {
                    if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                       let tmpPublicKey = data["publicKey"],
                       let stringPublicKey = tmpPublicKey.value as? String,
                       let tmpEmk = data["emk"],
                       let stringEmk = tmpEmk.value as? String,
                       let publicKey = Data(base64Encoded: stringPublicKey),
                       let emk = Data(base64Encoded: stringEmk) {
                        
                        do {
                            let result = try DTProtoAdapter().decryptKey(version: 2,
                                                        eKey: publicKey,
                                                        localPriKey: localPriKey,
                                                        eMKey: emk)
                            k_e2eeKey = result.mKey
                        } catch {
                            clearCurrentCall()
                            DTToastHelper.showCallToast(Localized("MEETING_JOINED_FAILURE_TIPS"))
                            Logger.error("\(logTag) decrypt error: \(error.localizedDescription)")
                        }
                    }
                }
                currentCall.mKey = k_e2eeKey
                
                roomContext = RoomContext(url: url,
                                          token: token,
                                          e2eeKey: k_e2eeKey,
                                          lkContext: appContext)
                roomContext?.serviceUrlManager = serviceUrlManager
                
                Task {
                    if fromCallKit, !currentCall.isConnecting { // 锁屏状态下 callkit 接听后, 不会触发 view 的 onAppear, 需要手动 connect
                        do {
                            Logger.info("\(logTag) 1 start connect")
                            currentCall.isConnecting = true
                            let _ = try await roomContext?.connect()
                        } catch {
                            await MainActor.run {
                                Logger.error("\(logTag): \(error)")
                                Task {
                                    currentCall.isConnecting = false
                                    Logger.info("\(self.logTag) hangup callkit room connect failed")
                                    await hangupCall(needSyncCallKit: fromCallKit)
                                }
                                DTToastHelper.dismiss(withInfo: "connect room failed")
                            }
                        }
                    }
                }
                
                let contextView = RoomContextView()
                    .environmentObject(appContext!)
                    .environmentObject(roomContext!)
                
                let callVC = DTHostingController(rootView: AnyView(contextView))
                self.hostRoomContentVC = callVC
                hasMeeting = true
                
                if isCaller {
                    OWSWindowManager.shared().startCall(callVC, animated: true)
                    if case .private = currentCall.callType {
                        startCallTimeoutTimer()

                        // no need to play
                        if !fromCallKit {
                            playSound(.callOutgoing1v1, playMode: .playback)
                        }
                    }
                } else {
                    OWSWindowManager.shared().startCall(callVC, animated: false)
                    
                    if let answerVC {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                            guard let self = self else { return }
                            if answerVC.presentingViewController != nil {
                                answerVC.dismiss(animated: false) { [weak self] in
                                    self?.answerVC = nil
                                }
                            } else if let nav = answerVC.navigationController {
                                nav.popViewController(animated: false)
                                self.answerVC = nil
                            } else {
                                self.answerVC = nil
                            }
                         }
                    }
                }
            case .failure(let error):
                Logger.error("processingMeetingError: \(error.localizedDescription)")
                clearCurrentCall()
                DispatchMainThreadSafe {
                    DTToastHelper.hide()
                    DTToastHelper.dismiss(withInfo: Localized("SINGLE_CALL_APPLY_MEETING_FAIL"))
                }
            }
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
    
    func isPresentedShare() -> Bool {
        return currentCall.isPresentedShare
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
    
}
