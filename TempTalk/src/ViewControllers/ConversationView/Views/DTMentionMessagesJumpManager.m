//
//  DTMentionMessagesJumpManager.m
//  Signal
//
//  Created by Kris.s on 2022/7/21.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTMentionMessagesJumpManager.h"
//
#import "TSGroupThread.h"
#import "AppContext.h"
#import "DTMentionMsgsIndicatorView.h"
#import "TSMessage.h"
#import "TempTalk-Swift.h"
#import "TSIncomingMessage.h"

@interface DTMentionMessagesJumpManager ()<DatabaseChangeDelegate>


@property (nonatomic, strong) TSGroupThread *thread;
@property (nonatomic, copy) void (^jumpBlock)(TSMessage *);

@property (nonatomic, strong) NSArray<TSIncomingMessage *> *items;

@property (nonatomic, assign) BOOL shouldObserveDBModifications;

@property (nonatomic, strong) DTMentionMsgsIndicatorView *mentionMsgsIndicatorView;

@property (nonatomic, assign) BOOL handledOnceAlready;


@end

@implementation DTMentionMessagesJumpManager

#pragma mark - Dependencies

- (DTMentionMsgsIndicatorView *)mentionMsgsIndicatorView{
    if(!_mentionMsgsIndicatorView){
        _mentionMsgsIndicatorView = [DTMentionMsgsIndicatorView new];
        _mentionMsgsIndicatorView.hidden = YES;
    }
    return _mentionMsgsIndicatorView;
}

 
- (instancetype)initWithConversationViewThread:(TSGroupThread *)thread
                           iconViewLayoutBlock:(void (^)(UIView *))iconViewLayoutBlock
                                     jumpBlock:(void (^)(TSMessage *))jumpBlock{
    
    if(self = [super init]){
        
        self.thread = thread;
        self.jumpBlock = jumpBlock;
        
        if(iconViewLayoutBlock){
            iconViewLayoutBlock(self.mentionMsgsIndicatorView);
        }
        
        @weakify(self);
        _mentionMsgsIndicatorView.tapBlock = ^{
            @strongify(self);
            if(self.jumpBlock){
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                if([self checkMentionMessagesCount] > 0){
                    self.jumpBlock([self getNextMessageWithIndexPath:indexPath]);
                }
                
            }
        };
        
        [self addObservers];
        
        self.shouldObserveDBModifications = YES;
        
        
    }
    
    return self;
}


- (TSMessage *)getNextMessageWithIndexPath:(NSIndexPath *)indexPath{
    return self.items[(NSUInteger)indexPath.row];
}


- (void)resetMappings {
 
    InteractionFinder *finder = [[InteractionFinder alloc] initWithThreadUniqueId:self.thread.uniqueId];
    
    NSMutableArray<TSIncomingMessage *> *items = @[].mutableCopy;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        [finder unseenMentionedInteractionsWithTransaction:transaction
                                                     block:^(TSIncomingMessage * instance) {
            [items addObject:instance];
        }];
    }];
    
    self.items = items.copy;
}

- (void)addObservers {
    
    
    [self.databaseStorage appendDatabaseChangeDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    self.shouldObserveDBModifications = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    self.shouldObserveDBModifications = YES;
    
    [self handleMentionMessages];
}
    

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges{
    
    OWSAssertIsOnMainThread();
    
    if (!self.shouldObserveDBModifications) {
        return;
    }
    
    if (![databaseChanges.threadUniqueIds containsObject:self.thread.uniqueId]) {
        // Ignoring irrelevant update.
        return;
    }
    
    [self handleMentionMessages];
    
}

- (void)databaseChangesDidUpdateExternally {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
}

- (void)databaseChangesDidReset {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
    
}
    
- (void)anyUIDBDidUpdateExternally
{

    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    if (self.shouldObserveDBModifications) {
        [self resetMappings];
    }
}


- (NSUInteger)checkMentionMessagesCount{
    [self resetMappings];
    NSUInteger count = self.items.count;
    
    self.mentionMsgsIndicatorView.hidden = (count <= 0);
    
    return count;
}

- (void)handleMentionMessages{
    
    NSUInteger count = [self checkMentionMessagesCount];
    NSString *badgeCountString = [NSString stringWithFormat:@"%lu", (unsigned long)count];
    if(count >= 99){
        badgeCountString = @"99+";
    }
    
    self.mentionMsgsIndicatorView.badgeCount = badgeCountString;
}

- (void)handleMentionedMessagesOnce{
    if(!self.handledOnceAlready){
        self.handledOnceAlready = YES;
        [self handleMentionMessages];
    }
}


@end
