//
//  MessageReadPositonFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/4.
//

import Foundation
import GRDB

public protocol MessageReadPositonFinder {
    associatedtype ReadTransaction
    associatedtype WriteTransaction

    func readPositonCount(transaction: ReadTransaction) -> UInt
    func enumerateReadPositons(transaction: ReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws
    func enumerateRecipientReadPositions(uniqueThreadId: String, transaction: ReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws
    func enumerateReadPositions(maxServerTime: UInt64, transaction: ReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws
    
    func latestRecipientReadPosition(uniqueThreadId: String, transaction: ReadTransaction) -> TSMessageReadPosition?
    
    //archived message
    func removeOutmodedReadPositions(timestamp: UInt64, transaction: WriteTransaction ) throws -> Void
    
    func removeArchivedMessageFromMessageTable(transaction: WriteTransaction ) throws -> Void
    
    func enumerateNeedArchivedInteractions(now: UInt64, receipt: String, transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    
}

@objc
public class AnyMessageReadPositonFinder: NSObject, MessageReadPositonFinder {
    
    public typealias ReadTransaction = SDSAnyReadTransaction
    public typealias WriteTransaction = SDSAnyWriteTransaction
    
    let grdbAdapter: GRDBMessageReadPositonFinder = GRDBMessageReadPositonFinder()
    
    @objc
    public func latestRecipientReadPosition(uniqueThreadId: String, transaction: SDSAnyReadTransaction) -> TSMessageReadPosition? {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return grdbAdapter.latestRecipientReadPosition(uniqueThreadId: uniqueThreadId, transaction: grdb)
        }
    }
    
    
    @objc
    public func enumerateNeedArchivedInteractions(now: UInt64, receipt: String, transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateNeedArchivedInteractions(now: now, receipt: receipt, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateReadPositions(maxServerTime: UInt64, transaction: SDSAnyReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateReadPositions(maxServerTime: maxServerTime, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func readPositonCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return grdbAdapter.readPositonCount(transaction: grdb)
        }
    }
    
    @objc
    public func enumerateReadPositons(transaction: SDSAnyReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateReadPositons(transaction: grdb, block: block)
        }
    }
    
    @objc
    public func enumerateRecipientReadPositions(uniqueThreadId: String, transaction: ReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws{
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumerateRecipientReadPositions(uniqueThreadId: uniqueThreadId, transaction: grdb, block: block)
        }
    }
    
    @objc
    public func removeOutmodedReadPositions(timestamp: UInt64, transaction: WriteTransaction ) throws -> Void {
        switch transaction.writeTransaction {
        case .grdbWrite(let grdb):
            try grdbAdapter.removeOutmodedReadPositions(timestamp: timestamp ,transaction: grdb)
        }
    }
    
    @objc
    public func removeArchivedMessageFromMessageTable(transaction: WriteTransaction ) throws -> Void {
        switch transaction.writeTransaction {
        case .grdbWrite(let grdb):
            try grdbAdapter.removeArchivedMessageFromMessageTable(transaction: grdb)
        }
    }
    
}

struct GRDBMessageReadPositonFinder: MessageReadPositonFinder {
    func latestRecipientReadPosition(uniqueThreadId: String, transaction: GRDBReadTransaction) -> TSMessageReadPosition? {
        let sql = """
            SELECT *
            FROM \(MessageReadPositionRecord.databaseTableName)
            WHERE \(messageReadPositionColumn: .uniqueThreadId) = ?
            AND \(messageReadPositionColumn: .recipientId) = ?
            ORDER BY \(messageReadPositionColumn: .maxServerTime) DESC
            LIMIT 1
            """
        let arguments: StatementArguments = [uniqueThreadId, TSAccountManager.localNumber()]
        
        return TSMessageReadPosition.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction)
        
    }
    
    func enumerateReadPositions(maxServerTime: UInt64, transaction: GRDBReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(MessageReadPositionRecord.databaseTableName)
            WHERE \(messageReadPositionColumn: .maxServerTime) = ?
            """
        let arguments: StatementArguments = [maxServerTime]
        
        try MessageReadPositionRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { readPositionRecord in
            block(try TSMessageReadPosition.fromRecord(readPositionRecord))
        }
    }
    
    
    func enumerateRecipientReadPositions(uniqueThreadId: String, transaction: GRDBReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(MessageReadPositionRecord.databaseTableName)
            WHERE \(messageReadPositionColumn: .uniqueThreadId) = ?
            AND \(messageReadPositionColumn: .recipientId) != ?
            ORDER BY \(messageReadPositionColumn: .maxServerTime)
            """
        let arguments: StatementArguments = [uniqueThreadId, TSAccountManager.shared.localNumber(with: transaction.asAnyRead)]
        
        try MessageReadPositionRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { readPositionRecord in
            block(try TSMessageReadPosition.fromRecord(readPositionRecord))
        }
    }
    
    func readPositonCount(transaction: GRDBReadTransaction) -> UInt {
        let sql = """
            SELECT COUNT(*)
            FROM \(MessageReadPositionRecord.databaseTableName)
        """
        
        do {
            guard let count = try UInt.fetchOne(transaction.database, sql: sql) else {
                owsFailDebug("count was unexpectedly nil")
                return 0
            }
            return count
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }
    
    func enumerateReadPositons(transaction: GRDBReadTransaction, block: @escaping (TSMessageReadPosition) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(MessageReadPositionRecord.databaseTableName)
            ORDER BY \(messageReadPositionColumn: .maxServerTime)
            """
        try MessageReadPositionRecord.fetchCursor(transaction.database, sql: sql).forEach { readPositionRecord in
            block(try TSMessageReadPosition.fromRecord(readPositionRecord))
        }
    }
    
    func removeOutmodedReadPositions(timestamp: UInt64, transaction: GRDBWriteTransaction ) throws -> Void{
        let sql = """
            DELETE FROM \(MessageReadPositionRecord.databaseTableName)
            WHERE \(messageReadPositionColumn: .recipientId) = ?
            AND \(messageReadPositionColumn: .creationTimestamp) <= ?
            """
        
        let arguments: StatementArguments = [TSAccountManager.localNumber(), timestamp]
        
        try transaction.database.execute(sql: sql, arguments: arguments)
        
    }
    
    /// 查询过期消息： 1.已读消息 2.已读时间+归档时间 <= 当前时间
    /// - Parameters:
    ///   - now: 当前时间
    ///   - receipt: readPosition belong to receipt
    ///   - transaction: transaction
    ///   - block: block
    func enumerateNeedArchivedInteractions(now: UInt64, receipt: String, transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let sql = """
        SELECT DISTINCT MSG.*
        FROM \(InteractionRecord.databaseTableName) MSG
        JOIN \(MessageReadPositionRecord.databaseTableName) R
          ON R.\(messageReadPositionColumn: .uniqueThreadId) = MSG.\(interactionColumn: .threadUniqueId)
         AND R.\(messageReadPositionColumn: .recipientId) = ?
         AND R.\(messageReadPositionColumn: .maxServerTime) >= MSG.\(interactionColumn: .serverTimestamp)
          JOIN \(ThreadRecord.databaseTableName) S
            ON S.\(threadColumn: .uniqueId) = MSG.\(interactionColumn: .threadUniqueId)
         WHERE S.\(threadColumn: .expiresInSeconds) > 0
           AND (
                  (S.\(threadColumn: .messageClearAnchor) > 0 AND (R.\(messageReadPositionColumn: .readAt) <= S.\(threadColumn: .messageClearAnchor)))
               OR ((R.\(messageReadPositionColumn: .readAt) + S.\(threadColumn: .expiresInSeconds) * 1000) <= ?)
              )
         LIMIT 1000
       """       
        let arguments: StatementArguments = [receipt, now]
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
    
    func removeArchivedMessageFromMessageTable(transaction: GRDBWriteTransaction) throws -> Void {
                
        let sql = """
            DELETE FROM \(InteractionRecord.databaseTableName)
            WHERE EXISTS (SELECT id
                            FROM \(TSInteraction.archivedTableName) archivedMSG
                            WHERE archivedMSG.id = \(InteractionRecord.databaseTableName).id)
            """
        
        try transaction.database.execute(sql: sql)
        
    }
    
    typealias ReadTransaction = GRDBReadTransaction
    typealias WriteTransaction = GRDBWriteTransaction
    
    
}


//extension TSInteraction {
//    public static var archivedTable: SDSTableMetadata {
//        let table = SDSTableMetadata(collection: self.table.collection, tableName: "model_TSInteraction_archived", columns: self.table.columns)
//        return table
//    }
//}

extension TSInteraction {
    public static var archivedTableName: String {
        return "model_TSInteraction_archived"
    }
}
