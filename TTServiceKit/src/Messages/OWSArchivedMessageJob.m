//
//  OWSArchivedMessageJob.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/16.
//

#import "OWSArchivedMessageJob.h"
#import "AppReadiness.h"
#import "DTFetchThreadConfigAPI.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSTimer+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

static const CGFloat kArchivedMessageFrequency = 0.05;
static const NSUInteger kArchivedMessageBatchSize = 30;

@interface OWSArchivedMessageJob ()

@property (nonatomic, assign) NSTimeInterval lastTimeStamp;
@property (nonatomic, assign) BOOL didRunInitialFix;
@property (nonatomic, nullable) NSTimer *fallbackTimer;
@property (nonatomic, strong) AnyMessageReadPositonFinder *finder;
@property (nonatomic, assign) BOOL isArchivingInProgress;
@property (nonatomic, assign) BOOL needsRetrigger;
@property (nonatomic, strong) dispatch_queue_t triggerQueue;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@end

@implementation OWSArchivedMessageJob

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];

    self.finder = [[AnyMessageReadPositonFinder alloc] init];
    self.isArchivingInProgress = NO;
    self.needsRetrigger = NO;
    self.triggerQueue = dispatch_queue_create("org.dt.archived.trigger", DISPATCH_QUEUE_SERIAL);
    self.stateQueue = dispatch_queue_create("org.dt.archived.state", DISPATCH_QUEUE_SERIAL);

    return self;
}

+ (instancetype)sharedJob
{
    static OWSArchivedMessageJob *sharedJob = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedJob = [[self alloc] init];
    });
    return sharedJob;
}

+ (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("org.dt.archived.messages", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)applicationDidBecomeActive:(NSNotification *)notify{

    OWSAssertIsOnMainThread();

    [self startIfNecessary];
}

- (void)applicationWillResignActive:(NSNotification *)notify{
    
    OWSAssertIsOnMainThread();
    
    [self stop];
}

- (void)startIfNecessary{
    // suspenders in case a deletion schedule is missed.
    NSTimeInterval kFallBackTimerInterval = 5 * kMinuteInterval;
    if(!TSConstants.isUsingProductionService){
        kFallBackTimerInterval = 1 * kMinuteInterval;
    }
    
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if (CurrentAppContext().isMainApp) {
            [self stop];
            self.fallbackTimer = [NSTimer weakScheduledTimerWithTimeInterval:kFallBackTimerInterval
                                                                      target:self
                                                                    selector:@selector(fallbackTimerDidFire)
                                                                    userInfo:nil
                                                                     repeats:YES];
            [self.fallbackTimer fire];
        }
    });

}

- (void)stop{
    [self.fallbackTimer invalidate];
    self.fallbackTimer = nil;
}

- (BOOL)shouldHandelMessages{

    if (!CurrentAppContext().isMainApp) {
        OWSLogError(@"%@ shouldHandelMessages isMainApp error", self.logTag);
        return NO;
    }

    if (!CurrentAppContext().isAppForegroundAndActive) {
        OWSLogError(@"%@ shouldHandelMessages isAppForegroundAndActive error", self.logTag);
        return NO;
    }

    if (CurrentAppContext().isInMeeting) {
        OWSLogError(@"%@ shouldHandelMessages isInMeeting error", self.logTag);
        return NO;
    }

    NSTimeInterval current = CACurrentMediaTime();

    if (self.inConversation) {
        if (current - [self getLastTimeStamp] < 5 * kMinuteInterval) {
            OWSLogError(@"%@ shouldHandelMessages inConversation error", self.logTag);
            return NO;
        }
        return YES;
    }

    NSTimeInterval minInterval = TSConstants.isUsingProductionService ? 30 : 10;
    if (current - [self getLastTimeStamp] < minInterval) {
        OWSLogError(@"%@ shouldHandelMessages getLastTimeStamp error", self.logTag);
        return NO;
    }

    return YES;
}

- (void)slowlyArchiveMessages:(NSMutableArray<TSMessage *> *)messages
                    batchSize:(NSUInteger)batchSize
                   completion:(void (^)(void))completion{
    
    dispatch_async([[self class] serialQueue], ^{
        
        if(messages.count <= 0 || ![self shouldHandelMessages]){
            if(completion){
                completion();
            }
            return;
        }
        
        __block NSUInteger loopBatchIndex = 0;
        [BenchManager benchWithTitle:@"slowlyArchiveMessages" block:^{
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                NSMutableSet<NSString *> *archivedThreadIds = [NSMutableSet set];
                [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                    TSMessage *lastMessage = messages.lastObject;
                    if (loopBatchIndex == batchSize || lastMessage == nil || ![self shouldHandelMessages]) {
                        *stop = YES;
                        return;
                    }
                    
                    [self archiveMessage:lastMessage transaction:writeTransaction];
                    [archivedThreadIds addObject:lastMessage.uniqueThreadId];
                    OWSLogInfo(@"archive message timestamp for sorting: %llu", lastMessage.timestampForSorting);
                    [messages removeLastObject];
                    loopBatchIndex += 1;
                }];
                
                [writeTransaction addAsyncCompletionOnMain:^{
                    [self dealThreadDataWithArchivedThreadIds:archivedThreadIds];
                }];
            });
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kArchivedMessageFrequency * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self slowlyArchiveMessages:messages batchSize:batchSize completion:completion];
        });
        
    });
    
}

- (void)dealThreadDataWithArchivedThreadIds:(NSMutableSet<NSString *> *)archivedThreadIds {
    if (archivedThreadIds.count == 0) {
        return;
    }

    OWSLogInfo(@"[Archive] processing %lu threads after message archiving", (unsigned long)archivedThreadIds.count);

    // 使用异步写操作，避免在主线程上阻塞
    // 这个方法由 addAsyncCompletionOnMain 调用，已经在主线程上
    // 如果使用 DatabaseStorageWrite 会导致主线程卡顿
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        // Track which threads already have the system message to avoid duplicates
        NSMutableSet<NSString *> *threadsWithSystemMessage = [NSMutableSet set];

        for (NSString *threadId in archivedThreadIds) {
            TSThread *thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
            if (!thread) {
                OWSLogWarn(@"[Archive] thread not found: %@", threadId);
                continue;
            }

            // 更新会话的归档状态
            [thread anyUpdateWithTransaction:transaction block:^(TSThread * _Nonnull t) {
                [t updateArchiveStateWithTransaction:transaction];
            }];

            if (![threadsWithSystemMessage containsObject:threadId]) {
                [self genrateSystemMessageWithThread:thread transaction:transaction];
                [threadsWithSystemMessage addObject:threadId];
            }
        }
    });
}

- (void)genrateSystemMessageWithThread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction {
    NSString *threadID = [TSContactThread threadIdFromContactId:TSAccountManager.localNumber];
    if ([thread.uniqueId isEqualToString:threadID]) {
        // 备忘录不会生成系统消息
        return;
    }

    DTThreadConfigEntity *threadConfig = thread.threadConfig;
    if (threadConfig && threadConfig.endTimestamp > 0) {
        uint64_t creationTimestamp = (uint64_t)([thread.creationDate timeIntervalSince1970] * 1000);
        if (creationTimestamp > threadConfig.endTimestamp) {
            OWSLogInfo(@"[Archive] Skipping system message for recreated thread: %@ (creationDate %llu > endTimestamp %llu)",
                       thread.uniqueId, creationTimestamp, threadConfig.endTimestamp);
            return;
        }
    }

    // 使用高效的 SQL SELECT EXISTS 查询检查是否已存在 TSInfoMessageArchiveMessage
    InteractionFinder *finder = [[InteractionFinder alloc] initWithThreadUniqueId:thread.uniqueId];
    if ([finder existsArchiveMessageWithTransaction:transaction]) {
        OWSLogDebug(@"[Archive] system message already exists for thread %@, skipping", thread.uniqueId);
        return;
    }

    uint64_t finalTimestamp = (uint64_t)([thread.creationDate timeIntervalSince1970] * 1000);
    if (finalTimestamp <= 0) {
        return;
    }

    // 创建新的系统消息
    TSInfoMessage *info = [[TSInfoMessage alloc] initWithTimestamp:finalTimestamp
                                                          inThread:thread
                                                       messageType:TSInfoMessageArchiveMessage
                                                     customMessage:Localized(@"EXPIRE_SYSTEM_MESSAGE",
                                                                                                                                                                               @"Message for the 'app launch failed' alert.")];
    [info anyInsertWithTransaction:transaction];
}


- (void)fallbackTimerDidFire {

    if (![self shouldHandelMessages]) return;
    
    OWSLogInfo(@"%@ OWSArchivedMessageJob fallbackTimerDidFire", self.logTag);

    dispatch_async([[self class] serialQueue], ^{

        __block OWSBackgroundTask *_Nullable backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:"archivedMessages"];
        NSMutableArray *archivedMessages = @[].mutableCopy;
        NSMutableArray *archivedMessageIds = @[].mutableCopy;
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        NSString *receipt = [TSAccountManager localNumber];

        [BenchManager benchWithTitle:@"enumerateNeedArchivedInteractionsWithNow" block:^{
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * readTransaction) {
                __block NSError *error;
                [self.finder enumerateNeedArchivedInteractionsWithNow:now
                                                              receipt:receipt
                                                          transaction:readTransaction
                                                                error:&error
                                                                block:^(TSInteraction * interaction, BOOL * stop) {
                    // Skip TSInfoMessageArchiveMessage system messages
                    if ([interaction isKindOfClass:[TSInfoMessage class]]) {
                        TSInfoMessage *infoMessage = (TSInfoMessage *)interaction;
                        if (infoMessage.messageType == TSInfoMessageArchiveMessage) {
                            return;
                        }
                    }

                    [archivedMessages addObject:interaction];
                    [archivedMessageIds addObject:interaction.uniqueId];

                    if (self.inConversation) {
                        *stop = YES;
                        return;
                    }
                }];

                if(error){
                    NSString *errorInfo = [NSString stringWithFormat:@"enumerateNeedArchivedInteractions error:%@", error.description];
                    OWSProdFail(errorInfo);
                }
            }];
        }];

        NSUInteger count = archivedMessages.count;
        if(count > 0){
            OWSLogInfo(@"[Archive] begin archiving %lu messages", (unsigned long)count);
            [self slowlyArchiveMessages:archivedMessages
                              batchSize:kArchivedMessageBatchSize
                             completion:^{
                OWSLogInfo(@"[Archive] archived %lu messages completed", (unsigned long)count);
                [self setLastTimeStamp:CACurrentMediaTime()];
                backgroundTask = nil;

                // 在 triggerQueue 上检查是否需要重新触发，并提交到主线程
                [self finishArchivingAndCheckForRetrigger];
            }];
        } else {
            [self setLastTimeStamp:CACurrentMediaTime()];
            backgroundTask = nil;

            // 在 triggerQueue 上检查是否需要重新触发，并提交到主线程
            [self finishArchivingAndCheckForRetrigger];
        }
    });
}

/// 完成归档操作并检查是否需要重新触发
/// 这个方法统一处理 retrigger 逻辑，避免代码重复和竞态条件
- (void)finishArchivingAndCheckForRetrigger {
    // 修复：使用 dispatch_async 替代 dispatch_sync，避免在主线程上的死锁
    // 状态更新异步进行，但由于是 serial queue，顺序仍然有保证
    dispatch_async(self.triggerQueue, ^{
        self.isArchivingInProgress = NO;

        // 如果期间有新的触发请求，自动执行重新检查
        if (self.needsRetrigger) {
            self.needsRetrigger = NO;
            self.isArchivingInProgress = YES;

            OWSLogInfo(@"[Archive] retrigger archive check");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self fallbackTimerDidFire];
            });
        }
    });
}

- (void)archiveMessage:(TSMessage *)message {

    DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *transaction) {
        [self archiveMessage:message transaction:transaction];
    }));

}

- (void)archiveMessage:(TSMessage *)message transaction:(SDSAnyWriteTransaction *)transaction {
    [message anyRemoveWithTransaction:transaction];
}

- (void)triggerArchiveCheckAfterLeavingConversation {
    // 延迟0.5秒后触发，确保会话页面完全关闭
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 重置 lastTimeStamp 以允许立即执行归档检查
        // 修复：使用异步版本避免阻塞主线程
        [self resetLastTimeStampAsync];
        [self fallbackTimerDidFire];
    });
}

- (void)triggerArchiveCheckImmediately {
    // 修复：使用 dispatch_async 替代 dispatch_sync，避免在主线程上阻塞导致死锁
    // serial queue 保证操作的顺序性，async 保证不会阻塞主线程
    dispatch_async(self.triggerQueue, ^{
        if (self.isArchivingInProgress) {
            // 如果当前正在执行归档，标记为需要重新检查
            // 待归档完成后，会自动再次执行检查
            self.needsRetrigger = YES;
            OWSLogDebug(@"[Archive] Archiving in progress, marked for retrigger");
            return;
        }

        // 标记为正在执行
        self.isArchivingInProgress = YES;
        self.needsRetrigger = NO;
        [self resetLastTimeStampAsync];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self fallbackTimerDidFire];
        });
    });
}

// TODO: 过几个版本清理掉（兼容老的历史逻辑WHERE expiresInSeconds > 0）
#pragma mark - Fix Zero ExpiresInSeconds
- (void)fixThreadsWithZeroExpiresInSecondsOnce {
    // 只在第一次执行，避免重复修复
    if (self.didRunInitialFix) {
        OWSLogInfo(@"[Archive] Skipping one-time fix - already executed");
        return;
    }

    self.didRunInitialFix = YES;
    OWSLogInfo(@"[Archive] Running one-time fix for threads with expiresInSeconds = 0");

    dispatch_async([[self class] serialQueue], ^{
        // Process in batches to avoid blocking for too long
        NSUInteger totalFixed = 0;
        NSUInteger batchSize = 100;
        NSUInteger maxIterations = 1000;  // 防止无限循环：最多迭代 1000 次
        NSUInteger iterations = 0;
        __block BOOL hasMore = YES;

        while (hasMore && iterations < maxIterations) {
            iterations++;
            __block NSUInteger batchFixed = 0;

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                AnyThreadFinder *threadFinder = [[AnyThreadFinder alloc] init];
                NSError *error = nil;
                NSArray<TSThread *> *threads = [threadFinder fetchThreadsWithZeroExpiresInSecondsWithLimit:batchSize
                                                                                                transaction:transaction
                                                                                                      error:&error];

                if (error) {
                    OWSFailDebug(@"[Archive] failed to fetch threads with zero expiresInSeconds: %@", error);
                    hasMore = NO;
                    return;
                }

                if (!threads || threads.count == 0) {
                    hasMore = NO;
                    return;
                }

                OWSLogInfo(@"[Archive] fixing batch of %lu threads with expiresInSeconds = 0", (unsigned long)threads.count);

                for (TSThread *thread in threads) {
                    uint32_t defaultExpiry = [thread messageExpiresInSecondsWithTransaction:transaction];

                    if (defaultExpiry > 0) {
                        [thread anyUpdateWithTransaction:transaction block:^(TSThread *t) {
                            t.expiresInSeconds = defaultExpiry;
                        }];
                        batchFixed++;
                    } else {
                        OWSLogWarn(@"[Archive] thread %@ has default expiresInSeconds = 0, skipping", thread.uniqueId);
                    }
                }
            });

            totalFixed += batchFixed;

            // If we got fewer threads than batch size, we're done
            if (batchFixed < batchSize) {
                hasMore = NO;
            }
        }

        if (iterations >= maxIterations) {
            OWSFailDebug(@"[Archive] one-time fix exceeded max iterations (%lu), possible infinite loop", (unsigned long)maxIterations);
        }

        if (totalFixed > 0) {
            OWSLogInfo(@"[Archive] one-time fix completed: fixed %lu threads total in %lu iterations", (unsigned long)totalFixed, (unsigned long)iterations);
        } else {
            OWSLogInfo(@"[Archive] one-time fix completed: no threads needed fixing");
        }
    });
}

#pragma mark - Cleanup Empty Threads

static NSString *const kOrphanCleanupDoneKey = @"kOrphanCleanupDone";
static NSString *const kArchivedJobStoreCollection = @"OWSArchivedMessageJob";

+ (SDSKeyValueStore *)keyValueStore
{
    static SDSKeyValueStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[SDSKeyValueStore alloc] initWithCollection:kArchivedJobStoreCollection];
    });
    return store;
}

- (void)cleanupEmptyThreadsIfNeeded {
    OWSLogInfo(@"[Archive] Starting cleanup of empty threads");

    dispatch_async([[self class] serialQueue], ^{
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            // 1. Cleanup empty visible threads
            [TSThread cleanupEmptyVisibleThreadsWithTransaction:transaction];

            // 2. Cleanup threads where user has been kicked from group
            [self cleanupKickedGroupThreadsWithTransaction:transaction];

            // 3. Once-ever: cleanup orphan threads (shouldBeVisible=0, no messages or only archive message)
            BOOL alreadyDone = [[OWSArchivedMessageJob keyValueStore] getBool:kOrphanCleanupDoneKey
                                                                defaultValue:NO
                                                                 transaction:transaction];
            if (!alreadyDone) {
                [TSThread cleanupOrphanThreadsWithTransaction:transaction];
                [[OWSArchivedMessageJob keyValueStore] setBool:YES key:kOrphanCleanupDoneKey transaction:transaction];
            }
        });

        OWSLogInfo(@"[Archive] Cleanup of empty threads completed");
    });
}

- (void)cleanupKickedGroupThreadsWithTransaction:(SDSAnyWriteTransaction *)transaction {
    OWSLogInfo(@"[Archive] Starting cleanup of kicked group threads");

    NSMutableArray<NSString *> *threadsToDelete = [NSMutableArray new];
    AnyThreadFinder *threadFinder = [[AnyThreadFinder alloc] init];

    // 使用 ThreadFinder 获取所有可见的 threads
    NSError *error = nil;
    [threadFinder enumerateVisibleThreadsWithIsArchived:NO transaction:transaction error:&error block:^(TSThread *thread) {
        // 检查是否是群组且用户被踢出
        if ([thread isKindOfClass:[TSGroupThread class]]) {
            TSGroupThread *groupThread = (TSGroupThread *)thread;
            if (![groupThread isLocalUserInGroupWithTransaction:transaction]) {
                OWSLogInfo(@"[Archive] Found thread for kicked user: %@", groupThread.uniqueId);
                [threadsToDelete addObject:groupThread.uniqueId];
            }
        }
    }];

    if (error) {
        OWSLogError(@"[Archive] Error enumerating threads: %@", error);
        return;
    }

    // 删除收集到的 threads
    for (NSString *threadId in threadsToDelete) {
        TSThread *thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
        if (thread) {
            OWSLogInfo(@"[Archive] Deleting thread for kicked user: %@", threadId);
            [thread anyRemoveWithTransaction:transaction];
        }
    }

    OWSLogInfo(@"[Archive] Deleted %lu threads for kicked users", (unsigned long)threadsToDelete.count);
}

#pragma mark - Thread-Safe Timestamp Access

/// 线程安全地获取 lastTimeStamp
- (NSTimeInterval)getLastTimeStamp {
    __block NSTimeInterval timestamp = 0;
    dispatch_sync(self.stateQueue, ^{
        timestamp = self->_lastTimeStamp;
    });
    return timestamp;
}

/// 线程安全地设置 lastTimeStamp
- (void)setLastTimeStamp:(NSTimeInterval)timestamp {
    dispatch_async(self.stateQueue, ^{
        self->_lastTimeStamp = timestamp;
    });
}

/// 线程安全地重置 lastTimeStamp 为 0（同步）
- (void)resetLastTimeStampSync {
    dispatch_sync(self.stateQueue, ^{
        self->_lastTimeStamp = 0;
    });
}

/// 线程安全地重置 lastTimeStamp 为 0（异步）
- (void)resetLastTimeStampAsync {
    dispatch_async(self.stateQueue, ^{
        self->_lastTimeStamp = 0;
    });
}

@end
