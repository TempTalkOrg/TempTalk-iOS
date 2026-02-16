//
//  DTContactsViewController.m
//  Signal
//
//  Created by Ethan on 2022/10/17.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTContactsViewController.h"
#import <JXPagingView/JXPagerListRefreshView.h>
#import <JXCategoryView/JXCategoryView.h>
#import <TTMessaging/OWSWindowManager.h>
#import "NewContactThreadViewController.h"
#import "DTGroupsViewController.h"
#import "Yelling-Swift.h"

@interface DTContactsViewController ()<JXCategoryTitleViewDataSource, JXPagerViewDelegate, JXCategoryViewDelegate>

@property (nonatomic, strong) OWSSearchBar *searchBar;
@property (nonatomic, strong) JXPagerListRefreshView *pagerView;
@property (nonatomic, strong) JXCategoryTitleView *titleView;
@property (nonatomic, strong) JXCategoryIndicatorLineView *indicator;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIButton *addContactButton;

@property (nonatomic, strong) NewContactThreadViewController *contactsVC;
@property (nonatomic, strong) DTGroupsViewController *groupsVC;

@end

@implementation DTContactsViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (OWSSearchBar *)searchBar {
    if (!_searchBar) {
        _searchBar = [OWSSearchBar new];
        _searchBar.customPlaceholder = Localized(@"HOME_VIEW_CONVERSATION_SEARCHBAR_PLACEHOLDER",
                                                  @"Placeholder text for search bar which filters conversations.");
        [_searchBar sizeToFit];
        [_searchBar autoSetDimensionsToSize:CGSizeMake(kScreenWidth, 44)];
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
        _titleView.backgroundColor = Theme.bgpagePrimaryColor;
        _titleView.delegate = self;
        _titleView.titleDataSource = self;
        _titleView.titleFont = [UIFont systemFontOfSize:15];
//        _titleView.titleSelectedFont = [UIFont systemFontOfSize:16].ows_semibold;
        _titleView.titleColor = Theme.tthirdColor;
        _titleView.titleSelectedColor = Theme.tprimaryColor;
        _titleView.titleColorGradientEnabled = YES;
        _titleView.averageCellSpacingEnabled = NO;
        _titleView.cellWidthIncrement = 10;
        _titleView.contentScrollViewClickTransitionAnimationEnabled = NO;
        _titleView.titles = @[Localized(@"CONTACT_ALL", @""), Localized(@"CONTACT_GROUPS", @"")];
        
        _indicator = [JXCategoryIndicatorLineView new];
        _indicator.lineStyle = JXCategoryIndicatorLineStyle_Normal;
        _indicator.indicatorHeight = 2.0;
        _indicator.indicatorColor = Theme.tprimaryColor;
        _titleView.indicators = @[_indicator];
        
        _separator = [UIView new];
        _separator.backgroundColor = Theme.lineColor;
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
        _pagerView.mainTableView.backgroundColor = Theme.bgpagePrimaryColor;
        _pagerView.listContainerView.listCellBackgroundColor = Theme.bgpagePrimaryColor;
    }
    return _pagerView;;
}

- (NewContactThreadViewController *)contactsVC {
    if (!_contactsVC) {
        _contactsVC = [NewContactThreadViewController new];
    }
    return _contactsVC;
}

- (DTGroupsViewController *)groupsVC {
    if (!_groupsVC) {
        _groupsVC = [DTGroupsViewController new];
    }
    return _groupsVC;
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
    self.leftTitle = Localized(@"MESSAGE_COMPOSEVIEW_TITLE", @"");

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
    [self.contactsVC requestContactsAtFirstTime];

    // 添加右上角的添加联系人按钮
    [self setupAddContactButton];
}

- (void)setupAddContactButton {
    self.addContactButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [[UIImage imageNamed:@"add_contacts"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.addContactButton setImage:image forState:UIControlStateNormal];
    [self.addContactButton addTarget:self action:@selector(addContactButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.addContactButton setFrame:CGRectMake(0, 0, 48, 48)];

    UIBarButtonItem *addContactBarItem = [[UIBarButtonItem alloc] initWithCustomView:self.addContactButton];
    self.navigationItem.rightBarButtonItem = addContactBarItem;
}

- (void)addContactButtonTapped {
    // 打开邀请码输入页面
    EnterCodeViewController *enterCodeVC = [EnterCodeViewController new];
    [self.navigationController pushViewController:enterCodeVC animated:YES];
}

- (BOOL)hidesBottomBarWhenPushed {
    return NO;
}

- (void)applyTheme {
    [super applyTheme];

    self.pagerView.listContainerView.listCellBackgroundColor = Theme.bgpagePrimaryColor;
    self.titleView.backgroundColor = Theme.bgpagePrimaryColor;
    self.titleView.titleSelectedColor = Theme.tprimaryColor;
    self.indicator.indicatorColor = Theme.tprimaryColor;
    self.separator.backgroundColor = Theme.lineColor;
    self.addContactButton.tintColor = Theme.iconColor;
    [self.titleView reloadData];
}

- (void)applyLanguage {
    [super applyLanguage];
    self.leftTitle = Localized(@"MESSAGE_COMPOSEVIEW_TITLE", @"");
    self.titleView.titles = @[Localized(@"CONTACT_GROUPS", @""), Localized(@"CONTACT_ALL", @"")];
    [self.titleView reloadData];
}

//MARK: - JXPagerViewDelegate
- (UIView *)tableHeaderViewInPagerView:(JXPagerView *)pagerView {
    return self.searchBar;
}

- (NSUInteger)tableHeaderViewHeightInPagerView:(JXPagerView *)pagerView {
    return (NSUInteger)self.searchBar.height;
}

- (NSUInteger)heightForPinSectionHeaderInPagerView:(JXPagerView *)pagerView {
    return 36;
}

- (UIView *)viewForPinSectionHeaderInPagerView:(JXPagerView *)pagerView {
    return self.titleView;
}

- (NSInteger)numberOfListsInPagerView:(JXPagerView *)pagerView {
    return (NSInteger)self.titleView.titles.count;
}

- (id<JXPagerViewListViewDelegate>)pagerView:(JXPagerView *)pagerView initListAtIndex:(NSInteger)index {
    if (index == 0) return self.contactsVC;
    else if (index == 1) return self.groupsVC;
    else return nil;
}


- (void)showSeachViewController {
        
    ConversationSearchViewController *searchResultsController = [ConversationSearchViewController new];
    searchResultsController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:searchResultsController animated:YES];
}

- (void)signalAccountsDidChange:(NSNotification *)noti {
    // do something;
}

@end
