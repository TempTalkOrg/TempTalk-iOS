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
    associatedtype WriteTransaction

    // MARK: - static methods
    
    static func existsRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : ReadTransaction) -> Bool
    static func duplicateRecallMessage(timestamp: UInt64, sourceId: String, sourceDeviceId: UInt32, transaction : ReadTransaction) -> Bool
    static func enumerateEditableMessagesWithBlock(transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void)
    static func enumerateUnClearedMessagesWithBlock(archived: Bool, transaction: ReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void)
    static func updateUnClearedArchivedMessage(infoMsg: TSInfoMessage, transaction: WriteTransaction) -> Void
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
    
    @objc
    public class func enumerateEditableMessagesWithBlock(transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        
        return GRDBRecallFinderAdapter.enumerateEditableMessagesWithBlock(transaction: transaction.unwrapGrdbRead, block: block)
    }
    
    @objc
    public class func enumerateUnClearedMessagesWithBlock(archived: Bool, transaction: SDSAnyReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        
        return GRDBRecallFinderAdapter.enumerateUnClearedMessagesWithBlock(archived: archived, transaction: transaction.unwrapGrdbRead, block: block)
    }
    
    @objc
    public class func updateUnClearedArchivedMessage(infoMsg: TSInfoMessage, transaction: SDSAnyWriteTransaction) -> Void {
        
        return GRDBRecallFinderAdapter.updateUnClearedArchivedMessage(infoMsg: infoMsg, transaction: transaction.unwrapGrdbWrite)
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
    
    static func enumerateEditableMessagesWithBlock(transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let sql = """
        SELECT message.*
        FROM \(RecallRecord.databaseTableName) recall ,\(InteractionRecord.databaseTableName) message
        WHERE recall.\(recallColumn: .uniqueId) = message.\(interactionColumn: .uniqueId)
        AND recall.\(recallColumn: .editable) IS TRUE
        AND recall.\(recallColumn: .originalSource) = ?
        ORDER BY (message.\(interactionColumn: .serverTimestamp) + 0)
        """
        
        let arguments: StatementArguments = [TSAccountManager.shared.localNumber(with: transaction.asAnyRead)]
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,arguments: arguments , transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                var stop: ObjCBool = false
                block(interaction, &stop)
                if stop.boolValue {
                    return
                }
            }
        } catch {
            Logger.error("error = \(error)")
        }
        
    }
    
    static func enumerateUnClearedMessagesWithBlock(archived: Bool, transaction: GRDBReadTransaction, block: @escaping (TSInteraction, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let msgTableName = archived ? TSInteraction.archivedTableName:InteractionRecord.databaseTableName
        let sql = """
        SELECT message.*
        FROM \(RecallRecord.databaseTableName) recall ,\(msgTableName) message
        WHERE recall.\(recallColumn: .uniqueId) = message.\(interactionColumn: .uniqueId)
        AND recall.\(recallColumn: .originalSource) = ?
        AND recall.\(recallColumn: .editable) IS FALSE
        AND recall.\(recallColumn: .clearFlag) IS NOT TRUE
        ORDER BY message.\(interactionColumn: .serverTimestamp)
        LIMIT 10
        """
        let arguments: StatementArguments = [TSAccountManager.shared.localNumber(with: transaction.asAnyRead)]
        let cursor = TSInteraction.grdbFetchCursor(sql: sql,arguments: arguments , transaction: transaction)
        do {
            while let interaction = try cursor.next() {
                var stop: ObjCBool = false
                block(interaction, &stop)
                if stop.boolValue {
                    return
                }
            }
        } catch {
            Logger.error("error = \(error)")
        }
        
    }
    
    
    static func updateUnClearedArchivedMessage(infoMsg: TSInfoMessage, transaction: GRDBWriteTransaction) -> Void {
        guard let recall = infoMsg.recall else {
            return
        }
        let sql = """
        UPDATE \(TSInteraction.archivedTableName)
        SET \(interactionColumn: .recall) = ?
        WHERE \(interactionColumn: .uniqueId) = ?
        """
        let recallData: Data = NSKeyedArchiver.archivedData(withRootObject: recall)
        let arguments: StatementArguments = [recallData, infoMsg.uniqueId]
        do {
            try transaction.database.execute(sql: sql, arguments: arguments)
        } catch {
            Logger.error("error = \(error)")
        }
        
    }
    
}
