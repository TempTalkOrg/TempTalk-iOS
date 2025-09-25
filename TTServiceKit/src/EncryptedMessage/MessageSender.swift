//
//  MessageSender.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/12/3.
//

import Foundation

extension MessageSender {
    
    static let senderRetryAttempts = 3
    
    @objc
    public func sendPrivateMessage(label: String,
                                   message: TSOutgoingMessage,
                                   thread: TSThread,
                                   recipient: SignalRecipient,
                                   attempts: Int,
                                   success: @escaping () -> Void,
                                   failure: @escaping (Error) -> Void) {
        Task{
            do {
                try await sendPrivateMessage(label: label,
                                             message: message,
                                             thread: thread,
                                             recipient: recipient,
                                             attempts: attempts,
                                             completion: success)
            } catch {
                failure(error)
            }
        }
    }
    
    @objc
    public func sendGroupMessage(label: String,
                                 message: TSOutgoingMessage,
                                 thread: TSGroupThread,
                                 attempts: Int,
                                 success: @escaping () -> Void,
                                 failure: @escaping (Error) -> Void) {
        Task{
            do {
                try await sendGroupMessage(label: label,
                                           message: message,
                                           thread: thread,
                                           attempts: attempts,
                                           completion: success)
            } catch {
                failure(error)
            }
        }
        
    }
    
    @objc
    public func sendLocallyEncryptedMessage(message: TSOutgoingMessage,
                                            toNote: Bool,
                                            attempts: Int,
                                            success: @escaping () -> Void,
                                            failure: @escaping (Error) -> Void) {
        Task {
            
            do {
                try await handleEncryptedMessageSentLocally(message: message,
                                                            toNote: toNote,
                                                            attempts: attempts,
                                                            completion: success)
            } catch {
                failure(error)
            }
            
             
        }
    }
    
    func sendPrivateMessage(label: String,
                            message: TSOutgoingMessage,
                            thread: TSThread,
                            recipient: SignalRecipient,
                            attempts: Int,
                            completion: @escaping () -> Void) async throws -> Void {
        
        let (plainText, serializedData, ermkeys) = try await getSerializedData(message: message, identifiers: [recipient.recipientId()], recipient: recipient, encryptionType: .private, attempts: attempts)
        
        var legacyData: Data?
        if DTMessageConfig.fetch().tunnelSecurityEnabled || recipient.recipientId().count <= 6 {
            legacyData = plainText
        }
        
        let result = try DTMessageParamsBuilder().buildParams(with: message, to: thread, recipient: recipient, messageType: .encryptedMessageType, serializedData: serializedData, legacySerializedData: legacyData, recipientPeerContexts: ermkeys)
        
        guard let messageParams = result as? [String: Any] else {
            let errorString = "messageParams convert error."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        let request = TSRequest(url: URL(string: "/v3/messages/\(recipient.recipientId())")!, method: "PUT", parameters: messageParams)
                
        var responseObject: Any?
        var responseError: Error?
        do {
            if socketManager.socketState() != .open {
                let sendResult = try await self.networkManager.asyncRequest(request)
                responseObject = sendResult.responseBodyJson
            } else {
                let sendResult = try await self.networkManager.asyncWebsocketRequest(request: request)
                responseObject = sendResult.responseBodyJson
            }
        } catch {
            OWSLogger.error("request private message error:\(error)")
            responseError = error
        }
        //handle errors:
        if let responseError, let statusCode = responseError.httpStatusCode, !(message is OWSReadReceiptsForSenderMessage) {
            if statusCode == 432 {
                databaseStorage.asyncWrite { wTransaction in
                    let now = NSDate.ows_millisecondTimeStamp()
                    if let contactThread = TSContactThread.getThread(contactId: recipient.recipientId(), transaction: wTransaction) {
                        let infoMsg = TSInfoMessage.init(timestamp: now, in: contactThread, messageType: .notFriend)
                        infoMsg.anyInsert(transaction: wTransaction)
                    }
                    
                }
            } else if statusCode == 404, let responseData = responseError.httpResponseJson {
                if let jsonData = responseData as? [AnyHashable : Any],
                   let metaData = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonData) as? DTAPIMetaEntity {
                    if metaData.status == 10105 {
                        databaseStorage.asyncWrite { wTransaction in
                            let now = NSDate.ows_millisecondTimeStamp()
                            if let contactThread = TSContactThread.getThread(contactId: recipient.recipientId(), transaction: wTransaction) {
                                let infoMsg = TSInfoMessage.init(timestamp: now, in: contactThread, messageType: .userUnLogined)
                                infoMsg.anyInsert(transaction: wTransaction)
                            }
                            
                        }
                    } else if metaData.status == 10110 {
                        databaseStorage.asyncWrite { wTransaction in
                            let now = NSDate.ows_millisecondTimeStamp()
                            if let contactThread = TSContactThread.getThread(contactId: recipient.recipientId(), transaction: wTransaction) {
                                let infoMsg = TSInfoMessage.init(timestamp: now, in: contactThread, messageType: .userAccountCanceled)
                                infoMsg.anyInsert(transaction: wTransaction)
                            }
                            
                        }
                    }
                }
            }
        }
        
        if let responseError {
            throw responseError
        }
        
        guard let jsonData = responseObject as? [AnyHashable : Any] else {
            let errorDesc = "data to json error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        guard let metaData = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonData) as? DTAPIMetaEntity else {
            let errorDesc = "json to metaData error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        
        //handle success result:
        if metaData.status == DTAPIRequestResponseStatus.OK.rawValue ||
            metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue{
            
            if metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue {
                OWSLogger.error("unsupported private message version!")
            }
            
            let serverReceipts = DTOutgoingMessageServerReceipts.init(response:metaData.data as NSDictionary)
            
            self.databaseStorage.write { wTransaction in
                message.updateWithAllRecipientsMarkedAsSent(with: serverReceipts, transaction: wTransaction)
            }
            if serverReceipts.needsSync {
                try await handleEncryptedMessageSentLocally(message: message,
                                                            toNote: false,
                                                            attempts: MessageSender.senderRetryAttempts) {
                }
            }
            
            completion()
            return
        }
        
        //handle failed result:
        if metaData.status == DTAPIRequestResponseStatus.invalidIdentifier.rawValue {
            self.databaseStorage.write { wTransaction in
                SessionStore.deleteSession(identifier: recipient.recipientId(), transaction: wTransaction)
            }
        }
        
        //retry
        try await sendPrivateMessage(label: label,
                               message: message,
                               thread: thread,
                               recipient: recipient,
                               attempts: attempts - 1,
                               completion: completion)

    }
    
    func sendGroupMessage(label: String,
                          message: TSOutgoingMessage,
                          thread: TSGroupThread,
                          attempts: Int,
                          completion: @escaping () -> Void) async throws -> Void {
        let recipient = SignalRecipient.init(textSecureIdentifier: "-1", relay: "")
        
        let (plainText, serializedData, ermkeys) = try await getSerializedData(message: message, identifiers: message.recipientIds(), recipient: recipient, encryptionType: .group, attempts: attempts)
        
        var legacyData: Data?
        if DTMessageConfig.fetch().tunnelSecurityEnabled {
            legacyData = plainText
        }
        
        let result = try DTMessageParamsBuilder().buildParams(with: message, to: thread, recipient: recipient, messageType: .encryptedMessageType, serializedData: serializedData, legacySerializedData: legacyData, recipientPeerContexts: ermkeys)
        
        guard let messageParams = result as? [String: Any] else {
            let errorString = "messageParams convert error."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        let request = TSRequest(url: URL(string: "/v3/messages/group/\(thread.serverThreadId)")!, method: "PUT", parameters: messageParams)
        
        var responseObject: Any?
        if socketManager.socketState() != .open {
            let sendResult = try await self.networkManager.asyncRequest(request)
            responseObject = sendResult.responseBodyJson
        } else {
            let sendResult = try await self.networkManager.asyncWebsocketRequest(request: request)
            responseObject = sendResult.responseBodyJson
        }
                
        guard let jsonData = responseObject as? [AnyHashable : Any] else {
            let errorDesc = "data to json error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        guard let metaData = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonData) as? DTAPIMetaEntity else {
            let errorDesc = "json to metaData error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        
        //handle success result:
        if metaData.status == DTAPIRequestResponseStatus.OK.rawValue ||
            metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue{
            
            if metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue {
                OWSLogger.error("unsupported group message version!")
            }
            
            let serverReceipts = DTOutgoingMessageServerReceipts.init(response:metaData.data as NSDictionary)
            
            self.databaseStorage.write { wTransaction in
                message.updateWithAllRecipientsMarkedAsSent(with: serverReceipts, transaction: wTransaction)
            }
            
            if serverReceipts.needsSync {
                try await handleEncryptedMessageSentLocally(message: message,
                                                            toNote: false,
                                                            attempts: MessageSender.senderRetryAttempts) {
                }
            }
            
            completion()
            return
        }
        
        //handle failed result:
        guard let extraRecipients = try MTLJSONAdapter.model(of: DTExtraRecipientsEntity.self, fromJSONDictionary: metaData.data) as? DTExtraRecipientsEntity else {
            let errorDesc = "json to extraRecipients error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        
        if let missing = extraRecipients.missing, !missing.isEmpty {
            OWSLogger.info("handle missing")
            var memberIds = [String]()
            memberIds.append(contentsOf: thread.groupModel.groupMemberIds)
            if !memberIds.isEmpty {
                for obj in missing {
                    if let uid = obj.uid, !uid.isEmpty {
                        memberIds.append(uid)
                    } else {
                        OWSLogger.info("missing recipientId is empty")
                    }
                }
            }
            databaseStorage.write { wTransaction in
                thread.anyUpdateGroupThread(transaction: wTransaction) { instance in
                    instance.groupModel.groupMemberIds = memberIds
                }
                storeSessions(prekeyBundles: missing, transaction: wTransaction)
            }
            message.resetRecipientStateMap(with: thread)
        }
        
        if let stale = extraRecipients.stale, !stale.isEmpty {
            OWSLogger.info("handle stale")
            databaseStorage.write { wTransaction in
                storeSessions(prekeyBundles: stale, transaction: wTransaction)
            }
        }
        
        if let extra = extraRecipients.extra, !extra.isEmpty {
            OWSLogger.info("handle extra")
            var memberIds = [String]()
            memberIds.append(contentsOf: thread.groupModel.groupMemberIds)
            if !memberIds.isEmpty {
                for obj in extra {
                    if let uid = obj.uid, !uid.isEmpty {
                        if let index = memberIds.firstIndex(where: { $0 == uid }) {
                            memberIds.remove(at: index)
                        }
                    } else {
                        OWSLogger.info("missing recipientId is empty")
                    }
                }
            }
            databaseStorage.write { wTransaction in
                thread.anyUpdateGroupThread(transaction: wTransaction) { instance in
                    instance.groupModel.groupMemberIds = memberIds
                }
            }
            message.resetRecipientStateMap(with: thread)
            
        }
        
        //extra only mark as success:
        if (extraRecipients.missing == nil || extraRecipients.missing!.isEmpty) ,
            (extraRecipients.stale == nil || extraRecipients.stale!.isEmpty) ,
           let extra = extraRecipients.extra, !extra.isEmpty {
            let serverReceipts = DTOutgoingMessageServerReceipts.init(response:metaData.data as NSDictionary)
            
            self.databaseStorage.write { wTransaction in
                message.updateWithAllRecipientsMarkedAsSent(with: serverReceipts, transaction: wTransaction)
            }
            
            if serverReceipts.needsSync {
                try await handleEncryptedMessageSentLocally(message: message,
                                                            toNote: false,
                                                            attempts: MessageSender.senderRetryAttempts) {
                }
            }
            
            completion()
            return
        }
        
        //retry
        try await sendGroupMessage(label: label,
                             message: message,
                             thread: thread,
                             attempts: attempts - 1,
                             completion: completion)

    }
    
    func handleEncryptedMessageSentLocally(message: TSOutgoingMessage,
                                           toNote: Bool,
                                           attempts: Int,
                                           completion: @escaping () -> Void) async throws -> Void {
        guard message.shouldSyncTranscript(), !message.isKind(of: OWSOutgoingSentMessageTranscript.self) else {
            return
        }
        var thread: TSThread?
        var selfRecipient: SignalRecipient?
        databaseStorage.read { transaction in
            thread = message.thread(with: transaction)
            selfRecipient = SignalRecipient.selfRecipient(with: transaction)
        }
        
        let sentMessageTranscript = OWSOutgoingSentMessageTranscript(outgoingMessage: message)
        sentMessageTranscript.toNote = toNote
        guard let thread, let selfRecipient  else {
            return
        }
        
        do {
            try await sendPrivateMessage(label: "e2ee private sync message",
                                   message: sentMessageTranscript,
                                   thread: thread,
                                   recipient: selfRecipient,
                                   attempts: attempts) {
                OWSLogger.info("Successfully sent e2ee sync transcript toNote \(toNote).")
                completion()
                self.databaseStorage.write { wTransaction in
                    message.update(withHasSyncedTranscript: true, transaction: wTransaction)
                }
            }
        } catch {
            OWSLogger.error("Failed to sent e2ee sync transcript toNote \(toNote): \(error)")
            throw error
        }
        
    }
    
    public func storeSessions(prekeyBundles: [DTPrekeyBundle], transaction: SDSAnyWriteTransaction) {
        for prekey in  prekeyBundles {
            if let uid = prekey.uid, !uid.isEmpty, let identityKey = prekey.identityKey, !identityKey.isEmpty {
                let sessionRecord = DTSessionRecord(version: MESSAGE_CURRENT_VERSION, remoteIdentityKey: prekey.identityKeyData(), remoteRegistrationId: prekey.registrationId)
                SessionStore.storeSession(sessionRecord, identifier: uid, transaction: transaction)
            }
        }
    }
    
    func getSerializedData(message: TSOutgoingMessage,
                           identifiers: [String],
                           recipient: SignalRecipient,
                           encryptionType: DTEncryptedMessageType,
                           attempts: Int) async throws -> (Data, Data, [DTMsgPeerContextParams]) {
        if TSAccountManager.shared.isTransfered() {
            let errorString = "is transfered."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        let sessions = try await SessionFetcher.fetchSessions(identifiers: identifiers)
        if !sessions.isEmpty {
            databaseStorage.write { wTransaction in
                storeSessions(prekeyBundles: sessions, transaction: wTransaction)
            }
        }
        
        if attempts <= 0 {
            let errorString = "attempts over limit."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        guard let plainText = message.buildPlainTextData(recipient) else {
            let errorString = "plainText is empty."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        let sessionCipher: DTSessionCipher
        if encryptionType == .private {
            sessionCipher = DTSessionCipher(recipientId: recipient.recipientId(), type: .private)
        } else {
            sessionCipher = DTSessionCipher(recipientIds: identifiers, type: .group)
        }
        var encryptedMessage: DTEncryptedMessage?
        var encryptError: Error?
        let encryptionString = encryptionType == .private ? "private" : "group"
        self.databaseStorage.read { transaction in
            do {
                encryptedMessage = try sessionCipher.encryptMessage(plainText.paddedMessageBody, transaction: transaction)
            } catch {
                let nsError = error as NSError
                let objc = nsError.userInfo[SCKExceptionWrapperUnderlyingExceptionKey]
                var reason = "DTProto encrypt message error."
                if let exception = objc as? NSException {
                    if  let eReason = exception.reason, !eReason.isEmpty {
                        reason = eReason
                    }
                }
                reason = "\(reason), send \(encryptionString) message"
                OWSLogger.error(reason)
                OWSProdError(reason, file: "MessageSender", function: "send \(encryptionString) message", line: 0)
                encryptError = error
            }
        }
        
        guard let encryptedMessage else {
            if let encryptError {
                throw encryptError
            }
            let errorString = "encryptedMessage is empty."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        
        let serializedData = encryptedMessage.serialized
        guard let ermkeys = encryptedMessage.eRMKeys, !ermkeys.isEmpty else {
            let errorString = "\(encryptionString) ermk error!"
            OWSLogger.error(errorString)
            OWSProdError(errorString, file: "MessageSender", function: "send \(encryptionString) message", line: 0)
            throw OWSAssertionError(errorString)
        }
        return (plainText, serializedData, ermkeys)
    }
    
}


extension Data {
    public var paddedMessageBody: Data {
        let paddingLength: Int = {
            // We have our own padding scheme, but so does the cipher.
            // The +2 here is to ensure the cipher has room for a padding byte, plus the separator byte.
            // The -2 at the end of this undoes that.
            let messageLengthWithTerminator = self.count + 2
            var messagePartCount = messageLengthWithTerminator / 160
            if !messageLengthWithTerminator.isMultiple(of: 160) {
                messagePartCount += 1
            }
            let resultLength = messagePartCount * 160
            return resultLength - 2 - self.count
        }()
        return self + [0x80] + Data(count: paddingLength)
    }

    public func withoutPadding() -> Data {
        guard
            let lastNonZeroByteIndex = self.lastIndex(where: { $0 != 0 }),
            self[lastNonZeroByteIndex] == 0x80 else {
            Logger.warn("Failed to find padding byte, returning unstripped data")
            return self
        }
        return self[..<lastNonZeroByteIndex]
    }
}
