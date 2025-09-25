//
//  IdentityKeyHandler.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/11/29.
//

import Foundation


@objc(DTIdentityKeyHandler)
public class IdentityKeyHandler : NSObject {
    
    @objc public static func registerIDKey(success: @escaping () -> Void, failure: @escaping (NSError) -> Void) {
        renewIDKey(oldSignEnable: false, success: success) { error in
            failure(error as NSError)
        }
    }
    
    public static func resetIDKey(success: (() -> Void)? = nil,
                                  failure: ((_ error: Error) -> Void)? = nil) {
        renewIDKey(oldSignEnable: true, success: success, failure: failure)
    }
    
    static func renewIDKey(oldSignEnable: Bool,
                           success: (() -> Void)? = nil,
                           failure: ((_ error: Error) -> Void)? = nil) {
        var registrationId: UInt32 = 0
        var currentKeyPair: ECKeyPair?
        self.databaseStorage.read { transaction in
            registrationId = TSAccountManager.shared.randomANewRegistrationId(transaction)
            currentKeyPair = OWSIdentityManager.shared().identityKeyPair(with: transaction)
        }
        if(currentKeyPair == nil){
            OWSIdentityManager.shared().generateNewIdentityKey()
            currentKeyPair = OWSIdentityManager.shared().identityKeyPair()
        }
        let newKeyPair = Curve25519.generateKeyPair()
        let pubIdentityKey = newKeyPair.publicKey as NSData
        let prependKey = pubIdentityKey.prependKeyType() as Data
        let identityKey = prependKey.base64EncodedString()
        
        guard let newData = (identityKey + "\(registrationId)").data(using: .utf8),
                let currentKeyPair else {
            let errorString = "newData or oldKeyPair error!"
            OWSLogger.error(errorString)
            failure?(DTErrorWithCodeDescription(.dataError, errorString))
            return
        }

        do {
            let newSignData = try Ed25519.sign(newData, with: newKeyPair)
            
            var oldSignData: Data?
            if oldSignEnable {
                oldSignData = try Ed25519.sign(newSignData, with: currentKeyPair)
            }
            let renewIDKeyApi = RenewIDKeyAPI()
            renewIDKeyApi.sendResetIdentityRequest(identityKey,
                                                   registrationId: Int(registrationId),
                                                   newSign:newSignData.base64EncodedString(),
                                                   oldSign:oldSignData?.base64EncodedString()) { _ in
                self.databaseStorage.asyncWrite { wTransaction in
                    OWSIdentityManager.shared().storeNewIdentityKeyPair(newKeyPair, transaction: wTransaction)
                    TSAccountManager.shared.storeRegistrationId(registrationId, transaction: wTransaction)
                } completion: {
                    success?()
                }
            } failure: { error in
                failure?(error)
            }
            
        } catch {
            let errorString = "sign with an error!"
            OWSLogger.error(errorString)
            failure?(error)
        }
    }
    
}
