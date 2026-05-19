//
//  MockGroupCryptoService.swift
//  TempTalkTests
//

import Foundation
@testable import Yelling

final class MockGroupCryptoService: GroupCryptoService {

    var generateRGroupResult = Data(repeating: 0xAA, count: 32)
    var deriveKeysResult: GroupKeySet? = GroupKeySet(
        kGroup: Data(repeating: 0x01, count: 32),
        skBind: Data(repeating: 0x02, count: 32),
        pkBind: Data(repeating: 0x03, count: 32),
        pkBindSPKI: "mockPkBindSPKIBase64"
    )
    var encryptGroupNameResult: String? = "encryptedNameBase64"
    var decryptGroupNameResult: String? = "Decrypted Group Name"
    var encryptGroupAvatarResult: String? = "encryptedAvatarBase64"
    var decryptGroupAvatarResult: String? = "{\"serverId\":\"abc\"}"
    var signUidResult: String? = "signatureBase64"
    var verifyUidResult: Bool = true

    private(set) var generateRGroupCallCount = 0
    private(set) var deriveKeysCallCount = 0
    private(set) var encryptNameCallCount = 0
    private(set) var decryptNameCallCount = 0
    private(set) var signUidCallCount = 0
    private(set) var verifyUidCallCount = 0
    private(set) var lastSignedUid: String?
    private(set) var lastVerifiedUid: String?

    func generateRGroup() -> Data {
        generateRGroupCallCount += 1
        return generateRGroupResult
    }

    func deriveKeys(rGroup: Data) -> GroupKeySet? {
        deriveKeysCallCount += 1
        return deriveKeysResult
    }

    func encryptGroupName(kGroup: Data, plainName: String) -> String? {
        encryptNameCallCount += 1
        return encryptGroupNameResult
    }

    func decryptGroupName(kGroup: Data, encryptedName: String) -> String? {
        decryptNameCallCount += 1
        return decryptGroupNameResult
    }

    func encryptGroupAvatar(kGroup: Data, plainAvatar: String) -> String? {
        return encryptGroupAvatarResult
    }

    func decryptGroupAvatar(kGroup: Data, encryptedAvatar: String) -> String? {
        return decryptGroupAvatarResult
    }

    func signUid(skBind: Data, uid: String) -> String? {
        signUidCallCount += 1
        lastSignedUid = uid
        return signUidResult
    }

    func verifyUid(pkBind: Data, uid: String, uidSignature: String) -> Bool {
        verifyUidCallCount += 1
        lastVerifiedUid = uid
        return verifyUidResult
    }
}
