//
//  DTSearchResultSortHelpter.swift
//  TTMessaging
//
//  Created by hornet on 2023/5/20.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTSearchResultSortHelpter: NSObject {
    
     class func sortGroupMember(account1: SignalAccount,account2: SignalAccount, searchText: String) -> Bool {
        guard let groupDisplayName1 = self.contactsManager.formattedFullName(forRecipientId: account1.recipientId),
              let groupDisplayName2 = self.contactsManager.formattedFullName(forRecipientId: account2.recipientId)
        else {
            if let email1 = account1.contact?.email,
               let email2 = account2.contact?.email,
               email1.lowercased().stripped  > email2.lowercased().stripped {
                return true
            } else {
                return false
            }
        }
        let searchText_lowercased = searchText.lowercased().stripped
        let groupDisplayName1_lowercased = groupDisplayName1.lowercased().stripped
        let groupDisplayName2_lowercased = groupDisplayName2.lowercased().stripped
        if groupDisplayName1_lowercased.hasPrefix(searchText_lowercased) &&
            !groupDisplayName2_lowercased.hasPrefix(searchText_lowercased){
            return true
            
        } else if !groupDisplayName1_lowercased.hasPrefix(searchText_lowercased) &&
                   groupDisplayName2_lowercased.hasPrefix(searchText_lowercased){
            return false
        } else if groupDisplayName1_lowercased < groupDisplayName2_lowercased {
            return true
        } else {
            if let email1 = account1.contact?.email,
               let email2 = account2.contact?.email,
               email1.lowercased().stripped  > email2.lowercased().stripped {
                return true
            } else {
                return false
            }
        }
    }
    
    class func searchGroupAccountsByDefaultSortMethod(account1: SignalAccount,account2: SignalAccount) -> Bool {
       guard let groupDisplayName1 = self.contactsManager.formattedFullName(forRecipientId: account1.recipientId),
             let groupDisplayName2 = self.contactsManager.formattedFullName(forRecipientId: account2.recipientId)
       else {
               return false
       }
       let groupDisplayName1_lowercased = groupDisplayName1.lowercased().stripped
       let groupDisplayName2_lowercased = groupDisplayName2.lowercased().stripped
       if groupDisplayName1_lowercased < groupDisplayName2_lowercased {
           return true
       } else {
           return false
       }
   }
    
    
    private class var contactsManager: OWSContactsManager {
        return Environment.shared.contactsManager
    }
    
    
}
