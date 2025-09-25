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
    
    func conversationViewModelDidUpdate(
        _ conversationUpdate: ConversationUpdate,
        transaction: SDSAnyReadTransaction?,
        completion: ((Bool) -> Void)? = nil
    ) {
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
        if !isViewLoaded || !shouldObserveDBModifications {
            // It's safe to ignore updates before the view loads;
            // viewWillAppear will call resetContentAndLayout.
            Logger.debug("------>>>>>> abord.")
            completion?(false)
            
            
            // 3.1.8 当应用进入后台，websocket 还未断开时，仍然能接收到 database change，
            // 但此时 shouldObserveDBModifications = false，无法触发刷新，而 app 返回前台后，若没有新的数据，也无法刷新
            // 为了解决上述问题，当应用进入后台且接收到 database change 时，记录下标志位 isNeedReloadAfterAppEnterForeground，
            // 在应用返回前台时进行刷新
            if CurrentAppContext().isInBackground() {
                Logger.info("=== Conversation ignore refresh when app in background ===")
                isNeedReloadAfterAppEnterForeground = true
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
            resetContentAndLayout(transaction: transaction) { [weak self] isFinished in
                guard let self else { return }
                if isFinished {
                    self.updateLastVisibleSortId()
                }
                completion?(isFinished)
            }
        case .diff:
            updateWithDiff(conversationUpdate, completion: completion)
        default:
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
        }
        
        self.lastReloadDate = Date()
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
            !viewHasEverAppeared {
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
