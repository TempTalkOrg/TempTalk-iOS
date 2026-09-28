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

    /// Source for a tap on a shared contact card. The `uid` the server wants is the person who
    /// shared the card with us — the author of an incoming message.
    ///
    /// A card we sent ourselves has no such person: reporting our own id would make the server
    /// resolve the sharer to the requester, which reads as self-referential on the other side. That
    /// is the same unresolvable-source defect this type exists to prevent, so it stays unspecified.
    static func shareContactSource(for viewItem: any ConversationViewItem) -> AddFriendSource {
        guard let incomingMessage = viewItem.interaction as? TSIncomingMessage else {
            return .unspecified
        }
        return .shareContact(uid: incomingMessage.authorId)
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

    /// Sent when accepting an incoming request. The server establishes the relationship outright
    /// instead of queueing another request, so a successful response is itself the confirmation.
    static let acceptAction = "accept"

    /// Main-actor bound: the `await` releases the main thread for the network round trip, while the
    /// continuation — `markAsFriend` and the account-unavailable alert — resumes where UIKit and the
    /// contacts manager expect to be. Callers must keep their own `Task { @MainActor in }`; dropping
    /// the isolation here would silently push their post-await UI work onto a background thread.
    @MainActor
    static func requestAddFriend(
        identifier: String,
        source: AddFriendSource,
        action: String? = nil
    ) async throws {
        // The server renders "How you met" from what we report here, and every entry point funnels
        // through this call — so this line is the one place that shows what was actually sent.
        OWSLogger.info("[AddFriend] request uid=…\(identifier.suffix(4)) source=\(source) action=\(action ?? "none")")

        do {
            let api = DTAskAddFriendsApi()
            let entity = try await api.askAddContacts(uid: identifier, source: source, action: action)

            // Accepting is authoritative — matches Android, which flips the local friend flag on a
            // successful accept without reading the response id. `id == -1` stays for the other
            // path: a plain request that crosses one already sent by the other side, and is only
            // evaluated when this is not an accept.
            if action == acceptAction || entity.data["id"] as? Int32 == -1 {
                OWSLogger.info("[AddFriend] became friends immediately uid=…\(identifier.suffix(4))")
                await markAsFriend(identifier: identifier)
            }
        } catch let error as NSError where error.code == accountUnavailableErrorCode {
            handleAccountUnavailable(identifier: identifier)
            throw AddFriendError.accountUnavailable
        }
    }

    /// Drives the request plus its toasts and info message, so it is pinned to the main actor for
    /// the same reason as `requestAddFriend` — a nonisolated async function does not inherit its
    /// caller's actor, which would put `DTToastHelper` on a background thread.
    @MainActor
    static func handleRequestAddFriend(
        identifier: String,
        source: AddFriendSource,
        action: String? = nil
    ) async throws {
        DTToastHelper.show()

        do {
            try await requestAddFriend(identifier: identifier, source: source, action: action)
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
                let now = DTTrustedClock.clientStampMs()
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

    /// Awaits its own write. Callers re-read friend state right after this returns (the conversation
    /// header reads `TSContactThread.isFriend` through a fresh `databaseStorage.read`), and nothing
    /// observes the database to correct them later — resuming before the commit would leave a
    /// just-accepted friend rendered as a stranger until the screen is rebuilt.
    @MainActor
    static func markAsFriend(identifier: String) async {

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
        await withCheckedContinuation { continuation in
            self.databaseStorage.asyncWrite { wTransaction in
                contactManager?.updateSignalAccount(withRecipientId: identifier, withNewSignalAccount: newAccount, with: wTransaction)
                let contactThread = TSContactThread.getOrCreateThread(withContactId: identifier, transaction: wTransaction)
                contactThread.anyUpdateContactThread(transaction: wTransaction) { latestThread in
                    latestThread.receivedFriendReq = false
                }
                DTWeakContactManager.shared.clearWeakPlaceholder(uid: identifier, transaction: wTransaction)
            } completion: {
                continuation.resume()
            }
        }
    }
}
