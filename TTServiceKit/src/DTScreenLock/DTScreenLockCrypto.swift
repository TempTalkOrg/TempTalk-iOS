//
//  DTScreenLockCrypto.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import CommonCrypto

@objc
public class DTScreenLockCrypto: NSObject {
    
    @objc
    public func hashPasscode(passcode: String) -> String? {
        if let salt = generateRandomSalt(), let hash = pbkdf2Hash(password: passcode, salt: salt) {
            let saltString = salt.hexadecimalString
            let hashString = hash.hexadecimalString
            return "\(hashString):\(saltString)"
        }
        Logger.error("hashPasscode result empty!")
        return nil
    }
    
    @objc
    public func hashPasscode(passcode: String, salt: String) -> String? {
        
        if salt.isEmpty || passcode.isEmpty {
            Logger.error("salt or passcode is empty!")
            return nil
        }
        
        if let saltData = Data.data(fromHex: salt){
            if saltData.count != 16 {
                Logger.error("valid salt!")
                return nil
            }
            if let hash = pbkdf2Hash(password: passcode, salt: saltData){
                let saltString = salt
                let hashString = hash.hexadecimalString
                return "\(hashString):\(saltString)"
            } else {
                Logger.error("hashPasscode pbkdf2Hash result empty!")
            }
        } else {
            Logger.error("hashPasscode salt fromHex error: \(salt)!")
        }
        return nil
    }
    
    @objc
    public func verifyPasscode(passcode: String, targetHash: String) -> Bool {
        
        if passcode.isEmpty || targetHash.isEmpty {
            Logger.error("passcode or targetHash is empty!")
            return false
        }
        
        let elements = targetHash.components(separatedBy: ":")
        if elements.count != 2 {
            Logger.error("valid targetHash!")
            return false
        }
        
        if let saltString = elements.last, let targetHashPasscode = elements.first, let saltData = Data.data(fromHex: saltString){
            if let hashData = pbkdf2Hash(password: passcode, salt: saltData) {
                let hashString = hashData.hexadecimalString
                return hashString == targetHashPasscode
            } else {
                Logger.error("verifyPasscode pbkdf2Hash result empty!")
            }
        }
        return false
    }
    
    @objc
    public func generateRandomSalt(length: Int = 16) -> Data? {
        var keyData = Data(count: length)
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        return result == errSecSuccess ? keyData : nil
    }
    
    @objc
    public func pbkdf2Hash(password: String, salt: Data, keyLength: Int = Int(CC_SHA256_DIGEST_LENGTH), rounds: Int = 10000) -> Data? {
        var derivedKey = Data(repeating: 0, count: keyLength)
        let derivationStatus = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, password.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress, keyLength)
            }
        }
        return derivationStatus == kCCSuccess ? derivedKey : nil
    }
    
     
    
    
}
