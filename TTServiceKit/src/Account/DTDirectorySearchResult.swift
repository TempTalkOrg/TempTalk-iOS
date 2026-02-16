//
//  DTDirectorySearchResult.swift
//  TTServiceKit
//
//  Created by henry Code on 2025/1/7.
//

import Foundation

@objc
public class DTDirectorySearchResult: NSObject, Codable {

    /// User ID (phone number)
    @objc public let uid: String

    /// User's display name
    @objc public let name: String?

    /// When user joined (e.g., "Dec 2025")
    @objc public let joinedAt: String?

    /// Avatar JSON string
    @objc public let avatar: String?

    /// Custom user ID
    @objc public let customUid: String?

    @objc
    public init(uid: String, name: String? = nil, joinedAt: String? = nil, avatar: String? = nil, customUid: String? = nil) {
        self.uid = uid
        self.name = name
        self.joinedAt = joinedAt
        self.avatar = avatar
        self.customUid = customUid
        super.init()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case uid
        case name
        case joinedAt
        case avatar
        case customUid
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        joinedAt = try container.decodeIfPresent(String.self, forKey: .joinedAt)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        customUid = try container.decodeIfPresent(String.self, forKey: .customUid)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(joinedAt, forKey: .joinedAt)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(customUid, forKey: .customUid)
    }
}
