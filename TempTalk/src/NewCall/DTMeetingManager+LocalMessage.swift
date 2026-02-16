//
//  Untitled.swift
//  Difft
//
//  Created by Henry on 2025/6/10.
//  Copyright © 2025 Difft. All rights reserved.
//

import AVFAudio
import LiveKit

extension DTMeetingManager {
    // MARK: - Group Start
    func receiveIncomingLocalGroupStartCallMessage(serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            guard let groupThread = getGroupThread(),
                  let source = currentCall.caller else { return }

            let body = Environment.shared.contactsManager.displayName(forPhoneIdentifier: currentCall.caller) + " has started a call"
            let message = createIncomingMessage(
                thread: groupThread,
                timestamp: currentCall.timestamp,
                serverTimestamp: serverTimestamp,
                authorId: source,
                body: body
            )
            OWSMessageManager.shared().finalizeIncomingMessage(message, thread: groupThread, transaction: transaction)
        }
    }

    func sendOutgoingLocalGroupStartCallMessage(thread: TSThread? = nil, serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            let targetThread = thread as? TSGroupThread ?? getGroupThread()
            if let thread = targetThread {
                createOutgoingMessage(
                    thread: thread,
                    body: self.nameSelf() + " has started a call",
                    serverTimestamp: serverTimestamp,
                    transaction: transaction
                )
            }
        }
    }

    // MARK: - Private Start
    func receiveIncomingLocalPrivateStartCallMessage(serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            let contactId = currentCall.caller ?? ""
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let message = createIncomingMessage(
                thread: thread,
                timestamp: currentCall.timestamp,
                serverTimestamp: serverTimestamp,
                authorId: contactId,
                body: "Calling"
            )
            OWSMessageManager.shared().finalizeIncomingMessage(message, thread: thread, transaction: transaction)
        }
    }

    func sendOutgoingLocalPrivateStartCallMessage(thread: TSThread? = nil, serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            let contactId = currentCall.caller ?? ""
            let targetThread = thread as? TSContactThread ?? TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            createOutgoingMessage(
                thread: targetThread,
                body: "Calling",
                contactId: contactId,
                serverTimestamp: serverTimestamp,
                transaction: transaction
            )
        }
    }

    // MARK: - Private Invite
    func receiveIncomingLocalPrivateInviteCallMessage(receiptId: String?, serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            guard let contactId = receiptId else { return }
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let body = Environment.shared.contactsManager.displayName(forPhoneIdentifier: contactId) + " invites you to a call"
            if let index = currentCall.inviteCallees?.firstIndex(of: TSAccountManager.localNumber() ?? "") {
                let ts = (currentCall.timestamp ?? Date().ows_millisecondsSince1970) + UInt64(index)
                let message = createIncomingMessage(thread: thread, timestamp: ts, serverTimestamp: serverTimestamp, authorId: contactId, body: body)
                OWSMessageManager.shared().finalizeIncomingMessage(message, thread: thread, transaction: transaction)
            }
        }
    }

    func sendOutgoingLocalPrivateInviteCallMessage(receiptId: String?, serverTimestamp: UInt64? = nil) {
        self.databaseStorage.write { transaction in
            guard let contactId = receiptId else { return }
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let body = self.nameSelf() + " invites you to a call"
            if let index = currentCall.inviteCallees?.firstIndex(of: receiptId ?? "") {
                let timestamp = (currentCall.timestamp ?? Date().ows_millisecondsSince1970) + UInt64(index)
                createOutgoingMessage(thread: thread, body: body, contactId: contactId, timestamp: timestamp, serverTimestamp: serverTimestamp, transaction: transaction)
            }
        }
    }
    
    // MARK: - CriticalAlert
    func createCriticalAlertLocalMessage(thread: TSThread? = nil,
                                         contactId: String? = nil,
                                         sourceDeviceId: UInt32? = nil,
                                         timestamp: UInt64? = nil,
                                         serverTimestamp: UInt64? = nil,
                                         transation: SDSAnyWriteTransaction?) {
        if let local = TSAccountManager.localNumber(), local == contactId {
            if sourceDeviceId != OWSDevice.currentDeviceId() {
                self.createCriticalAlertLocalOutgoingMessage (
                    thread: thread,
                    contactId: contactId,
                    timestamp: timestamp,
                    serverTimestamp: serverTimestamp,
                    transation: transation
                )
            }
        } else {
            self.createCriticalAlertLocalIncomingMessage(
                thread: thread,
                contactId: contactId,
                sourceDeviceId: sourceDeviceId,
                timestamp: timestamp,
                serverTimestamp: serverTimestamp,
                transation: transation
            )
        }
    }
    
    func createCriticalAlertLocalOutgoingMessage(thread: TSThread? = nil,
                                                 contactId: String? = nil,
                                                 timestamp: UInt64? = nil,
                                                 serverTimestamp: UInt64? = nil,
                                                 transation: SDSAnyWriteTransaction?) {
        if let thread = thread, let writeTransation = transation {
            let contactIdefier = contactId ?? currentCall.caller ?? ""
            createOutgoingMessage(thread: thread,
                                  body: Localized("CONVERSATION_MESSAGE_CRITICAL_ALERT"),
                                  contactId: contactIdefier,
                                  timestamp:timestamp,
                                  serverTimestamp: serverTimestamp,
                                  sourceDeviceId: OWSDevice.currentDeviceId(),
                                  transaction: writeTransation)
        }
    }
    
    func createCriticalAlertLocalIncomingMessage(thread: TSThread? = nil,
                                                 contactId: String? = nil,
                                                 sourceDeviceId: UInt32? = nil,
                                                 timestamp: UInt64? = nil,
                                                 serverTimestamp: UInt64? = nil,
                                                 transation: SDSAnyWriteTransaction?) {
        if let thread = thread, let contactId = contactId, let writeTransation = transation {
            let message = createIncomingMessage(thread: thread,
                                                timestamp: timestamp,
                                                serverTimestamp: serverTimestamp,
                                                authorId: contactId,
                                                sourceDeviceId: sourceDeviceId,
                                                body: Localized("CONVERSATION_MESSAGE_CRITICAL_ALERT"))
            OWSMessageManager.shared().finalizeIncomingMessage(message, thread: thread, transaction: writeTransation)
        }
    }

    // MARK: - 收到calling消息处理
    func dealCallingLocalMessage(createCallMsg: Bool?,
                                 controlType: String?,
                                 callees: [String]?,
                                 caller: String?,
                                 callType: CallType?,
                                 conversationId: String?,
                                 isFromOtherDevice: Bool?,
                                 serverTimestamp: UInt64?,
                                 completion: (() -> Void)? = nil) {

        guard (createCallMsg ?? false) else {
            return
        }
        completion?()
        switch controlType {
        case DTMeetingManager.sourceControlInvite:
            handleInviteCall(callees: callees,
                             caller: caller ?? "",
                             isFromOtherDevice: isFromOtherDevice ?? false,
                             serverTimestamp: serverTimestamp)

        case DTMeetingManager.sourceControlStart:
            handleStartCall(callType: callType ?? .private,
                            conversationId: conversationId ?? "",
                            isFromOtherDevice: isFromOtherDevice ?? false,
                            serverTimestamp: serverTimestamp)

        default:
            break
        }
    }

    private func handleInviteCall(callees: [String]?,
                                  caller: String,
                                  isFromOtherDevice: Bool,
                                  serverTimestamp: UInt64?) {
        if isFromOtherDevice {
            callees?.forEach { receiptId in
                sendOutgoingLocalPrivateInviteCallMessage(receiptId: receiptId, serverTimestamp: serverTimestamp)
            }
        } else {
            receiveIncomingLocalPrivateInviteCallMessage(receiptId: caller, serverTimestamp: serverTimestamp)
        }
    }

    private func handleStartCall(callType: CallType,
                                 conversationId: String?,
                                 isFromOtherDevice: Bool,
                                 serverTimestamp: UInt64?) {
        let isPrivateCall = (callType == .private)

        if isPrivateCall, let conversationId = conversationId {
            let contactThread = TSContactThread.getOrCreateThread(contactId: conversationId)
            prepareForMeetingStartOrInvite(thread: contactThread, serverTimestamp: serverTimestamp, isOutgoing: isFromOtherDevice)
        } else {
            prepareForMeetingStartOrInvite(serverTimestamp: serverTimestamp, isOutgoing: isFromOtherDevice)
        }
    }
    
    // MARK: - Common Helper
    private func createOutgoingMessage(
        thread: TSThread,
        body: String,
        contactId: String? = nil,
        timestamp: UInt64? = nil,
        serverTimestamp: UInt64? = nil,
        sourceDeviceId: UInt32? = nil,
        transaction: SDSAnyWriteTransaction
    ) {
        let finalTimestamp = timestamp ?? currentCall.timestamp ?? Date.ows_millisecondTimestamp()
        
        let finalServerTimestamp: UInt64
        if let serverTimestamp = serverTimestamp {
            finalServerTimestamp = serverTimestamp
        } else if let callServerTimestamp = currentCall.serverTimestamp {
            finalServerTimestamp = callServerTimestamp
        } else {
            finalServerTimestamp = finalTimestamp
        }

        let message = TSOutgoingMessage.init(outgoingMessageWithTimestamp: finalTimestamp,
                                             in: thread,
                                             messageBody: body,
                                             atPersons: nil,
                                             mentions: nil,
                                             attachmentIds: [],
                                             expiresInSeconds: thread.messageExpiresInSeconds(),
                                             expireStartedAt: 0,
                                             isVoiceMessage: false,
                                             groupMetaMessage: .messageUnspecified,
                                             quotedMessage: nil,
                                             forwardingMessage: nil,
                                             contactShare: nil)
        message.sourceDeviceId = sourceDeviceId ?? currentCall.envelopeSourceDevice ?? OWSDevice.currentDeviceId()
        message.serverTimestamp = finalServerTimestamp
        message.messageModeType = .normal
        message.recipientStateMap?.values.forEach { $0.state = .sent }
        message.anyInsert(transaction: transaction)
    }

    private func createIncomingMessage(
        thread: TSThread,
        timestamp: UInt64? = nil,
        serverTimestamp: UInt64? = nil,
        authorId: String? = nil,
        sourceDeviceId: UInt32? = nil,
        body: String
    ) -> TSIncomingMessage {
        let finalTimestamp = timestamp ?? currentCall.timestamp ?? Date.ows_millisecondTimestamp()
        
        let finalServerTimestamp: UInt64
        if let serverTimestamp = serverTimestamp {
            finalServerTimestamp = serverTimestamp
        } else if let callServerTimestamp = currentCall.serverTimestamp {
            finalServerTimestamp = callServerTimestamp
        } else {
            finalServerTimestamp = finalTimestamp
        }

        let sourceDeviceId = sourceDeviceId ?? currentCall.envelopeSourceDevice ?? OWSDevice.currentDeviceId()
        let author = authorId ?? currentCall.envelopeSource ?? ""
        let message = TSIncomingMessage(
            incomingMessageWithTimestamp: finalTimestamp,
            serverTimestamp: finalServerTimestamp,
            sequenceId: 1,
            notifySequenceId: 0,
            in: thread,
            authorId: author,
            sourceDeviceId: sourceDeviceId,
            messageBody: body,
            atPersons: nil,
            mentions: nil,
            attachmentIds: [],
            expiresInSeconds: thread.messageExpiresInSeconds(),
            quotedMessage: nil,
            forwardingMessage: nil,
            contactShare: nil
        )
        message.reactionMessage = nil
        message.whisperMessageType = .encryptedMessageType
        message.messageModeType = .normal
        return message
    }

    private func getGroupThread() -> TSGroupThread? {
        guard let gid = currentCall.conversationId,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid) else { return nil }
        return TSGroupThread.getWithGroupId(groupId)
    }
}
