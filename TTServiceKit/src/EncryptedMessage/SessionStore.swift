//
//  SessionStore.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/12/2.
//

import Foundation

@objc(TTSessionStore) public class SessionStore: NSObject {
    
    static let sessionStore = SDSKeyValueStore(collection: "TTSessionStore")
    
    @objc public class func loadSession(identifier: String, transaction: SDSAnyReadTransaction) -> DTSessionRecord? {
        if identifier.isEmpty {
            return nil
        }
        if let session = sessionStore.getObject(forKey: identifier, transaction: transaction) as? DTSessionRecord {
            return session
        }
        return nil
    }
    
    @objc public class func storeSession(_ session: DTSessionRecord, identifier: String, transaction: SDSAnyWriteTransaction) {
        if identifier.isEmpty {
            return
        }
        sessionStore.setObject(session, key: identifier, transaction: transaction)
    }
    
    @objc public class func deleteSession(identifier: String, transaction: SDSAnyWriteTransaction) {
        if identifier.isEmpty {
            return
        }
        sessionStore.removeValue(forKey: identifier, transaction: transaction)
    }
    
    @objc public class func containsSession(identifier: String, transaction: SDSAnyReadTransaction) -> Bool {
        if identifier.isEmpty {
            return false
        }
        if let session = sessionStore.getObject(forKey: identifier, transaction: transaction) as? DTSessionRecord {
            if !session.remoteIdentityKey.isEmpty  && session.remoteRegistrationId > 0 {
                return true
            }
        }
        return false
    }
    
}
