//
//  FullTextSearchFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/2.
//

import Foundation
import GRDB

// Create a searchable index for objects of type T
public class SearchIndexer<T> {

    private let indexBlock: (T, SDSAnyReadTransaction) -> String
    
    public init(indexBlock: @escaping (T, SDSAnyReadTransaction) -> String) {
        self.indexBlock = indexBlock
    }
    
    public func index(_ item: T, transaction: SDSAnyReadTransaction) -> String {
        return normalize(indexingText: indexBlock(item, transaction))
    }

    private func normalize(indexingText: String) -> String {
        return FullTextSearchFinder.normalize(text: indexingText)
    }
    
    public func removeWhitespacesAndNewlines(_ item: T, transaction: SDSAnyReadTransaction) -> String {
        let text = indexBlock(item, transaction)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@objc
public class FullTextSearchFinder: AnyFullTextSearchFinder {
    
    public func enumerateAccounts(
        with searchText: String,
        at transaction: SDSAnyReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (SignalAccount, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateAccounts(with: searchText, at: grdbRead, loadStrategy: loadStrategy, block: block)
            }
            
    }
    
    public func enumerateGroupThreads(
        with searchText: String,
        at transaction: SDSAnyReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSGroupThread, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateGroupThreads(with: searchText, at: grdbRead, loadStrategy: loadStrategy, block: block)
            }
    }
    
    @objc public func enumerateExternalRecipientGroups(
        with recipient: String,
        at transaction: SDSAnyReadTransaction,
        block: @escaping (TSGroupThread, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateExternalRecipientGroups(with: recipient, at: grdbRead, block: block)
            }
            
    }
    
    public func enumerateMessages(
        with searchText: String,
        for threadId: String,
        at transaction: SDSAnyReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSMessage, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateMessages(with: searchText, for: threadId, at: grdbRead, loadStrategy: loadStrategy, block: block)
            }
            
    }
    
    
    public func enumerateMessages(
        with searchText: String,
        at transaction: SDSAnyReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSMessage, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateMessages(with: searchText, at: grdbRead, loadStrategy: loadStrategy, block: block)
            }
            
    }
    
    @objc
    public func enumerateMessages(
        with recipientId: String,
        threadId: String,
        at transaction: SDSAnyReadTransaction,
        block: @escaping (TSMessage, String) -> Void) {
            
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                GRDBFullTextSearchFinder.enumerateMessages(with: recipientId, threadId: threadId, at: grdbRead, block: block)
            }
            
    }
    
    public func modelWasInserted(model: SDSIndexableModel, transaction: SDSAnyWriteTransaction) {
        assert(type(of: model).ftsIndexMode != .never)

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            GRDBFullTextSearchFinder.modelWasInserted(model: model, transaction: grdbWrite)
        }
    }

    @objc
    public func modelWasUpdatedObjc(model: AnyObject, transaction: SDSAnyWriteTransaction) {
        guard let model = model as? SDSIndexableModel else {
            owsFailDebug("Invalid model.")
            return
        }
        modelWasUpdated(model: model, transaction: transaction)
    }

    public func modelWasUpdated(model: SDSIndexableModel, transaction: SDSAnyWriteTransaction) {
        assert(type(of: model).ftsIndexMode != .never)

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            GRDBFullTextSearchFinder.modelWasUpdated(model: model, transaction: grdbWrite)
        }
    }

    public func modelWasRemoved(model: SDSIndexableModel, transaction: SDSAnyWriteTransaction) {
        assert(type(of: model).ftsIndexMode != .never)

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            GRDBFullTextSearchFinder.modelWasRemoved(model: model, transaction: grdbWrite)
        }
    }
    
    @objc
    public func modelWasRemovedObjc(model: AnyObject, transaction: SDSAnyWriteTransaction) {
        guard let model = model as? SDSIndexableModel else {
            owsFailDebug("Invalid model.")
            return
        }
        assert(type(of: model).ftsIndexMode != .never)

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            GRDBFullTextSearchFinder.modelWasRemoved(model: model, transaction: grdbWrite)
        }
    }

    public class func allModelsWereRemoved(collection: String, transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            GRDBFullTextSearchFinder.allModelsWereRemoved(collection: collection, transaction: grdbWrite)
        }
    }
    
}


class GRDBFullTextSearchFinder: AnyFullTextSearchFinder {
    
    static let contentTableName = "indexable_text"
    
    public static func enumerateAccounts(
        with searchText: String,
        at transaction: GRDBReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (SignalAccount, String) -> Void) {
            
//            let query = AnyFullTextSearchFinder.query(searchText: searchText)
            let query = searchText
            
            let conditionalString = "(INSTR(search.\(signalAccountSecondaryColumn: .fullName), ?) > 0 OR INSTR(search.\(signalAccountSecondaryColumn: .remarkName), ?) > 0 OR INSTR(search.\(signalAccountSecondaryColumn: .email), ?) > 0 OR INSTR(search.\(signalAccountSecondaryColumn: .buName), ?) > 0 OR INSTR(search.\(signalAccountSecondaryColumn: .uniqueId), ?) > 0 OR INSTR(search.\(signalAccountSecondaryColumn: .signature), ?) > 0) ORDER BY (CASE WHEN INSTR(search.\(signalAccountSecondaryColumn: .fullName), ?) = 1 THEN 1 WHEN INSTR(search.\(signalAccountSecondaryColumn: .remarkName), ?) = 1 THEN 1 WHEN INSTR(search.\(signalAccountSecondaryColumn: .fullName), ?) > 0 THEN 2 WHEN INSTR(search.\(signalAccountSecondaryColumn: .remarkName), ?) > 0 THEN 2 WHEN INSTR(search.\(signalAccountSecondaryColumn: .email), ?) > 0 THEN 3 WHEN INSTR(search.\(signalAccountSecondaryColumn: .signature), ?) > 0 THEN 4 WHEN INSTR(search.\(signalAccountSecondaryColumn: .buName), ?) > 0 THEN 5 WHEN INSTR(search.\(signalAccountSecondaryColumn: .uniqueId), ?) = 1 THEN 6 ELSE 7 END)"
            
                        
            let sql = """
                SELECT account.*
                FROM \(SignalAccountSecondaryRecord.databaseTableName) search ,\(SignalAccountRecord.databaseTableName) account
                WHERE search.\(signalAccountSecondaryColumn: .uniqueId) = account.\(signalAccountColumn: .uniqueId)
                AND \(conditionalString)
                \(Self.assembleQuery(strategy: loadStrategy))
                """
            
            let arguments: StatementArguments = StatementArguments.init(Array(repeating: query, count: 14))
            
            do {
                try SignalAccountRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { signalAccountRecord in
                    block(try SignalAccount.fromRecord(signalAccountRecord) , "")
                }
                
            } catch {
                owsFailDebug("error: \(error)")
            }
            
    }
    
    public static func enumerateGroupThreads(
        with searchText: String,
        at transaction: GRDBReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSGroupThread, String) -> Void) {
            
//            let query = AnyFullTextSearchFinder.query(searchText: searchText)
            let query = searchText
            
            let conditionalString = "(INSTR(search.\(groupThreadSecondaryColumn: .groupName), ?) > 0 OR INSTR(search.\(groupThreadSecondaryColumn: .members), ?) > 0) ORDER BY (CASE WHEN INSTR(search.\(groupThreadSecondaryColumn: .groupName), ?) = 1 THEN 1 WHEN INSTR(search.\(groupThreadSecondaryColumn: .groupName), ?) > 0 THEN 2 ELSE 3 END), search.\(groupThreadSecondaryColumn: .lastMessageDate) DESC"
            
            let sql = """
                SELECT g.*
                FROM \(GroupThreadSecondaryRecord.databaseTableName) search ,\(ThreadRecord.databaseTableName) g
                WHERE search.\(groupThreadSecondaryColumn: .uniqueId) = g.\(threadColumn: .uniqueId)
                AND \(conditionalString)
                \(Self.assembleQuery(strategy: loadStrategy))
                """
            
            let arguments: StatementArguments = StatementArguments.init(Array(repeating: query, count: 4))
            
            
            do {
                try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
                    if let thread = try TSThread.fromRecord(threadRecord) as? TSGroupThread {
                        block(thread , "")
                    }
                }
                
            } catch {
                owsFailDebug("error: \(error)")
            }
            
    }
    
    public static func enumerateExternalRecipientGroups(
        with recipient: String,
        at transaction: GRDBReadTransaction,
        block: @escaping (TSGroupThread, String) -> Void) {
            
            let conditionalString = "INSTR(search.\(groupThreadSecondaryColumn: .members), ?) > 0"
            
            let sql = """
                SELECT g.*
                FROM \(GroupThreadSecondaryRecord.databaseTableName) search ,\(ThreadRecord.databaseTableName) g
                WHERE search.\(groupThreadSecondaryColumn: .uniqueId) = g.\(threadColumn: .uniqueId)
                AND \(conditionalString)
                """
            
                    
            let arguments: StatementArguments = [recipient]


            do {
                if let groupThreadRecord = try ThreadRecord.fetchOne(transaction.database, sql: sql, arguments: arguments) {
                    if let groupThread = try TSGroupThread.fromRecord(groupThreadRecord) as? TSGroupThread {
                        block(groupThread, "")
                    }
                } else {
                    Logger.debug("not found!")
//                    owsFailDebug("not found!")
                }

            } catch {
                owsFailDebug("error: \(error)")
            }
            
    }
    
    public static func enumerateMessages(
        with searchText: String,
        for threadId: String,
        at transaction: GRDBReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSMessage, String) -> Void) {

            let tableName = "model_TSMessageSecondary_virtual"
            
            // simple_query 是 FTS5 自定义分词器 simple 自定义函数，用于 wrap 需要查询的字符串
            let query = "simple_query('\(searchText)')"
            
            // simple_snippet 效果等同于 FTS5 的 snippet，获取匹配结果中命中的关键词
            let snippet = "simple_snippet(\(tableName), 2, '', '', '', 1) as snippet"
            
            let sql = """
                SELECT \(messageSecondaryColumn: .uniqueId), \(snippet)
                FROM \(tableName)
                WHERE \(messageSecondaryColumn: .thread) = '\(threadId)'
                AND \(messageSecondaryColumn: .display) = 1
                AND \(messageSecondaryColumn: .message) MATCH \(query)
                ORDER BY \(messageSecondaryColumn: .timestamp) DESC
                \(Self.assembleQuery(strategy: loadStrategy))
            """
            
            do {
                
                let rows = try Row.fetchCursor(transaction.database, sql: sql)
                var results: [(uniqueId: String, snippet: String)] = []
                while let row = try rows.next() {
                    let uniqueId = row["uniqueId"] as? String
                    let snippet = row["snippet"] as? String
                    if let uniqueId, !uniqueId.isEmpty {
                        results.append((uniqueId: uniqueId, snippet: snippet ?? ""))
                    }
                }
                
                results.forEach {
                    let message = TSMessage.anyFetchMessage(
                        uniqueId: $0.uniqueId,
                        transaction: SDSAnyReadTransaction(.grdbRead(transaction))
                    )
                    if let message {
                        block(message, $0.snippet)
                    }
                }
                
            } catch {
                owsFailDebug("error: \(error)")
            }

    }
    
    
    public static func enumerateMessages(
        with searchText: String,
        at transaction: GRDBReadTransaction,
        loadStrategy: LoadStrategy,
        block: @escaping (TSMessage, String) -> Void) {
            
            let tableName = "model_TSMessageSecondary_virtual"
            
            // simple_query 是 FTS5 自定义分词器 simple 自定义函数，用于 wrap 需要查询的字符串
            let query = "simple_query('\(searchText)')"
            
            // simple_snippet 效果等同于 FTS5 的 snippet，获取匹配结果中命中的关键词
            let snippet = "simple_snippet(\(tableName), 2, '', '', '', 1) as snippet"
            
            let sql = """
                SELECT \(messageSecondaryColumn: .uniqueId), \(snippet)
                FROM \(tableName)
                WHERE \(messageSecondaryColumn: .display) = 1
                AND \(messageSecondaryColumn: .message) MATCH \(query)
                ORDER BY \(messageSecondaryColumn: .timestamp) DESC
                \(Self.assembleQuery(strategy: loadStrategy))
            """
            
            do {
                let rows = try Row.fetchCursor(transaction.database, sql: sql)
                var results: [(uniqueId: String, snippet: String)] = []
                while let row = try rows.next() {
                    let uniqueId = row["uniqueId"] as? String
                    let snippet = row["snippet"] as? String
                    if let uniqueId, !uniqueId.isEmpty {
                        results.append((uniqueId: uniqueId, snippet: snippet ?? ""))
                    }
                }
                
                results.forEach {
                    let message = TSMessage.anyFetchMessage(
                        uniqueId: $0.uniqueId,
                        transaction: SDSAnyReadTransaction(.grdbRead(transaction))
                    )
                    if let message {
                        block(message, $0.snippet)
                    }
                }
                
            } catch {
                owsFailDebug("error: \(error)")
            }
                        
    }
    
    
    public static func enumerateMessages(
        with recipientId: String,
        threadId: String,
        at transaction: GRDBReadTransaction,
        block: @escaping (TSMessage, String) -> Void) {
                        
            
            let sql = """
                SELECT *
                FROM \(InteractionRecord.databaseTableName)
                WHERE \(interactionColumn: .threadUniqueId) = ?
                AND \(interactionColumn: .authorId) = ?
                ORDER BY \(interactionColumn: .serverTimestamp) DESC
                """
            
            let arguments: StatementArguments = [threadId, recipientId]
            
            
            do {
                if let interactionRecord = try InteractionRecord.fetchOne(transaction.database, sql: sql, arguments: arguments) {
                    let message = try TSMessage.fromRecord(interactionRecord) as! TSMessage
                    block(message, "")
                } else {
//                    owsFailDebug("not found!")
                }

            } catch {
                owsFailDebug("error: \(error)")
            }
            
    }
    
    private class func collection(forModel model: SDSIndexableModel) -> String {
        // Note that allModelsWereRemoved(collection: ) makes the same
        // assumption that the FTS collection matches the
        // TSYapDatabaseObject.collection.
        return type(of: model).collection()
    }

    private static let serialQueue = DispatchQueue(label: "org.signal.fts")
    // This should only be accessed on serialQueue.
    private static let ftsCache = LRUCache<String, String>(maxSize: 128, nseMaxSize: 16)

    private class func cacheKey(collection: String, uniqueId: String) -> String {
        return "\(collection).\(uniqueId)"
    }
    
    private class func shouldSkipWriteFtx() -> Bool {
        return (CurrentAppContext().isMainApp && CurrentAppContext().isInBackground())
    }
    
    private class func shouldIndexModel(_ model: SDSIndexableModel) -> Bool {
        
        if shouldSkipWriteFtx() {
            Logger.info("is mainApp and isInBackground, skip handle ftx. type \(type(of: model))")
            return false
        }
        
        if model is TSMessage {
            return true
        }
        
        if model is SignalAccount {
            return true
        }
        
        if model is TSGroupThread {
            return true
        }
        
        return false
    }
    
    private class func checkShouldUpdate(inserted: Bool, model: SDSIndexableModel, ftsContent: String) -> Bool {
        let uniqueId = model.uniqueId
        let collection = self.collection(forModel: model)
        if(inserted){
            serialQueue.sync {
                let cacheKey = self.cacheKey(collection: collection, uniqueId: uniqueId)
                ftsCache.setObject(ftsContent, forKey: cacheKey)
            }
        } else {
            let shouldUpdate: Bool = serialQueue.sync {
                guard !CurrentAppContext().isRunningTests else {
                    return true
                }
                let cacheKey = self.cacheKey(collection: collection, uniqueId: uniqueId)
                if let cachedValue = ftsCache.object(forKey: cacheKey),
                    (cachedValue as String) == ftsContent {
                    return false
                }
                ftsCache.setObject(ftsContent, forKey: cacheKey)
                return true
            }
            return shouldUpdate
            
        }
        
        return true
    }
    
    private class func createMessageSecondary(inserted: Bool, message: TSMessage, transaction: GRDBWriteTransaction) -> TSMessageSecondary? {
        var content = self.messageIndexer.removeWhitespacesAndNewlines(message, transaction: transaction.asAnyRead)
        
        guard !content.isEmpty else { return nil}
        
        if let quoted = message.quotedMessage, let quotedBody = quoted.body, !quotedBody.isEmpty {
            content += " " + quotedBody
        }
        
        if let forward = message.combinedForwardingMessage, !forward.subForwardingMessages.isEmpty {
            let forwardContent = forward.subForwardingMessages.reduce("") { partialResult, message in
                return partialResult + " " + (message.body ?? "")
            }
            content += " " + forwardContent
        }
        
        let ftsContent = content.lowercased()
        guard checkShouldUpdate(inserted: inserted, model: message, ftsContent: ftsContent) else {
//            Logger.info("Skipping MessageSecondary FTS update")
            return nil;
        }
        
        let messageSecondary = TSMessageSecondary.init(uniqueId: message.uniqueId, message: content.lowercased(), thread: message.uniqueThreadId, timestamp: String(describing: message.timestampForSorting()), display: (message.isDisplay ? true : false))
        return messageSecondary
    }
    
    private class func handleGroupThreadSecondary(inserted: Bool, thread: TSGroupThread, transaction: GRDBWriteTransaction) -> Void {
            
        guard let name = thread.groupModel.groupName else {
            return
        }
        
        let groupName = name.lowercased()
        
        var groupMemberIds = thread.groupModel.groupMemberIds
        if groupMemberIds.count > 50 {
            groupMemberIds = Array(groupMemberIds.prefix(50))
        }
        
        let members = groupMemberIds.reduce("", { result, uniqueId in
            
            guard let account = SignalAccount.anyFetch(uniqueId: uniqueId, transaction: transaction.asAnyWrite),
                    let contact = account.contact else {
                return result
            }
            let append = (contact.fullName) + " " + (account.remarkName ?? "") + " " + (contact.email ?? "") + " " + (account.recipientId)
            return result + " " + append
        }).lowercased()
        let ftsContent = groupName + " " + members
        guard checkShouldUpdate(inserted: inserted, model: thread, ftsContent: ftsContent) else {
//                Logger.info("Skipping GroupThread FTS update")
            return
        }
        let date = thread.lastMessageDate ?? thread.creationDate
        
        let lastMessageDate = String(describing: date.timeIntervalSince1970)
        
        let groupThreadSecondary = TSGroupThreadSecondary.init(uniqueId: thread.uniqueId, lastMessageDate: lastMessageDate, members: members, groupName: groupName)
        
        if(inserted){
            groupThreadSecondary.anyInsert(transaction: transaction.asAnyWrite)
        }else{
            groupThreadSecondary.anyUpsert(transaction: transaction.asAnyWrite)
        }
            
    }
    
    private class func createSignalAccountSecondary(inserted: Bool, account: SignalAccount, transaction: GRDBWriteTransaction) -> SignalAccountSecondary? {
        
        guard !account.recipientId.isEmpty, let contact = account.contact else {
            return nil
        }
        
        let fullName = contact.fullName.lowercased()
        let email = contact.email?.lowercased() ?? ""
        let remarkName = account.remarkName?.lowercased() ?? ""
        let signature = contact.signature?.lowercased() ?? ""
        
        let ftsContent = fullName + " " + email + " " + remarkName + " " + signature
        guard checkShouldUpdate(inserted: inserted, model: account, ftsContent: ftsContent) else {
//            Logger.info("Skipping SignalAccount FTS update")
            return nil;
        }
        
        
        let accountSecondary = SignalAccountSecondary.init(uniqueId: account.uniqueId, fullName: fullName, email: email, remarkName: remarkName, signature: signature, buName: "")
        return accountSecondary
    }

    public class func modelWasInserted(model: SDSIndexableModel, transaction: GRDBWriteTransaction) {
        guard shouldIndexModel(model) else {
            return
        }
        
        if let message = model as? TSMessage {
            
            if let messageSecondary = createMessageSecondary(inserted: true, message: message, transaction: transaction) {
                messageSecondary.anyInsert(transaction: transaction.asAnyWrite)
            }
            
        } else if let thread = model as? TSGroupThread {
            
            handleGroupThreadSecondary(inserted: true, thread: thread, transaction: transaction)
        } else if let account = model as? SignalAccount {
            
            if let accountSecondary = createSignalAccountSecondary(inserted: true, account: account, transaction: transaction) {
                accountSecondary.anyInsert(transaction: transaction.asAnyWrite)
            }
            
        }
        
    }

    public class func modelWasUpdated(model: SDSIndexableModel, transaction: GRDBWriteTransaction) {
        guard shouldIndexModel(model) else {
            return
        }
        
        if let message = model as? TSMessage {
            
            if let messageSecondary = createMessageSecondary(inserted: false, message: message, transaction: transaction) {
                messageSecondary.anyUpsert(transaction: transaction.asAnyWrite)
            }
            
        } else if let thread = model as? TSGroupThread {
            
            handleGroupThreadSecondary(inserted: false, thread: thread, transaction: transaction)
        } else if let account = model as? SignalAccount {
            
            if let accountSecondary = createSignalAccountSecondary(inserted: false, account: account, transaction: transaction) {
                accountSecondary.anyUpsert(transaction: transaction.asAnyWrite)
            }
            
        }
        
    }

    public class func modelWasRemoved(model: SDSIndexableModel, transaction: GRDBWriteTransaction) {
        removeModelFromIndex(model, transaction: transaction)
    }

    private class func removeModelFromIndex(_ model: SDSIndexableModel, transaction: GRDBWriteTransaction) {
        guard shouldIndexModel(model) else {
            return
        }
        if let message = model as? TSMessage {
            
            if let messageSecondary = TSMessageSecondary.anyFetch(uniqueId: message.uniqueId, transaction: transaction.asAnyRead) {
                messageSecondary.anyRemove(transaction: transaction.asAnyWrite)
            }
            
        }
        
        if let thread = model as? TSGroupThread {
            
            if let groupSecondary = TSGroupThreadSecondary.anyFetch(uniqueId: thread.uniqueId, transaction: transaction.asAnyRead) {
                groupSecondary.anyRemove(transaction: transaction.asAnyWrite)
            }
            
        }
        
        if let account = model as? SignalAccount {
            
            if let accountSecondary = SignalAccountSecondary.anyFetch(uniqueId: account.uniqueId, transaction: transaction.asAnyRead) {
                accountSecondary.anyRemove(transaction: transaction.asAnyWrite)
            }
            
        }
    }

    public class func allModelsWereRemoved(collection: String, transaction: GRDBWriteTransaction) {

        if collection ==  TSMessage.collection() {
            TSMessageSecondary.anyRemoveAllWithInstantation(transaction: transaction.asAnyWrite)
        }
        
        if collection ==  TSGroupThread.collection() {
            TSGroupThreadSecondary.anyRemoveAllWithInstantation(transaction: transaction.asAnyWrite)
        }
        
        if collection ==  SignalAccount.collection() {
            SignalAccountSecondary.anyRemoveAllWithInstantation(transaction: transaction.asAnyWrite)
        }
    }
    
    
    
}

@objc
public class AnyFullTextSearchFinder: NSObject {
    public enum LoadStrategy {
        case all
        case limit(count: Int)
    }
    
    // MARK: - Index Building
    static func assembleQuery(strategy: LoadStrategy) -> String {
        guard case .limit(let count) = strategy, count > 0 else {
            return ""
        }
        return """
        LIMIT \(count)
        """
    }
    
    private class var contactsManager: ContactsManagerProtocol {
        return TextSecureKitEnv.shared().contactsManager
    }
    
    // We want to match by prefix for "search as you type" functionality.
    // SQLite does not support suffix or contains matches.
    public class func query(searchText: String) -> String {
        // 1. Normalize the search text.
        //
        // TODO: We could arguably convert to lowercase since the search
        // is case-insensitive.
        let normalizedSearchText = FullTextSearchFinder.normalize(text: searchText)
        let query = "\"\(normalizedSearchText)\"*"
 
        return query
    }

    fileprivate static var charactersToRemove: CharacterSet = {
        // * We want to strip punctuation - and our definition of "punctuation"
        //   is broader than `CharacterSet.punctuationCharacters`.
        // * FTS should be robust to (i.e. ignore) illegal and control characters,
        //   but it's safer if we filter them ourselves as well.
        var charactersToFilter = CharacterSet.punctuationCharacters
        charactersToFilter.formUnion(CharacterSet.illegalCharacters)
        charactersToFilter.formUnion(CharacterSet.controlCharacters)

        // We want to strip all ASCII characters except:
        // * Letters a-z, A-Z
        // * Numerals 0-9
        // * Whitespace
        var asciiToFilter = CharacterSet(charactersIn: UnicodeScalar(0x0)!..<UnicodeScalar(0x80)!)
        assert(!asciiToFilter.contains(UnicodeScalar(0x80)!))
        asciiToFilter.subtract(CharacterSet.alphanumerics)
        asciiToFilter.subtract(CharacterSet.whitespacesAndNewlines)
        charactersToFilter.formUnion(asciiToFilter)

        return charactersToFilter
    }()

    // This is a hot method, especially while running large migrations.
    // Changes to it should go through a profiler to make sure large migrations
    // aren't adversely affected.
    @objc
    public class func normalize(text: String) -> String {
        // 1. Filter out invalid characters.
        let filtered = text.removeCharacters(characterSet: charactersToRemove)

        // 2. Simplify whitespace.
        let simplified = filtered.replaceCharacters(characterSet: .whitespacesAndNewlines,
                                                    replacement: " ")

        // 3. Strip leading & trailing whitespace last, since we may replace
        // filtered characters with whitespace.
        let trimmed = simplified.trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Use canonical mapping.
        //
        // From the GRDB docs:
        //
        // Generally speaking, matches may fail when content and query don’t use
        // the same unicode normalization. SQLite actually exhibits inconsistent
        // behavior in this regard.
        //
        // For example, for aimé to match aimé, they better have the same
        // normalization: the NFC aim\u{00E9} form may not match its NFD aime\u{0301}
        // equivalent. Most strings that you get from Swift, UIKit and Cocoa use NFC,
        // so be careful with NFD inputs (such as strings from the HFS+ file system,
        // or strings that you can’t trust like network inputs). Use
        // String.precomposedStringWithCanonicalMapping to turn a string into NFC.
        //
        // Besides, if you want fi to match the ligature ﬁ (U+FB01), then you need
        // to normalize your indexed contents and inputs to NFKC or NFKD. Use
        // String.precomposedStringWithCompatibilityMapping to turn a string into NFKC.
        let canonical = trimmed.precomposedStringWithCanonicalMapping

        return canonical
    }
    
}

// MARK: - Normalization

extension AnyFullTextSearchFinder {

    private static let groupThreadIndexer: SearchIndexer<TSGroupThread> = SearchIndexer { (groupThread: TSGroupThread, transaction: SDSAnyReadTransaction)  in
        let groupName = groupThread.groupModel.groupName ?? ""

        let memberStrings = groupThread.groupModel.groupMemberIds.map { recipientId in
            groupWithRecipientIndexer.index(recipientId, transaction: transaction)
        }.joined(separator: " ")

        return "\(groupName) \(memberStrings)"
    }

    private static let contactThreadIndexer: SearchIndexer<TSContactThread> = SearchIndexer { (contactThread: TSContactThread, transaction: SDSAnyReadTransaction) in
        let recipientId =  contactThread.contactIdentifier()
        return recipientIndexer.index(recipientId, transaction: transaction)
    }

    private static let recipientIndexer: SearchIndexer<String> = SearchIndexer { (recipientId: String, transaction: SDSAnyReadTransaction) in
        var string = recipientId
        
        let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)

        if let account = account as SignalAccount? {
            
            if let displayName = contactsManager.displayName(forPhoneIdentifier: recipientId, signalAccount: account) {
                string = "\(string) \(displayName.lowercased())"
            }
            
            if let contact = account.contact {
                
                if let signature = contact.signature {
                    string = "\(string) \(signature.lowercased())"
                }
                
                if let email = contact.email {
                    string = "\(string) \(email.lowercased())"
                }
            }
        }
        
        return string
    }
    
    private static let groupWithRecipientIndexer: SearchIndexer<String> = SearchIndexer { (recipientId: String, transaction: SDSAnyReadTransaction) in
        var string = recipientId
        
        let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)
        
        if let account = account as SignalAccount? {
            
            if let displayName = contactsManager.displayName(forPhoneIdentifier: recipientId, signalAccount: account) {
                string = "\(string) \(displayName.lowercased())"
            }
            
            if let contact = account.contact {
                
                if let email = contact.email {
                    string = "\(string) \(email.lowercased())"
                }
            }
        }
        
        return string
    }

    static let messageIndexer: SearchIndexer<TSMessage> = SearchIndexer { (message: TSMessage, transaction: SDSAnyReadTransaction) in
        if let body = message.body, body.count > 0 {
            return body
        }
        if let oversizeText = oversizeText(forMessage: message, transaction: transaction) {
            return oversizeText
        }
        return ""
    }

    private static func oversizeText(forMessage message: TSMessage, transaction: SDSAnyReadTransaction) -> String? {
        guard message.hasAttachments() else {
            return nil
        }
        var oversizeText: String?
        guard let attachment = message.attachment(with: transaction) else {
            // This can happen during the initial save of incoming messages.
            Logger.warn("Could not load attachment for search indexing.")
            return nil
        }
        guard let attachmentStream = attachment as? TSAttachmentStream else {
            return nil
        }
        guard attachmentStream.isOversizeText() else {
            return nil
        }
        guard let text = attachmentStream.readOversizeText() else {
            owsFailDebug("Could not load oversize text attachment")
            return nil
        }
        oversizeText = text
        return oversizeText
    }

    private class func indexContent(object: Any, transaction: SDSAnyReadTransaction) -> String? {
        if let groupThread = object as? TSGroupThread {
            return self.groupThreadIndexer.index(groupThread, transaction: transaction)
        } else if let contactThread = object as? TSContactThread {
            guard contactThread.shouldBeVisible else {
                // If we've never sent/received a message in a TSContactThread,
                // then we want it to appear in the "Other Contacts" section rather
                // than in the "Conversations" section.
                return nil
            }
            return self.contactThreadIndexer.index(contactThread, transaction: transaction)
        } else if let signalAccount = object as? SignalAccount {
            return self.recipientIndexer.index(signalAccount.recipientId, transaction: transaction)
        } else {
            return nil
        }
    }
    
}

extension String {
    func replaceCharacters(characterSet: CharacterSet, replacement: String) -> String {
        let components = self.components(separatedBy: characterSet)
        return components.joined(separator: replacement)
    }

    func removeCharacters(characterSet: CharacterSet) -> String {
        let components = self.components(separatedBy: characterSet)
        return components.joined()
    }
}

public protocol SDSIndexableModel {
    var uniqueId: String { get }
    static var ftsIndexMode: TSFTSIndexMode { get }
    static func collection() -> String
}


private extension TSMessage {
    var isDisplay: Bool {
        
        guard !self.isRecalMessage() else {
            return false
        }
        
        guard !self.isReactionMessage else {
            return false
        }
        
        let type = interactionType()
        
        guard type != .unknown && type != .error && type != .info else {
            return false
        }
        
        return true
    }
}
