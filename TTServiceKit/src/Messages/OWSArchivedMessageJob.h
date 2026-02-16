//
//  OWSArchivedMessageJob.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/16.
//

#import <Foundation/Foundation.h>

@class TSMessage;
@class TSThread;
@class SDSAnyWriteTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface OWSArchivedMessageJob : NSObject

@property (nonatomic, assign) BOOL inConversation;

+ (instancetype)sharedJob;

- (void)startIfNecessary;

- (void)archiveMessage:(TSMessage *)message;

- (void)archiveMessage:(TSMessage *)message transaction:(SDSAnyWriteTransaction *)transaction;

- (void)fallbackTimerDidFire;

/// 离开会话页面时调用，延迟触发归档检查
- (void)triggerArchiveCheckAfterLeavingConversation;

/// 立即触发归档检查（用于特定场景，如 App 进入后台前）
- (void)triggerArchiveCheckImmediately;

/// 清理空的thread（只有归档消息或创建时间超过归档时间的空会话）
- (void)cleanupEmptyThreadsIfNeeded;

- (void)fixThreadsWithZeroExpiresInSecondsOnce;

- (void)resetLastTimeStampAsync;

@end

NS_ASSUME_NONNULL_END
