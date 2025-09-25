//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationItemMacro.h"
#import <TTMessaging/OWSViewController.h>
#import <JXPagingView/JXPagerView.h>

NS_ASSUME_NONNULL_BEGIN

@class TSThread;

@interface NewContactThreadViewController : OWSViewController<JXPagerViewListViewDelegate>

- (void)presentThread:(TSThread *)thread
               action:(ConversationViewAction)action
       focusMessageId:(nullable NSString *)focusMessageId;

- (void)requestContactsAtFirstTime;
- (void)loadDataIfNecessary;

@end

NS_ASSUME_NONNULL_END
