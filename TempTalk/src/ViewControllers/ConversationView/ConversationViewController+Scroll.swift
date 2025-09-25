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
        let maxContentOffsetY = contentHeight + adjustedContentInset.bottom - collectionView.bounds.size.height
        return maxContentOffsetY
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
    
    func scrollToDefaultPosition(animated: Bool) {
        guard !isUserScrolling else {
            return
        }
        
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
        guard let indexPath = indexPathOfFocusMessage ?? indexPathOfUnreadMessagesIndicator else {
            scrollToBottom(animated: animated)
            return
        }
        if indexPath.section == 0 && indexPath.row == 0 {
            collectionView.setContentOffset(.zero, animated: animated)
        } else if indexPath.row < dataSource.snapshot().numberOfItems {
            collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        }
    }
    
    func scrollToBottom(animated: Bool) {
        AssertIsOnMainThread()
        
        guard !isUserScrolling else {
            return
        }
        
        if conversationViewModel.canLoadNewerItems() {
            databaseStorage.uiRead { [weak self] transaction in
                guard let self else { return }
                self.conversationViewModel.ensureLoadWindowContainsNewestItems(with: transaction)
            }
        }
        
        // Ensure the view is fully layed out before we try to scroll to the bottom, since
        // we use the collectionView bounds to determine where the "bottom" is.
        self.view.layoutIfNeeded()
        
        let bottomInset = -collectionView.adjustedContentInset.bottom
        let firstContentPageTop = -collectionView.adjustedContentInset.top
        let collectionViewUnobscuredHeight = collectionView.bounds.size.height + bottomInset
        let lastContentPageTop = safeContentHeight - collectionViewUnobscuredHeight
        
        let dstY = max(firstContentPageTop, lastContentPageTop)
        
        collectionView.setContentOffset(.init(x: 0, y: dstY), animated: animated)
        didScrollToBottom()
    }
    
    private func didScrollToBottom() {
        self.scrollDownButton.isHidden = true
        
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
            reloadData { [weak self] isFinished in
                guard let self, isFinished else { return }
                self.scrollDown()
            }
        } else {
            scrollDown()
        }
    }
    
    private func scrollDown() {
        if let unreadMessageIndexPath = self.indexPathOfUnreadMessagesIndicator {
            let unreadRow = unreadMessageIndexPath.row
            let visibleIndexPaths = collectionView.indexPathsForVisibleItems
            let isScrolledAboveUnreadIndicator = visibleIndexPaths.first(where: { $0.row > unreadRow }) == nil
            
            if isScrolledAboveUnreadIndicator, unreadMessageIndexPath.row < dataSource.snapshot().numberOfItems {
                // Only scroll as far as the unread indicator if we're scrolled above the unread indicator.
                collectionView.scrollToItem(
                    at: unreadMessageIndexPath,
                    at: .top,
                    animated: true
                )
                return
            }
        }
        
        scrollToBottom(animated: true)
    }
    
    @objc func ensureScrollDownButton() {
        AssertIsOnMainThread()
        
        if peek {
            scrollDownButton.isHidden = true
            return
        }
        
        let contentInset = collectionView.contentInset
        let contentOffsetY = collectionView.contentOffset.y
        let collectionViewHeight = collectionView.frame.size.height
        
        let spaceToBottom = safeContentHeight + contentInset.bottom - (contentOffsetY + collectionViewHeight)
        let pageHeight = collectionViewHeight - (contentInset.top + contentInset.bottom)
        
        // Show "scroll down" button if user is scrolled up at least one page.
        let isScrolledUp = spaceToBottom > pageHeight
        
        var shouldShowScrollDownButton = false
        if let lastViewItem = viewItems.last {
            if lastViewItem.interaction.timestampForSorting() > self.lastVisibleSortId {
                shouldShowScrollDownButton = true
            } else if isScrolledUp {
                shouldShowScrollDownButton = true
            }
        }
        self.scrollDownButton.isHidden = !shouldShowScrollDownButton
    }
}

// MARK: - DateSeparatorView

extension ConversationViewController {
    private var dateSeparatorView: ConversationDateSeparatorView? {
        get { viewState.dateSeparatorView }
        set { viewState.dateSeparatorView = newValue }
    }

    private func startHideDateTimer() {
        hideDateTimer?.invalidate()
        hideDateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideDateSeparator()
        }
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
        dateSeparatorView.snp.updateConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
                .offset(collectionView.contentInset.top + joinbarHeight)
        }
    }

    private func refreshDateSeparator() {
        hideDateTimer?.invalidate()

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
    
    var hideDateTimer: Timer? {
        get { viewState.hideDateTimer }
        set { viewState.hideDateTimer = newValue }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if viewHasEverAppeared {
            updateLastKnownDistanceFromBottom()
        }
        
        scheduleScrollUpdateTimer()
        
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
        userHasScrolled = true
        isUserScrolling = true
        
        actionMenuController?.hideMenu(animation: false)
        
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
        isUserScrolling = false
        
        if decelerate {
            isWaitingForDeceleration = decelerate
        } else {
            scheduleScrollUpdateTimer()
            
            actionMenuController?.showMenu(animation: true)
            
            startHideDateTimer()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard isWaitingForDeceleration else {
            return
        }
        isWaitingForDeceleration = false
        
        scheduleScrollUpdateTimer()
        
        actionMenuController?.showMenu(animation: true)
        
        startHideDateTimer()
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
            
            Logger.debug("[hot data] ------ ⬆️⬆️⬆️")
            
            if isShowLoadOlderHeader {
                BenchManager.bench(title: "loading older interactions") {
                    self.databaseStorage.uiRead { transaction in
                        self.conversationViewModel.appendOlderItems(with: transaction)
                    }
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
            
            Logger.debug("[hot data] ------ ⬇️⬇️⬇️")
            
            if isShowLoadNewerHeader {
                BenchManager.bench(title: "loading newer interactions") {
                    self.databaseStorage.uiRead { transaction in
                        self.conversationViewModel.appendNewerItems(with: transaction)
                    }
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
            resetContentAndLayout(transaction: transaction)
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
        
        Logger.debug("------ showLoadOlderHeader:\(isShowLoadOlderHeader) showLoadNewerHeader: \(isShowLoadNewerHeader)")
        Logger.debug("------ [hot data] showFetchOlderHeader:\(isShowFetchOlderHeader) showFetchNewerHeader:\(isShowFetchNewerHeader)")
        
        return valueChanged
    }
    
    @objc func resetContentAndLayoutWithSneakyTransaction() {
        databaseStorage.uiRead { transaction in
            self.resetContentAndLayout(transaction: transaction)
        }
    }
    
    func resetContentAndLayout(
        transaction: SDSAnyReadTransaction,
        forceRealodRange: ReloadRange = .all,
        completion: ((Bool) -> Void)? = nil
    ) {
        scrollContinuity = .bottom
        
        // Avoid layout corrupt issues and out-of-date message subtitles.
        lastReloadDate = Date()
        conversationViewModel.viewDidResetContentAndLayout(with: transaction)
        
        reloadData(forceRealodRange: forceRealodRange) { [weak self] isFinished in
            guard let self else { return }
            if self.viewHasEverAppeared, isFinished {
                // Try to update the lastKnownDistanceFromBottom; the content size may have changed.
                self.updateLastKnownDistanceFromBottom()
            }
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
                Logger.debug("jump to message.body = \(focusMessage.body ?? "")")
                
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
        scrollToBottom(animated: false)
    }
}
