//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class ConversationMessageMapping: NSObject {
    
    // MARK: - Dependencies
    
    private var interactionReadCache: InteractionReadCache {
        SSKEnvironment.shared.modelReadCachesRef.interactionReadCache
    }

    // MARK: -
    
    private let interactionFinder: InteractionFinder
    private let thread: TSThread
    private weak var viewModel: ConversationViewModel?
    
    @objc public var isFetchingData: AtomicBool = AtomicBool(false, lock: .sharedGlobal)

    @objc
    public var loadedUniqueIds: [String] {
        loadedInteractions.map { $0.uniqueId }
    }
    
    @objc
    private(set) var loadedInteractions: [TSInteraction] {
        get {
            _loadedInteractions.get()
        }
        set {
            _loadedInteractions.set(newValue)
        }
    }
    
    private var _loadedInteractions: AtomicArray<TSInteraction> = AtomicArray(lock: .sharedGlobal)
    
    @objc
    public var canLoadOlder = AtomicBool(false, lock: .sharedGlobal)

    @objc
    public var canLoadNewer = AtomicBool(false, lock: .sharedGlobal)
    
    @objc
    public var canFetchOlder = AtomicBool(false, lock: .sharedGlobal)
    
    @objc
    public var canFetchNewer = AtomicBool(false, lock: .sharedGlobal)
    
    @objc
    public required init(viewModel: ConversationViewModel, thread: TSThread, threadUniqueId: String) {
        self.interactionFinder = InteractionFinder(threadUniqueId: threadUniqueId)
        self.thread = thread
        self.viewModel = viewModel
    }

    // The smaller this number is, the faster the conversation can display.
    //
    // However, too small and we'll immediately trigger a "load more" because
    // the user's viewports is too close to the conversation view's edge.
    //
    // Therefore we target a (slightly worse than) general case which will load fast for most
    // conversations, at the expense of a second fetch for conversations with pathologically
    // small messages (e.g. a bunch of 1-line texts in a row from the same sender and timestamp)
    internal var initialLoadCount: Int {
        let avgMessageHeight: CGFloat = 60
        let referenceSize = UIScreen.main.bounds
        let messageCountToFillScreen = (referenceSize.height / avgMessageHeight)

        let result = Int(messageCountToFillScreen * 2)
        Logger.verbose("initialLoadCount: \(result)")
        guard result >= 10 else {
            owsFailDebug("unexpectedly small initialLoadCount: \(result)")
            return 10
        }
        return result
    }

    // After this size, we'll start unloading interactions
    private let maxInteractionLimit: Int = 200

    // oldest saved message in a conversation has an index of 0, the most recent message has index conversationCount - 1.
    private var loadedIndexSet = AtomicIndexSet(lock: .sharedGlobal)

    enum LoadWindowDirection {
        case before(interactionUniqueId: String)
        case after(interactionUniqueId: String)
        case around(interactionUniqueId: String)
        case newest
    }

    @objc(loadMessagePageAroundInteractionId:transaction:error:)
    public func loadMessagePage(aroundInteractionId interactionUniqueId: String, transaction: SDSAnyReadTransaction) throws {
        try ensureLoaded(.around(interactionUniqueId: interactionUniqueId),
                         count: initialLoadCount,
                         transaction: transaction)
    }

    @objc
    public func loadNewerMessagePage(transaction: SDSAnyReadTransaction) throws {
        guard let newestLoadedId = loadedUniqueIds.last else {
            // empty convo
            return
        }

        try ensureLoaded(.after(interactionUniqueId: newestLoadedId),
                         count: initialLoadCount * 2,
                         transaction: transaction)
    }

    @objc
    public func loadOlderMessagePage(transaction: SDSAnyReadTransaction) throws {
        guard let oldestLoadedId = loadedUniqueIds.first else {
            // empty convo
            return
        }

        try ensureLoaded(.before(interactionUniqueId: oldestLoadedId),
                         count: initialLoadCount * 2,
                         transaction: transaction)
    }

    @objc
    public func loadNewestMessagePage(transaction: SDSAnyReadTransaction) throws {
        try ensureLoaded(.newest,
                         count: initialLoadCount,
                         transaction: transaction)
    }

    @objc
    public func loadInitialMessagePage(focusMessageId: String?, transaction: SDSAnyReadTransaction) throws {
        try updateOldestUnreadInteraction(transaction: transaction)
        Logger.info("[Conversation] begin focusId=\(focusMessageId ?? "nil") oldestUnread=\(self.oldestUnreadInteraction?.uniqueId ?? "nil") thread=\(thread.uniqueId)")

        if let focusMessageId = focusMessageId {
            try ensureLoaded(.around(interactionUniqueId: focusMessageId),
                             count: initialLoadCount * 2,
                             transaction: transaction)
        } else if let oldestUnreadInteraction = self.oldestUnreadInteraction {
            try ensureLoaded(.around(interactionUniqueId: oldestUnreadInteraction.uniqueId),
                             count: initialLoadCount * 2,
                             transaction: transaction)
        } else {
           try loadNewestMessagePage(transaction: transaction)
        }

        Logger.info("[Conversation] end loadedIndices=\(loadedIndexSet.count) canLoadOlder=\(canLoadOlder) canLoadNewer=\(canLoadNewer) loadedInteractions=\(loadedInteractions.count) thread=\(thread.uniqueId)")
    }

    // MARK: -
    @discardableResult
    private func ensureLoaded(_ direction: LoadWindowDirection, count: Int, transaction: SDSAnyReadTransaction) throws -> ConversationMessageMappingDiff {
        return try Bench(title: "ConversationMessageMapping.ensureLoaded") {
            return try _ensureLoaded(direction, count: count, transaction: transaction)
        }
    }
    
    @discardableResult
    private func _ensureLoaded(_ direction: LoadWindowDirection, count: Int, transaction: SDSAnyReadTransaction) throws -> ConversationMessageMappingDiff {
        let conversationSize = interactionFinder.count(transaction: transaction)
        
        Logger.info("[hot data] ------ conversationSize:\(conversationSize). thread=\(thread.uniqueId)")
        
        // The "sortIndex" is a zero relative number representing where
        // this interaction is in the conversation, with the first message
        // being 0 and the newest/last message being conversationSize - 1
        let getSortIndex = { (interactionUniqueId: String) throws -> Int in
            // To calculate the sort index, we figure out how far we are from the newest
            // message, and then subtract that from the conversation size. In the most
            // common cases, this will be *substantially* faster than trying to calculate
            // the distance from the oldest message, since most of the time the user will
            // be scrolled towards the bottom of the conversation. The further you scroll
            // from the bottom of the conversation, the more expensive this query will get.
            guard let distanceFromLatest = try self.interactionFinder.distanceFromLatest(interactionUniqueId: interactionUniqueId, transaction: transaction) else {
                throw OWSAssertionError("viewIndex was unexpectedly nil")
            }
            return Int(conversationSize - distanceFromLatest - 1)
        }

        let lowerBound: Int
        switch direction {
        case .before(let interactionUniqueId):
            let sortIndex = try getSortIndex(interactionUniqueId)
            lowerBound = sortIndex - count + 1
        case .after(let interactionUniqueId):
            let sortIndex = try getSortIndex(interactionUniqueId)
            lowerBound = sortIndex
        case .around(let interactionUniqueId):
            let sortIndex = try getSortIndex(interactionUniqueId)
            lowerBound = sortIndex - count / 2
        case .newest:
            lowerBound = Int(conversationSize) - count
        }
        let upperBound = lowerBound + count
        let requestRange = (lowerBound..<upperBound).clamped(to: 0..<Int(conversationSize))
        let requestSet = IndexSet(integersIn: requestRange)

        let unfetchedSet = requestSet.subtracting(loadedIndexSet.get())
        guard unfetchedSet.count > 0 else {
            //.newest 初始化没有数据，尝试拉取 hotdata
            
            Logger.info("ignoring empty fetch request: \(unfetchedSet.count) thread=\(thread.uniqueId)")
            updateCanLoadMore(conversationSize: conversationSize)
            return ConversationMessageMappingDiff(addedItemIds: [], removedItemIds: [], updatedItemIds: [])
        }

        // For perf we only want to fetch a substantially full batch...
        let isSubstantialRequest = unfetchedSet.count > (requestSet.count / 2)
        // ...but we always fulfill even small requests if we're getting just the tail end
        let isFetchingEdge = unfetchedSet.contains(0) || unfetchedSet.contains(Int(conversationSize - 1))

        guard isSubstantialRequest || isFetchingEdge else {
            Logger.info("ignoring small fetch request: \(unfetchedSet.count) thread=\(thread.uniqueId)")
            return ConversationMessageMappingDiff(addedItemIds: [], removedItemIds: [], updatedItemIds: [])
        }

        let oldItemIds = Set(self.loadedUniqueIds)

        guard let minUnfetched = unfetchedSet.min() else {
            Logger.warn("unfetchedSet is empty")
            return ConversationMessageMappingDiff(addedItemIds: [], removedItemIds: [], updatedItemIds: [])
        }
        let nsRange: NSRange = NSRange(location: minUnfetched, length: unfetchedSet.count)
        Logger.info("------ unfetching set: \(unfetchedSet), nsRange: \(nsRange) thread=\(thread.uniqueId)")
        let newItems = try fetchInteractions(nsRange: nsRange, transaction: transaction)

        let isFetchContiguousWithAlreadyLoadedItems = requestSet.union(loadedIndexSet.get()).isContiguous
        if isFetchContiguousWithAlreadyLoadedItems, let minLoaded = loadedIndexSet.get().min() {
            // If fetched items are just before the already loaded ones...
            if let maxUnfetched = unfetchedSet.max(), maxUnfetched < minLoaded {
                self.loadedIndexSet.update { $0.formUnion(requestSet) }
                let items = (newItems + self.loadedInteractions)
                let trimmedItems = items.prefix(maxInteractionLimit)
                if items.count != trimmedItems.count {
                    let trimCount = items.count - trimmedItems.count
                    self.loadedIndexSet.update { current in
                        let trimmedSet = current.suffix(trimCount)
                        current.subtract(IndexSet(trimmedSet))
                    }
                    Logger.verbose("trimmed newest \(trimCount) items")
                }
                self.loadedInteractions = Array(trimmedItems)
                
                // If fetched items are just after the already loaded ones...
            } else {
                self.loadedIndexSet.update { $0.formUnion(requestSet) }
                let items = (self.loadedInteractions + newItems)
                let trimmedItems = items.suffix(maxInteractionLimit)
                if items.count != trimmedItems.count {
                    let trimCount = items.count - trimmedItems.count
                    self.loadedIndexSet.update { current in
                        let trimmedSet = current.prefix(trimCount)
                        current.subtract(IndexSet(trimmedSet))
                    }
                    Logger.verbose("trimmed oldest \(trimCount) items")
                }
                self.loadedInteractions = Array(trimmedItems)
            }
        } else {
            // replace, rather than append, because the fetched records are not contiguous
            // with the existing loadedIndexSet
            self.loadedIndexSet.set(requestSet)
            self.loadedInteractions = newItems
        }

        updateCanLoadMore(conversationSize: conversationSize)
        
        let newItemIds = Set(self.loadedUniqueIds)
        
        let removedItemIds = oldItemIds.subtracting(newItemIds)
        let addedItemIds = newItemIds.subtracting(oldItemIds)
        
        return ConversationMessageMappingDiff(addedItemIds: addedItemIds,
                                              removedItemIds: removedItemIds,
                                              updatedItemIds: [])
    }

    @objc
    public class ConversationMessageMappingDiff: NSObject {
        @objc
        public let addedItemIds: Set<String>
        @objc
        public let removedItemIds: Set<String>
        @objc
        public let updatedItemIds: Set<String>

        init(addedItemIds: Set<String>, removedItemIds: Set<String>, updatedItemIds: Set<String>) {
            self.addedItemIds = addedItemIds
            self.removedItemIds = removedItemIds
            self.updatedItemIds = updatedItemIds
        }
    }

    // Updates and then calculates which items were inserted, removed or modified.
    @objc
    public func updateAndCalculateDiff(updatedInteractionIds: Set<String>,
                                       transaction: SDSAnyReadTransaction) throws -> ConversationMessageMappingDiff {
        let oldItemIds = Set(self.loadedUniqueIds)
        try reloadInteractions(transaction: transaction)
        let newItemIds = Set(self.loadedUniqueIds)

        let removedItemIds = oldItemIds.subtracting(newItemIds)
        let addedItemIds = newItemIds.subtracting(oldItemIds)
        // We only notify for updated items that a) were previously loaded b) weren't also inserted or removed.
        let exclusivelyUpdatedItemIds = updatedInteractionIds.subtracting(addedItemIds)
            .subtracting(removedItemIds)
            .intersection(oldItemIds)

        return ConversationMessageMappingDiff(addedItemIds: addedItemIds,
                                              removedItemIds: removedItemIds,
                                              updatedItemIds: exclusivelyUpdatedItemIds)
    }

    func updateCanLoadMore(conversationSize: UInt) {
        if conversationSize > 0 {
            
            self.canLoadOlder.set(!loadedIndexSet.contains(0))
            self.canLoadNewer.set(!loadedIndexSet.contains(Int(conversationSize) - 1))
        } else {
            
            self.canLoadOlder.set(false)
            self.canLoadNewer.set(false)
        }
        Logger.info("------ conversationSize:\(conversationSize) canLoadOlder: \(canLoadOlder) canLoadNewer: \(canLoadNewer) thread=\(thread.uniqueId)")
    }

    private func fetchInteractions(nsRange: NSRange, transaction: SDSAnyReadTransaction) throws -> [TSInteraction] {
        
        // This method is a perf hotspot. To improve perf, we try to leverage
        // the model cache. If any problems arise, we fall back to using
        // interactionFinder.enumerateInteractions() which is robust but expensive.
        let loadWithoutCache: () throws -> [TSInteraction] = {
            
            var newItems: [TSInteraction] = []
            try self.interactionFinder.enumerateInteractions(range: nsRange, transaction: transaction) { (interaction: TSInteraction, _) in
                newItems.append(interaction)
            }
            return newItems
        }
        
        // Loading the mapping from the cache has the following steps:
        //
        // 1. Fetch the uniqueIds for the interactions in the load window/mapping.
        let interactionIds = try interactionFinder.interactionIds(inRange: nsRange, transaction: transaction)
        guard !interactionIds.isEmpty else {
            return []
        }
        
        // 2. Try to pull as many interactions as possible from the cache.
        var interactionIdToModelMap: [String: TSInteraction] = interactionReadCache.getInteractionsIfInCache(forUniqueIds: interactionIds,
                                                                                                             transaction: transaction)
        var interactionsToLoad = Set(interactionIds)
        interactionsToLoad.subtract(interactionIdToModelMap.keys)
        
        // 3. Bulk load any interactions that are not in the cache in a
        //    single query.
        //
        // NOTE: There's an upper bound on how long SQL queries should be.
        //       We use kMaxIncrementalRowChanges to limit query size.
        guard interactionsToLoad.count <= DatabaseChangeObserver.kMaxIncrementalRowChanges else {
            return try loadWithoutCache()
        }
        if !interactionsToLoad.isEmpty {
            let loadedInteractions = InteractionFinder.interactions(withInteractionIds: interactionsToLoad, transaction: transaction)
            guard loadedInteractions.count == interactionsToLoad.count else {
                owsFailDebug("Loading interactions failed.")
                return try loadWithoutCache()
            }
            for interaction in loadedInteractions {
                interactionIdToModelMap[interaction.uniqueId] = interaction
            }
        }
        guard interactionIds.count == interactionIdToModelMap.count else {
            owsFailDebug("Missing interactions.")
            return try loadWithoutCache()
        }
        
        // 4. Build the ordered list of interactions.
        var interactions = [TSInteraction]()
        for interactionId in interactionIds {
            guard let interaction = interactionIdToModelMap[interactionId] else {
                owsFailDebug("Couldn't read interaction: \(interactionId)")
                return try loadWithoutCache()
            }
            interactions.append(interaction)
        }
        
        Logger.info("message mapping interactions: \(interactions.count) thread=\(thread.uniqueId)")
        
        return interactions
    }

    @objc
    var oldestUnreadInteraction: TSInteraction? {
        get {
            _oldestUnreadInteraction.get()
        }
        set {
            _oldestUnreadInteraction.set(newValue)
        }
    }
    private var _oldestUnreadInteraction: AtomicOptional<TSInteraction> = .init(nil, lock: .sharedGlobal)
    
    private func updateOldestUnreadInteraction(transaction: SDSAnyReadTransaction) throws {
        self.oldestUnreadInteraction = try interactionFinder.oldestUnseenInteraction(transaction: transaction)
    }

    private func reloadInteractions(transaction: SDSAnyReadTransaction) throws {
        if self.oldestUnreadInteraction == nil {
            try updateOldestUnreadInteraction(transaction: transaction)
        }
        let conversationSize = interactionFinder.count(transaction: transaction)

        let hasLoadedBottomEdge = !canLoadNewer.get() // contain conversationSize-1
        guard hasLoadedBottomEdge else {
            let reloadingSet = loadedIndexSet.get()
            let nsRange: NSRange = NSRange(location: reloadingSet.min()!, length: reloadingSet.count)
            Logger.info("reloadingSet: \(reloadingSet), nsRange: \(nsRange) thread=\(thread.uniqueId)")
            loadedInteractions = try fetchInteractions(nsRange: nsRange, transaction: transaction)
            updateCanLoadMore(conversationSize: conversationSize)
            return
        }

        guard var oldestLoadedIndex = loadedIndexSet.get().min() else {
            // no existing interactions until now
            try loadInitialMessagePage(focusMessageId: nil, transaction: transaction)
            return
        }

        // Ensure we're keeping at least `initialLoadCount` in our load window.
        // This solves two problems:
        //  1. avoids a crash in the extreme case that we delete a page of messages and
        //     conversationSize becomes less than oldestLoadedIndex
        //  2. in the case where we delete enough messages that reloading would leave us within the
        //     "autoload more messages" threshold, instead, we more optimally load more messages now.
        oldestLoadedIndex = min(oldestLoadedIndex, Int(conversationSize) - initialLoadCount)
        oldestLoadedIndex = max(0, oldestLoadedIndex)

        let updatingSet = IndexSet(integersIn: oldestLoadedIndex..<Int(conversationSize))
        guard updatingSet.count > 0 else {
            Logger.verbose("conversation is now empty")
            loadedIndexSet.set([])
            loadedInteractions = []
            updateCanLoadMore(conversationSize: conversationSize)
            return
        }

        Logger.info("loadedIndexSet: \(loadedIndexSet) thread=\(thread.uniqueId)")
        loadedIndexSet.set(updatingSet)
        let nsRange: NSRange = NSRange(location: updatingSet.min()!, length: updatingSet.count)
        Logger.info("updatingSet: \(updatingSet), nsRange: \(nsRange) thread=\(thread.uniqueId)")
        loadedInteractions = try fetchInteractions(nsRange: nsRange, transaction: transaction)
        updateCanLoadMore(conversationSize: conversationSize)
    }
    
}

@objc
public class ConversationScrollState: NSObject {

    @objc
    public let referenceViewItem: ConversationViewItem

    @objc
    public let referenceFrame: CGRect

    @objc
    public let contentOffset: CGPoint

    @objc
    public init(referenceViewItem: ConversationViewItem, referenceFrame: CGRect, contentOffset: CGPoint) {
        self.referenceViewItem = referenceViewItem
        self.referenceFrame = referenceFrame
        self.contentOffset = contentOffset
    }
}

extension IndexSet {
    var isContiguous: Bool {
        guard !self.isEmpty else {
            return true
        }
        guard let min = self.min() else {
            owsFailDebug("min was unexpectedly nil")
            return true
        }
        guard let max = self.max() else {
            owsFailDebug("min was unexpectedly nil")
            return true
        }
        
        return self == IndexSet(min..<(max+1))
    }
}
