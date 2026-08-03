//
//  DTMentionRankProvider.swift
//  TempTalk
//
//  Ranks @-mention candidates for the group member picker: builds a
//  ranking context once when the picker opens, then sorts candidates by
//  mention/speak relevance (and keyword match) on each keystroke without
//  touching the database in the comparator.
//

import Foundation
import TTServiceKit
import TTMessaging

/// Opaque holder of aggregated ranking stats for one picker session.
@objc
public class DTMentionRankContext: NSObject {
    let data: DTMentionRankData
    init(data: DTMentionRankData) {
        self.data = data
        super.init()
    }
}

@objc
public class DTMentionRankProvider: NSObject {

    private static var contactsManager: OWSContactsManager { Environment.shared.contactsManager }

    /// Builds the ranking context inside a read transaction. Call once when the picker opens.
    @objc(buildContextWithThreadId:transaction:)
    public static func buildContext(threadId: String, transaction: SDSAnyReadTransaction) -> DTMentionRankContext {
        let data = DTMentionRankStore.aggregate(threadUniqueId: threadId, transaction: transaction)
        return DTMentionRankContext(data: data)
    }

    /// Filters (by keyword) and sorts group-member candidates using the prebuilt context.
    /// Empty `searchText` keeps all candidates and applies pure relevance ranking.
    @objc(sortMentionCandidates:searchText:context:transaction:)
    public static func sortMentionCandidates(_ accounts: [SignalAccount],
                                             searchText: String,
                                             context: DTMentionRankContext,
                                             transaction: SDSAnyReadTransaction) -> [SignalAccount] {
        let data = context.data
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !query.isEmpty

        var keys = [RankKey]()
        keys.reserveCapacity(accounts.count)
        for account in accounts {
            let uid = account.recipientId
            var matchTier = 0
            if hasQuery {
                guard let tier = bestMatchTier(for: account, uid: uid, query: query, transaction: transaction) else {
                    continue // no keyword match: excluded
                }
                matchTier = tier
            }
            let c24 = data.count24h[uid] ?? 0
            let c14 = data.count14d[uid] ?? 0
            let lastSpeak = data.lastSpeakTime[uid] ?? 0
            let relevanceTier: Int
            if c24 > 0 { relevanceTier = 0 }
            else if c14 > 0 { relevanceTier = 1 }
            else if lastSpeak > 0 { relevanceTier = 2 }
            else { relevanceTier = 3 }
            let display = (contactsManager.formattedFullName(forRecipientId: uid, transaction: transaction) ?? uid)
            keys.append(RankKey(account: account,
                                uid: uid,
                                matchTier: matchTier,
                                relevanceTier: relevanceTier,
                                lastMentionTime: data.lastMentionTime[uid] ?? 0,
                                count24h: c24,
                                count14d: c14,
                                lastSpeakTime: lastSpeak,
                                compareName: sortKey(for: display)))
        }

        keys.sort(by: isBefore)
        return keys.map { $0.account }
    }

    /// recipientIds whose display name collides with another candidate,
    /// so the caller can disambiguate them with an ID suffix.
    @objc(duplicateDisplayNameRecipientIdsIn:transaction:)
    public static func duplicateDisplayNameRecipientIds(_ accounts: [SignalAccount],
                                                        transaction: SDSAnyReadTransaction) -> Set<String> {
        var nameToIds = [String: [String]]()
        for account in accounts {
            let uid = account.recipientId
            let name = (contactsManager.formattedFullName(forRecipientId: uid, transaction: transaction) ?? uid).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            nameToIds[name, default: []].append(uid)
        }
        var result = Set<String>()
        for (_, ids) in nameToIds where ids.count > 1 {
            result.formUnion(ids)
        }
        return result
    }

    // MARK: - Private

    private struct RankKey {
        let account: SignalAccount
        let uid: String
        let matchTier: Int
        let relevanceTier: Int
        let lastMentionTime: UInt64
        let count24h: Int
        let count14d: Int
        let lastSpeakTime: UInt64
        let compareName: String // pinyin sort key
    }

    /// Romanizes CJK to pinyin so Chinese names collate with Latin names (per PRD:
    /// Chinese by pinyin, English by letter, base58 id by string). Latin/digit input
    /// passes through unchanged since CFStringTransform only affects CJK.
    private static func sortKey(for name: String) -> String {
        let mutable = NSMutableString(string: name) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Best match tier across remark > name > base58 id (per PRD field list); nil when nothing matches.
    private static func bestMatchTier(for account: SignalAccount, uid: String, query: String, transaction: SDSAnyReadTransaction) -> Int? {
        var fields = [String]()
        if let remark = account.remarkName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !remark.isEmpty { fields.append(remark) }
        let name = contactsManager.rawDisplayName(forPhoneIdentifier: uid, transaction: transaction).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { fields.append(name) }
        fields.append(uid.lowercased())

        var best: Int?
        for field in fields {
            let tier: Int?
            if field == query { tier = 0 }
            else if field.hasPrefix(query) { tier = 1 }
            else if field.contains(query) { tier = 2 }
            else { tier = nil }
            if let tier, tier < (best ?? Int.max) { best = tier }
        }
        if let best { return best }

        // Multi-token fallback: every whitespace-separated token must appear in some
        // field (order-independent AND), matching the old full-text search behavior.
        let tokens = query.split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return nil }
        let matchesAll = tokens.allSatisfy { token in fields.contains { $0.contains(token) } }
        return matchesAll ? 2 : nil
    }

    private static func isBefore(_ a: RankKey, _ b: RankKey) -> Bool {
        // Keyword match precedes relevance; both precede in-tier ordering.
        if a.matchTier != b.matchTier { return a.matchTier < b.matchTier }
        if a.relevanceTier != b.relevanceTier { return a.relevanceTier < b.relevanceTier }
        switch a.relevanceTier {
        case 0: // 24h mentions: recency, then counts, then last speak
            if a.lastMentionTime != b.lastMentionTime { return a.lastMentionTime > b.lastMentionTime }
            if a.count24h != b.count24h { return a.count24h > b.count24h }
            if a.count14d != b.count14d { return a.count14d > b.count14d }
            if a.lastSpeakTime != b.lastSpeakTime { return a.lastSpeakTime > b.lastSpeakTime }
        case 1: // 14d mentions: count, then last speak
            if a.count14d != b.count14d { return a.count14d > b.count14d }
            if a.lastSpeakTime != b.lastSpeakTime { return a.lastSpeakTime > b.lastSpeakTime }
        case 2: // spoke but no mention: last speak
            if a.lastSpeakTime != b.lastSpeakTime { return a.lastSpeakTime > b.lastSpeakTime }
        default:
            break
        }
        // Name fallback: compareName is already a pinyin sort key, so a plain string
        // compare gives pinyin/letter order; base58 uid is the final tiebreak.
        if a.compareName != b.compareName { return a.compareName < b.compareName }
        return a.uid < b.uid
    }
}
