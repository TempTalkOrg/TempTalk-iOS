//
//  MediaGalleryFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/9.
//

import Foundation
import GRDB

protocol MediaGalleryFinder {
    associatedtype ReadTransaction

    func mostRecentMediaMessage(transaction: ReadTransaction) -> TSMessage?
    func mediaCount(transaction: ReadTransaction) -> UInt
    func mediaIndex(message: TSMessage, transaction: ReadTransaction) -> Int
    func enumerateMediaMessages(range: NSRange, transaction: ReadTransaction, block: @escaping (TSMessage) -> Void)
}

@objc
public class AnyMediaGalleryFinder: NSObject {
    public typealias ReadTransaction = SDSAnyReadTransaction

    public lazy var grdbAdapter: GRDBMediaGalleryFinder = {
        return GRDBMediaGalleryFinder(thread: self.thread)
    }()

    let thread: TSThread
    public init(thread: TSThread) {
        self.thread = thread
    }
}

extension AnyMediaGalleryFinder: MediaGalleryFinder {
    public func mediaIndex(message: TSMessage, transaction: SDSAnyReadTransaction) -> Int {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.mediaIndex(message: message, transaction: grdbRead)
        }
    }

    public func enumerateMediaMessages(range: NSRange, transaction: SDSAnyReadTransaction, block: @escaping (TSMessage) -> Void) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.enumerateMediaMessages(range: range, transaction: grdbRead, block: block)
        }
    }

    public func mediaCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.mediaCount(transaction: grdbRead)
        }
    }

    public func mostRecentMediaMessage(transaction: SDSAnyReadTransaction) -> TSMessage? {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return grdbAdapter.mostRecentMediaMessage(transaction: grdbRead)
        }
    }
}

// MARK: - GRDB

@objc
public class GRDBMediaGalleryFinder: NSObject {
    
    let thread: TSThread
    init(thread: TSThread) {
        self.thread = thread
    }
}

extension GRDBMediaGalleryFinder: MediaGalleryFinder {
    typealias ReadTransaction = GRDBReadTransaction

    func mostRecentMediaMessage(transaction: GRDBReadTransaction) -> TSMessage? {
        let sql = """
            SELECT message.*
            FROM \(AttachmentRecord.databaseTableName) attachment ,\(InteractionRecord.databaseTableName) message
            WHERE attachment.\(attachmentColumn: .albumId) = ?
            AND attachment.\(attachmentColumn: .albumMessageId) = message.\(interactionColumn: .uniqueId)
            AND attachment.\(attachmentColumn: .appearInMediaGallery) IS TRUE
            ORDER BY message.\(interactionColumn: .serverTimestamp) DESC
        """
        let arguments: StatementArguments = [thread.uniqueId]
        if let message = TSMessage.grdbFetchOne(sql: sql, arguments: arguments, transaction: transaction) as? TSMessage {
            return message
        }
        return nil
    }

    func mediaCount(transaction: GRDBReadTransaction) -> UInt {
        let sql = """
            SELECT COUNT(*)
            FROM \(AttachmentRecord.databaseTableName) attachment
            WHERE \(attachmentColumn: .albumId) = ?
            AND \(attachmentColumn: .appearInMediaGallery) IS TRUE
            AND EXISTS (SELECT id
                FROM \(InteractionRecord.databaseTableName) message
                WHERE attachment.\(attachmentColumn: .albumMessageId) = message.\(interactionColumn: .uniqueId))
        """
        
        do {
            guard let count = try UInt.fetchOne(transaction.database, sql: sql, arguments: [thread.uniqueId]) else {
                owsFailDebug("count was unexpectedly nil")
                return 0
            }
            
            return count
            
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }

    }

    func enumerateMediaMessages(range: NSRange, transaction: GRDBReadTransaction, block: @escaping (TSMessage) -> Void) {
        let sql = """
            SELECT message.*
            FROM \(AttachmentRecord.databaseTableName) attachment ,\(InteractionRecord.databaseTableName) message
            WHERE attachment.\(attachmentColumn: .albumId) = ?
            AND attachment.\(attachmentColumn: .albumMessageId) = message.\(interactionColumn: .uniqueId)
            AND attachment.\(attachmentColumn: .appearInMediaGallery) IS TRUE
            ORDER BY attachment.\(attachmentColumn: .id) DESC
            LIMIT \(range.length)
            OFFSET \(range.lowerBound)
        """
        
        do {
            try InteractionRecord.fetchCursor(transaction.database, sql: sql, arguments: [thread.uniqueId]).forEach { interactionRecord in
                if let message = try TSMessage.fromRecord(interactionRecord) as? TSMessage {
                    block(message)
                }
            }
            
        } catch {
            owsFailDebug("error: \(error)")
        }
    }

    func mediaIndex(message: TSMessage, transaction: GRDBReadTransaction) -> Int {
        let sql = """
            SELECT sortIndex
            FROM (
                SELECT
                    (ROW_NUMBER() OVER (ORDER BY \(attachmentColumn: .id) DESC) - 1) as sortIndex, \(attachmentColumn: .albumMessageId)
                FROM \(AttachmentRecord.databaseTableName)
                WHERE \(attachmentColumn: .albumId) = ?
                AND \(attachmentColumn: .appearInMediaGallery) IS TRUE
            )
            WHERE \(attachmentColumn: .albumMessageId) = ?
        """

        let albumId = thread.uniqueId
        
        let albumMessageId = message.uniqueId
        
        do {
            guard let index = try Int.fetchOne(transaction.database, sql: sql, arguments: [albumId, albumMessageId]) else {
                Logger.warn("index was unexpectedly nil")
                return 0
            }
            
            return index
            
        } catch {
            owsFailDebug("error: \(error)")
            return 0
        }
    }
}
