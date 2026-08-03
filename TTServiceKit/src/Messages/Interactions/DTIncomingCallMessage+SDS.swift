//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB
import SignalCoreKit

// Hand-written SDS serializer for DTIncomingCallMessage (recordType 64).
// Mirrors TSIncomingMessageSerializer, plus the stored callState/roomId fields.

// MARK: - SDSSerializer

// The SDSSerializer protocol specifies how to insert and update the
// row that corresponds to this model.
class DTIncomingCallMessageSerializer: SDSSerializer {

    private let model: DTIncomingCallMessage
    public required init(model: DTIncomingCallMessage) {
        self.model = model
    }

    // MARK: - Record

    func asRecord() throws -> SDSRecord {
        let id: Int64? = model.grdbId?.int64Value

        let recordType: SDSRecordType = .incomingCallMessage
        let uniqueId: String = model.uniqueId

        // Properties
        let associatedUniqueThreadId: String = model.associatedUniqueThreadId
        let atPersons: String? = model.atPersons
        let attachmentIds: Data? = optionalArchive(model.attachmentIds)
        let authorId: String? = model.authorId
        let body: String? = model.body
        let card: Data? = optionalArchive(model.card)
        let combinedForwardingMessage: Data? = optionalArchive(model.combinedForwardingMessage)
        let contactShare: Data? = optionalArchive(model.contactShare)
        let customAttributedMessage: Data? = nil
        let customMessage: String? = nil
        let editable: Bool? = model.editable
        let errorType: TSErrorMessageType? = nil
        let expireStartedAt: UInt64? = model.expireStartedAt
        let expiresAt: UInt64? = model.expiresAt
        let expiresInSeconds: UInt32? = model.expiresInSeconds
        let groupChatMode: TSGroupChatMode? = nil
        let groupMetaMessage: TSGroupMetaMessage? = nil
        let hasSyncedTranscript: Bool? = nil
        let inviteCode: String? = nil
        let isFromLinkedDevice: Bool? = nil
        let isPinnedMessage: Bool? = model.isPinnedMessage
        let isVoiceMessage: Bool? = nil
        let meetingDetailUrl: String? = nil
        let meetingName: String? = nil
        let meetingReminderType: DTMeetingReminderType? = nil
        let messageType: TSInfoMessageType? = nil
        let mostRecentFailureText: String? = nil
        let notifySequenceId: UInt64 = model.notifySequenceId
        let pinId: String? = model.pinId
        let quotedMessage: Data? = optionalArchive(model.quotedMessage)
        let rapidFiles: Data? = nil
        let reactionMap: Data? = optionalArchive(model.reactionMap)
        let reactionMessage: Data? = optionalArchive(model.reactionMessage)
        let read: Bool? = model.wasRead
        let realSource: Data? = nil
        let recall: Data? = optionalArchive(model.recall)
        let recallPreview: String? = nil
        let receivedAtTimestamp: UInt64 = model.receivedAtTimestamp
        let recipientId: String? = nil
        let recipientStateMap: Data? = nil
        let sequenceId: UInt64 = model.sequenceId
        let serverTimestamp: UInt64 = model.serverTimestamp
        let sourceDeviceId: UInt32? = model.sourceDeviceId
        let timestamp: UInt64 = model.timestamp
        let translateMessage: Data? = optionalArchive(model.translateMessage)
        let threadUniqueId: String = model.uniqueThreadId
        let unregisteredRecipientId: String? = nil
        let whisperMessageType: TSWhisperMessageType? = model.whisperMessageType
        let storedShouldStartExpireTimer: Bool? = model.storedShouldStartExpireTimer
        let mentionedMsgType: OWSMentionedMsgType? = model.mentionedMsgType
        let configurationDurationSeconds: UInt32? = nil
        let shouldAffectThreadSorting: Bool? = nil
        let mentions: Data? = optionalArchive(model.mentions)
        let storedMessageState: TSOutgoingMessageState? = nil
        let envelopSource: String? = model.envelopSource
        let cardUniqueId: String? = model.cardUniqueId
        let cardVersion: UInt32? = model.cardVersion
        let messageModeType: TSMessageModeType? = model.messageModeType
        let callState: Int? = model.callState
        let roomId: String? = model.roomId

        return InteractionRecord(delegate: model, id: id, recordType: recordType, uniqueId: uniqueId, associatedUniqueThreadId: associatedUniqueThreadId, atPersons: atPersons, attachmentIds: attachmentIds, authorId: authorId, body: body, card: card, combinedForwardingMessage: combinedForwardingMessage, contactShare: contactShare, customAttributedMessage: customAttributedMessage, customMessage: customMessage, editable: editable, errorType: errorType, expireStartedAt: expireStartedAt, expiresAt: expiresAt, expiresInSeconds: expiresInSeconds, groupChatMode: groupChatMode, groupMetaMessage: groupMetaMessage, hasSyncedTranscript: hasSyncedTranscript, inviteCode: inviteCode, isFromLinkedDevice: isFromLinkedDevice, isPinnedMessage: isPinnedMessage, isVoiceMessage: isVoiceMessage, meetingDetailUrl: meetingDetailUrl, meetingName: meetingName, meetingReminderType: meetingReminderType, messageType: messageType, mostRecentFailureText: mostRecentFailureText, notifySequenceId: notifySequenceId, pinId: pinId, quotedMessage: quotedMessage, rapidFiles: rapidFiles, reactionMap: reactionMap, reactionMessage: reactionMessage, read: read, realSource: realSource, recall: recall, recallPreview: recallPreview, receivedAtTimestamp: receivedAtTimestamp, recipientId: recipientId, recipientStateMap: recipientStateMap, sequenceId: sequenceId, serverTimestamp: serverTimestamp, sourceDeviceId: sourceDeviceId, timestamp: timestamp, translateMessage: translateMessage, threadUniqueId: threadUniqueId, unregisteredRecipientId: unregisteredRecipientId, whisperMessageType: whisperMessageType, storedShouldStartExpireTimer: storedShouldStartExpireTimer, mentionedMsgType: mentionedMsgType, configurationDurationSeconds: configurationDurationSeconds, shouldAffectThreadSorting: shouldAffectThreadSorting, mentions: mentions, storedMessageState: storedMessageState, envelopSource: envelopSource, cardUniqueId: cardUniqueId, cardVersion: cardVersion, messageModeType: messageModeType, callState: callState, roomId: roomId)
    }
}
