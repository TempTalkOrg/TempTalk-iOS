//
//  ForwardNoticeBuilder.swift
//  Difft
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
        DTNoticeAuthorListFormatter.sortedAuthorIds(for: messages)
    }

    /// Authors used for the FORWARD trace DECISION (not the "from" display). See
    /// `DTNoticeAuthorListFormatter.forwardTriggerAuthorIds`: a forwarded single message or a
    /// Chat History carries its inner content out, so it recurses every layer to the original
    /// authors; any foreign one means a trace. The "from" display still uses the bubble sender.
    static func triggerAuthorIds(for messages: [TSMessage]) -> [String] {
        DTNoticeAuthorListFormatter.forwardTriggerAuthorIds(for: messages)
    }

    static func combinedForwardMode(for messages: [TSMessage]) -> DTForwardNoticeCombinedForwardMode {
        guard !messages.isEmpty else { return .unknown }

        var hasCombinedForward = false
        var hasRegular = false

        for message in messages {
            if message.combinedForwardingMessage != nil {
                hasCombinedForward = true
            } else {
                hasRegular = true
            }
            if hasCombinedForward && hasRegular { break }
        }

        if hasCombinedForward && hasRegular {
            return .containsCombinedForward
        } else if hasCombinedForward {
            return .allCombinedForward
        } else {
            return .unknown
        }
    }
}
