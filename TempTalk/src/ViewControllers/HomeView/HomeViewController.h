//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationItemMacro.h"
#import <TTMessaging/OWSViewController.h>
#import <UIKit/UIKit.h>
#import <JXPagingView/JXPagerView.h>

@class ThreadMapping;
@class OWSSearchBar;
@class DTChatFolderEntity;
@class ThreadViewModel;
@class HomeReminderViewCell;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HomeViewMode) {
    HomeViewMode_Archive,
    HomeViewMode_Inbox,
};

@class TSThread;

@interface HomeViewController : OWSViewController<JXPagerViewListViewDelegate>

@property (nonatomic) HomeViewMode homeViewMode;
@property (nonatomic, assign) BOOL isFromRegistration;
@property (nonatomic, strong) ThreadMapping *threadMapping;
@property (nonatomic, strong) DTChatFolderEntity *currentFolder;

@property (nonatomic) UITableView *tableView;
@property (nonatomic, readonly) HomeReminderViewCell *reminderViewCell;
@property (nonatomic, readonly) NSMutableArray *allUnreadThreadArr;

@property (nonatomic, assign, readonly) BOOL viewDidAppear;//view是否已经渲染完成
@property (nonatomic, readonly) NSCache<NSString *, ThreadViewModel *> *threadViewModelCache;
@property (nonatomic, readonly) NSSet<NSString *> *blockedPhoneNumberSet;
@property (nonatomic, strong, nullable) TSThread *lastViewedThread;

- (void)resetMappings;
- (void)presentThread:(TSThread *)thread action:(ConversationViewAction)action;
- (void)presentThread:(TSThread *)thread
               action:(ConversationViewAction)action
       focusMessageId:(nullable NSString *)focusMessageId;
- (void)updateViewState;

@end

NS_ASSUME_NONNULL_END
