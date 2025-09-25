//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SelectThreadViewController.h"
#import "BlockListUIUtils.h"
#import "ContactTableViewCell.h"
#import "ContactsViewHelper.h"
#import "Environment.h"
#import "NSString+OWS.h"
#import "NewNonContactConversationViewController.h"
#import "OWSContactsManager.h"
#import "OWSTableViewController.h"
#import "ThreadViewHelper.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>

#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSThread.h>
#import <SVProgressHUD/SVProgressHUD.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectThreadViewController () <
    OWSTableViewControllerDelegate,
    ThreadViewHelperDelegate,
    ContactsViewHelperDelegate,
    UISearchBarDelegate,
    DatabaseChangeDelegate>
//    NewNonContactConversationViewControllerDelegate>

@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) ConversationSearcher *fullTextSearcher;
@property (nonatomic, readonly) ThreadViewHelper *threadViewHelper;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, readonly) OWSSearchBar *searchBar;

@property (nonatomic, strong) NSMutableArray <TSThread *> *selectedThreads;
@property (nonatomic, strong) NSMutableArray <NSString *> *selectedUniqueIds;
@property (nonatomic, strong) UIButton *btnSelectDone;

@end

#pragma mark -

@implementation SelectThreadViewController

- (NSMutableArray<TSThread *> *)selectedThreads {
    
    if (!_selectedThreads) {
        _selectedThreads = [NSMutableArray new];
    }
    return _selectedThreads;
}

- (NSMutableArray<NSString *> *)selectedUniqueIds {
    if (!_selectedUniqueIds) {
        _selectedUniqueIds = [NSMutableArray new];
    }
    return _selectedUniqueIds;
}

- (void)loadView
{
    [super loadView];
    
    self.navigationItem.title = Localized(@"FORWARD_MESSAGE_CONVERSATION_SINGLE_TITLE", @"");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:Localized(@"FORWARD_MESSAGE_SELECT_CLOSE", @"") style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(dismissPressed:)];
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:Localized(@"FORWARD_MESSAGE_SELECT_MULTI", @"") style:UIBarButtonItemStylePlain target:self action:@selector(multipleSelectPressed:)];
    self.view.backgroundColor = Theme.backgroundColor;

    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _fullTextSearcher = ConversationSearcher.shared;
    _threadViewHelper = [ThreadViewHelper new];
    _threadViewHelper.delegate = self;

    [self.databaseStorage appendDatabaseChangeDelegate:self];

    [self createViews];
    [self updateTableContents];
    
    if (self.isDefaultMultiSelect) {
        [self multipleSelectPressed:nil];
    }
}

- (void)applyTheme {
    [super applyTheme];
    [self updateTableContents];
}

- (void)createViews
{
    OWSAssertDebug(self.selectThreadViewDelegate);

    // Search
    OWSSearchBar *searchBar = [OWSSearchBar new];
    _searchBar = searchBar;
    searchBar.delegate = self;
    searchBar.customPlaceholder = Localized(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", @"");
    [searchBar sizeToFit];

    UIView *header = nil;
    if ([self.selectThreadViewDelegate respondsToSelector:@selector(createHeaderWithSearchBar:)]) {
        header = [self.selectThreadViewDelegate createHeaderWithSearchBar:searchBar];
    }
    if (!header) {
        header = searchBar;
    }
    [self.view addSubview:header];
    [header autoPinWidthToSuperview];
    [header autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [header setCompressionResistanceVerticalHigh];
    [header setContentHuggingVerticalHigh];

    // Table
    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    _tableViewController.tableViewStyle = UITableViewStylePlain;
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:header];
    [_tableViewController.view autoPinEdgeToSuperviewEdge:ALEdgeBottom];
//    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
//    self.tableViewController.tableView.estimatedRowHeight = 60;
}

- (UITableView *)tableView {
    
    return self.tableViewController.tableView;
}

- (UIButton *)btnSelectDone {
    
    if (!_btnSelectDone) {
        _btnSelectDone = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnSelectDone.bounds = CGRectMake(0, 0, 70, 30);
        _btnSelectDone.layer.cornerRadius = 15;
        _btnSelectDone.clipsToBounds = YES;
        _btnSelectDone.titleLabel.font = [UIFont ows_regularFontWithSize:15.0];
        [_btnSelectDone setBackgroundImage:[UIImage imageWithColor:Theme.buttonDisableColor] forState:UIControlStateDisabled];
        [_btnSelectDone setTitleColor:[UIColor ows_whiteColor] forState:UIControlStateNormal];
        [_btnSelectDone setBackgroundImage:[UIImage imageWithColor:[UIColor ows_materialBlueColor]] forState:UIControlStateNormal];

        [_btnSelectDone setTitle:Localized(@"BUTTON_DONE", @"") forState:UIControlStateDisabled];
        [_btnSelectDone setTitleColor:[UIColor ows_whiteColor] forState:UIControlStateDisabled];
        [_btnSelectDone addTarget:self action:@selector(btnSelectDoneAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _btnSelectDone;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)btnSelectDoneAction:(id)sender {
    
    if ([_selectThreadViewDelegate respondsToSelector:@selector(threadsWasSelected:)]) {
        [_selectThreadViewDelegate threadsWasSelected:self.selectedThreads];
    }
}

#pragma mark Database Update

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges{
    
    OWSAssertIsOnMainThread();
    
    if(![databaseChanges.tableNames containsObject:@"model_TSThread"]){
        return;
    }
    
    [self anyUIDBDidUpdateExternally];
    OWSLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
}

- (void)databaseChangesDidUpdateExternally {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
}

- (void)databaseChangesDidReset {
    
    OWSAssertIsOnMainThread();
    
    [self anyUIDBDidUpdateExternally];
    
}

- (void)anyUIDBDidUpdateExternally
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}
 
#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateTableContents];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self updateTableContents];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self updateTableContents];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
    [self updateTableContents];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self updateTableContents];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    ContactsViewHelper *helper = self.contactsViewHelper;
    OWSTableContents *contents = [OWSTableContents new];
    // Existing threads are listed first, ordered by most recently active
    
    BOOL isShowRecently = YES;
    if (self.selectThreadViewDelegate && [self.selectThreadViewDelegate respondsToSelector:@selector(showRecently)]) {
        isShowRecently = [self.selectThreadViewDelegate showRecently];
    }
    
    @weakify(self)
//    __block NSArray<TSThread *> *filteredThreads;
    __block NSArray<TSThread *> *recentConversations = [NSArray array];
    __block NSArray<SignalAccount *> *contacts = [NSArray array];
    __block NSUInteger recentlyItemCount = 0;
    NSString *searchString = self.searchBar.text.ows_stripped;
    
    void (^updateContents)(void) = ^{
        OWSTableSection *recentChatsSection = [OWSTableSection new];
        recentChatsSection.headerTitle = Localized(
                                                           @"SELECT_THREAD_TABLE_RECENT_CHATS_TITLE", @"Table section header for recently active conversations");
        for (TSThread *thread in recentConversations) {
            if ([self isContainThread:thread]) {
                continue;
            }
            if (thread.isRemovedFromConversation) {
                continue;
            }
            if (thread.isGroupThread) {
                TSGroupThread *groupThread = (TSGroupThread *)thread;
                if (!groupThread.isLocalUserInGroup) {
                    continue;
                }
            }
            
            [recentChatsSection
             addItem:[OWSTableItem
                      itemWithCustomCellBlock:^{
                // To be consistent with the threads (above), we use ContactTableViewCell
                // instead of HomeViewCell to present contacts and threads.
                ContactTableViewCell *cell = [ContactTableViewCell new];
                cell.tintColor = [UIColor ows_materialBlueColor];
                [cell configureWithThread:thread contactsManager:helper.contactsManager];
                return cell;
            }
                      customRowHeight:70
                      actionBlock:^{
                @strongify(self)
                if (!self) {
                    return;
                }
                
                if([self.selectThreadViewDelegate respondsToSelector:@selector(forwordThreadCanBeSelested:)] && ![self.selectThreadViewDelegate forwordThreadCanBeSelested:thread]){
                    return;}
                
                if (self.tableView.isEditing) {
                    [self updateSelectDoneButtonWithThread:thread isAdd:YES];
                    return;
                }
                [self.selectThreadViewDelegate threadsWasSelected:@[thread]];
            }
                      deselectActionBlock:^{
                @strongify(self)
                if (!self) {
                    return;
                }
                if (!self.tableView.isEditing) {
                    return;
                }
                [self updateSelectDoneButtonWithThread:thread isAdd:NO];
            }]];
        }
        
        recentlyItemCount = recentChatsSection.itemCount;
        if (recentlyItemCount > 0) {
            [contents addSection:recentChatsSection];
        }
        
        // 联系人
        BOOL isShowExternal = NO;
        if (self.selectThreadViewDelegate && [self.selectThreadViewDelegate respondsToSelector:@selector(showExternalContacts)]) {
            isShowExternal = [self.selectThreadViewDelegate showExternalContacts];
        }
        
        // Contacts who don't yet have a thread are listed last
        OWSTableSection *otherContactsSection = [OWSTableSection new];
        otherContactsSection.headerTitle = Localized(
                                                             @"SELECT_THREAD_TABLE_OTHER_CHATS_TITLE", @"Table section header for conversations you haven't recently used.");
        
        for (SignalAccount *signalAccount in contacts) {
            if (!isShowExternal && signalAccount.contact.isExternal) {
                continue;
            }
            if ([self isContainSignalAccount:signalAccount]) {
                continue;
            }
            [otherContactsSection
             addItem:[OWSTableItem
                      itemWithCustomCellBlock:^{
                @strongify(self)
                ContactTableViewCell *cell = [ContactTableViewCell new];
                cell.tintColor = [UIColor ows_materialBlueColor];
                if ([signalAccount.recipientId isEqualToString:[TSAccountManager localNumber]] && self.selectThreadViewDelegate && [self.selectThreadViewDelegate respondsToSelector:@selector(showSelfAsNote)]) {
                    BOOL showSelfAsNote = [self.selectThreadViewDelegate showSelfAsNote];
                    cell.cellView.type = showSelfAsNote ? UserOfSelfIconTypeNoteToSelf : UserOfSelfIconTypeRealAvater;
                }
                
                BOOL isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
                if (isBlocked) {
                    cell.accessoryMessage = Localized(
                                                              @"CONTACT_CELL_IS_BLOCKED", @"An indicator that a contact has been blocked.");
                }
                [cell configureWithSignalAccount:signalAccount contactsManager:helper.contactsManager];
                return cell;
            }
                      customRowHeight:70
                      actionBlock:^{
                @strongify(self)
                if (!self) {
                    return;
                }
                TSThread *thread = [self threadOfSignalAccount:signalAccount];
                if (!thread) {
                    return;
                }
                if([self.selectThreadViewDelegate respondsToSelector:@selector(forwordThreadCanBeSelested:)] && ![self.selectThreadViewDelegate forwordThreadCanBeSelested:thread]){return;}
                
                if (self.tableView.isEditing) {
                    [self updateSelectDoneButtonWithThread:thread isAdd:YES];
                    return;
                }
                [self.selectThreadViewDelegate threadsWasSelected:@[thread]];
            }
                      deselectActionBlock:^{
                @strongify(self)
                if (!self) {
                    return;
                }
                if (!self.tableView.isEditing) {
                    return;
                }
                TSThread *thread = [self threadOfSignalAccount:signalAccount];
                if (!thread) {
                    return;
                }
                [self updateSelectDoneButtonWithThread:thread isAdd:NO];
            }]];
        }
        
        if (otherContactsSection.itemCount > 0) {
            [contents addSection:otherContactsSection];
        }
        
        if (recentlyItemCount + otherContactsSection.itemCount < 1) {
            OWSTableSection *emptySection = [OWSTableSection new];
            [emptySection
             addItem:[OWSTableItem
                      softCenterLabelItemWithText:Localized(@"SETTINGS_BLOCK_LIST_NO_CONTACTS",
                                                                    @"A label that indicates the user has no Signal contacts.")]];
            [contents addSection:emptySection];
        }
        self.tableViewController.canEditRow = recentlyItemCount + otherContactsSection.itemCount > 0;
        self.tableViewController.contents = contents;
    };
    
    // 搜索
    if (DTParamsUtils.validateString(searchString)) {
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction *transaction) {

            NSArray *threads = [NSArray array];
            if (isShowRecently) {
                threads = [self.threadViewHelper threadsWithTransaction:transaction];
            }
            
            NSString *searchWord =  [[searchString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            OWSContactsManager *contactsManager = Environment.shared.contactsManager;
            [self.fullTextSearcher queryWithSearchText:searchWord
                                               threads:threads
                                           transaction:transaction
                                       contactsManager:contactsManager
                                                 block:^(NSArray<TSThread *> * _Nonnull recentConversationsResult, NSArray<SignalAccount *> * _Nonnull contactsResult) {
                
                NSMutableSet *contactIdsToIgnore = [NSMutableSet new];
                if (isShowRecently) {
                    for (TSThread *thread in recentConversationsResult) {
                        if ([thread isKindOfClass:[TSContactThread class]]) {
                            TSContactThread *contactThread = (TSContactThread *)thread;
                            [contactIdsToIgnore addObject:contactThread.contactIdentifier];
                        }
                    }
                }
                
                recentConversations = recentConversationsResult;

                NSArray *filterRecentConversations = [contactsResult filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SignalAccount *signalAccount, NSDictionary<NSString *, id> *_Nullable bindings) {
                    return ![contactIdsToIgnore containsObject:signalAccount.recipientId];
                }]];
                contacts = filterRecentConversations;
            }];

        } completion:^{
            
            updateContents();
        }];
    } else {
        
        if (isShowRecently) {
            
            [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction *transaction) {
                if (isShowRecently) {
                    recentConversations = [self.threadViewHelper threadsWithTransaction:transaction];
                }
            } completion:^{
                contacts = [self.contactsViewHelper signalAccounts];
                
                updateContents();
            }];
        } else {
            
            contacts = [self.contactsViewHelper signalAccounts];
            updateContents();
        }
    }
}

- (void)updateSelectDoneButtonWithThread:(TSThread *)thread isAdd:(BOOL)isAdd {
    if (isAdd) {
        NSUInteger maxSelectCount = self.maxSelectCount ?: 9;
        if (self.selectedThreads.count >= maxSelectCount) {
            self.tableViewController.maxSelected = YES;
            NSString *alertFormat =  Localized(@"FORWARD_MESSAGE_SELECT_CONVERSATION_MAX_COUNT", @"");
            if (self.selectThreadViewDelegate && [self.selectThreadViewDelegate respondsToSelector:@selector(selectedMaxCountAlertFormat)]) {
                NSString *customFormat = [self.selectThreadViewDelegate selectedMaxCountAlertFormat];
                if (DTParamsUtils.validateString(customFormat)) {
                    alertFormat = customFormat;
                }
            }
            NSString *alertMessage = [NSString stringWithFormat:alertFormat, maxSelectCount];
            [SVProgressHUD showInfoWithStatus:alertMessage];
            return;
        }
        [self.selectedThreads addObject:thread];
        [self.selectedUniqueIds addObject:thread.uniqueId];
    } else {
        self.tableViewController.maxSelected = NO;
        [self.selectedThreads removeObject:thread];
        [self.selectedUniqueIds removeObject:thread.uniqueId];
    }
    
    self.btnSelectDone.enabled = self.selectedThreads.count > 0;
    self.btnSelectDone.bounds = CGRectMake(0, 0, self.btnSelectDone.isEnabled ? 80 : 70, 30);
    NSString *selectDoneTitle = [NSString stringWithFormat:@"%@(%ld)", Localized(@"BUTTON_DONE", @""), self.selectedThreads.count];
    [self.btnSelectDone setTitle:selectDoneTitle forState:UIControlStateNormal];
}

- (TSThread *)threadOfSignalAccount:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);
    OWSAssertDebug(self.selectThreadViewDelegate);

    ContactsViewHelper *helper = self.contactsViewHelper;
    __block TSThread *thread = nil;
    if ([helper isRecipientIdBlocked:signalAccount.recipientId]
        && ![self.selectThreadViewDelegate canSelectBlockedContact]) {

        __weak SelectThreadViewController *weakSelf = self;
        [BlockListUIUtils showUnblockSignalAccountActionSheet:signalAccount
                                           fromViewController:self
                                              blockingManager:helper.blockingManager
                                              contactsManager:helper.contactsManager
                                              completionBlock:^(BOOL isBlocked) {
                                                  if (!isBlocked) {
                                                      thread = [weakSelf threadOfSignalAccount:signalAccount];
                                                  }
                                              }];
        return thread;
    }

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        thread = [TSContactThread getOrCreateThreadWithContactId:signalAccount.recipientId transaction:transaction];
    });
    OWSAssertDebug(thread);

    return thread;
}

#pragma mark - Filter

//- (NSArray<TSThread *> *)filteredThreadsWithSearchString:(NSString *)searchString
//                                             transaction:(SDSAnyReadTransaction *)transaction
//{
//    NSString *searchTerm = [searchString ows_stripped];
//    NSArray *threads = [self.threadViewHelper threadsWithTransaction:transaction];
//
//    return [self.fullTextSearcher queryRecentThreadsWithSearchText:searchTerm threads:threads transaction:transaction];
//}
//
//- (NSArray<SignalAccount *> *)filteredSignalAccountsWithSearchString:(NSString *)searchString
//                                                         transaction:(SDSAnyReadTransaction *)transaction
//{
//    // We don't want to show a 1:1 thread with Alice and Alice's contact,
//    // so we de-duplicate by recipientId.
//
//    BOOL isShowRecently = YES;
//    if (self.selectThreadViewDelegate && [self.selectThreadViewDelegate respondsToSelector:@selector(showRecently)]) {
//        isShowRecently = [self.selectThreadViewDelegate showRecently];
//    }
//    NSArray<TSThread *> *threads = [self.threadViewHelper threadsWithTransaction:transaction];
//    NSMutableSet *contactIdsToIgnore = [NSMutableSet new];
//    if (isShowRecently) {
//        for (TSThread *thread in threads) {
//            if ([thread isKindOfClass:[TSContactThread class]]) {
//                TSContactThread *contactThread = (TSContactThread *)thread;
//                [contactIdsToIgnore addObject:contactThread.contactIdentifier];
//            }
//        }
//    }
//
//    NSArray<SignalAccount *> *matchingAccounts =
//        [self.contactsViewHelper signalAccountsMatchingSearchString:searchString transaction:transaction];
//
//    return [matchingAccounts
//        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SignalAccount *signalAccount,
//                                        NSDictionary<NSString *, id> *_Nullable bindings) {
//            return ![contactIdsToIgnore containsObject:signalAccount.recipientId];
//        }]];
//}

- (void)originalTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if(![cell isKindOfClass:ContactTableViewCell.class]) return;
    ContactTableViewCell *contactTableViewCell = (ContactTableViewCell *)cell;
    if(![contactTableViewCell.cellView.thread isGroupThread]){return;}
    TSGroupThread *groupThread = (TSGroupThread *)contactTableViewCell.cellView.thread;
    if([self.selectThreadViewDelegate respondsToSelector:@selector(forwordThreadCanBeSelested:)] && ![self.selectThreadViewDelegate forwordThreadCanBeSelested:groupThread]){
        if(!self.selectedThreads.count){
                [self.tableView deselectRowAtIndexPath:indexPath animated:true];
        } else {
            for (TSThread *tmpThread in self.selectedThreads) {
                if ([tmpThread isKindOfClass:TSGroupThread.class]) {
                    TSGroupThread *groupThread_ = (TSGroupThread *)tmpThread;
                    if ([groupThread.groupModel.groupId isEqual:groupThread_.groupModel.groupId]) {
                        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
                    }else {
                        [self.tableView deselectRowAtIndexPath:indexPath animated:true];
                    }
                }
            }
        }
        
    }
}

- (void)originalTableView:(UITableView *)tableView
          willDisplayCell:(UITableViewCell *)cell
        forRowAtIndexPath:(NSIndexPath *)indexPath {
   
    if (![cell isKindOfClass:ContactTableViewCell.class]) {
        return;
    }
    ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
    NSString *uniqueId = nil;
    if (contactCell.thread != nil) {
        TSThread *targetThread = contactCell.thread;
        uniqueId = targetThread.uniqueId;
    } else if (contactCell.signalAccount != nil) {
        SignalAccount *signalAccount = contactCell.signalAccount;
        uniqueId = [@"c" stringByAppendingString:signalAccount.recipientId];
    }
    if (!uniqueId) {
        return;
    }
    
    if ([self.selectedUniqueIds containsObject:uniqueId]) {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

#pragma mark - Events

- (void)dismissPressed:(id)sender
{
    [self.searchBar resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)multipleSelectPressed:(nullable id)sender {
    
    self.navigationItem.title = Localized(@"FORWARD_MESSAGE_CONVERSATION_MULTI_TITLE", @"");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:Localized(@"TXT_CANCEL_TITLE", @"") style:UIBarButtonItemStylePlain target:self action:@selector(cancelMultiplePressed:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.btnSelectDone];
    self.btnSelectDone.enabled = NO;
    self.tableViewController.canEditRow = YES;
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.tableView setEditing:YES animated:YES];
}

- (void)cancelMultiplePressed:(id)sender {
    
    if (self.isDefaultMultiSelect) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    self.tableViewController.canEditRow = NO;
    [self.tableView setEditing:NO animated:YES];
    [self.selectedThreads removeAllObjects];
    [self.selectedUniqueIds removeAllObjects];
    self.tableViewController.maxSelected = NO;
    self.navigationItem.title = Localized(@"FORWARD_MESSAGE_CONVERSATION_SINGLE_TITLE", @"");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:Localized(@"FORWARD_MESSAGE_SELECT_CLOSE", @"") style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(dismissPressed:)];
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:Localized(@"FORWARD_MESSAGE_SELECT_MULTI", @"") style:UIBarButtonItemStylePlain target:self action:@selector(multipleSelectPressed:)];
}

- (void)tableViewWillBeginDragging
{
    [self.searchBar resignFirstResponder];
}

#pragma mark - ThreadViewHelperDelegate

- (void)threadListDidChange
{
//    [self updateTableContents];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return NO;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return  [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    return  [super resignFirstResponder];
}

- (BOOL)isContainThread:(TSThread *)thread {
   
    if (!DTParamsUtils.validateArray(self.existingThreadIds)) {
        return NO;
    }
    __block BOOL isExist = NO;
    [self.existingThreadIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *threadId = [self threadId:thread];
        if ([obj isEqualToString:threadId]) {
            isExist = YES;
            *stop = YES;
        }
    }];
    
    return isExist;
}

- (BOOL)isContainSignalAccount:(SignalAccount *)signalAccount {
  
    if (!DTParamsUtils.validateArray(self.existingThreadIds)) {
        return NO;
    }
    __block BOOL isExist = NO;
    [self.existingThreadIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqualToString:signalAccount.recipientId]) {
            isExist = YES;
            *stop = YES;
        }
    }];
    
    return isExist;
}

///个人Id或群serverId
- (NSString *)threadId:(TSThread *)thread {
    
    NSString *threadId = nil;
    if ([thread isKindOfClass:TSContactThread.class]) {
        threadId = thread.contactIdentifier;
    } else if ([thread isKindOfClass:TSGroupThread.class]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        threadId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    }
    
    return threadId;
}

@end

NS_ASSUME_NONNULL_END
