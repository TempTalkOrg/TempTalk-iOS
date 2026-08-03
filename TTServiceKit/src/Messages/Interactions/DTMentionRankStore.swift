//
//  DTMentionRankStore.swift
//  TTServiceKit
//
//  Local aggregation of @-mention ranking stats for a group thread.
//  All data is local, scoped to one thread, and mention history counts
//  only the current user's own outgoing messages.
//

import Foundation
import GRDB
import SignalCoreKit

/// Aggregated mention/speak stats for one thread, keyed by member recipientId.
public struct DTMentionRankData {
    /// Most recent self-mention time (effective sort ts) within the 14d window.
    public let lastMentionTime: [String: UInt64]
    /// Self-mention count within the last 24 hours.
    public let count24h: [String: Int]
    /// Self-mention count within the last 14 days.
    public let count14d: [String: Int]
    /// Last locally-visible message time; others keyed by authorId, self keyed by localNumber.
    public let lastSpeakTime: [String: UInt64]
}

private let moduleTag = "[DTMentionRank]"

/// Builds `DTMentionRankData` from local message history using GRDB.
public enum DTMentionRankStore {

    private static let dayMs: UInt64 = 24 * 60 * 60 * 1000
    private static let window14dMs: UInt64 = 14 * dayMs
    private static let window24hMs: UInt64 = dayMs

    public static func aggregate(threadUniqueId: String, transaction: SDSAnyReadTransaction) -> DTMentionRankData {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            return aggregate(threadUniqueId: threadUniqueId, transaction: grdbRead)
        }
    }

    static func aggregate(threadUniqueId: String, transaction: GRDBReadTransaction) -> DTMentionRankData {
        let now = NSDate.ows_millisecondTimeStamp()
        let cutoff14d = now > window14dMs ? now - window14dMs : 0
        let cutoff24h = now > window24hMs ? now - window24hMs : 0

        var lastMentionTime = [String: UInt64]()
        var count24h = [String: Int]()
        var count14d = [String: Int]()
        var lastSpeakTime = [String: UInt64]()

        // Effective sort timestamp, matching TSInteraction.timestampForSorting.
        let effectiveTs = "CASE WHEN \(interactionColumn: .serverTimestamp) = 0 THEN \(interactionColumn: .timestamp) ELSE \(interactionColumn: .serverTimestamp) END"

        // 1) Mentions from the current user's own outgoing messages in the 14d window.
        let mentionSql = """
            SELECT *
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) == ?
            AND \(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue)
            AND \(interactionColumn: .mentions) IS NOT NULL
            AND (\(effectiveTs)) >= ?
            """
        let mentionCursor = TSInteraction.grdbFetchCursor(sql: mentionSql,
                                                          arguments: [threadUniqueId, cutoff14d],
                                                          transaction: transaction)
        do {
            while let interaction = try mentionCursor.next() {
                guard let outgoing = interaction as? TSOutgoingMessage,
                      let mentions = outgoing.mentions, !mentions.isEmpty else { continue }
                let ts = outgoing.timestampForSorting()
                // Dedup per message so a member mentioned twice counts once.
                var uids = Set<String>()
                for mention in mentions {
                    let uid = mention.uid
                    guard !uid.isEmpty, uid != MENTIONS_ALL else { continue }
                    uids.insert(uid)
                }
                let within24h = ts >= cutoff24h
                for uid in uids {
                    count14d[uid, default: 0] += 1
                    if within24h { count24h[uid, default: 0] += 1 }
                    if ts > (lastMentionTime[uid] ?? 0) { lastMentionTime[uid] = ts }
                }
            }
        } catch {
            Logger.error("\(moduleTag) mention aggregate failed: \(error)")
        }

        // 2) Last speak time for other members (incoming), grouped by author.
        let incomingSql = """
            SELECT \(interactionColumn: .authorId) AS authorId, MAX(\(effectiveTs)) AS maxTs
            FROM \(InteractionRecord.databaseTableName)
            WHERE \(interactionColumn: .threadUniqueId) == ?
            AND \(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue)
            AND (\(effectiveTs)) >= ?
            GROUP BY \(interactionColumn: .authorId)
            """
        do {
            let rows = try Row.fetchAll(transaction.database, sql: incomingSql, arguments: [threadUniqueId, cutoff14d])
            for row in rows {
                guard let authorId: String = row["authorId"], !authorId.isEmpty else { continue }
                let maxTs: UInt64 = row["maxTs"] ?? 0
                if maxTs > 0 { lastSpeakTime[authorId] = maxTs }
            }
        } catch {
            Logger.error("\(moduleTag) incoming speak aggregate failed: \(error)")
        }

        // 3) Last speak time for the current user (own outgoing), keyed to localNumber.
        if let localNumber = TSAccountManager.localNumber() {
            let outgoingSql = """
                SELECT MAX(\(effectiveTs)) AS maxTs
                FROM \(InteractionRecord.databaseTableName)
                WHERE \(interactionColumn: .threadUniqueId) == ?
                AND \(interactionColumn: .recordType) IS \(SDSRecordType.outgoingMessage.rawValue)
                """
            do {
                if let maxTs = try UInt64.fetchOne(transaction.database, sql: outgoingSql, arguments: [threadUniqueId]), maxTs > 0 {
                    lastSpeakTime[localNumber] = maxTs
                }
            } catch {
                Logger.error("\(moduleTag) outgoing speak aggregate failed: \(error)")
            }
        }

        return DTMentionRankData(lastMentionTime: lastMentionTime,
                                 count24h: count24h,
                                 count14d: count14d,
                                 lastSpeakTime: lastSpeakTime)
    }
}
