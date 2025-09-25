//
//  DTTHreadHelper.m
//  Wea
//
//  Created by hornet on 2022/4/27.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTThreadHelper.h"

//
#import <TTServiceKit/TTServiceKit-swift.h>
#import "TSThread.h"
#import "TSGroupThread.h"
#import "TSContactThread.h"
//
#import "DTChatFolderManager.h"
#import "DTConversationNotifyEntity.h"

extern NSString *const kConversationDidChangeNotification;
extern NSString *const kConversationUpdateFromSocketMessageNotification;
@interface DTThreadHelper()<DatabaseChangeDelegate>
@property (nonatomic, strong, readwrite) NSMutableArray <TSThread *> *allUnReadMutableThreadArr;
//所有包含未读且没有mute的thread集合
@property (nonatomic, strong, readwrite) NSMutableArray <TSThread *> *unMutedThreadArr;
@property (nonatomic, strong, readwrite) NSArray <TSThread *> *allUnMutedThreadArr;//会根据folder变化
@property (nonatomic, strong, readwrite) NSArray <TSThread *> *allMutedThreadArr;//会根据folder变化
//所有包含未读且mute的thread集合
@property (nonatomic, strong, readwrite) NSMutableArray <TSThread *> *mutedThreadArr;
@property (nonatomic, strong, readwrite) NSMutableArray <TSThread *> *folderUnReadThreads;
@property (nonatomic, strong, nullable) NSMutableArray <TSThread *>* folderUnMutedThreadArr;
@property (nonatomic, strong, nullable) NSMutableArray <TSThread *> *folderMutedThreadArr;
@property (nonatomic, assign, readwrite) NSUInteger allUnMutedUnreadCount;
@property (nonatomic, assign, readwrite) NSUInteger allMutedUnReadCount;
@property (nonatomic, assign, readwrite) NSUInteger allUnreadCount;
@property (nonatomic, strong) YapDatabaseConnection *databaseConnection;
@property (nonatomic, strong, readwrite) NSDictionary *unreadThreadCache;//未读会话缓存

@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (nonatomic, strong) dispatch_source_t debounceTimer;
@end

@implementation DTThreadHelper

+ (instancetype)sharedManager {
    static DTThreadHelper *shareManger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManger = [self new];
        shareManger.allUnMutedUnreadCount = 0;
        shareManger.allMutedUnReadCount = 0;
        
        shareManger.serialQueue = dispatch_queue_create("com.difft.DTThreadHelper", DISPATCH_QUEUE_SERIAL);
        shareManger.pendingRequests = [NSMutableArray array];
    });
    return shareManger;
}

- (void)loadUnReadThread {
    
    [self asyncLoadUnReadThread];
}

- (void)asyncLoadUnReadThread {
    @synchronized (self) {
        
        if (self.debounceTimer) {
            dispatch_source_cancel(self.debounceTimer);
        }
        self.debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.serialQueue);
        dispatch_source_set_timer(self.debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(self.debounceTimer, ^{
            [self debounceAsyncLoadUnreadThread];
        });
        dispatch_resume(self.debounceTimer);
    }
}

- (void)syncLoadUnReadThreadForNSEWithCompletion:(nonnull LoadUnreadThreadCompletionBlock)completion {
    
    @synchronized (self) {
        
        [self.pendingRequests addObject:completion];
        if (self.debounceTimer) {
            dispatch_source_cancel(self.debounceTimer);
        }
        self.debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.serialQueue);
        dispatch_source_set_timer(self.debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(self.debounceTimer, ^{
            [self debounceSyncLoadUnreadThread];
        });
        dispatch_resume(self.debounceTimer);
    }
}

- (void)debounceAsyncLoadUnreadThread {
    
    @synchronized (self) {
        __block NSUInteger allUnMutedUnreadCount = 0;
        __block NSUInteger allMutedUnReadCount = 0;
        __block NSUInteger manualUnMuteUnreadThreadCount = 0; //当前thread是未mute的状态 手动置为未读的thread
        __block NSUInteger manualMuteUnreadThreadCount = 0;   //当前thread是mute状态， 手动置为未读的thread
        __block NSMutableArray *arr = [NSMutableArray array];
        __block NSMutableDictionary <NSString *, NSNumber *> *unreadThreadCache = [NSMutableDictionary dictionary];
        //关闭通知的Thread数组
        __block NSMutableArray *mutedThreadArr = [NSMutableArray array];
        @weakify(self);
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            @strongify(self);

            [[[AnyThreadFinder alloc] init] enumerateVisibleUnreadThreadsWithIsArchived:NO
                                                                            transaction:transaction
                                                                                  block:^(TSThread * unreadThread) {

                if (!unreadThread.serverThreadId) {
                    return;
                }

                NSInteger unreadMessageCount = [unreadThread unreadMessageCount];
                if (unreadMessageCount > 0) {
                    if (unreadThread.conversationEntity && unreadThread.conversationEntity.muteStatus == 1) {
                        allMutedUnReadCount += unreadMessageCount;
                        [mutedThreadArr addObject:unreadThread];
                        [unreadThreadCache setValue:@(unreadMessageCount) forKey:unreadThread.serverThreadId];
                    } else { //默认是没有mute 没有mute的都是红标
                        allUnMutedUnreadCount += unreadMessageCount;
                        if (unreadThread) {
                            [arr addObject:unreadThread];
                            [unreadThreadCache setValue:@(unreadMessageCount) forKey:unreadThread.serverThreadId];
                        }
                    }

                } else { // 手动标注未读
                    if (!(unreadThread.isUnread && unreadThread.lastMessageDate.ows_millisecondsSince1970 <= unreadThread.unreadTimeStimeStamp)) {
                        return;
                    }
                    if (![unreadThread isKindOfClass:[TSThread class]]) {
                        return;
                    }
                    if (!unreadThread.isMuted) {
                        manualUnMuteUnreadThreadCount += 1;
                        [arr addObject:unreadThread];
                        [unreadThreadCache setValue:@(1) forKey:unreadThread.serverThreadId];
                    } else {
                        manualMuteUnreadThreadCount +=1;
                        [mutedThreadArr addObject:unreadThread];
                        [unreadThreadCache setValue:@(1) forKey:unreadThread.serverThreadId];
                    }
                }
            }];

            [self sortWithMutableArray:arr];
            [self sortWithMutableArray:mutedThreadArr];
        } completion:^{
            @strongify(self);
            @synchronized (self) {
                self.allUnMutedUnreadCount = allUnMutedUnreadCount + manualUnMuteUnreadThreadCount;
                self.allMutedUnReadCount = allMutedUnReadCount + manualMuteUnreadThreadCount;
                self.allUnreadCount = allMutedUnReadCount + allUnMutedUnreadCount;
                self.unreadThreadCache = [unreadThreadCache copy];
                self.unMutedThreadArr = arr.mutableCopy;
                self.mutedThreadArr = mutedThreadArr.mutableCopy;
                [arr addObjectsFromArray:mutedThreadArr];
                self.allUnReadMutableThreadArr = arr;
                if (self.delegate && [self.delegate respondsToSelector:@selector(unreadCountCacheChanged)]) {
                    NSMutableSet <NSString *> *cacheIds = [NSMutableSet setWithArray:unreadThreadCache.allKeys];
                    NSMutableSet <NSString *> *unreadIds = [NSMutableSet new];
                    for (TSThread *thread in arr) {
                        [unreadIds addObject:thread.serverThreadId];
                    }
                    [cacheIds minusSet:unreadIds];

                    OWSLogInfo(@"[Chat folder] unreadCount:%ld, cacheCount:%ld, cacheIds:%@", arr.count, unreadThreadCache.count, cacheIds);
                    [self.delegate unreadCountCacheChanged];
                }
            }
            
            if (self.folderThreadUniqueIds) {
                self.folderThreadUniqueIds = self->_folderThreadUniqueIds;
            }
            
        }];
    }
}

///主要提供给NSE进程使用，仅仅用做计算未读数
- (void)debounceSyncLoadUnreadThread {
    @synchronized (self) {
        
        NSArray *requestsToProcess = [self.pendingRequests copy];
        [self.pendingRequests removeAllObjects];
        
        if (requestsToProcess.count > 1) {
            id lastRequest = [requestsToProcess lastObject];
            for (id request in requestsToProcess) {
                if (![request isEqual:[NSNull null]] && ![request isEqual: lastRequest] ) {
                    LoadUnreadThreadCompletionBlock completion = (LoadUnreadThreadCompletionBlock)request;
                    completion(-1000);
                }
            }
        }
        
        __block NSUInteger allUnMutedUnreadCount = 0;
        __block NSUInteger manualUnMuteUnreadThreadCount = 0; //当前thread是未mute的状态 手动置为未读的thread
        
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            [[[AnyThreadFinder alloc] init] enumerateVisibleUnreadThreadsWithIsArchived:NO
                                                                            transaction:transaction
                                                                                  block:^(TSThread * unreadThread) {
                
                if (!unreadThread.serverThreadId) {
                    return;
                }
                
                NSInteger unreadMessageCount = [unreadThread unreadMessageCount];
                if (unreadMessageCount > 0) {
                    if (!unreadThread.conversationEntity || (unreadThread.conversationEntity && unreadThread.conversationEntity.muteStatus != 1)) {
                        allUnMutedUnreadCount += unreadMessageCount;
                    }
                } else { // 手动标注未读
                    if (!(unreadThread.isUnread && unreadThread.lastMessageDate.ows_millisecondsSince1970 <= unreadThread.unreadTimeStimeStamp)) {
                        return;
                    }
                    if (![unreadThread isKindOfClass:[TSThread class]]) {
                        return;
                    }
                    if (!unreadThread.isMuted) {
                        manualUnMuteUnreadThreadCount += 1;
                    }
                }
            }];
            
            NSUInteger finalUnreadCount = allUnMutedUnreadCount + manualUnMuteUnreadThreadCount;
            id lastRequest = [requestsToProcess lastObject];
            if (lastRequest) {
                LoadUnreadThreadCompletionBlock completion = (LoadUnreadThreadCompletionBlock)lastRequest;
                completion(finalUnreadCount);
            } else {
                OWSLogInfo(@"debounceSyncLoadUnreadThread lastRequest = nil");
            }
           
        }];
    }
}

- (void)sortWithMutableArray:(NSMutableArray *)arr{
    if (!arr.count) {return;}
    [arr sortUsingComparator:^NSComparisonResult(TSThread * _Nonnull thread1, TSThread * _Nonnull thread2) {
        // 顺序 call置顶-普通置顶-普通会话
        if (thread1.isCallingSticked && thread2.isCallingSticked) {
            return [thread1.stickCallingDate compare:thread2.stickCallingDate];
        }
        if (thread1.isCallingSticked && !thread2.isCallingSticked) {
            return  NSOrderedDescending;
        }
        if (!thread1.isCallingSticked && thread2.isCallingSticked) {
            return  NSOrderedAscending;
        }
        if (thread1.isSticked && thread2.isSticked) {
            return [thread1.stickDate compare:thread2.stickDate];
        }
        if (thread1.isSticked && !thread2.isSticked) {
            return  NSOrderedDescending;
        }
        if (!thread1.isSticked && thread2.isSticked) {
            return  NSOrderedAscending;
        }
        return [thread1.lastMessageDate compare:thread2.lastMessageDate];
    }];
}

- (void)observerAllUnReadMessageCount {
    [self.databaseStorage appendDatabaseChangeDelegate:self];
}

- (void)setFolderThreadUniqueIds:(NSArray<NSString *> *)folderThreadUniqueIds {
    @synchronized (self) {
        _folderThreadUniqueIds = folderThreadUniqueIds;
        NSMutableArray <TSThread *> *folderUnreadThreads = @[].mutableCopy;
        NSMutableArray <TSThread *> *folderUnMutedThreadArr = @[].mutableCopy;
        NSMutableArray <TSThread *> *folderMutedThreadArr = @[].mutableCopy;
        //allUnReadMutableThreadArr 包括红标和 灰标
        for (TSThread *unreadThread in self.unMutedThreadArr) {
            for (NSString *folderThreadUniqueId in folderThreadUniqueIds) {
                if ([unreadThread.uniqueId isEqualToString:folderThreadUniqueId]) {
                    [folderUnreadThreads addObject:unreadThread];
                    [folderUnMutedThreadArr addObject:unreadThread];
                }
            }
        }
        for (TSThread *unreadThread in self.mutedThreadArr ) {
            for (NSString *folderThreadUniqueId in folderThreadUniqueIds) {
                if ([unreadThread.uniqueId isEqualToString:folderThreadUniqueId]) {
                    [folderUnreadThreads addObject:unreadThread];
                    [folderMutedThreadArr addObject:unreadThread];
                }
            }
        }
        
        _folderUnReadThreads = [[[folderUnreadThreads reverseObjectEnumerator] allObjects] mutableCopy];
        _folderUnMutedThreadArr = [folderUnMutedThreadArr mutableCopy];
        _folderMutedThreadArr = [folderMutedThreadArr mutableCopy];
    }
}
//TSThreadForManualUnreadDatabaseViewExtensionName
- (void)databaseChangesDidUpdateExternally {
    
    OWSAssertIsOnMainThread();
    
}

- (void)databaseChangesDidReset {
    
    OWSAssertIsOnMainThread();
    
    
}

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges{
    
    if(!databaseChanges.threadUniqueIds.count || !databaseChanges.interactionUniqueIds){
        return;
    }
    
    [self loadUnReadThread];
}

- (void)conversationSettingDidChange:(NSNotification *)notify {
    [self loadUnReadThread];
}

- (NSArray<TSThread *> *)allUnReadThreadArr {
    if (_folderThreadUniqueIds) {
        return self.folderUnReadThreads;
    } else {
        return [self.allUnReadMutableThreadArr copy];
    }
}

- (NSArray<TSThread *> *)allUnMutedThreadArr {
    if (_folderThreadUniqueIds) {
        return [self.folderUnMutedThreadArr copy];
    } else {
        return [self.unMutedThreadArr copy];
    }
}

- (NSArray<TSThread *> *)allMutedThreadArr {
    if (_folderThreadUniqueIds) {
        return [self.folderMutedThreadArr copy];
    } else {
        return [self.mutedThreadArr copy];
    }
}

- (NSMutableArray<TSThread *> *)allUnReadMutableThreadArr {
    if (!_allUnReadMutableThreadArr) {
        _allUnReadMutableThreadArr = [NSMutableArray array];
    }
    return _allUnReadMutableThreadArr;
}

@end
