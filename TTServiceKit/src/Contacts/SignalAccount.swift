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
        isFriend(localNumber: TSAccountManager.localNumber())
    }

    /// Use this variant while already inside a database transaction so checking the local
    /// account cannot open a nested GRDB read.
    @objc(isFriendWithLocalNumber:)
    public func isFriend(localNumber: String?) -> Bool {
        if recipientId == TSConstants.officialBotId || recipientId == localNumber {
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
