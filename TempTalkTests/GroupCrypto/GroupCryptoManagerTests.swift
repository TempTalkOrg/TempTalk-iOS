//
//  DTGroupCryptoManagerTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class DTGroupCryptoManagerTests: XCTestCase {

    private var sut: DTGroupCryptoManager!
    private var mockCrypto: MockGroupCryptoService!
    private var mockKeyStore: MockGroupCryptoKeyStore!

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

    // MARK: - isEncryptedGroup

    func test_isEncryptedGroup_zero_returnsFalse() {
        XCTAssertFalse(sut.isEncryptedGroup(groupCryptoMode: 0))
    }

    func test_isEncryptedGroup_positive_returnsTrue() {
        XCTAssertTrue(sut.isEncryptedGroup(groupCryptoMode: 1))
        XCTAssertTrue(sut.isEncryptedGroup(groupCryptoMode: 2))
    }

    // MARK: - hasRGroup

    func test_hasRGroup_whenNoKey_returnsFalse() {
        let result = sut.hasRGroup(gid: "group-1", transaction: FakeReadTransaction())
        XCTAssertFalse(result)
    }

    func test_hasRGroup_whenKeyExists_returnsTrue() {
        let rGroupBase64 = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockKeyStore.storage["group-1"] = rGroupBase64

        let result = sut.hasRGroup(gid: "group-1", transaction: FakeReadTransaction())
        XCTAssertTrue(result)
    }

    // MARK: - decryptedGroupName

    func test_decryptedGroupName_noEncryptedName_returnsNil() {
        let result = sut.decryptedGroupName(gid: "g1", encryptedName: nil, transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_decryptedGroupName_emptyString_returnsNil() {
        let result = sut.decryptedGroupName(gid: "g1", encryptedName: "", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_decryptedGroupName_noRGroup_returnsNil() {
        let result = sut.decryptedGroupName(gid: "g1", encryptedName: "enc", transaction: FakeReadTransaction())
        XCTAssertNil(result)
        XCTAssertEqual(mockCrypto.decryptNameCallCount, 0)
    }

    func test_decryptedGroupName_withKey_returnsDecrypted() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()

        let result = sut.decryptedGroupName(gid: "g1", encryptedName: "enc", transaction: FakeReadTransaction())
        XCTAssertEqual(result, "Decrypted Group Name")
        XCTAssertEqual(mockCrypto.deriveKeysCallCount, 1)
        XCTAssertEqual(mockCrypto.decryptNameCallCount, 1)
    }

    func test_decryptedGroupName_decryptFails_returnsNil() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.decryptGroupNameResult = nil

        let result = sut.decryptedGroupName(gid: "g1", encryptedName: "enc", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    // MARK: - prepareEncryptedGroupCreation

    func test_prepareEncryptedGroupCreation_success() {
        let params = sut.prepareEncryptedGroupCreation(
            groupName: "Test Group",
            avatar: "avatarJson",
            memberUids: ["+111", "+222"]
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(params?.groupCryptoMode, 1)
        XCTAssertEqual(params?.encryptedName, "encryptedNameBase64")
        XCTAssertEqual(params?.encryptedAvatar, "encryptedAvatarBase64")
        XCTAssertEqual(params?.groupMemberVerifyPublicKey, "mockPkBindSPKIBase64")
        XCTAssertEqual(params?.memberBindings.count, 2)
        XCTAssertEqual(mockCrypto.generateRGroupCallCount, 1)
        XCTAssertEqual(mockCrypto.signUidCallCount, 2)
    }

    func test_prepareEncryptedGroupCreation_noAvatar() {
        let params = sut.prepareEncryptedGroupCreation(
            groupName: "No Avatar",
            avatar: nil,
            memberUids: ["+111"]
        )

        XCTAssertNotNil(params)
        XCTAssertNil(params?.encryptedAvatar)
    }

    func test_prepareEncryptedGroupCreation_encryptFails_returnsNil() {
        mockCrypto.encryptGroupNameResult = nil

        let params = sut.prepareEncryptedGroupCreation(
            groupName: "Fail",
            avatar: nil,
            memberUids: ["+111"]
        )
        XCTAssertNil(params)
    }

    func test_prepareEncryptedGroupCreation_signFails_returnsNil() {
        mockCrypto.signUidResult = nil

        let params = sut.prepareEncryptedGroupCreation(
            groupName: "Fail",
            avatar: nil,
            memberUids: ["+111"]
        )
        XCTAssertNil(params)
    }

    // MARK: - prepareMemberBindings

    func test_prepareMemberBindings_noKey_returnsNil() {
        let result = sut.prepareMemberBindings(
            gid: "g1", newMemberUids: ["+333"], transaction: FakeReadTransaction()
        )
        XCTAssertNil(result)
    }

    func test_prepareMemberBindings_withKey_returnsBindings() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()

        let result = sut.prepareMemberBindings(
            gid: "g1", newMemberUids: ["+333", "+444"], transaction: FakeReadTransaction()
        )

        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(mockCrypto.signUidCallCount, 2)
    }

    // MARK: - saveRGroupIfNeeded

    func test_saveRGroupIfNeeded_new_savesBase64() {
        let rGroup = Data(repeating: 0xBB, count: 32)
        let saved = sut.saveRGroupIfNeeded(gid: "g1", rGroup: rGroup, transaction: FakeWriteTransaction())

        XCTAssertTrue(saved)
        XCTAssertEqual(mockKeyStore.storage["g1"], rGroup.base64EncodedString())
    }

    func test_saveRGroupIfNeeded_existing_skips() {
        mockKeyStore.storage["g1"] = "existingKey"
        let rGroup = Data(repeating: 0xBB, count: 32)

        let saved = sut.saveRGroupIfNeeded(gid: "g1", rGroup: rGroup, transaction: FakeWriteTransaction())

        XCTAssertFalse(saved)
        XCTAssertEqual(mockKeyStore.storage["g1"], "existingKey")
    }

    // MARK: - getRGroupData

    func test_getRGroupData_noKey_returnsNil() {
        let result = sut.getRGroupData(gid: "g1", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_getRGroupData_withKey_returnsData() {
        let original = Data(repeating: 0xCC, count: 32)
        mockKeyStore.storage["g1"] = original.base64EncodedString()

        let result = sut.getRGroupData(gid: "g1", transaction: FakeReadTransaction())
        XCTAssertEqual(result, original)
    }

    // MARK: - verifyMember

    func test_verifyMember_noKey_returnsNil() {
        let result = sut.verifyMember(gid: "g1", uid: "+111", uidSignature: "sig", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_verifyMember_valid_returnsTrue() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.verifyUidResult = true

        let result = sut.verifyMember(gid: "g1", uid: "+111", uidSignature: "sig", transaction: FakeReadTransaction())
        XCTAssertEqual(result, true)
    }

    func test_verifyMember_invalid_returnsFalse() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.verifyUidResult = false

        let result = sut.verifyMember(gid: "g1", uid: "+111", uidSignature: "sig", transaction: FakeReadTransaction())
        XCTAssertEqual(result, false)
    }

    // MARK: - prepareUpgradeToEncrypted

    func test_prepareUpgradeToEncrypted_noExistingKey_generatesNew() {
        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1", groupName: "Upgrade", avatar: nil,
            memberUids: ["+111"], transaction: FakeReadTransaction()
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(mockCrypto.generateRGroupCallCount, 1)
    }

    func test_prepareUpgradeToEncrypted_existingKey_reuses() {
        let existing = Data(repeating: 0xDD, count: 32)
        mockKeyStore.storage["g1"] = existing.base64EncodedString()

        let params = sut.prepareUpgradeToEncrypted(
            gid: "g1", groupName: "Upgrade", avatar: nil,
            memberUids: ["+111"], transaction: FakeReadTransaction()
        )

        XCTAssertNotNil(params)
        XCTAssertEqual(params?.rGroup, existing)
        XCTAssertEqual(mockCrypto.generateRGroupCallCount, 0)
    }

    // MARK: - decryptedGroupAvatar

    func test_decryptedGroupAvatar_noEncryptedAvatar_returnsNil() {
        let result = sut.decryptedGroupAvatar(gid: "g1", encryptedAvatar: nil, transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_decryptedGroupAvatar_emptyString_returnsNil() {
        let result = sut.decryptedGroupAvatar(gid: "g1", encryptedAvatar: "", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_decryptedGroupAvatar_noRGroup_returnsNil() {
        let result = sut.decryptedGroupAvatar(gid: "g1", encryptedAvatar: "enc", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_decryptedGroupAvatar_withKey_returnsDecrypted() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.decryptGroupAvatarResult = "{\"serverId\":\"abc\"}"

        let result = sut.decryptedGroupAvatar(gid: "g1", encryptedAvatar: "enc", transaction: FakeReadTransaction())
        XCTAssertEqual(result, "{\"serverId\":\"abc\"}")
    }

    // MARK: - encryptGroupName

    func test_encryptGroupName_noKey_returnsNil() {
        let result = sut.encryptGroupName(gid: "g1", plainName: "Test", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_encryptGroupName_withKey_returnsEncrypted() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.encryptGroupNameResult = "encBlob"

        let result = sut.encryptGroupName(gid: "g1", plainName: "Test", transaction: FakeReadTransaction())
        XCTAssertEqual(result, "encBlob")
        XCTAssertEqual(mockCrypto.encryptNameCallCount, 1)
    }

    // MARK: - encryptGroupAvatar

    func test_encryptGroupAvatar_noKey_returnsNil() {
        let result = sut.encryptGroupAvatar(gid: "g1", plainAvatar: "{}", transaction: FakeReadTransaction())
        XCTAssertNil(result)
    }

    func test_encryptGroupAvatar_withKey_returnsEncrypted() {
        mockKeyStore.storage["g1"] = Data(repeating: 0xAA, count: 32).base64EncodedString()
        mockCrypto.encryptGroupAvatarResult = "encAvatarBlob"

        let result = sut.encryptGroupAvatar(gid: "g1", plainAvatar: "{}", transaction: FakeReadTransaction())
        XCTAssertEqual(result, "encAvatarBlob")
    }

    // MARK: - EncryptedGroupCreationParams

    func test_encryptedGroupCreationParams_asDictionary() {
        let binding = GroupMemberBinding(uid: "+111", uidSignature: "sig1")
        let params = EncryptedGroupCreationParams(
            rGroup: Data(repeating: 0x01, count: 32),
            groupCryptoMode: 1,
            encryptedName: "encName",
            encryptedAvatar: "encAvatar",
            groupMemberVerifyPublicKey: "pkBase64",
            memberBindings: [binding]
        )

        XCTAssertEqual(params.groupCryptoMode, 1)
        XCTAssertEqual(params.encryptedName, "encName")
        XCTAssertEqual(params.encryptedAvatar, "encAvatar")
        XCTAssertEqual(params.groupMemberVerifyPublicKey, "pkBase64")
        XCTAssertEqual(params.memberBindings.count, 1)
        XCTAssertEqual(params.memberBindings[0].asDictionary["uid"], "+111")
        XCTAssertEqual(params.rGroup.count, 32)
    }

    func test_encryptedGroupCreationParams_nilAvatar() {
        let params = EncryptedGroupCreationParams(
            rGroup: Data(),
            groupCryptoMode: 1,
            encryptedName: "enc",
            encryptedAvatar: nil,
            groupMemberVerifyPublicKey: "pk",
            memberBindings: []
        )
        XCTAssertNil(params.encryptedAvatar)
        XCTAssertTrue(params.memberBindings.isEmpty)
    }
}

// MARK: - Fake Transactions

private final class FakeReadTransaction: SDSAnyReadTransaction {}
private final class FakeWriteTransaction: SDSAnyWriteTransaction {}
