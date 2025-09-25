//
//  AttachmentFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/19.
//

import Foundation
import GRDB

protocol AttachmentFinderAdapter {
    associatedtype ReadTransaction

    static func downloadingAttachmentPointerIds(transaction: ReadTransaction) -> [String]

    /// 查找需要删除的附件
    /// 1.已归档消息对应的附件 2.存储超过一定时间的头像
    /// - Parameters:
    ///   - beforeDataTimestamp: 条件 2 对应的早于的这个时间点
    ///   - transaction: transaction
    ///   - block: callback
    static func enumerateNeedDeleteAttachments(beforeDataTimestamp: Double, transaction: ReadTransaction, block: @escaping (TSAttachment, UnsafeMutablePointer<ObjCBool>) -> Void) throws
}

// MARK: -

@objc
public class AttachmentFinder: NSObject, AttachmentFinderAdapter {

//    let grdbAdapter: GRDBAttachmentFinderAdapter
//
//    @objc
//    public init(threadUniqueId: String) {
//        self.grdbAdapter = GRDBAttachmentFinderAdapter(threadUniqueId: threadUniqueId)
//    }

    // MARK: - static methods

    @objc
    public class func downloadingAttachmentPointerIds(transaction: SDSAnyReadTransaction) -> [String] {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return GRDBAttachmentFinderAdapter.downloadingAttachmentPointerIds(transaction: grdbRead)
        }
    }
    
    @objc
    public class func enumerateNeedDeleteAttachments(beforeDataTimestamp: Double, transaction: SDSAnyReadTransaction, block: @escaping (TSAttachment, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return try GRDBAttachmentFinderAdapter.enumerateNeedDeleteAttachments(beforeDataTimestamp: beforeDataTimestamp, transaction: grdbRead, block: block)
        }
    }
}

// MARK: -

struct GRDBAttachmentFinderAdapter: AttachmentFinderAdapter {

    typealias ReadTransaction = GRDBReadTransaction

//    let threadUniqueId: String
//
//    init(threadUniqueId: String) {
//        self.threadUniqueId = threadUniqueId
//    }

    // MARK: - static methods

    static func downloadingAttachmentPointerIds(transaction: ReadTransaction) -> [String] {
        let sql: String = """
        SELECT \(attachmentColumn: .uniqueId)
        FROM \(AttachmentRecord.databaseTableName)
        WHERE \(attachmentColumn: .recordType) = \(SDSRecordType.attachmentPointer.rawValue)
        AND \(attachmentColumn: .state) = ?
        """
        var result = [String]()
        do {
            let cursor = try String.fetchCursor(transaction.database,
                                                sql: sql,
                                                arguments: [TSAttachmentPointerState.downloading.rawValue])
            while let uniqueId = try cursor.next() {
                result.append(uniqueId)
            }
        } catch {
            owsFailDebug("error: \(error)")
        }
        return result
    }

    static func enumerateNeedDeleteAttachments(beforeDataTimestamp: Double, transaction: ReadTransaction, block: @escaping (TSAttachment, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        
        // 无 albumMessageId 表示是头像
        let sql = """
        SELECT *
        FROM \(AttachmentRecord.databaseTableName) ATTACH
        WHERE
            (ATTACH.\(attachmentColumn: .isDownloaded) IS TRUE OR ATTACH.\(attachmentColumn: .isUploaded) IS TRUE) AND
            ATTACH.\(attachmentColumn: .localRelativeFilePath) IS NOT NULL AND
            ATTACH.\(attachmentColumn: .localRelativeFilePath) != '' AND
            (ATTACH.\(attachmentColumn: .creationTimestamp) < ? OR
            EXISTS (
                SELECT 1
                FROM \(TSInteraction.archivedTableName) ARCHIVED
                WHERE ARCHIVED.\(interactionColumn: .uniqueId) = ATTACH.\(attachmentColumn: .albumMessageId)))
        """
        let arguments: StatementArguments = [beforeDataTimestamp]
        let cursor = TSAttachment.grdbFetchCursor(sql: sql,
                                                  arguments: arguments,
                                                  transaction: transaction)
        
        while let attachment = try cursor.next() {
            var stop: ObjCBool = false
            block(attachment, &stop)
            if stop.boolValue {
                return
            }
        }
    }
}


