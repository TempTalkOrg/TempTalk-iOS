//
//  ContactsSearch.swift
//  TTMessaging
//
//  Created by Kris.s on 2022/12/1.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation

@objc
public class ContactsSearcher: NSObject {
    
    private lazy var searcher = ConversationSearcher.shared
    
    private let threadViewHelper = ThreadViewHelper()
    
    private var contactsManager: OWSContactsManager { Environment.shared.contactsManager }
    
    @objc
    public func searchSignalAccounts(searchWord: String, transaction: SDSAnyReadTransaction) -> [SignalAccount] {
        
        guard (searchWord.count != 0) else {
            return []
        }
        
        let searchText = searchWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let resultSet = self.searcher.queryAccounts(
            searchText: searchText,
            threads: ["key":[]],
            transaction: transaction,
            contactsManager: self.contactsManager
        )
        
        var signalAccounts: Array<SignalAccount> = []
        
        for contactResult in resultSet.contacts {
            signalAccounts.append(contactResult.signalAccount)
        }
        
        return signalAccounts.sorted { account1, account2 in
            return DTSearchResultSortHelpter.sortGroupMember(account1: account1, account2: account2, searchText: searchWord)
        }
    }
    
    @objc
    public func getGroupAccountsByDefaultSortMethod(sortParms:[SignalAccount]) -> [SignalAccount] {
        return sortParms.sorted { account1, account2 in
            return DTSearchResultSortHelpter.searchGroupAccountsByDefaultSortMethod(account1: account1, account2: account2)
        }
    }
    
}

