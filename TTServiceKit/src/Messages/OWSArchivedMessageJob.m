//
//  OWSArchivedMessageJob.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/16.
//

#import "OWSArchivedMessageJob.h"
#import "AppReadiness.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSTimer+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

static const CGFloat kArchivedMessageFrequency = 0.05;
static const NSUInteger kArchivedMessageBatchSize = 30;

@interface OWSArchivedMessageJob ()

@property (nonatomic, assign) NSTimeInterval lastTimeStamp;
@property (nonatomic, nullable) NSTimer *fallbackTimer;
@property (nonatomic, strong) AnyMessageReadPositonFinder *finder;
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
    
    if (![self shouldHandelMessages]) return;
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
        return NO;
    }
    
    if (!CurrentAppContext().isAppForegroundAndActive) {
        return NO;
    }
    
    if (self.inConversation) {
        return NO;
    }
    
    if (CurrentAppContext().isInMeeting) {
        return NO;
    }
    
    NSTimeInterval current = CACurrentMediaTime();
    if(TSConstants.isUsingProductionService){
        // TODO: 避免频繁调用
//        if(current - self.lastTimeStamp < kHourInterval){
//            return NO;
//        }
    } else {
        if(current - self.lastTimeStamp < 1 * kMinuteInterval){
            return NO;
        }
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
    for (NSString *threadId in archivedThreadIds) {
        __block TSThread *thread = nil;
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            thread = [TSThread anyFetchWithUniqueId:threadId transaction:readTransaction];
            if (!thread) return;
        } completion:^{
            [self genrateSystemMessageWithThread:thread];
        }];
    }
}

- (void)genrateSystemMessageWithThread:(TSThread *)thread {
    NSString *threadID = [TSContactThread threadIdFromContactId:TSAccountManager.localNumber];
    if ([thread.uniqueId isEqualToString:threadID]) {
        // 备忘录不会生成系统消息
        return;
    }

    uint64_t finalTimestamp = (uint64_t)([thread.creationDate timeIntervalSince1970] * 1000);
    OWSLogInfo(@"%@ generate sysytem message finalTimestamp %llu", self.logTag, finalTimestamp);
    
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *updateTransaction) {
        if (finalTimestamp > 0) {
            TSInfoMessage *info = [[TSInfoMessage alloc] initWithTimestamp:finalTimestamp
                                                                  inThread:thread
                                                               messageType:TSInfoMessageArchiveMessage
                                                             customMessage:Localized(@"EXPIRE_SYSTEM_MESSAGE",
                                                                                                                                                                                       @"Message for the 'app launch failed' alert.")];
            [info anyUpsertWithTransaction:updateTransaction];
        }
    });
}

- (void)fallbackTimerDidFire {
    
    if (![self shouldHandelMessages]) return;
        
    dispatch_async([[self class] serialQueue], ^{
        
        OWSLogInfo(@"%@ begin fetch need archive messages.", self.logTag);
        
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
                    if ([interaction isKindOfClass:[TSInfoMessage class]]) {
                        TSInfoMessage *tmpMessage = (TSInfoMessage *)interaction;
                        if (tmpMessage.messageType != TSInfoMessageArchiveMessage) {
                            [archivedMessages addObject:interaction];
                            [archivedMessageIds addObject:interaction.uniqueId];
                        }
                    } else {
                        [archivedMessages addObject:interaction];
                        [archivedMessageIds addObject:interaction.uniqueId];
                    }
                   
                    
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
        OWSLogInfo(@"%@ begin archive %lu messages.", self.logTag, count);
        if(count > 0){
            [self slowlyArchiveMessages:archivedMessages
                              batchSize:kArchivedMessageBatchSize
                             completion:^{
                OWSLogInfo(@"archive %lu messages completion.", count);
                self.lastTimeStamp = CACurrentMediaTime();
                backgroundTask = nil;
            }];
        } else {
            
            self.lastTimeStamp = CACurrentMediaTime();
            backgroundTask = nil;
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

@end
