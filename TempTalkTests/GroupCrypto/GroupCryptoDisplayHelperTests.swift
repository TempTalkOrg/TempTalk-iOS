//
//  DTGroupCryptoDisplayHelperTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class DTGroupCryptoDisplayHelperTests: XCTestCase {

    private var mockManager: MockGroupCryptoManaging!
    private var sut: DTGroupCryptoDisplayHelper!

    override func setUp() {
        super.setUp()
        mockManager = MockGroupCryptoManaging()
        sut = DTGroupCryptoDisplayHelper(manager: mockManager)
    }

    override func tearDown() {
        mockManager = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - isEncryptedGroup

    func test_isEncryptedGroup_mode0_returnsFalse() {
        XCTAssertFalse(sut.isEncryptedGroup(0))
    }

    func test_isEncryptedGroup_mode1_returnsTrue() {
        XCTAssertTrue(sut.isEncryptedGroup(1))
    }

    func test_isEncryptedGroup_modeNegative_returnsFalse() {
        XCTAssertFalse(sut.isEncryptedGroup(-1))
    }

    // MARK: - displayGroupName (normal group)

    func test_displayGroupName_normalGroup_returnsOriginalName() {
        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 0,
                                          encryptedName: nil,
                                          originalName: "Team Chat",
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, "Team Chat")
        XCTAssertEqual(mockManager.decryptedNameCallCount, 0)
    }

    func test_displayGroupName_normalGroup_nilOriginal_returnsEmpty() {
        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 0,
                                          encryptedName: nil,
                                          originalName: nil,
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, "")
    }

    // MARK: - displayGroupName (encrypted group)

    func test_displayGroupName_encrypted_withDecryptedResult_returnsDecrypted() {
        mockManager.stubbedDecryptedName = "Decrypted Team"

        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 1,
                                          encryptedName: "blob",
                                          originalName: "fallback",
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, "Decrypted Team")
        XCTAssertEqual(mockManager.decryptedNameCallCount, 1)
    }

    func test_displayGroupName_encrypted_noKey_returnsPlaceholder() {
        mockManager.stubbedDecryptedName = nil

        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 1,
                                          encryptedName: "blob",
                                          originalName: "fallback",
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder)
    }

    func test_displayGroupName_encrypted_emptyDecrypted_returnsPlaceholder() {
        mockManager.stubbedDecryptedName = ""

        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 1,
                                          encryptedName: "blob",
                                          originalName: nil,
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder)
    }

    // MARK: - hasGroupKey

    func test_hasGroupKey_delegatesToManager() {
        mockManager.stubbedHasRGroup = true

        XCTAssertTrue(sut.hasGroupKey(gid: "g1", transaction: FakeReadTransaction()))
        XCTAssertEqual(mockManager.hasRGroupCallCount, 1)
    }

    // MARK: - displayGroupName edge cases

    func test_displayGroupName_encrypted_nilEncryptedName_returnsPlaceholder() {
        mockManager.stubbedDecryptedName = nil

        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 1,
                                          encryptedName: nil,
                                          originalName: "fallback",
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder)
    }

    func test_displayGroupName_encrypted_emptyEncryptedName_returnsPlaceholder() {
        mockManager.stubbedDecryptedName = nil

        let result = sut.displayGroupName(gid: "g1",
                                          groupCryptoMode: 1,
                                          encryptedName: "",
                                          originalName: nil,
                                          transaction: FakeReadTransaction())

        XCTAssertEqual(result, DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder)
    }

    // MARK: - Placeholder constants

    func test_placeholderConstants_notEmpty() {
        XCTAssertFalse(DTGroupCryptoDisplayHelper.encryptedGroupNamePlaceholder.isEmpty)
    }

    // MARK: - Shared instance

    func test_sharedInstance_isNotNil() {
        XCTAssertNotNil(DTGroupCryptoDisplayHelper.shared)
    }
}

// MARK: - Fake Transaction

private final class FakeReadTransaction: SDSAnyReadTransaction {}
