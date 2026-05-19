//
//  DTGroupCryptoKeyRecord.swift
//  TTServiceKit
//

import Foundation
import GRDB

// MARK: - Protocol

public protocol GroupCryptoKeyStore {
    func fetchRGroup(forGid gid: String, transaction: SDSAnyReadTransaction) -> String?
    @discardableResult
    func saveRGroupIfNeeded(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) -> Bool
    func updateRGroup(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction)
    func deleteRGroup(forGid gid: String, transaction: SDSAnyWriteTransaction)
}

// MARK: - Record

@objc
public final class DTGroupCryptoKeyRecord: NSObject, SDSCodableModel {

    public static let databaseTableName = "model_DTGroupCryptoKeyRecord"
    public static var recordType: UInt { SDSRecordType.groupCryptoKeyRecord.rawValue }

    public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
        case id
        case recordType
        case uniqueId
        case gid
        case rGroup
    }

    public var id: Int64?

    @objc
    public let uniqueId: String

    @objc
    public let gid: String

    @objc
    public let rGroup: String

    @objc
    public init(gid: String, rGroup: String) {
        self.uniqueId = gid
        self.gid = gid
        self.rGroup = rGroup
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedRecordType = try container.decode(Int.self, forKey: .recordType)
        owsAssertDebug(decodedRecordType == Self.recordType, "Unexpectedly decoded record with wrong type.")

        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        uniqueId = try container.decode(String.self, forKey: .uniqueId)
        gid = try container.decode(String.self, forKey: .gid)
        rGroup = try container.decode(String.self, forKey: .rGroup)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try id.map { try container.encode($0, forKey: .id) }
        try container.encode(recordType, forKey: .recordType)
        try container.encode(uniqueId, forKey: .uniqueId)
        try container.encode(gid, forKey: .gid)
        try container.encode(rGroup, forKey: .rGroup)
    }

    // MARK: - CRUD

    @objc
    public func anyInsert(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .insert, transaction: transaction)
    }

    @objc
    public func anyUpsert(transaction: SDSAnyWriteTransaction) {
        if Self.anyFetch(uniqueId: gid, transaction: transaction) != nil {
            sdsSave(saveMode: .update, transaction: transaction)
        } else {
            sdsSave(saveMode: .insert, transaction: transaction)
        }
    }

    @objc
    public class func fetch(forGid gid: String, transaction: SDSAnyReadTransaction) -> DTGroupCryptoKeyRecord? {
        anyFetch(uniqueId: gid, transaction: transaction)
    }

    @objc
    public class func delete(forGid gid: String, transaction: SDSAnyWriteTransaction) {
        guard let record = anyFetch(uniqueId: gid, transaction: transaction) else { return }
        record.anyRemove(transaction: transaction)
    }
}

// MARK: - Default Store Implementation

public final class DTGroupCryptoKeyStoreImpl: GroupCryptoKeyStore {

    public init() {}

    public func fetchRGroup(forGid gid: String, transaction: SDSAnyReadTransaction) -> String? {
        DTGroupCryptoKeyRecord.fetch(forGid: gid, transaction: transaction)?.rGroup
    }

    @discardableResult
    public func saveRGroupIfNeeded(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) -> Bool {
        if DTGroupCryptoKeyRecord.fetch(forGid: gid, transaction: transaction) != nil {
            return false
        }
        let record = DTGroupCryptoKeyRecord(gid: gid, rGroup: rGroup)
        record.anyInsert(transaction: transaction)
        Logger.info("[GroupCrypto] R_group saved (first time), gid: \(gid)")
        return true
    }

    public func updateRGroup(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) {
        let record = DTGroupCryptoKeyRecord(gid: gid, rGroup: rGroup)
        record.anyUpsert(transaction: transaction)
        Logger.info("[GroupCrypto] R_group upserted, gid: \(gid)")
    }

    public func deleteRGroup(forGid gid: String, transaction: SDSAnyWriteTransaction) {
        let existed = DTGroupCryptoKeyRecord.fetch(forGid: gid, transaction: transaction) != nil
        DTGroupCryptoKeyRecord.delete(forGid: gid, transaction: transaction)
        Logger.info("[GroupCrypto] deleteRGroup gid: \(gid), existed: \(existed)")
    }
}
