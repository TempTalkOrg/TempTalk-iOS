//
//  TSContactThread.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/11/23.
//

import Foundation

@objc
extension TSContactThread {
    
    public var isFriend: Bool {
        
        let number = self.contactIdentifier()
        
        if number == "+10000" ||
            number == TSAccountManager.localNumber() {
            return true
        }
        
        var threadAccount: SignalAccount?
        self.databaseStorage.read { transaction in
            threadAccount =  TextSecureKitEnv.shared().contactsManager.signalAccount(forRecipientId: number, transaction: transaction)
        }
        
        guard let threadAccount else {
            return false
        }
        
        return threadAccount.isFriend
    }
    
}
