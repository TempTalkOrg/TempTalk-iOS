//
//  DTTHreadHelper.h
//  Wea
//
//  Created by hornet on 2022/4/27.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>
@class TSThread;
@class DTChatFolderEntity;
NS_ASSUME_NONNULL_BEGIN

@protocol DTThreadHelperDelegate <NSObject>

- (void)unreadCountCacheChanged;

@end

typedef void(^LoadUnreadThreadCompletionBlock)(NSInteger allUnMutedUnreadCount);

@interface DTThreadHelper : NSObject

@property (nonatomic, weak) id<DTThreadHelperDelegate> delegate;

//muted和unmuted的集合
@property (nonatomic, strong, readonly) NSArray <TSThread *> *allUnReadThreadArr;
@property (nonatomic, strong, readonly) NSArray <TSThread *> *allUnMutedThreadArr;//会根据folder变化
@property (nonatomic, strong, readonly) NSArray <TSThread *> *allMutedThreadArr;//会根据folder变化
//所有包含未读且没有mute的thread集合
@property (nonatomic, strong, readonly) NSMutableArray <TSThread *> *unMutedThreadArr;//全部中的
//所有包含未读且mute的thread集合
@property (nonatomic, strong, readonly) NSMutableArray <TSThread *> *mutedThreadArr;//全部中的
/// 所有未muted的未读消息数
@property (nonatomic, assign, readonly) NSUInteger allUnMutedUnreadCount;
/// 所有muted的的未读的消息总数
@property (nonatomic, assign, readonly) NSUInteger allMutedUnReadCount;

/// 未读消息总数 
@property (nonatomic, assign, readonly) NSUInteger allUnreadCount;
//未读会话缓存
@property (nonatomic, strong, readonly) NSDictionary <NSString *, NSNumber *> *unreadThreadCache;

@property (nonatomic, strong, nullable) NSArray <NSString *> *folderThreadUniqueIds;

+ (instancetype)sharedManager;
- (void)observerAllUnReadMessageCount;
- (void)loadUnReadThread;
- (void)syncLoadUnReadThreadForNSEWithCompletion:(nonnull LoadUnreadThreadCompletionBlock)completion;
@end

NS_ASSUME_NONNULL_END
