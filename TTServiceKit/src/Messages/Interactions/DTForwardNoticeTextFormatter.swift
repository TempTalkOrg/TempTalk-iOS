//
//  DTForwardNoticeTextFormatter.swift
//  TTServiceKit
//
//  Single source of truth for the ForwardNotice system-message text.
//  Shared by the receive path (OWSMessageManager) and the local-insert path
//  used by the forwarder's own device (ForwardNoticeDispatcher), so both
//  render the same phrasing and never drift apart.
//

import Foundation

@objcMembers
public final class DTForwardNoticeTextFormatter: NSObject {
    @objc(textWithOperatorId:messageCount:sourceAuthorIds:transaction:)
    public static func text(
        operatorId: String?,
        messageCount: UInt32,
        sourceAuthorIds: [String]?,
        transaction: SDSAnyReadTransaction
    ) -> String {
        let localNumber = TSAccountManager.localNumber()
        let operatorDisplay = displayName(for: operatorId, localNumber: localNumber, transaction: transaction)
        // "You" 不加引号;其他人名用引号包裹以突出显示
        let isLocalOperator = operatorId != nil && operatorId == localNumber
        let displayedOperator = isLocalOperator ? operatorDisplay : "\"\(operatorDisplay)\""

        let (authorList, hasForeignAuthor) = resolveAuthorList(
            operatorId: operatorId,
            localNumber: localNumber,
            sourceAuthorIds: sourceAuthorIds,
            transaction: transaction
        )

        if messageCount <= 1 {
            return hasForeignAuthor
                ? String(format: Localized("FORWARD_NOTICE_SINGLE"), displayedOperator, authorList)
                : String(format: Localized("FORWARD_NOTICE_SINGLE_NO_FROM"), displayedOperator)
        } else {
            return hasForeignAuthor
                ? String(format: Localized("FORWARD_NOTICE_PLURAL"), displayedOperator, messageCount, authorList)
                : String(format: Localized("FORWARD_NOTICE_PLURAL_NO_FROM"), displayedOperator, messageCount)
        }
    }

    // MARK: - Private helpers

    private static func resolveAuthorList(
        operatorId: String?,
        localNumber: String?,
        sourceAuthorIds: [String]?,
        transaction: SDSAnyReadTransaction
    ) -> (String, Bool) {
        let maxVisible = 3
        var visible: [String] = []
        visible.reserveCapacity(maxVisible)
        var seen = Set<String>()
        var truncated = false
        var hasForeignAuthor = false
        let nonEmptyOperatorId: String? = (operatorId?.isEmpty == false) ? operatorId : nil
        for authorId in sourceAuthorIds ?? [] {
            guard !authorId.isEmpty, !seen.contains(authorId) else { continue }
            seen.insert(authorId)
            if let op = nonEmptyOperatorId {
                if authorId != op { hasForeignAuthor = true }
            } else {
                // Unknown operator: any author should be treated as foreign for safety.
                hasForeignAuthor = true
            }
            if visible.count >= maxVisible {
                truncated = true
                continue
            }
            let name = displayName(for: authorId, localNumber: localNumber, transaction: transaction)
            if !name.isEmpty {
                visible.append(name)
            }
        }
        var list = visible.joined(separator: ", ")
        if truncated {
            list += "..."
        }
        return (list, hasForeignAuthor)
    }

    private static func displayName(
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
}
