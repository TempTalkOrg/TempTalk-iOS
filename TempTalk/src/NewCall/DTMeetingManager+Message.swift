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

// 聊天消息类型
enum ChatMessageType: Int {
    case `default` = 0  // 默认类型（弹幕）
    case bubble = 1     // 气泡类型
}

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
                            if key != localNumber {
                                conversationIdBulider.setNumber(localNumber)
                            } else {
                                conversationIdBulider.setNumber(conversationId)
                            }
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
                Logger.error("\(logTag) cancel api is not private")
                return
            }
            guard targetCall.isCaller else {
                Logger.error("\(logTag) cancel api targetCall isCaller is false")
                return
            }
            guard let callees = targetCall.callees, !callees.isEmpty else {
                Logger.error("\(logTag) cancel api callees is nil")
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
                Logger.error("\(logTag) hangup api is end")
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
            forceEndGroupMeeting: forceEndGroupMeeting,
            callType: targetCall.callType
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
    
    @MainActor func inviteUsersToCall(_ recipientIds: [String]) {

        guard let roomId = currentCall.roomId,
              let mKey = currentCall.mKey,
              let localNumber = TSAccountManager.localNumber() else {
            return
        }

        // 发起邀请时，如果是1v1通话，立即转换为instant call
        // 发起邀请的人主观知道要邀请其他人，不管对方是否接受邀请，都应该转换
        if currentCall.callType == .private {
            Logger.info("\(logTag) inviting users in 1v1 call, turn into instant call immediately")
            turnIntoInstantCall()
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

                // ✅ 邀请成功后，记录邀请人列表（不发送 Critical Alert）
                recordInvitedUsers(recipientIds)
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
            
            if let currentRoomId = currentCall.roomId, currentRoomId == roomId {
                return
            }

            let hasActiveCall = currentCall.roomId != nil
                || (hasMeeting && roomContext != nil)
            if hasActiveCall {
                let newCall = DTLiveKitCallModel()
                newCall.callState = .alerting
                newCall.caller = caller
                newCall.roomId = roomId
                let fallbackRoomName = roomName ?? "[No Room Name]-\(caller)'s Call"
                newCall.roomName = fallbackRoomName
                newCall.publicKey = publicKey
                newCall.emk = emk
                newCall.createCallMsg = createCallMsg
                newCall.controlType = controlType
                newCall.inviteCallees = callees
                newCall.timestamp = timestamp
                newCall.serverTimestamp = serverTimestamp
                newCall.envelopeSource = envelopeSource
                newCall.envelopeSourceDevice = envelopeSourceDevice
                if let conversationId {
                    let callInfo = conversationId.getCallInfo()
                    newCall.conversationId = callInfo.conversationId
                    newCall.callType = callInfo.callType
                    if callInfo.callType == .group, let gid = callInfo.conversationId {
                        SDSDatabaseStorage.shared.read { tx in
                            newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                                serverGroupId: gid,
                                fallbackName: fallbackRoomName,
                                transaction: tx)
                        }
                    }
                } else {
                    newCall.callType = .instant
                }
                if newCall.callType == .private, let localNumber = TSAccountManager.localNumber() {
                    newCall.callees = [localNumber]
                }
                Logger.info("\(logTag) hasMeeting or currentCall exists, show alert banner for new call (roomId: \(roomId))")
                DTAlertCallViewManager.shared().addLiveKitCallAlert(newCall)
                return
            }

            let isSameSource = envelopeSource == TSAccountManager.localNumber()

            let newCall = DTLiveKitCallModel()
            newCall.callState = .alerting
            newCall.caller = caller
            newCall.roomId = roomId
            let fallbackRoomName = roomName ?? "[No Room Name]-\(caller)'s Call"
            newCall.roomName = fallbackRoomName
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
            if callType == .group, let gid = newCall.conversationId {
                SDSDatabaseStorage.shared.read { tx in
                    newCall.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: gid,
                        fallbackName: fallbackRoomName,
                        transaction: tx)
                }
            }

            if callType == .private, let localNumber = TSAccountManager.localNumber() {
                newCall.callees = [localNumber]
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
                                    isFromOtherDevice: isSameSource,
                                    serverTimestamp: serverTimestamp) {
                self.currentCall = newCall
            }
            
            if let localNumber = TSAccountManager.localNumber(), localNumber == caller {
                // 自己其他端发起的呼叫不展示接听
                return
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
    
    public func handleJoinedMessage(roomId: String, envelope: DSKProtoEnvelope) {
        let isCurrentDevice = RoomIdManager.shared.isCurrentDeviceCall(roomId)
        let envelopeSource = envelope.source ?? "unknown"
        let localNumber = TSAccountManager.localNumber() ?? "unknown"
        let isSameUser = (envelopeSource == localNumber)

        if roomId == currentCall.roomId {
            // 其他端join后发送的同步消息
            // 1). display meeting bar.
            handleMeetingBar(call: currentCall, action: .add)
            // 其他端join进来清理高亮
            clearCriticalHightMessages()

            // 2). remove answer call view.
            // CRITICAL: Only cancel if not in meeting AND not connecting
            // This means another device answered the call
            // If we're connecting or connected, this is our own "joined" message
            Task {
                // Check if we're in meeting or connecting
                if inMeeting {
                    return
                }

                if (lifecycleState == .connecting && roomContext != nil) || lifecycleState == .connected {
                    return
                }

                // Check if this is our device's call
                if isCurrentDevice {
                    return
                }

                // 关键判断：如果是同一个用户的不同设备，且我们还在idle状态
                // 说明另一个设备已经接听了，我们应该取消
                if isSameUser {
                    Logger.info("\(logTag) Another device answered, canceling call")
                    await remoteCallHaveBeenCanceled()
                }
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
        Logger.info("\(logTag) handleRemoteCanceledMessage roomId: \(roomId), currentRoomId: \(currentCall.roomId ?? "nil"), inMeeting: \(inMeeting)")

        if roomId == currentCall.roomId {
            if inMeeting {
                Logger.warn("\(logTag) handleRemoteCanceledMessage - already in meeting, ignoring cancel for roomId: \(roomId)")
                return
            }
            Task {
                Logger.info("\(logTag) handleRemoteCanceledMessage need remoteCallHaveBeenCanceled")
                await remoteCallHaveBeenCanceled()
            }
        } else {
            callAlertManager.removeLiveKitAlertCall(roomId)
            handleMeetingBar(roomId: roomId, action: .remove)

            let ckManager = DTCallKitManager.shared()
            if let uuidString = ckManager.uuidString(fromRoomId: roomId) {
                ckManager.endCallAction(uuidString, onlyForCallKit: true)
            }
        }
    }
    
    public func handleLocalWasRejectedMessage(roomId: String, envelope: DSKProtoEnvelope) {
        Logger.info("\(logTag) reject message roomId")
        
        guard let currentRoomId = currentCall.roomId else {
            return
        }
        
        if roomId == currentRoomId {
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
            handleMeetingBar(roomId: roomId, action: .remove)
        }
                
    }
    
    public func handleWasHungupMessage(roomId: String) {
        Logger.info("\(logTag) handleWasHungupMessage roomId: \(roomId), currentRoomId: \(currentCall.roomId ?? "nil")")

        if roomId == currentCall.roomId {
            Task {
                await othersideHungupCall(roomId: roomId)
            }
        } else {
            callAlertManager.removeLiveKitAlertCall(roomId)
            handleMeetingBar(roomId: roomId, action: .remove)
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
            let message = ThreadUtil.sendMessage(withText: "Calling",
                                   atPersons: nil,
                                   mentions: nil,
                                   in: contactThread,
                                   quotedReplyModel: nil,
                                   messageSender: self.messageSender,
                                   forceNormalMode: true,
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
            let message = ThreadUtil.sendMessage(withText: self.nameSelf() + " has started a call",
                                   atPersons: nil,
                                   mentions: nil,
                                   in: groupThread,
                                   quotedReplyModel: nil,
                                   messageSender: self.messageSender,
                                   forceNormalMode: true,
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
                    let message = ThreadUtil.sendMessage(withText: self.nameSelf() + " invites you to a call",
                                           atPersons: nil,
                                           mentions: nil,
                                           in: contactThread,
                                           quotedReplyModel: nil,
                                           messageSender: self.messageSender,
                                           forceNormalMode: true,
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
    func sendRemoteRoom(message: String, type: ChatMessageType = .default) async {
        var result: DTEncryptedRtmMsgResult
        do {
            if let localPriKey = OWSIdentityManager.shared().identityKeyPair()?.privateKey as? Data,
                let roomCtx = self.roomContext,
               let mkey = await roomCtx.currentCall.mKey {
                let sendTimestamp = Date.ows_millisecondTimestamp()

                // 构建消息数据，包含 type 字段
                var messageData: [String: Any] = [
                    RTMKeys.topic: "chat",
                    RTMKeys.text: message,
                    RTMKeys.sendTimestamp: sendTimestamp
                ]

                // 只有非默认类型时才添加 type 字段
                if type != .default {
                    messageData["type"] = type.rawValue
                }

                let msgData = try JSONSerialization.data(withJSONObject: messageData, options: [])
                //会议密钥截取前32位即可
                result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                aesKey: mkey.prefix(32),
                                                                localPriKey: localPriKey,
                                                                plainText: msgData)

                let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
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
    
    // 解析 textPresets 格式的消息，返回 (文本, emoji)
    private func parseTextPresetMessage(_ message: String) -> (text: String, emoji: String)? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedMessage.glyphCount == 1 && trimmedMessage.containsEmoji {
            Logger.info("[BulletChat] parseTextPresetMessage - pure emoji: \(trimmedMessage)")
            return (text: "", emoji: trimmedMessage)
        }

        var emojiEndIndex = trimmedMessage.endIndex
        var emojiStartIndex = trimmedMessage.endIndex
        var foundEmoji = false

        // 从后往前遍历，找到第一个 emoji 序列
        for char in trimmedMessage.reversed() {
            emojiEndIndex = emojiStartIndex
            emojiStartIndex = trimmedMessage.index(before: emojiStartIndex)

            let substring = String(trimmedMessage[emojiStartIndex..<emojiEndIndex])
            if substring.containsEmoji {
                foundEmoji = true
            } else if foundEmoji {
                emojiStartIndex = trimmedMessage.index(after: emojiStartIndex)
                break
            }
        }

        guard foundEmoji else {
            Logger.info("[BulletChat] parseTextPresetMessage - no emoji found")
            return nil
        }

        let emoji = String(trimmedMessage[emojiStartIndex..<trimmedMessage.endIndex])
        let textPart = String(trimmedMessage[..<emojiStartIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !textPart.isEmpty else {
            Logger.info("[BulletChat] parseTextPresetMessage - text part is empty")
            return nil
        }
        return (text: textPart, emoji: emoji)
    }

    // 处理气泡消息的发送（支持 textPresets 格式）
    private func sendBubbleMessageWithFormat(pid: String, message: String) {
        if let parsed = parseTextPresetMessage(message) {
            var senderName = "You"
            if let localNumber = TSAccountManager.localNumber(), localNumber != pid {
                senderName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: pid)
            }
            let truncatedName = String(senderName.prefix(5))
            let formattedText = parsed.text.isEmpty ? truncatedName : "\(truncatedName): \(parsed.text)"
            RoomDataManager.shared.sendBubbleMessage(pid: pid, text: formattedText, emoji: parsed.emoji)
        } else {
            RoomDataManager.shared.sendBubbleMessage(pid: pid, message: message)
        }
    }

    @MainActor func decryptRemoteRoom(signature: Data, decryptData: Data, participantId: String) {
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

                    // 获取type字段，默认为0
                    let messageType = receiveConfig["type"] as? Int ?? 0

                    if messageType == 0 {
                        // 弹幕类型
                        RoomDataManager.shared.sendRTMBarrageMessage(pid: participantId, message: plainText)
                    } else if messageType == 1 {
                        // 气泡类型
                        sendBubbleMessageWithFormat(pid: participantId, message: plainText)
                    }
                }
            }
        } catch {
            Logger.error("\(logTag) dencryptData error: \(error.localizedDescription)")
        }
    }
    
    func sendDanmu(_ message: String, type: ChatMessageType = .default) async {
        if let roomCtx = self.roomContext {
            // 本地显示逻辑
            let pid = roomCtx.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first ?? ""

            if type == .default {
                // 弹幕类型
                RoomDataManager.shared.sendRTMBarrageMessage(pid: pid, message: message)
            } else if type == .bubble {
                // 气泡类型
                sendBubbleMessageWithFormat(pid: pid, message: message)
            }

            // 发送远端的逻辑
            await sendRemoteRoom(message: message, type: type)
        }
    }
    
    /// 发送 Critical Alert（紧急提醒）
    /// - Parameter message: 可选的弹幕消息
    func sendCriticalAlert(message: String? = nil) async {
        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("[newCall] Missing localNumber")
            return
        }

        // 1. 过滤已入会的用户
        let invitedUserIds = Array(currentCall.invitedCriticalAlertUsers)
        let filteredUserIds = filterAlreadyJoinedUsers(invitedUserIds)

        // 2. 根据 room type 构建参数
        let timestamp = Date().ows_millisecondsSince1970
        var destinations: [CriticalAlertDestination]?
        var group: CriticalAlertGroup?

        switch currentCall.callType {
        case .group:
            // 群组：传 group 参数（发给所有群成员），同时传 destinations（发给受邀人）
            if let gid = currentCall.conversationId {
                group = CriticalAlertGroup(gid: gid, timestamp: timestamp)
            }
            // 如果有邀请人，传邀请人列表
            if !filteredUserIds.isEmpty {
                destinations = filteredUserIds.enumerated().map { index, userId in
                    CriticalAlertDestination(number: userId, timestamp: timestamp + UInt64(index + 1))
                }
            }

        case .private:
            // Private (1v1): 只发送给被叫方
            if let calleeId = currentCall.conversationId {
                destinations = [CriticalAlertDestination(number: calleeId, timestamp: timestamp)]
            }

        case .instant:
            // Instant: 传 destinations（被叫人 + 邀请人 id）
            var userIds = filteredUserIds
            if currentCall.isCaller {
                // 主叫：添加被叫人 id
                if let calleeId = currentCall.conversationId, !userIds.contains(calleeId) {
                    userIds.insert(calleeId, at: 0)
                }
            }

            // Instant 必须有 destinations，如果为空则不发送
            guard !userIds.isEmpty else {
                Logger.info("[newCall] Instant call: no users to send Critical Alert, skip")
                return
            }

            destinations = userIds.enumerated().map { index, userId in
                CriticalAlertDestination(number: userId, timestamp: timestamp + UInt64(index))
            }
        }

        // 3. 调用通用 API 方法
        await sendCriticalAlertAPI(
            destinations: destinations,
            group: group,
            timestamp: timestamp,
            message: message,
            onSuccess: { [weak self] serverTimestamp, delivers in
                guard let self = self else { return }

                // 为 conversationId 创建本地消息（私聊/群聊）
                if let conversationId = currentCall.conversationId {
                    self.databaseStorage.write { transaction in
                        self.sendLocalTraceableMessage(
                            conversationId: conversationId,
                            localTimestamp: timestamp,
                            serverTimestamp: serverTimestamp,
                            writeTransation: transaction
                        )
                    }
                }

                // 如果有受邀用户，为每个送达的用户创建本地消息
                if !filteredUserIds.isEmpty {
                    delivers.forEach { userId in
                        self.databaseStorage.write { transaction in
                            self.sendLocalTraceableMessage(
                                conversationId: userId,
                                localTimestamp: timestamp,
                                serverTimestamp: serverTimestamp,
                                writeTransation: transaction
                            )
                        }
                    }
                }
            }
        )
    }

    // MARK: - 通用 Critical Alert API 调用

    /// 通用的 Critical Alert API 调用方法
    /// - Parameters:
    ///   - destinations: 目标用户列表
    ///   - group: 群组信息
    ///   - timestamp: 时间戳
    ///   - message: 可选的弹幕消息
    ///   - onSuccess: 成功回调，返回 serverTimestamp 和 delivers 数组
    private func sendCriticalAlertAPI(
        destinations: [CriticalAlertDestination]?,
        group: CriticalAlertGroup?,
        timestamp: UInt64,
        message: String?,
        onSuccess: @escaping (UInt64, [String]) -> Void
    ) async {
        guard let roomId = currentCall.roomId else {
            Logger.error("[newCall] Missing roomId")
            criticalAlertFailedBarrage()
            return
        }

        CallCriticalAlertNewApi().criticalAlertNewServers(
            destinations: destinations,
            group: group,
            roomId: roomId,
            success: { [weak self] entity, responseData in
                guard let self = self else { return }

                if let data = responseData, data.result {
                    Logger.info("[newCall] Critical Alert success, delivers: \(data.delivers)")

                    // 发送实时弹幕（如果有消息）
                    if let message = message {
                        self.sendRTMBarrage(message: message)
                    }

                    // 调用成功回调处理本地消息
                    if let serverTimestamp = entity?.serverTimestamp as? UInt64 {
                        onSuccess(serverTimestamp, data.delivers)
                    }
                } else {
                    self.handleCriticalAlertFailure()
                    Logger.error("[newCall] Critical Alert result false or missing")
                }
            },
            failure: { [weak self] error, _ in
                self?.handleCriticalAlertFailure()
                Logger.error("[newCall] Critical Alert failure: \(error.localizedDescription)")
            }
        )
    }

    /// 发送错误提示
    private func handleCriticalAlertFailure() {
        criticalAlertFailedBarrage()
    }

    /// 弹幕发送
    private func sendRTMBarrage(message: String) {
        guard let roomCtx = roomContext else { return }
        let pid = roomCtx.room.localParticipant.identity?
            .stringValue.components(separatedBy: ".").first ?? ""
        
        RoomDataManager.shared.sendRTMBarrageMessage(pid: pid, message: message)
    }


    /// 统一处理 group / private 的本地可回溯消息
    private func sendLocalTraceableMessage(conversationId: String,
                                           localTimestamp: UInt64,
                                           serverTimestamp: UInt64,
                                           writeTransation: SDSAnyWriteTransaction)
    {
        DispatchMainThreadSafe {
            let callType = self.currentCall.callType
            switch callType {
            case .group:
                guard
                    let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId)
                else { return }
                let thread = TSGroupThread.getOrCreateThread(withGroupId: localGroupId, transaction: writeTransation)
                self.createCriticalAlertLocalOutgoingMessage(
                    thread: thread,
                    timestamp: localTimestamp,
                    serverTimestamp: serverTimestamp,
                    transation: writeTransation
                )

            case .private:
                let thread = TSContactThread.getOrCreateThread(withContactId: conversationId, transaction: writeTransation)
                self.createCriticalAlertLocalOutgoingMessage(
                    thread: thread,
                    timestamp: localTimestamp,
                    serverTimestamp: serverTimestamp,
                    transation: writeTransation
                )
            default:
                break
            }
        }
    }
    
    func criticalAlertFailedBarrage() {
        DTToastHelper.toast(withText: Localized("MEETING_CRITICAL_ALERT_ERROR_TIPS"), durationTime: 2.0)
    }

    // MARK: - Critical Alert for Invite
    private func recordInvitedUsers(_ invitedUserIds: [String]) {
        // 更新邀请列表（去重取合集）
        let newInvitedUsers = Set(invitedUserIds)
        currentCall.invitedCriticalAlertUsers.formUnion(newInvitedUsers)

        Logger.info("[newCall] Recorded invited users: \(invitedUserIds), total invited: \(currentCall.invitedCriticalAlertUsers.count)")

        // 发送通知以刷新 UI
        NotificationCenter.default.post(name: NSNotification.Name("DTGroupCriticalAlertChangedNotification"), object: nil)
    }


    private func filterAlreadyJoinedUsers(_ userIds: [String]) -> [String] {
        guard let roomContext = roomContext else {
            return userIds
        }

        // 获取当前房间中的所有参与者 ID
        let joinedUserIds = Set(roomContext.room.allParticipants.keys.map { identity in
            identity.stringValue.components(separatedBy: ".").first ?? identity.stringValue
        })

        // 过滤掉已入会的用户
        let filteredUserIds = userIds.filter { userId in
            !joinedUserIds.contains(userId)
        }

        Logger.info("[newCall] Filter invited users: total=\(userIds.count), filtered=\(filteredUserIds.count), joined=\(userIds.count - filteredUserIds.count)")

        return filteredUserIds
    }

    func removeUserFromInvitedList(_ userId: String) {
        if currentCall.invitedCriticalAlertUsers.contains(userId) {
            currentCall.invitedCriticalAlertUsers.remove(userId)
            Logger.info("[newCall] Removed \(userId) from invited Critical Alert list, remaining: \(currentCall.invitedCriticalAlertUsers.count)")

            // 发送通知以刷新 UI
            NotificationCenter.default.post(name: NSNotification.Name("DTGroupCriticalAlertChangedNotification"), object: nil)
        }
    }

    /// 获取待发送 Critical Alert 的邀请人数量
    var pendingCriticalAlertCount: Int {
        let invitedUserIds = Array(currentCall.invitedCriticalAlertUsers)
        let filteredUserIds = filterAlreadyJoinedUsers(invitedUserIds)
        return filteredUserIds.count
    }

    /// 是否需要显示二次确认弹窗
    var shouldShowCriticalAlertConfirm: Bool {
        if currentCall.callType == .private {
            return false
        }

        return true
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
               let mkey = await roomCtx.currentCall.mKey {

                // 从 remoteParticipants 里查找匹配 identity 的 participant
                if let matchedParticipant = roomCtx.room.remoteParticipants.values.first(where: {
                    return $0.identity?.stringValue == targetParticentId
                }) {
                    if let identity = matchedParticipant.identity {
                        let sendTimestamp = Date.ows_millisecondTimestamp()
                        let msgConfig = [RTMKeys.topic: "mute-other",
                                         RTMKeys.identities: [identity.stringValue],
                                         RTMKeys.sendTimestamp: sendTimestamp] as [String : Any]
                        let msgData = try JSONSerialization.data(withJSONObject: msgConfig, options: .prettyPrinted)
                        result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                        aesKey: mkey.prefix(32),
                                                                        localPriKey: localPriKey,
                                                                        plainText: msgData)

                        let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
                                          RTMKeys.uuid: UUID().uuidString,
                                          RTMKeys.signature: result.signature.base64EncodedString(),
                                          RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                                                
                        let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                        
                       Task { [weak self] in
                            guard let self, self.roomContext != nil else { return }
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
    @MainActor func decryptRemoteMicOffRoom(signature: Data, decryptData: Data) {
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
                    let audioTracks = roomCtx.room.localParticipant.localAudioTracks
                    for track in audioTracks {
                        Task { [weak track] in
                            guard let track else { return }
                            do {
                                try await track.mute()
                            } catch {
                                Logger.error("\(self.logTag) Failed to localAudioTracks mute track: \(error)")
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
               let mkey = await roomCtx.currentCall.mKey {

                // 从 remoteParticipants 里查找匹配 identity 的 participant
                if let matchedParticipant = roomCtx.room.remoteParticipants.values.first(where: {
                    return $0.identity?.stringValue == targetParticentId
                }) {
                    if let identity = matchedParticipant.identity {
                        let sendTimestamp = Date.ows_millisecondTimestamp()
                        let msgConfig = [RTMKeys.topic: "continue-call-after-silence",
                                         RTMKeys.identities: [identity.stringValue],
                                         RTMKeys.sendTimestamp: sendTimestamp] as [String : Any]
                        let msgData = try JSONSerialization.data(withJSONObject: msgConfig, options: .prettyPrinted)
                        result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                        aesKey: mkey.prefix(32),
                                                                        localPriKey: localPriKey,
                                                                        plainText: msgData)

                        let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
                                          RTMKeys.uuid: UUID().uuidString,
                                          RTMKeys.signature: result.signature.base64EncodedString(),
                                          RTMKeys.payload: result.cipherText.base64EncodedString()] as [String : Any]
                                                
                        let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                        
                       Task { [weak self] in
                            guard let self, self.roomContext != nil else { return }
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
    @MainActor func decryptRemoteSyncContinueStatus(signature: Data, decryptData: Data) {
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
                    DTMeetingManager.shared.dismissAutoLeaveTipView()
                    DTMeetingManager.shared.stopCheckTalking()
                    DTMeetingManager.shared.currentCallTalkingPop()
                }
            }
        } catch {
            Logger.error("\(logTag) dencryptData error: \(error.localizedDescription)")
        }
    }
    
    // MARK: 举手
    func handRaiseRemoteSyncStatus() async {
        do {
            let sendTimestamp = Date.ows_millisecondTimestamp()
            let dict: [String: Any] = [RTMKeys.topic: "raise-hand",
                                       RTMKeys.sendTimestamp: sendTimestamp]
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
               let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
                                 RTMKeys.uuid: UUID().uuidString,
                                 RTMKeys.payload: jsonString] as [String : Any]
                                        
               let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
               Task { [weak self] in
                    guard let self, self.roomContext != nil else { return }
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
        
        guard let ops = currentCall.ttcalResponseOptions else { return}
        if ops.autoPublishSilenceAudio {
            return
        }
        
        if ops.disableSilenceOnRaiseHand {
            return
        }
        
        Task {
            await roomContext?.setLocalMicrophone(enable: true, publishMuted: true)
        }
    }
    
    func handCancelRemoteSyncStatus(participantId: String) async {
        do {
            
            if let matchedParticipant = self.roomContext?.room.allParticipants.values.first(where: {
                return $0.identity?.stringValue.components(separatedBy: ".").first == participantId
            }) {
                if let identity = matchedParticipant.identity {
                    let sendTimestamp = Date.ows_millisecondTimestamp()
                    let dict: [String: Any] = [RTMKeys.topic: "cancel-hand",
                                               RTMKeys.hands:[identity.stringValue],
                                               RTMKeys.sendTimestamp: sendTimestamp]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                       let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
                                         RTMKeys.uuid: UUID().uuidString,
                                         RTMKeys.payload: jsonString] as [String : Any]
                                                
                       let dataResult = try JSONSerialization.data(withJSONObject: dataConfig, options: .prettyPrinted)
                       Task { [weak self] in
                            guard let self, self.roomContext != nil else { return }
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
               let mkey = await roomCtx.currentCall.mKey {
                let sendTimestamp = Date.ows_millisecondTimestamp()
                let msgConfig = [RTMKeys.topic: "end-call",
                                 RTMKeys.sendTimestamp: sendTimestamp] as [String : Any]
                let msgData = try JSONSerialization.data(withJSONObject: msgConfig, options: .prettyPrinted)
                //会议密钥截取前32位即可
                result = try DTProtoAdapter().encryptRtmMessage(version: MESSAGE_CURRENT_VERSION,
                                                                aesKey: mkey.prefix(32),
                                                                localPriKey: localPriKey,
                                                                plainText: msgData)

                let dataConfig = [RTMKeys.sendTimestamp: sendTimestamp,
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
