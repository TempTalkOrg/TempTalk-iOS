//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import AVFoundation

struct UserSearchCondition: OptionSet {
    let rawValue: Int
    static let name = UserSearchCondition(rawValue: 1)
    static let email = UserSearchCondition(rawValue: 2)
    static let signature = UserSearchCondition(rawValue: 4)
    static let department = UserSearchCondition(rawValue: 8)
    static let all = UserSearchCondition(rawValue: 16)
}

public class ConversationSearchResult: Comparable {
    public let thread: ThreadViewModel

    public let authorId: String?
    public let messageId: String?
    public let messageDate: Date?

    public let snippet: String?

    public let isLocalNumber: Bool
    private let sortKey: UInt64
    public let lastMessage: String
    
    init(thread: ThreadViewModel, sortKey: UInt64, authorId: String? = nil, messageId: String? = nil, messageDate: Date? = nil, snippet: String? = nil, lastMessage: String = "") {
        self.thread = thread
        self.sortKey = sortKey
        self.messageId = messageId
        self.messageDate = messageDate
        self.snippet = snippet
        self.authorId = authorId
        self.lastMessage = lastMessage
        self.isLocalNumber = TSAccountManager.localNumber() == thread.contactIdentifier
    }

    // Mark: Comparable

    public static func < (lhs: ConversationSearchResult, rhs: ConversationSearchResult) -> Bool {
        return lhs.sortKey < rhs.sortKey
    }

    // MARK: Equatable

    public static func == (lhs: ConversationSearchResult, rhs: ConversationSearchResult) -> Bool {
        return lhs.thread.threadRecord.uniqueId == rhs.thread.threadRecord.uniqueId &&
            lhs.messageId == rhs.messageId
    }
}

public class MessageSearchResult {
    public let thread: ThreadViewModel
    public let body: String?
    public let messageId: String
    public let messageDate: Date
    public let authorId: String?

    init(thread: ThreadViewModel, body: String?, messageId: String, messageDate: Date, authorId: String? = nil) {
        self.thread = thread
        self.body = body
        self.messageId = messageId
        self.messageDate = messageDate
        self.authorId = authorId
    }
}

@objcMembers
public class GroupSearchResult: NSObject {
    public let thread: TSGroupThread
    public let accounts: [SignalAccount]
    public let groupName: String
    
    init(thread: TSGroupThread, accounts: [SignalAccount], groupName: String) {
        self.thread = thread
        self.accounts = accounts
        self.groupName = groupName
    }
}

public class RecentSearchResult: Comparable {
    public let thread: TSThread
    public let threadName: String
    public let lastMessage: String
    public let lastMessageTime: UInt64
    public let account: SignalAccount?
    
    init(thread: TSThread, threadName: String, lastMessage: String, account: SignalAccount? = nil) {
        self.thread = thread
        self.threadName = threadName
        self.lastMessage = lastMessage
        self.lastMessageTime = NSDate.ows_millisecondsSince1970(for: thread.lastMessageDate ?? thread.creationDate)
        self.account = account
    }
    
    public static func < (lhs: RecentSearchResult, rhs: RecentSearchResult) -> Bool {
        if let contactThread = lhs.thread as? TSContactThread, contactThread.uniqueId == TSAccountManager.localNumber() {
            return true
        }
        if let contactThread = rhs.thread as? TSContactThread, contactThread.uniqueId == TSAccountManager.localNumber() {
            return false
        }
        return lhs.lastMessageTime < rhs.lastMessageTime
    }
    
    public static func == (lhs: RecentSearchResult, rhs: RecentSearchResult) -> Bool {
        return lhs.thread.uniqueId == rhs.thread.uniqueId
    }
}

public class ContactSearchResult: Comparable {
    public let signalAccount: SignalAccount
    public let contactsManager: ContactsManagerProtocol

    public var recipientId: String {
        return signalAccount.recipientId
    }

    init(signalAccount: SignalAccount, contactsManager: ContactsManagerProtocol) {
        self.signalAccount = signalAccount
        self.contactsManager = contactsManager
    }

    // Mark: Comparable

    public static func < (lhs: ContactSearchResult, rhs: ContactSearchResult) -> Bool {
        return lhs.contactsManager.compare(signalAccount: lhs.signalAccount, with: rhs.signalAccount) == .orderedAscending
    }

    // MARK: Equatable

    public static func == (lhs: ContactSearchResult, rhs: ContactSearchResult) -> Bool {
        return lhs.recipientId == rhs.recipientId
    }
}

public struct MessageSearchResultSet {
    public let searchText: String
    public let messages: [ConversationSearchResult]
    public var filteredMessagesThreads: [ConversationSearchResult]
    public var filteredMessagesDict: [String:[ConversationSearchResult]]
    
    public init(searchText: String, messages: [ConversationSearchResult]) {
        self.searchText = searchText
        self.messages = messages
        
        let tmpfilteredMessagesThreads = NSMutableArray()
        var tmpFilteredMessagesDict:[String:[ConversationSearchResult]] = [String:[ConversationSearchResult]]()
        var filteredMessages:[ConversationSearchResult] = [ConversationSearchResult]()
        let tmpMessageInThreadDict = NSMutableDictionary()
       
        if (messages.count > 0){
            for searchResult in messages {
                let uniqueId = searchResult.thread.threadRecord.uniqueId
                
                if tmpFilteredMessagesDict.keys.contains(where: {//包含
                    $0 == uniqueId
                }) {
                    filteredMessages = tmpFilteredMessagesDict[uniqueId]!
                    filteredMessages.append(searchResult)
                    tmpFilteredMessagesDict[uniqueId] = filteredMessages
                } else {
                    filteredMessages .removeAll()
                    filteredMessages.append(searchResult)
                    tmpFilteredMessagesDict[uniqueId] = filteredMessages
                }
                
                
                if !tmpMessageInThreadDict.allKeys.contains(where: {
                    $0 as! String == uniqueId
                }) {
                    tmpMessageInThreadDict.setValue(searchResult, forKey: uniqueId)
                    tmpfilteredMessagesThreads.add(searchResult)
                }
            }
        }
        self.filteredMessagesDict = tmpFilteredMessagesDict
        self.filteredMessagesThreads = tmpfilteredMessagesThreads as! [ConversationSearchResult]
    }
    
    public static var empty: Self {
        return .init(searchText: "", messages: [])
    }
}

public class SearchResultSet {
    public let searchText: String
    public let recentConversations: [RecentSearchResult]
    public let conversations: [GroupSearchResult]
    public let contacts: [ContactSearchResult]
    public var messages: [MessageSearchResult]
    public var filteredMessagesThreads: [MessageSearchResult]
    public var filteredMessagesDict: [String:[MessageSearchResult]]
    
    public init(searchText: String, conversations: [GroupSearchResult], contacts: [ContactSearchResult], messages: [MessageSearchResult], recentConversations: [RecentSearchResult]) {
        self.searchText = searchText
        self.conversations = conversations
        self.contacts = contacts
        self.messages = messages
        self.recentConversations = recentConversations
        
        let tmpfilteredMessagesThreads = NSMutableArray()
        var tmpFilteredMessagesDict:[String:[MessageSearchResult]] = [:]
        var filteredMessages:[MessageSearchResult] = []
        let tmpMessageInThreadDict = NSMutableDictionary()
       
        if (messages.count > 0){
            for searchResult in messages {
                let uniqueId = searchResult.thread.threadRecord.uniqueId
                
                if tmpFilteredMessagesDict.keys.contains(where: {//包含
                    $0 == uniqueId
                }) {
                    filteredMessages = tmpFilteredMessagesDict[uniqueId]!
                    filteredMessages.append(searchResult)
                    tmpFilteredMessagesDict[uniqueId] = filteredMessages
                } else {
                    filteredMessages .removeAll()
                    filteredMessages.append(searchResult)
                    tmpFilteredMessagesDict[uniqueId] = filteredMessages
                }
                
                
                if !tmpMessageInThreadDict.allKeys.contains(where: {
                    $0 as! String == uniqueId
                }) {
                    tmpMessageInThreadDict.setValue(searchResult, forKey: uniqueId)
                    tmpfilteredMessagesThreads.add(searchResult)
                }
            }
        }
        self.filteredMessagesDict = tmpFilteredMessagesDict
        self.filteredMessagesThreads = tmpfilteredMessagesThreads as! [MessageSearchResult]
    }
    
    public class var empty: SearchResultSet {
        return SearchResultSet(searchText: "", conversations: [], contacts: [], messages: [], recentConversations: [])
    }

    public var isEmpty: Bool {
        return conversations.isEmpty && contacts.isEmpty && messages.isEmpty && recentConversations.isEmpty
    }
}

@objc public class ConversationSearcher: NSObject {
    public enum LoadStrategy {
        public static let contact = 25
        public static let conversation = 25
        public static let message = 10000
    }
    
    private let activeTimeInterval: TimeInterval = kMonthInterval
    private let finder: FullTextSearchFinder
    var currentSearchText: String? = nil
    @objc public static let shared: ConversationSearcher = ConversationSearcher()
    
    override private init() {
        finder = FullTextSearchFinder()
        super.init()
    }
    
    
    /// forward search [recent + account]
    /// - Parameters:
    ///   - searchText: searchText
    ///   - threads: recent threads
    ///   - transaction: transaction
    ///   - contactsManager: contactsManager
    ///   - block: block
    @objc public func query(searchText: String,
                            threads: [TSThread],
                            transaction: SDSAnyReadTransaction,
                            contactsManager: ContactsManagerProtocol,
                            block: @escaping (_ recent: [TSThread], _ contacts: [SignalAccount]) -> Void) {
        
        guard !searchText.isEmpty else {
            block([], [])
            return
        }
        
        let lowercasedSearchText = searchText.lowercased()
        
        self.currentSearchText = lowercasedSearchText
        
        let recentConversations = queryRecentOneGroupConversations(
            searchText: lowercasedSearchText,
            threads: threads, transaction: transaction
        )
        
        let accountResults = queryContacts(
            searchText: lowercasedSearchText,
            transaction: transaction,
            contactsManager: contactsManager,
            loadStrategy: .all
        )

        var resultRecentConversations: [TSThread] = []
        recentConversations.forEach { result in
            resultRecentConversations.append(result.thread)
        }
        
        var resultAccountResults: [SignalAccount] = []
        accountResults.forEach { result in
            resultAccountResults.append(result.signalAccount)
        }
        
        block(resultRecentConversations, resultAccountResults)
    }
    
    public func query(searchText: String, threads: [String: [TSThread]], transaction: SDSAnyReadTransaction, contactsManager: ContactsManagerProtocol) -> SearchResultSet {
        guard !searchText.isEmpty else { return .empty}
        
        let lowercasedSearchText = searchText.lowercased()
        
        self.currentSearchText = lowercasedSearchText
        
        let accountResults = queryContacts(
            searchText: lowercasedSearchText,
            transaction: transaction,
            contactsManager: contactsManager,
            loadStrategy: .limit(count: LoadStrategy.contact)
        )
        let groupThreadResults = queryConversations(
            searchText: lowercasedSearchText,
            transaction: transaction,
            loadStrategy: .limit(count: LoadStrategy.conversation)
        )
        let messageResults = queryMessages(
            searchText: lowercasedSearchText,
            transaction: transaction,
            loadStrategy: .limit(count: LoadStrategy.message)
        )
        let recentConversations = queryRecentConversations(
            searchText: lowercasedSearchText,
            threads: threads, transaction: transaction
        )
        return .init(
            searchText: lowercasedSearchText,
            conversations: groupThreadResults,
            contacts: accountResults,
            messages: messageResults,
            recentConversations: recentConversations
        )
    }
    
    /// 由于查询 message 比较慢，将上面的 query 拆成两部分：quickQuery + queryMessages
    public func quickQuery(
        searchText: String,
        threads: [String: [TSThread]],
        transaction: SDSAnyReadTransaction,
        contactsManager: ContactsManagerProtocol
    ) -> SearchResultSet {
        guard !searchText.isEmpty else { return .empty}
        
        let lowercasedSearchText = searchText.lowercased()
        
        self.currentSearchText = lowercasedSearchText
        
        let accountResults = queryContacts(
            searchText: lowercasedSearchText,
            transaction: transaction,
            contactsManager: contactsManager,
            loadStrategy: .limit(count: LoadStrategy.contact)
        )
        let groupThreadResults = queryConversations(
            searchText: lowercasedSearchText,
            transaction: transaction,
            loadStrategy: .limit(count: LoadStrategy.conversation)
        )
        let recentConversations = queryRecentConversations(
            searchText: lowercasedSearchText,
            threads: threads, transaction: transaction
        )
        return .init(
            searchText: lowercasedSearchText,
            conversations: groupThreadResults,
            contacts: accountResults,
            messages: [],
            recentConversations: recentConversations
        )
    }
    
    public func queryAccounts(searchText: String, threads: [String: [TSThread]], transaction: SDSAnyReadTransaction, contactsManager: ContactsManagerProtocol) -> SearchResultSet {
        guard !searchText.isEmpty else { return .empty}
        
        let lowercasedSearchText = searchText.lowercased()
        
        self.currentSearchText = lowercasedSearchText
        
        let accountResults = queryContacts(
            searchText: lowercasedSearchText,
            transaction: transaction,
            contactsManager: contactsManager,
            loadStrategy: .limit(count: LoadStrategy.contact)
        )
        return .init(
            searchText: lowercasedSearchText,
            conversations: [],
            contacts: accountResults,
            messages: [],
            recentConversations: []
        )
    }
    
    public func queryRecentConversations(searchText: String, threads: [String: [TSThread]], transaction: SDSAnyReadTransaction) -> [RecentSearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let lowercasedSearchText = searchText.lowercased()
        
        var results: [RecentSearchResult] = []
        
        if let normalThreads = threads["normalThreads"] {
            results.append(contentsOf: queryRecentOneGroupConversations(searchText: lowercasedSearchText, threads: normalThreads, transaction: transaction))
        }
        
        if let invalidThreads = threads["invalidThreads"] {
            results.append(contentsOf: queryRecentOneGroupConversations(searchText: lowercasedSearchText, threads: invalidThreads, transaction: transaction))
        }
        
        if let invalidAndArchivedThreads = threads["invalidAndArchivedThreads"] {
            results.append(contentsOf: queryRecentOneGroupConversations(searchText: lowercasedSearchText, threads: invalidAndArchivedThreads, transaction: transaction))
        }
        
        return results
    }
    
    public func queryRecentOneGroupConversations(searchText: String, threads: [TSThread], transaction: SDSAnyReadTransaction) -> [RecentSearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let lowercasedSearchText = searchText.lowercased()
        
        var results: [RecentSearchResult] = []
        
        var namePrefixMatchs: [RecentSearchResult] = []
        var nameContanisMatchs: [RecentSearchResult] = []
        var otherMatches: [RecentSearchResult] = []
        
        for thread in threads {
            if lowercasedSearchText != self.currentSearchText {
                namePrefixMatchs = []
                nameContanisMatchs = []
                otherMatches = []
                break
            }
            if let group = thread as? TSGroupThread, let groupName = group.groupModel.groupName, groupName.lowercased().contains(lowercasedSearchText) {
                let element = RecentSearchResult(
                    thread: group,
                    threadName: groupName,
                    lastMessage: group.lastMessageText(transaction: transaction)
                )
                if groupName.lowercased().hasPrefix(lowercasedSearchText) {
                    namePrefixMatchs.append(element)
                } else {
                    nameContanisMatchs.append(element)
                }
            } else if let contact = thread as? TSContactThread {
                let contactIdentifier = contact.contactIdentifier()
                let contactName = contactsManager.displayName(forPhoneIdentifier: contactIdentifier, transaction: transaction)
                let signalAccount = contactsManager.signalAccount(forRecipientId: contactIdentifier, transaction: transaction)
                let element = RecentSearchResult(
                    thread: contact,
                    threadName: contactName,
                    lastMessage: contact.lastMessageText(transaction: transaction),
                    account: signalAccount
                )
                if contactName.lowercased().hasPrefix(lowercasedSearchText) {
                    namePrefixMatchs.append(element)
                } else if contactName.lowercased().contains(lowercasedSearchText) {
                    nameContanisMatchs.append(element)
                } else if self.contactThreadSearcher.matches(item: contact, query: lowercasedSearchText, transaction: transaction) {
                    otherMatches.append(element)
                }
            }
        }
        
        results.append(contentsOf: namePrefixMatchs)
        results.append(contentsOf: nameContanisMatchs)
        results.append(contentsOf: otherMatches)
        
        return results
    }
    
    public func queryGroupInCommon(searchText: String, transaction: SDSAnyReadTransaction) -> SearchResultSet {
        guard !searchText.isEmpty else { return .empty}
        
        let lowercasedSearchText = searchText.lowercased()
        
        self.currentSearchText = lowercasedSearchText

        let groupThreadResults = queryConversations(
            searchText: lowercasedSearchText,
            ignoreInGroup: false,
            transaction: transaction,
            loadStrategy: .all
        )
        
        return .init(
            searchText: lowercasedSearchText,
            conversations: groupThreadResults,
            contacts: [],
            messages: [],
            recentConversations: []
        )
    }

    
    private func map(thread: TSThread, transaction: SDSAnyReadTransaction) -> ConversationSearchResult {
        let viewModel = ThreadViewModel(thread: thread, transaction: transaction)
        var sortKey: UInt64 = 0
        if let lastMessageDate = viewModel.lastMessageDate {
            sortKey = NSDate.ows_millisecondsSince1970(for: lastMessageDate)
        }
        
        return .init(
            thread: viewModel,
            sortKey: sortKey,
            lastMessage: thread.lastMessageText(transaction: transaction)
        )
    }
    
    public func queryContacts(searchText: String, transaction: SDSAnyReadTransaction, contactsManager: ContactsManagerProtocol, loadStrategy: FullTextSearchFinder.LoadStrategy) -> [ContactSearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let lowercasedSearchText = searchText.lowercased()
        
        var finalSearchText = lowercasedSearchText
        if lowercasedSearchText == "备忘录" || lowercasedSearchText == "note" {
            let localNumber = tsAccountManager.localNumber(with: transaction)
            let localName = contactsManager.displayName(forPhoneIdentifier: localNumber, transaction: transaction)
            finalSearchText = localName.lowercased()
        }
        
        var accountResults: [ContactSearchResult] = []
        finder.enumerateAccounts(with: finalSearchText, at: transaction, loadStrategy: loadStrategy) { account, snippet in
            guard let currentSearchText = self.currentSearchText, lowercasedSearchText == currentSearchText else {
                return
            }
//            guard let contact = account.contact, contact.isExternal == false else {
//                return
//            }
            accountResults.append(ContactSearchResult(signalAccount: account, contactsManager: contactsManager))
        }
        
        Logger.debug("[search] contacts count: \(accountResults.count)")
        
        return accountResults
    }
    
    public func queryConversations(searchText: String, ignoreInGroup: Bool? = true, transaction: SDSAnyReadTransaction, loadStrategy: FullTextSearchFinder.LoadStrategy) -> [GroupSearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let lowercasedSearchText = searchText.lowercased()
        
        var groupThreadResults: [GroupSearchResult] = []
        finder.enumerateGroupThreads(with: lowercasedSearchText, at: transaction, loadStrategy: loadStrategy) { groupThread, snippet in
            
            // 后续观察性能影响，高频操作，其它地方搜索，遍历的话每次都会走一遍判断，决定是否应该单独加个方法
            if (ignoreInGroup == false) {
                let localInGroup = groupThread.isLocalUserInGroup(with: transaction)
                if (localInGroup == false) { return }
            }
            
            guard lowercasedSearchText == self.currentSearchText else {
                return
            }
            guard let groupName = groupThread.groupModel.groupName else {
                return
            }
            guard !groupName.lowercased().contains(lowercasedSearchText) else {
                groupThreadResults.append(.init(thread: groupThread, accounts: [], groupName: groupName))
                return
            }
            var members: [SignalAccount] = []
            for memberId in groupThread.groupModel.groupMemberIds {
                guard let account = self.contactsManager.signalAccount(forRecipientId: memberId, transaction: transaction), let contact = account.contact else {
                    continue
                }
                let append = ((contact.fullName) + " " + (account.remarkName ?? "") + " " + (contact.email ?? "") + " " + (account.recipientId)).lowercased()
                guard append.contains(lowercasedSearchText) else { continue }
                members.append(account)
                break
            }
            groupThreadResults.append(.init(thread: groupThread, accounts: members, groupName: groupName))
        }
        
        Logger.debug("[search] groupThread count: \(groupThreadResults.count)")
        
        return groupThreadResults
    }
    
    public func queryMessages(searchText: String, transaction: SDSAnyReadTransaction, loadStrategy: FullTextSearchFinder.LoadStrategy) -> [MessageSearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let start = CFAbsoluteTimeGetCurrent()
        
        let lowercasedSearchText = searchText.lowercased()
        
        var messageResults: [MessageSearchResult] = []
        finder.enumerateMessages(with: lowercasedSearchText, at: transaction, loadStrategy: loadStrategy) { (message, snippet) in
            guard let thread = message.thread(with: transaction), thread.shouldBeVisible else { return }
            
            // 过滤历史撤回消息
            if let infoMessage = message as? TSInfoMessage, infoMessage.recall != nil {
                return
            }
            
            var messageBody: String? = nil
            if let body = message.body, body.lowercased().contains(snippet) {
                messageBody = body
            } else if let body = message.quotedMessage?.body, body.lowercased().contains(snippet) {
                messageBody = body
            } else if let forwardMessage = message.combinedForwardingMessage, let forward = forwardMessage.subForwardingMessages.first(where: { $0.body?.lowercased().contains(snippet)  ?? false }) {
                messageBody = forward.body
            }
            let searchResult = MessageSearchResult(
                thread: .init(thread: thread, transaction: transaction),
                body: messageBody,
                messageId: message.uniqueId,
                messageDate: NSDate.ows_date(withMillisecondsSince1970: message.timestamp)
            )
            messageResults.append(searchResult)
        }
        
        Logger.debug("[search] messages count: \(messageResults.count)")
        
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        Logger.info("==== query message duration:\(duration)ms ====")
        
        return messageResults
    }
    
    public func queryMessages(with searchText: String, in thread: TSThread, at transaction: SDSAnyReadTransaction, loadStrategy: FullTextSearchFinder.LoadStrategy) -> MessageSearchResultSet {
        
        let searchWord = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !searchWord.isEmpty, let threadId = thread.primaryKey, !threadId.isEmpty else {
            return .init(searchText: searchText, messages: [])
        }

        var messages: [ConversationSearchResult] = []
        
        var authorId: String?
        
        finder.enumerateMessages(with: searchWord, for: threadId, at: transaction, loadStrategy: loadStrategy) { (message, snippet) in
            
            // 过滤历史撤回消息
            if let infoMessage = message as? TSInfoMessage, infoMessage.recall != nil {
                return
            }
            
            if let incomingMessage = message as? TSIncomingMessage {
                authorId = incomingMessage.messageAuthorId()
            } else {
                authorId = TSAccountManager.shared.localNumber(with: transaction);
            }
            let searchResult = ConversationSearchResult(
                thread: .init(thread: thread, transaction: transaction),
                sortKey: message.timestamp,
                authorId: authorId,
                messageId: message.uniqueId,
                messageDate: NSDate.ows_date(withMillisecondsSince1970: message.timestamp),
                snippet: snippet
            )
            messages.append(searchResult)
        }
    
        return .init(searchText: searchText, messages: messages)
    }
    
    @objc(filterThreads:withSearchText:transaction:)
    public func filterThreads(_ threads: [TSThread], searchText: String, transaction: SDSAnyReadTransaction) -> [TSThread] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else {
            return threads
        }

        return threads.filter { thread in
            switch thread {
            case let groupThread as TSGroupThread:
                return self.groupThreadSearcher.matches(item: groupThread, query: searchText, transaction: transaction)
            case let contactThread as TSContactThread:
                return self.contactThreadSearcher.matches(item: contactThread, query: searchText, transaction: transaction)
            default:
                owsFailDebug("Unexpected thread type: \(thread)")
                return false
            }
        }
    }
    
    @objc(filterSignalAccounts:withSearchText:transaction:)
    public func filterSignalAccounts(_ signalAccounts: [SignalAccount], searchText: String, transaction: SDSAnyReadTransaction) -> [SignalAccount] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else {
            return signalAccounts
        }

        return signalAccounts.filter { signalAccount in
            self.signalAccountSearcher(.all).matches(item: signalAccount, query: searchText, transaction: transaction)
        }
    }
    
    /// @list搜索，不需要签名/BU搜索
    @objc(filterAtSignalAccounts:withSearchText:searchResultClosure:transaction:)
    public func filterAtSignalAccounts(_ signalAccounts: [SignalAccount], searchText: String, searchResultClosure: ((String, [SignalAccount]) -> Void)?, transaction: SDSAnyReadTransaction) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else {
            searchResultClosure?(searchText,signalAccounts)
            return
        }
        let filterResult = signalAccounts.filter { signalAccount in
            self.signalAccountSearcher([.name, .email]).matchesEmailCharacters(item: signalAccount, query: searchText, transaction: transaction)
        }.sorted { account1, account2 in
            return DTSearchResultSortHelpter.sortGroupMember(account1: account1, account2: account2, searchText: searchText)
        }
        
        searchResultClosure?(searchText, filterResult)
    }
    
    // MARK: Searchers

    private var contactsManager: OWSContactsManager {
        return Environment.shared.contactsManager
    }
    
    private lazy var groupThreadSearcher: Searcher<TSGroupThread> = Searcher { (groupThread: TSGroupThread, transaction: SDSAnyReadTransaction)  in
        let groupName = groupThread.groupModel.groupName
        let memberStrings = groupThread.groupModel.groupMemberIds.map { recipientId in
            self.groupIndexingString(recipientId: recipientId, transaction:transaction)
            }.joined(separator: " ")

        return "\(memberStrings) \(groupName ?? "")"
    }
    
    private lazy var groupThreadNameSearcher: Searcher<TSGroupThread> = Searcher { (groupThread: TSGroupThread, transaction: SDSAnyReadTransaction) in
        let groupName = groupThread.groupModel.groupName
        
        return groupName ?? ""
    }
    
    private lazy var groupThreadMemberSearcher: Searcher<TSGroupThread> = Searcher { (groupThread: TSGroupThread, transaction: SDSAnyReadTransaction) in
        let memberStrings = groupThread.groupModel.groupMemberIds.map { recipientId in
            self.groupIndexingString(recipientId: recipientId, transaction:transaction)
        }.joined(separator: " ")
        
        return memberStrings
    }

    private lazy var contactThreadSearcher: Searcher<TSContactThread> = Searcher { (contactThread: TSContactThread, transaction: SDSAnyReadTransaction) in
        let recipientId = contactThread.contactIdentifier()
        return self.indexingString(recipientId: recipientId, transaction:transaction)
    }

//    private lazy var signalAccountSearcher: Searcher<SignalAccount> = Searcher { (signalAccount: SignalAccount, transaction: SDSAnyReadTransaction) in
//        let recipientId = signalAccount.recipientId
//        return self.indexingString(recipientId: recipientId, transaction:transaction)
    
    private func signalAccountSearcher(_ conditions: UserSearchCondition = .all) -> Searcher<SignalAccount> {
        
        return Searcher { (signalAccount: SignalAccount, transaction: SDSAnyReadTransaction) in
            let recipientId = signalAccount.recipientId
            return self.indexingString(recipientId: recipientId, conditions: conditions, transaction:transaction)
        }
    }
    
    private lazy var signalAccountNameSearcher: Searcher<SignalAccount> = Searcher { (signalAccount: SignalAccount, transaction: SDSAnyReadTransaction) in
        let recipientId = signalAccount.recipientId
        return self.contactNameIndexingString(recipientId: recipientId, transaction: transaction)
    }
    
    private lazy var signalAccountProfileSearcher: Searcher<SignalAccount> = Searcher { (signalAccount: SignalAccount, transaction: SDSAnyReadTransaction) in
        let recipientId = signalAccount.recipientId
        return self.contactProfileIndexingString(recipientId: recipientId, transaction:transaction)
    }

    private func contactNameIndexingString(recipientId: String, transaction: SDSAnyReadTransaction) -> String {
        var recipientDetail = ""
        
        let contactName = contactsManager.displayName(forPhoneIdentifier: recipientId, transaction:transaction)
        recipientDetail = recipientDetail.appending(contactName)
        
        if let profileName = contactsManager.profileName(forRecipientId: recipientId, transaction:transaction) {
            recipientDetail = recipientDetail.appending(" \(profileName)")
        }
        
        return recipientDetail.lowercased()
    }
    
    private func contactProfileIndexingString(recipientId: String, transaction: SDSAnyReadTransaction) -> String {
        var recipientDetail = recipientId
        
        if let signature = contactsManager.signature(forPhoneIdentifier: recipientId, transaction:transaction) {
            recipientDetail = recipientDetail.appending(" \(signature)")
        }
        
        if let email = contactsManager.email(forPhoneIdentifier: recipientId, transaction:transaction) {
            recipientDetail = recipientDetail.appending(" \(email)")
        }
        
        return recipientDetail.lowercased()
    }
    
    public let noteSearchKey = "备忘录 note"
    private func indexingString(recipientId: String, conditions: UserSearchCondition = .all, transaction: SDSAnyReadTransaction) -> String {
        var recipientDetail = recipientId
        
        if (conditions.contains(.name) || conditions.contains(.all)) {
            let contactName = contactsManager.displayName(forPhoneIdentifier: recipientId, transaction: transaction)
            recipientDetail = recipientDetail.appending(contactName)
                        
            if recipientId == tsAccountManager.localNumber(with: transaction) {
                recipientDetail = recipientDetail.appending(" \(noteSearchKey)")
            }
        }
        if (conditions.contains(.signature) || conditions.contains(.all)) {
            if let signature = contactsManager.signature(forPhoneIdentifier: recipientId, transaction: transaction) {
                recipientDetail = recipientDetail.appending(" \(signature)")
            }
        }
        
        if let email = contactsManager.email(forPhoneIdentifier: recipientId, transaction: transaction) ,
           conditions.contains(.email) || conditions.contains(.all) {
            recipientDetail = recipientDetail.appending(" \(email)")
        }

        return recipientDetail.lowercased()
    }
    
    private func groupIndexingString(recipientId: String, transaction: SDSAnyReadTransaction) -> String {
        var recipientDetail = recipientId
        
        let contactName = contactsManager.displayName(forPhoneIdentifier: recipientId, transaction: transaction)
        recipientDetail = recipientDetail.appending(contactName)
        
        if let profileName = contactsManager.profileName(forRecipientId: recipientId, transaction: transaction) {
            recipientDetail = recipientDetail.appending(" \(profileName)")
        }
        
        if let email = contactsManager.email(forPhoneIdentifier: recipientId, transaction: transaction) {
            recipientDetail = recipientDetail.appending(" \(email)")
        }
        
        return recipientDetail.lowercased()
    }
}

extension TSThread {
    @objc var primaryKey: String? {
        return TSContactThread.threadId(fromContactId: contactIdentifier() ?? "")
    }
}

extension TSGroupThread {
    @objc override var primaryKey: String? {
        return Self.threadId(fromGroupId: groupModel.groupId)
    }
}
