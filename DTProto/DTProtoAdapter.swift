//
//  DTProtoAdapter.swift
//
//  Created by Kris.s on 2023/5/22.
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
public class DTDecryptedMsgResult: NSObject {
    
    @objc
    public let plainText: Data
    
    @objc
    public let verifiedIDResult: Bool
    
    init(plainText: Data, verifiedIDResult: Bool) {
        self.plainText = plainText
        self.verifiedIDResult = verifiedIDResult
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
    }
}

@objc
public class DTEncryptedRtmMsgResult: NSObject {
    
    @objc
    public let cipherText: Data
    
    @objc
    public let signature: Data

    public init(cipherText: Data, signature: Data) {
        self.cipherText = cipherText
        self.signature = signature
    }
}


@objc
public class DTProtoAdapter: NSObject {
    
    @objc
    public func decryptMessage(version: Int32, signedEKey: Data, theirIdKey: Data, localTheirIdKey: Data, eKey: Data, localPriKey: Data, ermKey: Data, cipherText: Data) throws -> DTDecryptedMsgResult {
        let decryptedMessage = try DtProto(version: version).decryptMessage(signedEKey: signedEKey.bytes, theirIdKey: theirIdKey.bytes, localTheirIdKey: localTheirIdKey.bytes, eKey: eKey.bytes, localPriKey: localPriKey.bytes, ermKey: ermKey.bytes, cipherText: cipherText.bytes)
        return DTDecryptedMsgResult.init(plainText: decryptedMessage.plainText.data,
                                         verifiedIDResult: decryptedMessage.verifiedIdResult)
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
        
        return DTEncryptedMsgResult.init(cipherText: encryptedMessage.cipherText.data,
                                         signedEKey: encryptedMessage.signedEKey.data,
                                         eKey: encryptedMessage.eKey.data,
                                         identityKey: encryptedMessage.identityKey.data,
                                         ermKeys: bytesErmKeys)
        
    }
    
    @objc public func generateKey(version: Int32) -> Data {
        let new_key = DtProto(version: version).generateKey()
        return new_key.data
    }
    
    @objc public func decryptKey(version: Int32, eKey: Data, localPriKey: Data, eMKey: Data) throws -> DTDecryptedKeyResult {
        let decryptedKey = try DtProto(version: version).decryptKey(eKey: eKey.bytes, localPriKey: localPriKey.bytes, eMKey: eMKey.bytes)
        return DTDecryptedKeyResult.init(mKey: decryptedKey.mKey.data)
    }
    
    @objc public func encryptKey(version: Int32, pubIdKeys: [String: Data], mKey: Data?) throws -> DTEncryptedKeyResult {
        
        let bytesDict = pubIdKeys.mapValues { value in
            value.bytes
        }
        let encryptedKey = try DtProto(version: version).encryptKey(pubIdKeys: bytesDict, mKey: mKey?.bytes)
        let bytesEmKeys = encryptedKey.eMKeys.mapValues({ value in
            value.data
        })
        return DTEncryptedKeyResult.init(mKey: encryptedKey.mKey.data, eMKeys: bytesEmKeys, eKey: encryptedKey.eKey.data)
        
    }
    
    @objc public func decryptRtmMessage(version: Int32, signature: Data, theirLocalIdKey: Data?, aesKey: Data, cipherText: Data) throws -> DTDecryptedRtmMsgResult {
        let decryptedRtmMessage = try DtProto(version: version).decryptRtmMessage(signature: signature.bytes, theirLocalIdKey: theirLocalIdKey?.bytes, aesKey: aesKey.bytes, cipherText: cipherText.bytes)
        return DTDecryptedRtmMsgResult.init(plainText: decryptedRtmMessage.plainText.data, verifiedIdResult: decryptedRtmMessage.verifiedIdResult)
    }
    
    @objc public func encryptRtmMessage(version: Int32, aesKey: Data, localPriKey: Data, plainText: Data) throws -> DTEncryptedRtmMsgResult {
        let encryptRtmMessage = try DtProto(version: version).encryptRtmMessage(aesKey: aesKey.bytes, localPriKey: localPriKey.bytes, plainText: plainText.bytes)
        return DTEncryptedRtmMsgResult.init(cipherText: encryptRtmMessage.cipherText.data, signature: encryptRtmMessage.signature.data)
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
