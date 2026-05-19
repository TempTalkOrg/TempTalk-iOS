//
//  GroupNotifyUpgradeHandlerTests.swift
//  TempTalkTests
//
//  Tests for GroupNotifyUpgradeGroupCryptoHandler input validation logic.
//  The handler directly uses SDS database operations, so full integration
//  tests require a real database. These tests validate the guard conditions
//  and data flow using the mock-based DTGroupCryptoManager approach.

import XCTest
@testable import Yelling

final class GroupNotifyUpgradeHandlerTests: XCTestCase {

    // MARK: - DTGroupCryptoManager upgrade flow

    private var mockCrypto: MockGroupCryptoService!
    private var mockKeyStore: MockGroupCryptoKeyStore!
    private var sut: DTGroupCryptoManager!

    override func setUp() {
        super.setUp()
        mockCrypto = MockGroupCryptoService()
        mockKeyStore = MockGroupCryptoKeyStore()
        sut = DTGroupCryptoManager(cryptoService: mockCrypto, keyStore: mockKeyStore)
    }

    override func tearDown() {
        sut = nil
        mockCrypto = nil
        mockKeyStore = nil
        super.tearDown()
    }

    // MARK: - Upgrade preparation tests (same logic handler depends on)

    func test_prepareUpgrade_newGroup_generatesRGroup() {
        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "My Group",
            avatar: nil,
            memberUids: ["+111"],
            transaction: FakeReadTransaction()
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(params?.groupCryptoMode, 1)
        XCTAssertEqual(mockCrypto.generateRGroupCallCount, 1)
    }

    func test_prepareUpgrade_existingKey_reuses() {
        let existing = Data(repeating: 0xEE, count: 32)
        mockKeyStore.storage["g1"] = existing.base64EncodedString()

        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "My Group",
            avatar: "avatar.json",
            memberUids: ["+111", "+222"],
            transaction: FakeReadTransaction()
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(params?.rGroup, existing)
        XCTAssertEqual(mockCrypto.generateRGroupCallCount, 0)
        XCTAssertEqual(params?.memberBindings.count, 2)
    }

    func test_prepareUpgrade_encryptionFail_returnsNil() {
        mockCrypto.encryptGroupNameResult = nil

        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "Fail",
            avatar: nil,
            memberUids: [],
            transaction: FakeReadTransaction()
        )

        XCTAssertNil(params)
    }

    func test_prepareUpgrade_signFail_returnsNil() {
        mockCrypto.signUidResult = nil

        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "Group",
            avatar: nil,
            memberUids: ["+111"],
            transaction: FakeReadTransaction()
        )

        XCTAssertNil(params)
    }

    func test_prepareUpgrade_withAvatar_encryptsBoth() {
        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "Group",
            avatar: "{\"serverId\":\"abc\"}",
            memberUids: ["+111"],
            transaction: FakeReadTransaction()
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(params?.encryptedName, "encryptedNameBase64")
        XCTAssertEqual(params?.encryptedAvatar, "encryptedAvatarBase64")
    }

    func test_prepareUpgrade_avatarEncryptFail_returnsNil() {
        mockCrypto.encryptGroupAvatarResult = nil

        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1",
            groupName: "Group",
            avatar: "{\"id\":\"x\"}",
            memberUids: [],
            transaction: FakeReadTransaction()
        )

        XCTAssertNil(params)
    }

    // MARK: - Post-upgrade key save

    func test_afterUpgrade_saveRGroup_persists() {
        let rGroup = Data(repeating: 0xFF, count: 32)
        let saved = sut.saveRGroupIfNeeded(gid: "g1", rGroup: rGroup, transaction: FakeWriteTransaction())

        XCTAssertTrue(saved)
        XCTAssertEqual(mockKeyStore.storage["g1"], rGroup.base64EncodedString())
    }

    func test_afterUpgrade_duplicateSave_skips() {
        let rGroup = Data(repeating: 0xFF, count: 32)
        sut.saveRGroupIfNeeded(gid: "g1", rGroup: rGroup, transaction: FakeWriteTransaction())
        let saved2 = sut.saveRGroupIfNeeded(gid: "g1", rGroup: Data(repeating: 0x00, count: 32), transaction: FakeWriteTransaction())

        XCTAssertFalse(saved2)
        XCTAssertEqual(mockKeyStore.storage["g1"], rGroup.base64EncodedString())
    }

    // MARK: - isEncryptedGroup after upgrade

    func test_isEncryptedGroup_afterUpgrade_returnsTrue() {
        XCTAssertTrue(sut.isEncryptedGroup(groupCryptoMode: 1))
    }

    func test_isEncryptedGroup_beforeUpgrade_returnsFalse() {
        XCTAssertFalse(sut.isEncryptedGroup(groupCryptoMode: 0))
    }

    // MARK: - System message localization contract

    func test_upgradeSystemMessage_localizationKey_hasValue() {
        let key = "GROUP_CRYPTO_UPGRADE_SYSTEM_MSG"
        let localized = Localized(key)
        XCTAssertFalse(localized.isEmpty)
        XCTAssertNotEqual(localized, key, "Key \(key) is missing a value in Localizable.strings")
    }
}

// MARK: - Fake Transactions

private final class FakeReadTransaction: SDSAnyReadTransaction {}
private final class FakeWriteTransaction: SDSAnyWriteTransaction {}
