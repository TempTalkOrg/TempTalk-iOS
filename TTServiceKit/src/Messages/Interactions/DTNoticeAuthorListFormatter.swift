//
//  DTNoticeAuthorListFormatter.swift
//  TTServiceKit
//
//  Shared author-list formatting for copy/forward notice system messages.
//  Implements PRD §5.3.4 rules:
//    - 1–5 people: show all names
//    - ≥6 people: show first 5 + suffix
//    - Chinese suffix: "等 N 人" (N = total count)
//    - English suffix: "and N others" (N = total - 5)
//

import Foundation

public enum DTNoticeAuthorListFormatter {

    private struct AuthorInfo {
        var count: Int = 0
        var isCombinedForwardSender: Bool = false
        var latestTimestamp: UInt64 = 0
    }

    /// Sorted by: combined-forward sender first, then message count desc, then latest timestamp desc.
    public static func sortedAuthorIds(for messages: [TSMessage]) -> [String] {
        guard !messages.isEmpty else { return [] }

        var infoMap: [String: AuthorInfo] = [:]

        for message in messages {
            let authorId: String?
            if let incoming = message as? TSIncomingMessage {
                authorId = incoming.authorId
            } else {
                authorId = TSAccountManager.localNumber()
            }
            guard let authorId, !authorId.isEmpty else { continue }

            var info = infoMap[authorId] ?? AuthorInfo()
            info.count += 1
            if message.combinedForwardingMessage != nil {
                info.isCombinedForwardSender = true
            }
            if message.timestamp > info.latestTimestamp {
                info.latestTimestamp = message.timestamp
            }
            infoMap[authorId] = info
        }

        return infoMap
            .sorted { lhs, rhs in
                let l = lhs.value, r = rhs.value
                if l.isCombinedForwardSender != r.isCombinedForwardSender {
                    return l.isCombinedForwardSender
                }
                if l.count != r.count {
                    return l.count > r.count
                }
                return l.latestTimestamp > r.latestTimestamp
            }
            .map { $0.key }
    }

    /// Authors used for the copy/forward trace DECISION (not the "from" display).
    /// A single carried message that is a single-forward wrapper (`combinedForwardingMessage`
    /// with exactly one sub-message) gates on the ORIGINAL content author
    /// (`subForwardingMessages.first.authorId`), not the bubble sender — copying/forwarding
    /// it carries the original author's content out. All other cases fall back to
    /// `sortedAuthorIds` (bubble senders), so trigger == display there.
    public static func triggerAuthorIds(for messages: [TSMessage]) -> [String] {
        if messages.count == 1,
           let combined = messages[0].combinedForwardingMessage,
           combined.subForwardingMessages.count == 1 {
            let originalAuthorId = combined.subForwardingMessages[0].authorId
            if !originalAuthorId.isEmpty {
                return [originalAuthorId]
            }
        }
        return sortedAuthorIds(for: messages)
    }

    /// Max depth walked when resolving a forwarded tree's original authors.
    private static let maxForwardDepth = 4
    /// Sentinel that forces a trace when a forwarded tree can't be fully resolved. It is never
    /// a real account id and is never displayed — the notice "from" always uses the bubble sender.
    private static let unresolvedForwardMarker = "__dt_unresolved_forward__"

    /// Trigger authors for FORWARD: a forwarded single message or a Chat History carries its
    /// inner real content out, so recurse every layer to the ORIGINAL (leaf) authors — any
    /// foreign leaf means a trace. Unresolvable trees (depth cap / missing author) default to a
    /// trace. Non-forward messages fall back to the bubble author. The "from" display still uses
    /// the bubble sender (handled by callers), so the sentinel/leaf ids never reach the text.
    public static func forwardTriggerAuthorIds(for messages: [TSMessage]) -> [String] {
        guard !messages.isEmpty else { return [] }
        var authorIds: [String] = []
        var incomplete = false
        for message in messages {
            if let combined = message.combinedForwardingMessage {
                // Forwarded message / Chat History → recurse to original leaf authors.
                collectOriginalAuthorIds(combined, depth: 0, into: &authorIds, incomplete: &incomplete)
            } else {
                // Normal message → its bubble author carries the original content out.
                let authorId = (message as? TSIncomingMessage)?.authorId ?? TSAccountManager.localNumber()
                if let authorId, !authorId.isEmpty {
                    authorIds.append(authorId)
                }
            }
        }
        if incomplete {
            authorIds.append(unresolvedForwardMarker)
        }
        return authorIds.isEmpty ? sortedAuthorIds(for: messages) : authorIds
    }

    /// Recursively folds a combined-forward tree's leaf (original) authors into `authorIds`.
    /// A leaf whose nested forward is itself a single/combined forward is followed down. Marks
    /// `incomplete` when the depth cap is hit or a leaf is missing its author.
    private static func collectOriginalAuthorIds(
        _ combined: DTCombinedForwardingMessage,
        depth: Int,
        into authorIds: inout [String],
        incomplete: inout Bool
    ) {
        guard depth < maxForwardDepth else {
            incomplete = true
            return
        }
        for sub in combined.subForwardingMessages {
            if sub.subForwardingMessages.isEmpty {
                if sub.authorId.isEmpty {
                    incomplete = true
                } else {
                    authorIds.append(sub.authorId)
                }
            } else {
                collectOriginalAuthorIds(sub, depth: depth + 1, into: &authorIds, incomplete: &incomplete)
            }
        }
    }

    /// Resolves author IDs into a formatted display list and whether a foreign author exists.
    public static func resolveAuthorList(
        operatorId: String?,
        localNumber: String?,
        sourceAuthorIds: [String]?,
        transaction: SDSAnyReadTransaction
    ) -> (authorList: String, hasForeignAuthor: Bool) {
        let maxVisible = 5
        var visible: [String] = []
        visible.reserveCapacity(maxVisible)
        var seen = Set<String>()
        var totalCount = 0
        var hasForeignAuthor = false
        let nonEmptyOperatorId: String? = (operatorId?.isEmpty == false) ? operatorId : nil

        for authorId in sourceAuthorIds ?? [] {
            guard !authorId.isEmpty, !seen.contains(authorId) else { continue }
            seen.insert(authorId)
            totalCount += 1
            if let op = nonEmptyOperatorId {
                if authorId != op { hasForeignAuthor = true }
            } else {
                hasForeignAuthor = true
            }
            if visible.count < maxVisible {
                let name = displayName(for: authorId, localNumber: localNumber, transaction: transaction)
                if !name.isEmpty {
                    visible.append(name)
                }
            }
        }

        let list = format(visibleNames: visible, totalCount: totalCount)
        return (list, hasForeignAuthor)
    }

    public static func displayName(
        for userId: String?,
        localNumber: String?,
        transaction: SDSAnyReadTransaction
    ) -> String {
        guard let userId, !userId.isEmpty else { return "" }
        if let localNumber, !localNumber.isEmpty, userId == localNumber {
            return Localized("FORWARD_NOTICE_YOU", comment: "You")
        }
        let name = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: userId, transaction: transaction)
        if !name.isEmpty, name != userId {
            return name
        }
        if userId.count > 6 {
            return String(userId.suffix(6))
        }
        return userId
    }

    public static func format(visibleNames: [String], totalCount: Int) -> String {
        guard !visibleNames.isEmpty else { return "" }

        let isChinese = Self.isChineseLocale()

        if totalCount <= 5 {
            return formatAll(names: visibleNames, isChinese: isChinese)
        } else {
            return formatTruncated(names: visibleNames, totalCount: totalCount, isChinese: isChinese)
        }
    }

    // MARK: - Private

    private static func formatAll(names: [String], isChinese: Bool) -> String {
        if isChinese {
            return names.joined(separator: "、")
        }
        switch names.count {
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let allButLast = names.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(names.last!)"
        }
    }

    private static func formatTruncated(names: [String], totalCount: Int, isChinese: Bool) -> String {
        let displayNames = Array(names.prefix(5))

        if isChinese {
            let namesPart = displayNames.joined(separator: "、")
            let suffix = String(format: Localized("FORWARD_NOTICE_AND_N_OTHERS"), UInt32(totalCount))
            return "\(namesPart) \(suffix)"
        } else {
            let othersCount = totalCount - 5
            let namesPart = displayNames.joined(separator: ", ")
            let suffix = String(format: Localized("FORWARD_NOTICE_AND_N_OTHERS"), UInt32(othersCount))
            return "\(namesPart), \(suffix)"
        }
    }

    private static func isChineseLocale() -> Bool {
        return Localize.isChineseLanguage()
    }
}
