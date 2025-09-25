//
//  PinnedMessageFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/17.
//

import Foundation
import GRDB

public protocol PinnedMessageFinder {
    
    associatedtype ReadTransaction

    func enumeratePinnedMessages(groupId: String, transaction: ReadTransaction, block: @escaping (DTPinnedMessage) -> Void) throws
    
}

@objc
public class AnyPinnedMessageFinder: NSObject, PinnedMessageFinder {
    
    @objc
    public static let touchPinnedMessageNotification = Notification.Name("touchPinnedMessageNotification")
    
    public typealias ReadTransaction = SDSAnyReadTransaction
    
    let grdbAdapter: GRDBPinnedMessageFinder = GRDBPinnedMessageFinder()
    
    @objc
    public func enumeratePinnedMessages(groupId: String, transaction: SDSAnyReadTransaction, block: @escaping (DTPinnedMessage) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdb):
            try grdbAdapter.enumeratePinnedMessages(groupId: groupId, transaction: grdb, block: block)
        }
    }
    
}

struct GRDBPinnedMessageFinder: PinnedMessageFinder {
    
    typealias ReadTransaction = GRDBReadTransaction
    
    func enumeratePinnedMessages(groupId: String, transaction: GRDBReadTransaction, block: @escaping (DTPinnedMessage) -> Void) throws {
        let sql = """
            SELECT *
            FROM \(DTPinnedMessageRecord.databaseTableName)
            WHERE \(dTPinnedMessageColumn: .groupId) = ?
            ORDER BY \(dTPinnedMessageColumn: .timestampForSorting)
            """
        let arguments: StatementArguments = [groupId]
        
        try DTPinnedMessageRecord.fetchCursor(transaction.database, sql: sql, arguments: arguments).forEach { pinnedMessageRecord in
            block(try DTPinnedMessage.fromRecord(pinnedMessageRecord))
        }
    }
    
    
}
