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
    func receiveIncomingLocalGroupStartCallMessage() {
        self.databaseStorage.write { transaction in
            guard let groupThread = getGroupThread(),
                  let source = currentCall.caller else { return }

            let body = Environment.shared.contactsManager.displayName(forPhoneIdentifier: currentCall.caller) + " has started a call"
            let message = createIncomingMessage(thread: groupThread, timestamp: currentCall.timestamp, authorId: source, body: body)
            OWSMessageManager.shared().finalizeIncomingMessage(message, thread: groupThread, transaction: transaction)
        }
    }

    func sendOutgoingLocalGroupStartCallMessage(thread: TSThread? = nil) {
        self.databaseStorage.write { transaction in
            let targetThread = thread as? TSGroupThread ?? getGroupThread()
            if let thread = targetThread {
                createOutgoingMessage(thread: thread, body: self.nameSelf() + " has started a call", transaction: transaction)
            }
        }
    }

    // MARK: - Private Start
    func receiveIncomingLocalPrivateStartCallMessage() {
        self.databaseStorage.write { transaction in
            let contactId = currentCall.caller ?? ""
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let message = createIncomingMessage(thread: thread, timestamp: currentCall.timestamp, authorId: contactId, body: "Calling")
            OWSMessageManager.shared().finalizeIncomingMessage(message, thread: thread, transaction: transaction)
        }
    }

    func sendOutgoingLocalPrivateStartCallMessage(thread: TSThread? = nil) {
        self.databaseStorage.write { transaction in
            let contactId = currentCall.caller ?? ""
            let targetThread = thread as? TSContactThread ?? TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            createOutgoingMessage(thread: targetThread, body: "Calling", contactId: contactId, transaction: transaction)
        }
    }

    // MARK: - Private Invite
    func receiveIncomingLocalPrivateInviteCallMessage(receiptId: String?) {
        self.databaseStorage.write { transaction in
            guard let contactId = receiptId else { return }
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let body = Environment.shared.contactsManager.displayName(forPhoneIdentifier: contactId) + " invites you to a call"
            if let index = currentCall.inviteCallees?.firstIndex(of: TSAccountManager.localNumber() ?? "") {
                let ts = (currentCall.timestamp ?? Date().ows_millisecondsSince1970) + UInt64(index)
                let message = createIncomingMessage(thread: thread, timestamp: ts, authorId: contactId, body: body)
                OWSMessageManager.shared().finalizeIncomingMessage(message, thread: thread, transaction: transaction)
            }
        }
    }

    func sendOutgoingLocalPrivateInviteCallMessage(receiptId: String?) {
        self.databaseStorage.write { transaction in
            guard let contactId = receiptId else { return }
            let thread = TSContactThread.getOrCreateThread(withContactId: contactId, transaction: transaction)
            let body = self.nameSelf() + " invites you to a call"
            if let index = currentCall.inviteCallees?.firstIndex(of: receiptId ?? "") {
                let timestamp = (currentCall.timestamp ?? Date().ows_millisecondsSince1970) + UInt64(index)
                createOutgoingMessage(thread: thread, body: body, contactId: contactId, timestamp: timestamp, transaction: transaction)
            }
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
                                 completion: (() -> Void)? = nil) {
        
        guard (createCallMsg ?? false) else {
            return
        }
        completion?()
        switch controlType {
        case DTMeetingManager.sourceControlInvite:
            handleInviteCall(callees: callees,
                             caller: caller ?? "",
                             isFromOtherDevice: isFromOtherDevice ?? false)
            
        case DTMeetingManager.sourceControlStart:
            handleStartCall(callType: callType ?? .private,
                            conversationId: conversationId ?? "",
                            isFromOtherDevice: isFromOtherDevice ?? false)
            
        default:
            break
        }
    }
    
    private func handleInviteCall(callees: [String]?,
                                  caller: String,
                                  isFromOtherDevice: Bool) {
        if isFromOtherDevice {
            callees?.forEach { receiptId in
                sendOutgoingLocalPrivateInviteCallMessage(receiptId: receiptId)
            }
        } else {
            receiveIncomingLocalPrivateInviteCallMessage(receiptId: caller)
        }
    }

    private func handleStartCall(callType: CallType,
                                 conversationId: String?,
                                 isFromOtherDevice: Bool) {
        let isPrivateCall = (callType == .private)
        
        if isPrivateCall, let conversationId = conversationId {
            let contactThread = TSContactThread.getOrCreateThread(contactId: conversationId)
            prepareForMeetingStartOrInvite(thread: contactThread, isOutgoing: isFromOtherDevice)
        } else {
            prepareForMeetingStartOrInvite(isOutgoing: isFromOtherDevice)
        }
    }
    
    // MARK: - Common Helper
    private func createOutgoingMessage(
        thread: TSThread,
        body: String,
        contactId: String? = nil,
        timestamp: UInt64? = nil,
        transaction: SDSAnyWriteTransaction
    ) {
        let finalTimestamp = timestamp ?? currentCall.timestamp ?? Date.ows_millisecondTimestamp()
        let finalServerTimestamp = currentCall.serverTimestamp ?? Date.ows_millisecondTimestamp()
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
        message.sourceDeviceId = currentCall.envelopeSourceDevice ?? OWSDevice.currentDeviceId()
        message.serverTimestamp = finalServerTimestamp
        message.messageModeType = .normal
        message.recipientStateMap?.values.forEach { $0.state = .sent }
        message.anyInsert(transaction: transaction)
    }

    private func createIncomingMessage(
        thread: TSThread,
        timestamp: UInt64?,
        authorId: String,
        body: String
    ) -> TSIncomingMessage {
        let finalTimestamp = timestamp ?? currentCall.timestamp ?? Date.ows_millisecondTimestamp()
        let finalServerTimestamp = currentCall.serverTimestamp ?? Date.ows_millisecondTimestamp()
        let message = TSIncomingMessage(
            incomingMessageWithTimestamp: finalTimestamp,
            serverTimestamp: finalServerTimestamp,
            sequenceId: 1,
            notifySequenceId: 0,
            in: thread,
            authorId: currentCall.envelopeSource ?? "",
            sourceDeviceId: currentCall.envelopeSourceDevice ?? 1,
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
