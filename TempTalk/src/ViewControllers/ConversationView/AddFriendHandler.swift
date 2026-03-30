//
//  AddFriendHandler.swift
//  Signal
//
//  Created by Kris.s on 2024/11/23.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
class AddFriendHandler: NSObject {

    static func requestAddFriend(
        identifier: String,
        source: AddFriendSource
    ) async throws {
        let api = DTAskAddFriendsApi()
        let entity = try await api.askAddContacts(uid: identifier, source: source)
        
        if entity.data["id"] as? Int32 == -1 {
            markAsFriend(identifier: identifier)
        }
    }

    static func handleRequestAddFriend(
        identifier: String,
        source: AddFriendSource
    ) async throws {
        DTToastHelper.show()

        do {
            try await requestAddFriend(identifier: identifier, source: source)
            DTToastHelper.hide()
            DTToastHelper.toast(
                withText: Localized("CONTACT_REQUEST_SENTED"),
                in: DTToastHelper.shared().frontWindow(),
                durationTime: 2.0,
                afterDelay: 0.2
            )

            databaseStorage.asyncWrite { wTransaction in
                let latestThread = TSContactThread.getOrCreateThread(
                    withContactId: identifier,
                    transaction: wTransaction
                )
                latestThread.isRemovedFromConversation = false
                let now = NSDate.ows_millisecondTimeStamp()
                let infoMsg = TSInfoMessage(
                    timestamp: now,
                    in: latestThread,
                    messageType: .askFriend,
                    customMessage: Localized("CONTACT_REQUEST")
                )
                latestThread.update(withUpdatedMessage: infoMsg, transaction: wTransaction)
            } completion: {
                databaseStorage.write { wTransaction in
                    if let contactThread = TSContactThread.getOrCreateThread(
                        withContactId: identifier,
                        transaction: wTransaction
                    ) as? TSContactThread {
                        _ = ThreadUtil.sendMessage(
                            withText: Localized("CONTACT_REQUEST"),
                            atPersons: nil,
                            mentions: nil,
                            in: contactThread,
                            quotedReplyModel: nil,
                            messageSender: messageSender
                        )
                    }
                }
            }
        } catch {
            DTToastHelper.hide()
            let errorString = NSError.errorDesc(error as NSError, errResponse: nil)
            DTToastHelper.toast(
                withText: errorString,
                in: DTToastHelper.shared().frontWindow(),
                durationTime: 2.0,
                afterDelay: 0.2
            )
            throw error
        }
    }

    @objc
    static func requestAddFriend(identifier: String,
                                 sourceType: DTSourceToPersonalCardType,
                                 sourceConversationID: String?,
                                 shareContactCardUId: String?,
                                 action: String?,
                                 success: (() -> Void)? = nil,
                                 failure: ((_ errorString: String) -> Void)? = nil) {
        // 从 DTAddFriendSourceManager 获取上下文信息
        let sourceManager = DTAddFriendSourceManager.shared
        let finalSourceType = sourceType
        var finalSourceConversationID = sourceConversationID
        var finalShareContactCardUId = shareContactCardUId

        // 根据来源类型获取对应的上下文信息
        switch finalSourceType {
        case .inGroupUserIcon, .inGroupUserID, .inGroupMemberUserIcon:
            // 从群相关来源获取群ID
            if finalSourceConversationID == nil {
                finalSourceConversationID = sourceManager.groupId
            }
        case .inUserCard:
            // 从分享名片来源获取分享者的用户ID
            if finalShareContactCardUId == nil {
                finalShareContactCardUId = sourceManager.shareContactCardUid
            }
        default:
            break
        }

        var type = ""

        switch finalSourceType {
        case .inGroupUserIcon, .inGroupUserID, .inGroupMemberUserIcon:
            type = "fromGroup"
        case .inUserCard:
            type = "shareContact"
        case .inSearchUserId:
            type = "search"
        case .randomCode:
            type = "randomCode"
        case .unknow:
            type = ""
        @unknown default:
            type = ""
        }

        let api = DTAskAddFriendsApi()
        api.askAddContacts(identifier,
                           sourceType: type.isEmpty ? nil : type,
                           sourceConversationID: finalSourceConversationID,
                           shareContactCardUid: finalShareContactCardUId,
                           action: action) { metaEntity in
            success?()

            guard let askId = metaEntity?.data["id"] as? Int32 else {
                return
            }

            // id 为 -1说明是相互请求为好友
            if askId == -1 {
                markAsFriend(identifier: identifier)
            }

        } failure: { error, entity in
            var errorString = NSError.errorDesc(error, errResponse: entity)
            if let nsError = error as? NSError, nsError.code == 19009 {
                errorString = Localized("PERSONAL_CARD_ADD_FRIEND_ERROR_TOAST")
            }
            failure?(errorString)
        }

    }

    @objc
    static func handleRequestAddFriend(identifier: String,
                                       sourceType: DTSourceToPersonalCardType,
                                       sourceConversationID: String?,
                                       shareContactCardUId: String?,
                                       action: String?,
                                       success: (() -> Void)? = nil,
                                       failure: ((_ errorString: String) -> Void)? = nil) {
        DTToastHelper.show()
        
        self.requestAddFriend(identifier: identifier,
                              sourceType: sourceType,
                              sourceConversationID: sourceConversationID,
                              shareContactCardUId: shareContactCardUId,
                              action: action) {
            DTToastHelper.hide()
            DTToastHelper.toast(withText: Localized("CONTACT_REQUEST_SENTED"), in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
            var contactThread: TSContactThread?
            self.databaseStorage.asyncWrite { wTransaction in
                let latestThread = TSContactThread.getOrCreateThread(withContactId: identifier, transaction: wTransaction)
                latestThread.isRemovedFromConversation = false
                let now = NSDate.ows_millisecondTimeStamp()
                let infoMsg = TSInfoMessage.init(timestamp: now, in: latestThread, messageType: .askFriend, customMessage: Localized("CONTACT_REQUEST"))
                latestThread.update(withUpdatedMessage: infoMsg, transaction: wTransaction)
                contactThread = latestThread
            } completion: {
                if let contactThread {
                    let message = ThreadUtil.sendMessage(withText: Localized("CONTACT_REQUEST"), atPersons: nil, mentions: nil, in: contactThread, quotedReplyModel: nil, messageSender: self.messageSender)
                }
            }
        } failure: { errorString in
            DTToastHelper.hide()
            DTToastHelper.toast(withText: errorString, in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
        }

    }

    @objc
    static func markAsFriend(identifier: String) {

        let contactManager = Environment.shared.contactsManager
        var newAccount: SignalAccount
        if let threadAccount = contactManager?.signalAccount(forRecipientId: identifier) {
            newAccount = threadAccount
            if newAccount.contact == nil {
                newAccount.contact = Contact(recipientId: identifier)
            }
        } else {
            newAccount = SignalAccount(recipientId: identifier)
            newAccount.contact = Contact(fullName: identifier, phoneNumber: identifier)
        }
        newAccount.contact?.isExternal = false
        self.databaseStorage.asyncWrite { wTransaction in
            contactManager?.updateSignalAccount(withRecipientId: identifier, withNewSignalAccount: newAccount, with: wTransaction)
            let contactThread = TSContactThread.getOrCreateThread(withContactId: identifier, transaction: wTransaction)
            contactThread.anyUpdateContactThread(transaction: wTransaction) { latestThread in
                latestThread.receivedFriendReq = false
            }
        } completion: {

        }

    }
}

