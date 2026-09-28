//
//  Copyright (c) 2026 Difft. All rights reserved.
//

import Foundation

@objc
public enum DTEnvelopeConversationValidationResult: Int {
    /// The service-stamped delivery conversation agrees with decrypted content.
    case matched
    /// The service-stamped delivery conversation explicitly contradicts decrypted content.
    case mismatched
    /// No usable service-stamped delivery conversation is available.
    case unavailable
}

/// Cross-checks the conversation parsed from decrypted content against the
/// conversation stamped by the service for the actual delivery channel.
///
/// Only an explicit contradiction is rejected. A missing — or not yet
/// understood — service value fails open, so old servers and rollout traffic
/// are never dropped in bulk. Callers that have a narrower compatibility
/// fallback can use the tri-state APIs to handle `.unavailable` separately.
@objcMembers
public final class DTEnvelopeConversationValidator: NSObject {

    private enum EnvelopeConversation {
        case unavailable
        case group(Data)
        case oneToOne(String)
    }

    /// Keep DataMessage conversation classification identical at validation,
    /// pre-processing, and final thread resolution. A missing or empty group ID
    /// does not name a group conversation.
    @objc(isGroupDataMessage:)
    public static func isGroupDataMessage(_ dataMessage: DSKProtoDataMessage) -> Bool {
        guard let groupID = dataMessage.group?.id else {
            return false
        }
        return !groupID.isEmpty
    }

    @objc(isEnvelope:consistentWithGroupID:context:)
    public static func isEnvelope(
        _ envelope: DSKProtoEnvelope,
        consistentWithGroupID contentGroupID: Data?,
        context: String
    ) -> Bool {
        validationResult(
            for: envelope,
            consistentWithGroupID: contentGroupID,
            context: context
        ) != .mismatched
    }

    @objc(validationResultForEnvelope:consistentWithGroupID:context:)
    public static func validationResult(
        for envelope: DSKProtoEnvelope,
        consistentWithGroupID contentGroupID: Data?,
        context: String
    ) -> DTEnvelopeConversationValidationResult {
        guard let expectedGroupID = canonicalGroupID(contentGroupID) else {
            Logger.error("[ConversationOwnership] \(context) content group id is missing or malformed")
            return .mismatched
        }

        switch envelopeConversation(envelope) {
        case .unavailable:
            Logger.warn("[ConversationOwnership] \(context) envelope conversationId is missing or empty; allowing compatibility fallback")
            return .unavailable
        case .group(let envelopeGroupID):
            guard envelopeGroupID == expectedGroupID else {
                Logger.error("[ConversationOwnership] \(context) group conversation mismatch")
                return .mismatched
            }
            return .matched
        case .oneToOne:
            Logger.error("[ConversationOwnership] \(context) expected a group delivery channel")
            return .mismatched
        }
    }

    @objc(isEnvelope:consistentWithOneToOneNumber:context:)
    public static func isEnvelope(
        _ envelope: DSKProtoEnvelope,
        consistentWithOneToOneNumber contentNumber: String?,
        context: String
    ) -> Bool {
        validationResult(
            for: envelope,
            consistentWithOneToOneNumber: contentNumber,
            context: context
        ) != .mismatched
    }

    @objc(validationResultForEnvelope:consistentWithOneToOneNumber:context:)
    public static func validationResult(
        for envelope: DSKProtoEnvelope,
        consistentWithOneToOneNumber contentNumber: String?,
        context: String
    ) -> DTEnvelopeConversationValidationResult {
        guard let expectedNumber = nonEmpty(contentNumber) else {
            Logger.error("[ConversationOwnership] \(context) content 1v1 number is missing")
            return .mismatched
        }

        switch envelopeConversation(envelope) {
        case .unavailable:
            Logger.warn("[ConversationOwnership] \(context) envelope conversationId is missing or empty; allowing compatibility fallback")
            return .unavailable
        case .oneToOne(let envelopeNumber):
            guard envelopeNumber == expectedNumber else {
                Logger.error("[ConversationOwnership] \(context) 1v1 conversation mismatch")
                return .mismatched
            }
            return .matched
        case .group:
            Logger.error("[ConversationOwnership] \(context) expected a 1v1 delivery channel")
            return .mismatched
        }
    }

    private static func envelopeConversation(_ envelope: DSKProtoEnvelope) -> EnvelopeConversation {
        guard let conversationID = envelope.msgExtra?.conversationID else {
            return .unavailable
        }

        let groupID = canonicalGroupID(conversationID.groupID)
        let number = nonEmpty(conversationID.number)

        switch (groupID, number) {
        case (.none, .none):
            // An empty object provides no usable delivery-conversation evidence.
            return .unavailable
        case (.some(let groupID), .none):
            return .group(groupID)
        case (.none, .some(let number)):
            return .oneToOne(number)
        case (.some(let groupID), .some):
            // Match Android's parsing precedence: a present group id defines the
            // delivery conversation even when a number is also present.
            Logger.warn("[ConversationOwnership] envelope conversationId carries both a group id and a number; using group id")
            return .group(groupID)
        }
    }

    /// Converts both raw local ids and UTF-8 server ids into the local byte form.
    ///
    /// Server ids reach us as UTF-8 (32 or 36 bytes today, or the legacy
    /// prefixed form) and are decoded by `TSGroupThread`. Raw 16-byte legacy
    /// local ids are returned untouched: they are not text, and decoding one
    /// that happens to start with the legacy prefix would corrupt it.
    private static func canonicalGroupID(_ groupID: Data?) -> Data? {
        guard let groupID, !groupID.isEmpty else {
            return nil
        }

        if groupID.count == 16 {
            return groupID
        }

        if let serverGroupID = String(data: groupID, encoding: .utf8),
           !serverGroupID.isEmpty,
           let localGroupID = TSGroupThread.transformToLocalGroupId(withServerGroupId: serverGroupID),
           !localGroupID.isEmpty {
            return localGroupID
        }

        return groupID
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
