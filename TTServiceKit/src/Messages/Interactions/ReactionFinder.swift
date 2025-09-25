//
//  ReactionFinder.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/10/22.
//

import Foundation


import Foundation
import GRDB

protocol ReactionFinderAdapter {
    associatedtype ReadTransaction

    // MARK: - static methods
    
    static func findReactionRelatedMessages(timestamp: UInt64, sourceId: String, transaction: ReadTransaction) -> TSMessage?
    static func findReactions(originalUniqueId: String, transaction: ReadTransaction) throws -> [DTReactionMessage]
}

// MARK: -

@objc
public class ReactionFinder: NSObject, ReactionFinderAdapter {
    
    typealias ReadTransaction = SDSAnyReadTransaction
    
    @objc
    public class func findReactionRelatedMessages(timestamp: UInt64, sourceId: String, transaction: SDSAnyReadTransaction) -> TSMessage? {
        return GRDBReactionFinderAdapter.findReactionRelatedMessages(timestamp: timestamp, sourceId: sourceId, transaction: transaction.unwrapGrdbRead)
    }
    
    @objc
    public class func findReactions(originalUniqueId: String, transaction: SDSAnyReadTransaction) throws -> [DTReactionMessage] {
        return try GRDBReactionFinderAdapter.findReactions(originalUniqueId: originalUniqueId, transaction: transaction.unwrapGrdbRead)
    }
    
}

// MARK: -

struct GRDBReactionFinderAdapter: ReactionFinderAdapter {

    typealias ReadTransaction = GRDBReadTransaction
    
    static func findReactionRelatedMessages(timestamp: UInt64, sourceId: String, transaction: GRDBReadTransaction) -> TSMessage? {
        
        var fetched : TSMessage?
        
        do {
            
            fetched = try InteractionFinder.interactions(withTimestamp: timestamp,
                                                          filter: { interaction in
                             
                 if interaction is TSIncomingMessage {
                     let message = interaction as! TSIncomingMessage
                     return message.authorId == sourceId
                 }
                 
                 if interaction is TSOutgoingMessage {
                     return TSAccountManager.localNumber() == sourceId
                 }
                 
                 return false
                             
            }, transaction: transaction.asAnyRead).first as? TSMessage
            
        } catch {
            owsFailDebug("Error loading interactions: \(error)")
        }
        
        return fetched
        
        
    }
    
    static func findReactions(originalUniqueId: String, transaction: GRDBReadTransaction) throws -> [DTReactionMessage] {
        
        let sql = """
        SELECT *
        FROM \(DTReactionMessageRecord.databaseTableName)
        WHERE \(dTReactionMessageColumn: .originalUniqueId) = ?
        """
        let arguments: StatementArguments = [originalUniqueId]
        
        return try DTReactionMessage.grdbFetchCursor(sql: sql, arguments: arguments, transaction: transaction).all()
        
        
    }
    
}
