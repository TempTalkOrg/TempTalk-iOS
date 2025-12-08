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
    
    let contactsManager: OWSContactsManager = Environment.shared.contactsManager
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
    // 视图的状态
    var answerVCPresentationStyle: AnswerVCPresentationStyle = .windowManager
    // startcall 优化
    var startCallThread: TSThread?
    // startcall 优化
    var startCallRecipientIds: [String]? = nil
    // 区分start还是accept
    var fromSource: String?
    // 1v1的另一端是否开启CriticalAlert
    var otherCriticalAlert: Bool = false
    
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
    
    /// 通话状态枚举
    enum CallState {
        case idle
        case connecting
        case connected
        case disconnecting
        case error
    }
    
    /// 通话错误枚举
    enum CallError: Error, LocalizedError {
        case messageCreationFailed
        case connectionFailed
        case roomContextCreationFailed
        case invalidState
        
        var errorDescription: String? {
            switch self {
            case .messageCreationFailed:
                return "Failed to create call message"
            case .connectionFailed:
                return "Failed to connect to call"
            case .roomContextCreationFailed:
                return "Failed to create room context"
            case .invalidState:
                return "Invalid call state"
            }
        }
    }
    
    /// 状态管理串行队列
    let stateQueue = DispatchQueue(label: "com.temptalk.call.state", qos: .userInitiated)
    
    /// 当前通话状态
    var callState: CallState = .idle {
        didSet {
            Logger.info("\(logTag) Call state changed: \(oldValue) -> \(callState)")
            handleStateChange(from: oldValue, to: callState)
        }
    }
    
    /// 线程安全的状态更新
    func updateCallState(_ newState: CallState) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.callState = newState
        }
    }
    
    /// 当前是否在会议中
    var inMeeting: Bool = false {
        willSet {
            if newValue {
                hasMeeting = true
                updateCallState(.connecting)
            } else {
                updateCallState(.idle)
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
        
        let callMessageManager = DTCallMessageManager.shared
        callMessageManager.delegate = self
        registerNotifications()
        
        NotificationHandler.shared.registerDarwinNotification()
        LiveKitSDK.setLogger(OSLogger(minLevel: .debug))
    }
    
    /// 处理状态变化
    private func handleStateChange(from oldState: CallState, to newState: CallState) {
        switch (oldState, newState) {
        case (.idle, .connecting):
            Logger.info("\(logTag) Starting call connection")
        case (.connecting, .connected):
            Logger.info("\(logTag) Call connected successfully")
        case (.connected, .disconnecting):
            Logger.info("\(logTag) Starting call disconnection")
        case (.disconnecting, .idle):
            Logger.info("\(logTag) Call disconnected successfully")
        case (_, .error):
            Logger.error("\(logTag) Call entered error state")
            handleCallError()
        default:
            Logger.warn("\(logTag) Unexpected state transition: \(oldState) -> \(newState)")
        }
    }
}
