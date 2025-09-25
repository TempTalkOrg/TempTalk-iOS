//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

protocol InteractionFinderAdapter {
    associatedtype ReadTransaction

    // MARK: - static methods

    static func fetch(uniqueId: String, transaction: ReadTransaction) throws -> TSInteraction?
    
    static func fetch(uniqueId: String, beforeTimestamp: UInt64, transaction: ReadTransaction) throws -> [TSInteraction]
    
    static func fetchOutgoingMessages(beforeTimestamp: UInt64, transaction: ReadTransaction) throws -> [TSInteraction]
    
    static func fetchIncomingMessages(authorId: String, beforeTimestamp: UInt64, transaction: ReadTransaction) throws -> [TSInteraction]

    static func existsIncomingMessage(timestamp: UInt64, address: String, sourceDeviceId: UInt32, transaction: ReadTransaction) -> Bool

    static func interactions(withTimestamp timestamp: UInt64, filter: @escaping (TSInteraction) -> Bool, transaction: ReadTransaction) throws -> [TSInteraction]

//    static func incompleteCallIds(transaction: ReadTransaction) -> [String]

    static func attemptingOutInteractionIds(transaction: ReadTransaction) -> [String]

    static func unreadCountInAllThreads(readPosition: DTReadPositionEntity, transaction: ReadTransaction) -> UInt

    // The interactions should be enumerated in order from "first to expire" to "last to expire".
    static func enumerateMessagesWithStartedPerConversationExpiration(transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void)

    static func nextMessageWithStartedPerConversationExpirationToExpire(transaction: ReadTransaction) -> TSMessage?
    
    static func fetchAllMessageUniqueIdsWhichFailedToStartExpiring(transaction: ReadTransaction) -> [String]
    
    static func interactionIdsWithExpiredPerConversationExpiration(transaction: ReadTransaction) -> [String]

    static func enumerateMessagesWhichFailedToStartExpiring(transaction: ReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void)
    
    static func interactions(withInteractionIds interactionIds: Set<String>, transaction: ReadTransaction) -> Set<TSInteraction>

    // MARK: - instance methods

    func mostRecentInteractionForInbox(transaction: ReadTransaction) -> TSInteraction?
    func mostRecentInteractionNotContainSystermMessageForInbox(transaction: ReadTransaction) -> TSInteraction?
    func mostClosestTargetInteractionNotContainSystermMessage(serverTimestamp: UInt64,
                                                             transaction: ReadTransaction) throws -> [TSInteraction]?
    func sortIndex(interactionUniqueId: String, transaction: ReadTransaction) throws -> UInt?
    func distanceFromLatest(interactionUniqueId: String, transaction: ReadTransaction) throws -> UInt?
    func count(transaction: ReadTransaction) -> UInt
    func messageNotContainSystemMessagesCount(transaction: ReadTransaction) -> UInt
    func unreadCount(readPosition: DTReadPositionEntity, transaction: ReadTransaction) -> UInt
    func enumerateInteractionIds(transaction: ReadTransaction, block: @escaping (String, UnsafeMutablePointer<ObjCBool>) throws -> Void) throws
    func interactionIds(inRange range: NSRange, transaction: ReadTransaction) throws -> [String]
    func enumerateRecentInteractions(transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    func enumerateRecentWithoutNoteOutgoingMessages(transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    func enumerateInteractions(range: NSRange, transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    func enumerateUnseenInteractions(oldReadPosition: DTReadPositionEntity, newReadPosition: DTReadPositionEntity, transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    func oldestUnseenInteraction(transaction: ReadTransaction) throws -> TSInteraction?
    func latestUnseenInteraction(transaction: ReadTransaction) -> TSInteraction?
    func lastestIncomingInteraction(transaction: ReadTransaction) -> TSIncomingMessage?
    func existsOutgoingMessage(transaction: ReadTransaction) -> Bool
    func outgoingMessageCount(transaction: ReadTransaction) -> UInt

    func interaction(at index: UInt, transaction: ReadTransaction) throws -> TSInteraction?
    
    func unseenMentionedInteractions(transaction: ReadTransaction, block: @escaping (TSIncomingMessage) -> Void)
    
    static func enumerateCardRelatedInteractions(cardUniqueId: String, transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws

    #if DEBUG
    func enumerateUnstartedExpiringMessages(transaction: ReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void)
    #endif
}

// MARK: -

@objc
public class InteractionFinder: NSObject, InteractionFinderAdapter {
    

    let grdbAdapter: GRDBInteractionFinderAdapter
    
    @objc
    public static let messageDatabaseViewExtensionName: String = "TSMessageDatabaseViewExtensionName"
    
    @objc
    public init(threadUniqueId: String) {
        self.grdbAdapter = GRDBInteractionFinderAdapter(threadUniqueId: threadUniqueId)
    }

    // MARK: - static methods

    @objc
    public class func fetchSwallowingErrors(uniqueId: String, transaction: SDSAnyReadTransaction) -> TSInteraction? {
        return fetch(uniqueId: uniqueId, transaction: transaction)
    }
    
    @objc
    public class func fetch(uniqueId: String, transaction: SDSAnyReadTransaction)  -> TSInteraction? {
        do {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try GRDBInteractionFinderAdapter.fetch(uniqueId: uniqueId, transaction: grdbRead)
            }
        } catch {
            owsFailDebug("error: \(error)")
            return nil
        }
    }
    
    @objc
    public class func fetch(uniqueId: String, beforeTimestamp: UInt64, transaction: SDSAnyReadTransaction) -> [TSInteraction] {
        do {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try GRDBInteractionFinderAdapter.fetch(uniqueId: uniqueId, beforeTimestamp: beforeTimestamp, transaction: grdbRead)
            }
        } catch {
            owsFailDebug("error: \(error)")
            return []
        }
    }
    
    @objc
    public class func fetchOutgoingMessages(beforeTimestamp: UInt64, transaction: SDSAnyReadTransaction) -> [TSInteraction] {
        do {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try GRDBInteractionFinderAdapter.fetchOutgoingMessages(beforeTimestamp: beforeTimestamp, transaction: grdbRead)
            }
        } catch {
            owsFailDebug("error: \(error)")
            return []
        }
    }
    
    @objc
    public class func fetchIncomingMessages(authorId: String, beforeTimestamp: UInt64, transaction: SDSAnyReadTransaction) -> [TSInteraction] {
        do {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try GRDBInteractionFinderAdapter.fetchIncomingMessages(authorId: authorId, beforeTimestamp: beforeTimestamp, transaction: grdbRead)
            }
        } catch {
            owsFailDebug("error: \(error)")
            return []
        }
    }

    @objc
    public class func existsIncomingMessage(timestamp: UInt64, address: String, sourceDeviceId: UInt32, transaction: SDSAnyReadTransaction) -> Bool {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.existsIncomingMessage(timestamp: timestamp, address: address, sourceDeviceId: sourceDeviceId, transaction: grdbRead)
        }
    }

    @objc
    public class func interactions(withTimestamp timestamp: UInt64, filter: @escaping (TSInteraction) -> Bool, transaction: SDSAnyReadTransaction) throws -> [TSInteraction] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try GRDBInteractionFinderAdapter.interactions(withTimestamp: timestamp,
                                                                 filter: filter,
                                                                 transaction: grdbRead)
        }
    }

//    @objc
//    public class func incompleteCallIds(transaction: SDSAnyReadTransaction) -> [String] {
//        switch transaction.readTransaction {
//        case .yapRead(let yapRead):
//            return YAPDBInteractionFinderAdapter.incompleteCallIds(transaction: yapRead)
//        case .grdbRead(let grdbRead):
//            break //return GRDBInteractionFinderAdapter.incompleteCallIds(transaction: grdbRead)
//        }
//    }

    @objc
    public class func attemptingOutInteractionIds(transaction: SDSAnyReadTransaction) -> [String] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.attemptingOutInteractionIds(transaction: grdbRead)
        }
    }

    @objc
    public class func unreadCountInAllThreads(readPosition: DTReadPositionEntity, transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.unreadCountInAllThreads(readPosition: readPosition, transaction: grdbRead)
        }
    }

    // The interactions should be enumerated in order from "next to expire" to "last to expire".
    @objc
    public class func enumerateMessagesWithStartedPerConversationExpiration(transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            GRDBInteractionFinderAdapter.enumerateMessagesWithStartedPerConversationExpiration(transaction: grdbRead, block: block)
        }
    }
    
    @objc
    public class func nextMessageWithStartedPerConversationExpirationToExpire(transaction: SDSAnyReadTransaction) -> TSMessage? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.nextMessageWithStartedPerConversationExpirationToExpire(transaction: grdbRead)
        }
    }
    
    @objc
    public class func fetchAllMessageUniqueIdsWhichFailedToStartExpiring(transaction: SDSAnyReadTransaction) -> [String] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.fetchAllMessageUniqueIdsWhichFailedToStartExpiring(transaction: grdbRead)
        }
    }

    @objc
    public class func interactionIdsWithExpiredPerConversationExpiration(transaction: SDSAnyReadTransaction) -> [String] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.interactionIdsWithExpiredPerConversationExpiration(transaction: grdbRead)
        }
    }

    @objc
    public class func enumerateMessagesWhichFailedToStartExpiring(transaction: SDSAnyReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            GRDBInteractionFinderAdapter.enumerateMessagesWhichFailedToStartExpiring(transaction: grdbRead, block: block)
        }
    }
    
    @objc
    public class func interactions(withInteractionIds interactionIds: Set<String>, transaction: SDSAnyReadTransaction) -> Set<TSInteraction> {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBInteractionFinderAdapter.interactions(withInteractionIds: interactionIds, transaction: grdbRead)
        }
    }

    @objc
    public class func findMessage(
        withTimestamp timestamp: UInt64,
        threadId: String,
        author: String,
        transaction: SDSAnyReadTransaction
    ) -> TSMessage? {
        guard timestamp > 0 else {
            owsFailDebug("invalid timestamp: \(timestamp)")
            return nil
        }

        guard !threadId.isEmpty else {
            owsFailDebug("invalid thread")
            return nil
        }

//        guard author.isValid else {
//            owsFailDebug("Invalid author \(author)")
//            return nil
//        }

        let interactions: [TSInteraction]

        do {
            interactions = try InteractionFinder.interactions(
                withTimestamp: timestamp,
                filter: { $0 is TSMessage },
                transaction: transaction
            )
        } catch {
            owsFailDebug("Error loading interactions \(error.localizedDescription)")
            return nil
        }

        for interaction in interactions {
            guard let message = interaction as? TSMessage else {
                owsFailDebug("received unexpected non-message interaction")
                continue
            }

            guard message.uniqueThreadId == threadId else { continue }

            if let incomingMessage = message as? TSIncomingMessage,
                incomingMessage.authorId == author {
                return incomingMessage
            }

//            if let outgoingMessage = message as? TSOutgoingMessage,
//                author.isLocalAddress {
//                return outgoingMessage
//            }
            
            if let outgoingMessage = message as? TSOutgoingMessage {
                return outgoingMessage
            }
        }

        return nil
    }

    // MARK: - instance methods

    @objc
    public func mostRecentInteractionForInbox(transaction: SDSAnyReadTransaction) -> TSInteraction? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.mostRecentInteractionForInbox(transaction: grdbRead)
        }
    }
    
    @objc
    public func mostRecentInteractionNotContainSystermMessageForInbox(transaction: SDSAnyReadTransaction) -> TSInteraction? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.mostRecentInteractionNotContainSystermMessageForInbox(transaction: grdbRead)
        }
    }
    
    func mostClosestTargetInteractionNotContainSystermMessage(serverTimestamp: UInt64,
                                                             transaction: SDSAnyReadTransaction) throws -> [TSInteraction]? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.mostClosestTargetInteractionNotContainSystermMessage(serverTimestamp: serverTimestamp, transaction: grdbRead)
        }
    }

    public func sortIndex(interactionUniqueId: String, transaction: SDSAnyReadTransaction) throws -> UInt? {
        return try Bench(title: "sortIndex") {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try grdbAdapter.sortIndex(interactionUniqueId: interactionUniqueId, transaction: grdbRead)
            }
        }
    }

    @objc
    public func count(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.count(transaction: grdbRead)
        }
    }
    
    @objc
    public func messageNotContainSystemMessagesCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.messageNotContainSystemMessagesCount(transaction: grdbRead)
        }
    }
    
    
    public func distanceFromLatest(interactionUniqueId: String, transaction: SDSAnyReadTransaction) throws -> UInt? {
        return try Bench(title: "InteractionFinder.distanceFromLatest") {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try grdbAdapter.distanceFromLatest(interactionUniqueId: interactionUniqueId, transaction: grdbRead)
            }
        }
    }

    @objc
    public func unreadCount(readPosition: DTReadPositionEntity, transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.unreadCount(readPosition: readPosition, transaction: grdbRead)
        }
    }

    public func enumerateInteractionIds(transaction: SDSAnyReadTransaction, block: @escaping (String, UnsafeMutablePointer<ObjCBool>) throws -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateInteractionIds(transaction: grdbRead, block: block)
        }
    }
    
    public func interactionIds(inRange range: NSRange, transaction: SDSAnyReadTransaction) throws -> [String] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.interactionIds(inRange: range, transaction: grdbRead)
        }
    }

    @objc
    public func enumerateInteractionIds(transaction: SDSAnyReadTransaction, block: @escaping (String, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateInteractionIds(transaction: grdbRead, block: block)
        }
    }

    @objc
    public func enumerateRecentInteractions(transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateRecentInteractions(transaction: grdbRead, block: block)
        }
    }
    
    @objc
    public func enumerateRecentWithoutNoteOutgoingMessages(transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateRecentWithoutNoteOutgoingMessages(transaction: grdbRead, block: block)
        }
    }
    

    public func enumerateInteractions(range: NSRange, transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateInteractions(range: range, transaction: grdbRead, block: block)
        }
    }

    @objc
    public func enumerateUnseenInteractions(oldReadPosition: DTReadPositionEntity, newReadPosition: DTReadPositionEntity, transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.enumerateUnseenInteractions(oldReadPosition: oldReadPosition, newReadPosition: newReadPosition, transaction: grdbRead, block: block)
        }
    }

    public func oldestUnseenInteraction(transaction: SDSAnyReadTransaction) throws -> TSInteraction? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.oldestUnseenInteraction(transaction: grdbRead)
        }
    }
    
    @objc
    public func latestUnseenInteraction(transaction: SDSAnyReadTransaction) -> TSInteraction? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.latestUnseenInteraction(transaction: grdbRead)
        }
    }
    
    @objc
    public func lastestIncomingInteraction(transaction: SDSAnyReadTransaction) -> TSIncomingMessage? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.lastestIncomingInteraction(transaction: grdbRead)
        }
    }

    public func interaction(at index: UInt, transaction: SDSAnyReadTransaction) throws -> TSInteraction? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try grdbAdapter.interaction(at: index, transaction: grdbRead)
        }
    }

    @objc
    public func existsOutgoingMessage(transaction: SDSAnyReadTransaction) -> Bool {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.existsOutgoingMessage(transaction: grdbRead)
        }
    }

    #if DEBUG
    @objc
    public func enumerateUnstartedExpiringMessages(transaction: SDSAnyReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.enumerateUnstartedExpiringMessages(transaction: grdbRead, block: block)
        }
    }
    #endif

    @objc
    public func outgoingMessageCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.outgoingMessageCount(transaction: grdbRead)
        }
    }
    
    @objc
    public func unseenMentionedInteractions(transaction: SDSAnyReadTransaction, block: @escaping (TSIncomingMessage) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.unseenMentionedInteractions(transaction: grdbRead, block: block)
        }
    }
    
    @objc
    public class func enumerateCardRelatedInteractions(cardUniqueId: String, transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            try GRDBInteractionFinderAdapter.enumerateCardRelatedInteractions(cardUniqueId: cardUniqueId, transaction: grdbRead, block: block)
        }
    }
}

// MARK: -

struct GRDBInteractionFinderAdapter: InteractionFinderAdapter {

    typealias ReadTransaction = GRDBReadTransaction

    let threadUniqueId: String
        
    init(threadUniqueId: String) {
        self.threadUniqueId = threadUniqueId
    }

    // MARK: - static methods

    static func fetch(uniqueId: String, transaction: GRDBReadTransaction) throws -> TSInteraction? {
        return TSInteraction.anyFetch(uniqueId: uniqueId, transaction: transaction.asAnyRead)
    }
    
    static func fetch(uniqueId: String, beforeTimestamp: UInt64, transaction: GRDBReadTransaction) throws -> [TSInteraction] {
        
        var interactions = [TSInteraction]()
        
        // 查询比给定时间戳小的第一条消息
        let sqlBefore = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) = ?
            AND \(interactionColumn: .serverTimestamp) < ?
            """
        
        let argumentsBefore: StatementArguments = [
            uniqueId,
            beforeTimestamp
        ]
        
        let cursorBefore = TSInteraction.grdbFetchCursor(sql: sqlBefore,
                                                         arguments: argumentsBefore,
                                                         transaction: transaction)
        
        // 执行查询并将结果添加到数组中
        while let interaction = try cursorBefore.next() {
            interactions.append(interaction)
        }
        return interactions
        
    }
    
    static func fetchOutgoingMessages(beforeTimestamp: UInt64, transaction: GRDBReadTransaction) throws -> [TSInteraction] {
        var interactions = [TSInteraction]()
        
        // 查询比给定时间戳小的第一条消息
        let sqlBefore = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) != ?
            AND \(interactionColumn: .serverTimestamp) < ?
            AND (\(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue))
            """
        
        let threadUniqueId = TSContactThread.threadId(fromContactId: TSAccountManager.localNumber() ?? "")
        
        let argumentsBefore: StatementArguments = [
            threadUniqueId,
            beforeTimestamp
        ]
        
        let cursorBefore = TSInteraction.grdbFetchCursor(sql: sqlBefore,
                                                         arguments: argumentsBefore,
                                                         transaction: transaction)
        
        // 执行查询并将结果添加到数组中
        while let interaction = try cursorBefore.next() {
            interactions.append(interaction)
        }
        return interactions
    }
    
    static func fetchIncomingMessages(authorId: String, beforeTimestamp: UInt64, transaction: GRDBReadTransaction) throws -> [TSInteraction] {
        var interactions = [TSInteraction]()
        
        // 查询比给定时间戳小的第一条消息
        let sqlBefore = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) != ?
            AND \(interactionColumn: .serverTimestamp) < ?
            AND \(interactionColumn: .authorId) == ?
            AND (\(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue))
            """
        
        let threadUniqueId = TSContactThread.threadId(fromContactId: TSAccountManager.localNumber() ?? "")
        
        let argumentsBefore: StatementArguments = [
            threadUniqueId,
            beforeTimestamp,
            authorId
        ]
        
        let cursorBefore = TSInteraction.grdbFetchCursor(sql: sqlBefore,
                                                         arguments: argumentsBefore,
                                                         transaction: transaction)
        
        // 执行查询并将结果添加到数组中
        while let interaction = try cursorBefore.next() {
            interactions.append(interaction)
        }
        return interactions
    }

    static func existsIncomingMessage(timestamp: UInt64, address: String, sourceDeviceId: UInt32, transaction: GRDBReadTransaction) -> Bool {
        var exists = false
        let sql = """
            SELECT EXISTS(
                SELECT 1
                FROM \(InteractionRecord.databaseTableName)
                WHERE \(interactionColumn: .timestamp) = ?
                AND \(interactionColumn: .authorId) = ?
                AND \(interactionColumn: .sourceDeviceId) = ?
            )
        """
        let arguments: StatementArguments = [timestamp, address, sourceDeviceId]
        exists = try! Bool.fetchOne(transaction.database, sql: sql, arguments: arguments) ?? false

        return exists
    }

    static func interactions(withTimestamp timestamp: UInt64, filter: @escaping (TSInteraction) -> Bool, transaction: ReadTransaction) throws -> [TSInteraction] {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .timestamp) = ?
        """
        let arguments: StatementArguments = [timestamp]

        let unfiltered = try TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction).all()
        return unfiltered.filter(filter)
    }
    
    static func attemptingOutInteractionIds(transaction: ReadTransaction) -> [String] {
        let sql: String = """
        SELECT \(interactionColumn: .uniqueId)
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .storedMessageState) = ?
        """
        var result = [String]()
        do {
            result = try String.fetchAll(transaction.database,
                                         sql: sql,
                                         arguments: [TSOutgoingMessageState.sending.rawValue])
        } catch {
            owsFailDebug("error: \(error)")
        }
        return result
    }

    static func unreadCountInAllThreads(readPosition: DTReadPositionEntity, transaction: ReadTransaction) -> UInt {
        
        let maxServerTime = readPosition.maxServerTime
        
        do {
            let sql = """
                SELECT COUNT(*)
                FROM \(InteractionRecord.databaseTableName)
                WHERE \(sqlClauseForUnreadInteractions())
            """
            let arguments: StatementArguments = [maxServerTime]
            
            guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
                owsFailDebug("count was unexpectedly nil")
                return 0
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }

    // The interactions should be enumerated in order from "next to expire" to "last to expire".
    static func enumerateMessagesWithStartedPerConversationExpiration(transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        // NOTE: We DO NOT consult storedShouldStartExpireTimer here;
        //       once expiration has begun we want to see it through.
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .expiresInSeconds) > 0
        AND \(interactionColumn: .expiresAt) > 0
        ORDER BY \(interactionColumn: .expiresAt)
        """
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                var stop: ObjCBool = false
                block(interaction, &stop)
                if stop.boolValue {
                    return
                }
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
    }
    
    // The interactions should be enumerated in order from "next to expire" to "last to expire".
    static func nextMessageWithStartedPerConversationExpirationToExpire(transaction: ReadTransaction) -> TSMessage? {
        // NOTE: We DO NOT consult storedShouldStartExpireTimer here;
        //       once expiration has begun we want to see it through.
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .expiresInSeconds) > 0
        AND \(interactionColumn: .expiresAt) > 0
        ORDER BY \(interactionColumn: .expiresAt)
        """
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                if let message = interaction as? TSMessage {
                    return message
                } else {
                    owsFailDebug("Unexpected object: \(type(of: interaction))")
                }
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
        return nil
    }

    static func fetchAllMessageUniqueIdsWhichFailedToStartExpiring(transaction: ReadTransaction) -> [String] {
        // NOTE: We DO consult storedShouldStartExpireTimer here.
        //       We don't want to start expiration until it is true.
        let sql = """
        SELECT \(interactionColumn: .uniqueId)
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .storedShouldStartExpireTimer) IS TRUE
        AND (
            \(interactionColumn: .expiresAt) IS 0 OR
            \(interactionColumn: .expireStartedAt) IS 0
        )
        """
        do {
            return try String.fetchAll(transaction.database, sql: sql)
        } catch {
            owsFailDebug("error: \(error)")
            return []
        }
    }

    static func interactionIdsWithExpiredPerConversationExpiration(transaction: ReadTransaction) -> [String] {
        // NOTE: We DO NOT consult storedShouldStartExpireTimer here;
        //       once expiration has begun we want to see it through.
        let now: UInt64 = NSDate.ows_millisecondTimeStamp()
        let sql = """
        SELECT \(interactionColumn: .uniqueId)
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .expiresAt) > 0
        AND \(interactionColumn: .expiresAt) <= ?
        """
        let statementArguments: StatementArguments = [
            now
        ]
        var result = [String]()
        do {
            result = try String.fetchAll(transaction.database,
                                         sql: sql,
                                         arguments: statementArguments)
        } catch {
            owsFailDebug("error: \(error)")
        }
        return result
    }

    static func enumerateMessagesWhichFailedToStartExpiring(transaction: ReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void) {
        // NOTE: We DO consult storedShouldStartExpireTimer here.
        //       We don't want to start expiration until it is true.
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .storedShouldStartExpireTimer) IS TRUE
        AND (
            \(interactionColumn: .expiresAt) IS 0 OR
            \(interactionColumn: .expireStartedAt) IS 0
        )
        """
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: [], transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                guard let message = interaction as? TSMessage else {
                    owsFailDebug("Unexpected object: \(interaction)")
                    return
                }
                var stop: ObjCBool = false
                block(message, &stop)
                if stop.boolValue {
                    return
                }
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
    }

    static func interactions(withInteractionIds interactionIds: Set<String>, transaction: GRDBReadTransaction) -> Set<TSInteraction> {
        guard !interactionIds.isEmpty else {
            return []
        }
        
        let sql = """
            SELECT * FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .uniqueId) IN (\(interactionIds.map { "\'\($0)'" }.joined(separator: ",")))
        """
        let arguments: StatementArguments = []
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        var interactions = Set<TSInteraction>()
        do {
            while let interaction = try cursor.next() {
                interactions.insert(interaction)
            }
        } catch {
            owsFailDebug("unexpected error \(error)")
        }
        return interactions
    }
    
    // MARK: - instance methods

    func mostRecentInteractionForInbox(transaction: GRDBReadTransaction) -> TSInteraction? {
        let sql = """
                SELECT *
                FROM \(InteractionRecord.databaseTableName)
                \(sqlThreadUniqueIdCondition())
                AND \(interactionColumn: .errorType) IS NOT ?
                AND \(interactionColumn: .messageType) IS NOT ?
                AND \(interactionColumn: .recall) IS NULL
                ORDER BY \(interactionColumn: .serverTimestamp) DESC
                LIMIT 1
                """
        let arguments: StatementArguments = [threadUniqueId, TSErrorMessageType.nonBlockingIdentityChange.rawValue, TSInfoMessageType.verificationStateChange.rawValue]
        return TSInteraction.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction)
    }
    
    func mostRecentInteractionNotContainSystermMessageForInbox(transaction: GRDBReadTransaction) -> TSInteraction? {
        let sql = """
                SELECT *
                FROM \(InteractionRecord.databaseTableName)
                \(sqlThreadUniqueIdCondition())
                AND \(interactionColumn: .errorType) IS NOT ?
                AND \(interactionColumn: .messageType) IS NOT ?
                AND (\(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
                OR   \(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue))
                ORDER BY \(interactionColumn: .serverTimestamp) DESC
                LIMIT 1
                """
        let arguments: StatementArguments = [threadUniqueId, TSErrorMessageType.nonBlockingIdentityChange.rawValue, TSInfoMessageType.verificationStateChange.rawValue]
        
        return TSInteraction.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction)
    }
    ///最多返回最接近目标消息的两条消息
    func mostClosestTargetInteractionNotContainSystermMessage(serverTimestamp: UInt64,
                                                              transaction: GRDBReadTransaction) throws -> [TSInteraction]? {
        var interactions = [TSInteraction]()
        
        // 查询比给定时间戳小的第一条消息
        let sqlBefore = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) = ?
            AND \(interactionColumn: .errorType) IS NOT ?
            AND \(interactionColumn: .messageType) IS NOT ?
            AND \(interactionColumn: .serverTimestamp) < ?
            ORDER BY \(interactionColumn: .serverTimestamp) DESC
            LIMIT 1
            """
        
        let argumentsBefore: StatementArguments = [
            threadUniqueId,
            TSErrorMessageType.nonBlockingIdentityChange.rawValue,
            TSInfoMessageType.verificationStateChange.rawValue,
            serverTimestamp
        ]
        
        let cursorBefore = TSInteraction.grdbFetchCursor(sql: sqlBefore,
                                                         arguments: argumentsBefore,
                                                         transaction: transaction)
        
        // 执行查询并将结果添加到数组中
        while let interaction = try cursorBefore.next() {
            interactions.append(interaction)
        }
        
        // 查询比给定时间戳大的第一条消息
        let sqlAfter = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) = ?
            AND \(interactionColumn: .errorType) IS NOT ?
            AND \(interactionColumn: .messageType) IS NOT ?
            AND \(interactionColumn: .serverTimestamp) > ?
            ORDER BY \(interactionColumn: .serverTimestamp) ASC
            LIMIT 1
            """
        
        let argumentsAfter: StatementArguments = [
            threadUniqueId,
            TSErrorMessageType.nonBlockingIdentityChange.rawValue,
            TSInfoMessageType.verificationStateChange.rawValue,
            serverTimestamp
        ]
        
        let cursorAfter = TSInteraction.grdbFetchCursor(sql: sqlAfter,
                                                        arguments: argumentsAfter,
                                                        transaction: transaction)
        
        // 执行查询并将结果添加到数组中
        while let interaction = try cursorAfter.next() {
            interactions.append(interaction)
        }
        
        return interactions
    }


    func sortIndex(interactionUniqueId: String, transaction: GRDBReadTransaction) throws -> UInt? {
        
        let sql = """
            SELECT sortIndex
            FROM (
                SELECT
                    ROW_NUMBER() OVER (ORDER BY \(interactionColumn: .serverTimestamp)) - 1 as sortIndex,
                    \(interactionColumn: .serverTimestamp),
                    \(interactionColumn: .uniqueId)
                FROM \(InteractionRecord.databaseTableName)
                \(sqlThreadUniqueIdCondition())
            )
            WHERE \(interactionColumn: .uniqueId) = ?
            """
        var arguments: StatementArguments = [threadUniqueId, interactionUniqueId]
        
        return try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments)
    }
    
    func distanceFromLatest(interactionUniqueId: String, transaction: GRDBReadTransaction) throws -> UInt? {
        guard let serverTimestamp = try UInt64.fetchOne(transaction.database, sql: """
            SELECT \(interactionColumn: .serverTimestamp)
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .uniqueId) = ?
        """, arguments: [interactionUniqueId]) else {
            owsFailDebug("failed to find id for interaction \(interactionUniqueId)")
            return nil
        }
        
        let arguments: StatementArguments = [threadUniqueId, serverTimestamp]
        
        guard let distanceFromLatest = try UInt.fetchOne(transaction.database, sql: """
            SELECT count(*) - 1
            FROM \(InteractionRecord.databaseTableName)
            \(sqlThreadUniqueIdCondition())
            AND \(interactionColumn: .serverTimestamp) >= ?
            ORDER BY \(interactionColumn: .serverTimestamp) DESC
        """, arguments: arguments) else {
            owsFailDebug("failed to find distance from latest message")
            return nil
        }
        
        return distanceFromLatest
    }

    func count(transaction: GRDBReadTransaction) -> UInt {
        do {
            
            let arguments: StatementArguments = [threadUniqueId]
    
            guard let count = try UInt.fetchOne(transaction.database,
                                                sql: """
                SELECT COUNT(*)
                FROM \(InteractionRecord.databaseTableName)
                \(sqlThreadUniqueIdCondition())
                """,
                arguments: arguments) else {
                    throw assertionError("count was unexpectedly nil")
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }
    
    func messageNotContainSystemMessagesCount(transaction: GRDBReadTransaction) -> UInt {
        do {
            
            let arguments: StatementArguments = [threadUniqueId]
            
            guard let count = try UInt.fetchOne(transaction.database,
                                                sql: """
                SELECT COUNT(*)
                FROM \(InteractionRecord.databaseTableName)
                \(sqlThreadUniqueIdCondition())
                AND (\(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
                OR   \(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue))
                """,
                arguments: arguments) else {
                    throw assertionError("count was unexpectedly nil")
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }

    func unreadCount(readPosition: DTReadPositionEntity, transaction: GRDBReadTransaction) -> UInt {
        
        let maxServerTime = readPosition.maxServerTime
        
        do {
            let sql = """
                SELECT COUNT(*)
                FROM \(InteractionRecord.databaseTableName)
                WHERE \(interactionColumn: .threadUniqueId) = ?
                AND \(GRDBInteractionFinderAdapter.sqlClauseForUnreadInteractions())
            """
            let arguments: StatementArguments = [threadUniqueId, maxServerTime]

            guard let count = try UInt.fetchOne(transaction.database,
                                                sql: sql,
                                                arguments: arguments) else {
                    owsFailDebug("count was unexpectedly nil")
                    return 0
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }

    func enumerateInteractionIds(transaction: GRDBReadTransaction, block: @escaping (String, UnsafeMutablePointer<ObjCBool>) throws -> Void) throws {

        let arguments: StatementArguments = [threadUniqueId]
        
        let cursor = try String.fetchCursor(transaction.database,
                                            sql: """
            SELECT \(interactionColumn: .uniqueId)
            FROM \(InteractionRecord.databaseTableName)
            \(sqlThreadUniqueIdCondition())
            ORDER BY \(interactionColumn: .serverTimestamp) DESC
            """,
            arguments: arguments)
        while let uniqueId = try cursor.next() {
            var stop: ObjCBool = false
            try block(uniqueId, &stop)
            if stop.boolValue {
                return
            }
        }
    }

    func enumerateRecentInteractions(transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        """
        let arguments: StatementArguments = [threadUniqueId]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   arguments: arguments,
                                                   transaction: transaction)

        while let interaction = try cursor.next() {
            var stop: ObjCBool = false
            block(interaction, &stop)
            if stop.boolValue {
                return
            }
        }
    }
    
    func enumerateRecentWithoutNoteOutgoingMessages(transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .threadUniqueId) != ?
        AND   \(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue)
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        """
        let arguments: StatementArguments = [threadUniqueId]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   arguments: arguments,
                                                   transaction: transaction)

        while let interaction = try cursor.next() {
            var stop: ObjCBool = false
            block(interaction, &stop)
            if stop.boolValue {
                return
            }
        }
    }

    func enumerateInteractions(range: NSRange, transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        ORDER BY
            CASE
                WHEN \(interactionColumn: .serverTimestamp) = 0 THEN \(interactionColumn: .timestamp)
                ELSE \(interactionColumn: .serverTimestamp)
            END
        LIMIT \(range.length)
        OFFSET \(range.location)
        """
        let arguments: StatementArguments = [threadUniqueId]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   arguments: arguments,
                                                   transaction: transaction)

        while let interaction = try cursor.next() {
            var stop: ObjCBool = false
            block(interaction, &stop)
            if stop.boolValue {
                return
            }
        }
    }
    
    func interactionIds(inRange range: NSRange, transaction: GRDBReadTransaction) throws -> [String] {
        let sql = """
        SELECT \(interactionColumn: .uniqueId)
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        ORDER BY
            CASE
                WHEN \(interactionColumn: .serverTimestamp) = 0 THEN \(interactionColumn: .timestamp)
                ELSE \(interactionColumn: .serverTimestamp)
            END
        LIMIT \(range.length)
        OFFSET \(range.location)
        """
        let arguments: StatementArguments = [threadUniqueId]
        
        return try String.fetchAll(transaction.database,
                                   sql: sql,
                                   arguments: arguments)
    }

    func enumerateUnseenInteractions(oldReadPosition: DTReadPositionEntity, newReadPosition: DTReadPositionEntity, transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {

        let sql = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            \(sqlThreadUniqueIdCondition())
            AND \(GRDBInteractionFinderAdapter.sqlClauseForUnseenInteractions())
            ORDER BY \(interactionColumn: .serverTimestamp)
        """
        let arguments: StatementArguments = [threadUniqueId, oldReadPosition.maxServerTime, newReadPosition.maxServerTime]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let interaction = try cursor.next() {
            var stop: ObjCBool = false
            if interaction as? OWSReadTracking == nil {
                owsFailDebug("Interaction has unexpected type: \(interaction)")
            }
            block(interaction, &stop)
            if stop.boolValue {
                return
            }
        }
    }

    func oldestUnseenInteraction(transaction: GRDBReadTransaction) throws -> TSInteraction? {
        
        
        guard let thread = TSThread.anyFetch(uniqueId: threadUniqueId, transaction: transaction.asAnyRead) else {
            return nil
        }
        
        let maxServerTime = thread.readPositionEntity?.maxServerTime ?? 0
        
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(GRDBInteractionFinderAdapter.sqlClauseForUnreadInteractions())
        ORDER BY \(interactionColumn: .serverTimestamp)
        """
        
        let arguments: StatementArguments = [threadUniqueId, maxServerTime]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        return try cursor.next()
    }
    
    func latestUnseenInteraction(transaction: GRDBReadTransaction) -> TSInteraction? {
        
        
        guard let thread = TSThread.anyFetch(uniqueId: threadUniqueId, transaction: transaction.asAnyRead) else {
            return nil
        }
        
        let maxServerTime = thread.readPositionEntity?.maxServerTime ?? 0
        
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(GRDBInteractionFinderAdapter.sqlClauseForUnreadInteractions())
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        LIMIT 1
        """
        
        let arguments: StatementArguments = [threadUniqueId, maxServerTime]
        
        return TSInteraction.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction)
    }
    
    func lastestIncomingInteraction(transaction: GRDBReadTransaction) -> TSIncomingMessage? {
        
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        LIMIT 1
        """
        
        let arguments: StatementArguments = [threadUniqueId]
        
        return TSIncomingMessage.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction) as? TSIncomingMessage ?? nil
    }

    func interaction(at index: UInt, transaction: GRDBReadTransaction) throws -> TSInteraction? {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        LIMIT 1
        OFFSET ?
        """
        let arguments: StatementArguments = [threadUniqueId, index]
        
        return TSInteraction.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction)
    }

    func existsOutgoingMessage(transaction: GRDBReadTransaction) -> Bool {
        let sql = """
        SELECT EXISTS(
            SELECT 1
            FROM \(InteractionRecord.databaseTableName)
            \(sqlThreadUniqueIdCondition())
            AND \(interactionColumn: .recordType) = ?
            LIMIT 1
        )
        """
        let arguments: StatementArguments = [threadUniqueId, SDSRecordType.outgoingMessage.rawValue]
    
        return try! Bool.fetchOne(transaction.database, sql: sql, arguments: arguments) ?? false
    }

    #if DEBUG
    func enumerateUnstartedExpiringMessages(transaction: GRDBReadTransaction, block: @escaping (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void) {
        // NOTE: We DO consult storedShouldStartExpireTimer here.
        //       We don't want to start expiration until it is true.
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(interactionColumn: .storedShouldStartExpireTimer) IS TRUE
        AND (
            \(interactionColumn: .expiresAt) IS 0 OR
            \(interactionColumn: .expireStartedAt) IS 0
        )
        """
        
        let arguments: StatementArguments = [threadUniqueId]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                guard let message = interaction as? TSMessage else {
                    owsFailDebug("Unexpected object: \(interaction)")
                    return
                }
                var stop: ObjCBool = false
                block(message, &stop)
                if stop.boolValue {
                    return
                }
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
    }
    #endif

    func outgoingMessageCount(transaction: GRDBReadTransaction) -> UInt {
        let sql = """
        SELECT COUNT(*)
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(interactionColumn: .recordType) = ?
        """
        let arguments: StatementArguments = [threadUniqueId, SDSRecordType.outgoingMessage.rawValue]
        
        return try! UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) ?? 0
    }
    
    
    func unseenMentionedInteractions(transaction: GRDBReadTransaction, block: @escaping (TSIncomingMessage) -> Void) {
        
        guard let thread = TSThread.anyFetch(uniqueId: threadUniqueId, transaction: transaction.asAnyRead) else {
            return;
        }
        
        let maxServerTime = thread.readPositionEntity?.maxServerTime ?? 0
        
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        \(sqlThreadUniqueIdCondition())
        AND \(GRDBInteractionFinderAdapter.sqlClauseForUnreadInteractions())
        AND (\(interactionColumn: .mentionedMsgType) IS \(OWSMentionedMsgType.me.rawValue)
        OR \(interactionColumn: .mentionedMsgType) IS \(OWSMentionedMsgType.all.rawValue))
        ORDER BY \(interactionColumn: .serverTimestamp)
        """
        
        let arguments: StatementArguments = [threadUniqueId, maxServerTime]
        
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   arguments: arguments,
                                                   transaction: transaction)

        do {
            while let interaction = try cursor.next() {
                if let incomingMessage = interaction as? TSIncomingMessage {
                    block(incomingMessage)
                }
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
        
        
//        do {
//            try InteractionRecord.fetchCursor(transaction.database, sql: sql, arguments: [threadUniqueId, maxServerTime]).forEach { interactionRecord in
//                if let incomingMessage = try TSIncomingMessage.fromRecord(interactionRecord) as? TSIncomingMessage {
//                    block(incomingMessage)
//                }
//            }
//
//        } catch {
//            owsFailDebug("error: \(error)")
//        }
    }
    
    static func enumerateCardRelatedInteractions(cardUniqueId: String, transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let sql = """
        SELECT *
        FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .cardUniqueId) = ?
        ORDER BY \(interactionColumn: .serverTimestamp) DESC
        """
        let arguments: StatementArguments = [cardUniqueId]
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   arguments: arguments,
                                                   transaction: transaction)

        while let interaction = try cursor.next() {
            var stop: ObjCBool = false
            block(interaction, &stop)
            if stop.boolValue {
                return
            }
        }
    }


    // MARK: - Unseen & Unread
    
    private let sqlClauseForAllUnreadInteractions: String = {
        // The nomenclature we've inherited from our YDB database views is confusing.
        //
        // * "Unseen" refers to "all unread interactions".
        // * "Unread" refers to "unread interactions which affect unread counts".
        //
        // This clause is used for the former case.
        //
        // We can either whitelist or blacklist interactions.
        // It's a lot easier to whitelist.
        //
        // POST GRDB TODO: Rename "unseen" and "unread" finder methods.
        let recordTypes: [SDSRecordType] = [
            .call,
            .incomingMessage,
        ]

        let recordTypesSql = recordTypes.map { "\($0.rawValue)" }.joined(separator: ",")

        return """
        (
            \(interactionColumn: .read) IS 0
            AND \(interactionColumn: .recordType) IN (\(recordTypesSql))
        )
        """
    }()

    
    private static func sqlClauseForUnreadInteractions() -> String {

        return """
        \(interactionColumn: .serverTimestamp) > ?
        AND \(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
        """
    }
    
    private static func sqlClauseForUnseenInteractions() -> String {

        return """
        \(interactionColumn: .serverTimestamp) > ?
        AND \(interactionColumn: .serverTimestamp) <= ?
        AND \(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
        """
    }
    
    private func sqlThreadUniqueIdCondition() -> String {
        return """
        WHERE \(interactionColumn: .threadUniqueId) = ?
        """
    }
}

private func assertionError(_ description: String) -> Error {
    return OWSErrorMakeAssertionError(description)
}
