//
//  OWSRecallFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/10/21.
//

import Foundation
import GRDB

protocol RecallFinderAdapter {
    associatedtype ReadTransaction

    // MARK: - static methods
    
    static func existsRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : ReadTransaction) -> Bool
    static func duplicateRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : ReadTransaction) -> Bool
}

// MARK: -

@objc
public class RecallFinder: NSObject, RecallFinderAdapter {
    typealias ReadTransaction = SDSAnyReadTransaction
    
    @objc
    public class func existsRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : SDSAnyReadTransaction) -> Bool {
        return GRDBRecallFinderAdapter.existsRecallMessage(timestamp: timestamp, sourceId: sourceId, sourceDeviceId: sourceDeviceId, transaction: transaction.unwrapGrdbRead)
    }
    
    @objc
    public class func duplicateRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : SDSAnyReadTransaction) -> Bool {
        
        return GRDBRecallFinderAdapter.duplicateRecallMessage(timestamp: timestamp, sourceId: sourceId, sourceDeviceId: sourceDeviceId, transaction: transaction.unwrapGrdbRead)
    }
    
}

// MARK: -

struct GRDBRecallFinderAdapter: RecallFinderAdapter {

    typealias ReadTransaction = GRDBReadTransaction
    
    
    static func existsRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : GRDBReadTransaction) -> Bool {
        var exists = false
        let sql = """
            SELECT EXISTS(
                SELECT 1
                FROM \(RecallRecord.databaseTableName)
                WHERE \(recallColumn: .originalTimestamp) = ?
                AND \(recallColumn: .originalSource) = ?
                AND \(recallColumn: .originalSourceDevice) = ?
            )
        """
        let arguments: StatementArguments = [timestamp, sourceId, sourceDeviceId]
        exists = try! Bool.fetchOne(transaction.database, sql: sql, arguments: arguments) ?? false

        return exists
    }
    
    static func duplicateRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : GRDBReadTransaction) -> Bool {
        var exists = false
        let sql = """
            SELECT EXISTS(
                SELECT 1
                FROM \(RecallRecord.databaseTableName)
                WHERE \(recallColumn: .timestamp) = ?
                AND \(recallColumn: .source) = ?
                AND \(recallColumn: .sourceDevice) = ?
            )
        """
        let arguments: StatementArguments = [timestamp, sourceId, sourceDeviceId]
        exists = try! Bool.fetchOne(transaction.database, sql: sql, arguments: arguments) ?? false

        return exists
        
    }
}
