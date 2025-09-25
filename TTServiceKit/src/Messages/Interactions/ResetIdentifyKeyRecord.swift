//
//  File.swift
//  TTServiceKit
//
//  Created by Henry on 2025/7/30.
//

import Foundation
import GRDB

@objc
public final class ResetIdentifyKeyRecord: NSObject, SDSCodableModel {
    public static let databaseTableName = "model_ResetIdentifyKeyRecord"
    public static var recordType: UInt { SDSRecordType.resetIdentifyKeyRecord.rawValue }

    public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
        case id
        case recordType
        case uniqueId
        case operatorId
        case resetIdentifyKeyTime
        case isCompleted
        case createdAt
    }

    public var id: Int64?
    @objc
    public let uniqueId: String
    
    @objc
    public let operatorId: String
    @objc
    public var resetIdentifyKeyTime: UInt64
    @objc
    public let isCompleted: Bool
    @objc
    public let createdAt: Date

    @objc
    required public init(operatorId: String, resetIdentifyKeyTime: UInt64, isCompleted: Bool) {
        self.uniqueId = UUID().uuidString
        self.operatorId = operatorId
        self.resetIdentifyKeyTime = resetIdentifyKeyTime
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let decodedRecordType = try container.decode(Int.self, forKey: .recordType)
        owsAssertDebug(decodedRecordType == Self.recordType, "Unexpectedly decoded record with wrong type.")

        id = try container.decodeIfPresent(RowId.self, forKey: .id)
        uniqueId = try container.decode(String.self, forKey: .uniqueId)
        
        operatorId = try container.decode(String.self, forKey: .operatorId)
        resetIdentifyKeyTime = try container.decode(UInt64.self, forKey: .resetIdentifyKeyTime)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try id.map { try container.encode($0, forKey: .id) }
        try container.encode(recordType, forKey: .recordType)
        try container.encode(uniqueId, forKey: .uniqueId)
        
        try container.encode(operatorId, forKey: .operatorId)
        try container.encode(resetIdentifyKeyTime, forKey: .resetIdentifyKeyTime)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdAt, forKey: .createdAt)
    }

    // TODO: Figure out how to avoid having to duplicate this implementation

    @objc
    public func anyInsert(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .insert, transaction: transaction)
    }

    @objc
    public class func anyEnumerate(
        transaction: SDSAnyReadTransaction,
        batched: Bool = false,
        block: @escaping (ResetIdentifyKeyRecord, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        let batchSize = batched ? Batching.kDefaultBatchSize : 0
        anyEnumerate(transaction: transaction, batchSize: batchSize, block: block)
    }
}

