//
//  DTGroupCryptoKeyRecord.swift
//  TTServiceKit
//

import Foundation
import GRDB

// MARK: - Rotate Outcome

/// Result of routing an incoming R_group through the version-aware write funnel.
@objc public enum DTGroupKeyRotateOutcome: Int {
    case inserted  // no local key before (all-lost / freshly joined)
    case rotated   // a higher-version key replaced the local one
    case skipped   // version <= local; ignored to block old-key reflood
}

// MARK: - Protocol

public protocol GroupCryptoKeyStore {
    func fetchRGroup(forGid gid: String, transaction: SDSAnyReadTransaction) -> String?
    func fetchKeyVersion(forGid gid: String, transaction: SDSAnyReadTransaction) -> Int
    @discardableResult
    func saveRGroupIfNeeded(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) -> Bool
    func updateRGroup(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction)
    /// Version-aware funnel: insert when absent, overwrite when version is higher, skip otherwise.
    @discardableResult
    func saveOrRotateRGroup(gid: String, rGroup: String, version: Int, transaction: SDSAnyWriteTransaction) -> DTGroupKeyRotateOutcome
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
        case keyVersion
    }

    public var id: Int64?

    @objc
    public let uniqueId: String

    @objc
    public let gid: String

    @objc
    public let rGroup: String

    /// Monotonic crypto key version. Baseline 0 = original/never-rotated.
    @objc
    public let keyVersion: Int

    @objc
    public init(gid: String, rGroup: String, keyVersion: Int = 0) {
        self.uniqueId = gid
        self.gid = gid
        self.rGroup = rGroup
        self.keyVersion = keyVersion
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
        keyVersion = try container.decodeIfPresent(Int.self, forKey: .keyVersion) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try id.map { try container.encode($0, forKey: .id) }
        try container.encode(recordType, forKey: .recordType)
        try container.encode(uniqueId, forKey: .uniqueId)
        try container.encode(gid, forKey: .gid)
        try container.encode(rGroup, forKey: .rGroup)
        try container.encode(keyVersion, forKey: .keyVersion)
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

    public func fetchKeyVersion(forGid gid: String, transaction: SDSAnyReadTransaction) -> Int {
        DTGroupCryptoKeyRecord.fetch(forGid: gid, transaction: transaction)?.keyVersion ?? 0
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

    @discardableResult
    public func saveOrRotateRGroup(gid: String, rGroup: String, version: Int, transaction: SDSAnyWriteTransaction) -> DTGroupKeyRotateOutcome {
        guard let existing = DTGroupCryptoKeyRecord.fetch(forGid: gid, transaction: transaction) else {
            DTGroupCryptoKeyRecord(gid: gid, rGroup: rGroup, keyVersion: version).anyInsert(transaction: transaction)
            Logger.info("[GroupCrypto] R_group inserted, gid: \(gid), version: \(version)")
            return .inserted
        }
        // Missing/absent version maps to 0; only a strictly higher version overwrites.
        guard version > existing.keyVersion else {
            Logger.info("[GroupCrypto] R_group skip stale key, gid: \(gid), incoming: \(version), local: \(existing.keyVersion)")
            return .skipped
        }
        DTGroupCryptoKeyRecord(gid: gid, rGroup: rGroup, keyVersion: version).anyUpsert(transaction: transaction)
        Logger.info("[GroupCrypto] R_group rotated, gid: \(gid), \(existing.keyVersion) -> \(version)")
        return .rotated
    }

    public func deleteRGroup(forGid gid: String, transaction: SDSAnyWriteTransaction) {
        DTGroupCryptoKeyRecord.delete(forGid: gid, transaction: transaction)
    }
}
