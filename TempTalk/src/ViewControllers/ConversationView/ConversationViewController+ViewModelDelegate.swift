//
//  ConversationViewController+ViewModelDelegate.swift
//  Signal
//
//  Created by Jaymin on 2024/2/4.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

extension ConversationViewController: ConversationViewModelDelegate {
    private var scrollStateBeforeLoadingMore: ConversationScrollState? {
        get { viewState.scrollStateBeforeLoadingMore }
        set { viewState.scrollStateBeforeLoadingMore = newValue }
    }
    
    private var isNeedReloadAfterAppEnterForeground: Bool {
           get { viewState.isNeedReloadAfterAppEnterForeground }
           set { viewState.isNeedReloadAfterAppEnterForeground = newValue }
    }

    func reloadAfterAppEnterForegroundIfNeed() {
        let didChangeLoadMoreHeaderState = updateShowLoadMoreHeaders()
        let forceLoadMoreHeaderLayoutUpdate =
            viewState.pendingConversationLoadMoreHeaderLayoutUpdate
            || didChangeLoadMoreHeaderState

        // Foreground notifications are delivered to conversation controllers that are still in
        // the navigation stack. Keep their collection work deferred until viewIsAppearing makes
        // them visible again; that path calls back into this method when a full reload is pending.
        guard isViewVisible else {
            viewState.pendingConversationLoadMoreHeaderLayoutUpdate =
                forceLoadMoreHeaderLayoutUpdate
            return
        }
        viewState.pendingConversationLoadMoreHeaderLayoutUpdate = false

        guard isNeedReloadAfterAppEnterForeground else {
            applyPendingCollectionUpdateIfNeeded(
                forceLoadMoreHeaderLayoutUpdate: forceLoadMoreHeaderLayoutUpdate
            )
            return
        }

        isNeedReloadAfterAppEnterForeground = false
        let shouldScrollToBottom = viewState.pendingConversationShouldScrollToBottom
            && conversationViewModel.focusMessageIdOnOpen == nil
        // The foreground reload supersedes any off-screen incremental update.
        viewState.pendingConversationCollectionUpdate = .none
        viewState.pendingConversationShouldScrollToBottom = false
        let reloadViewportAnchorPolicy: ConversationViewportAnchorPolicy? =
            shouldScrollToBottom ? .disabled : nil

        let reloadUpdate = ConversationUpdate.reload()
        databaseStorage.uiRead { transation in
            self._conversationViewModelDidUpdate(
                reloadUpdate,
                transaction: transation,
                reloadViewportAnchorPolicy: reloadViewportAnchorPolicy,
                reloadShouldInvalidateLayout: forceLoadMoreHeaderLayoutUpdate
            ) { [weak self] isFinished in
                guard let self else { return }
                if !isFinished, forceLoadMoreHeaderLayoutUpdate {
                    self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate = true
                }
                if isFinished, shouldScrollToBottom {
                    self.scrollToBottom(animated: false)
                }
            }
        }
    }
    
    func conversationViewModelDidLoadInitialMessages(completion: @escaping ((Bool) -> Void)) {
        Logger.info("[Conversation] handle initial messages, threadId:\(thread.uniqueId)")

        guard viewState.initialLoadPhase == .loading else {
            Logger.warn("[Conversation] ignore duplicate initial messages callback, threadId:\(thread.uniqueId)")
            completion(false)
            return
        }
        viewState.initialLoadPhase = .ready

        guard isViewVisible else {
            Logger.info("[Conversation] queue refresh ui for initial messages until view visible, threadId:\(thread.uniqueId)")
            storePendingInitialLoadCompletion(completion)
            return
        }
        performInitialMessagesRefresh(completion: completion)
    }
    
    func conversationViewModelDidUpdate(
        _ conversationUpdate: ConversationUpdate,
        transaction: SDSAnyReadTransaction?,
        completion: ((Bool) -> Void)? = nil
    ) {
        Logger.info("[Conversation] type=\(conversationUpdate.conversationUpdateType)  shouldObserve=\(shouldObserveDBModifications) isViewLoaded=\(isViewLoaded)")
        if let transaction {
            _conversationViewModelDidUpdate(
                conversationUpdate,
                transaction: transaction,
                completion: completion
            )
        } else {
            databaseStorage.uiRead { transation in
                self._conversationViewModelDidUpdate(
                    conversationUpdate,
                    transaction: transation,
                    completion: completion
                )
            }
        }
    }
    
    private func _conversationViewModelDidUpdate(
        _ conversationUpdate: ConversationUpdate,
        transaction: SDSAnyReadTransaction,
        reloadViewportAnchorPolicy: ConversationViewportAnchorPolicy? = nil,
        reloadShouldInvalidateLayout: Bool = false,
        completion: ((Bool) -> Void)?
    ) {
        AssertIsOnMainThread()

        // The initial snapshot is authoritative. Coalesce database notifications
        // that race it instead of letting them expose a provisional render state.
        guard viewState.initialLoadPhase == .applied else {
            if isViewLoaded {
                recordPendingCollectionUpdate(conversationUpdate)
            }
            completion?(false)
            return
        }
        
        // FIX: https://developer.apple.com/forums/thread/728797
        if !isViewLoaded || !shouldObserveDBModifications {
            // Avoid mutating the collection view while it is off-screen, but don't
            // discard the reason for the update. viewIsAppearing will coalesce and
            // apply the minimum required snapshot invalidation.
            if isViewLoaded {
                recordPendingCollectionUpdate(conversationUpdate)
            }
            completion?(false)
            
            // 3.1.8 当应用进入后台，websocket 还未断开时，仍然能接收到 database change，
            // 但此时 shouldObserveDBModifications = false，无法触发刷新，而 app 返回前台后，若没有新的数据，也无法刷新
            // 为了解决上述问题，当应用进入后台且接收到 database change 时，记录下标志位 isNeedReloadAfterAppEnterForeground，
            // 在应用返回前台时进行刷新
            if CurrentAppContext().isInBackground() {
                Logger.info("[Conversation] ignore refresh when app in background, threadId:\(thread.uniqueId)")
                isNeedReloadAfterAppEnterForeground = true
            } else {
                Logger.info("[Conversation] ignore refresh when isViewDidLoaded:\(isViewLoaded), shouldObserveDBModifications:\(shouldObserveDBModifications) threadId:\(thread.uniqueId)")
            }
            
            return
        }
        
        DispatchQueue.main.async {
            // TODO: sneakTransaction
            self.updateNavigationBarSubtitleLabel()
            self.resetShowLoadMore()
        }
        
        if isGroupConversation {
            self.thread.anyReload(transaction: transaction)
            DispatchQueue.main.async {
                // TODO: sneakTransaction
                self.updateNavigationTitle()
                self.hideInputIfNeeded()
                self.updateBarButtonItems()
            }
        }
                
        switch conversationUpdate.conversationUpdateType {
        case .reload:
            let scrollAction = viewState.scrollActionForNextUpdate
            viewState.scrollActionForNextUpdate = nil
            let shouldInvalidateLayout = reloadShouldInvalidateLayout
                || viewState.pendingConversationLoadMoreHeaderLayoutUpdate
            viewState.pendingConversationLoadMoreHeaderLayoutUpdate = false
            Logger.info("[Conversation] will resetContentAndLayout (reload) threadId:\(thread.uniqueId)")
            resetContentAndLayout(
                transaction: transaction,
                viewportAnchorPolicy: reloadViewportAnchorPolicy,
                invalidateLayout: shouldInvalidateLayout,
                scrollAction: scrollAction
            ) { [weak self] isFinished in
                guard let self else { return }
                if !isFinished, shouldInvalidateLayout {
                    self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate = true
                }
                Logger.info("[Conversation] resetContentAndLayout finished=\(isFinished) contentSize=\(self.collectionView.contentSize) threadId:\(thread.uniqueId)")
                if isFinished {
                    self.updateLastVisibleSortId()
                }
                self.pruneSelectedMessagesIfNeeded()
                completion?(isFinished)
            }
        case .diff:
            let shouldInvalidateLayout = viewState.pendingConversationLoadMoreHeaderLayoutUpdate
            viewState.pendingConversationLoadMoreHeaderLayoutUpdate = false
            Logger.info("[Conversation] diff update, items before=\(viewItems.count) threadId:\(thread.uniqueId)")
            updateWithDiff(
                conversationUpdate,
                invalidateLayout: shouldInvalidateLayout
            ) { [weak self] isFinished in
                guard let self else { return }
                if !isFinished, shouldInvalidateLayout {
                    self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate = true
                }
                self.pruneSelectedMessagesIfNeeded()
                completion?(isFinished)
            }
        default:
            Logger.info("[Conversation] default update threadId:\(thread.uniqueId)")
            completion?(true)
            break
        }
    }

    private func recordPendingCollectionUpdate(_ conversationUpdate: ConversationUpdate) {
        let pendingUpdate: PendingConversationCollectionUpdate
        switch conversationUpdate.conversationUpdateType {
        case .minor:
            return
        case .reload:
            pendingUpdate = .reloadAll
        case .diff:
            let wasScrolledToBottom = isScrolledToBottom
            var shouldScrollToBottom = false
            let updatedItemIds = Set((conversationUpdate.updateItems ?? []).compactMap { updateItem -> String? in
                switch updateItem.updateItemType {
                case .insert:
                    if let message = updateItem.viewItem?.interaction as? TSMessage {
                        let isTailInsert = updateItem.newIndex == viewItems.count - 1
                        if isTailInsert,
                           let outgoingMessage = message as? TSOutgoingMessage,
                           !outgoingMessage.isFromLinkedDevice {
                            shouldScrollToBottom = true
                        } else if isTailInsert, wasScrolledToBottom {
                            shouldScrollToBottom = true
                        }
                    }
                    return updateItem.viewItem?.interaction.uniqueId
                case .update:
                    return updateItem.viewItem?.interaction.uniqueId
                case .delete:
                    return nil
                @unknown default:
                    return nil
                }
            })
            // Keep an empty diff as meaningful: it may contain only deletions, which
            // the next diffable snapshot will discover without explicit reload IDs.
            pendingUpdate = .diff(updatedItemIds: updatedItemIds)
            viewState.pendingConversationShouldScrollToBottom =
                viewState.pendingConversationShouldScrollToBottom || shouldScrollToBottom
        @unknown default:
            pendingUpdate = .reloadAll
        }

        viewState.pendingConversationCollectionUpdate.merge(pendingUpdate)
    }

    /// Applies the latest view-model state after returning from another screen.
    /// The diffable snapshot handles inserts/deletes; existing cells are rebuilt
    /// only when their interaction IDs were explicitly updated.
    @discardableResult
    func applyPendingCollectionUpdateIfNeeded(
        forceLoadMoreHeaderLayoutUpdate: Bool = false,
        allowViewportAnchorBeforeFirstAppearance: Bool = false
    ) -> Bool {
        let pendingUpdate = viewState.pendingConversationCollectionUpdate
        guard pendingUpdate != .none || forceLoadMoreHeaderLayoutUpdate else { return false }
        viewState.pendingConversationCollectionUpdate = .none
        let shouldScrollToBottom = viewState.pendingConversationShouldScrollToBottom
        viewState.pendingConversationShouldScrollToBottom = false

        let shouldFollowToBottom = shouldScrollToBottom
            && conversationViewModel.focusMessageIdOnOpen == nil
        let viewportAnchorPolicy: ConversationViewportAnchorPolicy
        if shouldFollowToBottom {
            viewportAnchorPolicy = .disabled
        } else if let viewportAnchor = captureViewportAnchor(
            allowBeforeFirstAppearance: allowViewportAnchorBeforeFirstAppearance
        ) {
            viewportAnchorPolicy = .preserve(viewportAnchor)
        } else {
            viewportAnchorPolicy = .inherit
        }
        let reloadRange: ReloadRange
        switch pendingUpdate {
        case .none:
            reloadRange = .none
        case .diff(let updatedItemIds):
            reloadRange = updatedItemIds.isEmpty
                ? .none
                : .part(uniqueIds: Array(updatedItemIds))
        case .reloadAll:
            reloadRange = .all
        }

        reloadData(
            forceRealodRange: reloadRange,
            viewportAnchorPolicy: viewportAnchorPolicy,
            invalidateLayout: forceLoadMoreHeaderLayoutUpdate,
            followToBottom: shouldFollowToBottom
        ) { [weak self] isFinished in
            guard let self else { return }
            guard isFinished else {
                if forceLoadMoreHeaderLayoutUpdate {
                    self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate = true
                }
                return
            }
            self.updateLastKnownDistanceFromBottom()
        }
        return true
    }
    
    public func conversationViewModelWillLoadMoreItems() {
        AssertIsOnMainThread()
        scrollStateBeforeLoadingMore = nil
        
        // To maintain scroll position after changing the items loaded in the conversation view:
        //
        // 1. in conversationViewModelWillLoadMoreItems
        //   - Get position of some interactions cell before transition.
        //   - Get content offset before transition
        //
        // 2. Load More
        //
        // 3. in conversationViewModelDidFinishLoadMoreItems
        //   - Get position of that same interaction's cell (it'll have a new index)
        //   - Get content offset after transition
        //   - Offset scrollViewContent so that the cell is in the same spot after as it was before.
        guard let indexPath = self.lastVisibleIndexPath else {
            // nothing visible yet
            return
        }

        guard let viewItem = viewItem(for: indexPath.row) else {
            owsFailDebug("viewItem was unexpectedly nil")
            return
        }

        // 使用 layoutAttributesForItem 获取准确的 frame
        guard let layoutAttributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            owsFailDebug("layoutAttributes was unexpectedly nil")
            return
        }

        let frame = layoutAttributes.frame
        let contentOffset = collectionView.contentOffset
        scrollStateBeforeLoadingMore = ConversationScrollState(
            referenceViewItem: viewItem,
            referenceFrame: frame,
            contentOffset: contentOffset
        )
    }
    
    public func conversationViewModelDidFinishLoadMoreItems(withSuccess success: Bool) {
        AssertIsOnMainThread()
        defer {
            isLoadingOlderItems = false
            isLoadingNewerItems = false
            scrollStateBeforeLoadingMore = nil
            updateWarningHeaderLayout()
            resumePendingScrollToBottom()
        }

        guard success else { return }
        self.layout.prepare()

        // scroll-to-top 动画期间不调整 contentOffset，避免与系统动画冲突导致闪烁
        guard !isScrollingToTop else { return }

        guard let scrollState = self.scrollStateBeforeLoadingMore else { return }

        guard let newIndexPath = conversationViewModel.indexPath(for: scrollState.referenceViewItem),
              let layoutAttributes = collectionView.layoutAttributesForItem(at: newIndexPath) else {
            return
        }

        // 强制布局更新，确保 cell 的位置是正确的
        collectionView.layoutIfNeeded()

        let newFrame = layoutAttributes.frame
        let previousDistance = scrollState.referenceFrame.origin.y - scrollState.contentOffset.y
        let newDistance = newFrame.origin.y - previousDistance

        collectionView.contentOffset = CGPoint(x: 0, y: newDistance)
    }
    
    public func conversationViewModelDidUpdateLoadMoreStatus() {
        AssertIsOnMainThread()
        
        let didChange = updateShowLoadMoreHeaders()
        if didChange {
            // The next snapshot invalidates the cached supplementary attributes only after its
            // render items are ready. This avoids rebuilding an intermediate, incomplete page.
            viewState.pendingConversationLoadMoreHeaderLayoutUpdate = true
        }
    }
    
    // Called after the view model recovers from a severe error
    // to prod the view to reset its scroll state, etc.
    public func conversationViewModelDidReset() {
        AssertIsOnMainThread()
        
        // Scroll to bottom to get view back to a known good state.
        scrollToBottom(animated: false)
    }
    
    public func conversationStyleForViewModel() -> ConversationStyle {
        conversationStyle
    }
    
    private func updateWithDiff(
        _ updateContext: ConversationUpdate,
        invalidateLayout: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        Logger.info("[Conversation] begin items=\(viewItems.count) renderItems=\(renderItems.count) threadId:\(thread.uniqueId)")
        var scrollToBottom = false
        let isScrolledToBottom = self.isScrolledToBottom
        scrollContinuity = isScrolledToBottom ? .bottom : .top
        
        let updateItems = updateContext.updateItems ?? []
        var needReloadUniqueIds: [String] = []
        updateItems.forEach {
            switch $0.updateItemType {
            case .insert:
                self.scrollContinuity = .top
                if let message = $0.viewItem?.interaction as? TSMessage {
                    let isTailInsert = ($0.newIndex == self.viewItems.count - 1)

                    // Signal parity (see updateWithDiff in Signal-iOS): a message
                    // sent from this device always follows to the bottom; any other
                    // freshly inserted tail message follows only when the user was
                    // already at the bottom before this update landed.
                    if isTailInsert,
                       let outgoingMessage = message as? TSOutgoingMessage,
                       !outgoingMessage.isFromLinkedDevice {
                        scrollToBottom = true
                    } else if isTailInsert, isScrolledToBottom {
                        scrollToBottom = true
                    }

                    // Keep the user anchored where they are when a message is
                    // inserted while they are reading history; don't yank them down.
                    if !scrollToBottom, isTailInsert, !isScrolledToBottom {
                        self.scrollContinuity = .bottom
                    }
                }
            case .update:
                if let uniqueId = $0.viewItem?.interaction.uniqueId, !uniqueId.isEmpty {
                    needReloadUniqueIds.append(uniqueId)
                }
            default:
                break
            }
        }
        let reloadRange: ReloadRange = needReloadUniqueIds.isEmpty ? .none : .part(uniqueIds: needReloadUniqueIds)
        let hasFocusMessageFromSearch = conversationViewModel.focusMessageIdOnOpen != nil
        let shouldFollowToBottom = !updateContext.ignoreScrollToDefaultPosition
            && scrollToBottom
            && !hasFocusMessageFromSearch
            && !isUserScrolling
            && !isWaitingForDeceleration
        let viewportAnchorPolicy: ConversationViewportAnchorPolicy
        if shouldFollowToBottom {
            viewportAnchorPolicy = .disabled
        } else if let viewportAnchor = captureViewportAnchor() {
            viewportAnchorPolicy = .preserve(viewportAnchor)
        } else {
            viewportAnchorPolicy = .inherit
        }

        reloadData(
            forceRealodRange: reloadRange,
            animated: updateContext.shouldAnimateUpdates,
            viewportAnchorPolicy: viewportAnchorPolicy,
            invalidateLayout: invalidateLayout,
            followToBottom: shouldFollowToBottom
        ) { [weak self] isFinished in
            AssertIsOnMainThread()
            guard let self else { return }
            
            completion?(isFinished)
            
            guard isFinished else { return }
            
            // We can't use the transaction parameter; this completion
            // will be run async.
            self.updateLastVisibleSortIdWithSneakyAsyncTransaction()
            
            let lastVisibleIndexPath = self.lastVisibleIndexPath

            if !shouldFollowToBottom,
               !updateContext.ignoreScrollToDefaultPosition,
               lastVisibleIndexPath == nil,
               !hasFocusMessageFromSearch {
                self.scrollToBottom(animated: false)
            }
            
            // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
            self.updateLastKnownDistanceFromBottom()
            Logger.info("[Conversation] end items=\(self.viewItems.count) renderItems=\(self.renderItems.count) contentSize=\(self.collectionView.contentSize) threadId:\(thread.uniqueId)")
        }
        
        self.lastReloadDate = Date()
    }
}

// MARK: - Initial Load Coordination

extension ConversationViewController {
    private func storePendingInitialLoadCompletion(_ completion: @escaping (Bool) -> Void) {
        if let staleCompletion = consumePendingInitialLoadCompletion() {
            staleCompletion(false)
        }
        Logger.info("[Conversation] storePendingInitialLoadCompletion, threadId:\(thread.uniqueId)")
        viewState.pendingInitialLoadCompletion = completion
    }

    private func consumePendingInitialLoadCompletion() -> ((Bool) -> Void)? {
        let completion = viewState.pendingInitialLoadCompletion
        viewState.pendingInitialLoadCompletion = nil
        return completion
    }

    @discardableResult
    func processPendingInitialMessagesIfNeeded() -> Bool {
        guard isViewVisible,
              viewState.initialLoadPhase == .ready,
              let completion = consumePendingInitialLoadCompletion() else {
            return false
        }
        Logger.info("[Conversation] resume pending initial messages refresh, threadId:\(thread.uniqueId)")
        performInitialMessagesRefresh(completion: completion)
        return true
    }

    func cancelPendingInitialMessagesIfNeeded() {
        guard let completion = consumePendingInitialLoadCompletion() else { return }
        Logger.info("[Conversation] cancel pending initial messages refresh, threadId:\(thread.uniqueId)")
        completion(false)
    }

    private func performInitialMessagesRefresh(completion: @escaping ((Bool) -> Void)) {
        guard viewState.initialLoadPhase == .ready else {
            completion(false)
            return
        }
        viewState.initialLoadPhase = .applying
        Logger.info("[Conversation] refresh ui for initial messages, threadId:\(thread.uniqueId)")
        // The initial snapshot contains the latest view-model state and supersedes
        // anything accumulated before the first appearance.
        viewState.pendingConversationCollectionUpdate = .none
        viewState.pendingConversationShouldScrollToBottom = false
        viewState.pendingConversationLoadMoreHeaderLayoutUpdate = false
        updateShowLoadMoreHeaders()
        databaseStorage.uiRead { transaction in
            self.resetContentAndLayout(transaction: transaction) { [weak self] isFinished in
                guard let self else { return }
                if isFinished {
                    self.updateLastVisibleSortId()
                }

                // Establish the final initial position before acknowledging the
                // first render. This mirrors Signal's reload -> position -> reveal
                // ordering and avoids a frame at the collection view's old offset.
                self.updateContentInsets(animated: false, forceScrollToDefaultPosition: true)
                self.viewState.initialLoadPhase = .applied
                completion(isFinished)

                // The view model clears its initial-loading state in the completion
                // above. Re-evaluate the true beginning-of-history notice without
                // forcing a second initial position; the header preserves the
                // viewport established before completion.
                self.updateWarningHeaderLayout()

                // A database notification may have landed while the first
                // snapshot was being built. Apply only that queued delta now,
                // preserving the initial viewport established above.
                let forceLoadMoreHeaderLayoutUpdate =
                    self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate
                self.viewState.pendingConversationLoadMoreHeaderLayoutUpdate = false
                let didApplyPendingUpdate = self.applyPendingCollectionUpdateIfNeeded(
                    forceLoadMoreHeaderLayoutUpdate: forceLoadMoreHeaderLayoutUpdate,
                    allowViewportAnchorBeforeFirstAppearance: true
                )
                // Keep focus ownership until a queued snapshot has committed. Its completion
                // performs this handoff; without a queued update, finish immediately.
                if !didApplyPendingUpdate {
                    self.finishFocusedMessageKeyboardPresentationIfNeeded()
                }
                // Don't clear focusMessageIdOnOpen here - it needs to persist across viewState recreations
                // until the user manually scrolls. This prevents the focus from being lost when
                // reloadViewItems() creates a new ConversationViewState.
                // self.conversationViewModel.focusMessageIdOnOpen = nil  // ← Commented out
                
                if self.viewHasEverAppeared {
                    self.markVisibleMessagesAsRead()
                }
            }
        }
    }
}

// MARK: - Refresh UI Timer

extension ConversationViewController {
    var reloadTimer: Timer? {
        get { viewState.reloadTimer }
        set { viewState.reloadTimer = newValue }
    }
    
    var shouldObserveDBModifications: Bool {
        get { viewState.shouldObserveDBModifications }
        set {
            guard newValue != viewState.shouldObserveDBModifications else {
                return
            }
            viewState.shouldObserveDBModifications = newValue
            if newValue {
                startRefreshUITimerIfNecessary()
            } else {
                stopRefreshUITimer()
            }
        }
    }
    
    @objc func updateShouldObserveDBModifications() {
        let isAppForegroundAndActive = CurrentAppContext().isAppForegroundAndActive()
        Logger.info("[Conversation] ObserveDBModifications isViewVisible is \(isViewVisible) isAppForegroundAndActive is \(isAppForegroundAndActive)")
        shouldObserveDBModifications = isViewVisible && isAppForegroundAndActive
    }
    
    private func startRefreshUITimerIfNecessary() {
        if CurrentAppContext().isMainApp {
            stopRefreshUITimer()
            reloadTimer = Timer.weakScheduledTimer(
                withTimeInterval: 1.0,
                target: self,
                selector: #selector(reloadTimerDidFire),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    @objc private func reloadTimerDidFire() {
        AssertIsOnMainThread()
        
        if isUserScrolling || 
            !isViewCompletelyAppeared ||
            !isViewVisible ||
            !CurrentAppContext().isAppForegroundAndActive() ||
            !viewHasEverAppeared || conversationViewModel.isLoadingInitialMessages() {
            return
        }
        
        let now = Date()
        if let lastReloadDate = self.lastReloadDate {
            let timeSinceLastReload = now.timeIntervalSince(lastReloadDate)
            let kReloadFrequency: TimeInterval = 60
            if timeSinceLastReload < kReloadFrequency {
                return
            }
        }
        
        Logger.verbose("reloading conversation view contents.")
        databaseStorage.uiRead { transaction in
            self.resetContentAndLayout(transaction: transaction, forceRealodRange: .none)
        }
    }
    
    @objc func stopRefreshUITimer() {
        reloadTimer?.invalidate()
        reloadTimer = nil
    }
}
