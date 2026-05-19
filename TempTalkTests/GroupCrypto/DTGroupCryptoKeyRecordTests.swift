//
//  DTGroupCryptoKeyRecordTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class DTGroupCryptoKeyRecordTests: XCTestCase {

    // MARK: - Init

    func test_init_setsUniqueIdToGid() {
        let record = DTGroupCryptoKeyRecord(gid: "group-abc", rGroup: "base64Key")

        XCTAssertEqual(record.uniqueId, "group-abc")
        XCTAssertEqual(record.gid, "group-abc")
        XCTAssertEqual(record.rGroup, "base64Key")
        XCTAssertNil(record.id)
    }

    func test_init_differentGids_produceDifferentUniqueIds() {
        let r1 = DTGroupCryptoKeyRecord(gid: "group-1", rGroup: "key1")
        let r2 = DTGroupCryptoKeyRecord(gid: "group-2", rGroup: "key2")

        XCTAssertNotEqual(r1.uniqueId, r2.uniqueId)
    }

    // MARK: - Codable round-trip

    func test_codable_roundTrip() throws {
        let original = DTGroupCryptoKeyRecord(gid: "group-rt", rGroup: "roundTripKey")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DTGroupCryptoKeyRecord.self, from: data)

        XCTAssertEqual(decoded.gid, original.gid)
        XCTAssertEqual(decoded.rGroup, original.rGroup)
        XCTAssertEqual(decoded.uniqueId, original.uniqueId)
    }

    // MARK: - RecordType

    func test_recordType_matchesSDSRecordType() {
        XCTAssertEqual(DTGroupCryptoKeyRecord.recordType, SDSRecordType.groupCryptoKeyRecord.rawValue)
    }

    func test_databaseTableName() {
        XCTAssertEqual(DTGroupCryptoKeyRecord.databaseTableName, "model_DTGroupCryptoKeyRecord")
    }
}
