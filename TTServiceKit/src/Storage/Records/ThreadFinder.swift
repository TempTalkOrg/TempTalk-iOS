//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

public protocol ThreadFinder {
    associatedtype ReadTransaction
//    associatedtype WriteTransaction

    var currentFolder: DTChatFolderEntity? { get }
    func visibleThreadCount(isArchived: Bool, transaction: ReadTransaction) -> UInt
    func enumerateVisibleThreads(isArchived: Bool, range: NSRange, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
    /// enum limit visible threads
    func enumerateVisibleThreads(isArchived: Bool, limit: Int, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
    func enumerateInactiveThreads(transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
    func enumerateVisibleThreads(isArchived: Bool, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
    func enumerateVisibleThreads(limit: Int, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
    func enumerateVisibleThreadIds(isArchived: Bool, transaction: ReadTransaction, block: @escaping (String) -> Void) throws
    func sortIndex(thread: TSThread, transaction: ReadTransaction) throws -> UInt?
    
    func virtualThreadCount(transaction: ReadTransaction) throws -> UInt
    func enumerateVirtualThreads(transaction: ReadTransaction, block: @escaping (DTVirtualThread) -> Void) throws
    
    func visibleThreadUnreadMsgCount(isArchived: Bool, transaction: ReadTransaction) -> UInt
    
    func enumerateVisibleUnreadThreads(isArchived: Bool, transaction: ReadTransaction, block: @escaping (TSThread) -> Void)
    
    func fetchStickedCallingThread(transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws
}

//extension ThreadFinder {
//    public func extensionName() -> String {
//        return TSThreadDatabaseViewExtensionName
//    }
//}

public class AnyThreadFinder: NSObject, ThreadFinder {
    
    
    @objc
    public func visibleThreadUnreadMsgCount(isArchived: Bool, transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return grdbAdapter.visibleThreadUnreadMsgCount(isArchived: isArchived, transaction: grdb)
        }
    }
    
    
    @objc
    public var currentFolder: DTChatFolderEntity? {
        set {
            grdbAdapter.currentFolder = newValue
        }
        get {
            grdbAdapter.currentFolder
        }
    }
    
    
    public typealias ReadTransaction = SDSAnyReadTransaction
//    public typealias WriteTransaction = SDSAnyWriteTransaction

    var grdbAdapter: GRDBThreadFinder = GRDBThreadFinder()
    
    @objc
    public static let inboxGroup = "TSInboxGroup" // Thread-收件箱分组
    
    @objc
    public static let virtualThreadGroup = "DTVirtualThreadGroup" // Thread-虚拟分组（即时会议）
    
    @objc
    public static let archiveGroup = "TSArchiveGroup" // Thread-归档分组
    
    @objc
    public func visibleThreadCount(isArchived: Bool, transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return grdbAdapter.visibleThreadCount(isArchived: isArchived, transaction: grdb)
        }
    }
    
    @objc
    public func enumerateVisibleThreads(isArchived: Bool, range: NSRange, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVisibleThreads(isArchived: isArchived, range: range, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateVisibleThreads(limit: Int, transaction: ReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVisibleThreads(limit: limit, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateVisibleThreads(isArchived: Bool, limit: Int, transaction: SDSAnyReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVisibleThreads(isArchived: isArchived, limit: limit, transaction: grdb, block: block)
        }
    }
        
    @objc
    public func enumerateInactiveThreads(transaction: SDSAnyReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateInactiveThreads(transaction: grdb, block: block)
        }
    }

    @objc
    public func enumerateVisibleThreads(isArchived: Bool, transaction: SDSAnyReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVisibleThreads(isArchived: isArchived, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateVisibleThreadIds(isArchived: Bool, transaction: SDSAnyReadTransaction, block: @escaping (String) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVisibleThreadIds(isArchived: isArchived, transaction: grdb, block: block)
        }
    }
    
    public func virtualThreadCount(transaction: SDSAnyReadTransaction) throws -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return try grdbAdapter.virtualThreadCount(transaction: grdb)
        }
    }

    @objc
    public func enumerateVirtualThreads(transaction: SDSAnyReadTransaction, block: @escaping (DTVirtualThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateVirtualThreads(transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateVisibleUnreadThreads(isArchived: Bool, transaction: SDSAnyReadTransaction, block: @escaping (TSThread) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            grdbAdapter.enumerateVisibleUnreadThreads(isArchived: isArchived, transaction: grdb, block: block)
        }
    }

    @objc
    public func sortIndexObjc(thread: TSThread, transaction: ReadTransaction) -> NSNumber? {
        do {
            guard let value = try sortIndex(thread: thread, transaction: transaction) else {
                return nil
            }
            return NSNumber(value: value)
        } catch {
            owsFailDebug("error: \(error)")
            return nil
        }
    }

    public func sortIndex(thread: TSThread, transaction: SDSAnyReadTransaction) throws -> UInt? {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return try grdbAdapter.sortIndex(thread: thread, transaction: grdb)
        }
    }
    
    @objc
    public func fetchStickedCallingThread(transaction: SDSAnyReadTransaction, block: @escaping (TSThread) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return try grdbAdapter.fetchStickedCallingThread(transaction: grdb, block: block)
        }
    }
}

struct GRDBThreadFinder: ThreadFinder {
    
    func visibleThreadUnreadMsgCount(isArchived: Bool, transaction: GRDBReadTransaction) -> UInt {
        let sql = """
            SELECT SUM(\(threadColumn: .unreadMessageCount))
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
        """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]

        do {
            guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
//                owsFailDebug("count was unexpectedly nil")
                return 0
            }
            return count
        } catch {
            owsFailDebug("error:\(error)")
            
            return 0
        }

    }
    
    
    var currentFolder: DTChatFolderEntity?
    
    typealias ReadTransaction = GRDBReadTransaction
    
    func virtualThreadCount(transaction: GRDBReadTransaction) throws -> UInt {
        
        if currentFolder != nil {
            return 0
        }
        
        let sql = """
            SELECT COUNT(*)
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .recordType) = ?
        """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue]

        guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
            owsFailDebug("count was unexpectedly nil")
            return 0
        }

        return count
    }
    
    func enumerateVirtualThreads(transaction: GRDBReadTransaction, block: @escaping (DTVirtualThread) -> Void) throws {
        
        if currentFolder != nil {
            return
        }
        
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .recordType) = ?
            \(sqlOrderByCondictions())
            """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() as? DTVirtualThread {
            block(thread)
        }

//        try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//            block(try TSThread.fromRecord(threadRecord) as! DTVirtualThread)
//        }
            
    }
    

    func visibleThreadCount(isArchived: Bool, transaction: GRDBReadTransaction) -> UInt {
        /*
        let sql = """
            SELECT COUNT(*)
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
        """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]

        guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
            owsFailDebug("count was unexpectedly nil")
            return 0
        }

        return count
         */
        do {
            let sql = """
                SELECT COUNT(*)
                FROM \(ThreadRecord.databaseTableName)
                WHERE \(threadColumn: .removedFromConversation) = 0
                AND \(threadColumn: .shouldBeVisible) = 1
                AND \(threadColumn: .recordType) != ?
                AND \(threadColumn: .isArchived) = ?
                \(sqlOrderByCondictions())
                """
            let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]

            guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
                owsFailDebug("count was unexpectedly nil")
                return 0
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
        
//
//        try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//            let thread = try? TSThread.fromRecord(threadRecord)
//            if let thread = thread, SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
//                count += 1
//            }
//        }
//
//        return count
    }
    
    func enumerateVisibleThreads(isArchived: Bool, range: NSRange, transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            \(sqlOrderByCondictions())
            LIMIT \(range.length)
            OFFSET \(range.location)
            """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }

//        try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//            let thread = try TSThread.fromRecord(threadRecord)
//            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
//                block(thread)
//            }
//        }
    }

    func enumerateInactiveThreads(transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        
        let groupInterval = DTDisappearanceTimeIntervalConfig.fetchDisappearanceTimeInterval().conversationGroup.doubleValue;
        let contactInterval = DTDisappearanceTimeIntervalConfig.fetchDisappearanceTimeInterval().conversationOthers.doubleValue;
        let currentInterval = NSDate().timeIntervalSince1970
        let groupArchiveT = currentInterval - groupInterval
        let contactArchiveT = currentInterval - contactInterval
                
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .isArchived) = 0
            AND ((\(threadColumn: .recordType) = ? AND \(threadColumn: .lastMessageDate) < ?) OR
                 (\(threadColumn: .recordType) = ? AND \(threadColumn: .lastMessageDate) < ?)
            )
            AND \(threadColumn: .unreadMessageCount) = 0
            AND (\(threadColumn: .stickCallingDate) IS NULL OR \(threadColumn: .stickCallingDate) = 0)
            AND (\(threadColumn: .stickDate) IS NULL OR \(threadColumn: .stickDate) = 0)
            """
        let arguments: StatementArguments = [SDSRecordType.groupThread.rawValue, groupArchiveT, SDSRecordType.contactThread.rawValue, contactArchiveT]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }
    }
    
    func enumerateVisibleThreads(isArchived: Bool, transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            \(sqlOrderByCondictions())
            """
//        LIMIT 500
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }

//        try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//            let thread = try TSThread.fromRecord(threadRecord)
//            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
//                block(thread)
//            }
//        }
    }
    
    func enumerateVisibleThreads(limit: Int = 500, transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            \(sqlOrderByCondictions())
            LIMIT \(limit)
            """
        
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }
    }
    
    func enumerateVisibleThreads(isArchived: Bool, limit: Int = 500, transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            \(sqlOrderByCondictions())
            LIMIT \(limit)
            """
        
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]
        
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }
    }
    
    func enumerateVisibleThreadIds(isArchived: Bool, transaction: GRDBReadTransaction, block: @escaping (String) -> Void) throws {
        let sql = """
            SELECT \(threadColumn: .uniqueId)
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            \(sqlOrderByCondictions())
            """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]
        
        let cursor = try String.fetchCursor(transaction.database,
                                            sql: sql,
                                            arguments: arguments)
        while let uniqueId = try cursor.next() {
            block(uniqueId)
        }

//        try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//            let thread = try TSThread.fromRecord(threadRecord)
//            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
//                block(thread)
//            }
//        }
    }
    
    func enumerateVisibleUnreadThreads(isArchived: Bool, transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) {
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            AND \(threadColumn: .removedFromConversation) = 0
            AND (\(threadColumn: .unreadMessageCount) > 0 OR \(threadColumn: .unreadFlag) = 1)
            \(sqlOrderByCondictions())
            """
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, isArchived]

        do {
            
            let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
            while let thread = try cursor.next() {
                if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                    block(thread)
                }
            }
            
//            try ThreadRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { threadRecord in
//                let thread = try? TSThread.fromRecord(threadRecord)
//                if let thread = thread, SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
//                    block(thread)
//                }
//            }
            
        } catch {
            owsFailDebug("error: \(error)")
        }
        
    }

    func sortIndex(thread: TSThread, transaction: GRDBReadTransaction) throws -> UInt? {
        let sql = """
        SELECT sortIndex
        FROM (
            SELECT
                (ROW_NUMBER() OVER (\(sqlOrderByCondictions()) - 1) as sortIndex,
                \(threadColumn: .id)
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
        )
        WHERE \(threadColumn: .id) = ?
        """
        guard let grdbId = thread.grdbId, grdbId.intValue > 0 else {
            throw OWSAssertionError("grdbId was unexpectedly nil")
        }

        let arguments: StatementArguments = [grdbId.intValue]
        return try UInt.fetchOne(transaction.database, sql: sql, arguments: arguments)
    }
    
    
    func sqlOrderByCondictions() -> String {
        return """
        ORDER BY \(threadColumn: .stickCallingDate) DESC, \(threadColumn: .stickDate) DESC, \(threadColumn: .lastMessageDate) DESC
        """
    }
       
    func fetchStickedCallingThread(transaction: GRDBReadTransaction, block: @escaping (TSThread) -> Void) throws {
        
        let sql = """
            SELECT *
            FROM \(ThreadRecord.databaseTableName)
            WHERE \(threadColumn: .removedFromConversation) = 0
            AND \(threadColumn: .shouldBeVisible) = 1
            AND \(threadColumn: .recordType) != ?
            AND \(threadColumn: .isArchived) = ?
            AND \(threadColumn: .stickCallingDate) > 0
        """
        
        let arguments: StatementArguments = [SDSRecordType.dTVirtualThread.rawValue, false]
        let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction)
        while let thread = try cursor.next() {
            if SDSDataFilter.filterThread(thread, chartFolder: currentFolder, transaction: transaction.asAnyRead) {
                block(thread)
            }
        }
    }
}

