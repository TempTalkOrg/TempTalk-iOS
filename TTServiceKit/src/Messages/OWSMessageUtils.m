//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageUtils.h"
#import "AppContext.h"
#import "MIMETypeUtil.h"
#import "OWSMessageSender.h"
//
#import "TSAccountManager.h"
#import "TSAttachment.h"
#import "TSAttachmentStream.h"
//
#import "TSIncomingMessage.h"
#import "TSMessage.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import "TSThread.h"
#import "UIImage+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
//

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageUtils ()


@end

#pragma mark -

@implementation OWSMessageUtils

+ (instancetype)sharedManager
{
    static OWSMessageUtils *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (NSUInteger)unreadMessagesCount
{
    __block NSUInteger count = 0;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        count = [[[AnyThreadFinder alloc] init] visibleThreadUnreadMsgCountWithIsArchived:NO
                                                                      transaction:transaction];
    }];
    
    return count;
}

- (NSUInteger)unreadMessagesCountExcept:(TSThread *)thread
{
//    __block NSUInteger count = 0;
//    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
//        count = [[[AnyThreadFinder alloc] init] visibleThreadUnreadMsgCountWithIsArchived:NO
//                                                                      transaction:transaction];
//        if(thread.unreadMessageCount > 0){
//            count -= thread.unreadMessageCount;
//        }
//
//        count = MAX(count, 0);
//    }];
//
//    return count;
    return 0;
}

- (void)updateApplicationBadgeCount
{
    if (!CurrentAppContext().isMainApp) {
        return;
    }

    NSUInteger numberOfItems = [self unreadMessagesCount];
    [CurrentAppContext() setMainAppBadgeNumber:numberOfItems];
}

@end

NS_ASSUME_NONNULL_END
