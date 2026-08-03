//
//  DTCopyNoticeTextFormatter.swift
//  TTServiceKit
//

import Foundation

@objcMembers
public final class DTCopyNoticeTextFormatter: NSObject {

    @objc(textWithOperatorId:messageCount:sourceAuthorIds:combinedForwardMode:transaction:)
    public static func text(
        operatorId: String?,
        messageCount: UInt32,
        sourceAuthorIds: [String]?,
        combinedForwardMode: DTForwardNoticeCombinedForwardMode,
        transaction: SDSAnyReadTransaction
    ) -> String {
        let localNumber = TSAccountManager.localNumber()
        let operatorDisplay = DTNoticeAuthorListFormatter.displayName(for: operatorId, localNumber: localNumber, transaction: transaction)
        let isLocalOperator = operatorId != nil && operatorId == localNumber
        let displayedOperator = isLocalOperator ? operatorDisplay : "\"\(operatorDisplay)\""

        let (authorList, hasForeignAuthor) = resolveAuthorList(
            operatorId: operatorId,
            localNumber: localNumber,
            sourceAuthorIds: sourceAuthorIds,
            transaction: transaction
        )

        if combinedForwardMode == .subCombinedForward {
            return formatFromChatHistoryDetail(
                displayedOperator: displayedOperator,
                messageCount: messageCount,
                authorList: authorList,
                hasForeignAuthor: hasForeignAuthor
            )
        } else {
            return formatMainChat(
                displayedOperator: displayedOperator,
                messageCount: messageCount,
                authorList: authorList,
                hasForeignAuthor: hasForeignAuthor
            )
        }
    }

    @objc(textWithOperatorId:messageCount:sourceAuthorIds:transaction:)
    public static func text(
        operatorId: String?,
        messageCount: UInt32,
        sourceAuthorIds: [String]?,
        transaction: SDSAnyReadTransaction
    ) -> String {
        return text(
            operatorId: operatorId,
            messageCount: messageCount,
            sourceAuthorIds: sourceAuthorIds,
            combinedForwardMode: .unknown,
            transaction: transaction
        )
    }

    // MARK: - Format helpers

    private static func formatMainChat(
        displayedOperator: String,
        messageCount: UInt32,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
        if messageCount <= 1 {
            return hasForeignAuthor
                ? String(format: Localized("COPY_NOTICE_SINGLE"), displayedOperator, authorList)
                : String(format: Localized("COPY_NOTICE_SINGLE_NO_FROM"), displayedOperator)
        } else {
            return hasForeignAuthor
                ? String(format: Localized("COPY_NOTICE_PLURAL"), displayedOperator, messageCount, authorList)
                : String(format: Localized("COPY_NOTICE_PLURAL_NO_FROM"), displayedOperator, messageCount)
        }
    }

    private static func formatFromChatHistoryDetail(
        displayedOperator: String,
        messageCount: UInt32,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
        if messageCount <= 1 {
            return hasForeignAuthor
                ? String(format: Localized("COPY_NOTICE_FROM_CHAT_HISTORY_SINGLE"), displayedOperator, authorList)
                : String(format: Localized("COPY_NOTICE_FROM_CHAT_HISTORY_SINGLE_NO_FROM"), displayedOperator)
        } else {
            return hasForeignAuthor
                ? String(format: Localized("COPY_NOTICE_FROM_CHAT_HISTORY_PLURAL"), displayedOperator, authorList, messageCount)
                : String(format: Localized("COPY_NOTICE_FROM_CHAT_HISTORY_PLURAL_NO_FROM"), displayedOperator, messageCount)
        }
    }

    // MARK: - Author list

    private static func resolveAuthorList(
        operatorId: String?,
        localNumber: String?,
        sourceAuthorIds: [String]?,
        transaction: SDSAnyReadTransaction
    ) -> (String, Bool) {
        DTNoticeAuthorListFormatter.resolveAuthorList(
            operatorId: operatorId,
            localNumber: localNumber,
            sourceAuthorIds: sourceAuthorIds,
            transaction: transaction
        )
    }
}
