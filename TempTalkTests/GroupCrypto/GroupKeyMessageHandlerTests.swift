//
//  DTGroupKeyMessageHandlerTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class DTGroupKeyMessageHandlerTests: XCTestCase {

    private var mockKeyStore: MockGroupCryptoKeyStore!
    private var sut: DTGroupKeyMessageHandler!

    override func setUp() {
        super.setUp()
        mockKeyStore = MockGroupCryptoKeyStore()
        sut = DTGroupKeyMessageHandler(keyStore: mockKeyStore)
    }

    override func tearDown() {
        mockKeyStore = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Shared instance

    func test_sharedInstance_isNotNil() {
        XCTAssertNotNil(DTGroupKeyMessageHandler.shared)
    }

    // MARK: - handleGroupKeyMessage: save path

    func test_handleGroupKeyMessage_newKey_savesToStore() {
        let gidHex = "abcd1234"
        let gidData = Data(hexString: gidHex)!
        let rGroupData = Data([0x01, 0x02, 0x03])
        let rGroupBase64 = rGroupData.base64EncodedString()

        let builder = DSKProtoGroupKeyMessage.builder()
        builder.setGroupID(gidData)
        builder.setGroupRootKey(rGroupData)
        guard let msg = try? builder.build() else {
            XCTFail("Failed to build DSKProtoGroupKeyMessage")
            return
        }

        sut.handleGroupKeyMessage(msg, transaction: FakeWriteTransaction())

        XCTAssertEqual(mockKeyStore.saveCallCount, 1)
        XCTAssertEqual(mockKeyStore.storage[gidHex], rGroupBase64)
    }

    func test_handleGroupKeyMessage_duplicateKey_doesNotOverwrite() {
        let gidHex = "abcd1234"
        let gidData = Data(hexString: gidHex)!
        mockKeyStore.storage[gidHex] = "existingKey"

        let builder = DSKProtoGroupKeyMessage.builder()
        builder.setGroupID(gidData)
        builder.setGroupRootKey(Data([0x99]))
        guard let msg = try? builder.build() else {
            XCTFail("Failed to build DSKProtoGroupKeyMessage")
            return
        }

        sut.handleGroupKeyMessage(msg, transaction: FakeWriteTransaction())

        XCTAssertEqual(mockKeyStore.storage[gidHex], "existingKey")
    }

    // MARK: - handleGroupKeyMessage: missing fields

    func test_handleGroupKeyMessage_missingGroupId_doesNotSave() {
        let builder = DSKProtoGroupKeyMessage.builder()
        builder.setGroupRootKey(Data([0x01]))
        // no setGroupID
        guard let msg = try? builder.build() else {
            // If build fails without groupId, that's also acceptable
            XCTAssertEqual(mockKeyStore.saveCallCount, 0)
            return
        }

        sut.handleGroupKeyMessage(msg, transaction: FakeWriteTransaction())
        // No gid → should not save
        XCTAssertEqual(mockKeyStore.saveCallCount, 0)
    }

    func test_handleGroupKeyMessage_missingRootKey_doesNotSave() {
        let builder = DSKProtoGroupKeyMessage.builder()
        builder.setGroupID(Data([0xAB, 0xCD]))
        // no setGroupRootKey
        guard let msg = try? builder.build() else {
            XCTAssertEqual(mockKeyStore.saveCallCount, 0)
            return
        }

        sut.handleGroupKeyMessage(msg, transaction: FakeWriteTransaction())
        XCTAssertEqual(mockKeyStore.saveCallCount, 0)
    }

    // MARK: - attachRGroupToGroupContext

    func test_attachRGroupToGroupContext_hasKey_setsOnBuilder() {
        let rGroupData = Data([0x01, 0x02, 0x03])
        mockKeyStore.storage["group-xyz"] = rGroupData.base64EncodedString()

        let builder = DSKProtoGroupContext.builder()
        sut.attachRGroupToGroupContext(builder: builder,
                                       gid: "group-xyz",
                                       transaction: FakeReadTransaction())

        let context = try? builder.build()
        XCTAssertTrue(context?.hasGroupRootKey ?? false)
        XCTAssertEqual(context?.groupRootKey, rGroupData)
    }

    func test_attachRGroupToGroupContext_noKey_doesNotSetOnBuilder() {
        let builder = DSKProtoGroupContext.builder()
        sut.attachRGroupToGroupContext(builder: builder,
                                       gid: "no-key-group",
                                       transaction: FakeReadTransaction())

        let context = try? builder.build()
        XCTAssertFalse(context?.hasGroupRootKey ?? true)
    }

    // MARK: - Notification posting

    func test_handleGroupKeyMessage_newKey_postsNotification() {
        let expectation = expectation(forNotification: DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification,
                                      object: nil) { notification in
            let gid = notification.userInfo?[DTGroupCryptoConstants.groupCryptoKeyGidKey] as? String
            return gid == "abcd1234"
        }

        let gidData = Data(hexString: "abcd1234")!
        let builder = DSKProtoGroupKeyMessage.builder()
        builder.setGroupID(gidData)
        builder.setGroupRootKey(Data([0x99]))
        guard let msg = try? builder.build() else {
            XCTFail("Failed to build")
            return
        }

        sut.handleGroupKeyMessage(msg, transaction: FakeWriteTransaction())

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Constants

    func test_constants_values() {
        XCTAssertEqual(DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification.rawValue,
                       "GroupCryptoKeyDidArrive")
        XCTAssertEqual(DTGroupCryptoConstants.groupCryptoKeyGidKey, "gid")
    }
}

// MARK: - Fake Transactions

private final class FakeWriteTransaction: SDSAnyWriteTransaction {}
private final class FakeReadTransaction: SDSAnyReadTransaction {}

// MARK: - Data hex helper

private extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
