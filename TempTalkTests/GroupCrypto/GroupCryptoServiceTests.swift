//
//  GroupCryptoServiceTests.swift
//  TempTalkTests
//

import XCTest
@testable import Yelling

final class GroupCryptoServiceTests: XCTestCase {

    // MARK: - generateRGroup

    func test_generateRGroup_returns32Bytes() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = sut.generateRGroup()
        XCTAssertEqual(rGroup.count, 32)
    }

    func test_generateRGroup_producesUniqueValues() {
        let sut = DTGroupCryptoServiceImpl()
        let r1 = sut.generateRGroup()
        let r2 = sut.generateRGroup()
        XCTAssertNotEqual(r1, r2)
    }

    // MARK: - Protocol conformance

    func test_mock_conforms_to_protocol() {
        let mock = MockGroupCryptoService()
        let _: GroupCryptoService = mock
        XCTAssertNotNil(mock.generateRGroup())
    }

    // MARK: - signMembers extension

    func test_signMembers_success_returnsAllBindings() {
        let mock = MockGroupCryptoService()
        mock.signUidResult = "sig123"

        let bindings = mock.signMembers(skBind: Data(), uids: ["+111", "+222", "+333"])

        XCTAssertEqual(bindings?.count, 3)
        XCTAssertEqual(bindings?[0].uid, "+111")
        XCTAssertEqual(bindings?[0].uidSignature, "sig123")
        XCTAssertEqual(bindings?[2].uid, "+333")
        XCTAssertEqual(mock.signUidCallCount, 3)
    }

    func test_signMembers_oneFails_returnsNil() {
        let mock = MockGroupCryptoService()
        mock.signUidResult = nil

        let bindings = mock.signMembers(skBind: Data(), uids: ["+111"])
        XCTAssertNil(bindings)
    }

    func test_signMembers_emptyUids_returnsEmptyArray() {
        let mock = MockGroupCryptoService()
        let bindings = mock.signMembers(skBind: Data(), uids: [])
        XCTAssertEqual(bindings?.count, 0)
    }

    // MARK: - GroupMemberBinding

    func test_memberBinding_asDictionary() {
        let binding = GroupMemberBinding(uid: "+12345", uidSignature: "sigABC")
        let dict = binding.asDictionary
        XCTAssertEqual(dict["uid"], "+12345")
        XCTAssertEqual(dict["uidSignature"], "sigABC")
    }

    // MARK: - Rust FFI: deriveKeys test vector

    func test_deriveKeys_withTestVector() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = Data(0x00...0x1f)

        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        XCTAssertEqual(keys.kGroup.hexString,
                       "c429ae7559b8f8a480f68e54e0becb5ef22d142e137ab10f4dd535e3a3f777ef")
        XCTAssertEqual(keys.skBind.hexString,
                       "aefb15f01c6e8c5bd3b03a9122a97b8198d69ce6138d833983f4ee46394e786b")
        XCTAssertEqual(keys.pkBind.hexString,
                       "1c37ad97463331dbcfdc44a0697482fdc00e33a6462c362980c1834f5ce16d3d")
    }

    func test_deriveKeys_pkBindSPKI_format() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = Data(0x00...0x1f)

        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        // SPKI = 12-byte Ed25519 header + 32-byte raw pk_bind
        guard let spkiData = Data(base64Encoded: keys.pkBindSPKI) else {
            XCTFail("pkBindSPKI is not valid Base64")
            return
        }
        XCTAssertEqual(spkiData.count, 44) // 12 + 32
        let header = spkiData.prefix(12)
        XCTAssertEqual(header.hexString, "302a300506032b657003210")
        let rawKey = spkiData.suffix(32)
        XCTAssertEqual(rawKey, keys.pkBind)
    }

    // MARK: - Rust FFI: encrypt/decrypt roundtrip

    func test_encryptDecryptGroupName_roundTrip() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = sut.generateRGroup()
        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        let plainName = "Test Group Name 测试群名"
        let encrypted = sut.encryptGroupName(kGroup: keys.kGroup, plainName: plainName)
        XCTAssertNotNil(encrypted)
        XCTAssertNotEqual(encrypted, plainName)

        let decrypted = sut.decryptGroupName(kGroup: keys.kGroup, encryptedName: encrypted!)
        XCTAssertEqual(decrypted, plainName)
    }

    func test_encryptDecryptGroupAvatar_roundTrip() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = sut.generateRGroup()
        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        let plainAvatar = "{\"url\":\"https://example.com/avatar.jpg\"}"
        let encrypted = sut.encryptGroupAvatar(kGroup: keys.kGroup, plainAvatar: plainAvatar)
        XCTAssertNotNil(encrypted)

        let decrypted = sut.decryptGroupAvatar(kGroup: keys.kGroup, encryptedAvatar: encrypted!)
        XCTAssertEqual(decrypted, plainAvatar)
    }

    func test_decryptGroupName_wrongKey_returnsNil() {
        let sut = DTGroupCryptoServiceImpl()
        guard let keys1 = sut.deriveKeys(rGroup: sut.generateRGroup()),
              let keys2 = sut.deriveKeys(rGroup: sut.generateRGroup()) else {
            XCTFail("deriveKeys returned nil")
            return
        }

        let encrypted = sut.encryptGroupName(kGroup: keys1.kGroup, plainName: "secret")
        XCTAssertNotNil(encrypted)

        let decrypted = sut.decryptGroupName(kGroup: keys2.kGroup, encryptedName: encrypted!)
        XCTAssertNil(decrypted)
    }

    // MARK: - Rust FFI: sign/verify roundtrip

    func test_signVerifyUid_roundTrip() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = sut.generateRGroup()
        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        let uid = "user-12345"
        let signature = sut.signUid(skBind: keys.skBind, uid: uid)
        XCTAssertNotNil(signature)

        let isValid = sut.verifyUid(pkBind: keys.pkBind, uid: uid, uidSignature: signature!)
        XCTAssertTrue(isValid)
    }

    func test_signUid_withTestVector() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = Data(0x00...0x1f)
        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        let signature = sut.signUid(skBind: keys.skBind, uid: "test-uid-001")
        XCTAssertNotNil(signature)

        guard let sigData = Data(base64Encoded: signature!) else {
            XCTFail("Signature is not valid Base64")
            return
        }
        XCTAssertEqual(sigData.count, 64)
        XCTAssertEqual(sigData.hexString,
                       "3e6d31fed3bf0bba4d06b4eb10e2de6bb419030b973bf49fd3666ff818cda4c5a42b109a431143a7e2200fb1023b9f6627303ed8ea9391de04cc056201eb8404")
    }

    func test_verifyUid_wrongSignature_returnsFalse() {
        let sut = DTGroupCryptoServiceImpl()
        let rGroup = sut.generateRGroup()
        guard let keys = sut.deriveKeys(rGroup: rGroup) else { XCTFail("deriveKeys returned nil"); return }

        let signature = sut.signUid(skBind: keys.skBind, uid: "user-A")
        XCTAssertNotNil(signature)

        let isValid = sut.verifyUid(pkBind: keys.pkBind, uid: "user-B", uidSignature: signature!)
        XCTAssertFalse(isValid)
    }
}

// MARK: - Test Helpers

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
