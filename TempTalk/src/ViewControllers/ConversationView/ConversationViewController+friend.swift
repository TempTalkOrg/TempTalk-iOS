//
//  ConversationViewController+friend.swift
//  Signal
//
//  Created by Kris.s on 2024/11/22.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
extension ConversationViewController: DTRequestBarDelegate {
    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, ignoreSender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }

    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, acceptSender: UIButton) {

        guard let contactThread = self.thread as? TSContactThread else {
            return
        }

        DTToastHelper.show()

        // Everything after the await touches UIKit, so this task stays on the main actor rather
        // than relying on the callee's isolation.
        Task { @MainActor in
            do {
                // Accepting an incoming request: the other side already reported how we met, and
                // our own view of it says nothing new. Matches Android, which also sends no source
                // on accept.
                try await AddFriendHandler.requestAddFriend(
                    identifier: contactThread.contactIdentifier(),
                    source: .unspecified,
                    action: AddFriendHandler.acceptAction
                )
                DTToastHelper.hide()
                // A friend sees the E2EE notice in the same header position.
                self.updateWarningHeaderLayout()
            } catch AddFriendHandler.AddFriendError.accountUnavailable {
                // Unified account-unavailable UI already shown by AddFriendHandler.
                OWSLogger.info("[AddFriend] accept: account unavailable (19009), handled by AddFriendHandler")
            } catch {
                DTToastHelper.hide()
                let errorString = (error as NSError).localizedDescription
                DTToastHelper.toast(
                    withText: errorString,
                    in: self.view,
                    durationTime: 3.0,
                    afterDelay: 0.2
                )
                OWSLogger.error("[AddFriend] accept error: \(errorString)")
            }
        }
    }


    var friendReqBar: DTRequestBar {

        if let requestBar = viewState.friendReqBar {
            return requestBar
        }

        let requestBar = DTRequestBar()
        requestBar.delegate = self
        return requestBar
    }

    var warningHeaderView: DTConversationWarningHeaderView {
        if let headerView = viewState.warningHeaderView {
            return headerView
        }

        let headerView = DTConversationWarningHeaderView(
            style: conversationNoticeHeaderStyle ?? .stranger
        )
        headerView.didTapEndToEndEncryption = { [weak self] in
            self?.presentEndToEndEncryptionInfo()
        }
        viewState.warningHeaderView = headerView
        return headerView
    }

    var isFriend: Bool {
        guard let contactThread = self.thread as? TSContactThread else {
            return false
        }
        return contactThread.isFriend
    }
    
    var isBot: Bool {
        guard let contactThread = self.thread as? TSContactThread else {
            return false
        }
        var isBot = false
        databaseStorage.read { transaction in
            if let account = self.contactsManager.signalAccount(forRecipientId: contactThread.contactIdentifier(), transaction: transaction) {
                isBot = account.isBot()
            }
        }
        return isBot
    }
    
    var showRequestBar: Bool {
        if isFriend {
            return false
        }
        guard let contactThread = self.thread as? TSContactThread else {
            return false
        }
        return contactThread.receivedFriendReq
    }

    /// The notice type implied by the conversation relationship. Unlike the
    /// header's visibility, this remains stable while history is loading and is
    /// therefore safe for one-time configuration such as the input placeholder.
    @nonobjc var conversationNoticeRelationshipStyle: DTConversationNoticeHeaderStyle? {
        if thread.isNoteToSelf {
            return nil
        }

        if thread.isGroupThread() {
            return .endToEndEncryption
        }

        guard thread is TSContactThread else { return nil }
        return isFriend ? .endToEndEncryption : .stranger
    }

    @nonobjc var conversationNoticeHeaderStyle: DTConversationNoticeHeaderStyle? {
        guard let relationshipStyle = conversationNoticeRelationshipStyle else {
            return nil
        }
        switch relationshipStyle {
        case .stranger:
            return .stranger
        case .endToEndEncryption:
            return shouldShowEndToEndEncryptionNotice ? .endToEndEncryption : nil
        }
    }

    /// The E2EE notice marks the beginning of the conversation history. Keep it
    /// hidden while the initial page or an older page is loading, or while the
    /// view model knows that more history is available.
    private var shouldShowEndToEndEncryptionNotice: Bool {
        guard !conversationViewModel.isLoadingInitialMessages(),
              !isLoadingOlderItems else {
            return false
        }
        return !conversationViewModel.canLoadOlderItems()
            && !conversationViewModel.canFetchOlderItems()
    }

    var showWarningHeader: Bool {
        conversationNoticeHeaderStyle != nil
    }

    func updateWarningHeaderLayout() {
        // Changing the inset would invalidate an active scroll target. Apply the
        // pending state after programmatic scrolling, dragging, or deceleration.
        guard !isScrollingToTop, !isUserScrolling, !isWaitingForDeceleration else { return }

        guard let style = conversationNoticeHeaderStyle else {
            removeWarningHeaderIfNeeded(force: true)
            return
        }

        let headerView = warningHeaderView
        headerView.configure(style: style)

        if headerView.superview == nil {
            collectionView.addSubview(headerView)
            headerView.autoresizingMask = [.flexibleWidth]
        }

        let width = collectionView.bounds.width
        let height = headerView.height(fittingWidth: width)

        headerView.frame = CGRect(x: 0, y: -height, width: width, height: height)

        updateWarningHeaderTopInset(height)
    }

    func removeWarningHeaderIfNeeded(force: Bool = false) {
        guard let headerView = viewState.warningHeaderView,
              headerView.superview != nil else {
            return
        }

        guard force || conversationNoticeHeaderStyle == nil else {
            return
        }

        headerView.removeFromSuperview()
        viewState.warningHeaderView = nil

        updateWarningHeaderTopInset(0)
    }

    /// Keep an existing bottom anchor when the inset changes; otherwise preserve
    /// the message-relative position restored after loading an older page, clamping
    /// only when removing the header makes the previous bounce offset invalid.
    private func updateWarningHeaderTopInset(_ topInset: CGFloat) {
        guard collectionView.contentInset.top != topInset
                || collectionView.verticalScrollIndicatorInsets.top != topInset else {
            return
        }

        // The initial scroll is established before the E2EE header becomes
        // eligible for display. For a short conversation, adding its top inset
        // changes the bottom offset from zero to a negative value. Preserve the
        // bottom anchor so the notice is visible without requiring a pull-down.
        let wasScrolledToBottom = isScrolledToBottom
        let previousOffset = collectionView.contentOffset
        UIView.performWithoutAnimation {
            var contentInset = collectionView.contentInset
            contentInset.top = topInset
            collectionView.contentInset = contentInset

            var scrollIndicatorInsets = collectionView.verticalScrollIndicatorInsets
            scrollIndicatorInsets.top = topInset
            collectionView.verticalScrollIndicatorInsets = scrollIndicatorInsets

            let minimumYOffset = -collectionView.adjustedContentInset.top
            let targetYOffset = wasScrolledToBottom
                ? maxContentOffsetY
                : max(previousOffset.y, minimumYOffset)
            collectionView.setContentOffset(
                CGPoint(x: previousOffset.x, y: targetYOffset),
                animated: false
            )
        }
    }

    private func presentEndToEndEncryptionInfo() {
        present(E2EEInfoViewController(), animated: false)
    }

    //send message
    func handleAddFriendRequest(message: TSMessage, source: AddFriendSource) {

        guard let contactThread = self.thread as? TSContactThread else {
            return
        }

        if message is DTScreenShotOutgoingMessage {
            return
        }

        if isFriend {
            return
        }

        let diffTime = TimeInterval(NSDate.ows_millisecondTimeStamp()) - viewState.friendReqTime

        if diffTime < 2 * kSecondInterval {
            return
        }

        Task { @MainActor in
            do {
                try await AddFriendHandler.requestAddFriend(
                    identifier: contactThread.contactIdentifier(),
                    source: source
                )
                self.markSendAddFriendAction()
            } catch AddFriendHandler.AddFriendError.accountUnavailable {
                // Unified account-unavailable UI already shown by AddFriendHandler.
                OWSLogger.info("[AddFriend] after message: account unavailable (19009), handled by AddFriendHandler")
            } catch {
                OWSLogger.error("[AddFriend] after message error: \((error as NSError).localizedDescription)")
            }
        }
    }

    func markSendAddFriendAction() {
        guard self.thread is TSContactThread else {
            return
        }
        self.viewState.friendReqTime = TimeInterval(NSDate.ows_millisecondTimeStamp())
    }
}

// MARK: - DTAddFriendSourceProviding

extension ConversationViewController: DTAddFriendSourceProviding {

    /// A group thread is its own provenance. A 1:1 thread has none of its own, so it falls back to
    /// whatever opened it (a card reached from a group, or from an invite link) and finally to
    /// unspecified — better no source than one the server would render as a fact.
    @objc var contextualAddFriendSource: AddFriendSource {
        AddFriendSource.from(thread: thread) ?? enteredFromAddFriendSource ?? .unspecified
    }
}
