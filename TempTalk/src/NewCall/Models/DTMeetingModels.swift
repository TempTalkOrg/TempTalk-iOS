//
//  DTMeetingModels.swift
//  TempTalk
//
//  Created by Ethan on 18/12/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import LiveKit

enum CallType: String {
    case `private` = "1on1"
    case group = "group"
    case instant = "instant"
}

/// 1on1 caller idle -> outgoing -> idle
///      callee idle -> answering -> idle
enum CallState: Int {
    case idle = 0
    case outgoing
    case alerting
    case answering
//    case connecting
}

/// 开始会议
enum StartCallType {
    case create // 发起会议
    case join   // 加入会议
}

/// 音频模式
enum AudioPlayMode {
    case current
    case playback
    case playAndRecord
}

var defaultRoomName: String {
    return "\(TSConstants.appDisplayName) Call"
}

@objcMembers public class DTLiveKitCallModel: NSObject, ObservableObject {
    
    @Published var callState: CallState = .idle {
        willSet {
            if newValue != callState {
                NotificationCenter.default.post(name: NSNotification.Name("CallStateDidChange"), object: nil)
            }
        }
    }
    @Published var callType: CallType = .instant
    var roomId: String?
    /// Client-generated id for one user-initiated start action. It stays stable across
    /// connection retries so control messages can address the call before `roomId` arrives.
    var clientCallId: String?
    /// True only for the local start-call path. Do not infer this from `isCaller`: the original
    /// caller can later join the same room again without being the initiator of that session.
    var isInitiator: Bool = false
    /// 当前通话对应的 CallKit UUID string（由 delegate 回调设置）
    var callKitUUID: String?
//    var roomName: String = ""
    var conversationId: String?
    var caller: String?
    var callees: [String]?
    var meetingName: String = defaultRoomName
    /// 仅收到calling自己入会时用
    var publicKey: Data?
    var emk: Data?
    var mKey: Data?
    
    var isPresentedShare: Bool = false
    /// 顶部、meeting bar计时
    var duration: TimeInterval?
    /// 是否展示本地的call消息
    var createCallMsg: Bool = false
    /// `createCallMsg == false` 时，群 start-call 通过普通 IM 补充 CallMsg。
    /// Signal 成功和快速挂断的成功回调可能竞争，必须只允许其中一个路径发送。
    private let groupStartCallMessageClaimLock = NSLock()
    private var didClaimGroupStartCallMessageDelivery = false
    /// calling的消息类型
    var controlType: String?
    /// 邀请人的id列表
    var inviteCallees: [String]?
    /// 已发送过 Critical Alert 的邀请人 id 列表（用于去重）
    var invitedCriticalAlertUsers: Set<String> = Set()
    /// 发起本地会议的时间戳
    var timestamp: UInt64?
    /// 发起本地会议的服务器时间戳（calling用evelop，其余用接口）
    var serverTimestamp: UInt64?
    /// calling消息的source
    var envelopeSource: String? = TSAccountManager.localNumber()
    /// calling的消息设备
    var envelopeSourceDevice: UInt32? = OWSDevice.currentDeviceId()
    /// sdk的sid，用于rtm清除信息使用
    var roomSid: String?
    /// startCall优化之后会返回响应body
    var ttcalResponseBody: Livekit_TTCallResponseBody?
    var ttcalResponseOptions: Livekit_TTCallOptions?

    func claimGroupStartCallMessageDelivery() -> Bool {
        groupStartCallMessageClaimLock.lock()
        defer { groupStartCallMessageClaimLock.unlock() }

        guard !didClaimGroupStartCallMessageDelivery else { return false }
        didClaimGroupStartCallMessageDelivery = true
        return true
    }
    
    private var _roomName: String = ""
    var roomName: String {
        get {
            if callType == .private {
                //获取昵称
                guard let caller = caller, !caller.isEmpty else {
                    return _roomName
                }
                let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: caller)
                if name == caller {
                    //获取昵称失败
                    return _roomName
                } else {
                    return name
                }
            } else if callType == .group {
                // _roomName 在接收/发起时已通过 DTGroupCryptoDisplayHelper.resolveGroupDisplayName 解析为本地真实群名
                return _roomName
            } else if callType == .instant {
                guard let caller = caller, !caller.isEmpty else {
                    return "instant call"
                }
                let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: caller)
                if name == caller {
                    // Never echo `_roomName` here: a group call resolved to instant for an outsider
                    // still carries the group name from the wire, and this is the one place it would
                    // reach the in-call title.
                    return "instant call"
                } else {
                    if DTParamsUtils.validateString(name).boolValue {
                        return "\(name)'s instant call"
                    } else {
                        return "instant call"
                    }
                }
            } else {
                return _roomName
            }
        }

        set(newValue) {
            _roomName = newValue
        }
    }
    
    var isCaller: Bool {
        guard let caller, !caller.isEmpty else {
            return false
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            return false
        }
        
        return caller == localNumber
    }

    /// The other side of the original 1v1 call: the callee(s) when this device is the caller,
    /// the caller otherwise. Inviting only these keeps the call at two people, so it stays 1v1.
    var oneToOnePeerIds: Set<String> {
        let peerIds: [String]
        if isCaller {
            if let callees, !callees.isEmpty {
                peerIds = callees
            } else if let conversationId, !conversationId.isEmpty {
                peerIds = [conversationId]
            } else {
                peerIds = []
            }
        } else if let caller, !caller.isEmpty {
            peerIds = [caller]
        } else {
            peerIds = []
        }

        return Set(peerIds.map {
            $0.components(separatedBy: ".").first ?? $0
        })
    }
        
    var othersideParticipantName: String {
        get {
            if isCaller {
                guard let othersideParticipant = callees?.first else {
                    return defaultRoomName
                }
                return Self.getDisplayName(recipientId: othersideParticipant)
            } else {
                guard let caller = caller else {
                    return defaultRoomName
                }
                return Self.getDisplayName(recipientId: caller)
            }
        }
    }
    
    // TODO: newcall duplicate with ParticipantView
    static func getDisplayName(recipientId: String) -> String {
         
        var participantName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: recipientId)
        participantName = participantName.removeBUMessage()
        
        return participantName

    }
    
    static func stringDuration(_ duration: TimeInterval) -> String {
        
        let totalSeconds = Int(duration)
        var stringDuration: String!
        if totalSeconds / 3600 >= 1 {
            stringDuration = String(format: "%01d:%02d:%02d", totalSeconds / 3600, (totalSeconds / 60) % 60, totalSeconds % 60)
        } else {
            stringDuration = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
        }
        
        return stringDuration
    }
//    var relatedThread: TSThread? {
//        get {
//            if let conversationId {
//                return TSThread()
//            } else {
//                return DTVirtualThread.
//            }
//        }
//    }

}

extension DTLiveKitCallModel: NSCopying {
      
    public func copy(with zone: NSZone? = nil) -> Any {
      
        let copy = DTLiveKitCallModel()
        copy.callState = self.callState
        copy.callType = self.callType
        copy.roomId = self.roomId
        copy.clientCallId = self.clientCallId
        // isInitiator is not copied: it belongs to one local start attempt, and bar/alert copies
        // outlive it — inheriting it would let a rejoin end a live meeting.
        copy.roomName = self.roomName
        copy.conversationId = self.conversationId
        copy.caller = self.caller
        copy.meetingName = self.meetingName
        copy.callees = self.callees?.map { $0 }
        copy.publicKey = self.publicKey
        copy.emk = self.emk
        copy.mKey = self.mKey
        copy.isPresentedShare = self.isPresentedShare
        
        return copy
    }
    
}


extension DSKProtoConversationId {
    
    func getCallInfo() -> (callType: CallType, conversationId: String?) {

        if hasGroupID, let groupID {
            let stringGroupId = TSGroupThread.transformToServerGroupId(withLocalGroupId: groupID)
            return (.group, stringGroupId)
        } else if hasNumber, let number {
            return (.private, number)
        }

        return (.instant, nil)
    }
    
}
