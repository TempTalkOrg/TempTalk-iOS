//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewModel.h"
#import "ConversationViewItem.h"
#import "DateUtil.h"
#import "OWSQuotedReplyModel.h"
#import "TempTalk-Swift.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/ThreadUtil.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/SSKEnvironment.h>
#import <TTServiceKit/TSIncomingMessage.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConversationProfileState : NSObject

@property (nonatomic) BOOL hasLocalProfile;
@property (nonatomic) BOOL isThreadInProfileWhitelist;
@property (nonatomic) BOOL hasUnwhitelistedMember;

@end

#pragma mark -

@interface ConversationReloadItemsResult : NSObject

@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, strong) ConversationViewState *viewState;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<ConversationViewItem>> *viewItemCache;

@end

@implementation ConversationReloadItemsResult

- (instancetype)initWithHasError:(BOOL)hasError
                       viewState:(ConversationViewState *)viewState
                    viewItemCache:(NSMutableDictionary<NSString *, id<ConversationViewItem>> *)viewItemCache {
    self = [super init];
    if (self) {
        _hasError = hasError;
        _viewState = viewState;
        _viewItemCache = viewItemCache;
    }
    return self;
}

@end

#pragma mark -

@implementation ConversationProfileState

@end

@implementation ConversationViewState

- (instancetype)initWithViewItems:(NSArray<id<ConversationViewItem>> *)viewItems
                   needRefreshIds:(NSArray<NSString *> *)needRefreshIds
                   focusMessageId:(nullable NSString *)focusMessageId
{
    self = [super init];
    if (!self) {
        return self;
    }

    _viewItems = viewItems;
    _needRefreshIds = needRefreshIds;
    NSMutableDictionary<NSString *, NSNumber *> *interactionIndexMap = [NSMutableDictionary new];
    NSMutableDictionary<NSString *, id<ConversationViewItem>> *viewItemsMap = [NSMutableDictionary new];
    NSMutableArray<NSString *> *interactionIds = [NSMutableArray new];
    for (NSUInteger i = 0; i < self.viewItems.count; i++) {
        id<ConversationViewItem> viewItem = self.viewItems[i];
        interactionIndexMap[viewItem.interaction.uniqueId] = @(i);
        viewItemsMap[viewItem.interaction.uniqueId] = viewItem;
        [interactionIds addObject:viewItem.interaction.uniqueId];
        if (focusMessageId != nil && [focusMessageId isEqualToString:viewItem.interaction.uniqueId]) {
            _focusItemIndex = @(i);
        }
        
        if ([viewItem.interaction isKindOfClass:OWSUnreadIndicatorInteraction.class]) {
            _unreadIndicatorIndex = @(i);
        }
    }
    _interactionIndexMap = [interactionIndexMap copy];
    _viewItemsMap = [viewItemsMap copy];
    _interactionIds = [interactionIds copy];

    return self;
}

@end

#pragma mark -

@implementation ConversationUpdateItem

- (instancetype)initWithUpdateItemType:(ConversationUpdateItemType)updateItemType
                              oldIndex:(NSUInteger)oldIndex
                              newIndex:(NSUInteger)newIndex
                              viewItem:(nullable id<ConversationViewItem>)viewItem
{
    self = [super init];
    if (!self) {
        return self;
    }

    _updateItemType = updateItemType;
    _oldIndex = oldIndex;
    _newIndex = newIndex;
    _viewItem = viewItem;

    return self;
}

@end

#pragma mark -

@implementation ConversationUpdate

- (instancetype)initWithConversationUpdateType:(ConversationUpdateType)conversationUpdateType
                                   updateItems:(nullable NSArray<ConversationUpdateItem *> *)updateItems
                          shouldAnimateUpdates:(BOOL)shouldAnimateUpdates
{
    self = [super init];
    if (!self) {
        return self;
    }

    _conversationUpdateType = conversationUpdateType;
    _updateItems = updateItems;
    _shouldAnimateUpdates = shouldAnimateUpdates;

    return self;
}

+ (ConversationUpdate *)minorUpdate
{
    return [[ConversationUpdate alloc] initWithConversationUpdateType:ConversationUpdateType_Minor
                                                          updateItems:nil
                                                 shouldAnimateUpdates:NO];
}

+ (ConversationUpdate *)reloadUpdate
{
    return [[ConversationUpdate alloc] initWithConversationUpdateType:ConversationUpdateType_Reload
                                                          updateItems:nil
                                                 shouldAnimateUpdates:NO];
}

+ (ConversationUpdate *)diffUpdateWithUpdateItems:(nullable NSArray<ConversationUpdateItem *> *)updateItems
                             shouldAnimateUpdates:(BOOL)shouldAnimateUpdates
{
    return [[ConversationUpdate alloc] initWithConversationUpdateType:ConversationUpdateType_Diff
                                                          updateItems:updateItems
                                                 shouldAnimateUpdates:shouldAnimateUpdates];
}

@end

#pragma mark -

@interface ConversationViewModel ()<DatabaseChangeDelegate>

@property (nonatomic, weak) id<ConversationViewModelDelegate> delegate;

@property (nonatomic, readonly) TSThread *thread;

// The mapping must be updated in lockstep with the uiDatabaseConnection.
//
// * The first (required) step is to update uiDatabaseConnection using beginLongLivedReadTransaction.
// * The second (required) step is to update messageMapping. The desired length of the mapping
//   can be modified at this time.
// * The third (optional) step is to update the view items using reloadViewItems.
// * The steps must be done in strict order.
// * If we do any of the steps, we must do all of the required steps.
// * We can't use messageMapping or viewItems after the first step until we've
//   done the last step; i.e.. we can't do any layout, since that uses the view
//   items which haven't been updated yet.
// * Afterward, we must prod the view controller to update layout & view state.
@property (nonatomic) ConversationMessageMapping *messageMapping;

@property (nonatomic) ConversationViewState *viewState;
@property (nonatomic) NSMutableDictionary<NSString *, id<ConversationViewItem>> *viewItemCache;

@property (nonatomic) BOOL hasClearedUnreadMessagesIndicator;
@property (nonatomic) NSDate *collapseCutoffDate;

@property (nonatomic, nullable) ConversationProfileState *conversationProfileState;
@property (nonatomic) BOOL hasTooManyOutgoingMessagesToBlockCached;

@property (nonatomic) NSArray<id<ConversationViewItem>> *persistedViewItems;
@property (nonatomic) NSArray<TSOutgoingMessage *> *unsavedOutgoingMessages;

@property (nonatomic, strong) NSArray<TSMessageReadPosition *> *recipientReadPositions;

@property (nonatomic, assign) BOOL isLoadingMore;

@property (nonatomic, assign) NSInteger lastTranslateState;

@end

#pragma mark -

@implementation ConversationViewModel

- (instancetype)initWithThread:(TSThread *)thread
          focusMessageIdOnOpen:(nullable NSString *)focusMessageIdOnOpen
          conversationViewMode:(ConversationViewMode)conversationViewMode
                   botViewItem:(nullable id<ConversationViewItem>)botViewItem
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSAssertDebug(thread);

    _thread = thread;
    _conversationMode = conversationViewMode;
    _botViewItem = botViewItem;
    _persistedViewItems = @[];
    _unsavedOutgoingMessages = @[];
    _focusMessageIdOnOpen = focusMessageIdOnOpen;
    _viewState = [[ConversationViewState alloc] initWithViewItems:@[] needRefreshIds:@[] focusMessageId:focusMessageIdOnOpen];
    _lastTranslateState = thread.translateSettingType.integerValue;
    
    _messageMapping = [[ConversationMessageMapping alloc] initWithViewModel:self thread:thread threadUniqueId:self.thread.uniqueId];
    _collapseCutoffDate = [NSDate new];
    
    return self;
}

// NOTE❗️❗️❗️:
// [self configure] 原本是在初始化方法中执行的，但是其执行过程中依赖 delegate，
// 这导致 ConversationViewModel 初始化时必须设置 delegate，
// 当 ConversationViewModel 作为某个类的非 Optional 存储属性时，这将产生冲突。
//
// 以 ConversationViewController.swift 为例，由于 ConversationViewModel 作为非 Optional 存储属性，
// 需要在 super.init() 之前完成初始化，但是 ConversationViewModel 初始化时需要设置 delegate，而此时 ConversationViewController
// 还未完成初始化，无法使用 self，进而无法设置 delegate = self，产生冲突。
// 虽然可以将 ConversationViewModel 改为 Optional 属性来解决上述问题，但势必造成后面使用时大量的可选解包，
// 从业务上来说，ConversationViewModel 也不该为 Optional。
//
// 综上最好的解决办法是，初始化时不需要设置 delegate，依赖 delegate 的方法就要从初始化方法中移除，在设置完 delegate 后执行
- (void)configWithDelegate:(id<ConversationViewModelDelegate>)delegate {
    _delegate = delegate;
    
    [self configure];
}

#pragma mark - Dependencies

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

- (OWSContactsManager *)contactsManager
{
    return Environment.shared.contactsManager;
}

- (OWSBlockingManager *)blockingManager
{
    return OWSBlockingManager.sharedManager;
}

- (TSAccountManager *)tsAccountManager
{
    return [TSAccountManager sharedInstance];
}

- (OWSProfileManager *)profileManager
{
    return [OWSProfileManager sharedManager];
}

#pragma mark -

- (void)addNotificationListeners
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localProfileDidChange:)
                                                 name:kNSNotificationName_LocalProfileDidChange
                                               object:nil];
    
    [self.databaseStorage appendDatabaseChangeDelegate:self];
}

- (void)localProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    self.conversationProfileState = nil;
    [self updateForTransientItems];
}

- (void)configure
{
    OWSLogInfo(@"");

    [BenchManager benchWithTitle:@"loading initial interactions"
                           block:^{
                               [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
                                   NSError *error;
                                   [self.messageMapping
                                       loadInitialMessagePageWithFocusMessageId:self.focusMessageIdOnOpen
                                                                    transaction:transaction
                                                                          error:&error];
                                   if (error != nil) {
                                       OWSFailDebug(@"error: %@", error);
                                   }
//                                   if (![self reloadViewItemsWithTransaction:transaction]) {
//                                       OWSFailDebug(@"failed to reload view items in configureForThread.");
//                                   }
                               }];
                           }];
}

- (void)viewDidLoad
{
    [self addNotificationListeners];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self resetClearedUnreadMessagesIndicator];
}

- (void)viewDidResetContentAndLayoutWithTransaction:(SDSAnyReadTransaction *)transaction
{
    self.collapseCutoffDate = [NSDate new];
    if (![self reloadViewItemsWithTransaction:transaction]) {
        OWSFailDebug(@"failed to reload view items in resetContentAndLayout.");
    }
}

- (BOOL)canLoadOlderItems
{
    return self.messageMapping.canLoadOlder;
}

- (BOOL)canLoadNewerItems
{
    return self.messageMapping.canLoadNewer;
}

- (BOOL)canFetchOlderItems
{
    return self.messageMapping.canFetchOlder;
}

- (BOOL)canFetchNewerItems
{
    return self.messageMapping.canFetchNewer;
}

- (void)appendOlderItemsWithTransaction:(SDSAnyReadTransaction *)transaction
{
    // 解决在下拉加载更多时，数据还在处理中，继续下拉刷新，导致一次拉取了多页数据
    if (self.isLoadingMore) {
        return;
    }
    self.isLoadingMore = YES;
    
    OWSLogDebug(@"[hot data] appendOlderItemsWithTransaction");
    
    [self.delegate conversationViewModelWillLoadMoreItems];
    NSError *error;
    [self.messageMapping loadOlderMessagePageWithTransaction:transaction error:&error];
    if (error != nil) {
        OWSFailDebug(@"failure: %@", error);
    }
    [self.delegate conversationViewModelDidUpdateLoadMoreStatus];
    
    // 在 3.0.8 版本中支持了异步 reload，需要在 reload completion 之后才能执行 did load more items 相关操作
    @weakify(self)
    [self diffMappingWithTransaction:transaction completion:^(BOOL isFinished) {
        @strongify(self)
        if (isFinished) {
            [self.delegate conversationViewModelDidLoadMoreItems];
        }
        self.isLoadingMore = NO;
    }];
}

- (void)appendNewerItemsWithTransaction:(SDSAnyReadTransaction *)transaction
{
    // 解决在下拉加载更多时，数据还在处理中，继续下拉刷新，导致一次拉取了多页数据
    if (self.isLoadingMore) {
        return;
    }
    self.isLoadingMore = YES;
    
    OWSLogDebug(@"[hot data] appendNewerItemsWithTransaction");
    
    [self.delegate conversationViewModelWillLoadMoreItems];
    NSError *error;
    [self.messageMapping loadNewerMessagePageWithTransaction:transaction error:&error];
    if (error != nil) {
        OWSFailDebug(@"failure: %@", error);
    }
    [self.delegate conversationViewModelDidUpdateLoadMoreStatus];
    
    // 在 3.0.8 版本中支持了异步 reload，需要在 reload completion 之后才能执行 did load more items 相关操作
    @weakify(self)
    [self diffMappingWithTransaction:transaction completion:^(BOOL isFinished) {
        @strongify(self)
        if (isFinished) {
            [self.delegate conversationViewModelDidLoadMoreItems];
        }
        self.isLoadingMore = NO;
    }];
}

- (void)clearUnreadMessagesIndicator
{
    OWSAssertIsOnMainThread();
    self.messageMapping.oldestUnreadInteraction = nil;

    // Once we've cleared the unread messages indicator,
    // make sure we don't show it again.
    self.hasClearedUnreadMessagesIndicator = YES;
}

- (void)resetClearedUnreadMessagesIndicator
{
    OWSAssertIsOnMainThread();
    self.messageMapping.oldestUnreadInteraction = nil;
    self.hasClearedUnreadMessagesIndicator = NO;
//    [self updateForTransientItems];
}

#pragma mark - GRDB Updates

- (void)databaseChangesDidUpdateExternally {
    NSSet<NSString *> *updatedInteractionIds = [[NSSet alloc] initWithArray:self.messageMapping.loadedUniqueIds];
    [self anyDBDidUpdateWithUpdatedInteractionIds:updatedInteractionIds];
}

- (void)databaseChangesDidReset {
    [self resetMappingWithSneakyTransaction];
}

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges
{
    OWSAssertIsOnMainThread();

    OWSLogDebug(@"------> collectionView databaseChanges.threadUniqueIds:%@ \n interactionUniqueIds:%@", databaseChanges.threadUniqueIds, databaseChanges.interactionUniqueIds);
    
    // NOTE: 解决由于 pin message 的表格没有关联 thread 表，当用户离线数据只有 pin 消息内容变更时，databaseChanges 中无对应会话的 threadUniqueId，会被下面的条件过滤掉
    if (self.thread.isGroupThread && [databaseChanges.tableNames containsObject:@"model_DTPinnedMessage"]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(conversationViewModelUpdatePin)]) {
            [self.delegate conversationViewModelUpdatePin];
        }
    }
    
    if (![databaseChanges.threadUniqueIds containsObject:self.thread.uniqueId]) {
        // Ignoring irrelevant update.
        
        OWSLogDebug(@"[hot data] thread:%@ Ignoring irrelevant update. isFetchingData:%d.", self.thread.debugName, [self.messageMapping.isFetchingData get]);
        return;
    }

//    if (!databaseChanges.interactionUniqueIds.count && !self.shouldShowThreadDetails) {
    if (!databaseChanges.interactionUniqueIds.count) {
        [self.delegate conversationViewModelDidUpdate:ConversationUpdate.minorUpdate transaction:nil completion:nil];
        return;
    }

    [self anyDBDidUpdateWithUpdatedInteractionIds:databaseChanges.interactionUniqueIds];
}

- (void)anyDBDidUpdateWithUpdatedInteractionIds:(NSSet<NSString *> *)updatedInteractionIds
{
    __block ConversationMessageMappingDiff *_Nullable diff = nil;
    __block NSError *error;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        diff = [self.messageMapping updateAndCalculateDiffWithUpdatedInteractionIds:updatedInteractionIds
                                                                        transaction:transaction
                                                                              error:&error];
    }];
    if (error != nil || diff == nil) {
        OWSFailDebug(@"Could not determine diff. error: %@", error);
        // resetMapping will call delegate.conversationViewModelDidUpdate.
        [self resetMappingWithSneakyTransaction];
        [self.delegate conversationViewModelDidReset];
        return;
    }

    NSMutableSet<NSString *> *diffAddedItemIds = [diff.addedItemIds mutableCopy];
    NSMutableSet<NSString *> *diffRemovedItemIds = [diff.removedItemIds mutableCopy];
    NSMutableSet<NSString *> *diffUpdatedItemIds = [diff.updatedItemIds mutableCopy];

    // If we have a thread details item, insert it into the updated items. We assume
    // it always needs to update, because it's rarely actually loaded and can be changed
    // by a large number of thread updates.
//    if (self.shouldShowThreadDetails) {
//        [diffUpdatedItemIds addObject:OWSThreadDetailsInteraction.ThreadDetailsId];
//    }
    
    if (diffAddedItemIds.count < 1 && diffRemovedItemIds.count < 1 && diffUpdatedItemIds.count < 1) {
        // This probably isn't an error; presumably the modifications
        // occurred outside the load window.
        OWSLogDebug(@"Empty diff.");
//        [self.delegate conversationViewModelDidUpdateWithSneakyTransaction:ConversationUpdate.minorUpdate];
        return;
    }
    
    for (TSOutgoingMessage *unsavedOutgoingMessage in self.unsavedOutgoingMessages) {
        BOOL isFound = ([diff.addedItemIds containsObject:unsavedOutgoingMessage.uniqueId] ||
                        [diff.removedItemIds containsObject:unsavedOutgoingMessage.uniqueId] ||
                        [diff.updatedItemIds containsObject:unsavedOutgoingMessage.uniqueId] ||
                        [updatedInteractionIds containsObject:unsavedOutgoingMessage.uniqueId]);
        if (isFound) {
            // Convert the "insert" to an "update".
            if ([diffAddedItemIds containsObject:unsavedOutgoingMessage.uniqueId]) {
                OWSLogVerbose(@"Converting insert to update: %@", unsavedOutgoingMessage.uniqueId);
                [diffAddedItemIds removeObject:unsavedOutgoingMessage.uniqueId];
                [diffUpdatedItemIds addObject:unsavedOutgoingMessage.uniqueId];
            }

            // Remove the unsavedOutgoingViewItem since it now exists as a persistedViewItem
            NSMutableArray<TSOutgoingMessage *> *unsavedOutgoingMessages = [self.unsavedOutgoingMessages mutableCopy];
            [unsavedOutgoingMessages removeObject:unsavedOutgoingMessage];
            self.unsavedOutgoingMessages = [unsavedOutgoingMessages copy];
        }
    }
    
    NSArray<NSString *> *oldItemIdList = self.viewState.interactionIds;
    OWSLogInfo(@"------>conversation old:%ld.", oldItemIdList.count);

    // We need to reload any modified interactions _before_ we call
    // reloadViewItems.
    __block BOOL hasMalformedRowChange = NO;
    NSMutableSet<NSString *> *updatedItemSet = [NSMutableSet new];
    
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        for (NSString *uniqueId in diffUpdatedItemIds) {
            id<ConversationViewItem> _Nullable viewItem = self.viewItemCache[uniqueId];
            if (viewItem) {
                [self reloadInteractionForViewItem:viewItem transaction:transaction];
                [updatedItemSet addObject:viewItem.itemId];
            } else {
                TSInteraction *interaction = [TSInteraction anyFetchWithUniqueId:uniqueId transaction:transaction];
                if (![interaction.uniqueThreadId isEqualToString:self.thread.uniqueId]) {
                    ///ignore 可能是topic消息
                } else {
                    OWSFailDebug(@"Update is missing view item");
                    hasMalformedRowChange = YES;
                }
               
            }
        }
    }];

    for (NSString *uniqueId in diffRemovedItemIds) {
        [self.viewItemCache removeObjectForKey:uniqueId];
    }

    if (hasMalformedRowChange) {
        // These errors seems to be very rare; they can only be reproduced
        // using the more extreme actions in the debug UI.
        OWSFailDebug(@"hasMalformedRowChange");
        // resetMapping will call delegate.conversationViewModelDidUpdate.
        [self resetMappingWithSneakyTransaction];
        [self.delegate conversationViewModelDidReset];
        return;
    }

    if (![self reloadViewItemsWithSneakyTransaction]) {
        // These errors are rare.
        OWSFailDebug(@"could not reload view items; hard resetting message mapping.");
        // resetMapping will call delegate.conversationViewModelDidUpdate.
        [self resetMappingWithSneakyTransaction];
        [self.delegate conversationViewModelDidReset];
        return;
    }

    // We may have filtered out some of the view items.
    // Ensure that these ids are culled from updatedItemSet.
    [updatedItemSet intersectSet:[NSSet setWithArray:self.viewState.interactionIndexMap.allKeys]];
    //add by Kris
    [updatedItemSet unionSet:[NSSet setWithArray:self.viewState.needRefreshIds]];

    OWSLogInfo(@"------>conversation old:%ld, update:%ld.", oldItemIdList.count, updatedItemSet.count);
    
    [self updateViewWithOldItemIdList:oldItemIdList updatedItemSet:updatedItemSet];
}
#pragma mark -

// A simpler version of the update logic we use when
// only transient items have changed.
- (void)updateForTransientItems
{
    OWSAssertIsOnMainThread();

    OWSLogVerbose(@"");

    NSArray<NSString *> *oldItemIdList = self.viewState.interactionIds;

    if (![self reloadViewItemsWithSneakyTransaction]) {
        // These errors are rare.
        OWSFailDebug(@"could not reload view items; hard resetting message mapping.");
        // resetMapping will call delegate.conversationViewModelDidUpdate.
        [self resetMappingWithSneakyTransaction];
        [self.delegate conversationViewModelDidReset];
        return;
    }

    OWSLogVerbose(@"self.viewItems.count: %zd -> %zd", oldItemIdList.count, self.viewState.viewItems.count);

    [self updateViewWithOldItemIdList:oldItemIdList updatedItemSet:[NSSet set]];
}

- (ConversationUpdate *)conversationUpdateWithOldItemIdList:(NSArray<NSString *> *)oldItemIdList
                                             updatedItemSet:(NSSet<NSString *> *)updatedItemSetParam
{
    OWSAssertDebug(oldItemIdList);
    OWSAssertDebug(updatedItemSetParam);
    
    if (oldItemIdList.count != [NSSet setWithArray:oldItemIdList].count) {
        OWSFailDebug(@"Old view item list has duplicates.");
        return ConversationUpdate.reloadUpdate;
    }
    
    NSArray<NSString *> *newItemIdList = self.viewState.interactionIds;
    NSMutableDictionary<NSString *, id<ConversationViewItem>> *newViewItemMap = [NSMutableDictionary new];
    for (id<ConversationViewItem> viewItem in self.viewState.viewItems) {
        newViewItemMap[viewItem.itemId] = viewItem;
    }
    
    if (newItemIdList.count != [NSSet setWithArray:newItemIdList].count) {
        OWSFailDebug(@"New view item list has duplicates.");
        return ConversationUpdate.reloadUpdate;
    }
    
    NSSet<NSString *> *oldItemIdSet = [NSSet setWithArray:oldItemIdList];
    NSSet<NSString *> *newItemIdSet = [NSSet setWithArray:newItemIdList];
    
    // We use sets and dictionaries here to ensure perf.
    // We use NSMutableOrderedSet to preserve item ordering.
    NSMutableOrderedSet<NSString *> *deletedItemIdSet = [NSMutableOrderedSet orderedSetWithArray:oldItemIdList];
    [deletedItemIdSet minusSet:newItemIdSet];
    NSMutableOrderedSet<NSString *> *insertedItemIdSet = [NSMutableOrderedSet orderedSetWithArray:newItemIdList];
    [insertedItemIdSet minusSet:oldItemIdSet];
    NSArray<NSString *> *deletedItemIdList = [deletedItemIdSet.array copy];
    NSArray<NSString *> *insertedItemIdList = [insertedItemIdSet.array copy];
    
    // Try to generate a series of "update items" that safely transform
    // the "old item list" into the "new item list".
    NSMutableArray<ConversationUpdateItem *> *updateItems = [NSMutableArray new];
    NSMutableArray<NSString *> *transformedItemList = [oldItemIdList mutableCopy];

    // 1. Deletes - Always perform deletes before inserts and updates.
    //
    // NOTE: We use reverseObjectEnumerator to ensure that items
    //       are deleted in reverse order, to avoid confusion around
    //       each deletion affecting the indices of subsequent deletions.
    for (NSString *itemId in deletedItemIdList.reverseObjectEnumerator) {
        OWSAssertDebug([oldItemIdSet containsObject:itemId]);
        OWSAssertDebug(![newItemIdSet containsObject:itemId]);

        NSUInteger oldIndex = [oldItemIdList indexOfObject:itemId];
        if (oldIndex == NSNotFound) {
            OWSFailDebug(@"Can't find index of deleted view item.");
            return ConversationUpdate.reloadUpdate;
        }

        [updateItems addObject:[[ConversationUpdateItem alloc] initWithUpdateItemType:ConversationUpdateItemType_Delete
                                                                             oldIndex:oldIndex
                                                                             newIndex:NSNotFound
                                                                             viewItem:nil]];
        [transformedItemList removeObject:itemId];
    }
    
    // 2. Inserts - Always perform inserts before updates.
    //
    // NOTE: We DO NOT use reverseObjectEnumerator.
    for (NSString *itemId in insertedItemIdList) {
        OWSAssertDebug(![oldItemIdSet containsObject:itemId]);
        OWSAssertDebug([newItemIdSet containsObject:itemId]);

        NSUInteger newIndex = [newItemIdList indexOfObject:itemId];
        if (newIndex == NSNotFound) {
            OWSFailDebug(@"Can't find index of inserted view item.");
            return ConversationUpdate.reloadUpdate;
        }
        id<ConversationViewItem> _Nullable viewItem = newViewItemMap[itemId];
        if (!viewItem) {
            OWSFailDebug(@"Can't find inserted view item.");
            return ConversationUpdate.reloadUpdate;
        }

        [updateItems addObject:[[ConversationUpdateItem alloc] initWithUpdateItemType:ConversationUpdateItemType_Insert
                                                                             oldIndex:NSNotFound
                                                                             newIndex:newIndex
                                                                             viewItem:viewItem]];
        [transformedItemList insertObject:itemId atIndex:newIndex];
    }

    if (![newItemIdList isEqualToArray:transformedItemList]) {
        // We should be able to represent all transformations as a series of
        // inserts, updates and deletes - moves should not be necessary.
        //
        // TODO: The unread indicator might end up being an exception.
        OWSLogWarn(@"New and updated view item lists don't match.");
        return ConversationUpdate.reloadUpdate;
    }

    // In addition to "update" items from the database change notification,
    // we may need to update other items.  One example is neighbors of modified
    // cells. Another is cells whose appearance has changed due to the passage
    // of time.  We detect "dirty" items by whether or not they have cached layout
    // state, since that is cleared whenever we change the properties of the
    // item that affect its appearance.
    //
    // This replaces the setCellDrawingDependencyOffsets/
    // YapDatabaseViewChangedDependency logic offered by YDB mappings,
    // which only reflects changes in the data store, not at the view
    // level.
    NSMutableSet<NSString *> *updatedItemSet = [updatedItemSetParam mutableCopy];
    NSMutableSet<NSString *> *updatedNeighborItemSet = [NSMutableSet new];
    for (NSString *itemId in newItemIdSet) {
        if (![oldItemIdSet containsObject:itemId]) {
            continue;
        }
        if ([insertedItemIdSet containsObject:itemId] || [updatedItemSet containsObject:itemId]) {
            continue;
        }
        OWSAssertDebug(![deletedItemIdSet containsObject:itemId]);

        NSUInteger newIndex = [newItemIdList indexOfObject:itemId];
        if (newIndex == NSNotFound) {
            OWSFailDebug(@"Can't find index of holdover view item.");
            return ConversationUpdate.reloadUpdate;
        }
        id<ConversationViewItem> _Nullable viewItem = newViewItemMap[itemId];
        if (!viewItem) {
            OWSFailDebug(@"Can't find holdover view item.");
            return ConversationUpdate.reloadUpdate;
        }
        if (viewItem.needsUpdate) {
            [updatedItemSet addObject:itemId];
            [updatedNeighborItemSet addObject:itemId];
        }
    }

    // 3. Updates.
    //
    // NOTE: Order doesn't matter.
    for (NSString *itemId in updatedItemSet) {
        if (![newItemIdList containsObject:itemId]) {
            OWSFailDebug(@"Updated view item not in new view item list.");
            continue;
        }
        if ([insertedItemIdList containsObject:itemId]) {
            continue;
        }
        NSUInteger oldIndex = [oldItemIdList indexOfObject:itemId];
        if (oldIndex == NSNotFound) {
            OWSFailDebug(@"Can't find old index of updated view item.");
            return ConversationUpdate.reloadUpdate;
        }
        NSUInteger newIndex = [newItemIdList indexOfObject:itemId];
        if (newIndex == NSNotFound) {
            OWSFailDebug(@"Can't find new index of updated view item.");
            return ConversationUpdate.reloadUpdate;
        }
        id<ConversationViewItem> _Nullable viewItem = newViewItemMap[itemId];
        if (!viewItem) {
            OWSFailDebug(@"Can't find inserted view item.");
            return ConversationUpdate.reloadUpdate;
        }
        [updateItems addObject:[[ConversationUpdateItem alloc] initWithUpdateItemType:ConversationUpdateItemType_Update
                                                                             oldIndex:oldIndex
                                                                             newIndex:newIndex
                                                                             viewItem:viewItem]];
    }

    BOOL shouldAnimateUpdates = [self shouldAnimateUpdateItems:updateItems
                                              oldViewItemCount:oldItemIdList.count
                                        updatedNeighborItemSet:updatedNeighborItemSet];
    
    return [ConversationUpdate diffUpdateWithUpdateItems:updateItems shouldAnimateUpdates:shouldAnimateUpdates];
}

- (void)updateViewWithOldItemIdList:(NSArray<NSString *> *)oldItemIdList
                     updatedItemSet:(NSSet<NSString *> *)updatedItemSetParam {
    ConversationUpdate *conversationUpdate = [self conversationUpdateWithOldItemIdList:oldItemIdList
                                                                        updatedItemSet:updatedItemSetParam];
//    [self.delegate conversationViewModelWillLoadMoreItems];self.viewItems.count
    [self.delegate conversationViewModelDidUpdate:conversationUpdate transaction:nil completion:nil];
//    [self.delegate conversationViewModelDidLoadMoreItems];
}

- (BOOL)shouldAnimateUpdateItems:(NSArray<ConversationUpdateItem *> *)updateItems
                oldViewItemCount:(NSUInteger)oldViewItemCount
          updatedNeighborItemSet:(nullable NSMutableSet<NSString *> *)updatedNeighborItemSet
{
    OWSAssertDebug(updateItems);

    // If user sends a new outgoing message, don't animate the change.
    BOOL isOnlyModifyingLastMessage = YES;
    for (ConversationUpdateItem *updateItem in updateItems) {
        switch (updateItem.updateItemType) {
            case ConversationUpdateItemType_Delete:
                isOnlyModifyingLastMessage = NO;
                break;
            case ConversationUpdateItemType_Insert: {
                id<ConversationViewItem> viewItem = updateItem.viewItem;
                OWSAssertDebug(viewItem);
                switch (viewItem.interaction.interactionType) {
                    case OWSInteractionType_IncomingMessage:
                    case OWSInteractionType_OutgoingMessage:
                        if (updateItem.newIndex < oldViewItemCount) {
//                            isOnlyModifyingLastMessage = NO;
                        }
                        break;
                    default:
                        isOnlyModifyingLastMessage = NO;
                        break;
                }
                break;
            }
            case ConversationUpdateItemType_Update: {
                id<ConversationViewItem> viewItem = updateItem.viewItem;
                if ([updatedNeighborItemSet containsObject:viewItem.itemId]) {
                    continue;
                }
                OWSAssertDebug(viewItem);
                switch (viewItem.interaction.interactionType) {
                    case OWSInteractionType_IncomingMessage:
                    case OWSInteractionType_OutgoingMessage:
                        // We skip animations for the last _two_
                        // interactions, not one since there
                        // may be a typing indicator.
                        if (updateItem.newIndex + 2 < updateItems.count) {
                            isOnlyModifyingLastMessage = NO;
                        }
                        break;
                    default:
                        isOnlyModifyingLastMessage = NO;
                        break;
                }
                break;
            }
        }
    }
    BOOL shouldAnimateRowUpdates = !isOnlyModifyingLastMessage;
    return shouldAnimateRowUpdates;
}

// This is more expensive than incremental updates.
//
// We call `resetMapping` for two separate reasons:
//
// * Most of the time, we call `resetMapping` after a severe error to get back into a known good state.
//   We then call `conversationViewModelDidReset` to get the view back into a known good state (by
//   scrolling to the bottom).
// * We also call `resetMapping` to load an additional page of older message.  We very much _do not_
// want to change view scroll state in this case.
- (void)resetMappingWithSneakyTransaction
{
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        [self resetMappingWithTransaction:transaction];
    }];
}

- (void)resetMappingWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(self.messageMapping);

    self.collapseCutoffDate = [NSDate new];

    if (![self reloadViewItemsWithTransaction:transaction]) {
        OWSFailDebug(@"failed to reload view items in resetMapping.");
    }

    // PERF TODO: don't call "reload" when appending new items, do a batch insert. Otherwise we re-render every cell.
    [self.delegate conversationViewModelDidUpdate:ConversationUpdate.reloadUpdate transaction:transaction completion:nil];
}

- (void)diffMappingWithTransaction:(SDSAnyReadTransaction *)transaction completion:(void (^ __nullable)(BOOL))completion
{
    OWSAssertDebug(self.messageMapping);

    NSArray<NSString *> *oldItemIdList = self.viewState.interactionIds;
    
    if (![self reloadViewItemsWithTransaction:transaction]) {
        OWSFailDebug(@"failed to reload view items in diffMapping.");
    }

    ConversationUpdate *conversationUpdate = [self conversationUpdateWithOldItemIdList:oldItemIdList updatedItemSet:[NSSet set]];
    conversationUpdate.shouldAnimateUpdates = NO;
    conversationUpdate.ignoreScrollToDefaultPosition = YES;
    [self.delegate conversationViewModelDidUpdate:conversationUpdate transaction:transaction completion:completion];
}

#pragma mark - View Items

- (nullable NSIndexPath *)indexPathForViewItem:(id<ConversationViewItem>)viewItem
{
    return [self indexPathForInteractionId:viewItem.interaction.uniqueId];
}

- (nullable NSIndexPath *)indexPathForInteractionId:(NSString *)interactionId
{
    NSUInteger index = [self.viewState.viewItems indexOfObjectPassingTest:^BOOL(id<ConversationViewItem>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.interaction.uniqueId isEqualToString:interactionId];
    }];
    if (index == NSNotFound) {
        return nil;
    }
    return [NSIndexPath indexPathForRow:(NSInteger)index inSection:0];
}

- (void)ensureConversationProfileStateWithTransaction:(SDSAnyReadTransaction *)transaction
{
    if (self.conversationProfileState) {
        return;
    }

    // Many OWSProfileManager methods aren't safe to call from inside a database
    // transaction, so do this work now.
    //
    // TODO: It'd be nice if these methods took a transaction.
    BOOL hasLocalProfile = [self.profileManager hasLocalProfileWithTransaction:transaction];
    
    BOOL isThreadInProfileWhitelist = [self.profileManager isThreadInProfileWhitelist:self.thread
                                                                          transaction:transaction];
    BOOL hasUnwhitelistedMember = NO;
//    for (NSString *address in self.thread.recipientIdentifiers) {
//        if (![self.profileManager isUserInProfileWhitelist:address transaction:transaction]) {
//            hasUnwhitelistedMember = YES;
//            break;
//        }
//    }

    ConversationProfileState *conversationProfileState = [ConversationProfileState new];
    conversationProfileState.hasLocalProfile = hasLocalProfile;
    conversationProfileState.isThreadInProfileWhitelist = isThreadInProfileWhitelist;
    conversationProfileState.hasUnwhitelistedMember = hasUnwhitelistedMember;
    self.conversationProfileState = conversationProfileState;
}

// This is a key method.  It builds or rebuilds the list of
// cell view models.
- (BOOL)reloadViewItemsWithSneakyTransaction
{
    __block BOOL result;

    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self reloadViewItemsWithTransaction:transaction];
    }];

    return result;
}

- (void)reloadReadPositionsWithTransaction:(SDSAnyReadTransaction *)transaction {
    if(!self.thread.isWithoutReadRecipt) {
        AnyMessageReadPositonFinder *readPositionFinder = [AnyMessageReadPositonFinder new];
        NSError *error;
        NSMutableArray *items = @[].mutableCopy;
        [readPositionFinder enumerateRecipientReadPositionsWithUniqueThreadId:self.thread.uniqueId
                                                                  transaction:transaction
                                                                        error:&error
                                                                        block:^(TSMessageReadPosition * readPosition) {
            [items addObject:readPosition];
        }];
        self.recipientReadPositions = items.copy;
    }
}

- (BOOL)reloadViewItemsWithTransaction:(SDSAnyReadTransaction *)transaction {
    ConversationReloadItemsResult *result = [self _reloadViewItemsWithTransaction:transaction];
    self.viewState = result.viewState;
    self.viewItemCache = result.viewItemCache;
    return !result.hasError;
}

- (ConversationReloadItemsResult *)_reloadViewItemsWithTransaction:(SDSAnyReadTransaction *)transaction {
    
    OWSLogInfo(@"------>conversation _reloadViewItemsWithTransaction.");
    
    [self reloadReadPositionsWithTransaction:transaction];
    
    NSMutableArray<id<ConversationViewItem>> *viewItems = [NSMutableArray new];
    NSMutableArray<NSString *> *needRefreshIds = [NSMutableArray new];
    NSMutableArray<id<ConversationViewItem>> *cardMessages = [NSMutableArray new];
    NSMutableDictionary<NSString *, id<ConversationViewItem>> *viewItemCache = [NSMutableDictionary new];
    [self ensureConversationProfileStateWithTransaction:transaction];

    __block BOOL hasError = NO;
    _Nullable id<ConversationViewItem> (^tryToAddViewItem)(TSInteraction *) = ^_Nullable id<ConversationViewItem> (TSInteraction *interaction) {
        
        if (![self.thread.uniqueId isEqualToString:interaction.uniqueThreadId]) {///对于非本群的异常消息要进行过滤
            OWSLogError(@"error: interaction.uniqueThreadId not equal to self.thread.uniqueId, %@!=%@.", self.thread.uniqueId, interaction.uniqueThreadId);
            return nil;
        }
        
        __block id<ConversationViewItem> viewItem = nil;
        __block BOOL needMarkAsRead = NO;
        __block BOOL needRefreshCard = NO;
        [self buildViewItemWithInteraction:interaction transaction:transaction completion:^(id<ConversationViewItem> _Nullable item, BOOL read, BOOL refresh) {
            viewItem = item;
            needMarkAsRead = read;
            needRefreshCard = refresh;
        }];
        
        if(!viewItem){
            return nil;
        }
        
        //新增的或者需要刷新的
        if(!self.viewItemCache[interaction.uniqueId] || needRefreshCard){
            if(viewItem.card.content.length){
                [cardMessages addObject:viewItem];
            }
        }
        
        viewItemCache[interaction.uniqueId] = viewItem;
        [viewItem clearNeedsUpdate];
        [viewItems addObject:viewItem];
        if(needMarkAsRead || needRefreshCard){
            [needRefreshIds addObject:viewItem.interaction.uniqueId];
        }
        
        return viewItem;
    };

    NSMutableSet<NSString *> *interactionIds = [NSMutableSet new];
    NSMutableArray<TSInteraction *> *interactions = [NSMutableArray new];

    for (TSInteraction *interaction in self.messageMapping.loadedInteractions) {
        if (!interaction.uniqueId) {
            OWSFailDebug(@"invalid interaction in message mapping: %@.", interaction);
            // TODO: Add analytics.
            hasError = YES;
            continue;
        }
        //MARK: reaction message不在列表显示
        if ([interaction isKindOfClass:[TSMessage class]]) {
            TSMessage *tmpMessage = (TSMessage *)interaction;
            if (tmpMessage.isReactionMessage) {
                continue;
            }
        }
        [interactions addObject:interaction];
        if ([interactionIds containsObject:interaction.uniqueId]) {
            OWSFailDebug(@"Duplicate interaction: %@", interaction.uniqueId);
            continue;
        }
        [interactionIds addObject:interaction.uniqueId];
    }

    BOOL hasPlacedUnreadIndicator = NO;
    for (TSInteraction *interaction in interactions) {
        if (!hasPlacedUnreadIndicator && 
            !self.hasClearedUnreadMessagesIndicator
            && self.messageMapping.oldestUnreadInteraction != nil
            && self.messageMapping.oldestUnreadInteraction.timestampForSorting <= interaction.timestampForSorting 
            && interaction.isNeedUnreadIndicator ) {
            hasPlacedUnreadIndicator = YES;
            OWSUnreadIndicatorInteraction *unreadIndicator =
                [[OWSUnreadIndicatorInteraction alloc] initWithThread:self.thread
                                                            timestamp:interaction.timestamp
                                                  receivedAtTimestamp:interaction.receivedAtTimestamp];
            tryToAddViewItem(unreadIndicator);
        }

        tryToAddViewItem(interaction);
    }

    if (self.unsavedOutgoingMessages.count > 0) {
        for (TSOutgoingMessage *outgoingMessage in self.unsavedOutgoingMessages) {
            if ([interactionIds containsObject:outgoingMessage.uniqueId]) {
                OWSFailDebug(@"Duplicate interaction: %@", outgoingMessage.uniqueId);
                continue;
            }
            tryToAddViewItem(outgoingMessage);
            [interactionIds addObject:outgoingMessage.uniqueId];
        }
    }

    // Flag to ensure that we only increment once per launch.
    if (hasError) {
        //MARK GRDB need to focus on
        OWSLogWarn(@"incrementing version of: %@", @"TSMessageDatabaseViewExtensionName");
    }

    // Update the "shouldShowDate" property
    BOOL shouldShowDateOnNextViewItem = YES;
    uint64_t previousViewItemTimestamp = 0;
    uint64_t collapseCutoffTimestamp = [NSDate ows_millisecondsSince1970ForDate:self.collapseCutoffDate];

    for (id<ConversationViewItem> viewItem in viewItems) {
        BOOL canShowDate = NO;
        switch (viewItem.interaction.interactionType) {
            case OWSInteractionType_Unknown:
            case OWSInteractionType_Offer:
                canShowDate = NO;
                break;
            case OWSInteractionType_Info: {
                // Only show the date for non-synced thread messages;
//                TSInfoMessage *infoMessage = (TSInfoMessage *)viewItem.interaction;
//                canShowDate = infoMessage.messageType != TSInfoMessageSyncedThread;
                canShowDate = NO;
                break;
            }
            case OWSInteractionType_UnreadIndicator:
            case OWSInteractionType_IncomingMessage:
            case OWSInteractionType_OutgoingMessage:
            case OWSInteractionType_Error:
                canShowDate = YES;
                break;
        }

        // 3.1.1 replace timestamp with timestampForSorting
        uint64_t viewItemTimestamp = viewItem.interaction.timestampForSorting;

        OWSAssertDebug(viewItemTimestamp > 0);
        BOOL shouldShowDate = NO;
        if (previousViewItemTimestamp == 0) {
            // Only show for the first item if the date is not today
            shouldShowDateOnNextViewItem
                = ![DateUtil dateIsToday:[NSDate ows_dateWithMillisecondsSince1970:viewItemTimestamp]];
        } else if (![DateUtil isSameDayWithTimestamp:previousViewItemTimestamp timestamp:viewItemTimestamp]) {
            shouldShowDateOnNextViewItem = YES;
        }

        if (shouldShowDateOnNextViewItem && canShowDate) {
            shouldShowDate = YES;
            shouldShowDateOnNextViewItem = NO;
        }

        viewItem.shouldShowDate = shouldShowDate;

        previousViewItemTimestamp = viewItemTimestamp;
    }

    // Update the properties of the view items.
    //
    // NOTE: This logic uses the break properties which are set in the previous pass.
    for (NSUInteger i = 0; i < viewItems.count; i++) {
        id<ConversationViewItem> viewItem = viewItems[i];
        id<ConversationViewItem> _Nullable previousViewItem = (i > 0 ? viewItems[i - 1] : nil);
        id<ConversationViewItem> _Nullable nextViewItem = (i + 1 < viewItems.count ? viewItems[i + 1] : nil);
        BOOL shouldShowSenderAvatar = NO;
        BOOL shouldHideFooter = NO;
        BOOL isFirstInCluster = YES;
        BOOL isLastInCluster = YES;
        NSAttributedString *_Nullable senderName = nil;
        NSString *_Nullable accessibilityAuthorName = nil;

        OWSInteractionType interactionType = viewItem.interaction.interactionType;
        NSString *timestampText = [DateUtil formatTimestampShort:viewItem.interaction.timestamp];

        if (interactionType == OWSInteractionType_OutgoingMessage) {

            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
            MessageReceiptStatus receiptStatus =
            [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage thread:self.thread transaction:transaction];
            BOOL isDisappearingMessage = outgoingMessage.hasPerConversationExpiration;
            accessibilityAuthorName = Localized(
                @"ACCESSIBILITY_LABEL_SENDER_SELF", @"Accessibility label for messages sent by you.");

            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                TSOutgoingMessage *nextOutgoingMessage = (TSOutgoingMessage *)nextViewItem.interaction;
                MessageReceiptStatus nextReceiptStatus =
                    [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:nextOutgoingMessage];
                NSString *nextTimestampText = [DateUtil formatTimestampShort:nextViewItem.interaction.timestamp];

                // We can skip the "outgoing message status" footer if the next message
                // has the same footer and no "date break" separates us...
                // ...but always show "failed to send" status
                // ...and always show the "disappearing messages" animation.
                shouldHideFooter
                    = ([timestampText isEqualToString:nextTimestampText] && receiptStatus == nextReceiptStatus
                        && outgoingMessage.messageState != TSOutgoingMessageStateFailed
                        && outgoingMessage.messageState != TSOutgoingMessageStateSending && !nextViewItem.hasCellHeader
                        && !isDisappearingMessage);
            }

            // clustering
            if (previousViewItem == nil) {
                isFirstInCluster = YES;
            } else if (viewItem.hasCellHeader) {
                isFirstInCluster = YES;
            } else {
                isFirstInCluster = previousViewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage;
            }

            if (nextViewItem == nil) {
                isLastInCluster = YES;
            } else if (nextViewItem.hasCellHeader) {
                isLastInCluster = YES;
            } else {
                isLastInCluster = nextViewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage;
            }
            
            if (previousViewItem && previousViewItem.interaction.interactionType == interactionType) {
                shouldShowSenderAvatar = viewItem.hasCellHeader;
            }else {
                shouldShowSenderAvatar = YES;
            }
        } else if (interactionType == OWSInteractionType_IncomingMessage) {

            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)viewItem.interaction;
//            SignalServiceAddress *incomingSenderAddress = incomingMessage.authorAddress;
//            OWSAssertDebug(incomingSenderAddress.isValid);
//            accessibilityAuthorName = [self.contactsManager displayNameForAddress:incomingSenderAddress
//                                                                      transaction:transaction];
            NSString *incomingSenderId = [incomingMessage messageAuthorId];
            BOOL isDisappearingMessage = incomingMessage.hasPerConversationExpiration;
            accessibilityAuthorName = [self.contactsManager displayNameForPhoneIdentifier:incomingSenderId transaction:transaction];
//            if (viewItem.interaction.interactionType == OWSInteractionType_ThreadDetails) {
//                viewItem.senderUsername = [self.profileManager usernameForAddress:incomingSenderAddress
//                                                                      transaction:transaction];
//            }

//            SignalServiceAddress *_Nullable nextIncomingSenderAddress = nil;
            NSString *_Nullable nextIncomingSenderId = nil;
            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                TSIncomingMessage *nextIncomingMessage = (TSIncomingMessage *)nextViewItem.interaction;
//                nextIncomingSenderAddress = nextIncomingMessage.authorAddress;
//                OWSAssertDebug(nextIncomingSenderAddress.isValid);
                nextIncomingSenderId = nextIncomingMessage.authorId;
            }

            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                NSString *nextTimestampText = [DateUtil formatTimestampShort:nextViewItem.interaction.timestamp];
                // We can skip the "incoming message status" footer in a cluster if the next message
                // has the same footer and no "date break" separates us.
                // ...but always show the "disappearing messages" animation.
                shouldHideFooter = ([timestampText isEqualToString:nextTimestampText] && !nextViewItem.hasCellHeader
                    && ((!incomingSenderId && !nextIncomingSenderId) ||
                        [incomingSenderId isEqualToString:nextIncomingSenderId])
                    && !isDisappearingMessage);
            }

            // clustering
            if (previousViewItem == nil) {
                isFirstInCluster = YES;
            } else if (viewItem.hasCellHeader) {
                isFirstInCluster = YES;
            } else if (previousViewItem.interaction.interactionType != OWSInteractionType_IncomingMessage) {
                isFirstInCluster = YES;
            } else {
                TSIncomingMessage *previousIncomingMessage = (TSIncomingMessage *)previousViewItem.interaction;
                isFirstInCluster = ![incomingSenderId isEqualToString:previousIncomingMessage.authorId];
            }

            if (nextViewItem == nil) {
                isLastInCluster = YES;
            } else if (nextViewItem.interaction.interactionType != OWSInteractionType_IncomingMessage) {
                isLastInCluster = YES;
            } else if (nextViewItem.hasCellHeader) {
                isLastInCluster = YES;
            } else {
                TSIncomingMessage *nextIncomingMessage = (TSIncomingMessage *)nextViewItem.interaction;
                isLastInCluster = ![incomingSenderId isEqualToString:nextIncomingMessage.authorId];
            }

            // 群组与单人会话保持一致
//            if (viewItem.isGroupThread) {
                // Show the sender name for incoming group messages unless
                // the previous message has the same sender name and
                // no "date break" separates us.
                BOOL shouldShowSenderName = YES;
                if (previousViewItem && previousViewItem.interaction.interactionType == interactionType) {

                    TSIncomingMessage *previousIncomingMessage = (TSIncomingMessage *)previousViewItem.interaction;
//                    SignalServiceAddress *previousIncomingSenderAddress = previousIncomingMessage.authorAddress;
//                    OWSAssertDebug(previousIncomingSenderAddress.isValid);
                    NSString *previousIncomingSenderId = previousIncomingMessage.authorId;
                    shouldShowSenderAvatar = (![NSObject isNullableObject:previousIncomingSenderId equalTo:incomingSenderId]|| viewItem.hasCellHeader);
                    shouldShowSenderName = ((!incomingSenderId && !previousIncomingSenderId)
                        || ![incomingSenderId isEqualToString:previousIncomingSenderId]
                        || viewItem.hasCellHeader);
                } else {
                    shouldShowSenderAvatar = YES;
                }
                if (shouldShowSenderName) {
                    if (SSKFeatureFlags.profileDisplayChanges) {
                        senderName = [[NSAttributedString alloc] initWithString:accessibilityAuthorName];
                    } else {
                        UIFont *font = UIFont.ows_dynamicTypeSubheadlineFont.ows_semibold;
                        UIColor *textColor = ConversationStyle.bubbleTextColorIncoming;
                        senderName = [self.contactsManager attributedContactOrProfileNameForPhoneIdentifier:incomingSenderId
                                                                                                primaryFont:font
                                                                                              secondaryFont:font.ows_italic
                                                                                           primaryTextColor:textColor
                                                                                         secondaryTextColor:textColor
                                                                                                transaction:transaction];
                    }
                }
            }
//        }

        if (viewItem.interaction.receivedAtTimestamp > collapseCutoffTimestamp) {
            shouldHideFooter = NO;
        }

        viewItem.isFirstInCluster = isFirstInCluster;
        viewItem.isLastInCluster = isLastInCluster;
        viewItem.shouldShowSenderAvatar = shouldShowSenderAvatar;
        viewItem.shouldHideFooter = shouldHideFooter;
        viewItem.senderName = senderName;
//        viewItem.accessibilityAuthorName = accessibilityAuthorName;
    }

    OWSLogInfo(@"==== reloadItems total rows: %ld ====", viewItems.count);
    
    ConversationViewState *viewState = [[ConversationViewState alloc] initWithViewItems:viewItems
                                                                         needRefreshIds:needRefreshIds
                                                                         focusMessageId:self.focusMessageIdOnOpen];
    
    ConversationReloadItemsResult *result = [[ConversationReloadItemsResult alloc] initWithHasError:hasError
                                                                                          viewState:viewState
                                                                                      viewItemCache:viewItemCache];

    return result;
}

- (void)buildViewItemWithInteraction:(TSInteraction *)interaction
                         transaction:(SDSAnyReadTransaction *)transaction
                          completion:(void(^)(__nullable id<ConversationViewItem>, BOOL needMarkAsRead, BOOL needRefreshCard))completion {
    OWSAssertDebug(interaction.uniqueId.length > 0);
    
    TSInteraction *freshInteraction = interaction;
    NSString *interactionUniqueId = freshInteraction.uniqueId;
    if (!DTParamsUtils.validateString(interactionUniqueId)) {
        OWSLogError(@"error: interaction.uniqueId = nil.");
        return completion(nil, NO, NO);
    }
    
    if ([freshInteraction isKindOfClass:[TSInfoMessage class]] &&
        ((TSInfoMessage *)freshInteraction).isRecalMessage) {
        return completion(nil, NO, NO);
    }
    
    id<ConversationViewItem> _Nullable viewItem = self.viewItemCache[interactionUniqueId];
    if (!viewItem) {
        viewItem = [[ConversationInteractionViewItem alloc] initWithInteraction:interaction
                                                                         thread:self.thread
                                                           conversationViewMode:self.conversationMode
                                                                    transaction:transaction
                                                              conversationStyle:self.delegate.conversationStyleForViewModel];
        
    }
    
    __block BOOL needMarkAsRead = NO;
    __block BOOL needRefreshCard = NO;
    
    if ([freshInteraction isKindOfClass:[TSMessage class]]) {
        
        TSMessage *freshMessage = (TSMessage *)freshInteraction;
        
        if (freshMessage.cardUniqueId.length) {
            DTCardMessageEntity *latestCard = [DTCardMessageEntity anyFetchWithUniqueId:freshMessage.cardUniqueId
                                                                            transaction:transaction];
            if(latestCard && latestCard.version > viewItem.card.version){
                viewItem.card = latestCard;
                viewItem.cardAttrString = nil;
                [viewItem clearCachedLayoutState];
                if([viewItem.interaction isKindOfClass:[TSMessage class]] &&
                   viewItem.card.version > ((TSMessage *)viewItem.interaction).translateMessage.cardVersion &&
                   ((TSMessage *)viewItem.interaction).translateMessage.translatedState.longValue == DTTranslateMessageStateTypeSucessed){
                    ((TSMessage *)viewItem.interaction).translateMessage = nil;
                }
                needRefreshCard = YES;
            }
        }
        
        if (freshMessage.reactionMap.count) {
            viewItem.emojiTitles = [DTReactionHelper emojiTitlesForMessage:freshMessage displayForBubble:YES transaction:transaction];
        }
        
        if ([freshMessage isKindOfClass:[TSOutgoingMessage class]]
            && !self.thread.isWithoutReadRecipt
            && self.recipientReadPositions.count) {
            TSOutgoingMessage *message = (TSOutgoingMessage *)viewItem.interaction;
            BOOL ignoreReadStatus = message.isConfidentialMessage && !self.thread.isGroupThread;
            if ([message isKindOfClass:[TSOutgoingMessage class]] && !ignoreReadStatus){
                //fix readstatus issue: The first time I received the group sync message, and the group members have not been synchronized to it.
                if (message.sourceDeviceId != [OWSDevice currentDeviceId] &&
                    message.recipientStateMap.count == 0) {
                    [message updateRecipientStateMapWithThread:self.thread state:OWSOutgoingMessageRecipientStateSent];
                }
                [self.recipientReadPositions enumerateObjectsUsingBlock:^(TSMessageReadPosition * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    TSOutgoingMessageRecipientState *oldRecipientState = message.recipientStateMap[obj.recipientId];
                    if(oldRecipientState &&
                       oldRecipientState.state == OWSOutgoingMessageRecipientStateSent &&
                       obj.maxServerTime >= message.timestampForSorting &&
                       oldRecipientState.readTimestamp == nil){
                        needMarkAsRead = YES;
                        [message updateWithReadRecipientId:obj.recipientId
                                             readTimestamp:obj.readAt
                                               transaction:transaction];
                    }
                }];
            }
        }
        
    }

    completion(viewItem, needMarkAsRead, needRefreshCard);
}

- (void)appendUnsavedOutgoingTextMessage:(TSOutgoingMessage *)outgoingMessage
{
    // Because the message isn't yet saved, we don't have sufficient information to build
    // in-memory placeholder for message types more complex than plain text.
    OWSAssertDebug(outgoingMessage.attachmentIds.count == 0);
    OWSAssertDebug(outgoingMessage.contactShare == nil);

    NSMutableArray<TSOutgoingMessage *> *unsavedOutgoingMessages = [self.unsavedOutgoingMessages mutableCopy];
    [unsavedOutgoingMessages addObject:outgoingMessage];
    self.unsavedOutgoingMessages = unsavedOutgoingMessages;

    [self updateForTransientItems];
}

// Whenever an interaction is modified, we need to reload it from the DB
// and update the corresponding view item.
- (void)reloadInteractionForViewItem:(id<ConversationViewItem>)viewItem transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);

    // This should never happen, but don't crash in production if we have a bug.
    if (!viewItem) {
        return;
    }

    TSInteraction *_Nullable interaction = [TSInteraction anyFetchWithUniqueId:viewItem.interaction.uniqueId transaction:transaction];

    if (!interaction) {
        OWSFailDebug(@"could not reload interaction");
    } else {
        [viewItem replaceInteraction:interaction transaction:transaction];
    }
}

- (void)ensureLoadWindowContainsQuotedReply:(OWSQuotedReplyModel *)quotedReply
                                transaction:(SDSAnyReadTransaction *)transaction
                                 completion:(nonnull void (^)(NSIndexPath * _Nullable))completion
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(quotedReply);
    OWSAssertDebug(quotedReply.timestamp > 0);
//    OWSAssertDebug(quotedReply.authorAddress.isValid);

    // TODO: 区分 local 和 remote
//    if (quotedReply.isRemotelySourced) {
//        return nil;
//    }

    TSInteraction *quotedInteraction = [ThreadUtil findInteractionInThreadByTimestamp:quotedReply.timestamp
                                                                             authorId:quotedReply.authorId
                                                                       threadUniqueId:self.thread.uniqueId
                                                                          transaction:transaction];

    if (!quotedInteraction) {
        completion(nil);
        return;
    }

    [self ensureLoadWindowContainsInteractionId:quotedInteraction.uniqueId transaction:transaction completion:completion];
}

- (void)ensureLoadWindowContainsInteractionId:(NSString *)interactionId
                                  transaction:(SDSAnyReadTransaction *)transaction
                                   completion:(nonnull void (^)(NSIndexPath * _Nullable))completion
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(interactionId);

    NSError *error;
    [self.messageMapping loadMessagePageAroundInteractionId:interactionId transaction:transaction error:&error];
    if (error != nil) {
        OWSFailDebug(@"failure: %@", error);
        completion(nil);
        return;
    }

    self.collapseCutoffDate = [NSDate new];

    if (![self reloadViewItemsWithTransaction:transaction]) {
        OWSFailDebug(@"failed to reload view items in resetMapping.");
    }

    [self.delegate conversationViewModelDidUpdateLoadMoreStatus];
    
    @weakify(self)
    [self.delegate conversationViewModelDidUpdate:ConversationUpdate.reloadUpdate transaction:transaction completion:^(BOOL isFinished) {
        @strongify(self)
        NSIndexPath *_Nullable indexPath = [self indexPathForInteractionId:interactionId];
        if (indexPath == nil) {
            OWSFailDebug(@"indexPath was unexpectedly nil");
        }
        completion(indexPath);
    }];
}

- (void)ensureLoadWindowContainsNewestItemsWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();

    NSError *error;
    [self.messageMapping loadNewestMessagePageWithTransaction:transaction error:&error];
    if (error != nil) {
        OWSFailDebug(@"failure: %@", error);
        return;
    }

    self.collapseCutoffDate = [NSDate new];

    if (![self reloadViewItemsWithTransaction:transaction]) {
        OWSFailDebug(@"failed to reload view items in resetMapping.");
    }

    [self.delegate conversationViewModelDidUpdateLoadMoreStatus];
    [self.delegate conversationViewModelDidUpdate:ConversationUpdate.reloadUpdate transaction:transaction completion:nil];
}

- (nullable TSInteraction *)firstCallOrMessageForLoadedInteractionsWithTransaction:(SDSAnyReadTransaction *)transaction
{
    for (TSInteraction *interaction in self.messageMapping.loadedInteractions) {
        switch (interaction.interactionType) {
            case OWSInteractionType_Unknown:
                OWSFailDebug(@"Unknown interaction type.");
                break;
            case OWSInteractionType_IncomingMessage:
            case OWSInteractionType_OutgoingMessage:
                return interaction;
            case OWSInteractionType_Error:
            case OWSInteractionType_Info:
                break;
            case OWSInteractionType_UnreadIndicator:
                break;
            case OWSInteractionType_Offer:
                break;
        }
    }
    return nil;
}

- (BOOL)shouldShowThreadDetails
{
    return !self.canLoadOlderItems;// && SSKFeatureFlags.messageRequest;
}

// MARK: - hot data

- (void)finishFetchInitialItems {
    [self.delegate conversationViewModelDidReset];
}

// MARK: - topic related

// 获取扩展表名字
- (NSString *)getDatabaseViewExtensionName {
    return [InteractionFinder messageDatabaseViewExtensionName];
}

// MARK: - Card

- (void)cleanCardCaches {
    [self.viewState.viewItems enumerateObjectsUsingBlock:^(id<ConversationViewItem>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.cardAttrString) {
            obj.cardAttrString = nil;
        }
    }];
}

@end

NS_ASSUME_NONNULL_END
