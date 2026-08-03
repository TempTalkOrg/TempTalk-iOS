//
// Copyright 2024 Difft. All rights reserved.
//
//
// Persistent base class for all jobs scheduled by ``JobQueueRunner``.
//
// Persistent base class for all jobs scheduled by ``JobQueueRunner``.
//

import Foundation
import GRDB

public class JobRecord: SDSCodableModel, InheritableRecord {

    public enum Status: Int, Codable {
        case unknown = 0
        case ready
        case running
        case permanentlyFailed
        case obsolete
    }

    // MARK: - SDSCodableModel conformance

    public static let databaseTableName: String = "model_SSKJobRecord"

    public typealias CodingKeys = JobRecordColumns

    /// Subclasses must override.
    public class var jobRecordType: JobRecordType {
        owsFail("Must be provided by subclasses!")
    }

    public static var recordType: UInt { jobRecordType.rawValue }

    // MARK: - Stored properties

    public var id: RowId?
    public let uniqueId: String

    public private(set) var failureCount: UInt
    let label: String
    private(set) var status: Status

    // MARK: - Job-type columns

    public let attachmentIdMap: Data?
    public let contactThreadId: String?
    public let envelopeData: Data?
    public let invisibleMessage: Data?
    public let messageId: String?
    public let removeMessageAfterSending: Bool
    public let threadId: String?

    // MARK: - Future-proof columns (Signal later migrations, added upfront)

    public var exclusiveProcessIdentifier: String?
    public let isHighPriority: Bool
    public let isMediaMessage: Bool

    // MARK: - Initialization

    init(
        failureCount: UInt = 0,
        status: Status = .ready,
        attachmentIdMap: Data? = nil,
        contactThreadId: String? = nil,
        envelopeData: Data? = nil,
        invisibleMessage: Data? = nil,
        messageId: String? = nil,
        removeMessageAfterSending: Bool = false,
        threadId: String? = nil,
        exclusiveProcessIdentifier: String? = nil,
        isHighPriority: Bool = false,
        isMediaMessage: Bool = false
    ) {
        self.uniqueId = UUID().uuidString
        self.label = Self.jobRecordType.jobRecordLabel
        self.failureCount = failureCount
        self.status = status
        self.attachmentIdMap = attachmentIdMap
        self.contactThreadId = contactThreadId
        self.envelopeData = envelopeData
        self.invisibleMessage = invisibleMessage
        self.messageId = messageId
        self.removeMessageAfterSending = removeMessageAfterSending
        self.threadId = threadId
        self.exclusiveProcessIdentifier = exclusiveProcessIdentifier
        self.isHighPriority = isHighPriority
        self.isMediaMessage = isMediaMessage
    }

    // MARK: - InheritableRecord (Codable plumbing)

    public required init(inheritableDecoder decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(SDSCodableModel.RowId.self, forKey: .id)
        uniqueId = try container.decode(String.self, forKey: .uniqueId)

        failureCount = try container.decode(UInt.self, forKey: .failureCount)
        label = try container.decode(String.self, forKey: .label)
        status = Status(rawValue: try container.decode(Int.self, forKey: .status)) ?? .unknown

        attachmentIdMap = try container.decodeIfPresent(Data.self, forKey: .attachmentIdMap)
        contactThreadId = try container.decodeIfPresent(String.self, forKey: .contactThreadId)
        envelopeData = try container.decodeIfPresent(Data.self, forKey: .envelopeData)
        invisibleMessage = try container.decodeIfPresent(Data.self, forKey: .invisibleMessage)
        messageId = try container.decodeIfPresent(String.self, forKey: .messageId)
        removeMessageAfterSending = try container.decodeIfPresent(Bool.self, forKey: .removeMessageAfterSending) ?? false
        threadId = try container.decodeIfPresent(String.self, forKey: .threadId)

        exclusiveProcessIdentifier = try container.decodeIfPresent(String.self, forKey: .exclusiveProcessIdentifier)
        isHighPriority = try container.decodeIfPresent(Bool.self, forKey: .isHighPriority) ?? false
        isMediaMessage = try container.decodeIfPresent(Bool.self, forKey: .isMediaMessage) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try id.map { try container.encode($0, forKey: .id) }
        try container.encode(Self.recordType, forKey: .recordType)
        try container.encode(uniqueId, forKey: .uniqueId)

        try container.encode(failureCount, forKey: .failureCount)
        try container.encode(label, forKey: .label)
        try container.encode(status.rawValue, forKey: .status)

        try container.encodeIfPresent(attachmentIdMap, forKey: .attachmentIdMap)
        try container.encodeIfPresent(contactThreadId, forKey: .contactThreadId)
        try container.encodeIfPresent(envelopeData, forKey: .envelopeData)
        try container.encodeIfPresent(invisibleMessage, forKey: .invisibleMessage)
        try container.encodeIfPresent(messageId, forKey: .messageId)
        try container.encode(removeMessageAfterSending, forKey: .removeMessageAfterSending)
        try container.encodeIfPresent(threadId, forKey: .threadId)

        try container.encodeIfPresent(exclusiveProcessIdentifier, forKey: .exclusiveProcessIdentifier)
        try container.encode(isHighPriority, forKey: .isHighPriority)
        try container.encode(isMediaMessage, forKey: .isMediaMessage)
    }

    // MARK: - JobRecordType registry

    /// Fork-specific values start at 1000.
    public enum JobRecordType: UInt, CaseIterable {
        case _reserved = 0
        case reactionSend = 1000
        case gifFavoriteSend = 1001
    }

    public static func concreteType(forRecordType recordType: UInt) -> (any InheritableRecord.Type)? {
        guard let jobRecordType = JobRecordType(rawValue: recordType) else {
            return nil
        }
        switch jobRecordType {
        case ._reserved:
            return nil
        case .reactionSend:
            return ReactionSendJobRecord.self
        case .gifFavoriteSend:
            return DTGifFavoriteJobRecord.self
        }
    }

    // MARK: - GRDB integration

    public func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }

    public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - JobRecordType label

extension JobRecord.JobRecordType {
    var jobRecordLabel: String {
        switch self {
        case ._reserved:
            return "_Reserved"
        case .reactionSend:
            return "ReactionSend"
        case .gifFavoriteSend:
            return "GifFavoriteSend"
        }
    }
}

// MARK: - Failure tracking

public extension JobRecord {
    func addFailure(tx: DBWriteTransaction) {
        anyUpdate(transaction: tx) { record in
            record.failureCount += 1
        }
    }
}
