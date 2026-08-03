//
//  DTMultiSelectCopyFormatter.swift
//  Difft
//
//  Formats selected messages into a plain-text clipboard string
//  following the multi-select copy spec (Telegram-style).
//

import Foundation
import TTServiceKit

enum DTMultiSelectCopyFormatter {

    static func format(viewItems: [ConversationViewItem], transaction: SDSAnyReadTransaction) -> String {
        let sorted = viewItems.sorted {
            $0.interaction.compare(forSorting: $1.interaction) != .orderedDescending
        }

        return sorted.enumerated().map { index, viewItem in
            let senderName = senderDisplayName(for: viewItem, transaction: transaction)
            let timestamp = viewItem.interaction.timestamp
            let dateString = formatTimestamp(timestamp)
            let content = contentText(for: viewItem)

            return "\(senderName), [\(dateString)]\n\(content)"
        }.joined(separator: "\n\n")
    }

    // MARK: - Sender name (uses raw name, NOT remark name per PRD §3.3)

    private static func senderDisplayName(for viewItem: ConversationViewItem, transaction: SDSAnyReadTransaction) -> String {
        let authorId: String
        if let incoming = viewItem.interaction as? TSIncomingMessage {
            authorId = incoming.authorId
        } else {
            authorId = TSAccountManager.localNumber() ?? ""
        }

        guard !authorId.isEmpty else { return "" }

        let rawName = TextSecureKitEnv.shared().contactsManager
            .rawDisplayName(forPhoneIdentifier: authorId, transaction: transaction)

        return sanitizeSenderName(rawName)
    }

    private static func sanitizeSenderName(_ name: String) -> String {
        let controlChars = CharacterSet.controlCharacters
        return name.unicodeScalars
            .map { controlChars.contains($0) ? " " : String($0) }
            .joined()
    }

    // MARK: - Timestamp formatting (PRD §3.2)

    private static let monthAbbreviations = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private static func formatTimestamp(_ timestamp: UInt64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let month = monthAbbreviations[(components.month ?? 1) - 1]
        let day = components.day ?? 1
        let year = components.year ?? calendar.component(.year, from: Date())
        let hour = String(format: "%02d", components.hour ?? 0)
        let minute = String(format: "%02d", components.minute ?? 0)

        return "\(month) \(day), \(year) at \(hour):\(minute)"
    }

    // MARK: - Content rendering (PRD §3.4)

    private static var fallbackText: String {
        "[\(Localized("SHORT_FOR_MESSAGE"))]"
    }

    private static func contentText(for viewItem: ConversationViewItem) -> String {
        // A forwarded message (Chat History) copies as its label, never its inner content —
        // consistent with macOS/Android. A single-forward wrapper has only one sub-message,
        // so `messageCellType()` reports `.textMessage` rather than `.combinedForwarding`;
        // key off the data model directly to cover both single and combined forwards.
        if let message = viewItem.interaction as? TSMessage, message.combinedForwardingMessage != nil {
            return "[\(Localized("PLACEHOLDER_WRAPPER_FOR_CHAT_HISTORY"))]"
        }

        switch viewItem.messageCellType() {
        case .textMessage, .oversizeTextMessage:
            return viewItem.displayableBodyText()?.fullText ?? fallbackText

        case .stillImage, .animatedImage:
            return "[\(Localized("SHORT_FOR_IMAGE"))]"

        case .video:
            return "[\(Localized("SHORT_FOR_VIDEO"))]"

        case .audio:
            return fallbackText

        case .genericAttachment:
            return fileContent(for: viewItem)

        case .contactShare:
            return contactCardContent(for: viewItem)

        case .combinedForwarding:
            return "[\(Localized("PLACEHOLDER_WRAPPER_FOR_CHAT_HISTORY"))]"

        case .card:
            return cardContent(for: viewItem)

        case .downloadingAttachment:
            return downloadingAttachmentContent(for: viewItem)

        case .unknown:
            return fallbackText

        @unknown default:
            return fallbackText
        }
    }

    private static func downloadingAttachmentContent(for viewItem: ConversationViewItem) -> String {
        guard let pointer = viewItem.attachmentPointer() else {
            return fallbackText
        }
        let contentType = (pointer.contentType ?? "").lowercased()
        if contentType.hasPrefix("video/") {
            return "[\(Localized("SHORT_FOR_VIDEO"))]"
        }
        if contentType.hasPrefix("image/") {
            return "[\(Localized("SHORT_FOR_IMAGE"))]"
        }
        if contentType.hasPrefix("audio/") {
            return fallbackText
        }
        let label = Localized("SHORT_FOR_ATTACHMENT")
        if let filename = pointer.sourceFilename, !filename.isEmpty {
            return "[\(label): \(filename)]"
        }
        return "[\(label)]"
    }

    private static func fileContent(for viewItem: ConversationViewItem) -> String {
        let label = Localized("SHORT_FOR_ATTACHMENT")
        if let stream = viewItem.attachmentStream(),
           let filename = stream.sourceFilename, !filename.isEmpty {
            return "[\(label): \(filename)]"
        }
        if let pointer = viewItem.attachmentPointer(),
           let filename = pointer.sourceFilename, !filename.isEmpty {
            return "[\(label): \(filename)]"
        }
        return "[\(label)]"
    }

    private static func contactCardContent(for viewItem: ConversationViewItem) -> String {
        let label = Localized("SHORT_FOR_CONTACT_MESSAGE")
        if let contactShare = viewItem.contactShare,
           !contactShare.displayName.isEmpty {
            return "[\(label)] \(contactShare.displayName)"
        }
        return "[\(label)]"
    }

    private static func cardContent(for viewItem: ConversationViewItem) -> String {
        if viewItem.hasBodyText,
           let text = viewItem.displayableBodyText()?.fullText, !text.isEmpty {
            return text
        }
        return fallbackText
    }
}
