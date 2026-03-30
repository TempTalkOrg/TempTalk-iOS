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
    var autoLeaveTipView: DTAutoLeaveTipView?
    var hasShowLeaveTipView: Bool = false
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
        case roomContextCreationFailed
        case invalidState
        case alreadyInMeeting

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
            case .alreadyInMeeting:
                return "Already in a meeting"
            }
        }
    }

    /// 状态锁，保护 lifecycleState 的线程安全
    private let stateLock = NSLock()

    /// 当前会议生命周期状态（内部存储）
    private var _lifecycleState: MeetingLifecycleState = .idle

    /// 当前会议生命周期状态（线程安全访问）
    var lifecycleState: MeetingLifecycleState {
        stateLock.withLock { _lifecycleState }
    }

    /// 原子性尝试转换状态（仅当当前状态为 expectedState 时才转换）
    /// - Returns: 是否成功转换
    @discardableResult
    func tryTransition(from expectedState: MeetingLifecycleState, to newState: MeetingLifecycleState) -> Bool {
        stateLock.withLock {
            guard _lifecycleState == expectedState else {
                Logger.error("\(logTag) State transition failed: expected \(expectedState), but was \(_lifecycleState)")
                return false
            }
            let oldState = _lifecycleState
            _lifecycleState = newState
            Logger.info("\(logTag) State: \(oldState) -> \(newState)")
            handleStateChange(to: newState)
            return true
        }
    }

    /// 强制转换到目标状态
    func forceTransition(to newState: MeetingLifecycleState) {
        stateLock.withLock {
            let oldState = _lifecycleState
            _lifecycleState = newState
            Logger.info("\(logTag) State: \(oldState) -> \(newState) (forced)")
            handleStateChange(to: newState)
        }
    }

    /// 处理状态变化的副作用（在锁内调用，保持简单）
    private func handleStateChange(to newState: MeetingLifecycleState) {
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
            DispatchQueue.main.async { [weak self] in
                self?.startCallDurationTimer()
            }
        case .disconnecting:
            break
        }

        // 将当前呼叫对应的 Join 条与生命周期同步（只做 add，不在本地退出时移除，避免会议仍在时条目消失）
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

    /// 当前是否在会议中（兼容旧代码）
    var inMeeting: Bool {
        get { lifecycleState == .connected }
        set {
            if newValue {
                tryTransition(from: .connecting, to: .connected)
            }
        }
    }

    /// 当前是否有会议(包含正在连接中的)（兼容旧代码）
    var hasMeeting: Bool {
        get { lifecycleState.isActive }
        set {
            if newValue {
                tryTransition(from: .idle, to: .connecting)
            } else {
                forceTransition(to: .idle)
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

        let callMessageManager = DTCallMessageManager.shared
        callMessageManager.delegate = self
        registerNotifications()

        // Darwin notification is registered in DTCallKitManager.init
        // No need to register here to avoid duplicate registration
        LiveKitSDK.setLogger(OSLogger(minLevel: .debug))
    }
    
}
