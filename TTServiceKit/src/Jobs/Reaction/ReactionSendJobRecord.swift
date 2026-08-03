//
// Copyright 2024 Difft. All rights reserved.
//
// Persistent job record for a single reaction send (emoji add/remove).
// Uses `invisibleMessage` BLOB to store the serialized domain data.
//

import Foundation
import GRDB

public final class ReactionSendJobRecord: JobRecord {

    override public class var jobRecordType: JobRecordType { .reactionSend }

    // MARK: - Domain fields (decoded from invisibleMessage)

    public let realSourceTimestamp: UInt64
    public let realSourceDevice: UInt32
    public let realSourceAuthor: String
    public let emoji: String
    public let removeAction: Bool
    public let operationTimestamp: UInt64
    /// Timestamp of the old reaction being removed; 0 when adding.
    public let removedOriginTimestamp: UInt64

    // MARK: - Payload Codable (stored in invisibleMessage)

    private struct Payload: Codable {
        let realSourceTimestamp: UInt64
        let realSourceDevice: UInt32
        let realSourceAuthor: String
        let emoji: String
        let removeAction: Bool
        let operationTimestamp: UInt64
        let removedOriginTimestamp: UInt64
    }

    // MARK: - Init (create new job)

    public init(
        conversationId: String,
        realSourceTimestamp: UInt64,
        realSourceDevice: UInt32,
        realSourceAuthor: String,
        emoji: String,
        removeAction: Bool,
        operationTimestamp: UInt64,
        removedOriginTimestamp: UInt64 = 0
    ) {
        self.realSourceTimestamp = realSourceTimestamp
        self.realSourceDevice = realSourceDevice
        self.realSourceAuthor = realSourceAuthor
        self.emoji = emoji
        self.removeAction = removeAction
        self.operationTimestamp = operationTimestamp
        self.removedOriginTimestamp = removedOriginTimestamp

        guard let payloadData = try? JSONEncoder().encode(Payload(
            realSourceTimestamp: realSourceTimestamp,
            realSourceDevice: realSourceDevice,
            realSourceAuthor: realSourceAuthor,
            emoji: emoji,
            removeAction: removeAction,
            operationTimestamp: operationTimestamp,
            removedOriginTimestamp: removedOriginTimestamp
        )) else {
            owsFail("Failed to encode ReactionSendJobRecord payload")
        }

        super.init(
            failureCount: 0,
            status: .ready,
            invisibleMessage: payloadData,
            threadId: conversationId
        )
    }

    // MARK: - InheritableRecord (decode from DB)

    required init(inheritableDecoder decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let blobData = try container.decodeIfPresent(Data.self, forKey: .invisibleMessage)
        guard let data = blobData else {
            throw OWSGenericError("ReactionSendJobRecord missing invisibleMessage")
        }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        self.realSourceTimestamp = p.realSourceTimestamp
        self.realSourceDevice = p.realSourceDevice
        self.realSourceAuthor = p.realSourceAuthor
        self.emoji = p.emoji
        self.removeAction = p.removeAction
        self.operationTimestamp = p.operationTimestamp
        self.removedOriginTimestamp = p.removedOriginTimestamp

        try super.init(inheritableDecoder: decoder)
    }

    // MARK: - Convenience

    /// The conversation (thread) this reaction belongs to.
    public var conversationId: String {
        threadId ?? ""
    }
}
