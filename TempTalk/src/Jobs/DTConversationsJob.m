//
//  DTConversationsJob.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/5.
//

#import "DTConversationsJob.h"
//
#import "AppContext.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSTimer+OWS.h"
#import "TSAccountManager.h"
#import "ThreadUtil.h"
#import <TTServiceKit/AppReadiness.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTConversationsJob ()

@property (nonatomic, assign) NSTimeInterval lastTimeInterval;

@end

@implementation DTConversationsJob

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];

    return self;
}

+ (instancetype)sharedJob
{
    static DTConversationsJob *sharedJob = nil;
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
        queue = dispatch_queue_create("org.dt.conversation.messages", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)applicationDidBecomeActive:(NSNotification *)notify{
    
    OWSAssertIsOnMainThread();

    [self startIfNecessary];
    
}

- (void)startIfNecessary{
//    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
//        if (CurrentAppContext().isMainApp) {
//            dispatch_async([[self class] serialQueue], ^{
//                if([NSDate ows_millisecondTimeStamp] - self.lastTimeInterval > kDayInterval*1000){
//                    
//                    OWSLogInfo(@"begin archive inactive conversations");
//                    
//                    [ThreadUtil archiveInactiveConversations];
//                    self.lastTimeInterval = [NSDate ows_millisecondTimeStamp];
//                }
//            });
//        }
//    });
    
}


@end
