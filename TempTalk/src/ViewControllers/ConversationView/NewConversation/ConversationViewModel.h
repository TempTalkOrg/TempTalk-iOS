//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//


#import "ConversationItemMacro.h"

NS_ASSUME_NONNULL_BEGIN

@class ConversationStyle;
@class ConversationViewModel;
@class OWSQuotedReplyModel;
@class SDSAnyReadTransaction;
@class TSOutgoingMessage;
@class TSThread;
@class ConversationMessageMapping;
@class TSInteraction;
@class SDSAnyReadTransaction;

@protocol ConversationViewItem;

typedef NS_ENUM(NSUInteger, ConversationUpdateType) {
    // No view items in the load window were effected.
    ConversationUpdateType_Minor,
    // A subset of view items in the load window were effected;
    // the view should be updated using the update items.
    ConversationUpdateType_Diff,
    // Complicated or unexpected changes occurred in the load window;
    // the view should be reloaded.
    ConversationUpdateType_Reload,
};

#pragma mark -

typedef NS_ENUM(NSUInteger, ConversationUpdateItemType) {
    ConversationUpdateItemType_Insert,
    ConversationUpdateItemType_Delete,
    ConversationUpdateItemType_Update,
};

#pragma mark -

@interface ConversationViewState : NSObject

@property (nonatomic, readonly) NSArray<id<ConversationViewItem>> *viewItems;
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *interactionIndexMap;
// We have to track interactionIds separately.  We can't just use interactionIndexMap.allKeys,
// as that won't preserve ordering.
@property (nonatomic, readonly) NSArray<NSString *> *interactionIds;
//已读消息ids add by Kris
@property (nonatomic, readonly) NSArray<NSString *> *needRefreshIds;
@property (nonatomic, readonly, nullable) NSNumber *unreadIndicatorIndex;
@property (nonatomic, readonly, nullable) NSNumber *focusItemIndex;

// 方便根据 uniqueId 查找对应的 viewItem (时间复杂度 O(n))
@property (nonatomic, readonly) NSDictionary<NSString *, id<ConversationViewItem>> *viewItemsMap;

@end

#pragma mark -

@interface ConversationUpdateItem : NSObject

@property (nonatomic, readonly) ConversationUpdateItemType updateItemType;
// Only applies in the "delete" and "update" cases.
@property (nonatomic, readonly) NSUInteger oldIndex;
// Only applies in the "insert" and "update" cases.
@property (nonatomic, readonly) NSUInteger newIndex;
// Only applies in the "insert" and "update" cases.
@property (nonatomic, readonly, nullable) id<ConversationViewItem> viewItem;

@end

#pragma mark -

@interface ConversationUpdate : NSObject

@property (nonatomic, readonly) ConversationUpdateType conversationUpdateType;
// Only applies in the "diff" case.
@property (nonatomic, readonly, nullable) NSArray<ConversationUpdateItem *> *updateItems;
// Only applies in the "diff" case.
@property (nonatomic, assign) BOOL shouldAnimateUpdates;
// 完成 ConversationUpdate 更新后，是否忽略滚到指定位置
@property (nonatomic, assign) BOOL ignoreScrollToDefaultPosition;

+ (ConversationUpdate *)reloadUpdate;

@end

#pragma mark -

@protocol ConversationViewModelDelegate <NSObject>

- (void)conversationViewModelDidUpdate:(ConversationUpdate *)conversationUpdate
                           transaction:(nullable SDSAnyReadTransaction *)transaction
                            completion:(void (^ __nullable)(BOOL))completion;

- (void)conversationViewModelWillLoadMoreItems;
- (void)conversationViewModelDidLoadMoreItems;
- (void)conversationViewModelDidUpdateLoadMoreStatus;

- (void)conversationViewModelUpdatePin;

// Called after the view model recovers from a severe error
// to prod the view to reset its scroll state, etc.
- (void)conversationViewModelDidReset;

- (ConversationStyle *)conversationStyleForViewModel;

@end

#pragma mark -

@interface ConversationViewModel : NSObject

@property (nonatomic, readonly) ConversationViewState *viewState;
@property (nonatomic, nullable) NSString *focusMessageIdOnOpen;
@property (nonatomic, readonly) ConversationViewMode conversationMode;

@property (nonatomic, readonly) ConversationMessageMapping *messageMapping;
@property (nonatomic, readonly) id<ConversationViewItem> botViewItem;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithThread:(TSThread *)thread
          focusMessageIdOnOpen:(nullable NSString *)focusMessageIdOnOpen
          conversationViewMode:(ConversationViewMode)conversationViewMode
                   botViewItem:(nullable id<ConversationViewItem>)botViewItem NS_DESIGNATED_INITIALIZER;

- (void)configWithDelegate:(id<ConversationViewModelDelegate>)delegate;

- (void)clearUnreadMessagesIndicator;

- (nullable NSIndexPath *)indexPathForViewItem:(id<ConversationViewItem>)viewItem;

- (void)viewDidResetContentAndLayoutWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)viewDidLoad;

- (BOOL)canLoadOlderItems;
- (BOOL)canLoadNewerItems;
- (BOOL)canFetchOlderItems;
- (BOOL)canFetchNewerItems;
- (void)appendOlderItemsWithTransaction:(SDSAnyReadTransaction *)transaction;
- (void)appendNewerItemsWithTransaction:(SDSAnyReadTransaction *)transaction;

// hot data reload
//- (BOOL)reloadViewItemsWithTransaction:(SDSAnyReadTransaction *)transaction;
//- (void)conversationViewModelRangeDidChangeWithTransaction:(SDSAnyReadTransaction *)transaction;
- (void)finishFetchInitialItems;
- (void)resetMappingWithSneakyTransaction;
//- (void)resetMappingWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)ensureLoadWindowContainsQuotedReply:(OWSQuotedReplyModel *)quotedReply
                                transaction:(SDSAnyReadTransaction *)transaction
                                 completion:(void (^)(NSIndexPath * _Nullable))completion;

- (void)ensureLoadWindowContainsInteractionId:(NSString *)interactionId
                                  transaction:(SDSAnyReadTransaction *)transaction
                                   completion:(void (^)(NSIndexPath * _Nullable))completion;

- (void)ensureLoadWindowContainsNewestItemsWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)appendUnsavedOutgoingTextMessage:(TSOutgoingMessage *)outgoingMessage;

- (void)buildViewItemWithInteraction:(TSInteraction *)interaction
                         transaction:(SDSAnyReadTransaction *)transaction
                          completion:(void(^)(__nullable id<ConversationViewItem>, BOOL needMarkAsRead, BOOL needRefreshCard))completion;

- (void)cleanCardCaches;

@end

NS_ASSUME_NONNULL_END
