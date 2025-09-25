//
//  DTRSA.swift
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/22.
//

import Foundation

public enum DTDBKeyCipherError: Error {
    case emptyPublicKey(description: String)
    case emptyPrivatekey(description: String)
    case invalidCipherText(description: String)
    case invalidSignatureText(description: String)
    case emptyPublicKeyData(description: String)
    case emptyKeyEntity(description: String)
}

@objc
public class DTDBKeyCipher: NSObject {
    
    private static let keyServiceName: String = "DTDBKeyRelatedService"
    private static let dbKeyEntityKeyName: String = "dbKeyEntity"
    
    public var privateKey: SecKey?
    
    public var publicKey: SecKey?
    
    public var publicKeyData: Data?
    
    private static func data(forService service: String, key: String) throws -> Data? {
        
        var data: Data?
        do {
            data = try CurrentAppContext().keychainStorage().data(forService: service, key: key)
        } catch KeychainStorageError.missing {
            Logger.info("missing \(key)")
        } catch {
            throw error
        }
        
        return data
    }
    
    static func keyEntity() throws -> DTDBKeyEntity? {
        guard let keyData = try Self.data(forService: keyServiceName, key: dbKeyEntityKeyName) else {
            return nil
        }
        
        return try JSONDecoder().decode(DTDBKeyEntity.self,from:keyData)
    }
    
    @objc
    public static func clearAll() throws -> Void {
        Logger.info("DTDBKeyCipher clearAll.")
        try CurrentAppContext().keychainStorage().remove(service: keyServiceName, key: dbKeyEntityKeyName)
    }
    
    public static func canLoadKeys() throws -> Bool {
        guard let keyEntity = try self.keyEntity() else {
            return false
        }
        return !keyEntity.privateKey.isEmpty && !keyEntity.publicKey.isEmpty
    }
    
    @objc
    public static func registered() -> Bool {
        do {
            guard let keyEntity = try self.keyEntity() else {
                return false
            }
            return keyEntity.registerFlag
            
        } catch {
            owsFail("get registered error: \(error)")
        }
        
    }
    
    @objc
    public static func rekeyFlag() -> Bool {
        do {
            guard let keyEntity = try self.keyEntity() else {
                return false
            }
            return keyEntity.rekeyFlag
        
        } catch {
            owsFail("get registered error: \(error)")
        }
    }
    
    public static func privateKeyData() throws -> Data {
        guard let keyEntity = try Self.keyEntity() else {
            throw DTDBKeyCipherError.emptyKeyEntity(description: "KeyEntity is empty!")
        }
        guard let privateKeyData = Data(base64Encoded: keyEntity.privateKey) else {
            throw DTDBKeyCipherError.emptyPrivatekey(description: "privateKeyData is empty!")
        }
        return privateKeyData
    }
    
    public static func publicKeyData() throws -> Data {
        guard let keyEntity = try Self.keyEntity() else {
            throw DTDBKeyCipherError.emptyKeyEntity(description: "KeyEntity is empty!")
        }
        guard let publicKeyData = Data(base64Encoded: keyEntity.publicKey) else {
            throw DTDBKeyCipherError.emptyPrivatekey(description: "publicKeyData is empty!")
        }
        return publicKeyData
    }
    
    
    @objc
    public static func markAsRegistered() throws -> Void {
        guard var keyEntity = try self.keyEntity() else {
            throw DTDBKeyCipherError.emptyKeyEntity(description: "KeyEntity is empty!")
        }
        keyEntity.registerFlag = true
        let encodedData = try JSONEncoder().encode(keyEntity)
        try CurrentAppContext().keychainStorage().set(data: encodedData, service: keyServiceName, key: dbKeyEntityKeyName)
    }
    
    @objc
    public static func markRekeyFlag() throws -> Void {
        guard var keyEntity = try self.keyEntity() else {
            throw DTDBKeyCipherError.emptyKeyEntity(description: "KeyEntity is empty!")
        }
        keyEntity.rekeyFlag = true
        let encodedData = try JSONEncoder().encode(keyEntity)
        try CurrentAppContext().keychainStorage().set(data: encodedData, service: keyServiceName, key: dbKeyEntityKeyName)
    }
    
    @objc
    public func generateAndStoreKeypair() throws -> Void {
        var error: Unmanaged<CFError>?
        
        let cipherAttributes: [String: Any] =
            [kSecAttrKeyType as String:            kSecAttrKeyTypeRSA,
             kSecAttrKeySizeInBits as String:      "4096",
        ]

        // Generate PrivateKey / Keypair
        guard let privateKey = SecKeyCreateRandomKey(cipherAttributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        self.privateKey = privateKey
        
        // Extract PrivateKey
        guard let privateKeyOptional = SecKeyCopyExternalRepresentation(privateKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        let privateKeyData = privateKeyOptional as Data
        

        // Extract PublicKey
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyOptional = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        self.publicKey = publicKey
        let publicKeyData = publicKeyOptional as Data
        
        let dbkeyEntity = DTDBKeyEntity(privateKey: privateKeyData.base64EncodedString(), publicKey: publicKeyData.base64EncodedString(), registerFlag: false, rekeyFlag: false)
        let encodedData = try JSONEncoder().encode(dbkeyEntity)
        try CurrentAppContext().keychainStorage().set(data: encodedData, service: DTDBKeyCipher.keyServiceName, key: DTDBKeyCipher.dbKeyEntityKeyName)
        
        self.publicKeyData = publicKeyData
        
    }
    
    @objc
    public func encryptData(plainTextData: Data) throws -> String {
        
        guard let publicKey = self.publicKey else {
            throw DTDBKeyCipherError.emptyPublicKey(description: "Public key is empty!")
        }
        
        var error: Unmanaged<CFError>?
        guard let cipherText = SecKeyCreateEncryptedData(publicKey,
                                                         SecKeyAlgorithm.rsaEncryptionOAEPSHA256,
                                                         plainTextData as CFData,
                                                         &error) as Data? else {
                                                            throw error!.takeRetainedValue() as Error
        }
        
        return cipherText.base64EncodedString()
    }
    
    @objc
    public func decryptData(cipherText: String) throws -> Data {
        
        if self.privateKey == nil {
            let privateKeyData = try Self.privateKeyData()
            var error: Unmanaged<CFError>?
            let cipherAttributes: [String: Any] =
                [kSecAttrKeyType as String:            kSecAttrKeyTypeRSA,
                 kSecAttrKeyClass as String:           kSecAttrKeyClassPrivate,
                 kSecAttrKeySizeInBits as String:      "4096"
            ]
            self.privateKey = SecKeyCreateWithData(privateKeyData as CFData, cipherAttributes as CFDictionary, &error)
            if error != nil {
                Logger.error("create privateKey error: \(String(describing: error))")
            }
        }
        
        guard let privateKey = self.privateKey else {
            throw DTDBKeyCipherError.emptyPrivatekey(description: "Private key is empty!")
        }
        
        guard let cipherTextData = Data(base64Encoded: cipherText) else {
            throw DTDBKeyCipherError.invalidCipherText(description: "parse cipherText error!")
        }
        
        var error: Unmanaged<CFError>?
        guard let clearText = SecKeyCreateDecryptedData(privateKey,
                                                        SecKeyAlgorithm.rsaEncryptionOAEPSHA256,
                                                        cipherTextData as CFData,
                                                        &error) as Data? else {
                                                            throw error!.takeRetainedValue() as Error
        }
        
        return clearText
    }
    
    @objc
    public func signatureData(text: String) throws -> String {
        
        if self.privateKey == nil {
            let privateKeyData = try Self.privateKeyData()
            var error: Unmanaged<CFError>?
            let cipherAttributes: [String: Any] =
                [kSecAttrKeyType as String:            kSecAttrKeyTypeRSA,
                 kSecAttrKeyClass as String:           kSecAttrKeyClassPrivate,
                 kSecAttrKeySizeInBits as String:      "4096"
            ]
            self.privateKey = SecKeyCreateWithData(privateKeyData as CFData, cipherAttributes as CFDictionary, &error)
            if error != nil {
                Logger.error("create privateKey error: \(String(describing: error))")
            }
        }
        
        guard let privateKey = self.privateKey else {
            throw DTDBKeyCipherError.emptyPrivatekey(description: "Private key is empty!")
        }
        
        guard let textData = text.data(using: .utf8) else {
            throw DTDBKeyCipherError.invalidSignatureText(description: "textData is empty!")
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey,
                                                    SecKeyAlgorithm.rsaSignatureMessagePSSSHA256,
                                                    textData as CFData,
                                                    &error) as Data? else {
                                                        throw error!.takeRetainedValue() as Error
        }
        
        return signature.base64EncodedString()
    }
    
    @objc
    public func publicKeyPemContent() throws -> String {
        
        if self.publicKeyData == nil {
            self.publicKeyData = try Self.publicKeyData()
        }
        
        guard let publicKeyData = self.publicKeyData else {
            throw DTDBKeyCipherError.emptyPublicKeyData(description: "Public key data is empty!")
        }
        return "-----BEGIN RSA PUBLIC KEY-----\n" + publicKeyData.base64EncodedString() + "\n-----END RSA PUBLIC KEY-----"
    }
    
    
}
