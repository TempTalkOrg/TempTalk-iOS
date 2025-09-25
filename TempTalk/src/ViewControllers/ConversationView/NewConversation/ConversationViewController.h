//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <SignalMessaging/OWSViewController.h>
#import <SignalMessaging/ThreadUtil.h>
#import "ConversationItemMacro.h"

@class ConversationViewItem;
@class OWSMessageSender;
@class SignalAttachment;
@class YapDatabaseViewMappings;
@class ConversationCollectionView;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ConversationViewAction) {
    ConversationViewActionNone,
    ConversationViewActionCompose,
    ConversationViewActionAudioCall,
    ConversationViewActionVideoCall,
};



@class TSThread;

@interface ConversationViewController : OWSViewController

@property (nonatomic, readonly) TSThread *thread;

@property (nonatomic, readonly) NSArray<ConversationViewItem *> *viewItems;

- (void)configureForThread:(TSThread *)thread
                    action:(ConversationViewAction)action
            focusMessageId:(nullable NSString *)focusMessageId;

- (nullable NSNumber *)findGroupIndexOfThreadInteraction:(TSInteraction *)interaction
                                             transaction:(YapDatabaseReadTransaction *)transaction;

- (void)loadNMoreMessages:(NSUInteger)numberOfMessagesToLoad;

- (void)configureForThread:(TSThread *)thread
                    action:(ConversationViewAction)action
            focusMessageId:(nullable NSString *)focusMessageId
                 viewModel:(ConversationViewMode) viewMode;

- (void)popKeyBoard;

#pragma mark 3D Touch Methods

- (void)peekSetup;
- (void)popped;


@property (nonatomic, readonly) YapDatabaseConnection *uiDatabaseConnection;
@property (nonatomic, readonly) YapDatabaseViewMappings *messageMappings;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ConversationCollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray <ConversationViewItem *> *forwardMessageItems;
@property (nonatomic, readonly) BOOL isMultiSelectMode;
@property(nonatomic,strong) ConversationViewItem *botViewItem;

@property (nonatomic, readonly) NSString *serverGroupId;

- (void)sendMessageAttachment:(SignalAttachment *)attachment targetThread:(nullable TSThread *)targetThread completion:(nullable void(^)(void))completion;
- (void)cancelMultiSelectMode;

- (BOOL)recipientsContainsBot;

- (void)updateThreadFiltering;

@end

NS_ASSUME_NONNULL_END

