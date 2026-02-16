//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NewContactThreadViewController.h"
#import "ContactTableViewCell.h"
#import "ContactsViewHelper.h"
#import "NewGroupViewController.h"
#import "NewNonContactConversationViewController.h"
#import "OWSTableViewController.h"
#import "Yelling-Swift.h"
#import "SignalApp.h"
#import "UIColor+OWS.h"
#import "UIView+SignalUI.h"
#import <MessageUI/MessageUI.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/UIUtil.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/AppVersion.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSAccountManager.h>

#import "ConversationItemMacro.h"

NS_ASSUME_NONNULL_BEGIN

@interface SignalAccount (Collation)

- (NSString *)stringForCollation;

@end

@implementation SignalAccount (Collation)

- (NSString *)stringForCollation
{
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    return [contactsManager comparableNameForSignalAccount:self];
}

@end

// added: only fetching internal contacts from server when the page is showed first time.
static BOOL isLoadInternalContactsOver = NO;

@interface NewContactThreadViewController () <
    UITableViewDelegate,
    UITableViewDataSource,
    ContactsViewHelperDelegate,
    NewNonContactConversationViewControllerDelegate,
    MFMessageComposeViewControllerDelegate>

@property (nonatomic, strong) ContactsViewHelper *contactsViewHelper;

@property (nonatomic, readonly) UIView *noSignalContactsView;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UILocalizedIndexedCollation *collation;

// A list of possible phone numbers parsed from the search text as
// E164 values.
@property (nonatomic) NSArray<NSString *> *searchPhoneNumbers;

// This set is used to cache the set of non-contact phone numbers
// which are known to correspond to Signal accounts.
@property (nonatomic, strong) NSMutableSet *nonContactAccountSet;

@property (nonatomic) BOOL isNoContactsModeActive;

@property (nonatomic, assign) BOOL viewDidAppear;
@property (nonatomic, assign) BOOL needRefreshView;
@property (nonatomic, assign) BOOL hasLoadContacts;

@property (nonatomic, copy) void(^scrollCallback)(UIScrollView *scrollView);

@property (nonatomic, strong) NSMutableArray <NSMutableArray<SignalAccount *> *> *collatedSignalAccounts;
@property (nonatomic, strong) NSArray <NSString *> *sectionTitles;

@end

#pragma mark -

@implementation NewContactThreadViewController

- (ContactsViewHelper *)contactsViewHelper {
    if (!_contactsViewHelper) {
        _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    }
    return _contactsViewHelper;
}

- (UILocalizedIndexedCollation *)collation {
    if (!_collation) {
        _collation = [UILocalizedIndexedCollation currentCollation];
    }
    return _collation;
}

- (NSMutableArray<NSMutableArray<SignalAccount *> *> *)collatedSignalAccounts {
    if (!_collatedSignalAccounts) {
        _collatedSignalAccounts = [@[] mutableCopy];
    }
    return _collatedSignalAccounts;
}

- (NSMutableSet *)nonContactAccountSet {
    if (!_nonContactAccountSet) {
        _nonContactAccountSet = [NSMutableSet set];
    }
    return _nonContactAccountSet;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = Theme.bgpagePrimaryColor;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 0;
        _tableView.rowHeight = 70;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.sectionIndexColor = Theme.tinfoColor;
        if (@available(iOS 15.0, *)) {
            _tableView.sectionHeaderTopPadding = 0;
        }
        [_tableView registerClass:[ContactTableViewCell class] forCellReuseIdentifier:[ContactTableViewCell reuseIdentifier]];
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DTNoContactsCellID"];

        UIRefreshControl *pullToRefreshView = [UIRefreshControl new];
        pullToRefreshView.tintColor = [UIColor grayColor];
        [pullToRefreshView addTarget:self
                              action:@selector(pullToRefreshPerformed:)
                    forControlEvents:UIControlEventValueChanged];
        _tableView.refreshControl = pullToRefreshView;
    }
    
    return _tableView;
}

- (void)loadView {
    [super loadView];

//    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    
    [self.view addSubview:self.tableView];
    [self.tableView autoPinEdgesToSuperviewEdges];

    _noSignalContactsView = [self createNoSignalContactsView];
    self.noSignalContactsView.hidden = YES;
    [self.view addSubview:self.noSignalContactsView];
    [self.noSignalContactsView autoPinWidthToSuperview];
    [self.noSignalContactsView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.noSignalContactsView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
}

- (void)pullToRefreshPerformed:(UIRefreshControl *)refreshControl {
    OWSAssertIsOnMainThread();

    [self.contactsViewHelper.contactsManager
     userRequestedSystemContactsRefreshWithIsUserRequested:YES completion:^(NSError * _Nullable error)  {
        if (error) {
            DDLogError(@"%@ refreshing contacts failed with error: %@", self.logTag, error);
        }
        [refreshControl endRefreshing];
        //  mannually update internal contacts if internal contacts is never loaded.
        if (!isLoadInternalContactsOver) {
            isLoadInternalContactsOver = YES;
            [self updateTableContents];
        }
    }];
}

//无联系人视图
- (UIView *)createNoSignalContactsView
{
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor whiteColor];

    UIView *contents = [UIView new];
    [view addSubview:contents];
    [contents autoCenterInSuperview];

    UIImage *heroImage = [UIImage imageNamed:@"uiEmptyContact"];
    OWSAssertDebug(heroImage);
    UIImageView *heroImageView = [[UIImageView alloc] initWithImage:heroImage];
    heroImageView.layer.minificationFilter = kCAFilterTrilinear;
    heroImageView.layer.magnificationFilter = kCAFilterTrilinear;
    [contents addSubview:heroImageView];
    [heroImageView autoHCenterInSuperview];
    [heroImageView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    const CGFloat kHeroSize = ScaleFromIPhone5To7Plus(100, 150);
    [heroImageView autoSetDimension:ALDimensionWidth toSize:kHeroSize];
    [heroImageView autoSetDimension:ALDimensionHeight toSize:kHeroSize];
    UIView *lastSubview = heroImageView;

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = Localized(
        @"EMPTY_CONTACTS_LABEL_LINE1", @"Full width label displayed when attempting to compose message");
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont ows_semiboldFontWithSize:ScaleFromIPhone5To7Plus(17.f, 20.f)];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.numberOfLines = 0;
    [contents addSubview:titleLabel];
    [titleLabel autoPinWidthToSuperview];
    [titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastSubview withOffset:30];
    lastSubview = titleLabel;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.text = Localized(
        @"EMPTY_CONTACTS_LABEL_LINE2", @"Full width label displayed when attempting to compose message");
    subtitleLabel.textColor = [UIColor colorWithWhite:0.32f alpha:1.f];
    subtitleLabel.font = [UIFont ows_regularFontWithSize:ScaleFromIPhone5To7Plus(12.f, 14.f)];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleLabel.numberOfLines = 0;
    [contents addSubview:subtitleLabel];
    [subtitleLabel autoPinWidthToSuperview];
    [subtitleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastSubview withOffset:15];
    lastSubview = subtitleLabel;

    UIButton *inviteContactsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [inviteContactsButton setTitle:Localized(@"INVITE_FRIENDS_CONTACT_TABLE_BUTTON",
                                       @"Label for the cell that presents the 'invite contacts' workflow.")
                          forState:UIControlStateNormal];
    [inviteContactsButton setTitleColor:[UIColor ows_materialBlueColor] forState:UIControlStateNormal];
    [inviteContactsButton.titleLabel setFont:[UIFont ows_regularFontWithSize:17.f]];
    [contents addSubview:inviteContactsButton];
    [inviteContactsButton autoHCenterInSuperview];
    [inviteContactsButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastSubview withOffset:50];
    lastSubview = inviteContactsButton;

    UIButton *searchByPhoneNumberButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [searchByPhoneNumberButton setTitle:Localized(@"NO_CONTACTS_SEARCH_BY_PHONE_NUMBER",
                                            @"Label for a button that lets users search for contacts by phone number")
                               forState:UIControlStateNormal];
    [searchByPhoneNumberButton setTitleColor:[UIColor ows_materialBlueColor] forState:UIControlStateNormal];
    [searchByPhoneNumberButton.titleLabel setFont:[UIFont ows_regularFontWithSize:17.f]];
    [contents addSubview:searchByPhoneNumberButton];
    [searchByPhoneNumberButton autoHCenterInSuperview];
    [searchByPhoneNumberButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastSubview withOffset:20];
    [searchByPhoneNumberButton addTarget:self
                                  action:@selector(hideBackgroundView)
                        forControlEvents:UIControlEventTouchUpInside];
    lastSubview = searchByPhoneNumberButton;

    [lastSubview autoPinEdgeToSuperviewMargin:ALEdgeBottom];

    return view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView reloadData];

    // 监听字体大小变化通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textSizeDidChange)
                                                 name:NSNotification.TextSizeDidChange
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Make sure we have requested contact access at this point if, e.g.
    // the user has no messages in their inbox and they choose to compose
    // a message.
// modified: donot access system contacts.
//    [self.contactsViewHelper.contactsManager requestSystemContactsOnce];

    [self showContactAppropriateViews];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.viewDidAppear = YES;
    if(self.needRefreshView){
        [self loadDataIfNecessary];
    }
}

- (void)requestContactsAtFirstTime {
    if (!self.hasLoadContacts) {
        _hasLoadContacts = YES;
        [self.tableView reloadData];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateTableContents];

            [self.contactsViewHelper.contactsManager userRequestedSystemContactsRefreshWithIsUserRequested:NO completion:^(NSError * _Nullable error)  {
                if (error) {
                    DDLogError(@"%@ refreshing contacts failed with error: %@", self.logTag, error);
                } else {
                    [self updateTableContents];
                }
            }];
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:animated];
    self.viewDidAppear = NO;
    
}

- (BOOL)hidesBottomBarWhenPushed
{
    return NO;
}

- (void)applyTheme
{
    OWSAssertIsOnMainThread();
    self.tableView.backgroundColor = Theme.bgpagePrimaryColor;
    self.tableView.sectionIndexColor = Theme.bgpagePrimaryColor;
    [super applyTheme];
    [self.tableView reloadData];
}

- (void)applyLanguage {
    [super applyLanguage];
    [self.tableView reloadData];
}

- (void)textSizeDidChange {
    [self.tableView reloadData];
}

- (void)loadDataIfNecessary {
    
    self.needRefreshView = YES;
    
    if(!self.viewDidAppear) return;
    
    [self updateTableContents];

    [self showContactAppropriateViews];
    
    self.needRefreshView = NO;
}

- (BOOL)hasRequestData {
    return self.contactsViewHelper.hasUpdatedContactsAtLeastOnce || isLoadInternalContactsOver;
}

- (NSInteger)signalAccountsCount {
    return (NSInteger)self.collatedSignalAccounts.count;
}

- (void)updateTableContents {

    [self.collatedSignalAccounts removeAllObjects];
    for (NSUInteger i = 0; i < self.collation.sectionTitles.count; i++) {
        self.collatedSignalAccounts[i] = [NSMutableArray new];
    }
    
    for (SignalAccount *signalAccount in self.contactsViewHelper.signalAccounts) {
        if (!signalAccount.isFriend) {
            continue;
        }
        NSInteger section =
        [self.collation sectionForObject:signalAccount collationStringSelector:@selector(stringForCollation)];

        if (section < 0) {
            OWSFailDebug(@"Unexpected collation for name:%@", signalAccount.stringForCollation);
            continue;
        }
        NSUInteger sectionIndex = (NSUInteger)section;

        [self.collatedSignalAccounts[sectionIndex] addObject:signalAccount];
    }
    
    NSMutableArray *tmpSectionTitles = [self.collation.sectionTitles mutableCopy];
    NSMutableArray <NSMutableArray<SignalAccount *> *> *tmpCollatedSignalAccounts = [self.collatedSignalAccounts mutableCopy];
    [tmpCollatedSignalAccounts enumerateObjectsUsingBlock:^(NSMutableArray<SignalAccount *> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.count == 0) {
            [self.collatedSignalAccounts removeObject:obj];
            [tmpSectionTitles removeObject:self.collation.sectionTitles[idx]];
        }
    }];
    self.sectionTitles = [tmpSectionTitles copy];
    [self.tableView reloadData];
}

#pragma mark - Table Contents

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.signalAccountsCount < 1 ? 1 : self.signalAccountsCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.signalAccountsCount < 1) {
        return 1;
    }
    return (NSInteger)self.collatedSignalAccounts[(NSUInteger)section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.signalAccountsCount < 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DTNoContactsCellID" forIndexPath:indexPath];
        cell.userInteractionEnabled = NO;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.contentView.backgroundColor = Theme.bgpagePrimaryColor;
        if (self.hasRequestData) {
            for (UIView *subview in cell.contentView.subviews) {
                if ([subview isKindOfClass:UIActivityIndicatorView.class]) {
                    [subview removeFromSuperview];
                    break;
                }
            }
            cell.textLabel.text = Localized(@"SETTINGS_BLOCK_LIST_NO_CONTACTS",
                                                    @"A label that indicates the user has no Signal contacts.");
            cell.textLabel.font = [UIFont ows_regularFontWithSize:15.f];
            cell.textLabel.textColor = Theme.tprimaryColor;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        } else {
            cell.textLabel.text = nil;
            UIActivityIndicatorView *activityIndicatorView =
                [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.color = Theme.tprimaryColor;
            [cell.contentView addSubview:activityIndicatorView];
            [activityIndicatorView startAnimating];
            
            [activityIndicatorView autoCenterInSuperview];
            [activityIndicatorView setCompressionResistanceHigh];
            [activityIndicatorView setContentHuggingHigh];
        }
        
        return cell;
    }
    
    ContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[ContactTableViewCell reuseIdentifier] forIndexPath:indexPath];
    NSUInteger section = (NSUInteger)indexPath.section, row = (NSUInteger)indexPath.row;
    if (section >= self.collatedSignalAccounts.count || row >= self.collatedSignalAccounts[section].count) {
        return nil;
    }
    SignalAccount *signalAccount = self.collatedSignalAccounts[section][row];
    BOOL isBlocked = [self.contactsViewHelper
        isRecipientIdBlocked:signalAccount.recipientId];
    if (isBlocked) {
        cell.accessoryMessage = Localized(@"CONTACT_CELL_IS_BLOCKED",
            @"An indicator that a contact has been blocked.");
    }

    [cell configureWithSignalAccount:signalAccount
                     contactsManager:self.contactsViewHelper.contactsManager];

    return cell;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if (self.signalAccountsCount < 1) {
        return nil;
    }

    NSUInteger sectionSignalAccountCount = self.collatedSignalAccounts[(NSUInteger)section].count;
    if (sectionSignalAccountCount > 0) {
        NSString *sectionTitle = self.sectionTitles[(NSUInteger)section];
        UIView *sectionHeader = [self headerWithTitle:sectionTitle];
        return sectionHeader;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.signalAccountsCount < 1) {
        return CGFLOAT_MIN;
    }
    NSUInteger sectionSignalAccountCount = self.collatedSignalAccounts[(NSUInteger)section].count;
    return sectionSignalAccountCount > 0 ? 30 : CGFLOAT_MIN;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSUInteger section = (NSUInteger)indexPath.section, row = (NSUInteger)indexPath.row;
    if (section >= self.collatedSignalAccounts.count) return;
    if (row >= self.collatedSignalAccounts[section].count) return;
    SignalAccount *signalAccount = self.collatedSignalAccounts[section][row];
    [self showProfileCardInfoWith:signalAccount.recipientId isFromSameThread:false isPresent:false isFromContacts:true];
}

- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.sectionTitles;
}

- (UIView *)headerWithTitle:(NSString *)title {
    
    UIView *headerView = [UIView new];
    headerView.backgroundColor = Theme.bgpagePrimaryColor;
    
    UILabel *lbTitle = [UILabel new];
    lbTitle.font = [UIFont systemFontOfSize:14];
    lbTitle.textColor = Theme.tthirdColor;
    lbTitle.text = title;
    [headerView addSubview:lbTitle];
    [lbTitle autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:16];
    [lbTitle autoVCenterInSuperview];
    
    return headerView;
}


#pragma mark - No Contacts Mode

- (void)hideBackgroundView
{
    [[Environment preferences] setHasDeclinedNoContactsView:YES];

    [self showContactAppropriateViews];
}

- (void)showContactAppropriateViews
{
//    if (self.contactsViewHelper.contactsManager.isSystemContactsAuthorized) {
    if (YES) {
        if (self.contactsViewHelper.hasUpdatedContactsAtLeastOnce && self.contactsViewHelper.signalAccounts.count < 1
            && ![[Environment preferences] hasDeclinedNoContactsView]) {
            self.isNoContactsModeActive = YES;
        } else {
            self.isNoContactsModeActive = NO;
        }
    } else {
        // don't show "no signal contacts", show "no contact access"
//        self.isNoContactsModeActive = NO;
    }
}

- (void)setIsNoContactsModeActive:(BOOL)isNoContactsModeActive
{
    if (isNoContactsModeActive == _isNoContactsModeActive) {
        return;
    }

    _isNoContactsModeActive = isNoContactsModeActive;

    if (isNoContactsModeActive) {
        self.tableView.hidden = YES;
        self.noSignalContactsView.hidden = NO;
    } else {
        self.tableView.hidden = NO;
        self.noSignalContactsView.hidden = YES;
    }

    [self updateTableContents];
}

#pragma mark - SMS Composer Delegate

// called on completion of message screen
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
    switch (result) {
        case MessageComposeResultCancelled:
            break;
        case MessageComposeResultFailed: {
            [OWSAlerts showErrorAlertWithMessage:Localized(@"SEND_INVITE_FAILURE", @"")];
            break;
        }
        case MessageComposeResultSent: {
            [self dismissViewControllerAnimated:NO
                                     completion:^{
                                         DDLogDebug(@"view controller dismissed");
                                     }];
            [OWSAlerts
                showAlertWithTitle:Localized(@"SEND_INVITE_SUCCESS", @"Alert body after invite succeeded")];
            break;
        }
        default:
            break;
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Methods

- (void)dismissPressed
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)newConversationWithRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);
    TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactId:recipientId];
    [self newConversationWithThread:thread];
}

- (void)newConversationWithThread:(TSThread *)thread
{
    OWSAssertDebug(thread != nil);
    
//    [SignalApp.sharedApp presentConversationForThread:thread
//                                               action:ConversationViewActionCompose];
    
    ConversationViewController *viewController = [[ConversationViewController alloc] initWithThread:thread
                                                                                             action:ConversationViewActionCompose
                                                                                     focusMessageId:nil
                                                                                        botViewItem:nil
                                                                                           viewMode:ConversationViewMode_Main
                                                                                 isFromPersonalCard:false];

    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)showNewGroupView:(id)sender
{
    NewGroupViewController *newGroupViewController = [NewGroupViewController new];
    [self.navigationController pushViewController:newGroupViewController animated:YES];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self loadDataIfNecessary];
}

- (BOOL)shouldHideLocalNumber
{
    return NO;
}

#pragma mark - NewNonContactConversationViewControllerDelegate

- (void)recipientIdWasSelected:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);
    [self showProfileCardInfoWith:recipientId isFromSameThread:false isPresent:false isFromContacts:true];
}

- (void)updateNonContactAccountSet:(NSArray<SignalRecipient *> *)recipients
{
    BOOL didUpdate = NO;
    for (SignalRecipient *recipient in recipients) {
        if ([self.nonContactAccountSet containsObject:recipient.recipientId]) {
            continue;
        }
        [self.nonContactAccountSet addObject:recipient.recipientId];
        didUpdate = YES;
    }
    if (didUpdate) {
        [self updateTableContents];
    }
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
                                                                                               viewMode:ConversationViewMode_Main
                                                                                     isFromPersonalCard:false];

        [self pushTopLevelViewController:viewController animateDismissal:NO animatePresentation:YES];
    });
}

- (void)presentTopLevelModalViewController:(UIViewController *)viewController
                          animateDismissal:(BOOL)animateDismissal
                       animatePresentation:(BOOL)animatePresentation
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewController);

    [self presentViewControllerWithBlock:^{
        [self presentViewController:viewController animated:animatePresentation completion:nil];
    }
                        animateDismissal:animateDismissal];
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
        if (self.navigationController.viewControllers.lastObject != self) {
            [CATransaction begin];
            [CATransaction setCompletionBlock:^{
                presentationBlock();
            }];

            [self.navigationController popToViewController:self animated:animateDismissal];
//            [self.navigationController setViewControllers:@[self] animated:animateDismissal];

            [CATransaction commit];
        } else {
            presentationBlock();
        }
    };

    // Perform the first step.
    if (self.presentedViewController) {
//        if ([self.presentedViewController isKindOfClass:[CallViewController class]]) {
//            OWSProdInfo([OWSAnalyticsEvents errorCouldNotPresentViewDueToCall]);
//            return;
//        }
        [self.presentedViewController dismissViewControllerAnimated:animateDismissal completion:dismissNavigationBlock];
    } else {
        dismissNavigationBlock();
    }
}

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

- (void)userTakeScreenshotEvent:(NSNotification *)notify {}

@end

NS_ASSUME_NONNULL_END
