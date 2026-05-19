//
//  GroupCryptoKeyStoreTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class GroupCryptoKeyStoreTests: XCTestCase {

    private var sut: MockGroupCryptoKeyStore!

    override func setUp() {
        super.setUp()
        sut = MockGroupCryptoKeyStore()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - fetchRGroup

    func test_fetchRGroup_whenEmpty_returnsNil() {
        // MockGroupCryptoKeyStore doesn't need real transactions for unit tests
        // In integration tests, use SDSDatabaseStorage.shared
        let result = sut.storage["nonexistent-gid"]
        XCTAssertNil(result)
    }

    func test_fetchRGroup_whenExists_returnsValue() {
        sut.storage["group-123"] = "base64EncodedRGroup"

        let result = sut.storage["group-123"]

        XCTAssertEqual(result, "base64EncodedRGroup")
    }

    // MARK: - saveRGroupIfNeeded

    func test_saveRGroupIfNeeded_whenNew_savesAndReturnsTrue() {
        let saved = sut.saveRGroupIfNeeded(gid: "group-123", rGroup: "rGroupBase64", transaction: FakeWriteTransaction())

        XCTAssertTrue(saved)
        XCTAssertEqual(sut.storage["group-123"], "rGroupBase64")
        XCTAssertEqual(sut.saveCallCount, 1)
    }

    func test_saveRGroupIfNeeded_whenAlreadyExists_skipsAndReturnsFalse() {
        sut.storage["group-123"] = "existingRGroup"

        let saved = sut.saveRGroupIfNeeded(gid: "group-123", rGroup: "newRGroup", transaction: FakeWriteTransaction())

        XCTAssertFalse(saved)
        XCTAssertEqual(sut.storage["group-123"], "existingRGroup", "Should not overwrite existing key")
        XCTAssertEqual(sut.saveCallCount, 1)
    }

    func test_saveRGroupIfNeeded_multipleGroups_independent() {
        sut.saveRGroupIfNeeded(gid: "group-1", rGroup: "key1", transaction: FakeWriteTransaction())
        sut.saveRGroupIfNeeded(gid: "group-2", rGroup: "key2", transaction: FakeWriteTransaction())

        XCTAssertEqual(sut.storage.count, 2)
        XCTAssertEqual(sut.storage["group-1"], "key1")
        XCTAssertEqual(sut.storage["group-2"], "key2")
    }

    // MARK: - deleteRGroup

    func test_deleteRGroup_removesKey() {
        sut.storage["group-123"] = "rGroupBase64"

        sut.deleteRGroup(forGid: "group-123", transaction: FakeWriteTransaction())

        XCTAssertNil(sut.storage["group-123"])
        XCTAssertEqual(sut.deleteCallCount, 1)
    }

    func test_deleteRGroup_whenNotExists_noOp() {
        sut.deleteRGroup(forGid: "nonexistent", transaction: FakeWriteTransaction())

        XCTAssertEqual(sut.deleteCallCount, 1)
        XCTAssertTrue(sut.storage.isEmpty)
    }

    // MARK: - idempotency

    func test_saveDeleteSave_worksCorrectly() {
        sut.saveRGroupIfNeeded(gid: "group-1", rGroup: "key1", transaction: FakeWriteTransaction())
        XCTAssertEqual(sut.storage["group-1"], "key1")

        sut.deleteRGroup(forGid: "group-1", transaction: FakeWriteTransaction())
        XCTAssertNil(sut.storage["group-1"])

        let saved = sut.saveRGroupIfNeeded(gid: "group-1", rGroup: "key2", transaction: FakeWriteTransaction())
        XCTAssertTrue(saved)
        XCTAssertEqual(sut.storage["group-1"], "key2")
    }
}

// MARK: - Fake Transaction (for mock tests only)

private final class FakeWriteTransaction: SDSAnyWriteTransaction {
    // SDSAnyWriteTransaction is a class in the project.
    // For pure mock-based tests, the mock store ignores the transaction parameter.
    // Integration tests should use real database transactions.
}
