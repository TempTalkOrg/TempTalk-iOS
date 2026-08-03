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
#import "TSGroupThread.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSWindowManager.h>
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
#import <JXCategoryView/JXCategoryView.h>
#import "DTThreadHelper.h"
#import "DTHomeVirtualCell.h"
#import "Yelling-Swift.h"
#import "SVProgressHUD.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import "DTInviteRequestHandler.h"
#import <TTMessaging/OWSPreferences.h>
#import "DTCallInviteMemberVC.h"
#import "NewGroupViewController.h"
#import <TTMessaging/TTMessaging-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kReminderViewPseudoGroup = @"kReminderViewPseudoGroup";
NSString *const kArchiveButtonPseudoGroup = @"kArchiveButtonPseudoGroup";
NSString *const kArchivedConversationsReuseIdentifier = @"kArchivedConversationsReuseIdentifier";

static NSString *const kDTShowScreenLockAlertKey = @"showScreenLockAlertKey";
static CGFloat const kSearchBarHeight = 44.0;
static CGFloat const kSearchBarContainerHeight = 59.0;  // kSearchBarHeight + 15

@interface HomeViewController () <OWSQRScannerDelegate, DatabaseChangeDelegate, ActionFloatViewDelegate, OWSNavigationChildController>

// UI Components
@property (nonatomic, strong) HomeEmptyBoxView *emptyBoxView;
@property (nonatomic, strong) HomeReminderViewCell *reminderViewCell;
@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) OWSSearchBar *searchBar;
@property (nonatomic, strong, nullable) DTMessageActionFloatView *actionFloatView;
@property (nonatomic, strong) UIImageView *avatarStateImageView;

// State
@property (nonatomic, assign) BOOL isViewVisible;
@property (nonatomic, assign) BOOL shouldObserveDBModifications;
@property (nonatomic, assign) BOOL hasBeenPresented;
@property (nonatomic, assign) BOOL viewDidAppear;

// Data
@property (nonatomic, strong) NSSet<NSString *> *blockedPhoneNumberSet;
@property (nonatomic, strong) NSCache<NSString *, ThreadViewModel *> *threadViewModelCache;
@property (nonatomic, strong, nullable) NSIndexPath *updateIndexPath;
@property (nonatomic, strong, nullable) NSIndexPath *preLastThreadIndexPath;
@property (nonatomic, strong, nullable) NSSet<NSString *> *needUpdatedItemIds;
@property (nonatomic, assign) BOOL processingUpdatedItems;

// Timer
@property (nonatomic, nullable) NSTimer *refreshUITimer;

// APIs
@property (nonatomic, strong) DTRemoveMembersOfAGroupAPI *removeMembersOfAGroupAPI;
@property (nonatomic, strong) DTDismissAGroupAPI *dismissAGroupAPI;

// Dependencies (readonly)
@property (nonatomic, readonly) AccountManager *accountManager;
@property (nonatomic, readonly) OWSBlockingManager *blockingManager;
@property (nonatomic, readonly) UIView *missingContactsPermissionView;

@end

@interface OWSWindowManager (HomeViewControllerPresenting)
- (void)ensureRootWindowShown;
@end

#pragma mark -

@implementation HomeViewController

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    
    _viewDidAppear = NO;
    _homeViewMode = HomeViewMode_Inbox;
    [self commonInit];
    
    return self;
}

- (void)commonInit {
    _blockedPhoneNumberSet = [NSSet setWithArray:[self.blockingManager blockedPhoneNumbers]];
    _threadViewModelCache = [NSCache new];
    _preLastThreadIndexPath = nil;
}

- (void)dealloc {
    [self stopRefreshUITimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View Life Cycle

- (void)loadView {
    [super loadView];
    
    [self setupReminderCell];
    [self setupSearchBarContainer];
    [self setupTableView];
    [self setupEmptyBoxView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNavigationTitle];
    [self setupTableViewFooter];
    [self addNotificationObserver];
    [self updateBarButtonItems];
    [self socketStateDidChange];
    [self updateViewState];
    [self updateReminderViews];
    [self applyTheme];
    [self stickNoteToSelfIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.isViewVisible = YES;
    // Refresh the proxy shield in case the proxy was toggled on the settings page.
    [self updateBarButtonItems];

    OWSLogInfo(@"[homevc] home vc viewWillAppear");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _viewDidAppear = YES;
    
    if (!CurrentAppContext().isMainAppAndActive) {
        OWSLogWarn(@"viewDidAppear: app not active");
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && CurrentAppContext().isMainAppAndActive) {
                [strongSelf handleRemoteNotify:[PushManager sharedManager].apnsInfo];
            }
        });
        return;
    }
    
    [self handleRemoteNotify:[PushManager sharedManager].apnsInfo];
    [self checkIfNeedShowScreenLockAlert];
    
    OWSLogInfo(@"[homevc] home vc viewDidAppear");
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.actionFloatView hide:YES];
    self.isViewVisible = NO;
    _viewDidAppear = NO;
}

#pragma mark - Properties (Lazy Load)

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [self createTableView];
        _tableView.bounces = YES;
        _tableView.showsVerticalScrollIndicator = NO;
    }
    return _tableView;
}

- (ThreadMapping *)threadMapping {
    if (!_threadMapping) {
        _threadMapping = [ThreadMapping new];
    }
    return _threadMapping;
}

- (UIView *)searchBarContainer {
    if (!_searchBarContainer) {
        _searchBarContainer = [UIView new];
        _searchBarContainer.backgroundColor = Theme.bgpagePrimaryColor;
    }
    return _searchBarContainer;
}

- (OWSSearchBar *)searchBar {
    if (!_searchBar) {
        _searchBar = [OWSSearchBar new];
        _searchBar.customPlaceholder = Localized(@"HOME_VIEW_CONVERSATION_SEARCHBAR_PLACEHOLDER",
                                                 @"Placeholder text for search bar which filters conversations.");
        [_searchBar sizeToFit];
        
        UIButton *btnSearch = [UIButton buttonWithType:UIButtonTypeSystem];
        btnSearch.userInteractionEnabled = YES;
        [btnSearch addTarget:self action:@selector(showSeachViewController) forControlEvents:UIControlEventTouchUpInside];
        [_searchBar addSubview:btnSearch];
        [btnSearch autoPinEdgesToSuperviewEdges];
    }
    return _searchBar;
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

- (DTRemoveMembersOfAGroupAPI *)removeMembersOfAGroupAPI {
    if (!_removeMembersOfAGroupAPI) {
        _removeMembersOfAGroupAPI = [DTRemoveMembersOfAGroupAPI new];
    }
    return _removeMembersOfAGroupAPI;
}

- (DTDismissAGroupAPI *)dismissAGroupAPI {
    if (!_dismissAGroupAPI) {
        _dismissAGroupAPI = [DTDismissAGroupAPI new];
    }
    return _dismissAGroupAPI;
}

#pragma mark - Layout Setup

- (void)setupReminderCell {
    self.reminderViewCell = [self createReminderCell];
}

- (void)setupSearchBarContainer {
    [self.view addSubview:self.searchBarContainer];
    [self.searchBarContainer autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [self.searchBarContainer autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self.searchBarContainer autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [self.searchBarContainer autoSetDimension:ALDimensionHeight toSize:kSearchBarContainerHeight];
    
    [self.searchBarContainer addSubview:self.searchBar];
    [self.searchBar autoPinEdgesToSuperviewEdges];
}

- (void)setupTableView {
    [self.view addSubview:self.tableView];
    [self.tableView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.searchBarContainer];
    [self.tableView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
    [self.tableView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self.tableView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    
    self.tableView.tableHeaderView = nil;
}

- (void)setupEmptyBoxView {
    HomeEmptyBoxView *emptyBoxView = [HomeEmptyBoxView new];
    _emptyBoxView = emptyBoxView;
    self.tableView.backgroundView = emptyBoxView;
}

- (void)setupNavigationTitle {
    if ([TSAccountManager sharedInstance].isNewRegister) {
        OWSLogInfo(@"is newRegister");
    } else {
        OWSLogInfo(@"not newRegister");
        self.leftTitle = [NSString stringWithFormat:@"%@...", Localized(@"NETWORK_STATUS_CONNECTING", @"")];
    }
    
    if (self.homeViewMode == HomeViewMode_Archive) {
        self.navigationItem.title = Localized(@"HOME_VIEW_TITLE_ARCHIVE", @"");
    }
}

- (void)setupTableViewFooter {
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

#pragma mark - Navigation Bar

- (void)updateBarButtonItems {
    if (self.homeViewMode != HomeViewMode_Inbox) {
        return;
    }
    
    UIImage *barAddImage = [UIImage imageNamed:@"barbuttonicon_add"];
    OWSAssertDebug(barAddImage);
    UIBarButtonItem *barAddButton = [[UIBarButtonItem alloc] initWithImage:barAddImage
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(showActionFloatView:)];
    barAddButton.accessibilityLabel = Localized(@"CREATE_NEW_GROUP", @"Accessibility label for the create group new group button");

    // rightBarButtonItems are laid out right-to-left, so the proxy shield (when shown) sits to
    // the left of the "+" button (mirrors the Android shield). The shield's horizontal
    // offset toward the "+" is done via imageInsets in proxyStatusBarButtonItem — negative
    // fixed-space items are ignored by the Auto Layout nav bar on iOS 11+.
    NSMutableArray<UIBarButtonItem *> *rightItems = [NSMutableArray arrayWithObject:barAddButton];
    UIBarButtonItem *proxyShield = [self proxyStatusBarButtonItem];
    if (proxyShield) {
        [rightItems addObject:proxyShield];
    }
    self.navigationItem.rightBarButtonItems = rightItems;
}

// Proxy status shield: hidden when the proxy is off; green check when connected through the proxy,
// gray ✕ otherwise. Two states only — connectivity is derived from the main IM socket:
// proxy-on means all traffic is tunneled, so "socket open" means "connected through the proxy",
// and connecting/closed both read as not-yet-connected. Icons are full-color Figma assets, so
// they render as original (no tint).
- (nullable UIBarButtonItem *)proxyStatusBarButtonItem {
    if (![ProxyManager.shared isEnabled]) {
        return nil;
    }
    // Green only when the tunnel is actually running AND the main socket is open. Fail-closed
    // routing means a socket can only ever open THROUGH the proxy (proxy-on-but-not-ready returns a
    // fail-closed socket that never connects), so an open socket genuinely means "through the
    // proxy"; also requiring the running tunnel guards the teardown window (startedPort briefly 0)
    // from showing a false "protected". Otherwise gray ✕.
    BOOL tunnelRunning = ([ProxyManager.shared connectionProxyDictionary] != nil);
    BOOL connected = tunnelRunning && (self.socketManager.socketState == OWSWebSocketStateOpen);
    NSString *imageName = connected ? @"ic_proxy_shield_connected" : @"ic_proxy_shield_unavailable";
    UIImage *image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!image) {
        return nil;
    }
    // Use a customView button sized tight to the 24pt icon. A plain image bar button reserves a
    // ~44pt touch slot whose wide white padding pushes the icon left and opens a big gap to "+";
    // a tight customView removes that padding so the shield sits close to "+".
    UIButton *shieldButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [shieldButton setImage:image forState:UIControlStateNormal];
    shieldButton.frame = CGRectMake(0, 0, 24, 24);
    shieldButton.adjustsImageWhenHighlighted = NO;   // no dim animation on tap, jump straight in
    [shieldButton addTarget:self action:@selector(proxyShieldTapped) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:shieldButton];
    item.accessibilityLabel = Localized(@"PROXY_USE_PROXY", @"");
    return item;
}

- (void)proxyShieldTapped {
    DTProxySettingsViewController *proxyVC = [DTProxySettingsViewController new];
    proxyVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:proxyVC animated:YES];
}

- (void)settingsButtonPressed:(id)sender {
    OWSNavigationController *navigationController = [AppSettingsViewController inModalNavigationController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - SearchBar

- (void)showSeachViewController {
    ConversationSearchViewController *searchResultsController = [ConversationSearchViewController new];
    searchResultsController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:searchResultsController animated:YES];
}

#pragma mark - Action Float View

- (void)setupActionFloatView {
    // 先移除旧的
    if (_actionFloatView) {
        [_actionFloatView removeFromSuperview];
        _actionFloatView = nil;
    }
    
    DTMessageActionFloatView *actionFloatView = [DTMessageActionFloatView new];
    actionFloatView.delegate = self;
    [actionFloatView layoutSubContent];
    _actionFloatView = actionFloatView;
    
    [self.view addSubview:_actionFloatView];
    [actionFloatView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
    [actionFloatView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
}

- (void)showActionFloatView:(id)sender {
    if (self.actionFloatView && !self.actionFloatView.hidden) {
        [self.actionFloatView hide:YES];
        return;
    }
    
    [self setupActionFloatView];
    self.actionFloatView.hidden = NO;
}

- (void)showNewGroupView {
    SignalApp.sharedApp.homeViewController = self;
    NewGroupViewController *newGroupViewController = [NewGroupViewController new];
    [self.navigationController pushViewController:newGroupViewController animated:YES];
}

#pragma mark - ActionFloatViewDelegate

- (void)floatViewTapItemIndex:(enum ActionFloatViewItemType)type {
    if (self.isUserDeregistered) return;
    
    switch (type) {
        case ActionFloatViewItemTypeCreateGroup:
            [self showNewGroupView];
            break;
            
        case ActionFloatViewItemTypeScan: {
            DTScanQRCodeController *scanQRCodeController = [DTScanQRCodeController new];
            @weakify(self);
            scanQRCodeController.didReceiveHandler = ^(NSURL *url) {
                @strongify(self);
                [self showDeviceTransfer:url];
            };
            [self.navigationController pushViewController:scanQRCodeController animated:YES];
            break;
        }
            
        case ActionFloatViewItemTypeAddContacts: {
            EnterCodeViewController *enterCodeVc = [EnterCodeViewController new];
            [self.navigationController pushViewController:enterCodeVc animated:YES completion:nil];
            break;
        }
            
        case ActionFloatViewItemTypeMyCode: {
            DTInviteCodeViewController *inviteCodeViewController = [DTInviteCodeViewController new];
            OWSNavigationController *navController = [[OWSNavigationController alloc] initWithRootViewController:inviteCodeViewController];
            [self.navigationController presentViewController:navController animated:YES completion:nil];
            break;
        }
            
        default:
            break;
    }
}

- (void)floatViewDidRemoveFromSuperView {
    self.actionFloatView = nil;
}

- (void)showDeviceTransfer:(NSURL *_Nonnull)url {
    NSError *error;
    DeviceTransferURLComponent *urlComponent = [[DeviceTransferService shared] parseTransferURL:url error:&error];
    if (error || urlComponent == nil) return;
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:Localized(@"Transfer Data", @"")
                                          message:[NSString stringWithFormat:Localized(@"Are you sure to transfer all your data to this device: %1$@?", @""), urlComponent.peerId.displayName]
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"Cancel", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:NULL];
    
    UIAlertAction *confimAction = [UIAlertAction actionWithTitle:Localized(@"Yes", @"")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        if ([DeviceTransferService.shared launchCleanup]) {
            [self beginTransferData:urlComponent];
        } else {
            OWSLogInfo(@"launchCleanup failed");
        }
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:confimAction];
    [self.navigationController presentViewController:alertController animated:YES completion:NULL];
}

- (void)beginTransferData:(DeviceTransferURLComponent *)urlComponent {
    DTTransferringDataViewController *transferringController = [[DTTransferringDataViewController alloc] initWithLogintoken:nil urlComponent:urlComponent oldDevice:YES];
    DTTransferNavgationController *navgationController = [[DTTransferNavgationController alloc] initWithRootViewController:transferringController];
    [navgationController setModalPresentationStyle:UIModalPresentationFullScreen];
    [self.navigationController presentViewController:navgationController animated:YES completion:NULL];
}

#pragma mark - Socket State

- (void)socketStateDidChange {
    // Keep the proxy shield in sync with the live connection state.
    [self updateBarButtonItems];

    if (TSAccountManager.sharedInstance.isDeregistered) {
        self.leftTitle = Localized(@"NETWORK_STATUS_DEREGISTERED", @"");
        return;
    }
    
    if (![Reachability reachabilityForInternetConnection].isReachable) {
        self.leftTitle = Localized(@"NETWORK_STATUS_OFFLINE", @"");
        return;
    }
    
    OWSWebSocketState socketState = self.socketManager.socketState;
    switch (socketState) {
        case OWSWebSocketStateClosed:
            self.leftTitle = Localized(@"NETWORK_STATUS_OFFLINE", @"");
            break;
        case OWSWebSocketStateConnecting:
            self.leftTitle = [NSString stringWithFormat:@"%@...", Localized(@"NETWORK_STATUS_CONNECTING", @"")];
            break;
        case OWSWebSocketStateOpen:
            self.leftTitle = Localized(@"TABBAR_HOME", @"Title for the home view's default mode.");
            break;
    }
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack {
    return YES;
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    return Theme.bgpagePrimaryColor;
}

- (BOOL)prefersNavigationBarHidden {
    return NO;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
}

#pragma mark - View State

- (void)setIsViewVisible:(BOOL)isViewVisible {
    _isViewVisible = isViewVisible;
    [self updateShouldObserveDBModifications];
}

- (void)updateShouldObserveDBModifications {
    BOOL isAppForegroundAndActive = CurrentAppContext().isAppForegroundAndActive;
    self.shouldObserveDBModifications = self.isViewVisible && isAppForegroundAndActive;
}

- (void)setShouldObserveDBModifications:(BOOL)shouldObserveDBModifications {
    if (_shouldObserveDBModifications == shouldObserveDBModifications) {
        return;
    }
    
    _shouldObserveDBModifications = shouldObserveDBModifications;
    
    if (shouldObserveDBModifications) {
        [self resetMappings];
        [self startRefreshUITimerIfNecessary];
    } else {
        [self stopRefreshUITimer];
    }
}

- (BOOL)hidesBottomBarWhenPushed {
    return self.homeViewMode != HomeViewMode_Inbox;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Notifications

- (void)addNotificationObserver {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self
               selector:@selector(signalAccountsDidChange:)
                   name:OWSContactsManagerSignalAccountsDidChangeNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationWillEnterForeground:)
                   name:OWSApplicationWillEnterForegroundNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive:)
                   name:OWSApplicationDidBecomeActiveNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationWillResignActive:)
                   name:OWSApplicationWillResignActiveNotification
                 object:nil];
    
    [self.databaseStorage appendDatabaseChangeDelegate:self];
    
    [center addObserver:self
               selector:@selector(deregistrationStateDidChange:)
                   name:NSNotificationNameDeregistrationStateDidChange
                 object:nil];
    
    [center addObserver:self
               selector:@selector(outageStateDidChange:)
                   name:OutageDetection.outageStateDidChange
                 object:nil];
    
    [center addObserver:self
               selector:@selector(didReceiveRemoteNotification:)
                   name:kDTDidReceiveRemoteNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(didReceiveGroupPeriodicRemindNotification:)
                   name:DTGroupPeriodicRemindNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(didReceiveMarkAsUnreadNotification:)
                   name:DTMarkAsUnreadNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(externalInvite:)
                   name:AppLinkNotificationHandler.externalInviteNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(criticalAlertHighlightDidChange:)
                   name:DTCriticalAlertHighlightDidChangeNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(socketStateDidChange)
                   name:OWSWebSocket.webSocketStateDidChange
                 object:nil];
    
    [center addObserver:self
               selector:@selector(tabBarItemDoubleClickNotification:)
                   name:kTabBarItemDoubleClickNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(groupCryptoKeyDidArrive:)
                   name:DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(groupAvatarDidChange:)
                   name:TSGroupThreadAvatarChangedNotification
                 object:nil];
}

- (void)signalAccountsDidChange:(id)notification {
    // 联系人/备注名变化可能影响任意行，全量刷新
    [self invalidateCellsForThreadIds:nil];
}

- (void)groupCryptoKeyDidArrive:(NSNotification *)notification {
    NSString *gid = notification.userInfo[DTGroupCryptoConstants.groupCryptoKeyGidKey];
    NSString *threadId = [self threadIdFromServerGroupId:gid];
    if (!threadId.length) {
        OWSLogWarn(@"groupCryptoKeyDidArrive: invalid gid=%@", gid);
        return;
    }
    [self invalidateCellsForThreadIds:[NSSet setWithObject:threadId]];
}

- (void)groupAvatarDidChange:(NSNotification *)notification {
    NSString *threadId = notification.userInfo[TSGroupThread_NotificationKey_UniqueId];
    if (!threadId.length) {
        OWSLogWarn(@"groupAvatarDidChange: missing threadId");
        return;
    }
    [self invalidateCellsForThreadIds:[NSSet setWithObject:threadId]];
}

- (void)invalidateCellsForThreadIds:(nullable NSSet<NSString *> *)threadIds {
    OWSAssertIsOnMainThread();

    if (threadIds.count == 0) {
        [self.threadViewModelCache removeAllObjects];
        [self fullReloadDataWithAnimated:NO completion:nil];
    } else {
        for (NSString *threadId in threadIds) {
            [self.threadViewModelCache removeObjectForKey:threadId];
        }
        [self diffReloadDataWithForceReloadItemIds:threadIds animated:NO completion:nil];
    }
}

- (nullable NSString *)threadIdFromServerGroupId:(nullable NSString *)gid {
    if (!gid.length) { return nil; }
    NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:gid];
    if (!groupId) { return nil; }
    return [TSGroupThread threadIdFromGroupId:groupId];
}

- (void)deregistrationStateDidChange:(id)notification {
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"deregistrationStateDidChange.");
    [self updateReminderViews];
    
    [OWSDevicesService checkIfKickedOffComplete:^(BOOL kickedOff) {
        if (kickedOff) {
            [RegistrationUtils kickedOffToRegistration];
        }
    }];
}

- (void)outageStateDidChange:(id)notification {
    OWSAssertIsOnMainThread();
    [self updateReminderViews];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self updateViewState];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updateShouldObserveDBModifications];
    
    __block BOOL hasAnyMessages;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        hasAnyMessages = [self hasAnyMessagesWithTransaction:transaction];
    }];
    
    if (hasAnyMessages) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateReminderViews];
        });
    }
    
    if ([TSAccountManager isRegistered]) {
        [[DTConversationsJob sharedJob] startIfNecessary];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self updateShouldObserveDBModifications];
}

- (void)didReceiveRemoteNotification:(NSNotification *)notify {
    [self handleRemoteNotify:notify.userInfo[@"apnsInfo"]];
}

- (void)didReceiveGroupPeriodicRemindNotification:(NSNotification *)noti {
    if (!noti.object) return;
    
    BOOL isChanged = [noti.userInfo[@"isChanged"] boolValue];
    if (!isChanged) return;
    
    TSThread *targetThread = (TSThread *)noti.object;
    __block BOOL hasUnread = NO;
    NSArray<NSString *> *allUnreadThreadIds = [DTThreadHelper sharedManager].unreadThreadCache.allKeys;
    
    for (NSString *obj in allUnreadThreadIds) {
        if ([obj hasPrefix:@"+"]) {
            continue;
        }
        if ([obj isEqualToString:targetThread.serverThreadId]) {
            hasUnread = YES;
            break;
        }
    }
    
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
    if (!noti.object) return;
    
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

- (void)externalInvite:(NSNotification *)notify {
    OWSLogInfo(@"添加好友 addContactsFromNotify userInfo = %@", notify.userInfo);
    NSDictionary *userInfo = notify.userInfo;
    NSString *inviteCode = userInfo[AppLinkNotificationHandler.inviteCodeKey];
    DTInviteRequestHandler *inviteRequestHandler = [[DTInviteRequestHandler alloc] initWithSourceVc:self];
    [inviteRequestHandler queryUserAccountByInviteCode:inviteCode];
}

- (void)criticalAlertHighlightDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fullReloadDataWithAnimated:NO completion:nil];
    });
}

- (void)tabBarItemDoubleClickNotification:(NSNotification *)notify {
    NSDictionary *userInfo = notify.userInfo;
    NSNumber *numberSelectedIndex = userInfo[@"selectedIndex"];
    NSUInteger selectedIndex = numberSelectedIndex.unsignedIntegerValue;
    
    if (selectedIndex != 0) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToNextUnreadConversation];
    });
}

#pragma mark - APNs

- (void)handleRemoteNotify:(DTApnsInfo *)apnsInfo {
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
    
    [[DTMeetingManager shared] handleRemoteCallNotifyWithApnsInfo:apnsInfo];
    
    NSString *conversationId = apnsInfo.conversationId;
    if (!conversationId.length) {
        OWSLogInfo(@"conversationId is nil, no need to open conversation");
        return;
    }
    
    [self sendCriticalReadSyncMessageWithApnsInfo:apnsInfo];
    
    __block TSThread *thread = nil;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        thread = [TSContactThread getThreadWithContactId:conversationId transaction:transaction];
        if (!thread) {
            NSData *groupId = [NSData dataFromBase64String:conversationId];
            if (groupId && groupId.length > 0) {
                thread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
            }
        }
    }];

    // Check if thread was found
    if (!thread) {
        OWSLogError(@"Could not find thread for conversationId: %@", conversationId);
        return;
    }

    id cvc = self.navigationController.viewControllers.lastObject;
    if ([cvc isKindOfClass:ConversationViewController.class]) {
        ConversationViewController *conversationVC = (ConversationViewController *)cvc;
        TSThread *openedThread = conversationVC.thread;
        if (openedThread && [openedThread.uniqueId isEqualToString:thread.uniqueId]) {
            OWSLogInfo(@"topvc is same conversationvc, no need to reopen");
            [conversationVC resetContentAndLayoutWithSneakyTransaction];
            return;
        }
    }
    
    if (self.tabBarController.selectedIndex != 0) {
        UIViewController *selectedVC = self.tabBarController.selectedViewController;
        if ([selectedVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *selectedNav = (UINavigationController *)selectedVC;
            if (selectedNav.viewControllers.count > 0) {
                [selectedNav popToRootViewControllerAnimated:NO];
            }
        }
        self.tabBarController.selectedIndex = 0;
    }

    if (thread) {
        [self presentThread:thread action:ConversationViewActionNone];
    }
}

- (void)sendCriticalReadSyncMessageWithApnsInfo:(DTApnsInfo *)apnsInfo {
    NSString *_Nullable interruptionLevel = apnsInfo.interruptionLevel;
    NSString *_Nullable msg = apnsInfo.msg;
    
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
    
    OWSLinkedDeviceReadReceipt *criticalReadReceipt = [[OWSLinkedDeviceReadReceipt alloc] initWithSenderId:senderId
                                                                                       messageIdTimestamp:timestamp
                                                                                            readTimestamp:0];
    OWSCriticalReadReceiptsMessage *readSyncMessage = [[OWSCriticalReadReceiptsMessage alloc] initWithReadReceipts:@[criticalReadReceipt]];
    
    OWSLogInfo(@"%@ will send linked critical read receipt", self.logTag);
    
    __weak typeof(self) weakSelf = self;
    [self.messageSender enqueueMessage:readSyncMessage
                               success:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        OWSLogInfo(@"%@ Successfully sent linked critical read receipt", strongSelf.logTag);
    }
                               failure:^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        OWSLogError(@"%@ Failed to send critical read receipt to linked devices with error: %@", strongSelf.logTag, error);
    }];
}

- (void)handleScheduleMeetingPopupsNotify:(DTApnsInfo *)apnsInfo {
    NSDictionary *passthroughInfo = apnsInfo.passthroughInfo;
    
    BOOL isLiveStream = NO;
    NSNumber *number_isLiveStream = passthroughInfo[@"isLiveStream"];
    if (DTParamsUtils.validateNumber(number_isLiveStream)) {
        isLiveStream = number_isLiveStream.boolValue;
    }
}

#pragma mark - Screen Lock Alert

- (void)checkIfNeedShowScreenLockAlert {
    NSString *firstVersion = [AppVersion shared].firstAppVersion;
    NSString *targetVersion = @"3.1.4";
    
    BOOL oldLockEnable = [ScreenLock sharedManager].old_isScreenLockEnabled || [OWS2FAManager.sharedManager is2FAEnabled];
    
    if (![self screenLockAlertFlag] &&
        [firstVersion compare:targetVersion options:NSNumericSearch] == NSOrderedAscending &&
        oldLockEnable) {
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:[Localize localized:@"SCREENLOCK_UPGRADE_TITLE"]
                                              message:[NSString stringWithFormat:[Localize localized:@"SCREENLOCK_UPGRADE_TIPS"], TSConstants.appDisplayName]
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *ignoreAction = [UIAlertAction actionWithTitle:[Localize localized:@"SCREENLOCK_UPGRADE_IGNORE"]
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *_Nonnull action) {
            [self markScreenLockAlertFlag];
        }];
        
        UIAlertAction *checkAction = [UIAlertAction actionWithTitle:[Localize localized:@"SCREENLOCK_UPGRADE_CHECK"]
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

- (BOOL)screenLockAlertFlag {
    return [CurrentAppContext().appUserDefaults boolForKey:kDTShowScreenLockAlertKey];
}

- (void)markScreenLockAlertFlag {
    [CurrentAppContext().appUserDefaults setBool:YES forKey:kDTShowScreenLockAlertKey];
    [CurrentAppContext().appUserDefaults synchronize];
}

#pragma mark - UITableViewDataSource

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath {
    return [self.threadMapping threadForIndexPath:indexPath];
}

- (BOOL)hasAnyMessagesWithTransaction:(SDSAnyReadTransaction *)transaction {
    return [TSThread anyCountWithTransaction:transaction] > 0;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // bounces 和 showsVerticalScrollIndicator 已在 tableView getter 中设置
}

#pragma mark - Present Thread

- (void)presentThread:(TSThread *)thread action:(ConversationViewAction)action {
    [BenchManager startEventWithTitle:@"Presenting Conversation"
                              eventId:[NSString stringWithFormat:@"presenting-conversation-%@", thread.uniqueId]];
    [self presentThread:thread action:action focusMessageId:nil];
}

- (void)presentThread:(TSThread *)thread
               action:(ConversationViewAction)action
       focusMessageId:(nullable NSString *)focusMessageId {
    if (thread == nil) {
        OWSFailDebug(@"Thread unexpectedly nil");
        return;
    }

    DispatchMainThreadSafe(^{
        if (!self.isViewLoaded) {
            OWSLogWarn(@"View not loaded, loading now");
            [self loadViewIfNeeded];
        }

        if (!self.navigationController) {
            OWSLogError(@"NavigationController is nil, cannot present thread");
            return;
        }

        if (!self.isViewVisible && CurrentAppContext().isMainAppAndActive) {
            OWSLogWarn(@"Forcing isViewVisible = YES before presentation");
            self.isViewVisible = YES;
        }

        ConversationViewController *viewController = [[ConversationViewController alloc] initWithThread:thread
                                                                                                 action:action
                                                                                         focusMessageId:focusMessageId
                                                                                            botViewItem:nil
                                                                                               viewMode:ConversationViewMode_Main isFromPersonalCard:false];
        self.lastViewedThread = thread;
        
        OWSLogInfo(@"[Conversation] Before push: nav class=%@", NSStringFromClass(self.navigationController.class));
        
        if (self.presentedViewController) {
            [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
                [self.navigationController pushViewController:viewController animated:YES];
            }];
        } else {
            [self.navigationController pushViewController:viewController animated:YES];
        }
    });
}

#pragma mark - Data Update (Full Reload)

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
    } completionQueue:dispatch_get_main_queue() completion:^{
        [self fullUpdateUI];
    }];
}

- (void)fullUpdateUI {
    [self updateHasArchivedThreadsRow];
    [self reloadTableViewData];
    [self updateViewState];
}

- (void)reloadTableViewData {
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

#pragma mark - Data Update (Incremental)

- (void)startRefreshUITimerIfNecessary {
    if (!CurrentAppContext().isMainApp) return;
    
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

- (void)stopRefreshUITimer {
    [self.refreshUITimer invalidate];
    self.refreshUITimer = nil;
}

- (void)refreshUI {
    if (self.needUpdatedItemIds.count > 0 && !self.processingUpdatedItems) {
        [self incrementRefresh];
    }
}

- (void)incrementRefresh {
    [BenchManager startEventWithTitle:@"uiDatabaseUpdate" eventId:@"uiDatabaseUpdate"];
    
    self.processingUpdatedItems = YES;
    NSSet<NSString *> *updatedItemIds = self.needUpdatedItemIds.copy;
    self.needUpdatedItemIds = nil;
    
    for (NSString *key in updatedItemIds) {
        [self.threadViewModelCache removeObjectForKey:key];
    }
    
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

#pragma mark - DatabaseChangeDelegate

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges {
    OWSAssertIsOnMainThread();
    
    if (!self.shouldObserveDBModifications) {
        return;
    }

    // Early return if there are no thread changes (neither updates nor deletes)
    BOOL hasThreadUpdates = databaseChanges.threadUniqueIds.count > 0;
    BOOL hasThreadDeletes = databaseChanges.threadDeletedUniqueIds.count > 0;

    if (!hasThreadUpdates && !hasThreadDeletes) {
        return;
    }

    [self anyUIDBDidUpdateWithUpdatedThreadIds:databaseChanges.threadUniqueIds
                       threadDeletedUniqueIds:databaseChanges.threadDeletedUniqueIds
                      interactionDeletedUniqueIds:databaseChanges.interactionDeletedUniqueIds];
}

- (void)databaseChangesDidUpdateExternally {
    OWSAssertIsOnMainThread();
    [self anyUIDBDidUpdateExternally];
}

- (void)databaseChangesDidReset {
    OWSAssertIsOnMainThread();
    [self anyUIDBDidUpdateExternally];
}

- (void)anyUIDBDidUpdateWithUpdatedThreadIds:(NSSet<NSString *> *)updatedItemIds
                       threadDeletedUniqueIds:(NSSet<NSString *> *)threadDeletedUniqueIds
                      interactionDeletedUniqueIds:(NSSet<NSString *> *)interactionDeletedUniqueIds {
    OWSAssertIsOnMainThread();

    // If threads were deleted, we need to reload the entire list
    if (threadDeletedUniqueIds.count > 0) {
        OWSLogInfo(@"Threads deleted: %lu, reloading data", (unsigned long)threadDeletedUniqueIds.count);
        [self resetMappings];
        return;
    }

    if (updatedItemIds.count < 1) {
        [self updateViewState];
        return;
    }

    NSMutableSet<NSString *> *needCheckIds = updatedItemIds.mutableCopy;
    NSMutableSet<NSString *> *needUpdatedItemIds = updatedItemIds.mutableCopy;

    if (interactionDeletedUniqueIds.count) {
        [needCheckIds minusSet:interactionDeletedUniqueIds];
    }

    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        for (NSString *obj in needCheckIds.allObjects) {
            ThreadViewModel *_Nullable cachedThreadViewModel = [self.threadViewModelCache objectForKey:obj];
            TSThread *cachedThread = cachedThreadViewModel.threadRecord;
            if (cachedThread) {
                TSThread *newThread = [TSThread anyFetchWithUniqueId:obj transaction:transaction];
                if ([newThread previewEqualTo:cachedThread]) {
                    [needUpdatedItemIds removeObject:obj];
                }
            }
        }
    }];

    if (needUpdatedItemIds.count < 1) {
        // 即使没有需要更新的项目，也应该检查是否需要更新视图状态
        // 例如：interactions 被删除后，可能影响 thread 预览，需要更新视图状态
        if (interactionDeletedUniqueIds.count > 0) {
            [self updateViewState];
        }
        return;
    }

    if (!self.needUpdatedItemIds.count) {
        self.needUpdatedItemIds = needUpdatedItemIds.copy;
    } else {
        NSMutableSet *finalSet = self.needUpdatedItemIds.mutableCopy;
        [finalSet unionSet:needUpdatedItemIds];
        self.needUpdatedItemIds = finalSet.copy;
    }
}

- (void)anyUIDBDidUpdateExternally {
    OWSAssertIsOnMainThread();
}

#pragma mark - Empty View

- (void)updateViewState {
    NSInteger inboxCount = [self.threadMapping numberOfItemsInSection:HomeViewControllerSectionConversations];
    NSUInteger archiveCount = self.threadMapping.archiveCount;
    
    if (self.homeViewMode == HomeViewMode_Inbox && inboxCount == 0) {
        [self updateEmptyBoxText];
        [_emptyBoxView setHidden:(archiveCount != 0)];
    } else if (self.homeViewMode == HomeViewMode_Archive && archiveCount == 0) {
        [self updateEmptyBoxText];
        [_emptyBoxView setHidden:NO];
    } else {
        [_emptyBoxView setHidden:YES];
    }
}

- (void)updateEmptyBoxText {
    NSString *firstLine = @"";
    
    if (self.homeViewMode == HomeViewMode_Inbox) {
        if ([Environment.preferences getHasSentAMessage]) {
            firstLine = Localized(@"EMPTY_INBOX_FIRST_TITLE", @"");
        } else {
            firstLine = [NSString stringWithFormat:Localized(@"EMPTY_ARCHIVE_FIRST_TITLE", @""), TSConstants.appDisplayName];
        }
    } else {
        if ([Environment.preferences getHasArchivedAMessage]) {
            firstLine = Localized(@"EMPTY_INBOX_TITLE", @"");
        } else {
            firstLine = Localized(@"EMPTY_ARCHIVE_TITLE", @"");
        }
    }
    
    _emptyBoxView.emptyText = firstLine;
}

#pragma mark - Theme

- (void)applyTheme {
    OWSAssertIsOnMainThread();
    [super applyTheme];
    
    self.tableView.backgroundColor = Theme.bgpagePrimaryColor;
    self.tableView.separatorColor = [Theme.dividerColor colorWithAlphaComponent:0.2];
    self.searchBarContainer.backgroundColor = Theme.bgpagePrimaryColor;
    self.searchBar.backgroundColor = Theme.bgpagePrimaryColor;
    
    [self.emptyBoxView applyTheme];
    [self.reminderViewCell applyTheme];
    [self fullReloadDataWithAnimated:NO completion:nil];
}

- (void)applyLanguage {
    [super applyLanguage];
    
    [self socketStateDidChange];
    [self setupActionFloatView];
    [self fullReloadDataWithAnimated:NO completion:nil];
}

@end

NS_ASSUME_NONNULL_END
