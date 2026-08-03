//
//  DTForwardNoticeTextFormatter.swift
//  TTServiceKit
//

import Foundation

@objc
public enum DTForwardNoticeCombinedForwardMode: Int {
    case unknown = 0
    case containsCombinedForward = 1
    case allCombinedForward = 2
    case subCombinedForward = 3

    public var protoValue: DSKProtoMessageActivityNoticeCombinedForwardMode {
        switch self {
        case .unknown: return .unknown
        case .containsCombinedForward: return .containsCombinedForward
        case .allCombinedForward: return .allCombinedForward
        case .subCombinedForward: return .subCombinedForward
        }
    }

    public init(protoValue: DSKProtoMessageActivityNoticeCombinedForwardMode) {
        switch protoValue {
        case .unknown: self = .unknown
        case .containsCombinedForward: self = .containsCombinedForward
        case .allCombinedForward: self = .allCombinedForward
        case .subCombinedForward: self = .subCombinedForward
        }
    }
}

@objcMembers
public final class DTForwardNoticeTextFormatter: NSObject {

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

        switch combinedForwardMode {
        case .unknown:
            return formatRegular(
                displayedOperator: displayedOperator,
                messageCount: messageCount,
                authorList: authorList,
                hasForeignAuthor: hasForeignAuthor
            )
        case .allCombinedForward:
            return formatAllChatHistory(
                displayedOperator: displayedOperator,
                messageCount: messageCount,
                authorList: authorList,
                hasForeignAuthor: hasForeignAuthor
            )
        case .containsCombinedForward:
            return formatMixed(
                displayedOperator: displayedOperator,
                messageCount: messageCount,
                authorList: authorList,
                hasForeignAuthor: hasForeignAuthor
            )
        case .subCombinedForward:
            return formatFromChatHistoryDetail(
                displayedOperator: displayedOperator,
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

    private static func formatRegular(
        displayedOperator: String,
        messageCount: UInt32,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
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

    private static func formatAllChatHistory(
        displayedOperator: String,
        messageCount: UInt32,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
        if messageCount <= 1 {
            return hasForeignAuthor
                ? String(format: Localized("FORWARD_NOTICE_CHAT_HISTORY_SINGLE"), displayedOperator, authorList)
                : String(format: Localized("FORWARD_NOTICE_CHAT_HISTORY_SINGLE_NO_FROM"), displayedOperator)
        } else {
            return hasForeignAuthor
                ? String(format: Localized("FORWARD_NOTICE_CHAT_HISTORY_PLURAL"), displayedOperator, messageCount, authorList)
                : String(format: Localized("FORWARD_NOTICE_CHAT_HISTORY_PLURAL_NO_FROM"), displayedOperator, messageCount)
        }
    }

    private static func formatMixed(
        displayedOperator: String,
        messageCount: UInt32,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
        return hasForeignAuthor
            ? String(format: Localized("FORWARD_NOTICE_PLURAL_MIXED"), displayedOperator, messageCount, authorList)
            : String(format: Localized("FORWARD_NOTICE_PLURAL_MIXED_NO_FROM"), displayedOperator, messageCount)
    }

    private static func formatFromChatHistoryDetail(
        displayedOperator: String,
        authorList: String,
        hasForeignAuthor: Bool
    ) -> String {
        return hasForeignAuthor
            ? String(format: Localized("FORWARD_NOTICE_FROM_CHAT_HISTORY_SINGLE"), displayedOperator, authorList)
            : String(format: Localized("FORWARD_NOTICE_FROM_CHAT_HISTORY_SINGLE_NO_FROM"), displayedOperator)
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
