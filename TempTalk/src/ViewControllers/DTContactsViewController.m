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
#import "NewContactThreadViewController.h"
#import "DTGroupsViewController.h"
#import "TempTalk-Swift.h"

@interface DTContactsViewController ()<JXCategoryTitleViewDataSource, JXPagerViewDelegate, JXCategoryViewDelegate>

@property (nonatomic, strong) OWSSearchBar *searchBar;
@property (nonatomic, strong) JXPagerListRefreshView *pagerView;
@property (nonatomic, strong) JXCategoryTitleView *titleView;
@property (nonatomic, strong) JXCategoryIndicatorLineView *indicator;
@property (nonatomic, strong) UIView *separator;

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
        _titleView.backgroundColor = Theme.backgroundColor;
        _titleView.delegate = self;
        _titleView.titleDataSource = self;
        _titleView.titleFont = [UIFont systemFontOfSize:15];
//        _titleView.titleSelectedFont = [UIFont systemFontOfSize:16].ows_semibold;
        _titleView.titleColor = Theme.ternaryTextColor;
        _titleView.titleSelectedColor = Theme.alertCancelColor;
        _titleView.titleColorGradientEnabled = YES;
        _titleView.averageCellSpacingEnabled = NO;
        _titleView.cellWidthIncrement = 10;
        _titleView.contentScrollViewClickTransitionAnimationEnabled = NO;
        _titleView.titles = @[Localized(@"CONTACT_ALL", @""), Localized(@"CONTACT_GROUPS", @"")];
        
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
        _pagerView.listContainerView.listCellBackgroundColor = Theme.backgroundColor;
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
}

- (BOOL)hidesBottomBarWhenPushed {
    return NO;
}

- (void)applyTheme {
    [super applyTheme];

    self.pagerView.listContainerView.listCellBackgroundColor = Theme.backgroundColor;
    self.titleView.backgroundColor = Theme.backgroundColor;
    self.titleView.titleSelectedColor = Theme.alertCancelColor;
    self.indicator.indicatorColor = Theme.alertCancelColor;
    self.separator.backgroundColor = Theme.hairlineColor;
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
