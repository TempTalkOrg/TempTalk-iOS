//
//  MessageSender.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/12/3.
//

import Foundation

protocol SyncPlainTextBuildable {
    func buildSyncPlainTextData(_ recipient: SignalRecipient) -> Data?
}

extension TSOutgoingForwardNoticeMessage: SyncPlainTextBuildable {}
extension TSOutgoingActivityNoticeMessage: SyncPlainTextBuildable {}

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
        
        let (_, serializedData, ermkeys) = try await getSerializedData(message: message, identifiers: [recipient.recipientId()], recipient: recipient, encryptionType: .private, attempts: attempts)

        // Generate sync content for non-sync messages
        let syncContent: Data? = try await generateSyncContent(for: message, attempts: attempts)

        let result = try DTMessageParamsBuilder().buildParams(with: message, to: thread, recipient: recipient, messageType: .encryptedMessageType, serializedData: serializedData, legacySerializedData: nil, recipientPeerContexts: ermkeys, syncContent: syncContent)
        
        guard let messageParams = result as? [String: Any] else {
            let errorString = "messageParams convert error."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        let request = TSRequest(url: URL(string: "/v4/messages/\(recipient.recipientId())")!, method: "PUT", parameters: messageParams)
                
        var responseObject: Any?
        var responseError: Error?
        do {
            let sendResult: HTTPResponse
            if OWSWebSocket.canAppUseSocketsToMakeRequests {
                sendResult = try await self.networkManager.asyncWebsocketRequest(request: request)
            } else {
                sendResult = try await self.networkManager.asyncRequest(request)
            }
            responseObject = sendResult.responseBodyJson
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

        // Get self recipient ID and add to identifiers
        var identifiers = message.recipientIds()
        var selfRecipient: SignalRecipient?
        databaseStorage.read { transaction in
            selfRecipient = SignalRecipient.selfRecipient(with: transaction)
        }
        if let selfRecipientId = selfRecipient?.recipientId(), !identifiers.contains(selfRecipientId) {
            identifiers.append(selfRecipientId)
        }

        let (_, serializedData, ermkeys) = try await getSerializedData(message: message, identifiers: identifiers, recipient: recipient, encryptionType: .group, attempts: attempts)
        
        // Group messages are broadcast to human members only; never send legacy plaintext.
        let result = try DTMessageParamsBuilder().buildParams(with: message, to: thread, recipient: recipient, messageType: .encryptedMessageType, serializedData: serializedData, legacySerializedData: nil, recipientPeerContexts: ermkeys, syncContent: nil)
        
        guard let messageParams = result as? [String: Any] else {
            let errorString = "messageParams convert error."
            OWSLogger.error(errorString)
            throw OWSAssertionError(errorString)
        }
        
        let request = TSRequest(url: URL(string: "/v4/messages/group/\(thread.serverThreadId)")!, method: "PUT", parameters: messageParams)

        let sendResult: HTTPResponse
        if OWSWebSocket.canAppUseSocketsToMakeRequests {
            sendResult = try await self.networkManager.asyncWebsocketRequest(request: request)
        } else {
            sendResult = try await self.networkManager.asyncRequest(request)
        }
        let responseObject: Any? = sendResult.responseBodyJson
                
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
    
    // only private
    func generateSyncContent(for message: TSOutgoingMessage,
                            attempts: Int) async throws -> Data? {
        guard message.shouldSyncTranscript() else {
            return nil
        }

        var selfRecipient: SignalRecipient?
        databaseStorage.read { transaction in
            selfRecipient = SignalRecipient.selfRecipient(with: transaction)
        }

        guard let selfRecipient else {
            OWSLogger.warn("selfRecipient is nil, cannot generate sync content")
            return nil
        }
        if let notice = message as? SyncPlainTextBuildable {
            let label = String(describing: type(of: message))
            guard let syncPlainText = notice.buildSyncPlainTextData(selfRecipient) else {
                OWSLogger.warn("\(label) sync plaintext is nil")
                return nil
            }
            do {
                let serializedData = try encryptPlainText(
                    syncPlainText,
                    recipientId: selfRecipient.recipientId()
                )
                OWSLogger.info("Generated \(label) sync content")
                return serializedData
            } catch {
                OWSLogger.error("\(label) sync encrypt failed (best-effort): \(error)")
                return nil
            }
        }

        let sentMessageTranscript = OWSOutgoingSentMessageTranscript(outgoingMessage: message)
        sentMessageTranscript.toNote = false

        let (_, serializedData, _) = try await getSerializedData(
            message: sentMessageTranscript,
            identifiers: [selfRecipient.recipientId()],
            recipient: selfRecipient,
            encryptionType: .private,
            attempts: attempts
        )

        OWSLogger.info("Generated sync content for message")
        return serializedData
    }

    func handleEncryptedMessageSentLocally(message: TSOutgoingMessage,
                                           toNote: Bool,
                                           attempts: Int,
                                           completion: @escaping () -> Void) async throws -> Void {
        guard message.shouldSyncTranscript(), !message.isKind(of: OWSOutgoingSentMessageTranscript.self) else {
            // Nothing to sync, but the local send succeeded. Must call completion(), or the send
            // operation never finishes and deadlocks the per-thread serial send queue.
            completion()
            return
        }
        var thread: TSThread?
        var selfRecipient: SignalRecipient?
        databaseStorage.read { transaction in
            thread = message.thread(with: transaction)
            selfRecipient = SignalRecipient.selfRecipient(with: transaction)
        }
        
        guard let thread, let selfRecipient  else {
            // No self/thread resolved — still complete so the operation finishes and frees the queue.
            completion()
            return
        }

        // Notice messages (copy/forward activity notices) carry their sync payload via
        // syncMessage.activityNoticeSync / forwardNoticeSync, which OWSOutgoingSentMessageTranscript
        // cannot represent (it only emits syncMessage.sent). Send the notice's own sync payload to
        // self as the main content instead.
        if let notice = message as? SyncPlainTextBuildable {
            let label = String(describing: type(of: message))
            guard let syncPlainText = notice.buildSyncPlainTextData(selfRecipient) else {
                OWSLogger.warn("\(label) sync plaintext is nil, nothing to sync to self.")
                completion()
                return
            }
            let (serializedSync, ermkeys) = try encryptPlainTextWithPeerContexts(syncPlainText, recipientId: selfRecipient.recipientId())
            do {
                try await sendSerializedSyncToSelf(label: "e2ee \(label) sync",
                                                   message: message,
                                                   thread: thread,
                                                   selfRecipient: selfRecipient,
                                                   serializedData: serializedSync,
                                                   recipientPeerContexts: ermkeys,
                                                   attempts: attempts)
                OWSLogger.info("Successfully synced \(label) to self.")
                completion()
            } catch {
                OWSLogger.error("Failed to sync \(label) to self: \(error)")
                throw error
            }
            return
        }

        let sentMessageTranscript = OWSOutgoingSentMessageTranscript(outgoingMessage: message)
        sentMessageTranscript.toNote = toNote

        do {
            try await sendPrivateMessage(label: "e2ee private sync message",
                                   message: sentMessageTranscript,
                                   thread: thread,
                                   recipient: selfRecipient,
                                   attempts: attempts) {
                OWSLogger.info("Successfully sent e2ee sync transcript toNote \(toNote).")
                completion()
            }
        } catch {
            OWSLogger.error("Failed to sent e2ee sync transcript toNote \(toNote): \(error)")
            throw error
        }

    }

    /// Sends already-encrypted serialized sync content to self as the main payload.
    /// `syncContent` is nil here — the serialized data already IS the sync form, so the direct
    /// `content.activityNotice`/`forwardNotice` form is never emitted. Mirrors the request/response
    /// handling of `sendPrivateMessage`.
    private func sendSerializedSyncToSelf(label: String,
                                          message: TSOutgoingMessage,
                                          thread: TSThread,
                                          selfRecipient: SignalRecipient,
                                          serializedData: Data,
                                          recipientPeerContexts: [DTMsgPeerContextParams],
                                          attempts: Int) async throws -> Void {
        if attempts <= 0 {
            throw OWSAssertionError("\(label) attempts over limit.")
        }

        // Mirror the private-message path: only bot / service self-recipients get legacy content.
        var legacyData: Data?
        if DTBotConfig.isBotId(selfRecipient.recipientId()) {
            legacyData = serializedData
        }

        let result = try DTMessageParamsBuilder().buildParams(with: message,
                                                              to: thread,
                                                              recipient: selfRecipient,
                                                              messageType: .encryptedMessageType,
                                                              serializedData: serializedData,
                                                              legacySerializedData: legacyData,
                                                              recipientPeerContexts: recipientPeerContexts,
                                                              syncContent: nil)

        guard let messageParams = result as? [String: Any] else {
            throw OWSAssertionError("\(label) messageParams convert error.")
        }

        let request = TSRequest(url: URL(string: "/v4/messages/\(selfRecipient.recipientId())")!, method: "PUT", parameters: messageParams)

        let sendResult: HTTPResponse
        if OWSWebSocket.canAppUseSocketsToMakeRequests {
            sendResult = try await self.networkManager.asyncWebsocketRequest(request: request)
        } else {
            sendResult = try await self.networkManager.asyncRequest(request)
        }

        guard let jsonData = sendResult.responseBodyJson as? [AnyHashable : Any] else {
            throw OWSAssertionError("\(label) data to json error!")
        }
        guard let metaData = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonData) as? DTAPIMetaEntity else {
            throw OWSAssertionError("\(label) json to metaData error!")
        }

        if metaData.status == DTAPIRequestResponseStatus.OK.rawValue ||
            metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue {
            if metaData.status == DTAPIRequestResponseStatus.unsupportedMsgVersion.rawValue {
                OWSLogger.error("unsupported \(label) message version!")
            }
            return
        }

        if metaData.status == DTAPIRequestResponseStatus.invalidIdentifier.rawValue {
            self.databaseStorage.write { wTransaction in
                SessionStore.deleteSession(identifier: selfRecipient.recipientId(), transaction: wTransaction)
            }
        }

        // retry
        try await sendSerializedSyncToSelf(label: label,
                                           message: message,
                                           thread: thread,
                                           selfRecipient: selfRecipient,
                                           serializedData: serializedData,
                                           recipientPeerContexts: recipientPeerContexts,
                                           attempts: attempts - 1)
    }
    
    func encryptPlainText(_ plainText: Data, recipientId: String) throws -> Data {
        // Preserve original behavior: serialized ciphertext only, no eRMKeys requirement.
        return try encryptForRecipient(plainText, recipientId: recipientId).serialized
    }

    /// Like `encryptPlainText` but also returns the per-recipient peer contexts (eRMKeys) required by
    /// the v4 message envelope's `recipients` field. Throws if eRMKeys are missing (needed for the
    /// self-addressed sync send), unlike `encryptPlainText` which tolerates their absence.
    func encryptPlainTextWithPeerContexts(_ plainText: Data, recipientId: String) throws -> (serialized: Data, ermkeys: [DTMsgPeerContextParams]) {
        let result = try encryptForRecipient(plainText, recipientId: recipientId)
        guard let ermkeys = result.ermkeys, !ermkeys.isEmpty else {
            throw OWSAssertionError("sync ermk error!")
        }
        return (result.serialized, ermkeys)
    }

    private func encryptForRecipient(_ plainText: Data, recipientId: String) throws -> (serialized: Data, ermkeys: [DTMsgPeerContextParams]?) {
        let sessionCipher = DTSessionCipher(recipientId: recipientId, type: .private)
        var encryptedMessage: DTEncryptedMessage?
        var encryptError: Error?
        databaseStorage.read { transaction in
            do {
                encryptedMessage = try sessionCipher.encryptMessage(plainText.paddedMessageBody, transaction: transaction)
            } catch {
                encryptError = error
            }
        }
        if let encryptError { throw encryptError }
        guard let encryptedMessage else {
            throw OWSAssertionError("sync encrypt failed")
        }
        return (encryptedMessage.serialized, encryptedMessage.eRMKeys)
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
