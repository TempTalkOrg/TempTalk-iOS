//
//  AddFriendSource.swift
//  TTServiceKit
//
//  Created by henry on 2025/3/5.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

/// How the local user came across the person they are about to add.
///
/// The server renders the "How you met" line on the personal card from whatever we report here,
/// so a source is only ever constructed at a call site that actually knows the answer. Cases that
/// carry context (group / shared card) take it as a constructor argument, which makes it impossible
/// to report `shareContact` without the sharer's uid — the mistake that used to surface as
/// "met via Unknown".
///
/// Modelled as a class rather than an enum so Objective-C call sites can build one too.
@objc(DTAddFriendSource)
public final class AddFriendSource: NSObject {

    private enum Kind {
        case fromGroup(groupId: String)
        case shareContact(uid: String)
        case search
        case randomCode
        case link
        case unspecified
    }

    private let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
        super.init()
    }

    /// Reached through a group: member list, avatar, or an @mention.
    ///
    /// An empty `groupId` degrades to `unspecified`: a type the server cannot resolve renders worse
    /// than no source at all, which is the exact failure this type exists to prevent.
    @objc(fromGroupWithGroupId:)
    public static func fromGroup(groupId: String) -> AddFriendSource {
        groupId.isEmpty ? unspecified : AddFriendSource(.fromGroup(groupId: groupId))
    }

    /// Reached through a contact card someone shared. `uid` is the sharer, not the card's subject.
    /// An empty `uid` degrades to `unspecified` for the same reason as `fromGroup`.
    @objc(shareContactWithUid:)
    public static func shareContact(uid: String) -> AddFriendSource {
        uid.isEmpty ? unspecified : AddFriendSource(.shareContact(uid: uid))
    }

    /// Provenance a conversation can vouch for on its own: we came across this person in a group.
    /// Returns nil for a 1:1 thread, which says nothing about how the two of us met — callers then
    /// fall back to whatever context they have.
    ///
    /// Every screen that hosts message bubbles needs this same derivation — a tapped @mention can
    /// open a personal card from a conversation, a topic list, or a long-message view — so it lives
    /// here rather than being re-derived per screen.
    @objc(fromThread:)
    public static func from(thread: TSThread?) -> AddFriendSource? {
        guard let groupThread = thread as? TSGroupThread,
              let groupId = TSGroupThread.transformToServerGroupId(withLocalGroupId: groupThread.groupModel.groupId),
              !groupId.isEmpty else {
            return nil
        }
        return fromGroup(groupId: groupId)
    }

    /// Found by searching for a name or uid.
    @objc public static let search = AddFriendSource(.search)

    /// Entered the other party's four-digit invite code.
    @objc public static let randomCode = AddFriendSource(.randomCode)

    /// Opened the other party's invite link or scanned their QR code.
    @objc public static let link = AddFriendSource(.link)

    /// Genuinely unknown — a generic deep link, or a conversation we have no provenance for.
    /// Reports no source at all rather than guessing; never use it to paper over a known source.
    @objc public static let unspecified = AddFriendSource(.unspecified)

    /// `source` payload for `/v3/friend/ask`. Empty when unspecified, so the key is omitted.
    var apiParameters: [String: Any] {
        switch kind {
        case .fromGroup(let groupId):
            return ["type": "fromGroup", "groupID": groupId]
        case .shareContact(let uid):
            return ["type": "shareContact", "uid": uid]
        case .search:
            return ["type": "search"]
        case .randomCode:
            return ["type": "randomCode"]
        case .link:
            return ["type": "link"]
        case .unspecified:
            return [:]
        }
    }

    /// Trailing characters only. Enough to tell two ids apart while reading a log, without the log
    /// itself carrying a group id or a user id.
    private static func loggableTail(_ id: String) -> String {
        id.count <= 4 ? "…" : "…\(id.suffix(4))"
    }

    public override var description: String {
        switch kind {
        case .fromGroup(let groupId):
            return "fromGroup(\(Self.loggableTail(groupId)))"
        case .shareContact(let uid):
            return "shareContact(\(Self.loggableTail(uid)))"
        case .search:
            return "search"
        case .randomCode:
            return "randomCode"
        case .link:
            return "link"
        case .unspecified:
            return "unspecified"
        }
    }
}

/// A screen that can say where a friend request started from on behalf of a generic navigation
/// step that cannot — deep links, in particular, carry a uid but no provenance.
@objc public protocol DTAddFriendSourceProviding {
    var contextualAddFriendSource: AddFriendSource { get }
}
