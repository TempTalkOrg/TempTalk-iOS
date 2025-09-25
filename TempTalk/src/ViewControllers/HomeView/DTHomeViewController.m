//
//  DTHomeViewController.m
//  Signal
//
//  Created by Ethan on 2022/10/19.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTHomeViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <JXPagingView/JXPagerListRefreshView.h>
#import <JXCategoryView/JXCategoryView.h>
#import "HomeViewController.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/DTThreadHelper.h>
#import <TTMessaging/Theme.h>
#import "DTCallInviteMemberVC.h"
#import "OWSLinkDeviceViewController.h"
#import "NewGroupViewController.h"
#import "DTChatFolderManager.h"
#import "TempTalk-Swift.h"

@interface DTHomeViewController ()<JXCategoryTitleViewDataSource,
    JXPagerViewDelegate,
    JXCategoryViewDelegate,
    DTChatFolderManagerDelegate,
    DTThreadHelperDelegate,
    ActionFloatViewDelegate,
    OWSNavigationChildController
>

// 点击 right bar item 展示功能菜单
@property (nonatomic, strong, nullable) DTMessageActionFloatView *actionFloatView;

@property (nonatomic, strong) OWSSearchBar *searchBar;
@property (nonatomic, strong) JXPagerListRefreshView *pagerView;
@property (nonatomic, strong) JXCategoryTitleView *titleView;
@property (nonatomic, strong) JXCategoryIndicatorLineView *indicator;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, assign, getter=isViewVisible) BOOL viewVisible;

@property (nonatomic, strong) HomeViewController *conversationVC;
@property (nonatomic, assign) HomeViewMode homeViewMode;
@property (nonatomic, copy) DTChatFolderEntity *currentFolder;
@property (nonatomic, strong, nullable) NSArray <NSString *> *lastFolderKeys;
@property (nonatomic, assign) NSUInteger lastUnreadThreadCount;

@end

@implementation DTHomeViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (HomeViewMode)homeViewMode {
    return self.conversationVC.homeViewMode;
}

- (NSArray<DTChatFolderEntity *> *)chatFolders {
    return [DTChatFolderManager sharedManager].chatFolders;
}

- (NSArray <NSString *> *)folderKeys {
    NSMutableArray *folderKeys = @[].mutableCopy;
    [self.chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [folderKeys addObject:obj.name];
    }];

    return folderKeys.copy;
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

- (JXCategoryTitleView *)titleView {
    
    if (!_titleView) {
        _titleView = [[JXCategoryTitleView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 36)];
        _titleView.backgroundColor = Theme.backgroundColor;
        _titleView.delegate = self;
        _titleView.titleDataSource = self;
        _titleView.titleFont = [UIFont systemFontOfSize:15];
        _titleView.titleColor = Theme.ternaryTextColor;
        _titleView.titleSelectedColor = Theme.alertCancelColor;
        _titleView.titleColorGradientEnabled = YES;
        _titleView.averageCellSpacingEnabled = NO;
        _titleView.contentScrollViewClickTransitionAnimationEnabled = NO;
        _titleView.cellWidthIncrement = 10;
        _titleView.titles = @[DTChatFolderManager.folderAllKey];
        
        _indicator = [JXCategoryIndicatorLineView new];
        _indicator.lineStyle = JXCategoryIndicatorLineStyle_Normal;
        _indicator.indicatorHeight = 2.0;
        _indicator.indicatorColor = Theme.alertCancelColor;
        _titleView.indicators = @[_indicator];
        
        _separator = [UIView new];
        _separator.backgroundColor = Theme.hairlineColor;
        [_titleView addSubview:_separator];
        [_separator autoPinEdgeToSuperviewEdge:ALEdgeLeading];
        [_separator autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
        [_separator autoPinEdgeToSuperviewEdge:ALEdgeBottom];
        [_separator autoSetDimension:ALDimensionHeight toSize:1.0/UIScreen.mainScreen.scale];
    }
    
    return _titleView;
}

- (JXPagerListRefreshView *)pagerView {
    
    if (!_pagerView) {
        _pagerView = [[JXPagerListRefreshView alloc] initWithDelegate:self];
        _pagerView.mainTableView.backgroundColor = Theme.backgroundColor;
        _pagerView.isListHorizontalScrollEnabled = NO;
    }
    return _pagerView;;
}

- (HomeViewController *)conversationVC {
    
    if (!_conversationVC) {
        _conversationVC = [HomeViewController new];
        _conversationVC.isFromRegistration = self.isFromRegistration;
    }
    return _conversationVC;
}

- (void)loadView {
    [super loadView];

    [self.view addSubview:self.pagerView];
    [self.pagerView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [self.pagerView autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [self.pagerView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self.pagerView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    
    self.titleView.listContainer = (id<JXCategoryViewListContainer>)self.pagerView.listContainerView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if([TSAccountManager sharedInstance].isNewRegister){
        
        OWSLogInfo(@"is newRegister");
    } else {
        
        OWSLogInfo(@"not newRegister");
        
        self.leftTitle = [NSString stringWithFormat:@"%@...", Localized(@"NETWORK_STATUS_CONNECTING", @"")];
        
        @weakify(self);
        [self waitUntil:^ BOOL{
            
            @strongify(self);
            return self.viewVisible;
        } withFrequency:0.05].doneOn(dispatch_get_main_queue(), ^(id _Nonnull result) {
            
        }).catch(^(NSError *error){
            
            OWSLogError(@"Error: %@", error);
        });;
    }
        
    [self socketStateDidChange];
    
    [DTChatFolderManager sharedManager].delegate = self;
    [DTThreadHelper sharedManager].delegate = self;
    [self syncChatFolderFirstLaunch];
    [self updateBarButtonItems];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketStateDidChange)
                                                 name:OWSWebSocket.webSocketStateDidChange
                                               object:nil];
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tabBarItemDoubleClickNotification:)
                                                 name:kTabBarItemDoubleClickNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.viewVisible = YES;
    
    OWSLogInfo(@"dthomeview viewWillAppear");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    OWSLogInfo(@"dthomeview viewDidAppear");
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.actionFloatView hide:true];
    
    self.viewVisible = NO;
}

- (BOOL)hidesBottomBarWhenPushed {
    return NO;
}

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
    barAddButton.accessibilityLabel
        = Localized(@"CREATE_NEW_GROUP", @"Accessibility label for the create group new group button");
    self.navigationItem.rightBarButtonItem = barAddButton;
}

- (void)applyTheme {
    [super applyTheme];

    self.pagerView.mainTableView.backgroundColor = Theme.backgroundColor;
    self.titleView.backgroundColor = Theme.backgroundColor;
    self.titleView.titleSelectedColor = Theme.alertCancelColor;
    self.indicator.indicatorColor = Theme.alertCancelColor;
    [self.titleView reloadData];
    self.separator.backgroundColor = Theme.hairlineColor;
}

- (void)applyLanguage {
    [super applyLanguage];
    [self socketStateDidChange];
    [self.pagerView.mainTableView reloadData];
    [self setupActionFloatView];
}

//MARK: JXCategoryViewDelegate

- (void)categoryView:(JXCategoryBaseView *)categoryView didClickSelectedItemAtIndex:(NSInteger)index {
    
    [self categoryView:categoryView didSelectedItemAtIndex:index];
    
}


- (void)categoryView:(JXCategoryBaseView *)categoryView didSelectedItemAtIndex:(NSInteger)index {
    
    DTChatFolderEntity *targetFolder = index == 0 ? nil : self.chatFolders[(NSUInteger)index - 1];
    if ([self.currentFolder isEqual:targetFolder]) {
        return;
    }
    
    self.currentFolder = index == 0 ? nil : targetFolder;
    self.conversationVC.currentFolder = self.currentFolder;
    self.conversationVC.threadMapping.currentFolder = self.currentFolder;
//    [self.conversationVC updateFiltering];
    
    NSMutableArray <NSString *> *lastFolderkeys = @[].mutableCopy;
    [self.chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [lastFolderkeys addObject:obj.name];
    }];
    self.lastFolderKeys = lastFolderkeys.copy;
}
 

//MARK: - JXPagerViewDelegate
- (UIView *)tableHeaderViewInPagerView:(JXPagerView *)pagerView {
    return self.searchBar;
}

- (NSUInteger)tableHeaderViewHeightInPagerView:(JXPagerView *)pagerView {
    return (NSUInteger)self.searchBar.height;
}

- (NSUInteger)heightForPinSectionHeaderInPagerView:(JXPagerView *)pagerView {
    return self.chatFolders.count > 0 ? 36 : 0;
}

- (UIView *)viewForPinSectionHeaderInPagerView:(JXPagerView *)pagerView {
    return self.titleView;
}

- (NSInteger)numberOfListsInPagerView:(JXPagerView *)pagerView {
    return (NSInteger)self.titleView.titles.count;
}

- (id<JXPagerViewListViewDelegate>)pagerView:(JXPagerView *)pagerView initListAtIndex:(NSInteger)index {
    return self.conversationVC;
}


- (void)showSeachViewController {
        
    ConversationSearchViewController *searchResultsController = [ConversationSearchViewController new];
    searchResultsController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:searchResultsController animated:YES];
}

- (void)socketStateDidChange {
        
    if (TSAccountManager.sharedInstance.isDeregistered) {
        self.leftTitle = [NSString stringWithFormat:@"%@",  Localized(@"NETWORK_STATUS_DEREGISTERED", @"")];
        return;
    }
    
    if (![Reachability reachabilityForInternetConnection].isReachable) {
        self.leftTitle = [NSString stringWithFormat:@"%@",  Localized(@"NETWORK_STATUS_OFFLINE", @"")];
        return;
    }
    
    OWSWebSocketState socketState = self.socketManager.socketState;
    switch (socketState) {
        case OWSWebSocketStateClosed:
            self.leftTitle = [NSString stringWithFormat:@"%@",  Localized(@"NETWORK_STATUS_OFFLINE", @"")];
            break;
        case OWSWebSocketStateConnecting:
            self.leftTitle = [NSString stringWithFormat:@"%@...", Localized(@"NETWORK_STATUS_CONNECTING", @"")];
            break;
        case OWSWebSocketStateOpen:
            self.leftTitle = Localized(@"TABBAR_HOME", @"Title for the home view's default mode.");
            break;
    }
}

- (void)tabBarItemDoubleClickNotification:(NSNotification *)notify {
    
    NSDictionary *userInfo = notify.userInfo;
    NSNumber *numberSelectedIndex = userInfo[@"selectedIndex"];
    NSUInteger selectedIndex = numberSelectedIndex.unsignedIntegerValue;
    if (selectedIndex != 0) { return; }
    
    if (self.pagerView.mainTableView.contentOffset.y < self.searchBar.height) {
        [self.pagerView.mainTableView setContentOffset:CGPointMake(0, self.searchBar.height) animated:NO];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.conversationVC scrollToNextUnreadConversation];
    });
}

- (void)applicationDidBecomeActive:(NSNotification *)noti {
    
    __block BOOL hasUpdate = NO;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        hasUpdate = [[TSAccountManager sharedInstance].keyValueStore getBool:kChatFolderUpdateKey defaultValue:NO transaction:readTransaction];
        if (!hasUpdate) {
            return;
        }
        [[DTChatFolderManager sharedManager] fetchChatFolders:readTransaction];
    } completion:^{
        [self reloadFolderBar];
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [[TSAccountManager sharedInstance].keyValueStore setBool:NO key:kChatFolderUpdateKey transaction:writeTransaction];
        });
    }];
}

//MARK: chat folder
- (void)reloadFolderBar {
    
    if (self.homeViewMode == HomeViewMode_Archive) {
        return;
    }
    
    if (self.chatFolders.count == 0) {
        DispatchMainThreadSafe(^{
            self.titleView.hidden = YES;
            self.separator.hidden = YES;
            [self.titleView selectItemAtIndex:0];
            [self.pagerView reloadData];
        });
        return;
    }
    
    NSDictionary *unreadThreadCache = [DTThreadHelper sharedManager].unreadThreadCache;
    NSString *allThreadTitle = [self folderTitle:DTChatFolderManager.folderAllKey unreadThreadsCount:(NSInteger)unreadThreadCache.count];
    NSMutableArray *folderTitles = @[allThreadTitle].mutableCopy;
    
    [BenchManager startEventWithTitle:@"reloadFolderBar" eventId:@"reloadFolderBar"];
    
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        
        // 记录需要查询数据库来计算未读数的 custom folder
        NSMutableArray<DTChatFolderEntity *> *customFolders = @[].mutableCopy;
        // 记录 custom folder title 在 folderTitles 中的位置，方便后续替换
        NSMutableDictionary<NSString *, NSNumber *> *customFolderTitleIndexMap = @{}.mutableCopy;
        
        // 0 是 all
        NSInteger index = 1;
        for (DTChatFolderEntity *folder in self.chatFolders) {
            
            NSInteger unreadThreadsCount = 0;
            
            // recommend folder
            if (folder.folderType == DTFolderTypeRecommend) {
                unreadThreadsCount = [self unreadCountForRecommendFolder:folder unreadCache:unreadThreadCache transaction:transaction];
                // 如果设置 vega 未读消息数不计入 all，需要重新调整 all 未读数
                if ([folder.name isEqualToString:kChatFolderVegaKey] && [DTChatFolderManager sharedManager].excludeVegaFromAll && unreadThreadsCount > 0) {
                    NSString *allTitle = Localized(@"CHAT_FOLDER_NAME_CHATS", @"");
                    NSInteger count = (NSInteger)unreadThreadCache.count;
                    if(count <= unreadThreadsCount) {
                        count = 0;
                    }else{
                        count = count - unreadThreadsCount;
                    }
                    NSString *chatsTitle = [self folderTitle:allTitle unreadThreadsCount:count];
                    [folderTitles replaceObjectAtIndex:0 withObject:chatsTitle];
                }
                NSString *folderTitle = [self folderTitle:folder.displayName unreadThreadsCount:unreadThreadsCount];
                [folderTitles addObject:folderTitle];
                
            // custom folder
            } else {
                if (unreadThreadCache == nil || unreadThreadCache.count == 0) {
                    NSString *folderTitle = [self folderTitle:folder.displayName unreadThreadsCount:0];
                    [folderTitles addObject:folderTitle];
                    
                } else if (DTParamsUtils.validateString(folder.conditions.keywords) || DTParamsUtils.validateString(folder.conditions.groupOwners)) {
                    // 对于需要查询数据库来计算未读数的自定义 folder，先添加占位符，后续统一高效处理自定义 folder 后，再进行替换
                    [folderTitles addObject:@""];
                    [customFolders addObject:folder];
                    customFolderTitleIndexMap[folder.uniqueId] = @(index);
                    
                } else {
                    unreadThreadsCount = [self unreadCountForCustomFolder:folder visibleThreadIds:nil unreadCache:unreadThreadCache];
                    NSString *folderTitle = [self folderTitle:folder.displayName unreadThreadsCount:unreadThreadsCount];
                    [folderTitles addObject:folderTitle];
                }
            }
            index ++;
        }
        
        // 统一处理需要查询数据库的计算未读消息数的 custom folders
        if (customFolders.count > 0) {
            NSDictionary<NSString *, NSString *> *result = [self titlesForCustomFolders:customFolders unreadCache:unreadThreadCache transaction:transaction];
            [customFolderTitleIndexMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
                NSString *folderTitle = result[key];
                NSUInteger position = [obj unsignedIntValue];
                if (folderTitle && position < folderTitles.count) {
                    folderTitles[position] = folderTitle;
                }
            }];
        }
        
    } completion:^{
        
        [BenchManager completeEventWithEventId:@"reloadFolderBar"];
        
        self.titleView.titles = folderTitles.copy;
        DispatchMainThreadSafe(^{

            self.titleView.hidden = NO;
            self.separator.hidden = NO;
            
            BOOL needFullUpdate = NO;
            if((self.lastFolderKeys.count == 0 && self.folderKeys.count != 0) ||
               (self.lastFolderKeys.count != 0 && self.folderKeys.count == 0)){
                needFullUpdate = YES;
            }
            
            if (self.isViewVisible) {
                if ([self.folderKeys containsObject:self.currentFolder.name]) {
                    NSInteger currentIndex = (NSInteger)[self.folderKeys indexOfObject:self.currentFolder.name] + 1;
                    [self.titleView selectItemAtIndex:currentIndex];
                } else {
                    NSInteger foldersUpdateType = [self chatFoldersUpdateType];
                    NSInteger targetIndex = 0;
                    if (foldersUpdateType == 0) {
                        targetIndex = self.titleView.selectedIndex;
                    }
                    [self.titleView selectItemAtIndex:targetIndex];
                }
            } else {
                NSInteger targetIndex = 0;
                if ([self.folderKeys containsObject:self.currentFolder.name]) {
                    targetIndex = (NSInteger)[self.folderKeys indexOfObject:self.currentFolder.name] + 1;
                } else {
                    if ([self chatFoldersUpdateType] == 0) {
                        targetIndex = self.titleView.selectedIndex;
                    }
                }
                self.titleView.defaultSelectedIndex = targetIndex;
                [self categoryView:self.titleView didSelectedItemAtIndex:targetIndex];
            }
            
            if (needFullUpdate) {
                // 因为 pagerView 在执行 reloadData 时内部会执行 listContaner reloadData，所以 titleView 执行 reloadDataWithoutListContainer 即可
                [self.titleView reloadDataWithoutListContainer];
                // pagerView reloadData 时会刷新 titleView 的高度，只有在 chat folder 从无到有，或从有到无时需要刷新 titleView 高度
                [self.pagerView reloadData];
            } else {
                [self.titleView reloadData];
            }
            
        });
    }];
}

- (NSInteger)unreadCountForRecommendFolder:(DTChatFolderEntity *)folder
                               unreadCache:(NSDictionary<NSString *, NSNumber *> *)unreadThreadCache
                               transaction:(SDSAnyReadTransaction *)transaction
{
    if (unreadThreadCache == nil || unreadThreadCache.count == 0) {
        return 0;
    }
    
    if ([folder.name isEqualToString:kChatFolderPrivateKey]) {
        __block NSInteger privateUnreadCount = 0;
        [unreadThreadCache.allKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![obj hasPrefix:@"+"]) {
                return;
            }
            privateUnreadCount += 1;
        }];
        return privateUnreadCount;
    }
    
    if ([folder.name isEqualToString:kChatFolderUnreadKey]) {
        return (NSInteger)unreadThreadCache.count;
    }
    
    if ([folder.name isEqualToString:kChatFolderAtMeKey]) {
        __block NSInteger atMeUnreadCount = 0;
        [unreadThreadCache.allKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj hasPrefix:@"+"]) {
                return;
            }
            NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:obj];
            TSGroupThread *groupThread = [TSGroupThread anyFetchGroupThreadWithUniqueId:[TSGroupThread threadIdFromGroupId:groupId] transaction:transaction];
            NSString *atPersons = [groupThread atPersonsWithTransaction:transaction];
            if (!atPersons || ![[TSAccountManager sharedInstance] localNumberWithTransaction:transaction]) {
                return;
            }
            if (![atPersons containsString:[[TSAccountManager sharedInstance] localNumberWithTransaction:transaction]] && ![atPersons containsString:MENTIONS_ALL]) {
                return;
            }
            atMeUnreadCount += 1;
        }];
        return atMeUnreadCount;
    }
    
    if ([folder.name isEqualToString:kChatFolderVegaKey]) {
        __block NSInteger vegaUnreadCount = 0;
        [unreadThreadCache.allKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj hasPrefix:@"+"]) {
                return;
            }
            NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:obj];
            TSGroupThread *groupThread = [TSGroupThread anyFetchGroupThreadWithUniqueId:[TSGroupThread threadIdFromGroupId:groupId] transaction:transaction];
            if(groupThread.businessFromVega){
                vegaUnreadCount += 1;
            }
        }];
        return vegaUnreadCount;
    }
    
    return 0;
}

// MARK: 自定义 folder 未读计数
- (NSInteger)unreadCountForCustomFolder:(DTChatFolderEntity *)customFolder
                       visibleThreadIds:(nullable NSSet<NSString *> *)visibleThreadIds
                            unreadCache:(NSDictionary<NSString *, NSNumber *> *)unreadThreadCache
{
    if (unreadThreadCache == nil || unreadThreadCache.count == 0) {
        return 0;
    }
    
    NSMutableSet<NSString *> *folderThreadIds = [NSMutableSet new];
    [customFolder.cIds enumerateObjectsUsingBlock:^(DTFolderThreadEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!DTParamsUtils.validateString(obj.id)) {
            OWSLogError(@"[Chat folder] thread id is nil \n%@", obj.description);
            return;
        }
        [folderThreadIds addObject:obj.id];
    }];
    if (visibleThreadIds && visibleThreadIds.count > 0) {
        [folderThreadIds unionSet:visibleThreadIds];
    }
    
    __block NSInteger customFolderUnreadCount = 0;
    [folderThreadIds enumerateObjectsUsingBlock:^(NSString * _Nonnull serverThreadId, BOOL * _Nonnull stop) {
        if ([unreadThreadCache.allKeys containsObject:serverThreadId]) {
            customFolderUnreadCount += 1;
        }
    }];
    
    return customFolderUnreadCount;
}

// 批量计算自定义 folder 的标题
- (NSDictionary<NSString *, NSString *> *)titlesForCustomFolders:(NSArray<DTChatFolderEntity *> *)customFolders
                                                          unreadCache:(NSDictionary<NSString *, NSNumber *> *)unreadThreadCache
                                                          transaction:(SDSAnyReadTransaction *)transaction
{
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *visibleThreadIdsMap = @{}.mutableCopy;
    
    AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
    NSError *error;
    [finder enumerateVisibleThreadsWithIsArchived:NO
                                      transaction:transaction
                                            error:&error
                                            block:^(TSThread * _Nonnull thread) {
        if (![thread isKindOfClass:[TSContactThread class]] && ![thread isKindOfClass:[TSGroupThread class]]) {
            OWSLogError(@"[Chat folder] object isn't TSThread class %@", thread.class);
            return;
        }
        if (!thread.shouldBeVisible || thread.isArchived || thread.isRemovedFromConversation) {
            return;
        }
        if (!thread.serverThreadId) {
            return;
        }
        for (DTChatFolderEntity *folder in customFolders) {
            if ([folder isConditonsContainThread:thread transaction:transaction]) {
                NSMutableSet<NSString *> *newThreadIds;
                NSSet<NSString *> *oldThreadIds = visibleThreadIdsMap[folder.uniqueId];
                if (oldThreadIds && oldThreadIds.count > 0) {
                    newThreadIds = oldThreadIds.mutableCopy;
                } else {
                    newThreadIds = [[NSMutableSet alloc] init];
                }
                [newThreadIds addObject:thread.serverThreadId];
                visibleThreadIdsMap[folder.uniqueId] = newThreadIds;
            }
        }
    }];
    
    NSMutableDictionary<NSString *, NSString *> *result = @{}.mutableCopy;
    for (DTChatFolderEntity *folder in customFolders) {
        NSSet<NSString *> *visibleThreadIds = visibleThreadIdsMap[folder.uniqueId];
        NSInteger unreadCount = [self unreadCountForCustomFolder:folder visibleThreadIds:visibleThreadIds unreadCache:unreadThreadCache];
        NSString *folderTitle = [self folderTitle:folder.displayName unreadThreadsCount:unreadCount];
        result[folder.uniqueId] = folderTitle;
    }
    
    return result;
}

- (NSString *)folderTitle:(NSString *)folderName unreadThreadsCount:(NSInteger)unreadThreadsCount {
    
    NSString *folderTitle = nil;
    if (unreadThreadsCount > 0) {
        if (unreadThreadsCount < 100) {
            folderTitle = [NSString stringWithFormat:@"%@(%ld)", folderName, unreadThreadsCount];
        } else {
            folderTitle = [NSString stringWithFormat:@"%@(99+)", folderName];
        }
    } else {
        folderTitle = folderName;
    }

    return folderTitle;
}

//MARK: 0:改名，1:顺序变更， 2:删除
- (NSInteger)chatFoldersUpdateType {
    NSSet <NSString *> *oldKeySet = [NSSet setWithArray:self.lastFolderKeys];
    NSSet <NSString *> *newKeySet = [NSSet setWithArray:self.folderKeys];
    NSMutableSet <NSString *> *tmpOldKeySet = oldKeySet.mutableCopy;
    NSMutableSet <NSString *> *tmpNewKeySet = newKeySet.mutableCopy;
    [tmpNewKeySet minusSet:oldKeySet];
    [tmpOldKeySet minusSet:newKeySet];
    if (tmpNewKeySet.count > 0 && tmpOldKeySet.count > 0 && oldKeySet.count == newKeySet.count) {
        return 0;
    }
    if (tmpNewKeySet.count == 0 && tmpOldKeySet.count == 0 && oldKeySet.count == newKeySet.count) {
        return 1;//无变化或顺序变更
    }
    if (tmpOldKeySet.count > 0 && oldKeySet.count > newKeySet.count) {
        return 2;
    }
    
    return -1;
}

//MARK: DTChatFolderManagerDelegate
- (void)chatFoldersChanged {
    [self reloadFolderBar];
}

//MARK: DTThreadHelperDelegate
- (void)unreadCountCacheChanged {
    NSUInteger unreadThreadCount = [[DTThreadHelper sharedManager].unreadThreadCache count];
//    __block BOOL existAtMe = NO;
//    [self.chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        if ([obj.name isEqualToString:kChatFolderAtMeKey]) {
//            existAtMe = YES;
//            *stop = YES;
//        }
//    }];
    if (self.lastUnreadThreadCount != unreadThreadCount
        || unreadThreadCount == 0) {
        
        self.lastUnreadThreadCount = unreadThreadCount;
        [self reloadFolderBar];
    }
}

- (void)syncChatFolderFirstLaunch {
    
    [[DTChatFolderManager sharedManager] fetchChatFolders];
    [self reloadFolderBar];
    
    [[TSAccountManager sharedInstance] getChatFolderSuccess:^(NSArray<DTChatFolderEntity *> * _Nonnull chatFolders) {} failure:^(NSError * _Nonnull error) {}];
}

- (void)setupActionFloatView {
    DTMessageActionFloatView *actionFloatView = [DTMessageActionFloatView new];
    actionFloatView.delegate = self;
    [actionFloatView layoutSubContent];
    _actionFloatView = actionFloatView;
    [self.view addSubview:_actionFloatView];
    [actionFloatView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
    [actionFloatView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
}

- (void)showActionFloatView:(id)sender {
    if (self.actionFloatView && self.actionFloatView.hidden == false) {
        [self.actionFloatView hide:true];
        return;
    }//防止双击
    [self setupActionFloatView];
    self.actionFloatView.hidden = NO;
}

- (void)showNewGroupView
{
    SignalApp.sharedApp.homeViewController = self;
    NewGroupViewController *newGroupViewController = [NewGroupViewController new];
    [self.navigationController pushViewController:newGroupViewController animated:YES];
}

#pragma mark - ActionFloatViewDelegate

- (void)floatViewTapItemIndex:(enum ActionFloatViewItemType)type {
    
    if (self.isUserDeregistered) return;

    if (type == ActionFloatViewItemTypeCreateGroup) {
        
        [self showNewGroupView];
    } else if (type == ActionFloatViewItemTypeScan) {
        
        DTScanQRCodeController *scanQRCodeController =  [DTScanQRCodeController new];
        @weakify(self);
        scanQRCodeController.didReceiveHandler = ^(NSURL *url) {
            @strongify(self);
            [self showDeviceTransfer:url];
        };
        [self.navigationController pushViewController:scanQRCodeController animated:true];
    } else if(type == ActionFloatViewItemTypeAddContacts){
        EnterCodeViewController *enterCodeVc = [EnterCodeViewController new];
        [self.navigationController pushViewController:enterCodeVc animated:YES completion:nil];
    } else if (type == ActionFloatViewItemTypeMyCode) {
        DTInviteCodeViewController *inviteCodeViewController = [DTInviteCodeViewController new];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:inviteCodeViewController];
        [self.navigationController presentViewController:navController animated:YES completion:nil];
    }
}

- (void)showDeviceTransfer:(NSURL *_Nonnull)url {
    NSError *error;
    DeviceTransferURLComponent *urlComponent = [[DeviceTransferService shared] parseTransferURL:url error:&error];
    if (error || urlComponent == nil) return;
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:Localized(@"Transfer Data", @"")
                                          message: [NSString stringWithFormat:Localized(@"Are you sure to transfer all your data to this device: %1$@?", @""), urlComponent.peerId.displayName]
                                          preferredStyle:UIAlertControllerStyleAlert
    ];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"Cancel", @"") style:UIAlertActionStyleCancel handler:NULL];
    UIAlertAction *confimAction = [UIAlertAction actionWithTitle:Localized(@"Yes", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if( [DeviceTransferService.shared launchCleanup]){
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
    //  MARK: - 传递DTD Token 验证Token有效性
    //  验证失败 终止
    //  验证成功 断开WebSocket
    //  跳转到转换界面
    DTTransferringDataViewController *transferringController = [[DTTransferringDataViewController alloc] initWithLogintoken:nil urlComponent:urlComponent oldDevice:true];
    DTTransferNavgationController *navgationController = [[DTTransferNavgationController alloc] initWithRootViewController:transferringController];
    [navgationController setModalPresentationStyle:UIModalPresentationFullScreen];
    [self.navigationController presentViewController:navgationController animated:YES completion:NULL];
}

- (void)floatViewDidRemoveFromSuperView {
    self.actionFloatView = nil;
}

// MARK: promise wait until - to remove to other file

- (AnyPromise *)waitUntil:(BOOL (^)(void))condition withFrequency:(NSTimeInterval)frequency {
    
    return AnyPromise.withFutureOn(dispatch_get_global_queue(0, 0), ^(AnyFuture * _Nonnull future) {

        [self checkCondition:condition withFuture:future andFrequency:frequency];
    });
}

- (void)checkCondition:(BOOL (^)(void))condition withFuture:(AnyFuture *)future andFrequency:(NSTimeInterval)frequency {    
    BOOL result = condition ? condition() : NO;
    if (result) {
        
        [future resolveWithValue:@(1)];
    } else {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(frequency * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkCondition:condition withFuture:future andFrequency:frequency];
        });
    }
}

#pragma mark - OWSNavigationChildController delegate

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack
{
    return YES;
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    return Theme.backgroundColor;
}

- (BOOL)prefersNavigationBarHidden {
    return NO;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
}

@end
