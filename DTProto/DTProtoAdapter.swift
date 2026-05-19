//
//  DTProtoAdapter.swift
//
//  Created by TempTalkOrg.
//

import Foundation

@objc
public class DTEncryptedMsgResult: NSObject {
    
    @objc
    public let cipherText: Data
    
    @objc
    public let signedEKey: Data
    
    @objc
    public let eKey: Data
    
    @objc
    public let identityKey: Data
    
    @objc
    public let ermKeys: [String: Data]?
    
    
    init(cipherText: Data, signedEKey: Data, eKey: Data, identityKey: Data, ermKeys: [String: Data]?) {
        self.cipherText = cipherText
        self.signedEKey = signedEKey
        self.eKey = eKey
        self.identityKey = identityKey
        self.ermKeys = ermKeys
        super.init()
    }
    
}

@objc
public enum DTIdentityVerifyResult: Int {
    case match = 0
    case cacheOutdated = 1
    case senderKeyUpdated = 2
    case allMismatch = 3
}

@objc
public class DTDecryptedMsgResult: NSObject {

    @objc
    public let plainText: Data

    @objc
    public let identityVerifyResult: DTIdentityVerifyResult

    init(plainText: Data, identityVerifyResult: DTIdentityVerifyResult) {
        self.plainText = plainText
        self.identityVerifyResult = identityVerifyResult
        super.init()
    }

}


@objc
public class DTEncryptedKeyResult: NSObject {

    @objc
    public let mKey: Data

    @objc
    public let eMKeys: [String: Data]

    @objc
    public let eKey: Data

    init(mKey: Data, eMKeys: [String: Data], eKey: Data) {
        self.mKey = mKey
        self.eMKeys = eMKeys
        self.eKey = eKey
        super.init()
    }
}

@objc
public class DTDecryptedKeyResult: NSObject {

    @objc
    public let mKey: Data

    init(mKey: Data) {
        self.mKey = mKey
        super.init()
    }
}

@objc
public class DTDecryptedRtmMsgResult: NSObject {

    @objc
    public let plainText: Data

    @objc
    public let verifiedIdResult: Bool

    init(plainText: Data, verifiedIdResult: Bool) {
        self.plainText = plainText
        self.verifiedIdResult = verifiedIdResult
        super.init()
    }
}

@objc
public class DTEncryptedRtmMsgResult: NSObject {

    @objc
    public let cipherText: Data

    @objc
    public let signature: Data

    init(cipherText: Data, signature: Data) {
        self.cipherText = cipherText
        self.signature = signature
        super.init()
    }
}


@objc
public class DTProtoAdapter: NSObject {

    @objc
    public func decryptMessage(version: Int32, signedEKey: Data, theirIdKey: Data, localTheirIdKey: Data, cachedTheirIdKey: Data?, eKey: Data, localPriKey: Data, ermKey: Data, cipherText: Data) throws -> DTDecryptedMsgResult {
        let cachedKey: [UInt8]? = cachedTheirIdKey?.bytes
        let decryptedMessage = try DtProto(version: version).decryptMessage(signedEKey: signedEKey.bytes, theirIdKey: theirIdKey.bytes, localTheirIdKey: localTheirIdKey.bytes, cachedTheirIdKey: cachedKey, eKey: eKey.bytes, localPriKey: localPriKey.bytes, ermKey: ermKey.bytes, cipherText: cipherText.bytes)

        let verifyResult: DTIdentityVerifyResult
        switch decryptedMessage.identityVerifyResult {
        case .match:
            verifyResult = .match
        case .cacheOutdated:
            verifyResult = .cacheOutdated
        case .senderKeyUpdated:
            verifyResult = .senderKeyUpdated
        case .allMismatch:
            verifyResult = .allMismatch
        }

        return DTDecryptedMsgResult(plainText: decryptedMessage.plainText.data,
                                    identityVerifyResult: verifyResult)
    }

    @objc
    public func encryptMessage(version: Int32, pubIdKey: Data, pubIdKeys: [String: Data], localPriKey: Data, plainText: Data) throws -> DTEncryptedMsgResult {
        let bytesDict = pubIdKeys.mapValues { value in
            value.bytes
        }
        let encryptedMessage = try DtProto(version: version).encryptMessage(pubIdKey: pubIdKey.bytes, pubIdKeys: bytesDict, localPriKey: localPriKey.bytes, plainText: plainText.bytes)

        let bytesErmKeys = encryptedMessage.ermKeys?.mapValues({ value in
            value.data
        })

        return DTEncryptedMsgResult(cipherText: encryptedMessage.cipherText.data,
                                    signedEKey: encryptedMessage.signedEKey.data,
                                    eKey: encryptedMessage.eKey.data,
                                    identityKey: encryptedMessage.identityKey.data,
                                    ermKeys: bytesErmKeys)
    }

    @objc
    public func generateKey(version: Int32) -> Data {
        return DtProto(version: version).generateKey().data
    }

    @objc
    public func decryptKey(version: Int32, eKey: Data, localPriKey: Data, eMKey: Data) throws -> DTDecryptedKeyResult {
        let decryptedKey = try DtProto(version: version).decryptKey(eKey: eKey.bytes, localPriKey: localPriKey.bytes, eMKey: eMKey.bytes)
        return DTDecryptedKeyResult(mKey: decryptedKey.mKey.data)
    }

    @objc
    public func encryptKey(version: Int32, pubIdKeys: [String: Data], mKey: Data?) throws -> DTEncryptedKeyResult {
        let bytesDict = pubIdKeys.mapValues { value in
            value.bytes
        }
        let encryptedKey = try DtProto(version: version).encryptKey(pubIdKeys: bytesDict, mKey: mKey?.bytes)
        let bytesEmKeys = encryptedKey.eMKeys.mapValues { value in
            value.data
        }
        return DTEncryptedKeyResult(mKey: encryptedKey.mKey.data, eMKeys: bytesEmKeys, eKey: encryptedKey.eKey.data)
    }

    @objc
    public func decryptRtmMessage(version: Int32, signature: Data, theirLocalIdKey: Data?, aesKey: Data, cipherText: Data) throws -> DTDecryptedRtmMsgResult {
        let decryptedRtmMessage = try DtProto(version: version).decryptRtmMessage(signature: signature.bytes, theirLocalIdKey: theirLocalIdKey?.bytes, aesKey: aesKey.bytes, cipherText: cipherText.bytes)
        return DTDecryptedRtmMsgResult(plainText: decryptedRtmMessage.plainText.data, verifiedIdResult: decryptedRtmMessage.verifiedIdResult)
    }

    @objc
    public func encryptRtmMessage(version: Int32, aesKey: Data, localPriKey: Data, plainText: Data) throws -> DTEncryptedRtmMsgResult {
        let encryptRtmMessage = try DtProto(version: version).encryptRtmMessage(aesKey: aesKey.bytes, localPriKey: localPriKey.bytes, plainText: plainText.bytes)
        return DTEncryptedRtmMsgResult(cipherText: encryptRtmMessage.cipherText.data, signature: encryptRtmMessage.signature.data)
    }
}

// MARK: - Group Crypto

@objc
public class DTGroupKeySetResult: NSObject {

    @objc
    public let kGroup: Data

    @objc
    public let skBind: Data

    @objc
    public let pkBind: Data

    init(kGroup: Data, skBind: Data, pkBind: Data) {
        self.kGroup = kGroup
        self.skBind = skBind
        self.pkBind = pkBind
        super.init()
    }
}

extension DTProtoAdapter {

    @objc
    public func groupCryptoDeriveKeys(version: UInt8, rGroup: Data) throws -> DTGroupKeySetResult {
        let gc = DtGroupCrypto(version: version)
        let keys = try gc.deriveKeys(rGroup: rGroup.bytes)
        return DTGroupKeySetResult(kGroup: keys.kGroup.data,
                                   skBind: keys.skBind.data,
                                   pkBind: keys.pkBind.data)
    }

    @objc
    public func groupCryptoEncrypt(version: UInt8, kGroup: Data, plaintext: Data, aad: Data) throws -> Data {
        let gc = DtGroupCrypto(version: version)
        let blob = try gc.encrypt(kGroup: kGroup.bytes, plaintext: plaintext.bytes, aad: aad.bytes)
        return blob.data
    }

    @objc
    public func groupCryptoDecrypt(version: UInt8, kGroup: Data, blob: Data, aad: Data) throws -> Data {
        let gc = DtGroupCrypto(version: version)
        let plaintext = try gc.decrypt(kGroup: kGroup.bytes, blob: blob.bytes, aad: aad.bytes)
        return plaintext.data
    }

    @objc
    public func groupCryptoSignUid(version: UInt8, skBind: Data, uid: String) throws -> Data {
        let gc = DtGroupCrypto(version: version)
        let signature = try gc.signUid(skBind: skBind.bytes, uid: uid)
        return signature.data
    }

    @objc
    public func groupCryptoVerifyUid(version: UInt8, pkBind: Data, uid: String, signature: Data) throws -> NSNumber {
        let gc = DtGroupCrypto(version: version)
        let result = try gc.verifyUid(pkBind: pkBind.bytes, uid: uid, signature: signature.bytes)
        return NSNumber(value: result)
    }
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}
