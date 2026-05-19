//
//  GroupCryptoAPITests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class GroupCryptoAPITests: XCTestCase {

    private var sut: MockGroupCryptoAPI!

    override func setUp() {
        super.setUp()
        sut = MockGroupCryptoAPI()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - upgradeToEncrypted

    func test_upgradeToEncrypted_success_recordsCallAndParams() async throws {
        let request = UpgradeGroupCryptoRequest(
            groupCryptoMode: 1,
            encryptedName: "encName",
            encryptedAvatar: "encAvatar",
            groupMemberVerifyPublicKey: "pkBase64",
            memberBindings: [["uid": "+1234", "uidSignature": "sigBase64"]]
        )

        try await sut.upgradeToEncrypted(groupId: "group-123", request: request)

        XCTAssertEqual(sut.upgradeCallCount, 1)
        XCTAssertEqual(sut.lastUpgradeGroupId, "group-123")
        XCTAssertEqual(sut.lastUpgradeRequest?.groupCryptoMode, 1)
        XCTAssertEqual(sut.lastUpgradeRequest?.encryptedName, "encName")
        XCTAssertEqual(sut.lastUpgradeRequest?.encryptedAvatar, "encAvatar")
        XCTAssertEqual(sut.lastUpgradeRequest?.groupMemberVerifyPublicKey, "pkBase64")
        XCTAssertEqual(sut.lastUpgradeRequest?.memberBindings.count, 1)
    }

    func test_upgradeToEncrypted_withNilAvatar() async throws {
        let request = UpgradeGroupCryptoRequest(
            groupCryptoMode: 1,
            encryptedName: "encName",
            encryptedAvatar: nil,
            groupMemberVerifyPublicKey: "pkBase64",
            memberBindings: []
        )

        try await sut.upgradeToEncrypted(groupId: "group-456", request: request)

        XCTAssertNil(sut.lastUpgradeRequest?.encryptedAvatar)
    }

    func test_upgradeToEncrypted_failure_throwsError() async {
        let expectedError = NSError(domain: "test", code: 500)
        sut.upgradeError = expectedError

        let request = UpgradeGroupCryptoRequest(
            groupCryptoMode: 1,
            encryptedName: "enc",
            encryptedAvatar: nil,
            groupMemberVerifyPublicKey: "pk",
            memberBindings: []
        )

        do {
            try await sut.upgradeToEncrypted(groupId: "group-err", request: request)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, 500)
        }
        XCTAssertEqual(sut.upgradeCallCount, 1)
    }

    // MARK: - cryptoDispose

    func test_cryptoDispose_success_recordsCallAndParams() async throws {
        let request = CryptoDisposeRequest(members: ["+1111", "+2222"])

        try await sut.cryptoDispose(groupId: "group-789", request: request)

        XCTAssertEqual(sut.disposeCallCount, 1)
        XCTAssertEqual(sut.lastDisposeGroupId, "group-789")
        XCTAssertEqual(sut.lastDisposeRequest?.members, ["+1111", "+2222"])
    }

    func test_cryptoDispose_failure_throwsError() async {
        let expectedError = NSError(domain: "test", code: 403)
        sut.disposeError = expectedError

        let request = CryptoDisposeRequest(members: ["+3333"])

        do {
            try await sut.cryptoDispose(groupId: "group-err", request: request)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, 403)
        }
        XCTAssertEqual(sut.disposeCallCount, 1)
    }

    // MARK: - reset

    func test_reset_clearsAllState() async throws {
        try await sut.upgradeToEncrypted(
            groupId: "g1",
            request: UpgradeGroupCryptoRequest(
                groupCryptoMode: 1, encryptedName: "n", encryptedAvatar: nil,
                groupMemberVerifyPublicKey: "pk", memberBindings: []
            )
        )
        try await sut.cryptoDispose(groupId: "g2", request: CryptoDisposeRequest(members: ["u1"]))

        sut.reset()

        XCTAssertEqual(sut.upgradeCallCount, 0)
        XCTAssertEqual(sut.disposeCallCount, 0)
        XCTAssertNil(sut.lastUpgradeGroupId)
        XCTAssertNil(sut.lastDisposeGroupId)
    }
}
