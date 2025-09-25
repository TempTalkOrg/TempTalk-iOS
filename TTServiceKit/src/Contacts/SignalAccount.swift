//
//  SignalAccount.swift
//  TTServiceKit
//
//  Created by Kris.s on 2025/1/9.
//

import Foundation

@objc
extension SignalAccount {
    
    public var isFriend: Bool {
        
        let number = self.recipientId
        
        if number == "+10000" ||
            number == TSAccountManager.localNumber() {
            return true
        }
        
        guard let contact else {
            return false
        }
        if !contact.isExternal {
            return true
        }
        
        return false
    }
    
}
