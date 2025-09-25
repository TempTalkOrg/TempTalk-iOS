//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ThreadViewHelper.h"
#import <TTServiceKit/AppContext.h>
//
//
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSGroupThread.h>
//
//
//
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/TSAccountManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThreadViewHelper ()

@end

#pragma mark -

@implementation ThreadViewHelper


- (NSArray<TSThread *> *)threadsWithTransaction:(SDSAnyReadTransaction *)transaction {
    
    NSMutableArray *threads = @[].mutableCopy;
    
    AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
    NSError *error;
    [finder enumerateVisibleThreadsWithIsArchived:NO
                                      transaction:transaction
                                            error:&error
                                            block:^(TSThread * thread) {
        [threads addObject:thread];
    }];
    
    return threads.copy;
    
}

- (NSDictionary<NSString *, NSArray<TSThread *> *> *)recentThreadsWithTransaction:(SDSAnyReadTransaction *)transaction {
    
    NSMutableDictionary<NSString *, NSArray<TSThread *> *> *threadsMap = @{}.mutableCopy;
    NSMutableArray *normalThreads = @[].mutableCopy;
    NSMutableArray *archivedThreads = @[].mutableCopy;
    NSMutableArray *invalidThreads = @[].mutableCopy;
    NSMutableArray *invalidAndArchivedThreads = @[].mutableCopy;
    
    AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
    NSError *error;
    [finder enumerateVisibleThreadsWithLimit:1000
                                 transaction:transaction
                                       error:&error
                                       block:^(TSThread * thread) {
        NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
        BOOL invalid = (thread.isGroupThread && ![((TSGroupThread *)thread).groupModel.groupMemberIds containsObject:localNumber]);
        
        if(invalid && thread.isArchived){
            [invalidAndArchivedThreads addObject:thread];
        }else if (invalid){
            [invalidThreads addObject:thread];
        }else if (thread.isArchived){
            [archivedThreads addObject:thread];
        }else{
            [normalThreads addObject:thread];
        }
    }];
    
    if(normalThreads.count){
        threadsMap[@"normalThreads"] = normalThreads.copy;
    }
    
    if(archivedThreads.count){
        threadsMap[@"archivedThreads"] = archivedThreads.copy;
    }
    
    if(invalidThreads.count){
        threadsMap[@"invalidThreads"] = invalidThreads.copy;
    }
    
    if(invalidAndArchivedThreads.count){
        threadsMap[@"invalidAndArchivedThreads"] = invalidAndArchivedThreads.copy;
    }
    
    
    return threadsMap.copy;
    
}


@end

NS_ASSUME_NONNULL_END
