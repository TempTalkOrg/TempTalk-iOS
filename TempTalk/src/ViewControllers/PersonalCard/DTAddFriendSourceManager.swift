//
//  DTAddFriendSourceManager.swift
//  TempTalk
//
//  Created by henry on 2025/1/7.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
enum DTSourceToPersonalCardType: UInt {
    case unknow = 0
    case inGroupUserIcon = 1 //点击群中的用户头像过来
    case inGroupUserID = 2 //点击群中的用户ID过来
    case inGroupMemberUserIcon = 3 //通过群中的成员列表过来
    case inUserCard = 4 //通过用户分享的名片
    case inSearchUserId = 5 //通过搜索他人的用户id过来
    case randomCode = 6 //通过四位数邀请码添加
}

@objc
class DTAddFriendSourceManager: NSObject {

    @objc static let shared = DTAddFriendSourceManager()

    /// 添加好友来源
    @objc var addFriendSource: DTSourceToPersonalCardType = .unknow

    /// 群ID（用于 inGroupUserIcon, inGroupUserID, inGroupMemberUserIcon）
    @objc var groupId: String?

    /// 分享名片的用户ID（用于 inUserCard）
    @objc var shareContactCardUid: String?

    private override init() {
        super.init()
    }

    /// 重置添加好友来源为未知
    @objc func resetAddFriendSource() {
        self.addFriendSource = .unknow
        self.groupId = nil
        self.shareContactCardUid = nil
    }

    /// 设置群相关的来源
    /// - Parameters:
    ///   - sourceType: 来源类型（inGroupUserIcon, inGroupUserID, inGroupMemberUserIcon）
    ///   - groupId: 群ID
    @objc func setGroupSource(_ sourceType: DTSourceToPersonalCardType, groupId: String) {
        self.addFriendSource = sourceType
        self.groupId = groupId
        self.shareContactCardUid = nil
    }

    /// 设置分享名片的来源
    /// - Parameters:
    ///   - shareContactCardUid: 分享名片的用户ID
    @objc func setShareContactSource(shareContactCardUid: String) {
        self.addFriendSource = .inUserCard
        self.shareContactCardUid = shareContactCardUid
        self.groupId = nil
    }

    /// 设置其他来源
    /// - Parameters:
    ///   - sourceType: 来源类型
    @objc func setOtherSource(_ sourceType: DTSourceToPersonalCardType) {
        self.addFriendSource = sourceType
        self.groupId = nil
        self.shareContactCardUid = nil
    }
}
