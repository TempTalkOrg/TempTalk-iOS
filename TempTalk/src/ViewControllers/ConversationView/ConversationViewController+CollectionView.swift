//
//  ConversationViewController+CollectionView.swift
//  Signal
//
//  Created by Jaymin on 2024/4/7.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

// MARK: - Init

extension ConversationViewController {
    
    func setupCollectionView() {
        layout.delegate = self
        conversationStyle.viewWidth = floor(view.width)
        
        collectionView.layoutDelegate = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.keyboardDismissMode = .interactive
        // To minimize time to initial apearance, we initially disable prefetching, but then
        // re-enable it once the view has appeared.
        collectionView.allowsSelection = false
        collectionView.isPrefetchingEnabled = false
        collectionView.alwaysBounceVertical = true
        
        view.addSubview(collectionView)
        collectionView.autoPinEdge(toSuperviewSafeArea: .top)
        collectionView.autoPinEdge(toSuperviewEdge: .bottom)
        collectionView.autoPinEdge(toSuperviewSafeArea: .leading)
        collectionView.autoPinEdge(toSuperviewSafeArea: .trailing)
        
        collectionView.applyInsetsFix()
        collectionView.accessibilityIdentifier = "collectionView"
        
        collectionView.addGestureRecognizer(tapGestureRecognizer)
        
        collectionView.register(
            ConversationIncomingMessageCell.self,
            forCellWithReuseIdentifier: ConversationIncomingMessageCell.reuseIdentifier
        )
        collectionView.register(
            ConversationOutgoingMessageCell.self,
            forCellWithReuseIdentifier: ConversationOutgoingMessageCell.reuseIdentifier
        )
        collectionView.register(
            ConversationSystemMessageCell.self,
            forCellWithReuseIdentifier: ConversationSystemMessageCell.reuserIdentifier
        )
        collectionView.register(
            ConversationUnknownCell.self,
            forCellWithReuseIdentifier: ConversationUnknownCell.reuserIdentifier
        )
        collectionView.register(
            ConversationUnreadIndicatorCell.self,
            forCellWithReuseIdentifier: ConversationUnreadIndicatorCell.reuserIdentifier
        )
        collectionView.register(
            LoadMoreMessagesView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: LoadMoreMessagesView.reuseIdentifier
        )
        collectionView.register(
            LoadMoreMessagesView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LoadMoreMessagesView.reuseIdentifier
        )
        
        setupBackgroundView()
    }
    
    func setupBackgroundView() {
        // 清除已有的背景视图
        collectionView.backgroundView = nil
        if let backgroundImage = UIImage(named: "conversation_background") {
            let backgroundImageView = UIImageView(image: backgroundImage)
            backgroundImageView.contentMode = .scaleAspectFill
            collectionView.backgroundView = backgroundImageView
        } else {
            Logger.warn("Warning: Background image 'view_background' not found!")
        }
    }
}

// MARK: - Diffable Data Source

extension ConversationViewController {
    enum ReloadRange: Equatable {
        case all
        case part(uniqueIds: [String])
        case none
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.all, .all):
                return true
            case (.none, .none):
                return true
            case (.part(let lhsIds), .part(let rhsIds)):
                return lhsIds == rhsIds
            default:
                return false
            }
        }
    }
    
    var dataSource: UICollectionViewDiffableDataSource<ConversationSection, String> {
        if let dataSource = viewState.dataSource {
            return dataSource
        }
        let newDataSource = createDiffableDataSource()
        viewState.dataSource = newDataSource
        return newDataSource
    }

    /// 创建差量化数据源
    ///
    /// - Note:
    ///    - UICollectionViewDiffableDataSource 关联两个范型，对应 section 和 item 的唯一标识符（IdentifierType，必须实现 Hashable 协议）
    ///    - 其中 SectionIdentifierType 使用自定义枚举 ConversationSection，ItemIdentifierType 使用 ConversationViewItem.interaction.uniqueId
    private func createDiffableDataSource() -> UICollectionViewDiffableDataSource<ConversationSection, String> {
        
        let dataSource = UICollectionViewDiffableDataSource<ConversationSection, String>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, uniqueId in
            
            // Note: 虽然方法定义的返回值是 UICollectionViewCell?，但是若返回 nil 还是会 crash
            guard let self, let renderItem = self.renderItem(for: uniqueId) else {
                Logger.error("ConversationViewController can not find the viewItem for uniqueId:\(uniqueId)")
                return collectionView.dequeueReusableCell(
                    withReuseIdentifier: ConversationUnknownCell.reuserIdentifier,
                    for: indexPath
                )
            }
            
            let cell = renderItem.dequeueCell(for: collectionView, indexPath: indexPath)
            switch (cell, renderItem) {
            case (let messageCell as ConversationMessageCell, let messageRenderItem as ConversationMessageRenderItem):
                messageCell.delegate = self
                messageCell.messageBubbleView.delegate = self
                messageCell.shouldHandle = shouldHandleAndMarkMessage(id: messageRenderItem.uniqueId)
                messageCell.configure(renderItem: messageRenderItem)
                messageCell.isMultiSelectMode = isMultiSelectMode
                messageCell.isCellSelected = isSelectedViewItemInMultiSelectMode(messageRenderItem.viewItem)
                messageCell.refreshTheme()
                
                Logger.info("audio message byesize \(String(describing: messageRenderItem.messageBubbleRenderItem?.bodyMediaRenderItem?.viewItem.attachmentStream()?.byteCount))")
                Logger.info("audio message isUploaded \(String(describing: messageRenderItem.messageBubbleRenderItem?.bodyMediaRenderItem?.viewItem.attachmentStream()?.isUploaded))")
                
            case (let systemCell as ConversationSystemMessageCell, let systemRenderItem as ConversationSystemRenderItem):
                systemCell.delegate = self
                systemCell.configure(renderItem: systemRenderItem)
                systemCell.refreshTheme()
                
            case (let unreadCell as ConversationUnreadIndicatorCell, let unreadRenderItem as ConversationUnreadRenderItem):
                unreadCell.configure(renderItem: unreadRenderItem)
                unreadCell.refreshTheme()
                
            default:
                break
            }
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            switch elementKind {
            case UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter:
                let loadMoreView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: elementKind,
                    withReuseIdentifier: LoadMoreMessagesView.reuseIdentifier,
                    for: indexPath
                )
                if let moreMessageView = loadMoreView as? LoadMoreMessagesView {
                    moreMessageView.configureForDisplay()
                }
                return loadMoreView
            default:
                return nil
            }
        }
        
        return dataSource
    }
    
    /// 刷新数据（基于 snapshot 实现，代替 performBatchUpdate）
    ///
    /// - Parameters:
    ///    - forceRealodRange: 需要强制刷新数据范围，这里特指前后两次快照中都存在的 item 是否需要强制刷新
    ///    - animated: 是否启用动画
    ///    - completion: 刷新完成回调
    ///
    /// - Note:
    ///    - 基于 NSDiffableDataSourceSnapshot 实现的刷新，无需关心是需要新增还是删除 item，系统内部会根据前后快照推断出来，
    ///    - 但是 UICollectionViewDiffableDataSource 无法知道前后快照都存在的 item 是否需要刷新，需要我们通过 NSDiffableDataSourceSnapshot.reloadItems api 告知系统，
    ///    - 默认情况下，我们选择刷新全部，并不用为性能担忧，实际在执行时只会刷新可见区域的 cell，
    ///    - 若明确知道需要刷新的 item，或者明确知道不需要刷新已存在的 item （比如只有新增删除），可以通过 forceRealodRange 参数指定范围
    func reloadData(
        forceRealodRange: ReloadRange = .all,
        animated: Bool = false,
        completion: ((Bool) -> Void)? = nil
    ) {
        // 默认不进行离线操作
        DatabaseOfflineManager.shared.canOfflineUpdateDatabase = false
        // 每一次都重新获取当前最新数据源的所有 uniqueId，确保外部数据源始终和快照中的数据源一致
        let currentUniqueIds = viewItems.compactMap { $0.interaction.uniqueId }
        var newSnapshot = NSDiffableDataSourceSnapshot<ConversationSection, String>()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(currentUniqueIds, toSection: .main)
        
        // 获取新旧快照的交集 intersectionUniqueIds，由于 UnreadIndicatorInteractionId 对应的 cell 实际并不需要刷新，所以过滤掉
        let oldSnapshot = dataSource.snapshot()
        let oldUniqueIds = oldSnapshot.itemIdentifiers
        let intersectionUniqueIds = Set(currentUniqueIds).intersection(Set(oldUniqueIds)).filter { $0 != "UnreadIndicatorInteractionId" }
        
        // 根据 forceRealodRange 和 intersectionUniqueIds 找到需要刷新指定的 item
        var forceReloadUniqueIds: [String] = []
        if !intersectionUniqueIds.isEmpty, forceRealodRange != .none {
            switch forceRealodRange {
            case .all:
                forceReloadUniqueIds = Array(intersectionUniqueIds)
            case let .part(uniqueIds):
                forceReloadUniqueIds = Array(intersectionUniqueIds.intersection(Set(uniqueIds)))
            default:
                break
            }
            if !forceReloadUniqueIds.isEmpty {
                newSnapshot.reloadItems(forceReloadUniqueIds)
            }
        }
        
        // 异步计算 cell 高度
        firstly {
            self.renderItemBuilder.build(
                viewItems: viewItems,
                forceRebuildIds: forceReloadUniqueIds,
                style: conversationStyle
            )
        }.done { [weak self] (renderItems, renderItemsMap) in
            guard let self else { return }
            DispatchMainThreadSafe {
                self.renderItems = renderItems
                self.renderItemsMap = renderItemsMap
                self.dataSource.apply(newSnapshot, animatingDifferences: animated) {
                    completion?(true)
                }
            }
        }.catch { error in
            completion?(false)
        }
    }
    
    /// 刷新指定 cell
    /// 如果确定只刷新部分 cell，而无新增和删除，调用此方法性能更好
    func reloadItems(at indexPaths: [IndexPath]) {
        let items: [String] = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
        if !items.isEmpty {
            var snapshot = dataSource.snapshot()
            snapshot.reloadItems(items)
            dataSource.apply(snapshot)
        }
    }
    
    func shouldHandleAndMarkMessage(id: String) -> Bool {
        if handledMessageIds.isEmpty || !handledMessageIds.contains(id) {
            handledMessageIds.insert(id)
            return true
        }
        return false
    }
}

// MARK: - ConversationViewLayoutDelegate

extension ConversationViewController: ConversationViewLayoutDelegate {
    var layoutItems: [any ConversationViewLayoutItem] {
        renderItems
    }
    
    var layoutHeaderHeight: CGFloat {
        if isShowLoadOlderHeader || isShowFetchOlderHeader {
            return LoadMoreMessagesView.fixedHeight
        }
        return .zero
    }
    
    var layoutFooterHeight: CGFloat {
        if isShowLoadNewerHeader || isShowFetchNewerHeader {
            return LoadMoreMessagesView.fixedHeight
        }
        return .zero
    }
}

// MARK: - CollectionViewDelegate

extension ConversationViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let conversationCell = cell as? ConversationCell {
            conversationCell.isCellVisible = true
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let conversationCell = cell as? ConversationCell {
            conversationCell.isCellVisible = false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectMessageInMultiSelectMode(indexPath: indexPath)
    }
    
    // We use this hook to ensure scroll state continuity.  As the collection
    // view's content size changes, we want to keep the same cells in view.
    func collectionView(
        _ collectionView: UICollectionView,
        targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        
        var newProposedContentOffset = proposedContentOffset
        
        if let lastKnownDistanceFromBottom,
           (scrollContinuity == .top) {
            
            Logger.debug("------1 proposedContentOffset:\(proposedContentOffset) lastKnownDistance:\(lastKnownDistanceFromBottom)")
            
            newProposedContentOffset = contentOffsetForLastKnownDistanceFromBottom(lastKnownDistanceFromBottom)
            
            Logger.debug("------1 proposedContentOffset:\(newProposedContentOffset)")
        }
        
        return newProposedContentOffset
    }
    
    private func contentOffsetForLastKnownDistanceFromBottom(_ distance: CGFloat) -> CGPoint {
        // Adjust the content offset to reflect the "last known" distance
        // from the bottom of the content.
        let contentOffsetYBottom = maxContentOffsetY
        var contentOffsetY = contentOffsetYBottom - max(0, distance)
        let minContentOffsetY = -collectionView.safeAreaInsets.top
        
        contentOffsetY = max(minContentOffsetY, contentOffsetY)
        return CGPoint(x: 0, y: contentOffsetY)
    }
    
    func updateCellsVisible() {
        // panModal 展示 vc 时只有半屏，如果设置 isCellVisible = NO，会出现图片不展示的情况
        let isShowPanModalVC = {
            if let _ = presentedViewController as? DTPanModalNavController {
                return true
            }
            return false
        }()
        let isAppInBackground = CurrentAppContext().isInBackground()
        let isCellVisible = (isViewVisible || isShowPanModalVC) && !isAppInBackground
        collectionView.visibleCells.forEach {
            if let conversationCell = $0 as? ConversationCell {
                conversationCell.isCellVisible = isCellVisible
            }
        }
    }
}

// MARK: - ConversationCollectionViewDelegate

extension ConversationViewController: ConversationCollectionViewDelegate {
    func collectionViewWillChangeSize(from oldSize: CGSize, to newSize: CGSize) {
        AssertIsOnMainThread()
    }
    
    func collectionViewDidChangeSize(from oldSize: CGSize, to newSize: CGSize) {
        AssertIsOnMainThread()
        updateLastVisibleSortIdWithSneakyAsyncTransaction()
    }
    
    func collectionViewDidChangeContentInset(_ oldContentInset: UIEdgeInsets, to newContentInset: UIEdgeInsets) {
        refreshDateSeparatorViewPosition()
    }
}
