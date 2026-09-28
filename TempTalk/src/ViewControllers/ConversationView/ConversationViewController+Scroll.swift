//
//  ConversationViewController+Scroll.swift
//  Signal
//
//  Created by Jaymin on 2024/2/2.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

extension ConversationViewController {
    var isScrolledToBottom: Bool {
        let distanceFromBottom = safeDistanceFromBottom
        let kIsAtBottomTolerancePts: CGFloat = 5
        return distanceFromBottom <= kIsAtBottomTolerancePts
    }
    
    private var safeDistanceFromBottom: CGFloat {
        // This is a bit subtle.
        //
        // The _wrong_ way to determine if we're scrolled to the bottom is to
        // measure whether the collection view's content is "near" the bottom edge
        // of the collection view.  This is wrong because the collection view
        // might not have enough content to fill the collection view's bounds
        // _under certain conditions_ (e.g. with the keyboard dismissed).
        //
        // What we're really interested in is something a bit more subtle:
        // "Is the scroll view scrolled down as far as it can, "at rest".
        //
        // To determine that, we find the appropriate "content offset y" if
        // the scroll view were scrolled down as far as possible.  IFF the
        // actual "content offset y" is "near" that value, we return YES.
        let maxContentOffsetY = maxContentOffsetY
        let distanceFromBottom = maxContentOffsetY - collectionView.contentOffset.y
        return distanceFromBottom
    }
    
    var maxContentOffsetY: CGFloat {
        let contentHeight = safeContentHeight
        let adjustedContentInset = collectionView.adjustedContentInset
        
        // Note the usage of MAX() to handle the case where there isn't enough
        // content to fill the collection view at its current size.
        let firstContentPageTop = -adjustedContentInset.top
        let lastContentPageTop = contentHeight + adjustedContentInset.bottom - collectionView.bounds.size.height
        return max(firstContentPageTop, lastContentPageTop)
    }
    
    var safeContentHeight: CGFloat {
        // Don't use self.collectionView.contentSize.height as the collection view's
        // content size might not be set yet.
        //
        // We can safely call prepareLayout to ensure the layout state is up-to-date
        // since our layout uses a dirty flag internally to debounce redundant work.
        layout.prepare()
        return collectionView.collectionViewLayout.collectionViewContentSize.height
    }
    
    private var indexPathOfUnreadMessagesIndicator: IndexPath? {
        guard let index = conversationViewModel.viewState.unreadIndicatorIndex else {
            return nil
        }
        return IndexPath(row: index.intValue, section: 0)
    }
    
    private var indexPathOfFocusMessage: IndexPath? {
        guard let index = conversationViewModel.viewState.focusItemIndex else {
            return nil
        }
        return IndexPath(row: index.intValue, section: 0)
    }

    private var indexPathOfOldestFailedMessage: IndexPath? {
        guard let index = conversationViewModel.viewState.oldestFailedOutgoingIndex else {
            return nil
        }
        return IndexPath(row: index.intValue, section: 0)
    }

    /// Unread and failed messages rank equally, so land on whichever comes first in the
    /// conversation. The load window is anchored the same way in
    /// `ConversationMessageMapping.loadInitialMessagePage`.
    private var indexPathOfDefaultPosition: IndexPath? {
        return [indexPathOfUnreadMessagesIndicator, indexPathOfOldestFailedMessage]
            .compactMap { $0 }
            .min { $0.row < $1.row }
    }
    
    func scrollToDefaultPosition(animated: Bool) {
        guard !isUserScrolling else { return }
        
        // Fix: 解决某些场景下，还未 reload ui 的情况下，执行了 scroll to 操作，引发 crash
        if viewItems.count != dataSource.snapshot().numberOfItems {
            reloadData { [weak self] isFinished in
                guard let self, isFinished else { return }
                self._scrollToDefaultPosition(animated: animated)
            }
        } else {
            _scrollToDefaultPosition(animated: animated)
        }
    }

    private func _scrollToDefaultPosition(animated: Bool) {
        cancelScrollDownButtonNavigation()

        let focusIndexPath = indexPathOfFocusMessage
        let unreadIndexPath = indexPathOfUnreadMessagesIndicator
        let defaultIndexPath = indexPathOfDefaultPosition

        guard let indexPath = focusIndexPath ?? defaultIndexPath else {
            scrollToBottom(animated: animated)
            viewState.hasCompletedInitialScroll = true
            return
        }


        if indexPath.section == 0 && indexPath.row == 0 {
            collectionView.setContentOffset(.zero, animated: animated)
        } else if indexPath.row < dataSource.snapshot().numberOfItems {
            // For focus messages (from search), use .centeredVertically to highlight the message
            // For unread / failed messages, use .top with padding to show them near the top of the screen
            let isFocusMessage = indexPathOfFocusMessage != nil

            if isFocusMessage {
                // Focus message: center it for emphasis
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
            } else {
                if defaultIndexPath == unreadIndexPath,
                   let unreadAttributes = collectionView.layoutAttributesForItem(at: indexPath) {
                    let bottomOffset = maxContentOffsetY
                    let unreadIndicatorY = unreadAttributes.frame.minY
                    let unreadIndicatorScreenY = unreadIndicatorY - bottomOffset

                    // If unread indicator would be visible when at bottom, scroll to bottom
                    if unreadIndicatorScreenY >= 40 && unreadIndicatorScreenY < collectionView.bounds.height {
                        scrollToBottom(animated: animated)
                        viewState.initialScrollTargetOffset = collectionView.contentOffset.y
                        viewState.initialScrollProtectionDeadline = Date().addingTimeInterval(2.0)
                        viewState.hasCompletedInitialScroll = true
                        return
                    }
                }

                collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                let topPadding: CGFloat = 40
                let currentOffset = collectionView.contentOffset.y
                let adjustedOffset = max(currentOffset - topPadding, -collectionView.adjustedContentInset.top)
                collectionView.setContentOffset(CGPoint(x: 0, y: adjustedOffset), animated: animated)
            }

            // Store the target scroll position to protect against keyboard flash events
            // This position will be restored if keyboard events try to disrupt it
            let targetOffset = collectionView.contentOffset.y
            viewState.initialScrollTargetOffset = targetOffset
            // Set protection deadline to 2 seconds from now
            viewState.initialScrollProtectionDeadline = Date().addingTimeInterval(2.0)
        }

        viewState.hasCompletedInitialScroll = true
    }
    
    func scrollToBottom(animated: Bool) {
        AssertIsOnMainThread()

        guard !isUserScrolling else { return }

        // This explicit target supersedes every viewport anchor captured by an
        // in-flight collection rebuild.
        viewState.collectionViewportAnchorsByGeneration.removeAll()

        if viewState.scrollDownButtonTarget == .latestMessage,
           viewState.activeScrollDownCollectionAction == nil {
            viewState.activeScrollDownCollectionAction = ConversationCollectionScrollAction(
                destination: .bottomOfLoadWindow,
                isAnimated: animated,
                userScrollGeneration: viewState.userScrollGeneration,
                requestGeneration: viewState.scrollActionRequestGeneration
            )
        }

        if isLoadingOlderItems || isLoadingNewerItems {
            enqueueScrollToBottom(animated: animated)
            return
        }
        
        let canLoadNewerItems = conversationViewModel.canLoadNewerItems()
        if canLoadNewerItems {
            // Match Signal's loadAndScrollToNewestItems: carry the bottom action through the
            // reload and perform it only after the winning collection generation has landed.
            let isScrollDownButtonRequest = viewState.scrollDownButtonTarget == .latestMessage
            if !isScrollDownButtonRequest {
                viewState.scrollActionRequestGeneration &+= 1
            }
            let scrollAction: ConversationCollectionScrollAction
            if isScrollDownButtonRequest,
               let activeScrollAction = viewState.activeScrollDownCollectionAction {
                scrollAction = activeScrollAction
            } else {
                scrollAction = ConversationCollectionScrollAction(
                    destination: .bottomOfLoadWindow,
                    isAnimated: animated,
                    userScrollGeneration: viewState.userScrollGeneration,
                    requestGeneration: viewState.scrollActionRequestGeneration
                )
            }
            if isScrollDownButtonRequest {
                viewState.activeScrollDownCollectionAction = scrollAction
            }
            viewState.scrollActionForNextUpdate = scrollAction
            isLoadingNewerItems = true
            var didStartLoading = false
            databaseStorage.uiRead { [weak self] transaction in
                guard let self else { return }
                didStartLoading = self.conversationViewModel.ensureLoadWindowContainsNewestItems(
                    with: transaction
                ) { [weak self] isFinished in
                    guard let self else { return }
                    self.isLoadingNewerItems = false
                    if !isFinished {
                        self.viewState.scrollActionForNextUpdate = nil
                        self.scrollToLoadedWindowBottom(animated: animated)
                    }
                    self.resumePendingScrollToBottom()
                }
            }
            if !didStartLoading {
                isLoadingNewerItems = false
                viewState.scrollActionForNextUpdate = nil
                scrollToLoadedWindowBottom(animated: animated)
            }
            return
        }

        viewState.pendingScrollToBottomAnimated = nil
        scrollToLoadedWindowBottom(animated: animated)
    }

    private func enqueueScrollToBottom(animated: Bool) {
        if let pendingAnimated = viewState.pendingScrollToBottomAnimated {
            viewState.pendingScrollToBottomAnimated = pendingAnimated || animated
        } else {
            viewState.pendingScrollToBottomAnimated = animated
        }
    }

    /// Resumes a scroll request that arrived while a pagination/newest-window
    /// load was running. A failed newest-window rebuild falls back to the bottom
    /// of the currently loaded window instead of retrying indefinitely.
    func resumePendingScrollToBottom(allowNewestLoad: Bool = true) {
        guard let animated = viewState.pendingScrollToBottomAnimated else { return }
        viewState.pendingScrollToBottomAnimated = nil

        // A drag that began after the request is newer user intent.
        guard !isUserScrolling else { return }

        if allowNewestLoad {
            scrollToBottom(animated: animated)
        } else {
            scrollToLoadedWindowBottom(animated: animated)
        }
    }

    private func scrollToLoadedWindowBottom(animated: Bool) {
        AssertIsOnMainThread()
        
        // Ensure the view is fully layed out before we try to scroll to the bottom, since
        // we use the collectionView bounds to determine where the "bottom" is.
        self.view.layoutIfNeeded()
        
        let dstY = maxContentOffsetY
        let isScrollDownButtonRequest = viewState.scrollDownButtonTarget == .latestMessage
        let shouldWaitForAnimation = isScrollDownButtonRequest
            && animated
            && abs(collectionView.contentOffset.y - dstY) > 0.5
        if shouldWaitForAnimation {
            viewState.isStartingScrollDownAnimation = true
        }
        collectionView.setContentOffset(.init(x: 0, y: dstY), animated: animated)
        viewState.isStartingScrollDownAnimation = false
        if !shouldWaitForAnimation {
            didScrollToBottom()
        }
    }

    /// Performs a Signal-style scroll action after its collection generation commits.
    /// The action is ignored if a newer user drag has taken ownership of the viewport.
    func performCollectionScrollAction(_ scrollAction: ConversationCollectionScrollAction) {
        AssertIsOnMainThread()

        guard scrollAction.userScrollGeneration == viewState.userScrollGeneration,
              scrollAction.requestGeneration == viewState.scrollActionRequestGeneration,
              !isUserScrolling else {
            // A stale update belongs to an older navigation request. Ignoring it must not
            // cancel a newer button tap that has already taken ownership of the viewport.
            return
        }

        switch scrollAction.destination {
        case .bottomOfLoadWindow:
            scrollToLoadedWindowBottom(animated: scrollAction.isAnimated)
        }
    }
    
    private func didScrollToBottom() {
        if viewState.scrollDownButtonTarget == .latestMessage {
            viewState.scrollDownButtonTarget = nil
        }
        viewState.isStartingScrollDownAnimation = false
        viewState.isScrollDownAnimationRetryScheduled = false
        viewState.scrollDownAnimationRetryCount = 0
        viewState.activeScrollDownCollectionAction = nil
        self.scrollDownButton.isHidden = true

        // We are now at the very bottom, so the newest item is fully seen.
        // Advance the "last visible" markers synchronously here to close the
        // small window where the async update lags behind and briefly flashes
        // the scroll-down button (e.g. right after sending a voice message,
        // whose cell measures its height asynchronously).
        if let lastItem = viewItems.last {
            let sortId = lastItem.interaction.timestampForSorting()
            if sortId > self.lastVisibleSortId {
                self.lastVisibleSortId = sortId
                self.lastMsgSequenceId = lastItem.interaction.sequenceId
                self.lastNotifySequenceId = lastItem.interaction.notifySequenceId
            }
        }

        updateLastVisibleSortIdWithSneakyAsyncTransaction()
    }
}


// MARK: - ScrollDownButton

extension ConversationViewController {
    private var hasUnreadMessages: Bool {
        get { viewState.hasUnreadMessages }
        set {
            guard newValue != viewState.hasUnreadMessages else {
                return
            }
            viewState.hasUnreadMessages = newValue
            scrollDownButton.hasUnreadMessages = newValue
        }
    }
    
    @objc var scrollDownButton: ConversationScrollButton {
        if let button = viewState.scrollDownButton {
            return button
        }
        let newButton = ConversationScrollButton(iconText: "\u{f103}") ?? ConversationScrollButton()
        viewState.scrollDownButton = newButton
        return newButton
    }
    
    @objc func createConversationScrollButtons() {
        self.scrollDownButton.addTarget(
            self,
            action: #selector(scrollDownButtonTapped),
            for: .touchUpInside
        )
        self.scrollDownButton.accessibilityIdentifier = "scrollDownButton"
        
        self.view.addSubview(self.scrollDownButton)
        let buttonSize = ConversationScrollButton.buttonSize()
        self.scrollDownButton.autoSetDimension(.width, toSize: buttonSize)
        self.scrollDownButton.autoSetDimension(.height, toSize: buttonSize)
        self.scrollDownButton.autoPinEdge(.bottom, to: .top, of: self.bottomBar)
        self.scrollDownButton.autoPinEdge(toSuperviewSafeArea: .trailing)
    }
    
    @objc private func scrollDownButtonTapped() {
        // Fix: 解决某些场景下，还未 reload ui 的情况下，执行了 scroll down 操作，引发 crash
        if viewItems.count != dataSource.snapshot().numberOfItems {
            // This tap is an explicit viewport request. An anchor inherited from an
            // in-flight reload must not restore the old position after we choose a target.
            reloadData(viewportAnchorPolicy: .disabled) { [weak self] isFinished in
                guard let self, isFinished else { return }
                self.scrollDown()
            }
        } else {
            scrollDown()
        }
    }
    
    private func scrollDown() {
        if let unreadIndexPath = indexPathOfUnreadMessagesIndicator,
           unreadIndexPath.row < dataSource.snapshot().numberOfItems,
           isViewportAboveUnreadIndicator(at: unreadIndexPath),
           scrollToUnreadIndicator(at: unreadIndexPath, animated: true) {
            // Signal's first stage: while above the divider, stop at unread.
            return
        }

        beginScrollDownButtonTarget(.latestMessage)
        scrollToBottom(animated: true)
    }

    private func beginScrollDownButtonTarget(_ target: ConversationScrollDownTarget) {
        viewState.scrollActionRequestGeneration &+= 1
        viewState.scrollActionForNextUpdate = nil
        viewState.activeScrollDownCollectionAction = nil
        viewState.collectionScrollActionsByGeneration.removeAll()
        viewState.scrollDownButtonTarget = target
        viewState.isStartingScrollDownAnimation = false
        viewState.isScrollDownAnimationRetryScheduled = false
        viewState.scrollDownAnimationRetryCount = 0
        viewState.collectionViewportAnchorsByGeneration.removeAll()
        Logger.info(
            "[ConversationScrollDown] begin target=\(target) offset=\(collectionView.contentOffset.y)"
        )
    }

    func cancelScrollDownButtonNavigation() {
        viewState.scrollActionRequestGeneration &+= 1
        viewState.scrollDownButtonTarget = nil
        viewState.pendingScrollToBottomAnimated = nil
        viewState.scrollActionForNextUpdate = nil
        viewState.activeScrollDownCollectionAction = nil
        viewState.collectionScrollActionsByGeneration.removeAll()
        viewState.isStartingScrollDownAnimation = false
        viewState.isScrollDownAnimationRetryScheduled = false
        viewState.scrollDownAnimationRetryCount = 0
    }

    /// Match Signal's boundary: once any row after the unread divider is visible, the
    /// divider has been reached and the next tap should go directly to the latest message.
    private func isViewportAboveUnreadIndicator(at indexPath: IndexPath) -> Bool {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.isEmpty {
            return visibleIndexPaths.allSatisfy { $0.row <= indexPath.row }
        }

        view.layoutIfNeeded()
        guard let attributes = layout.layoutAttributesForItem(at: indexPath) else { return false }
        let visibleBottomY = collectionView.contentOffset.y
            + collectionView.bounds.height
            - collectionView.adjustedContentInset.bottom
        return visibleBottomY <= attributes.frame.maxY
    }

    @discardableResult
    private func scrollToUnreadIndicator(at indexPath: IndexPath, animated: Bool) -> Bool {
        guard !isUserScrolling else { return false }

        view.layoutIfNeeded()
        guard let attributes = layout.layoutAttributesForItem(at: indexPath) else {
            return false
        }

        beginScrollDownButtonTarget(.unreadIndicator)
        let destinationY = unreadIndicatorDestinationY(attributes: attributes)
        let shouldWaitForAnimation = animated
            && abs(collectionView.contentOffset.y - destinationY) > 0.5
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: destinationY),
            animated: animated
        )
        updateLastKnownDistanceFromBottom()
        if !shouldWaitForAnimation {
            completeScrollDownButtonAnimation()
        }
        return true
    }

    private func unreadIndicatorDestinationY(
        attributes: UICollectionViewLayoutAttributes
    ) -> CGFloat {
        let topInset = collectionView.adjustedContentInset.top
        let minimumOffsetY = -topInset
        return min(
            maxContentOffsetY,
            max(minimumOffsetY, attributes.frame.minY - topInset)
        )
    }

    /// Reapplies the button's semantic destination after either the UIKit animation or
    /// an interrupting diffable snapshot completes. Signal gives programmatic scrolling
    /// ownership over load landing; this is the equivalent coordination for TempTalk.
    func resumeScrollDownButtonTargetAfterCollectionUpdate() {
        guard let target = viewState.scrollDownButtonTarget else { return }
        guard !isUserScrolling else {
            viewState.scrollDownButtonTarget = nil
            return
        }

        switch target {
        case .unreadIndicator:
            finishScrollToUnreadIndicator()

        case .latestMessage:
            // A collection update that inherited the bottom action will call
            // performCollectionScrollAction from its own completion. This fallback covers
            // non-generation layout updates without completing the action prematurely.
            guard !isLoadingOlderItems, !isLoadingNewerItems else { return }
            performCollectionScrollAction(
                ConversationCollectionScrollAction(
                    destination: .bottomOfLoadWindow,
                    isAnimated: true,
                    userScrollGeneration: viewState.userScrollGeneration,
                    requestGeneration: viewState.scrollActionRequestGeneration
                )
            )
        }
    }

    /// Completes only from UIScrollView's animation callback. The scroll timer must not
    /// finalize a long animation while UIKit is still moving toward its destination.
    private func completeScrollDownButtonAnimation() {
        guard let target = viewState.scrollDownButtonTarget else { return }

        switch target {
        case .unreadIndicator:
            finishScrollToUnreadIndicator()

        case .latestMessage:
            view.layoutIfNeeded()
            let destinationY = maxContentOffsetY
            guard abs(collectionView.contentOffset.y - destinationY) <= 1 else {
                if viewState.isScrollDownAnimationRetryScheduled {
                    return
                }

                if viewState.scrollDownAnimationRetryCount > 0 {
                    // UIKit has already interrupted the one recovery animation. Consume the
                    // semantic target before snapping so synchronous delegate callbacks are
                    // idempotent and the button request cannot loop forever.
                    viewState.scrollDownButtonTarget = nil
                    collectionView.setContentOffset(
                        CGPoint(x: collectionView.contentOffset.x, y: destinationY),
                        animated: false
                    )
                    didScrollToBottom()
                    Logger.info(
                        "[ConversationScrollDown] complete target=latestMessage "
                            + "fallback=true offset=\(collectionView.contentOffset.y)"
                    )
                    return
                }

                viewState.scrollDownAnimationRetryCount += 1
                viewState.isScrollDownAnimationRetryScheduled = true
                let requestGeneration = viewState.scrollActionRequestGeneration
                Logger.info(
                    "[ConversationScrollDown] interrupted target=latestMessage "
                        + "offset=\(collectionView.contentOffset.y) destination=\(destinationY)"
                )
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.viewState.scrollDownButtonTarget == .latestMessage,
                          self.viewState.scrollActionRequestGeneration == requestGeneration,
                          !self.isUserScrolling else { return }
                    self.viewState.isScrollDownAnimationRetryScheduled = false
                    self.scrollToLoadedWindowBottom(animated: true)
                }
                return
            }

            didScrollToBottom()
            Logger.info(
                "[ConversationScrollDown] complete target=latestMessage offset=\(collectionView.contentOffset.y)"
            )
        }
    }

    private func finishScrollToUnreadIndicator() {
        // Consume the target before layout; layout can synchronously re-enter scroll callbacks.
        viewState.scrollDownButtonTarget = nil
        view.layoutIfNeeded()
        guard let indexPath = indexPathOfUnreadMessagesIndicator,
              indexPath.row < dataSource.snapshot().numberOfItems,
              let attributes = layout.layoutAttributesForItem(at: indexPath) else {
            beginScrollDownButtonTarget(.latestMessage)
            scrollToBottom(animated: false)
            return
        }

        let destinationY = unreadIndicatorDestinationY(attributes: attributes)
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: destinationY),
            animated: false
        )
        updateLastKnownDistanceFromBottom()
        ensureScrollDownButton()
        Logger.info(
            "[ConversationScrollDown] complete target=unreadIndicator offset=\(collectionView.contentOffset.y)"
        )
    }
    
    @objc func ensureScrollDownButton() {
        AssertIsOnMainThread()
        
        if peek {
            scrollDownButton.isHidden = true
            return
        }

        // Do not hide the control merely because the newest row became visible during
        // the animation. It is complete only after the final content offset is reached.
        if viewState.scrollDownButtonTarget != nil {
            scrollDownButton.isHidden = false
            return
        }
        
        let contentInset = collectionView.contentInset
        let contentOffsetY = collectionView.contentOffset.y
        let collectionViewHeight = collectionView.frame.size.height
        
        let spaceToBottom = safeContentHeight + contentInset.bottom - (contentOffsetY + collectionViewHeight)
        let pageHeight = collectionViewHeight - (contentInset.top + contentInset.bottom)

        // Show the button once the user has scrolled up at least one page.
        let isScrolledUpOnePage = spaceToBottom > pageHeight

        // Or when there is newer content the user hasn't reached yet: a later
        // message not yet seen (only meaningful when not already at the bottom,
        // otherwise the newest message is on screen), or newer items still
        // outside the loaded window.
        let hasLaterMessageOffscreen = (!isScrolledToBottom
            && (viewItems.last?.interaction.timestampForSorting() ?? 0) > self.lastVisibleSortId)
            || conversationViewModel.canLoadNewerItems()

        let shouldShowScrollDownButton = !viewItems.isEmpty && (isScrolledUpOnePage || hasLaterMessageOffscreen)
        self.scrollDownButton.isHidden = !shouldShowScrollDownButton
    }
}

// MARK: - DateSeparatorView

extension ConversationViewController {
    private var dateSeparatorView: ConversationDateSeparatorView? {
        get { viewState.dateSeparatorView }
        set { viewState.dateSeparatorView = newValue }
    }

    private func hideDateSeparator() {
        dateSeparatorView?.isHidden = true
    }

    private func showDateSeparator() {
        dateSeparatorView?.isHidden = false
    }

    private func ensureDateSeparatorViewExists() {
        guard dateSeparatorView == nil else { return }
        let separatorView = ConversationDateSeparatorView()
        view.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top) // 初始约束，后续会更新
            make.centerX.equalToSuperview()
        }
        dateSeparatorView = separatorView
    }

    private func updateDateSeparatorConstraints(joinbarHeight: CGFloat) {
        guard let dateSeparatorView else { return }

        // The E2EE notice is part of the scrollable conversation content. Its
        // content inset must not push the floating date header down after the
        // notice has scrolled away. Keep the legacy stranger-warning offset.
        let noticeHeaderOffset: CGFloat
        switch conversationNoticeHeaderStyle {
        case .stranger:
            noticeHeaderOffset = collectionView.contentInset.top
        case .endToEndEncryption, .none:
            noticeHeaderOffset = 0
        }

        let topOffset = noticeHeaderOffset + joinbarHeight
        guard viewState.dateSeparatorTopOffset != topOffset else { return }
        viewState.dateSeparatorTopOffset = topOffset

        dateSeparatorView.snp.updateConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
                .offset(topOffset)
        }
    }

    private func refreshDateSeparator() {
        let currentOffset = CGPoint(
            x: collectionView.contentOffset.x,
            y: collectionView.contentOffset.y + collectionView.contentInset.top
        )
        let minScrollDistance = ConversationDateSeparatorView.Constants.height
        guard currentOffset.y > minScrollDistance else {
            if let dateSeparatorView, !dateSeparatorView.isHidden {
                hideDateSeparator()
            }
            return
        }

        let fixedOffset: CGPoint = .init(
            x: currentOffset.x,
            y: isScrollUp ? currentOffset.y : currentOffset.y - minScrollDistance * 0.5
        )
        guard
            let indexPath = collectionView.indexPathForItem(at: fixedOffset),
            let viewItem = viewItem(for: indexPath.row)
        else { return }

        // Skip floating date for archive system messages
        if let infoMessage = viewItem.interaction as? TSInfoMessage,
           infoMessage.messageType == .archiveMessage {
            if let dateSeparatorView, !dateSeparatorView.isHidden {
                hideDateSeparator()
            }
            return
        }

        // 处理生成系统消息0，导致的日期显示问题
        let date = viewItem.interaction.dateForSorting()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let targetDate = dateFormatter.date(from: "2000-01-01"), date < targetDate {
            return
        }

        ensureDateSeparatorViewExists()
        let joinbarHeight = showJoinBarView() ? showJoinBarViewHeight() : 0
        updateDateSeparatorConstraints(joinbarHeight: joinbarHeight)

        showDateSeparator()
        dateSeparatorView?.configure(viewItem: viewItem)
        dateSeparatorView?.refreshTheme()
    }

    func refreshDateSeparatorViewPosition() {
        guard dateSeparatorView?.superview != nil else { return }
        let joinbarHeight = showJoinBarView() ? showJoinBarViewHeight() : 0
        updateDateSeparatorConstraints(joinbarHeight: joinbarHeight)
    }
}

// MARK: -

@objc
extension ConversationViewController {
    var lastVisibleIndexPath: IndexPath? {
        var lastVisibleIndexPath: IndexPath?
        collectionView.indexPathsForVisibleItems.forEach {
            if let currentValue = lastVisibleIndexPath {
                if $0.row > currentValue.row {
                    lastVisibleIndexPath = $0
                }
            } else {
                lastVisibleIndexPath = $0
            }
        }
        
        let items = self.viewItems
        if let lastVisibleIndexPath, lastVisibleIndexPath.row > items.count {
            // unclear to me why this should happen, so adding an assert to catch it.
            owsFailDebug("invalid lastVisibleIndexPath")
            if items.isEmpty {
                return nil
            }
            return IndexPath(row: items.count - 1, section: 0)
        }
        
        return lastVisibleIndexPath
    }
    
    // Certain view states changes (scroll state, view layout, etc.) can
    // update which messages are visible and thus should be marked as
    // read.  Many of those changes occur when UIKit responds to some
    // app activity that may have an open transaction.  Therefore, we
    // update the "last visible sort id" async to avoid opening a
    // transaction within a transaction.
    func updateLastVisibleSortIdWithSneakyAsyncTransaction() {
        DispatchQueue.main.async {
            self.updateLastVisibleSortId()
        }
    }
    
    func updateLastVisibleSortId() {
        AssertIsOnMainThread()
        
        if let indexPath = self.lastVisibleIndexPath,
           let lastVisibleViewItem = self.viewItem(for: indexPath.row) {
            
            let lastVisibleSortId = lastVisibleViewItem.interaction.timestampForSorting()
            if lastVisibleSortId > self.lastVisibleSortId {
                self.lastVisibleSortId = lastVisibleSortId
                self.lastMsgSequenceId = lastVisibleViewItem.interaction.sequenceId
                self.lastNotifySequenceId = lastVisibleViewItem.interaction.notifySequenceId
            }
        }
        
        ensureScrollDownButton()
        
        let unreadCount = self.thread.unreadMessageCount
        self.hasUnreadMessages = unreadCount > 0
    }
}

// MARK: - UIScrollViewDelegate

extension ConversationViewController: UIScrollViewDelegate {
    private var lastPosition: CGFloat {
        get { viewState.lastPosition }
        set { viewState.lastPosition = newValue }
    }
    
    private var isScrollUp: Bool {
        get { viewState.isScrollUp }
        set { viewState.isScrollUp = newValue }
    }
    
    var isUserScrolling: Bool {
        get { viewState.isUserScrolling }
        set {
            viewState.isUserScrolling = newValue
            autoLoadMoreIfNecessary()
        }
    }
    
    var userHasScrolled: Bool {
        get { viewState.userHasScrolled }
        set { viewState.userHasScrolled = newValue }
    }
    
    var lastKnownDistanceFromBottom: CGFloat? {
        get { viewState.lastKnownDistanceFromBottom }
        set { viewState.lastKnownDistanceFromBottom = newValue }
    }
    
    @objc var scrollUpdateTimer: Timer? {
        get { viewState.scrollUpdateTimer }
        set { viewState.scrollUpdateTimer = newValue }
    }
    
    var isScrollingToTop: Bool {
        get { viewState.isScrollingToTop }
        set { viewState.isScrollingToTop = newValue }
    }

    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        performCustomScrollToTop()
        return false
    }

    private func performCustomScrollToTop() {
        cancelScrollDownButtonNavigation()
        isScrollingToTop = true
        viewState.scrollStateBeforeLoadingMore = nil

        let topOffset = -collectionView.adjustedContentInset.top
        let currentOffset = collectionView.contentOffset.y
        let twoScreenHeight = collectionView.bounds.height * 2
        let distance = currentOffset - topOffset

        if distance <= twoScreenHeight {
            // 短距离，直接动画
            UIView.animate(withDuration: 0.3, animations: {
                self.collectionView.setContentOffset(CGPoint(x: 0, y: topOffset), animated: false)
            }, completion: { completed in
                self.finishScrollToTop(didComplete: completed)
            })
        } else {
            // 长距离：先无动画跳到接近顶部（一屏距离），再短距离动画滑到顶部
            let nearTopOffset = topOffset + collectionView.bounds.height
            collectionView.setContentOffset(CGPoint(x: 0, y: nearTopOffset), animated: false)

            DispatchQueue.main.async {
                guard self.isScrollingToTop else { return }

                UIView.animate(withDuration: 0.3, animations: {
                    self.collectionView.setContentOffset(CGPoint(x: 0, y: topOffset), animated: false)
                }, completion: { completed in
                    self.finishScrollToTop(didComplete: completed)
                })
            }
        }
    }

    private func finishScrollToTop(didComplete: Bool) {
        // A drag clears this flag before cancelling the animation, so its delayed
        // completion must not move the viewport or update the header mid-gesture.
        guard isScrollingToTop else { return }

        isScrollingToTop = false
        guard didComplete else {
            updateWarningHeaderLayout()
            return
        }

        isScrollUp = false
        autoLoadMoreIfNecessary()
        updateWarningHeaderLayout()
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
        updateLastVisibleSortIdWithSneakyAsyncTransaction()
    }

    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        finishScrollToTop(didComplete: true)
    }

    // MARK: - scrollViewDidScroll

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if viewHasEverAppeared {
            updateLastKnownDistanceFromBottom()
        }

        guard !isScrollingToTop else { return }

        scheduleScrollUpdateTimer()

        // 更新滚动方向
        let position = scrollView.contentOffset.y
        if position - lastPosition > 5, position > 0 {
            lastPosition = position
            isScrollUp = true
        } else if lastPosition - position > 5, position <= scrollView.contentSize.height - scrollView.bounds.size.height - 5 {
            lastPosition = position
            isScrollUp = false
        }
        
        refreshDateSeparator()
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户手指触摸会打断 scroll-to-top 动画
        if isScrollingToTop {
            isScrollingToTop = false
        }

        userHasScrolled = true
        viewState.userScrollGeneration &+= 1
        cancelScrollDownButtonNavigation()
        isUserScrolling = true
        actionMenuController?.hideMenu(animation: false)

        dismissKeyBoard(byUserAction: true)

        // 清除搜索跳转的焦点消息
        if viewState.hasCompletedInitialScroll {
            conversationViewModel.clearFocusMessageIndex()
            conversationViewModel.focusMessageIdOnOpen = nil
        }

        // 清除初始滚动保护
        if viewState.initialScrollTargetOffset != nil {
            viewState.initialScrollTargetOffset = nil
            viewState.initialScrollProtectionDeadline = nil
        }
        viewState.isFocusKeyboardPresentationComplete = false

        refreshDateSeparator()
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if let actionMenuController {
            let offset = targetContentOffset.pointee.y - scrollView.contentOffset.y
            actionMenuController.dismissMenuIfNeed(offset: offset)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard isUserScrolling else {
            return
        }
        isWaitingForDeceleration = decelerate
        isUserScrolling = false
        
        if !decelerate {
            scheduleScrollUpdateTimer()
            updateWarningHeaderLayout()

            actionMenuController?.showMenu(animation: true)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard isWaitingForDeceleration else {
            return
        }
        isWaitingForDeceleration = false

        scheduleScrollUpdateTimer()
        updateWarningHeaderLayout()

        actionMenuController?.showMenu(animation: true)
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // setContentOffset(animated:) can synchronously report the animation it just
        // superseded. The replacement animation has not had a chance to move yet.
        guard !viewState.isStartingScrollDownAnimation else { return }

        completeScrollDownButtonAnimation()

        scheduleScrollUpdateTimer()
    }
    
    @objc func updateLastKnownDistanceFromBottom() {
        // Never update the lastKnownDistanceFromBottom,
        // if we're presenting the message actions which
        // temporarily meddles with the content insets.
        lastKnownDistanceFromBottom = safeDistanceFromBottom
    }
    
    private func scheduleScrollUpdateTimer() {
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = Timer.weakScheduledTimer(
            withTimeInterval: 0.1,
            target: self,
            selector: #selector(scrollUpdateTimerDidFire),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func scrollUpdateTimerDidFire() {
        guard viewHasEverAppeared else {
            return
        }

        autoLoadMoreIfNecessary()
        updateLastVisibleSortIdWithSneakyAsyncTransaction()
    }
    
    func stopScrollUpdateTimer() {
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = nil
    }
}


// MARK: - Load More

extension ConversationViewController {
    var isShowLoadOlderHeader: Bool {
        get { viewState.isShowLoadOlderHeader }
        set { viewState.isShowLoadOlderHeader = newValue }
    }
    
    var isShowLoadNewerHeader: Bool {
        get { viewState.isShowLoadNewerHeader }
        set { viewState.isShowLoadNewerHeader = newValue }
    }
    
    var isShowFetchOlderHeader: Bool {
        get { viewState.isShowFetchOlderHeader }
        set { viewState.isShowFetchOlderHeader = newValue }
    }
    
    var isShowFetchNewerHeader: Bool {
        get { viewState.isShowFetchNewerHeader }
        set { viewState.isShowFetchNewerHeader = newValue }
    }
    
    var scrollContinuity: ScrollContinuity {
        get { viewState.scrollContinuity }
        set { viewState.scrollContinuity = newValue }
    }
    
    var lastReloadDate: Date? {
        get { viewState.lastReloadDate }
        set { viewState.lastReloadDate = newValue }
    }
    
    private func autoLoadMoreIfNecessary() {
        // scroll-to-top 动画期间不触发加载更多
        guard !isScrollingToTop else { return }
        // ConversationViewModel serializes older/newer pagination with one shared flag.
        // Mirror that ownership here so a request in the opposite direction cannot start.
        guard !isLoadingOlderItems, !isLoadingNewerItems else { return }

        let isMainAppAndActive = CurrentAppContext().isMainAppAndActive
        if isUserScrolling || isWaitingForDeceleration || !isViewVisible || !isMainAppAndActive {
            return
        }
        
        if !isShowLoadOlderHeader, !isShowLoadNewerHeader, !isShowFetchOlderHeader, !isShowFetchNewerHeader {
            return
        }
        
        let viewSize = navigationController?.view.frame.size ?? .zero
        let loadThreshold = max(viewSize.width, viewSize.height) * 3
        
        let closeToTop = collectionView.contentOffset.y < loadThreshold
        if closeToTop, !isScrollUp {

            Logger.info("[hot data] ------ ⬆️⬆️⬆️")

            if isShowLoadOlderHeader {
                isLoadingOlderItems = true
                var didStartLoading = false
                BenchManager.bench(title: "loading older interactions") {
                    self.databaseStorage.uiRead { transaction in
                        didStartLoading = self.conversationViewModel.appendOlderItems(with: transaction)
                    }
                }
                if !didStartLoading {
                    isLoadingOlderItems = false
                }
            } else if isShowFetchOlderHeader {
                if conversationViewModel.messageMapping.isFetchingData.get() {
                    return
                }
            }
        }
        
        let distanceFromBottom = collectionView.contentSize.height - collectionView.bounds.size.height - collectionView.contentOffset.y
        let closeToBottom = distanceFromBottom < loadThreshold
        if closeToBottom, isScrollUp {

            Logger.info("[hot data] ------ ⬇️⬇️⬇️")

            if isShowLoadNewerHeader {
                isLoadingNewerItems = true
                var didStartLoading = false
                BenchManager.bench(title: "loading newer interactions") {
                    self.databaseStorage.uiRead { transaction in
                        didStartLoading = self.conversationViewModel.appendNewerItems(with: transaction)
                    }
                }
                if !didStartLoading {
                    isLoadingNewerItems = false
                }
            } else if isShowFetchNewerHeader {
                if conversationViewModel.messageMapping.isFetchingData.get() {
                    return
                }
            }
        }
    }
    
    // TODO: PERF 找到合适时机处理 loadOlder 和 loadNewer
    func resetShowLoadMore() {
        AssertIsOnMainThread()
        
        databaseStorage.uiRead { transaction in
            self.updateShowLoadMoreHeaders(transaction: transaction)
        }
    }
    
    func updateShowLoadMoreHeaders(transaction: SDSAnyReadTransaction) {
        let valueChanged = updateShowLoadMoreHeaders()
        if valueChanged, viewHasEverAppeared {
            resetContentAndLayout(transaction: transaction, invalidateLayout: true)
        }
    }
    
    func updateShowLoadMoreHeaders() -> Bool {
        let canLoadOlderItems = conversationViewModel.canLoadOlderItems()
        let canFetchOlderItems = conversationViewModel.canFetchOlderItems()
        let canLoadNewerItems = conversationViewModel.canLoadNewerItems()
        let canFetchNewerItems = conversationViewModel.canFetchNewerItems()
        
        let valueChanged = canLoadOlderItems != isShowLoadOlderHeader
            || canFetchOlderItems != isShowFetchOlderHeader
            || canLoadNewerItems != isShowLoadNewerHeader
            || canFetchNewerItems != isShowFetchNewerHeader
        
        isShowLoadOlderHeader = canLoadOlderItems
        isShowFetchOlderHeader = canFetchOlderItems
        isShowLoadNewerHeader = canLoadNewerItems
        isShowFetchNewerHeader = canFetchNewerItems
        
        Logger.info("[Conversation] showLoadOlderHeader:\(isShowLoadOlderHeader) showLoadNewerHeader: \(isShowLoadNewerHeader)")
        
        return valueChanged
    }
    
    @objc func resetContentAndLayoutWithSneakyTransaction() {
        Logger.info("[Conversation] request uiRead")
        databaseStorage.uiRead { transaction in
            Logger.info("[Conversation] got transaction, calling resetContentAndLayout")
            self.resetContentAndLayout(transaction: transaction)
        }
    }
    
    func resetContentAndLayout(
        transaction: SDSAnyReadTransaction,
        forceRealodRange: ReloadRange = .all,
        viewportAnchorPolicy explicitViewportAnchorPolicy: ConversationViewportAnchorPolicy? = nil,
        invalidateLayout: Bool = false,
        scrollAction: ConversationCollectionScrollAction? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        let viewportAnchorPolicy: ConversationViewportAnchorPolicy
        if let explicitViewportAnchorPolicy {
            viewportAnchorPolicy = explicitViewportAnchorPolicy
        } else if let viewportAnchor = captureViewportAnchor() {
            viewportAnchorPolicy = .preserve(viewportAnchor)
        } else {
            viewportAnchorPolicy = .inherit
        }
        scrollContinuity = .bottom
        
        // Avoid layout corrupt issues and out-of-date message subtitles.
        lastReloadDate = Date()
        conversationViewModel.viewDidResetContentAndLayout(with: transaction)
        
        reloadData(
            forceRealodRange: forceRealodRange,
            viewportAnchorPolicy: viewportAnchorPolicy,
            invalidateLayout: invalidateLayout,
            scrollAction: scrollAction
        ) { [weak self] isFinished in
            guard let self else { return }
            if self.viewHasEverAppeared, isFinished {
                // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
                self.updateLastKnownDistanceFromBottom()
            }
            Logger.info("[Conversation] end finished=\(isFinished) items(after)=\(self.viewItems.count) renderItems=\(self.renderItems.count) contentSize=\(self.collectionView.contentSize)")
            completion?(isFinished)
        }
    }
}

// MARK: - Mentioned Message Jump

extension ConversationViewController {
    private var mentionMessagesJumpManager: DTMentionMessagesJumpManager? {
        get { viewState.mentionMessagesJumpManager }
        set { viewState.mentionMessagesJumpManager = newValue }
    }
    
    func prepareForMentionMessage() {
        guard isGroupConversation, let groupThread = self.thread as? TSGroupThread else {
            return
        }
        self.mentionMessagesJumpManager = DTMentionMessagesJumpManager(
            conversationViewThread: groupThread,
            iconViewLayoutBlock: { [weak self] indicatorView in
                
                guard let self else { return }
                self.view.addSubview(indicatorView)
                let size = ConversationScrollButton.buttonSize()
                indicatorView.autoPinEdge(.bottom, to: .top, of: self.scrollDownButton)
                indicatorView.autoPinEdge(.right, to: .right, of: self.scrollDownButton)
                indicatorView.autoSetDimensions(to: .init(width: size, height: size))
                
            },
            jump: { [weak self] focusMessage in
                
                guard let self else { return }
                Logger.info("jump to message")
                
                self.forcusMessage(focusMessage, animated: true)
                DispatchQueue.main.async {
                    // TODO: Jaymin 为什么执行两遍?
                    self.forcusMessage(focusMessage, animated: false)
                }
            }
        )
    }
    
    func refreshMentionMessageCount() {
        self.mentionMessagesJumpManager?.handleMentionedMessagesOnce()
    }
    
    private func forcusMessage(_ message: TSMessage, animated: Bool) {
        cancelScrollDownButtonNavigation()
        databaseStorage.uiRead { transaction in
            self.conversationViewModel.ensureLoadWindowContainsInteractionId(
                message.uniqueId,
                transaction: transaction,
                completion: { [weak self] indexPath in
                    guard let self else { return }
                    guard let indexPath, indexPath.row < self.dataSource.snapshot().numberOfItems else {
                        return
                    }
                    self.collectionView.scrollToItem(
                        at: indexPath,
                        at: .centeredVertically,
                        animated: animated
                    )
                }
            )
        }
    }
}

// MARK: - DTPanModalNavigationChildController

extension ConversationViewController: DTPanModalNavigationChildController {
    // 解决从个人信息页进入会话页时，若又 present 一个新的 vc (比如点击图片预览器)，
    // 当新的 vc dismiss 时，需要更新当前会话页展示位置
    func layoutDidUpdateWhenViewWillAppear() {
        // Don't auto-scroll to bottom when returning from call window
        // The user should stay at their current scroll position
        if isReturningFromCallWindow {
            isReturningFromCallWindow = false
        }
    }
}
