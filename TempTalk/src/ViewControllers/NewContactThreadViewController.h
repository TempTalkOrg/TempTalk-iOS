//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationItemMacro.h"
#import <TTMessaging/OWSViewController.h>
#import <JXCategoryView/JXCategoryView.h>

NS_ASSUME_NONNULL_BEGIN

@class TSThread;

@interface NewContactThreadViewController : OWSViewController<JXCategoryListContentViewDelegate>

- (void)presentThread:(TSThread *)thread
               action:(ConversationViewAction)action
       focusMessageId:(nullable NSString *)focusMessageId;

- (void)requestContactsAtFirstTime;
- (void)loadDataIfNecessary;

@end

NS_ASSUME_NONNULL_END
