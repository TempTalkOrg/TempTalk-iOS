//
//  DTMeetingManager+Message.swift
//  TempTalk
//
//  Created by Ethan on 24/12/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import DTProto
import LiveKit

enum DTCallMessageType: String {
    // 1on1 | instant | group caller inviter (1on1不发给自己, 多人需要发给自己用来展示bar)
    case calling
    // 1on1 | instant | group callee sync to link device (1on1被叫发, 多人被叫都发用来终止振铃)
    case joined
    // 1on1 caller cancel (1on1主叫发)
    case cancel
    // callee reject (1on1被叫给所有人发, 多人只发自己)
    case reject
    // 1on1 calller/callee to otherside (1on1自己给所有人发)
    case hangup
}

private enum RTMKeys {
    static let topic = "topic"
    static let text = "text"
    static let identities = "identities"
    static let sendTimestamp = "sendTimestamp"
    static let uuid = "uuid"
    static let signature = "signature"
    static let payload = "payload"
    static let hands = "hands"
}

extension DTMeetingManager {
    
    func createCallMessage(
        localNumber: String,
        callType: CallType,
        msgType: DTCallMessageType = .calling,
        conversationId: String?,
        caller: String?,
        recipientIds: [String],
        roomId: String?,
        roomName: String?,
        mKey: Data?,
        createCallMsg: Bool? = false,
        controlType: String? = nil,
        callees: [String]?,
        timestamp: UInt64?
    ) async -> (cipherMessages: [[String: Any]], encInfos: [[String: Any]], keyResult: DTEncryptedKeyResult)? {

        await requestPublicKeysIfNeed(identifiers: recipientIds)
        
        let sessionRecords = await loadSessionRecords(identifiers: recipientIds)
        guard let result = encryptKeyResult(sessionRecords: sessionRecords, mKey: mKey) else {
            await DTToastHelper.dismiss(withInfo: Localized("SINGLE_CALL_APPLY_MEETING_FAIL"))
            Logger.error("encryptKey error")
            return nil
        }
    
        let publicKey = result.eKey
        let encInfos = result.eMKeys.map { key, value in
            let stringEmk = value.base64EncodedString()
            return ["uid": key, "emk": stringEmk]
        }
        
        var cipherMessages = [[String: Any]]()
        // 不需要同步给另一段的消息类型
        var igonreSelfMsgTypes: [DTCallMessageType] = []
        if callType == .private {
            if createCallMsgEnabled() {
                igonreSelfMsgTypes = [.cancel]
            } else {
                igonreSelfMsgTypes = [.calling, .cancel]
            }
        }
        
        do {
            try sessionRecords.forEach { [self] key, value in
                
                if key == localNumber && igonreSelfMsgTypes.contains(msgType) {
                    return
                }
                
                var cipherMessage = [String: Any]()
                cipherMessage["uid"] = key
                cipherMessage["registrationId"] = value.remoteRegistrationId
                
                let sessionCipher = DTSessionCipher(
                    recipientId: key,
                    type: .private
                )
                
                let callMsgBuilder = DSKProtoCallMessage.builder()
                switch msgType {
                case .calling:
                    let callingBuilder = DSKProtoCallMessageCalling.builder()
                   
                    let conversationIdBulider = DSKProtoConversationId.builder()
                    if let conversationId {
                        if case .private = callType {
                            conversationIdBulider.setNumber(conversationId)
                        } else if case .group = callType, let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) {
                            conversationIdBulider.setGroupID(groupId)
                        }
                        
                        if let conversationID = try? conversationIdBulider.build() {
                            callingBuilder.setConversationID(conversationID)
                        }
                    }

                    callingBuilder.setPublicKey(publicKey)
                    callingBuilder.setCaller(localNumber)
                    if let roomId, !roomId.isEmpty {
                        callingBuilder.setRoomID(roomId)
                    }
                    if let roomName {
                        callingBuilder.setRoomName(roomName)
                    }
                    if let emk = result.eMKeys[key] {
                        callingBuilder.setEmk(emk)
                    }
                    
                    if let createCallMsg {
                        callingBuilder.setCreateCallMsg(createCallMsg)
                    }
                    
                    if let controlType {
                        callingBuilder.setControlType(controlType)
                    }
                    
                    if let callees {
                        callingBuilder.setCallees(callees)
                    }
                    
                    if let timestamp {
                        callingBuilder.setTimestamp(timestamp)
                    }
                    
                    let calling = try callingBuilder.build()
                    callMsgBuilder.setCalling(calling)
                case .joined:
                    let joinedBuilder = DSKProtoCallMessageJoined.builder()
                    if let roomId, !roomId.isEmpty {
                        joinedBuilder.setRoomID(roomId)
                    }
                    let joined = try joinedBuilder.build()
                    callMsgBuilder.setJoined(joined)
                case .cancel:
                    let cancelBuilder = DSKProtoCallMessageCancel.builder()
                    if let roomId, !roomId.isEmpty {
                        cancelBuilder.setRoomID(roomId)
                    }
                    let cancel = try cancelBuilder.build()
                    callMsgBuilder.setCancel(cancel)
                case .reject:
                    let rejectBuilder = DSKProtoCallMessageReject.builder()
                    if let roomId, !roomId.isEmpty {
                        rejectBuilder.setRoomID(roomId)
                    }
                    let reject = try rejectBuilder.build()
                    callMsgBuilder.setReject(reject)
                case .hangup:
                    let hangupBuilder = DSKProtoCallMessageHangup.builder()
                    if let roomId, !roomId.isEmpty {
                        hangupBuilder.setRoomID(roomId)
                    }
                    let hangup = try hangupBuilder.build()
                    callMsgBuilder.setHangup(hangup)
                }
                
                let callMsg = try callMsgBuilder.build()
                
                let contentBuilder = DSKProtoContent.builder()
                contentBuilder.setCallMessage(callMsg)
                
                if let content = try? contentBuilder.build(), let plainText = try? content.serializedData() {
                    
                    try databaseStorage.write { transaction in
                        let encryptedMessage = try sessionCipher.encryptMessage((plainText as NSData).paddedMessageBody(), transaction: transaction)
                        let stringContent = encryptedMessage.serialized.base64EncodedString(options: [.endLineWithLineFeed])
                        cipherMessage["content"] = stringContent
                        
                        cipherMessages.append(cipherMessage)
                    }
                    
                }
            }
            
        } catch {
            Logger.error("encryptMessage error: \(error.localizedDescription)")
        }

        return (cipherMessages, encInfos, result)
    }
    
    func sendCallMessage(_ msgType: DTCallMessageType,
                         forceEndGroupMeeting: Bool = false,
                         _ targetCall: DTLiveKitCallModel = DTMeetingManager.shared.currentCall) async {
        
        Logger.info("\(logTag) send \(msgType) message")
        
        guard let localNumber = TSAccountManager.localNumber() else {
            return
        }
        
        guard let caller = targetCall.caller else {
            Logger.error("no caller")
            return
        }
        
        guard let roomId = targetCall.roomId else {
            Logger.error("no roomId")
            return
        }
        
        var recipientIds: [String] = []
        switch msgType {
        case .joined:
            recipientIds = [localNumber]
        case .cancel:
            guard targetCall.callType == .private else {
                return
            }
            guard targetCall.isCaller else {
                return
            }
            guard let callees = targetCall.callees, !callees.isEmpty else {
                return
            }
            recipientIds = callees
        case .reject:
            if targetCall.callType == .private {
                if let callees = targetCall.callees, !callees.isEmpty {
                    recipientIds += callees
                }
                recipientIds.append(caller)
            } else {
                recipientIds = [localNumber]
            }
        case .hangup:
            if !forceEndGroupMeeting && targetCall.callType != .private{
                return
            }
            
            // 区分end和leave
            if forceEndGroupMeeting {
                // 添加远程的其他人的id
                if let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: currentCall.conversationId ?? ""),
                   let groupThread = TSGroupThread.getWithGroupId(groupId) {
                    // 群成员和参会人员并集
                        let allIds = groupThread.groupModel.groupMemberIds + DTMeetingManager.shared.allParticipantIds
                        recipientIds = Array(Set(allIds))
                } else {
                    for participantId in DTMeetingManager.shared.allParticipantIds {
                        recipientIds.append(participantId)
                    }
                }
            } else {
                if let callees = targetCall.callees, !callees.isEmpty {
                    recipientIds += callees
                }
                recipientIds.append(caller)
            }
            
            // 发送RTM消息
            Task {
                await sendRTMEndCallData()
            }
        default: break
        }
        
        guard let callMessage = await createCallMessage(
            localNumber: localNumber,
            callType: targetCall.callType,
            msgType: msgType,
            conversationId: nil,
            caller: caller,
            recipientIds: recipientIds,
            roomId: roomId,
            roomName: nil,
            mKey: nil,
            callees: [],
            timestamp: targetCall.timestamp) else {
            
            return
        }
                        
        let data = await DTCallAPIManager().controlCallMessage(
            roomId: roomId,
            msgType: msgType,
            cipherMessages: callMessage.cipherMessages,
            forceEndGroupMeeting: forceEndGroupMeeting
        )

        if let tmpNeedsSync = data["needsSync"],
           let needsSync = tmpNeedsSync.value as? Bool,
           needsSync == true {
            // TODO: 需发送数据到另一端, 目前其它端把自己另一端的消息也放进去了
        }
        
        if let tmpStale = data["stale"],
           let stale = tmpStale.value as? [[String: Any]],
           !stale.isEmpty {
            Logger.error("\(logTag) ⚠️ \(msgType.rawValue) stale, need to resend message!!! ")
            
            storeFreshPrekeys(stale) { [weak self] in
                guard let self else { return }
                Task {
                    await self.sendCallMessage(msgType, forceEndGroupMeeting: forceEndGroupMeeting)
                }
            }
        } else {
            Logger.info("sendCallMessageSuccess: \(msgType.rawValue)")
        }
        
    }
    
    func inviteUsersToCall(_ recipientIds: [String]) {
        
        guard let roomId = currentCall.roomId,
              let mKey = currentCall.mKey,
              let localNumber = TSAccountManager.localNumber() else {
            return
        }
        
        let timestamp = Date.ows_millisecondTimestamp()
        let collapseId = collapseId(timestamp: timestamp)
        let notification: [String: Any] = [
            "type": DTApnsMessageType.ENC_CALL.rawValue,
            "args": ["collapseId": collapseId]
        ]
      
        currentCall.createCallMsg = createCallMsgEnabled()
        currentCall.controlType = DTMeetingManager.sourceControlInvite
        currentCall.inviteCallees = recipientIds
        currentCall.timestamp = timestamp
        
        var recipientIdentifiers = recipientIds
        if createCallMsgEnabled() {
            recipientIdentifiers.append(localNumber)
            let filteredIdentifiers = recipientIdentifiers.map { recipient in
                return recipient.split(separator: ".").first.map { String($0) } ?? recipient
            }
            recipientIdentifiers = filteredIdentifiers
        }
        
        Task {
            let conversationId = currentCall.callType == .group ? currentCall.conversationId : nil
            guard let inviteMessage = await createCallMessage(
                localNumber: localNumber,
                callType: currentCall.callType,
                conversationId: conversationId,
                caller: localNumber,
                recipientIds: recipientIdentifiers,
                roomId: nil,
                roomName: currentCall.roomName,
                mKey: mKey,
                createCallMsg: createCallMsgEnabled(),
                controlType: DTMeetingManager.sourceControlInvite,
                callees: recipientIds,
                timestamp: timestamp) else {
                return
            }
            
            let stringPublicKey = inviteMessage.keyResult.eKey.base64EncodedString()
            let data = await DTCallAPIManager().inviteToCall(
                roomId: roomId,
                publicKey: stringPublicKey,
                encInfos: inviteMessage.encInfos,
                timestamp: timestamp,
                notification: notification,
                cipherMessages: inviteMessage.cipherMessages
            )
            
            if let tmpInvalidUids = data["invalidUids"],
               let invalidUids = tmpInvalidUids.value as? [String] {
                Logger.info("\(logTag) \(invalidUids) not your friend or does not exist")
            }
            
            if let serverShowTimestamp = data["systemShowTimestamp"] {
                currentCall.serverTimestamp = anyCodableToUInt64(serverShowTimestamp)
            }
        
            if let tmpStale = data["stale"],
               let stale = tmpStale.value as? [[String: Any]],
               !stale.isEmpty {
                Logger.error("\(logTag) ⚠️ calling stale, need to resend message!!! ")
                storeFreshPrekeys(stale) { [weak self] in
                    guard let self else { return }
                    self.inviteUsersToCall(recipientIds)
                }
            } else {
                // 发送邀请人的文本消息
                if createCallMsgEnabled() {
                    recipientIds.forEach { receiptId in
                        sendOutgoingLocalPrivateInviteCallMessage(receiptId: receiptId)
                    }
                } else {
                    sendInviteCallMessage(receiptIds: recipientIds)
                }
            }
        }
    }
    
    func collapseId(timestamp: UInt64) -> String {
        
        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("localNumber == nil")
            return ""
        }
        let plainText = "\(timestamp)\(localNumber)\(OWSDevice.currentDeviceId())"
        
        return SSKCryptography.getMd5With(plainText)
    }
    
}

extension DTMeetingManager: DTCallMessageDelegate {
    
    public func handleCallingMessage(roomId: String,
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
                                     serverTimestamp: UInt64?) {
        
        Logger.info("\(logTag) receive incoming call, caller: \(caller).")

        Task {
            
            let result = await DTMeetingManager.checkRoomIdValid(roomId)
            let isRoomIdValid = (result != nil)
            guard isRoomIdValid else {
                Logger.info("\(logTag) roomId invalid")
                return
                
            }
            
            // 数据返回true就不执行
            if result?.userStopped ?? false {
                return
            }
            
            // 当前有会议, 新收到的call和当前是一个, 忽略
            if let currentRoomId = currentCall.roomId, currentRoomId == roomId {
                return
            }
            
            let isSameSource = envelopeSource == TSAccountManager.localNumber()
            
            let newCall = DTLiveKitCallModel()
            newCall.callState = .alerting
            newCall.caller = caller
            newCall.roomId = roomId
            // TODO: call test
            newCall.roomName = roomName ?? "[No Room Name]-\(caller)'s Call"
            newCall.publicKey = publicKey
            newCall.emk = emk
            newCall.createCallMsg = createCallMsg
            newCall.controlType = controlType
            newCall.inviteCallees = callees
            newCall.timestamp = timestamp
            newCall.serverTimestamp = serverTimestamp
            newCall.envelopeSource = envelopeSource
            newCall.envelopeSourceDevice = envelopeSourceDevice
            
            var callType: CallType = .instant
            if let conversationId {
                let callInfo = conversationId.getCallInfo()
                newCall.conversationId = callInfo.conversationId
                callType = callInfo.callType
            }
            newCall.callType = callType
            
            if callType == .private, let localNumber = TSAccountManager.localNumber() {
                newCall.callees = [localNumber]
            }
            
            if let currentRoomId = currentCall.roomId, currentRoomId != roomId {
                // 弹出提醒
                Logger.info("\(logTag) hasMeeting")
                DTAlertCallViewManager.shared().addLiveKitCallAlert(newCall)
                return
            }

            /// calling展示meetingbar
            handleMeetingBar(call: newCall, action: .add)
            
            // 收到邀请的calling就发文本消息
            dealCallingLocalMessage(createCallMsg: createCallMsg,
                                    controlType: controlType,
                                    callees: callees,
                                    caller: caller,
                                    callType: callType,
                                    conversationId: newCall.conversationId,
                                    isFromOtherDevice: isSameSource) {
                self.currentCall = newCall
            }
            
            if let localNumber = TSAccountManager.localNumber(), localNumber == caller {
                // 自己其他端发起的呼叫不展示接听
                return
            }
            
            DispatchMainThreadSafe {
                if self.hasMeeting, OWSWindowManager.shared().hasCall() {
                    return
                }
            }

            let isPrivateCall = newCall.callType == .private
            let sound: OWSSound = isPrivateCall ? .callIncomming1v1 : .callIncommingGroup
            showAnswer(call: newCall) { [self] in
                DispatchMainThreadSafe { [self] in
                    if UIApplication.shared.applicationState == .active  {
                        playSound(sound, isLoop: isPrivateCall, playMode: .playback)
                    }
                }
            }
        }
    }
    
    public func handleJoinedMessage(roomId: String) {
        Logger.info("\(logTag) roomId handleJoinedMessage")
        
        if roomId == currentCall.roomId {
            // 其他端join后发送的同步消息
            // 1). display meeting bar.
            handleMeetingBar(call: currentCall, action: .add)
            
            // 2). remove answer call view.
            Task {
                guard !inMeeting else { return }
                Logger.info("\(logTag) handleJoinedMessages need remoteCallHaveBeenCanceled")
                await remoteCallHaveBeenCanceled()
            }
        } else {
            // 收到顶部弹窗call的join
            guard let callAlert = callAlertManager.lkAlertCalls.first (where: { $0.liveKitCall?.roomId == roomId
            }) else {
                return
            }
            
            guard let liveKitCall = callAlert.liveKitCall else {
                return
            }
            
            handleMeetingBar(call: liveKitCall, action: .add)
            callAlertManager.removeLiveKitAlertCall(roomId)
        }
    }
    
    // callee reveiced cancel to close alert view
    public func handleRemoteCanceledMessage(roomId: String) {
        Logger.info("\(logTag) roomId handleRemoteCanceledMessage")
        
        if roomId == currentCall.roomId {
            Task {
                Logger.info("\(logTag) handleRemoteCanceledMessage need remoteCallHaveBeenCanceled")
                await remoteCallHaveBeenCanceled()
            }
        } else {
            // TODO: call remove 多个 call 的悬浮小窗
            callAlertManager.removeLiveKitAlertCall(roomId)
        }
    }
    
    public func handleLocalWasRejectedMessage(roomId: String, envelope: DSKProtoEnvelope) {
        Logger.info("\(logTag) reject message roomId")
        
        guard let currentRoomId = currentCall.roomId else {
            return
        }
        
        if roomId == currentRoomId {
            // 1v1 call：
            // 在会议中，被叫用户一端入会，需要忽略被叫用户其它端的reject的消息：可以通过消息的source， sourceDevice来判断
            // 自己忽略自己的reject消息
            if currentCall.callType == .private, DTMeetingManager.shared.inMeeting, envelope.source == TSAccountManager.shared.localNumber() {
                Logger.info("\(logTag) Ignoring reject message from other device while in meeting")
                return
            }
            
            if currentCall.callType == .private, let roomContext, roomContext.room.remoteParticipants.count > 0 {
                Logger.info("\(logTag) Ignoring reject message - remote participant already in meeting")
                return
            }
            
            if currentCall.callType == .private {
                DispatchMainThreadSafe {
                    DTToastHelper.showCallToast(Localized("SINGLE_CALL_CALLEE_DECLINED"))
                }
            }

            Task {
                await othersideHungupCall(roomId: roomId)
            }
        } else {
            // MARK: call remove 多个 call 的悬浮小窗
            callAlertManager.removeLiveKitAlertCall(roomId)
        }
                
    }
    
    public func handleWasHungupMessage(roomId: String) {
        Logger.info("\(logTag) handleWasHungupMessage roomId")
        
        if roomId == currentCall.roomId {
            Task {
                await othersideHungupCall(roomId: roomId, isRemoveBar: true)
            }
        } else {
            // TODO: call remove 多个 call 的悬浮小窗
            callAlertManager.removeLiveKitAlertCall(roomId)
        }
    }
    
    
    func send1on1CallMessage(thread: TSThread) {
        guard let contactThread = thread as? TSContactThread else {
            return
        }
        
        guard !createCallMsgEnabled() else {
            return
        }
        
        DispatchMainThreadSafe {
            ThreadUtil.sendMessage(withText: "Calling",
                                   atPersons: nil,
                                   mentions: nil,
                                   in: contactThread,
                                   quotedReplyModel: nil,
                                   messageSender: self.messageSender,
                                   success: {}, failure: { error in
                Logger.error("\(self.logTag) Failed to deliver message with error: \(error.localizedDescription)")
            })
        }
    }
    
    func sendGroupCallMessage(thread: TSThread) {
        
        guard let groupThread = thread as? TSGroupThread else {
            return
        }
        
        guard !createCallMsgEnabled() else {
            return
        }
        
        DispatchMainThreadSafe {
            ThreadUtil.sendMessage(withText: self.nameSelf() + " has started a call",
                                   atPersons: nil,
                                   mentions: nil,
                                   in: groupThread,
                                   quotedReplyModel: nil,
                                   messageSender: self.messageSender,
                                   success: {}, failure: { error in
                Logger.error("\(self.logTag) Failed to deliver message with error: \(error.localizedDescription)")
            })
        }

    }
    
    func sendInviteCallMessage(receiptIds: [String]) {
        
        databaseStorage.write { wTransaction in
            receiptIds.forEach { receiptId in
                let contactThread = TSContactThread.getOrCreateThread(withContactId: receiptId, transaction: wTransaction)
                DispatchMainThreadSafe {
                    ThreadUtil.sendMessage(withText: self.nameSelf() + " invites you to a call",
                                           atPersons: nil,
                                           mentions: nil,
                                           in: contactThread,
                                           quotedReplyModel: nil,
                                           messageSender: self.messageSender,
                                           success: {}, failure: { error in
                        Logger.error("\(self.logTag) Failed to deliver message with error: \(error.localizedDescription)")
                    })
                }
            }
        }
    }
    
    func nameSelf() -> String {
        guard let localNumber = TSAccountManager.localNumber() else {
            return ""
        }
        
        return Environment.shared.contactsManager.displayName(forPhoneIdentifier: localNumber)
    }
    
    // MARK: 发送弹幕和接收弹幕的消息
    func sendRemoteRoom(message: String) async {
        var result: DTEncryptedRtmMsgResult
        do {
            if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {
                let msgData = try roomCtx.jsonEncoder.encode([RTMKeys.topic: "chat",
                                                              RTMKeys.text: message])
                //会议密钥截取前32位即可
                result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                aesKey: mkey.prefix(32),
                                                                localPriKey: localPriKey,
                                                                plainText: msgData)
                
                let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                  RTMKeys.uuid: UUID().uuidString,
                                  RTMKeys.signature: result.signature.base64EncodedString(),
                                  RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                
                let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                
                let options = DataPublishOptions(topic: "chat", reliable: true)
                try await roomCtx.room.localParticipant.publish(data: dataResult, options: options)
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
    
    func decryptRemoteRoom(signature: Data, decryptData: Data, participantId: String) {
        var result: DTDecryptedRtmMsgResult
        do {
            if  let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {
                //会议密钥截取前32位即可
                result = try DTProtoAdapter().decryptRtmMessage(version: MESSAGE_CURRENT_VERSION, signature: signature, theirLocalIdKey: nil, aesKey: mkey.prefix(32), cipherText: decryptData)
                
                if let receiveConfig = try JSONSerialization.jsonObject(with:  result.plainText, options: []) as? [String: Any] {
                    guard let plainText = receiveConfig["text"] as? String else {
                        return
                    }
                    //发送弹幕
                    RoomDataManager.shared.sendRTMBarrageMessage(pid: participantId, message: plainText)
                }
            }
        } catch {
            Logger.error("\(logTag) dencryptData error: \(error.localizedDescription)")
        }
    }
    
    func sendDanmu(_ message: String) async {
        if let roomCtx = self.roomContext {
            // 本地弹幕逻辑
            RoomDataManager.shared.sendRTMBarrageMessage(pid: roomCtx.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first ?? "", message: message)
            //发送远端的逻辑
            await sendRemoteRoom(message: message)
        }
    }
    
    // MARK: 控制他人关麦
    func sendRemoteMicOffRoom(targetParticentId: String) async {
        var result: DTEncryptedRtmMsgResult
        do {
            if roomContext?.room.localParticipant.identity?.stringValue == targetParticentId {
                // 如果是自己闭麦
                try await roomContext?.room.localParticipant.setMicrophone(enabled:false)
                return
            }
            
            if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {

                // 从 remoteParticipants 里查找匹配 identity 的 participant
                if let matchedParticipant = roomCtx.room.remoteParticipants.values.first(where: {
                    return $0.identity?.stringValue == targetParticentId
                }) {
                    if let identity = matchedParticipant.identity {
                        let msgConfig = [RTMKeys.topic: "mute-other",
                                         RTMKeys.identities: [identity.stringValue],
                                         RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000)] as [String : Any]
                        let msgData = try JSONSerialization.data(withJSONObject: msgConfig, options: .prettyPrinted)
                        result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                        aesKey: mkey.prefix(32),
                                                                        localPriKey: localPriKey,
                                                                        plainText: msgData)
                        
                        let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                          RTMKeys.uuid: UUID().uuidString,
                                          RTMKeys.signature: result.signature.base64EncodedString(),
                                          RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                                                
                        let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                        
                       Task.detached { [weak self] in
                            guard let self else { return }
                            do {
                                let options = DataPublishOptions(destinationIdentities: [identity], topic: "mute-other", reliable: true)
                                try await self.roomContext?.room.localParticipant.publish(data: dataResult, options: options)
                            } catch {
                                Logger.error("Failed to encode data \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
    
    /// 关闭他人麦克风
    func decryptRemoteMicOffRoom(signature: Data, decryptData: Data) {
        var result: DTDecryptedRtmMsgResult
        do {
            if  let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {
                result = try DTProtoAdapter().decryptRtmMessage(version: MESSAGE_CURRENT_VERSION, signature: signature, theirLocalIdKey: nil, aesKey: mkey.prefix(32), cipherText: decryptData)
                
                if let receiveConfig = try JSONSerialization.jsonObject(with:  result.plainText, options: []) as? [String: Any] {
                    guard let identities = receiveConfig["identities"] as? [String],
                          let firstIdentity = identities.first,
                          firstIdentity == roomCtx.room.localParticipant.identity?.stringValue else {
                        return
                    }
                    
                    // 本地关麦
                    if roomCtx.room.localParticipant.localAudioTracks.count > 0 {
                        roomCtx.room.localParticipant.localAudioTracks.forEach { track in
                            Task {
                                do {
                                    try await track.mute()
                                } catch {
                                    Logger.error("\(logTag) Failed to localAudioTracks mute track: \(error)")
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) dencryptData error: \(error.localizedDescription)")
        }
    }
    
    // MARK: 他人静音继续
    func sendRemoteSyncContinueStatus() async {
        var result: DTEncryptedRtmMsgResult
        do {
            guard let targetParticentId = roomContext?.room.remoteParticipants.values.first?.identity?.stringValue else {
                return
            }
            
            if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {

                // 从 remoteParticipants 里查找匹配 identity 的 participant
                if let matchedParticipant = roomCtx.room.remoteParticipants.values.first(where: {
                    return $0.identity?.stringValue == targetParticentId
                }) {
                    if let identity = matchedParticipant.identity {
                        let msgConfig = [RTMKeys.topic: "continue-call-after-silence",
                                         RTMKeys.identities: [identity.stringValue]] as [String : Any]
                        let msgData = try JSONSerialization.data(withJSONObject: msgConfig, options: .prettyPrinted)
                        result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                        aesKey: mkey.prefix(32),
                                                                        localPriKey: localPriKey,
                                                                        plainText: msgData)
                        
                        let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                          RTMKeys.uuid: UUID().uuidString,
                                          RTMKeys.signature: result.signature.base64EncodedString(),
                                          RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                                                
                        let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                        
                       Task.detached { [weak self] in
                            guard let self else { return }
                            do {
                                let options = DataPublishOptions(destinationIdentities: [identity], topic: "continue-call-after-silence", reliable: true)
                                try await self.roomContext?.room.localParticipant.publish(data: dataResult, options: options)
                            } catch {
                                Logger.error("Failed to encode data \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
    
    /// 静音继续
    func decryptRemoteSyncContinueStatus(signature: Data, decryptData: Data) {
        var result: DTDecryptedRtmMsgResult
        do {
            if currentCall.callType != .private {
                return
            }
            if  let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {
                result = try DTProtoAdapter().decryptRtmMessage(version: MESSAGE_CURRENT_VERSION, signature: signature, theirLocalIdKey: nil, aesKey: mkey.prefix(32), cipherText: decryptData)
                
                if let receiveConfig = try JSONSerialization.jsonObject(with:  result.plainText, options: []) as? [String: Any] {
                    guard let identities = receiveConfig["identities"] as? [String],
                          let firstIdentity = identities.first,
                          firstIdentity == roomCtx.room.localParticipant.identity?.stringValue else {
                        return
                    }
                    
                    // 调用继续的逻辑
                    DispatchMainThreadSafe {
                        DTMeetingManager.shared.hostRoomContentVC?.autoLeaveTipView?.removeFromSuperview()
                        DTMeetingManager.shared.hostRoomContentVC?.hasShowLeaveTipView = false
                        DTMeetingManager.shared.hostRoomContentVC?.autoLeaveTipView?.stopTimeoutTimer()
                        DTMeetingManager.shared.stopCheckTalking()
                        DTMeetingManager.shared.currentCallTalkingPop()
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) dencryptData error: \(error.localizedDescription)")
        }
    }
    
    // MARK: 举手
    func handRaiseRemoteSyncStatus() async {
        do {
            let dict: [String: Any] = [RTMKeys.topic: "raise-hand"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
               let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                 RTMKeys.uuid: UUID().uuidString,
                                 RTMKeys.payload: jsonString] as [String : Any]
                                        
               let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
               Task.detached { [weak self] in
                    guard let self else { return }
                    do {
                        RoomDataManager.shared.raiseLocalHand()
                        let options = DataPublishOptions(topic: "raise-hand", reliable: true)
                        try await self.roomContext?.room.localParticipant.publish(data: dataResult, options: options)
                    } catch {
                        Logger.error("Failed to encode data \(error)")
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
    
    func handCancelRemoteSyncStatus(participantId: String) async {
        do {
            
            if let matchedParticipant = self.roomContext?.room.allParticipants.values.first(where: {
                return $0.identity?.stringValue.components(separatedBy: ".").first == participantId
            }) {
                if let identity = matchedParticipant.identity {
                    let dict: [String: Any] = [RTMKeys.topic: "cancel-hand",
                                               RTMKeys.hands:[identity.stringValue]]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                       let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                         RTMKeys.uuid: UUID().uuidString,
                                         RTMKeys.payload: jsonString] as [String : Any]
                                                
                       let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                       Task.detached { [weak self] in
                            guard let self else { return }
                            do {
                                RoomDataManager.shared.cancelHand(participantId: identity.stringValue.components(separatedBy: ".").first ?? "")
                                let options = DataPublishOptions(destinationIdentities: [identity], topic: "cancel-hand", reliable: true)
                                try await self.roomContext?.room.localParticipant.publish(data: dataResult, options: options)
                            } catch {
                                Logger.error("Failed to encode data \(error)")
                            }
                        }
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
    
    /// 处理远端的举手和放下
    func dealRemoteHandsStatus(topic: String, payload: String) {
        if let data = payload.data(using: .utf8) {
            do {
                if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let handArray = dict["hands"] as? [[String: Any]] {
                        let sortedIdentities = handArray
                            .sorted {
                                let ts1 = $0["ts"] as? Int ?? 0
                                let ts2 = $1["ts"] as? Int ?? 0
                                return ts1 < ts2
                            }
                            .compactMap { $0["identity"] as? String }
                        RoomDataManager.shared.updateRaiseHands(hands: sortedIdentities)
                    } else {
                        RoomDataManager.shared.updateRaiseHands(hands: [])
                    }
                }
            } catch {
                Logger.error("\(logTag) remote raise hands data failure")
            }
        }
    }
    
    // MARK: 发送end call消息
    func sendRTMEndCallData() async {
        var result: DTEncryptedRtmMsgResult
        do {
            if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                let roomCtx = self.roomContext,
                let mkey = roomCtx.currentCall.mKey {
                let msgData = try roomCtx.jsonEncoder.encode([RTMKeys.topic: "end-call"])
                //会议密钥截取前32位即可
                result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                aesKey: mkey.prefix(32),
                                                                localPriKey: localPriKey,
                                                                plainText: msgData)
                
                let dataConfig = [RTMKeys.sendTimestamp: Int(Date().timeIntervalSince1970 * 1000),
                                  RTMKeys.uuid: UUID().uuidString,
                                  RTMKeys.signature: result.signature.base64EncodedString(),
                                  RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                
                let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                
                let options = DataPublishOptions(topic: "end-call", reliable: true)
                try await roomCtx.room.localParticipant.publish(data: dataResult, options: options)
            }
        } catch {
            Logger.error("\(logTag) sendData error: \(error.localizedDescription)")
        }
    }
}
