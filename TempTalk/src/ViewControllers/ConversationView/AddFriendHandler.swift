//
//  AddFriendHandler.swift
//  Signal
//
//  Created by Kris.s on 2024/11/23.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import UIKit

@objc
class AddFriendHandler: NSObject {

    // MARK: - Account unavailable (19009)

    /// Server collapses every "account gone" reason (friend-deleted / deactivated / banned /
    /// disabled / inactive) into this single code. We never surface the specific reason.
    private static let accountUnavailableErrorCode = 19009

    /// Thrown after the unified account-unavailable UI has been shown, so callers skip their own error toast.
    enum AddFriendError: Error {
        case accountUnavailable
    }

    /// Present the unified "account unavailable" result. Offers "Delete Contact" only when the
    /// target is still in our contacts (a weak / pending-removal contact); otherwise just a toast.
    private static func handleAccountUnavailable(identifier: String) {
        DispatchQueue.main.async {
            DTToastHelper.hide()
            let message = Localized("PERSONAL_CARD_ACCOUNT_UNAVAILABLE_MESSAGE")
            guard DTWeakContactManager.shared.isWeakContact(recipientId: identifier),
                  let presenter = frontmostViewController() else {
                DTToastHelper.toast(withText: message, in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
                return
            }
            let alert = UIAlertController(title: Localized("PERSONAL_CARD_ACCOUNT_UNAVAILABLE_TITLE"),
                                          message: message,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("BUTTON_OK"), style: .cancel))
            alert.addAction(UIAlertAction(title: Localized("PERSONAL_CARD_ACCOUNT_UNAVAILABLE_DELETE"), style: .destructive) { _ in
                removeContactNow(identifier: identifier)
            })
            // Defer until any in-flight push/present settles, otherwise the alert is laid out
            // mid-transition and visibly jumps when the destination finishes animating in.
            if let coordinator = presenter.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { _ in presenter.present(alert, animated: true) }
            } else {
                presenter.present(alert, animated: true)
            }
        }
    }

    /// Remove a weak contact immediately: clear the server pending-removal record, then drop the local placeholder.
    private static func removeContactNow(identifier: String) {
        DTToastHelper.show()
        Task {
            do {
                try await DTDeletedRecordsApi().removeDeletedRecord(uid: identifier)
            } catch {
                await MainActor.run {
                    DTToastHelper.hide()
                    DTToastHelper.toast(withText: NSError.errorDesc(error as NSError, errResponse: nil), in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
                }
                return
            }
            await MainActor.run {
                databaseStorage.asyncWrite { transaction in
                    DTWeakContactManager.shared.removeFromWeakState(uid: identifier, transaction: transaction)
                } completion: {
                    DTToastHelper.hide()
                    // Return to the contacts list (weak contacts are always reached from there).
                    frontmostViewController()?.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
    }

    /// Actually-visible view controller of the key window, walking modal, navigation and tab
    /// containers, for presenting from this static helper.
    private static func frontmostViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let root = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController else {
            return nil
        }
        return visibleViewController(from: root)
    }

    private static func visibleViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return visibleViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return visibleViewController(from: top)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return visibleViewController(from: selected)
        }
        return vc
    }

    static func requestAddFriend(
        identifier: String,
        source: AddFriendSource
    ) async throws {
        do {
            let api = DTAskAddFriendsApi()
            let entity = try await api.askAddContacts(uid: identifier, source: source)

            if entity.data["id"] as? Int32 == -1 {
                markAsFriend(identifier: identifier)
            }
        } catch let error as NSError where error.code == accountUnavailableErrorCode {
            handleAccountUnavailable(identifier: identifier)
            throw AddFriendError.accountUnavailable
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
        } catch AddFriendError.accountUnavailable {
            // Unified account-unavailable UI already shown by requestAddFriend; do not toast again.
            DTToastHelper.hide()
            throw AddFriendError.accountUnavailable
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
            if let nsError = error as? NSError, nsError.code == Self.accountUnavailableErrorCode {
                OWSLogger.info("add friend: account unavailable (19009) for \(identifier)")
                Self.handleAccountUnavailable(identifier: identifier)
                return
            }
            let errorString = NSError.errorDesc(error, errResponse: entity)
            failure?(errorString)
        }

    }

    /// `proceedHandler` fires only when the request succeeds, so the caller can open the
    /// conversation on success and stay put on any failure (including the account-unavailable
    /// alert). Matches Android: navigate on success, don't navigate on failure.
    @objc
    static func handleRequestAddFriend(identifier: String,
                                       sourceType: DTSourceToPersonalCardType,
                                       sourceConversationID: String?,
                                       shareContactCardUId: String?,
                                       action: String?,
                                       success: (() -> Void)? = nil,
                                       failure: ((_ errorString: String) -> Void)? = nil,
                                       proceedHandler: (() -> Void)? = nil) {
        DTToastHelper.show()

        self.requestAddFriend(identifier: identifier,
                              sourceType: sourceType,
                              sourceConversationID: sourceConversationID,
                              shareContactCardUId: shareContactCardUId,
                              action: action) {
            DTToastHelper.hide()
            DTToastHelper.toast(withText: Localized("CONTACT_REQUEST_SENTED"), in: DTToastHelper.shared().frontWindow(), durationTime: 2.0, afterDelay: 0.2)
            proceedHandler?()
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
            DTWeakContactManager.shared.clearWeakPlaceholder(uid: identifier, transaction: wTransaction)
        } completion: {

        }

    }
}

