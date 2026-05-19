//
//  ForwardNoticeBuilder.swift
//  Difft
//
//  Pure helpers for building ForwardNotice payload metadata.
//  No UI / no I/O — safe to call from any actor or queue.
//

import Foundation
import TTServiceKit

enum ForwardNoticeBuilder {

    static func scene(for forwardType: DTForwardMessageType, messageCount: Int) -> DTForwardNoticeScene {
        switch forwardType {
        case .combined:
            return messageCount <= 1 ? .single : .combined
        case .note:
            return .saveToNotes
        case .oneByOne:
            return messageCount <= 1 ? .single : .oneByOne
        @unknown default:
            return .oneByOne
        }
    }

    static func sourceAuthorIds(for messages: [TSMessage]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        func append(_ authorId: String?) {
            guard let authorId, !authorId.isEmpty, !seen.contains(authorId) else { return }
            seen.insert(authorId)
            ordered.append(authorId)
        }

        for message in messages {
            if let incoming = message as? TSIncomingMessage {
                append(incoming.authorId)
            } else {
                append(TSAccountManager.localNumber())
            }
        }

        return ordered
    }
}
