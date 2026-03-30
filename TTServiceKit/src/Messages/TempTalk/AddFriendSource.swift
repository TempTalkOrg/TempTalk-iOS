//
//  AddFriendSource.swift
//  TTServiceKit
//
//  Created by henry on 2025/3/5.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

/// Type-safe enum for add friend source
public enum AddFriendSource {
    case fromGroup(groupId: String)
    case shareContact(uid: String)
    case search
    case randomCode
    case link

    /// Convert to API parameters
    var apiParameters: [String: Any] {
        var params: [String: Any] = [:]

        switch self {
        case .fromGroup(let groupId):
            params["type"] = "fromGroup"
            params["groupID"] = groupId
        case .shareContact(let uid):
            params["type"] = "shareContact"
            params["uid"] = uid
        case .search:
            params["type"] = "search"
        case .randomCode:
            params["type"] = "randomCode"
        case .link:
            params["type"] = "link"
        }

        return params
    }
}
