//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "HomeViewController.h"
#import "AppDelegate.h"
#import "HomeViewCell.h"

#import "PushManager.h"
#import "RegistrationUtils.h"
#import "SignalApp.h"
#import "TSAccountManager.h"
//
#import "TSGroupThread.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/UIUtil.h>

#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/OWSMessageUtils.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

#import <SignalCoreKit/Threading.h>
#import <SignalCoreKit/NSDate+OWS.h>

#import "DTRemoveMembersOfAGroupAPI.h"
#import "OWSLinkDeviceViewController.h"
#import "HomeEmptyBoxView.h"
#import "DTPatternHelper.h"
#import "DTConversationsJob.h"
#import "HomeViewController+ChatFolder.h"
#import <JXCategoryView/JXCategoryView.h>
#import "DTThreadHelper.h"
#import "DTHomeVirtualCell.h"
#import "TempTalk-Swift.h"
#import "SVProgressHUD.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import "DTInviteRequestHandler.h"

NS_ASSUME_NONNULL_BEGIN

// The bulk of the content in this view is driven by a YapDB view/mapping.
// However, we also want to optionally include ReminderView's at the top
// and an "Archived Conversations" button at the bottom. Rather than introduce
// index-offsets into the Mapping calculation, we introduce two pseudo groups
// to add a top and bottom section to the content, and create cells for those
// sections without consulting the YapMapping.
// This is a bit of a hack, but it consolidates the hacks into the Reminder/Archive section
// and allows us to leaves the bulk of the content logic on the happy path.
NSString *const kReminderViewPseudoGroup = @"kReminderViewPseudoGroup";
NSString *const kArchiveButtonPseudoGroup = @"kArchiveButtonPseudoGroup";

NSString *const kArchivedConversationsReuseIdentifier = @"kArchivedConversationsReuseIdentifier";

static NSString *const kDTShowScreenLockAlertKey = @"showScreenLockAlertKey";


@interface HomeViewController () <OWSQRScannerDelegate, DatabaseChangeDelegate>

@property (nonatomic) HomeEmptyBoxView *emptyBoxView;

@property (nonatomic, strong) NSSet<NSString *> *blockedPhoneNumberSet;
@property (nonatomic, strong) NSCache<NSString *, ThreadViewModel *> *threadViewModelCache;
@property (nonatomic) BOOL isViewVisible;
@property (nonatomic) BOOL shouldObserveDBModifications;
@property (nonatomic) BOOL hasBeenPresented;

@property (nonatomic,assign) BOOL viewDidAppear;//view是否已经渲染完成

// Dependencies

@property (nonatomic, readonly) AccountManager *accountManager;
@property (nonatomic, readonly) OWSBlockingManager *blockingManager;

// Views
@property (nonatomic, strong) HomeReminderViewCell *reminderViewCell;
@property (nonatomic, readonly) UIView *missingContactsPermissionView;

@property (nonatomic, strong) DTRemoveMembersOfAGroupAPI *removeMembersOfAGroupAPI;
@property (nonatomic, strong) NSIndexPath *updateIndexPath;
@property (nonatomic, strong) NSIndexPath *preLastThreadIndexPath;
@property (nonatomic, strong) UIImageView *avatarStateImageView;//个人头像的状态

@property (nonatomic, copy) void(^scrollCallback)(UIScrollView *scrollView);

@property (nonatomic, nullable) NSTimer *refreshUITimer;
@property (nonatomic, strong, nullable) NSSet<NSString *> *needUpdatedItemIds;
/// 增量刷新异步计算，用来保证刷新的有效间隔
@property (nonatomic, assign) BOOL processingUpdatedItems;

@property (nonatomic, strong) DTDismissAGroupAPI *dismissAGroupAPI;

@end

#pragma mark -

@implementation HomeViewController

#pragma mark - Init

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    _viewDidAppear = false;
    _homeViewMode = HomeViewMode_Inbox;
    [self commonInit];

    return self;
}

- (void)commonInit
{
    _blockedPhoneNumberSet = [NSSet setWithArray:[self.blockingManager blockedPhoneNumbers]];
    _threadViewModelCache = [NSCache new];
    _preLastThreadIndexPath = nil;
}

-(BOOL)hidesBottomBarWhenPushed
{
    return self.homeViewMode != HomeViewMode_Inbox;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - View Life Cycle

- (void)loadView
{
    [super loadView];

    self.reminderViewCell = [self createReminderCell];
    [self.view addSubview:self.tableView];
    [self.tableView autoPinEdgesToSuperviewSafeArea];
    
    HomeEmptyBoxView *emptyBoxView = [HomeEmptyBoxView new];
    _emptyBoxView = emptyBoxView;
    self.tableView.backgroundView = emptyBoxView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Create the database connection.
    
    if (self.homeViewMode == HomeViewMode_Archive) {
        self.navigationItem.title = Localized(@"HOME_VIEW_TITLE_ARCHIVE", @"");
    }

    [self updateViewState];
    [self updateReminderViews];
    // because this uses the table data source, `tableViewSetup` must happen
    // after mappings have been set up in `showInboxGrouping`
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    [self addNotificationObserver];

    [self applyTheme];
    [self stickNoteToSelfIfNeeded];    
}

- (void)viewDidAppear:(BOOL)animated
{
    if (!CurrentAppContext().isMainAppAndActive) {
        return;
    }
    
    [super viewDidAppear:animated];
    
    _viewDidAppear = true;
    
    [self handleRemoteNotify:[PushManager sharedManager].apnsInfo];
    
    [self checkIfNeedShowScreenLockAlert];
    
    OWSLogInfo(@"viewDidAppear");
}

- (void)checkIfNeedShowScreenLockAlert{
    NSString *firstVersion = [AppVersion shared].firstAppVersion;
    NSString *targetVersion = @"3.1.4";

    BOOL oldLockEnable = [ScreenLock sharedManager].old_isScreenLockEnabled || [OWS2FAManager.sharedManager is2FAEnabled];
    if(![self screenLockAlertFlag] &&
       [firstVersion compare:targetVersion options:NSNumericSearch] == NSOrderedAscending &&
       oldLockEnable){
        
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:[Localize localized:@"SCREENLOCK_UPGRADE_TITLE"]
                                            message:[NSString stringWithFormat:[Localize localized:@"SCREENLOCK_UPGRADE_TIPS"], TSConstants.appDisplayName]
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *ignoreAction = [UIAlertAction actionWithTitle:
                                       [Localize localized:@"SCREENLOCK_UPGRADE_IGNORE"]
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *_Nonnull action) {
            [self markScreenLockAlertFlag];
        }];
        UIAlertAction *checkAction = [UIAlertAction actionWithTitle:
                                      [Localize localized:@"SCREENLOCK_UPGRADE_CHECK"]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *_Nonnull action) {
            [self markScreenLockAlertFlag];
            DTSecurityAndPrivacyViewController *privacyVc = [DTSecurityAndPrivacyViewController new];
            [self.navigationController pushViewController:privacyVc animated:YES];
        }];
        [alertController addAction:ignoreAction];
        [alertController addAction:checkAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (NSInteger)screenLockAlertFlag{
    return [CurrentAppContext().appUserDefaults boolForKey:kDTShowScreenLockAlertKey];
}

- (void)markScreenLockAlertFlag{
    [CurrentAppContext().appUserDefaults setBool:YES forKey:kDTShowScreenLockAlertKey];
    [CurrentAppContext().appUserDefaults synchronize];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (!CurrentAppContext().isMainAppAndActive) {
        return;
    }
    [super viewWillAppear:animated];
    self.isViewVisible = YES;
    
    OWSLogInfo(@"viewWillAppear");
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.isViewVisible = NO;
    
    _viewDidAppear = false;
}

- (void)setIsViewVisible:(BOOL)isViewVisible
{
    _isViewVisible = isViewVisible;

    [self updateShouldObserveDBModifications];
}

- (void)updateShouldObserveDBModifications
{
    BOOL isAppForegroundAndActive = CurrentAppContext().isAppForegroundAndActive;
    self.shouldObserveDBModifications = self.isViewVisible && isAppForegroundAndActive;
}

- (void)setShouldObserveDBModifications:(BOOL)shouldObserveDBModifications
{
    if (_shouldObserveDBModifications == shouldObserveDBModifications) {
        return;
    }

    _shouldObserveDBModifications = shouldObserveDBModifications;

    if (self.shouldObserveDBModifications) {
        [self updateFiltering];
        [self startRefreshUITimerIfNecessary];
    }else{
        [self stopRefreshUITimer];
    }
}

#pragma mark - Actions

- (void)settingsButtonPressed:(id)sender
{
    OWSNavigationController *navigationController = [AppSettingsViewController inModalNavigationController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Notifications

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:OWSApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];

    [self.databaseStorage appendDatabaseChangeDelegate:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deregistrationStateDidChange:)
                                                 name:NSNotificationNameDeregistrationStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(outageStateDidChange:)
                                                 name:OutageDetection.outageStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteNotification:)
                                                 name:kDTDidReceiveRemoteNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveGroupPeriodicRemindNotification:)
                                                 name:DTGroupPeriodicRemindNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMarkAsUnreadNotification:)
                                                 name:DTMarkAsUnreadNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalInvite:)
                                                 name:AppLinkNotificationHandler.externalInviteNotification
                                               object:nil];
    
}

- (void)signalAccountsDidChange:(id)notification
{
    OWSAssertIsOnMainThread();
}

- (void)deregistrationStateDidChange:(id)notification
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"deregistrationStateDidChange.");

    [self updateReminderViews];
    
    [OWSDevicesService checkIfKickedOffComplete:^(BOOL kickedOff) {
        if (kickedOff) {
            [RegistrationUtils kickedOffToRegistration];
        }
    }];
}

- (void)outageStateDidChange:(id)notification
{
    OWSAssertIsOnMainThread();

    [self updateReminderViews];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self updateViewState];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self updateShouldObserveDBModifications];

    // It's possible a thread was created while we where in the background. But since we don't honor contact
    // requests unless the app is in the foregrond, we must check again here upon becoming active.
    __block BOOL hasAnyMessages;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        hasAnyMessages = [self hasAnyMessagesWithTransaction:transaction];
    }];
    
    if (hasAnyMessages) {
// changed: forbid to read system contacts
//        [self.contactsManager requestSystemContactsOnceWithCompletion:^(NSError *_Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateReminderViews];
            });
//        }];
    }
    
    if ([TSAccountManager isRegistered]) {
        [[DTConversationsJob sharedJob] startIfNecessary];
    }
}

- (BOOL)hasAnyMessagesWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [TSThread anyCountWithTransaction:transaction] > 0;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self updateShouldObserveDBModifications];
}

- (void)didReceiveRemoteNotification:(NSNotification *)notify{
    [self handleRemoteNotify:notify.userInfo[@"apnsInfo"]];
}

- (void)didReceiveGroupPeriodicRemindNotification:(NSNotification *)noti {
  
    if (!noti.object) return;
    
    BOOL isChanged = [noti.userInfo[@"isChanged"] boolValue];
    if (!isChanged) return;
    
    TSThread *targetThread = (TSThread *)noti.object;
    __block BOOL hasUnread = NO;
    NSArray <NSString *> *allUnreadThreadIds = [DTThreadHelper sharedManager].unreadThreadCache.allKeys;
    [allUnreadThreadIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj hasPrefix:@"+"]) {
            return;
        }
        if ([obj isEqualToString:targetThread.serverThreadId]) {
            hasUnread = YES;
            *stop = YES;
        }
    }];
    if (hasUnread) return;
    
    if ([self.navigationController.topViewController isKindOfClass:[ConversationViewController class]]) {
        ConversationViewController *conversationVC = (ConversationViewController *)self.navigationController.topViewController;
        if ([targetThread.serverThreadId isEqualToString:conversationVC.thread.serverThreadId]) {
            return;
        }
    }
    [self markAsUnreadWithThread:targetThread];
}

- (void)didReceiveMarkAsUnreadNotification:(NSNotification *)noti {
    if (!noti.object) {
        return;
    }
    TSThread *targetThread = (TSThread *)noti.object;
    if ([self.navigationController.topViewController isKindOfClass:[ConversationViewController class]]) {
        ConversationViewController *conversationVC = (ConversationViewController *)self.navigationController.topViewController;
        if ([targetThread.serverThreadId isEqualToString:conversationVC.thread.serverThreadId]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self clearUnreadBadgeFor:targetThread];
            });
        }
    }
}

#pragma mark - APNs

- (void)handleRemoteNotify:(DTApnsInfo *)apnsInfo{
    
    if (!apnsInfo) {
        OWSLogInfo(@"apnsInfo is nil, do nothing");
        return;
    }
    
    [PushManager sharedManager].apnsInfo = nil;
    
    NSString *pushType = apnsInfo.passthroughInfo[@"type"];
    if (DTParamsUtils.validateString(pushType) && [pushType isEqualToString:@"meeting-popups"]) {
        [self handleScheduleMeetingPopupsNotify:apnsInfo];
        return;
    }
    
    [self handleRemoteCallNotifyWithApnsInfo:apnsInfo];
    
    NSString *conversationId = apnsInfo.conversationId;
    
    if (!conversationId.length) {
        OWSLogInfo(@"conversationId is nil, no need to open conversation");
        return;
    }
        
    [self sendCriticalReadSyncMessageWithApnsInfo:apnsInfo];
    
    __block TSThread *thread = nil;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        thread = [TSContactThread getThreadWithContactId:conversationId
                                               transaction:transaction];
        if(!thread){
            NSData *groupId = [NSData dataFromBase64String:conversationId];
            if(groupId.length){
                thread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
            }
        }
    }];
    
    id cvc = self.navigationController.viewControllers.lastObject;
    if ([cvc isKindOfClass:ConversationViewController.class]) {
        ConversationViewController *cconversationVC = (ConversationViewController *)cvc;
        TSThread *openedThread = cconversationVC.thread;
        if ([openedThread.uniqueId isEqualToString:thread.uniqueId]) {
            OWSLogInfo(@"topvc is same conversationvc, no need to reopen");
            [cconversationVC resetContentAndLayoutWithSneakyTransaction];
            return;
        }
    }
    
    if (self.tabBarController.selectedIndex != 0) {
        UINavigationController *selectedNav = (UINavigationController *)self.tabBarController.selectedViewController;
        [selectedNav popToRootViewControllerAnimated:NO];
        self.tabBarController.selectedIndex = 0;
    }
    
    if(thread){
        [self presentThread:thread action:ConversationViewActionNone];
    }
}

- (void)sendCriticalReadSyncMessageWithApnsInfo:(DTApnsInfo *)apnsInfo  {
    
    NSString  * _Nullable interruptionLevel = apnsInfo.interruptionLevel;
    NSString  * _Nullable msg = apnsInfo.msg;

    if (!DTParamsUtils.validateString(interruptionLevel) || !DTParamsUtils.validateString(msg)) {
        return;
    }
    
    if (![interruptionLevel isEqualToString:@"critical"]) {
        return;
    }
        
    NSString *signalKey = [TSAccountManager signalingKey];
    if (!DTParamsUtils.validateString(signalKey)) {
        return;
    }
    
    NSData *data = [[NSData alloc] initWithBase64EncodedString:msg options:0];
    if (!data || data.length == 0) {
        return;
    }
    
    NSData *decryptedPayload = [SSKCryptography decryptAppleMessagePayload:data withSignalingKey:signalKey];
    if (!decryptedPayload || decryptedPayload.length == 0) {
        return;
    }
    
    NSError *err;
    DSKProtoEnvelope *envelope = [[DSKProtoEnvelope alloc] initWithSerializedData:decryptedPayload error:&err];
    if (err) {
        OWSLogError(@"%@ critical read error: %@", self.logTag, err.localizedFailureReason);
        return;
    }
    
    NSString *senderId = envelope.source;
    if (!DTParamsUtils.validateString(senderId)) {
        return;
    }
    uint64_t timestamp = envelope.timestamp;
    
    OWSLinkedDeviceReadReceipt *criticalReadReceipt = [[OWSLinkedDeviceReadReceipt alloc] initWithSenderId:senderId messageIdTimestamp:timestamp readTimestamp:0];
    OWSCriticalReadReceiptsMessage *readSyncMessage =
        [[OWSCriticalReadReceiptsMessage alloc] initWithReadReceipts:@[criticalReadReceipt]];

    OWSLogInfo(@"%@ will send linked critical read receipt", self.logTag);
    
    [self.messageSender enqueueMessage:readSyncMessage
        success:^{
        OWSLogInfo(@"%@ Successfully sent linked critical read receipt", self.logTag);
    }
                               failure:^(NSError *error) {
        OWSLogError(@"%@ Failed to send critical read receipt to linked devices with error: %@", self.logTag, error);
    }];

}

- (void)handleScheduleMeetingPopupsNotify:(DTApnsInfo *)apnsInfo {
    
    NSDictionary *passthroughInfo = apnsInfo.passthroughInfo;
    
    BOOL isLiveStream = NO;
    NSNumber *number_isLiveStream = passthroughInfo[@"isLiveStream"];
    if (DTParamsUtils.validateNumber(number_isLiveStream)) {
        isLiveStream = number_isLiveStream.boolValue;
    }
    NSString *eid = passthroughInfo[@"eid"];
    
    NSString *emk = passthroughInfo[@"emk"];
    NSNumber *meetingVersion = passthroughInfo[@"meetingVersion"];
    NSString *meetingId = passthroughInfo[@"meetingId"];

    // TODO: 处理预约会议的方法 DTAlertCallTypeSchedule
}

#pragma mark - Table View Data Source

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath
{
    return [self.threadMapping threadForIndexPath:indexPath];
}

#pragma mark - Present Thread

- (void)presentThread:(TSThread *)thread action:(ConversationViewAction)action
{
    [BenchManager startEventWithTitle:@"Presenting Conversation"
                              eventId:[NSString stringWithFormat:@"presenting-conversation-%@", thread.uniqueId]];
    [self presentThread:thread action:action focusMessageId:nil];
}

- (void)presentThread:(TSThread *)thread
               action:(ConversationViewAction)action
       focusMessageId:(nullable NSString *)focusMessageId
{
    if (thread == nil) {
        OWSFailDebug(@"Thread unexpectedly nil");
        return;
    }

    // We do this synchronously if we're already on the main thread.
    DispatchMainThreadSafe(^{
        ConversationViewController *viewController = [[ConversationViewController alloc] initWithThread:thread
                                                                                                 action:action
                                                                                         focusMessageId:focusMessageId
                                                                                            botViewItem:nil
                                                                                               viewMode:ConversationViewMode_Main];
        self.lastViewedThread = thread;

        [self pushTopLevelViewController:viewController animateDismissal:NO animatePresentation:YES];
    });
}

- (void)pushTopLevelViewController:(UIViewController *)viewController
                  animateDismissal:(BOOL)animateDismissal
               animatePresentation:(BOOL)animatePresentation
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewController);

    [self presentViewControllerWithBlock:^{
        [self.navigationController pushViewController:viewController animated:animatePresentation];
    }
                        animateDismissal:animateDismissal];
}

- (void)presentViewControllerWithBlock:(void (^)(void))presentationBlock animateDismissal:(BOOL)animateDismissal
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(presentationBlock);

    // Presenting a "top level" view controller has three steps:
    //
    // First, dismiss any presented modal.
    // Second, pop to the root view controller if necessary.
    // Third present the new view controller using presentationBlock.

    // Define a block to perform the second step.
    void (^dismissNavigationBlock)(void) = ^{
        if (![self.navigationController.viewControllers.lastObject isKindOfClass:NSClassFromString(@"DTHomeViewController")]) {
            [CATransaction begin];
            [CATransaction setCompletionBlock:^{
                presentationBlock();
            }];

            [self.navigationController popToRootViewControllerAnimated:animateDismissal];
            [CATransaction commit];
        } else {
            presentationBlock();
        }
    };

    // Perform the first step.
    if (self.presentedViewController) {
        // NOTE: 修复在展示 PanModalPresentable 弹窗后，退至后台，通过 push 进入其他会话页时，整个 app 布局错乱问题
        BOOL animated = animateDismissal;
        if (self.presentedViewController.isPanModalPresentable) {
            animated = YES;
        }
        [self.presentedViewController dismissViewControllerAnimated:animated completion:dismissNavigationBlock];
    } else {
        dismissNavigationBlock();
    }
}

#pragma mark - Reload Data (全量更新)

- (void)resetMappings {
    OWSLogInfo(@"-------resetMappings----");
    
    [BenchManager startEventWithTitle:@"resetMappings" eventId:@"resetMappings"];
    [self fullUpdateData];
}

- (void)fullUpdateData {
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        [self.threadMapping updateSwallowingErrorsWithIsArchived:self.isViewingArchive
                                                     isCalculate:YES
                                                     transaction:transaction];
    } completion:^{
        [self fullUpdateUI];
    }];
}

- (void)fullUpdateUI {
    [self updateHasArchivedThreadsRow];
    [self reloadTableViewData];
    [self updateViewState];
}

- (void)reloadTableViewData {
    // PERF: come up with a more nuanced cache clearing scheme
    [self.threadViewModelCache removeAllObjects];
    
    @weakify(self)
    [self fullReloadDataWithAnimated:NO completion:^{
        @strongify(self)
        [self resetLastViewedThreadPosition];
        [BenchManager completeEventWithEventId:@"resetMappings"];
    }];
}

- (BOOL)isViewingArchive {
    return self.homeViewMode == HomeViewMode_Archive;
}

#pragma mark - Empty View

- (void)updateViewState
{
//    NSUInteger inboxCount = self.threadMapping.inboxCount;
    NSInteger inboxCount = [self.threadMapping numberOfItemsInSection:HomeViewControllerSectionConversations];
    NSUInteger archiveCount = self.threadMapping.archiveCount;

    if (self.homeViewMode == HomeViewMode_Inbox && inboxCount == 0) {
        [self updateEmptyBoxText];
        if (self.isSelectedFolder) {
            [_emptyBoxView setHidden:NO];
        } else {
            [_emptyBoxView setHidden:(archiveCount != 0)];
        }
    } else if (self.homeViewMode == HomeViewMode_Archive && archiveCount == 0) {
        [self updateEmptyBoxText];
        [_emptyBoxView setHidden:NO];
    } else {
        [_emptyBoxView setHidden:YES];
    }
}

- (void)updateEmptyBoxText
{
    NSString *firstLine = @"";
    if (self.homeViewMode == HomeViewMode_Inbox) {
        if ([Environment.preferences getHasSentAMessage]) {
            //  FIXME: This doesn't appear to ever show up as the defaults flag is never set (setHasSentAMessage: is never called).
            firstLine = Localized(@"EMPTY_INBOX_FIRST_TITLE", @"");
        } else {
            //  FIXME: Misleading localizable string key name.
            if (self.isSelectedFolder) {
                firstLine = Localized(@"CHAT_FOLDER_EMPTY_MESSAGE_TIP", @"");
            } else {
                firstLine = [NSString stringWithFormat:Localized(@"EMPTY_ARCHIVE_FIRST_TITLE", @"First (bolded) part of the label that shows up when there are neither active nor archived conversations"), TSConstants.appDisplayName];
            }
        }
    } else {
        if ([Environment.preferences getHasArchivedAMessage]) {
            //  FIXME: Shows up after the archival tab is cleared up completely by the user, the localizable string key is misleading.
            firstLine = Localized(@"EMPTY_INBOX_TITLE", @"");
        } else {
            firstLine = Localized(@"EMPTY_ARCHIVE_TITLE", @"");
        }
    }
    _emptyBoxView.emptyText = firstLine;
}

#pragma mark - Database Update

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges{
    
    OWSAssertIsOnMainThread();
    
    if (!self.shouldObserveDBModifications) {
        return;
    }
    
    if(!databaseChanges.threadUniqueIds.count){
//        [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
//            [self.threadMapping updateSwallowingErrorsWithIsArchived:self.isViewingArchive
//                                                         isCalculate:NO
//                                                         transaction:transaction];
//        }];
//        [self updateViewState];
        return;
    }
    
    [self anyUIDBDidUpdateWithUpdatedThreadIds:databaseChanges.threadUniqueIds deletedUniqueIds:databaseChanges.interactionDeletedUniqueIds];
    
}

- (void)databaseChangesDidUpdateExternally {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
}

- (void)databaseChangesDidReset {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
    
}

- (void)anyUIDBDidUpdateWithUpdatedThreadIds:(NSSet<NSString *> *)updatedItemIds deletedUniqueIds:(NSSet<NSString *> *)deletedUniqueIds{
    OWSAssertIsOnMainThread();

    if (updatedItemIds.count < 1) {
        // Ignoring irrelevant update.
        [self updateViewState];
        return;
    }
    
    NSMutableSet<NSString *> *needCheckIds = updatedItemIds.mutableCopy;
    NSMutableSet<NSString *> *needUpdatedItemIds = updatedItemIds.mutableCopy;
    if(deletedUniqueIds.count){
        [needCheckIds minusSet:deletedUniqueIds];
    }
    
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        [needCheckIds.allObjects enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ThreadViewModel *_Nullable cachedThreadViewModel = [self.threadViewModelCache objectForKey:obj];
            TSThread *cachedThread = cachedThreadViewModel.threadRecord;
            if(cachedThread){
                TSThread *newThread = [TSThread anyFetchWithUniqueId:obj transaction:transaction];
                if([newThread previewEqualTo:cachedThread]){
                    [needUpdatedItemIds removeObject:obj];
                }
            }
        }];
    }];
    
    if (needUpdatedItemIds.count < 1) {
        return;
    }
    
    if(!self.needUpdatedItemIds.count){
        self.needUpdatedItemIds = needUpdatedItemIds.copy;
    }else{
        NSMutableSet *finalSet = self.needUpdatedItemIds.mutableCopy;
        [finalSet unionSet:needUpdatedItemIds];
        self.needUpdatedItemIds = finalSet.copy;
    }
    
}

- (void)anyUIDBDidUpdateExternally
{
    OWSAssertIsOnMainThread();

    if (self.shouldObserveDBModifications) {
        // External database modifications can't be converted into incremental updates,
        // so rebuild everything.  This is expensive and usually isn't necessary, but
        // there's no alternative.
        //
        // We don't need to do this if we're not observing db modifications since we'll
        // do it when we resume.
        [self updateFiltering];
    }
}

#pragma mark - refresh UI timer (增量更新)

- (void)startRefreshUITimerIfNecessary {
    if (CurrentAppContext().isMainApp) {
        [self stopRefreshUITimer];
        NSUInteger inboxCount = [self.threadMapping inboxCount];
        double timeFactor = MAX(inboxCount / 500.0, 1.0);
        NSTimeInterval timeInterval = 0.5 * timeFactor;
        self.refreshUITimer = [NSTimer weakScheduledTimerWithTimeInterval:timeInterval
                                                                  target:self
                                                                selector:@selector(refreshUI)
                                                                userInfo:nil
                                                                 repeats:YES];
    }
    
}

- (void)stopRefreshUITimer {
    [self.refreshUITimer invalidate];
    self.refreshUITimer = nil;
}

- (void)refreshUI {
    if (self.needUpdatedItemIds.count > 0 && !self.processingUpdatedItems){
        [self incrementRefresh];
    }
}

- (void)incrementRefresh {
    [BenchManager startEventWithTitle:@"uiDatabaseUpdate" eventId:@"uiDatabaseUpdate"];
    
    self.processingUpdatedItems = YES;
    NSSet<NSString *> *updatedItemIds = self.needUpdatedItemIds.copy;
    self.needUpdatedItemIds = nil;
    
    // 删除缓存，触发重新构建 threadViewModel
    for (NSString *key in updatedItemIds) {
        [self.threadViewModelCache removeObjectForKey:key];
    }
    
    // 异步更新 mapping，刷新快照
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        [self.threadMapping updateSwallowingErrorsWithIsArchived:self.isViewingArchive
                                                     isCalculate:YES
                                                     transaction:transaction];
    } completion:^{
        @weakify(self)
        [self diffReloadDataWithForceReloadItemIds:updatedItemIds animated:NO completion:^{
            @strongify(self)
            self.processingUpdatedItems = NO;
            [BenchManager completeEventWithEventId:@"uiDatabaseUpdate"];
        }];
    }];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    scrollView.bounces = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    !self.scrollCallback ?: self.scrollCallback(scrollView);
}

#pragma mark - JXPagingViewListViewDelegate

- (UIView *)listView {
    return self.view;
}

- (UIScrollView *)listScrollView {
    return self.tableView;
}

- (void)listViewDidScrollCallback:(void (^)(UIScrollView *))callback {
    self.scrollCallback = callback;
}

#pragma mark - Theme

- (void)applyTheme
{
    OWSAssertIsOnMainThread();
    [super applyTheme];
    [self.tableView reloadData];

    self.tableView.backgroundColor = Theme.backgroundColor;
    self.tableView.separatorColor = [Theme.cellSeparatorColor colorWithAlphaComponent:0.2];
    [self.emptyBoxView applyTheme];
    
    [self.reminderViewCell applyTheme];
}

- (void)applyLanguage {
    [super applyLanguage];
    [self.tableView reloadData];
}

#pragma mark - addContacts notification

//添加好友
- (void)externalInvite:(NSNotification *)notify {
    OWSLogInfo(@"添加好友 addContactsFromNotify userInfo = %@", notify.userInfo);
    NSDictionary *userInfo = notify.userInfo;
    NSString *inviteCode = userInfo[AppLinkNotificationHandler.inviteCodeKey];
    DTInviteRequestHandler *inviteRequestHandler = [[DTInviteRequestHandler alloc] initWithSourceVc:self];
    [inviteRequestHandler queryUserAccountByInviteCode:inviteCode];
}

#pragma mark - Lazy Load

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [self createTableView];
    }
    return _tableView;
}

- (ThreadMapping *)threadMapping {
    if (!_threadMapping) {
        _threadMapping = [ThreadMapping new];
    }
    return _threadMapping;
}

- (AccountManager *)accountManager {
    return SignalApp.sharedApp.accountManager;
}

- (OWSContactsManager *)contactsManager {
    return Environment.shared.contactsManager;
}

- (OWSBlockingManager *)blockingManager {
    return [OWSBlockingManager sharedManager];
}

- (DTRemoveMembersOfAGroupAPI *)removeMembersOfAGroupAPI{
    if(!_removeMembersOfAGroupAPI){
        _removeMembersOfAGroupAPI = [DTRemoveMembersOfAGroupAPI new];
    }
    return _removeMembersOfAGroupAPI;
}

- (DTDismissAGroupAPI *)dismissAGroupAPI{
    if(!_dismissAGroupAPI){
        _dismissAGroupAPI = [DTDismissAGroupAPI new];
    }
    return _dismissAGroupAPI;
}

@end

NS_ASSUME_NONNULL_END
