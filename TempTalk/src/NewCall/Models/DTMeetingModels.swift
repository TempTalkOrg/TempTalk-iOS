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

let defaultRoomName = "TempTalk Call"

@objcMembers public class DTLiveKitCallModel: NSObject, ObservableObject {
    
    var callState: CallState = .idle
    @Published var callType: CallType = .instant
    var roomId: String?
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
    /// calling的消息类型
    var controlType: String?
    /// 邀请人的id列表
    var inviteCallees: [String]?
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
    /// 是否当前会议已经正在连接中
    var isConnecting: Bool = false
    
    private var _roomName: String = ""
    var roomName: String {
        get {
            if callType == .private {
                //获取昵称
                let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: caller)
                if name == caller {
                    //获取昵称失败
                    return _roomName
                } else {
                    return name
                }
            } else if callType == .group {
                if let gid = conversationId,
                    let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
                   let groupThread = TSGroupThread.getWithGroupId(groupId) {
                    return groupThread.name(with: nil)
                } else {
                    return _roomName
                }
            } else if callType == .instant {
                let name = Environment.shared.contactsManager.displayName(forPhoneIdentifier: caller)
                if name == caller {
                    //获取昵称失败
                    return "\(_roomName)'s instant call"
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
