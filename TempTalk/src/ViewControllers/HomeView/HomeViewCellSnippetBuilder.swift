//
//  HomeViewCellSnippetBuilder.swift
//  Difft
//
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging

/// Tags the conversation list can prefix onto a thread's preview line.
/// Left-to-right display order is: Critical alert, Send failed, @you/@All, Draft.
@objcMembers
public class HomeViewCellSnippetInput: NSObject {
    /// Never dropped.
    public var criticalAlertText: String?
    /// Never dropped.
    public var sendFailedText: String?
    /// Dropped second. @you and @All are mutually exclusive and rank equally.
    public var mentionText: String?
    /// Dropped first.
    public var draftText: String?
    /// Body shown while the Draft tag survives.
    public var draftBody: String?
    /// Body shown otherwise — the thread's last message.
    public var messageBody: String?
}

/// Builds the conversation list preview line, dropping optional tags from the right
/// when the row is too narrow to fit them alongside the body text.
@objcMembers
public class HomeViewCellSnippetBuilder: NSObject {

    /// Width reserved for the body so tags can never squeeze it out completely.
    private static let minBodyWidth: CGFloat = 40

    /// - Parameter availableWidth: the label's laid-out width. Pass 0 when it isn't known
    ///   yet — every tag is kept and the caller re-builds once layout settles.
    public static func snippet(
        input: HomeViewCellSnippetInput,
        availableWidth: CGFloat,
        font: UIFont,
        tagColor: UIColor,
        bodyColor: UIColor
    ) -> NSAttributedString {
        let tagFont = font.ows_semibold()

        var keepMention = input.mentionText != nil
        var keepDraft = input.draftText != nil

        if availableWidth > 0 {
            while true {
                let tagsWidth = width(
                    of: tags(input, keepMention: keepMention, keepDraft: keepDraft),
                    font: tagFont
                )
                if tagsWidth + minBodyWidth <= availableWidth {
                    break
                }
                // Drop from the right: Draft first, then @you/@All. Critical alert and
                // Send failed always stay.
                if keepDraft {
                    keepDraft = false
                } else if keepMention {
                    keepMention = false
                } else {
                    break
                }
            }
        }

        // Dropping the Draft tag drops the draft body with it — showing draft content
        // under no Draft tag would read as if it were the last message. Keep the tag when
        // there is no last message to fall back to, so the row isn't left tag-only.
        var body = keepDraft ? input.draftBody : input.messageBody
        if (body?.isEmpty ?? true), input.draftText != nil, let draftBody = input.draftBody, !draftBody.isEmpty {
            keepDraft = true
            body = draftBody
        }

        let result = NSMutableAttributedString()
        for tag in tags(input, keepMention: keepMention, keepDraft: keepDraft) {
            result.append(NSAttributedString(
                string: tag,
                attributes: [.font: tagFont, .foregroundColor: tagColor]
            ))
        }
        if let body, !body.isEmpty {
            result.append(NSAttributedString(
                string: body,
                attributes: [.font: font, .foregroundColor: bodyColor]
            ))
        }
        return result
    }

    private static func tags(
        _ input: HomeViewCellSnippetInput,
        keepMention: Bool,
        keepDraft: Bool
    ) -> [String] {
        var tags: [String] = []
        if let criticalAlertText = input.criticalAlertText {
            tags.append(spaced(criticalAlertText))
        }
        if let sendFailedText = input.sendFailedText {
            tags.append(spaced(sendFailedText))
        }
        if keepMention, let mentionText = input.mentionText {
            tags.append(spaced(mentionText))
        }
        if keepDraft, let draftText = input.draftText {
            tags.append(spaced(draftText))
        }
        return tags
    }

    /// Some tag strings ship with a trailing space, some don't — normalise so tags never
    /// run into each other or into the body.
    private static func spaced(_ tag: String) -> String {
        return tag.hasSuffix(" ") ? tag : tag + " "
    }

    private static func width(of tags: [String], font: UIFont) -> CGFloat {
        return tags.reduce(0) { total, tag in
            total + (tag as NSString).size(withAttributes: [.font: font]).width
        }
    }
}
