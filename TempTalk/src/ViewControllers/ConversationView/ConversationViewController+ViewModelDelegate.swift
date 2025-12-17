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
        if isNeedReloadAfterAppEnterForeground {
            isNeedReloadAfterAppEnterForeground = false

            let reloadUpdate = ConversationUpdate.reload()
            databaseStorage.uiRead { transation in
                self._conversationViewModelDidUpdate(
                    reloadUpdate,
                    transaction: transation,
                    completion: nil
                )
            }
        }
    }
    
    func conversationViewModelDidLoadInitialMessages(completion: @escaping ((Bool) -> Void)) {
        guard isViewVisible else {
            Logger.info("[Conversation] queue refresh ui for initial messages until view visible, threadId:\(thread.uniqueId)")
            storePendingInitialLoadCompletion(completion)
            return
        }
        Logger.info("[Conversation] handle initial messages, threadId:\(thread.uniqueId)")
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
        completion: ((Bool) -> Void)?
    ) {
        AssertIsOnMainThread()
        
        // FIX: https://developer.apple.com/forums/thread/728797
        if !isViewLoaded {
            Logger.info("[Conversation] ignored (isViewLoaded=\(isViewLoaded), shouldObserve=\(shouldObserveDBModifications)) updateType=\(conversationUpdate.conversationUpdateType) threadId:\(thread.uniqueId)")
            // It's safe to ignore updates before the view loads;
            // viewWillAppear will call resetContentAndLayout.
            completion?(false)
            return
            
        } else if !shouldObserveDBModifications && CurrentAppContext().isInBackground() {
            Logger.info("[Conversation] ignore refresh when isViewDidLoaded:\(isViewLoaded), shouldObserveDBModifications:\(shouldObserveDBModifications) threadId:\(thread.uniqueId)")
            isNeedReloadAfterAppEnterForeground = true
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
            Logger.info("[Conversation] will resetContentAndLayout (reload) threadId:\(thread.uniqueId)")
            resetContentAndLayout(transaction: transaction) { [weak self] isFinished in
                guard let self else { return }
                Logger.info("[Conversation] resetContentAndLayout finished=\(isFinished) contentSize=\(self.collectionView.contentSize) threadId:\(thread.uniqueId)")
                if isFinished {
                    self.updateLastVisibleSortId()
                }
                completion?(isFinished)
            }
        case .diff:
            Logger.info("[Conversation] diff update, items before=\(viewItems.count) threadId:\(thread.uniqueId)")
            updateWithDiff(conversationUpdate, completion: completion)
        default:
            Logger.info("[Conversation] default update threadId:\(thread.uniqueId)")
            completion?(true)
            break
        }
    }
    
    public func conversationViewModelWillLoadMoreItems() {
        AssertIsOnMainThread()
        
        // To maintain scroll position after changing the items loaded in the conversation view:
        //
        // 1. in conversationViewModelWillLoadMoreItems
        //   - Get position of some interactions cell before transition.
        //   - Get content offset before transition
        //
        // 2. Load More
        //
        // 3. in conversationViewModelDidLoadMoreItems
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
        
        var cell: UICollectionViewCell?
        if #available(iOS 18, *) {
            cell = collectionView.cellForItem(at: indexPath)
        } else {
            cell = viewItem.dequeueCell(for: collectionView, indexPath: indexPath)
        }
        guard let cell else {
            owsFailDebug("cell was unexpectedly nil")
            return
        }
        
        let frame = cell.frame
        let contentOffset = collectionView.contentOffset
        scrollStateBeforeLoadingMore = ConversationScrollState(
            referenceViewItem: viewItem,
            referenceFrame: frame,
            contentOffset: contentOffset
        )
    }
    
    public func conversationViewModelDidLoadMoreItems() {
        AssertIsOnMainThread()
        
        self.layout.prepare()
        
        guard let scrollState = self.scrollStateBeforeLoadingMore else {
            owsFailDebug("scrollState was unexpectedly nil")
            return
        }
        
        guard let newIndexPath = conversationViewModel.indexPath(for: scrollState.referenceViewItem) else {
            owsFailDebug("newIndexPath was unexpectedly nil")
            return
        }
        
        var cell: UICollectionViewCell?
        if #available(iOS 18, *) {
            cell = collectionView.cellForItem(at: newIndexPath)
        } else {
            cell = scrollState.referenceViewItem.dequeueCell(for: collectionView, indexPath: newIndexPath)
        }
        guard let cell else {
            owsFailDebug("cell was unexpectedly nil")
            return
        }
        
        let newFrame = cell.frame
        // distance from top of cell to top of content pane.
        let previousDistance = scrollState.referenceFrame.origin.y - scrollState.contentOffset.y
        let newDistance = newFrame.origin.y - previousDistance
        
        let newContentOffset = CGPointMake(0, newDistance)
        collectionView.contentOffset = newContentOffset
    }
    
    public func conversationViewModelDidUpdateLoadMoreStatus() {
        AssertIsOnMainThread()
        
        let _ = updateShowLoadMoreHeaders()
    }
    
    public func conversationViewModelUpdatePin() {
        resetPinnedMappings(animated: true)
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
    
    private func updateWithDiff(_ updateContext: ConversationUpdate, completion: ((Bool) -> Void)? = nil) {
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
                    if let outgoingMessage = message as? TSOutgoingMessage, !outgoingMessage.isFromLinkedDevice {
                        scrollToBottom = true
                    }
                    if !scrollToBottom &&
                        $0.newIndex == self.viewItems.count - 1 &&
                        (message.envelopSource == DTEnvelopeSourceRestHotdata || !isScrolledToBottom) {
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
        
        reloadData(forceRealodRange: reloadRange, animated: updateContext.shouldAnimateUpdates) { [weak self] isFinished in
            AssertIsOnMainThread()
            guard let self else { return }
            
            completion?(isFinished)
            
            guard isFinished else { return }
            
            // We can't use the transaction parameter; this completion
            // will be run async.
            self.updateLastVisibleSortIdWithSneakyAsyncTransaction()
            
            let lastVisibleIndexPath = self.lastVisibleIndexPath
            if !updateContext.ignoreScrollToDefaultPosition, (scrollToBottom || lastVisibleIndexPath == nil) {
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
    private func performInitialMessagesRefresh(completion: @escaping ((Bool) -> Void)) {
        Logger.info("[Conversation] refresh ui for initial messages, threadId:\(thread.uniqueId)")
        updateShowLoadMoreHeaders()
        databaseStorage.uiRead { transaction in
            self.resetContentAndLayout(transaction: transaction) { [weak self] isFinished in
                guard let self else { return }
                if isFinished {
                    self.updateLastVisibleSortId()
                }
                
                completion(isFinished)
                
                self.updateContentInsets(animated: false, forceScrollToDefaultPosition: true)
                self.conversationViewModel.focusMessageIdOnOpen = nil
                
                if self.viewHasEverAppeared {
                    self.markVisibleMessagesAsRead()
                }
            }
        }
    }
    
    private func storePendingInitialLoadCompletion(_ completion: @escaping (Bool) -> Void) {
        if let staleCompletion = consumePendingInitialLoadCompletion() {
            staleCompletion(false)
        }
        Logger.info("[Conversation] storePendingInitialLoadCompletion messages, threadId:\(thread.uniqueId)")
        viewState.pendingInitialLoadCompletion = completion
        viewState.hasPendingInitialLoad = true
    }
    
    private func consumePendingInitialLoadCompletion() -> ((Bool) -> Void)? {
        let completion = viewState.pendingInitialLoadCompletion
        viewState.pendingInitialLoadCompletion = nil
        viewState.hasPendingInitialLoad = false
        Logger.info("[Conversation] consumePendingInitialLoadCompletion messages, threadId:\(thread.uniqueId)")
        return completion
    }
    
    func processPendingInitialMessagesIfNeeded() {
        guard isViewVisible,
              viewState.hasPendingInitialLoad,
              let completion = consumePendingInitialLoadCompletion() else {
            Logger.error("[Conversation] resume pending initial messages refresh,isViewVisible=\(isViewVisible) hasPendingInitialLoad = \(viewState.hasPendingInitialLoad) threadId:\(thread.uniqueId)")
            return
        }
        Logger.info("[Conversation] resume pending initial messages refresh, threadId:\(thread.uniqueId)")
        performInitialMessagesRefresh(completion: completion)
    }
    
    func cancelPendingInitialMessagesIfNeeded() {
        guard let completion = consumePendingInitialLoadCompletion() else { return }
        Logger.info("[Conversation] cancel pending initial messages refresh, threadId:\(thread.uniqueId)")
        completion(false)
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
