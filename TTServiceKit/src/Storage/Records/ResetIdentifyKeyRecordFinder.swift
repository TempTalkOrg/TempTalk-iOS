//
//  ResetIdentifyKeyRecordFinder.swift
//  Pods
//
//  Created by Henry on 2025/7/30.
//

import Foundation
import GRDB

public protocol ResetIdentifyKeyRecordFinder {
    associatedtype ReadTransaction
    associatedtype WriteTransaction
    // 查询所有未完成的数据库
    static func fetchResetKeyRecords(transaction: ReadTransaction) throws -> [ResetIdentifyKeyRecord]
    // 获取数据库最新的时间戳
    static func lastResetKeyRecord(transaction: ReadTransaction) -> UInt64
    // 修改已操作完成的数据
    static func updateResetKeyCompleted(operationId: String, resetIdentifyKeyTime: UInt64, transaction: WriteTransaction) throws
    
}

@objc
public class AnyResetIdentifyKeyRecordFinder: NSObject, ResetIdentifyKeyRecordFinder {
    public typealias ReadTransaction = SDSAnyReadTransaction
    
    var grdbAdapter: GRDBResetIdentifyKeyRecordFinder = GRDBResetIdentifyKeyRecordFinder()
    
    @objc
    static public func fetchResetKeyRecords(transaction: SDSAnyReadTransaction) throws -> [ResetIdentifyKeyRecord] {
        do {
            switch transaction.readTransaction {
            case .grdbRead(let grdbRead):
                return try GRDBResetIdentifyKeyRecordFinder.fetchResetKeyRecords(transaction: grdbRead)
            }
        } catch {
            owsFailDebug("error: \(error)")
            return []
        }
    }
    
    @objc
    static public func lastResetKeyRecord(transaction: SDSAnyReadTransaction) -> UInt64 {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            return GRDBResetIdentifyKeyRecordFinder.lastResetKeyRecord(transaction: grdb)
        }
    }
    
    static public func updateResetKeyCompleted(operationId: String, resetIdentifyKeyTime: UInt64, transaction: SDSAnyWriteTransaction) throws {
        switch transaction.writeTransaction {
        case .grdbWrite(let grdb):
            try GRDBResetIdentifyKeyRecordFinder.updateResetKeyCompleted(operationId: operationId, resetIdentifyKeyTime: resetIdentifyKeyTime, transaction: grdb)
        }
    }
    
}


struct GRDBResetIdentifyKeyRecordFinder: ResetIdentifyKeyRecordFinder {
    typealias ReadTransaction = GRDBReadTransaction
    
    static func fetchResetKeyRecords(transaction: GRDBReadTransaction) throws -> [ResetIdentifyKeyRecord] {
        var records = [ResetIdentifyKeyRecord]()
        let sql = """
            SELECT *
            FROM \(ResetIdentifyKeyRecord.databaseTableName)
            WHERE \(ResetIdentifyKeyRecord.columnName(.isCompleted)) = ?
            ORDER BY \(ResetIdentifyKeyRecord.columnName(.resetIdentifyKeyTime)) ASC
            """
        let arguments: StatementArguments = [0]
        
        do {
            let cursor = try ResetIdentifyKeyRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments)
            while let record = try cursor.next() {
                records.append(record)
            }
        } catch {
            owsFailDebug("unexpected error \(error)")
        }
        return records
    }
    
    
    static func lastResetKeyRecord(transaction: GRDBReadTransaction) -> UInt64 {
        let sql = """
            SELECT resetIdentifyKeyTime
            FROM \(ResetIdentifyKeyRecord.databaseTableName)
            ORDER BY \(ResetIdentifyKeyRecord.columnName(.resetIdentifyKeyTime)) DESC
            LIMIT 1
            """
        let arguments: StatementArguments = []
        
        do {
            guard let time = try UInt64.fetchOne(transaction.database, sql: sql, arguments: arguments) else {
                return 0
            }
            return time
        } catch {
            owsFailDebug("error:\(error)")
            return 0
        }
    }
    
    static func updateResetKeyCompleted(operationId: String, resetIdentifyKeyTime: UInt64, transaction: GRDBWriteTransaction) throws {
        let sql = """
            UPDATE \(ResetIdentifyKeyRecord.databaseTableName)
            SET \(ResetIdentifyKeyRecord.columnName(.isCompleted)) = 1
            WHERE \(ResetIdentifyKeyRecord.columnName(.operatorId)) = ? 
            AND \(ResetIdentifyKeyRecord.columnName(.resetIdentifyKeyTime)) = ? 
        """
        let arguments: StatementArguments = [operationId, resetIdentifyKeyTime]
        
        transaction.executeUpdate(sql: sql, arguments: arguments)
    }
}
