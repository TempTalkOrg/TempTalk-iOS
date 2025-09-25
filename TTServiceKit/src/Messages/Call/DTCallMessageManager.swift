//
//  DTCallMessageManager.swift
//  TTServiceKit
//
//  Created by undefined on 12/12/24.
//

import Foundation

public protocol DTCallMessageDelegate: NSObjectProtocol {
    
    func handleCallingMessage(roomId: String,
                              conversationId: DSKProtoConversationId?,
                              roomName: String?,
                              caller: String,
                              emk: Data,
                              publicKey: Data,
                              createCallMsg: Bool,
                              controlType: String?,
                              callees: [String]?,
                              timestamp: UInt64?,
                              envelopeSource: String?,
                              envelopeSourceDevice: UInt32?,
                              serverTimestamp: UInt64?)

    func handleJoinedMessage(roomId: String)
    
    func handleRemoteCanceledMessage(roomId: String)
    
    /// Handles when a local call was rejected
    /// - Parameters:
    ///   - roomId: The ID of the room where the call was rejected
    ///   - envelope: The envelope containing additional rejection metadata
    func handleLocalWasRejectedMessage(roomId: String, envelope: DSKProtoEnvelope)
    
    func handleWasHungupMessage(roomId: String)
    
}

@objcMembers open class DTCallMessageManager: NSObject, CallMessageHandlerProtocol {
    
    @objc public static let shared = DTCallMessageManager()
    public weak var delegate: DTCallMessageDelegate?
    
    @objc public func handleIncoming(envelope: DSKProtoEnvelope,
                                     callMessage: DSKProtoCallMessage,
                                     transaction: SDSAnyWriteTransaction) {
        
        // 根据 source 来判断是否是自己另一端来的消息
        let source = envelope.source
        let localNumber = self.tsAccountManager.localNumber(with: transaction)
        
        // server 推送消息时间戳与 systemShowTimestamp 差值, 表示消息在 server 停留时间
        let pushTimestamp = envelope.pushTimestamp
        // calling 消息中 roomId 为空时，使用该字段
        let envelopRoomId = envelope.roomID
        
        guard let callMessageDelegate = Self.shared.delegate else {
            Logger.error("callMessageDelegate is nil.")
            return
        }
        
        // calling: 发起 Call & 邀请他人时发送(1on1 不需要向自己的另一端设备发送, 入会后)
        if let calling = callMessage.calling {
            
            if let roomId = calling.roomID,
               let envelopRoomId,
               !roomId.isEmpty && !envelopRoomId.isEmpty,
               roomId != envelopRoomId { // envelop 中 roomId 和 CallMessage 中 roomId 都非空时，两者不相等报错
                Logger.error("calling roomid 不一致")
                // TODO: call throw error
                return
            }
            
            var roomId: String?
            if calling.hasRoomID {
                roomId = calling.roomID
            } else {
                if let envelopRoomId {
                    roomId = envelopRoomId
                }
            }
            
            guard let roomId else {
                Logger.error("roomId 为空")
                return
            }
            
            let conversationId = calling.conversationID
            let roomName = calling.roomName
            guard let caller = calling.caller else {
                Logger.error("caller 为空")
                return
            } // Call creator or 临时邀请人
            guard let emk = calling.emk else {
                Logger.error("emk 为空")
                return
            } // mk 的密文，需要用自己私钥解密
            guard let publicKey = calling.publicKey else {
                Logger.error("publicKey 为空")
                return
            } // 临时的 ecc 公钥
            
            // fix Livekit 漏洞
            if !(caller.caseInsensitiveCompare(source ?? "") == .orderedSame) {
                return
            }
            delegate?.handleCallingMessage(roomId: roomId,
                                           conversationId: conversationId,
                                           roomName: roomName,
                                           caller: caller,
                                           emk: emk,
                                           publicKey: publicKey,
                                           createCallMsg: calling.createCallMsg,
                                           controlType: calling.controlType,
                                           callees: calling.callees,
                                           timestamp: calling.timestamp,
                                           envelopeSource: envelope.source,
                                           envelopeSourceDevice: envelope.sourceDevice,
                                           serverTimestamp: envelope.systemShowTimestamp)
        } else if let joined = callMessage.joined {
            // [1on1]
            // caller & callee 成功入会时，同步给自己另一端(如果有)
            // 多人 Call 时，caller/callee 不用发送该消息，因为多人 Call 时收到 Calling 消息后，就可以显示 MeetingBar
            guard let roomId = joined.roomID else {
                Logger.error("roomId 为空")
                return
            }
            
            delegate?.handleJoinedMessage(roomId: roomId)
        } else if let cancel = callMessage.cancel { // call 取消
            // [1on1]
            // cancel: caller 取消 Call
            // 1on1 Call, 同步给自己另一端(如果有)和对方；caller 去及时清理数据，callee 关闭弹窗
            // 多人 Call 无需该消息，使用 Server 推送的 Call 结束 notify 消息即可

            guard let roomId = cancel.roomID else {
                Logger.error("roomId 为空")
                return
            }

            delegate?.handleRemoteCanceledMessage(roomId: roomId)
        } else if let reject = callMessage.reject { // 拒绝 call
            // reject: callee 拒绝加入 Call
            // 1on1 Call, 同步给自己另一端(如果有)和caller；callee去关闭弹窗；caller(仅发起一端)关闭弹窗，caller 两端清理数据
            // 多人 Call, 同步给自己另一端(如果有)
            guard let roomId = reject.roomID else {
                Logger.error("roomId 为空")
                return
            }
            
            delegate?.handleLocalWasRejectedMessage(roomId: roomId, envelope: envelope)
        } else if let hangup = callMessage.hangup { // 挂断 call
            // hangup: 1on1 Call一方挂断
            guard let roomId = hangup.roomID else {
                Logger.error("roomId 为空")
                return
            }
            
            delegate?.handleWasHungupMessage(roomId: roomId)
        } else {
            // TODO: call prod error
            let errorPayload = OWSAnalyticsEvents.messageManagerErrorCallMessageNoActionablePayload()
            Logger.error("\(errorPayload) \(envelope)")
        }
    }
}

// 1on1 caller -> call
