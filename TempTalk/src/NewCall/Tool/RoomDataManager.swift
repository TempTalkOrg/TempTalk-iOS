//
//  RoomDataManager.swift
//  Difft
//
//  Created by Henry on 2025/4/18.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import Combine
import LiveKit

struct RoomParticipant {
    var pid: String
    var isMuted: Bool
    var isConnected: Bool
    var isHost: Bool
    var isScreenShared: Bool
    var isSpeaking: Bool
}

@objcMembers
class RoomDataManager: NSObject, ObservableObject {
    static let shared: RoomDataManager = {
        let instance = RoomDataManager()
        return instance
    }()
    
    @Published var bulletType: RoomDelegateType = .roomDefault
    @Published var message: String = ""
    @Published var participantId: String = ""
    @Published var isMuted: Bool = false
    @Published var handsData: [String] = []
    @Published var hasRaiseHands: Bool = false
    @Published var localRaiseHand: Bool = false
     
    // 会议消息
    var messageMeetingPublisher = PassthroughSubject<String, Never>()
    var onMeetingUpdate: (() -> Void)?
    
    // pip发布器
    var messagePipPublisher = PassthroughSubject<String, Never>()
    var onPipUpdate: (() -> Void)?

    // 弹幕发布器
    var bulletMessagePublisher = PassthroughSubject<String, Never>()
    var onBulletMessageUpdate: (() -> Void)?
    
    // 举手发布器
    var raiseHandsPublisher = PassthroughSubject<String, Never>()
    var onRaiseHandsUpdate: (() -> Void)?

    private var cancellables: Set<AnyCancellable> = []
    private override init() {
        self.bulletType = .roomDefault
        self.message = ""
        self.participantId = ""
        self.isMuted = false
        self.handsData = []
        self.hasRaiseHands = false
        self.localRaiseHand = false
        
        super.init()

        defer {
            self.onMeetingUpdate = {
                self.messageMeetingPublisher.send("Message")
            }
            self.onPipUpdate = {
                self.messagePipPublisher.send("Message")
            }
            self.onBulletMessageUpdate = {
                self.bulletMessagePublisher.send("Message")
            }
            self.onRaiseHandsUpdate = {
                self.raiseHandsPublisher.send("Message")
            }
        }
    }  // 防止外部实例化
    
    func connectParticipant(participant: Participant) {
        DispatchMainThreadSafe {
            if let pid = participant.identity?.stringValue {
                let isLocal = pid.components(separatedBy: ".").first == TSAccountManager.shared.localNumber()
                self.bulletType = isLocal ? .localPartConnect : .remotePartConnect
                self.message = ""
                self.isMuted = false
                self.participantId = pid.components(separatedBy: ".").first ?? ""
                self.onBulletMessageUpdate?()
            }
            self.onMeetingUpdate?()
            self.onPipUpdate?()
        }
    }
    
    func disconnectParticipant(participant: Participant) {
        updateParticipantRoomStatus(participant: participant)
    }
    
    // 刷新mute状态
    func updateMuteParticipant(participant: Participant, isMuted: Bool) {
        //添加弹幕
        DispatchMainThreadSafe {
            self.bulletType = .remoteMute
            self.message = ""
            self.isMuted = isMuted
            self.participantId = participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
            self.onBulletMessageUpdate?()
            self.updateParticipantRoomStatus(participant: participant)
        }
    }
    
    func updateVideoMuteParticipant(participant: Participant) {
        self.onPipUpdate?()
    }
    
    // 开启屏幕分享状态
    func openScreenSharedParticipant(participant: Participant) {
        //添加弹幕
        DispatchMainThreadSafe {
            self.bulletType = .startScreenShare
            self.message = ""
            self.isMuted = false
            self.participantId = participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
            self.onBulletMessageUpdate?()
            self.updateParticipantRoomStatus(participant: participant)
        }
    }
    
    // 关闭共享状态
    func closeScreenSharedParticipant(participant: Participant) {
        updateParticipantRoomStatus(participant: participant)
    }
    
    // 刷新说话人状态
    func updateSeakingParticipant() {
        self.onMeetingUpdate?()
        self.onPipUpdate?()
    }
    
    func sendRTMBarrageMessage(pid: String, message: String) {
        //添加弹幕
        DispatchMainThreadSafe {
            self.bulletType = .RTMBarrage
            self.message = message
            self.isMuted = false
            self.participantId = pid
            self.onBulletMessageUpdate?()
        }
    }
    
    private func updateParticipantRoomStatus(participant: Participant) {
        self.onMeetingUpdate?()
        self.onPipUpdate?()
    }
    
    // 倒计时pip刷新
    func pipCountDownUpdate() {
        self.onPipUpdate?()
    }
    
    func updateRaiseHands(hands: [String]) {
        DispatchMainThreadSafe {
            if hands.isEmpty {
                self.hasRaiseHands = false
                self.localRaiseHand = false
                self.handsData = []
            } else {
                self.handsData = hands.map { item in
                    item.components(separatedBy: ".").first ?? item
                }
                if let roomCtx = DTMeetingManager.shared.roomContext, let pid = roomCtx.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first, !self.handsData.contains(pid) {
                    self.localRaiseHand = false;
                }
                self.hasRaiseHands = true
            }
            self.onRaiseHandsUpdate?()
            self.raiseHandsPublisher.send("message")
        }
    }
    
    func raiseLocalHand() {
        DispatchMainThreadSafe {
            if let roomCtx = DTMeetingManager.shared.roomContext, let participantId = roomCtx.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first {
                if !self.handsData.contains(participantId) {
                    self.handsData.append(participantId)
                    self.hasRaiseHands = true
                }
            }
            self.onRaiseHandsUpdate?()
            self.raiseHandsPublisher.send("message")
        }
    }
    
    func cancelHand(participantId: String) {
        DispatchMainThreadSafe {
            if let index = self.handsData.firstIndex(of: participantId) {
                self.handsData.remove(at: index)
            }
            if self.handsData.isEmpty {
                self.hasRaiseHands = false
            }
            if let roomCtx = DTMeetingManager.shared.roomContext, let pid = roomCtx.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first, !self.handsData.contains(pid) {
                self.localRaiseHand = false;
            }
            self.onRaiseHandsUpdate?()
            self.raiseHandsPublisher.send("message")
        }
    }
    
    func clearRoomDataSource() {
        DispatchMainThreadSafe {
            self.handsData.removeAll()
            self.handsData = []
            self.hasRaiseHands = false
            self.localRaiseHand = false
        }
    }
}
