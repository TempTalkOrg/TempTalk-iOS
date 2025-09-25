//
//  AddFriendHandler.swift
//  Signal
//
//  Created by Kris.s on 2024/11/23.
//  Copyright © 2024 Difft. All rights reserved.
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
}


@objc
class AddFriendHandler: NSObject{
    /// request add friend accept好友请求，或者随消息发送
    /// - Parameters:
    ///   - sourceType: source 用于展示如何相识
    ///   - sourceConversationID: from conversationId
    ///   - shareContactCardUId: shareContactCardUid 分享名片的用户的用户id
    ///   - action: accept or request, already useless
    ///   - isFriend: isFriend
    ///   - success: success
    ///   - failure: failure
    @objc
    static func requestAddFriend(identifier: String,
                                 sourceType: DTSourceToPersonalCardType,
                                 sourceConversationID: String?,
                                 shareContactCardUId: String?,
                                 action: String?,
                                 success: (() -> Void)? = nil,
                                 failure: ((_ errorString: String) -> Void)? = nil) {
        var type = ""
        if sourceType == .inGroupUserIcon ||
            sourceType == .inGroupUserID ||
            sourceType == .inGroupMemberUserIcon {
            type = "fromGroup"
        } else if sourceType == .inUserCard {
            type = "shareContact"
        }
        
        let api = DTAskAddFriendsApi()
        api.askAddContacts(identifier,
                           sourceType: type,
                           sourceConversationID: sourceConversationID,
                           shareContactCardUid: shareContactCardUId,
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
    static func markAsFriend(identifier: String) {
        
        let contactManager = Environment.shared.contactsManager
        var newAccount: SignalAccount
        if let threadAccount = contactManager?.signalAccount(forRecipientId: identifier){
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
    
    //主动请求好友，包含发送消息
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
                    ThreadUtil.sendMessage(withText: Localized("CONTACT_REQUEST"), atPersons: nil, mentions: nil, in: contactThread, quotedReplyModel: nil, messageSender: self.messageSender)
                }
            }
        } failure: { errorString in
            DTToastHelper.hide()
            DTToastHelper.toast(withText: errorString, in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
        }

    }
}
