//
//  DTRecallMessagesJob.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/25.
//

#import "DTRecallMessagesJob.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSTimer+OWS.h"
#import "TSMessage.h"
#import "DTRecallMessage.h"
#import "TSInfoMessage.h"
#import "TSAccountManager.h"
#import "DTRecallConfig.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTRecallMessagesJob ()

@property (nonatomic, nullable) NSTimer *fallbackTimer;

@end

@implementation DTRecallMessagesJob

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

    return self;
}

+ (instancetype)sharedJob
{
    static DTRecallMessagesJob *sharedJob = nil;
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
        queue = dispatch_queue_create("org.dt.recall.messages", DISPATCH_QUEUE_SERIAL);
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
    
    NSTimeInterval kFallBackTimerInterval = 2 * kMinuteInterval;
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

- (void)fallbackTimerDidFire{
    
    dispatch_async([[self class] serialQueue], ^{
        
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        
        NSMutableArray<TSInfoMessage *> *items = @[].mutableCopy;
        
        __block BOOL hasEditableMsg = NO;
        
        [BenchManager benchWithTitle:@"mesure find recall editableMsg" block:^{
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * readTransaction) {
                
                NSTimeInterval editableInterval = [DTRecallConfig fetchRecallConfig].editableInterval*1000;
                [RecallFinder enumerateEditableMessagesWithBlockWithTransaction:readTransaction
                                                                          block:^(TSInteraction * interaction, BOOL * stop) {
                    
                    TSInfoMessage *message = (TSInfoMessage *)interaction;
                    
                    if(![message isKindOfClass:[TSInfoMessage class]]){
                        return;
                    }
                    
                    if (now - message.recall.timestamp < editableInterval) {
                        hasEditableMsg = YES;
                        return;
                    }
                    
                    if(!message.customAttributedMessage.length){
                        return;
                    }
                    
                    [items addObject:message];
                }];
            }];
        }];
        
        if(items.count){
            DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
                OWSLogInfo(@"%@ set message editable to no.", self.logTag);
                [items enumerateObjectsUsingBlock:^(TSInfoMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
                    
                    NSMutableAttributedString *customString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE",nil), Localized(@"YOU",nil)]];
                    
                    [message anyUpdateInfoMessageWithTransaction:writeTransaction
                                                           block:^(TSInfoMessage *instance) {
                        instance.customAttributedMessage = customString;
                        instance.editable = NO;
                        [instance.recall clearOriginContent];
                    }];
                    
                    OWSRecall *recall = [OWSRecall anyFetchWithUniqueId:message.uniqueId transaction:writeTransaction];
                    [recall anyUpdateWithTransaction:writeTransaction
                                               block:^(OWSRecall * instance) {
                        instance.clearFlag = YES;
                    }];
                    
                }];
                
            }));
        }
        
        NSMutableArray<TSInfoMessage *> *unClearedMessages = @[].mutableCopy;
        NSMutableArray<TSInfoMessage *> *unClearedArchivedMessages = @[].mutableCopy;
        [BenchManager benchWithTitle:@"mesure find recall unClearedMessages" block:^{
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * readTransaction) {
                
                OWSLogInfo(@"%@ find unClearedMessages.", self.logTag);
                
                NSString *localNumber = [TSAccountManager.shared localNumberWithTransaction:readTransaction];
                
                [RecallFinder enumerateUnClearedMessagesWithBlockWithArchived:NO
                                                                  transaction:readTransaction
                                                                        block:^(TSInteraction * interaction, BOOL * stop) {
                    TSInfoMessage *message = (TSInfoMessage *)interaction;
                    
                    if(![message isKindOfClass:[TSInfoMessage class]]){
                        return;
                    }
                    
                    if(![message.recall.source.source isEqualToString:localNumber]){
                        return;
                    }
                    
                    [unClearedMessages addObject:message];
                }];
                
                if(!unClearedMessages.count){
                    OWSLogInfo(@"%@ find unClearedArchivedMessages.", self.logTag);
                    [RecallFinder enumerateUnClearedMessagesWithBlockWithArchived:YES
                                                                      transaction:readTransaction
                                                                            block:^(TSInteraction * interaction, BOOL * stop) {
                        TSInfoMessage *message = (TSInfoMessage *)interaction;
                        
                        if(![message isKindOfClass:[TSInfoMessage class]]){
                            return;
                        }
                        
                        if(![message.recall.source.source isEqualToString:localNumber]){
                            return;
                        }
                        
                        [unClearedArchivedMessages addObject:message];
                    }];
                }
            }];
        }];
        
        if (unClearedMessages.count ||
            unClearedArchivedMessages.count) {
            
            DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
                
                if (unClearedMessages.count) {
                    
                    OWSLogInfo(@"%@ handle unClearedMessages.", self.logTag);
                    [unClearedMessages enumerateObjectsUsingBlock:^(TSInfoMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
                        
                        [message anyUpdateInfoMessageWithTransaction:writeTransaction
                                                               block:^(TSInfoMessage *instance) {
                            [instance.recall clearOriginContent];
                        }];
                        
                        OWSRecall *recall = [OWSRecall anyFetchWithUniqueId:message.uniqueId transaction:writeTransaction];
                        [recall anyUpdateWithTransaction:writeTransaction
                                                   block:^(OWSRecall * instance) {
                            instance.clearFlag = YES;
                        }];
                    }];
                }
                
                if (unClearedArchivedMessages.count) {
                    
                    OWSLogInfo(@"%@ handle unClearedArchivedMessages.", self.logTag);
                    [unClearedArchivedMessages enumerateObjectsUsingBlock:^(TSInfoMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
                        
                        [message.recall clearOriginContent];
                        [RecallFinder updateUnClearedArchivedMessageWithInfoMsg:message transaction:writeTransaction];
                        
                        OWSRecall *recall = [OWSRecall anyFetchWithUniqueId:message.uniqueId transaction:writeTransaction];
                        [recall anyUpdateWithTransaction:writeTransaction
                                                   block:^(OWSRecall * instance) {
                            instance.clearFlag = YES;
                        }];
                        
                    }];
                }
            }));
        }
        
        if(!hasEditableMsg){
            [self stop];
        }
    });
    
}

@end
