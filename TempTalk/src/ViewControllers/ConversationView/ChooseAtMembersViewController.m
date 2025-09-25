//
//  ChooseAtMembersViewController.m
//  Signal
//
//  Created by user on 2021/6/2.
//

#import "ChooseAtMembersViewController.h"
#import "TempTalk-Swift.h"
#import "SignalApp.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/UIUtil.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupThread.h>

@import ContactsUI;

NS_ASSUME_NONNULL_BEGIN
@interface ChooseAtMembersViewController () <UISearchBarDelegate, ContactsViewHelperDelegate>

@property (nonatomic, readonly) TSThread *thread;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) ConversationSearcher *fullTextSearcher;

@property (nonatomic, nullable) NSSet <NSString *> *memberRecipientIds;
@property (nonatomic, strong) NSArray <SignalAccount *> *otherSignalAccounts;

@property (nonatomic, assign) ChooseMemberPageType pageType;

@property (nonatomic, strong) OWSSearchBar *searchBar;

@property (nonatomic, strong) NSString *searchText;


@property (nonatomic, strong) NSArray * defaultGroupMemberArr;
@property (nonatomic, strong) NSArray * searchedGroupMemberArr;
@property (nonatomic, strong) NSArray * defaultOtherMemberArr;
@property (nonatomic, strong) NSArray * searchedOtherMemberArr;
@property (nonatomic, strong) NSOperationQueue * operationQueue;

@property (nonatomic, strong) NSMutableArray *operationsArr;

@end

@implementation ChooseAtMembersViewController

+ (ChooseAtMembersViewController *)presentFromViewController:(UIViewController *)viewController
                                                    pageType:(ChooseMemberPageType)pageType
                                                      thread:(TSThread *)thread
                                                    delegate:(id<ChooseAtMembersViewControllerDelegate>) theDelegate
{
    OWSAssertDebug(thread);
    ChooseAtMembersViewController *vc = [[ChooseAtMembersViewController alloc] initWithPageType:pageType];;
    vc.tableViewStyle = UITableViewStylePlain;
    [vc configWithThread:thread];
    vc.resultDelegate = theDelegate;
    OWSNavigationController *navigationController =
        [[OWSNavigationController alloc] initWithRootViewController:vc];
    [viewController presentViewController:navigationController animated:YES completion:nil];
    return vc;
}

- (void)dismissVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
    if ([self.resultDelegate respondsToSelector:@selector(chooseAtPeronsCancel)]) {
        [self.resultDelegate chooseAtPeronsCancel];
    }
}

- (instancetype)initWithPageType:(ChooseMemberPageType)pageType
{
    self = [super init];
    if (self) {
        self.pageType = pageType;
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _fullTextSearcher = ConversationSearcher.shared;
    
    [self observeNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
}

- (void)configWithThread:(TSThread *)thread {
    
    OWSAssertDebug(thread);
    _thread = thread;
    
    NSMutableArray <SignalAccount *> *tmpSignalAccounts = [NSMutableArray arrayWithArray:self.contactsViewHelper.signalAccounts];
    
    if (self.thread.isGroupThread &&
        ChooseMemberPageTypeMention == self.pageType) {
        
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        OWSAssertDebug(groupThread.groupModel);
        OWSAssertDebug(groupThread.groupModel.groupMemberIds);
        
        self.memberRecipientIds = [NSSet setWithArray:groupThread.groupModel.groupMemberIds];
        NSMutableSet *tmpRecipientIds = [self.memberRecipientIds mutableCopy];
        
        [self.contactsViewHelper.signalAccounts enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.contact.isExternal) {
                [tmpSignalAccounts removeObjectAtIndex:idx];
                if ([self.memberRecipientIds containsObject:obj.recipientId]) {
                    [tmpRecipientIds removeObject:obj.recipientId];
                }
                return;
            }
            if ([self.memberRecipientIds containsObject:obj.recipientId]) {
                [tmpSignalAccounts removeObjectAtIndex:idx];
                [tmpRecipientIds removeObject:obj.recipientId];
            }
            if (tmpRecipientIds.count == 0) {
                *stop = YES;
            }
        }];
    }
    
    self.otherSignalAccounts = [tmpSignalAccounts copy];
    [self refreshUIData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                  target:self
                                                  action:@selector(dismissVC)];
    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);
    
    if (self.thread.isGroupThread) {
        self.title = Localized(@"LIST_GROUP_MEMBERS_ACTION", @"title for show group members view");
    } else {
        self.title = Localized(@"COMPOSE_MESSAGE_CONTACT_SECTION_TITLE", @"title for show group members view");
    }
    
    if (ChooseMemberPageTypeMention == self.pageType) {
        
        self.title = Localized(@"LIST_GROUP_MEMBERS_ACTION", @"title for show group members view");
    } else if (ChooseMemberPageTypeSendContact == self.pageType) {
        
        self.title = Localized(@"TABBAR_CONTACT", @"title for show contacts");
    }
    
    [self configUI];
    
    [self updateTableContents];
}

- (void)configUI {
    
    self.tableView.rowHeight = 70;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    OWSSearchBar *searchBar = [OWSSearchBar new];
    _searchBar = searchBar;
    searchBar.customPlaceholder = Localized(@"HOME_VIEW_CONVERSATION_SEARCHBAR_PLACEHOLDER",
                                                    @"Placeholder text for search bar which filters @ contracts.");
    searchBar.delegate = self;
    [searchBar sizeToFit];
    
    self.tableView.tableHeaderView = searchBar;
}

- (void)applyTheme {
    
    [self updateTableContents];
    self.tableView.backgroundColor = Theme.backgroundColor;
    self.tableView.separatorColor = Theme.cellSeparatorColor;
}

#pragma mark - Table Contents
- (NSString *)convertToEnglish:(NSString *)inputStr {
    if(!DTParamsUtils.validateString(inputStr)){return nil;}
    NSData *inputData = [inputStr dataUsingEncoding:NSUTF8StringEncoding];
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSString *gbStr = [[NSString alloc] initWithData:inputData encoding:encoding];
    NSData *outputData = [gbStr dataUsingEncoding:NSUTF8StringEncoding];
    return [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
}


- (void)updateTableContents
{
    OWSAssertDebug(self.thread);
    OWSTableContents *contents = [OWSTableContents new];
    NSString *searchText = [self convertToEnglish:[self.searchBar text]] ;
    BOOL hasSearchText = searchText.length > 0;
    
    if (self.thread.isGroupThread &&
        ChooseMemberPageTypeMention == self.pageType) {
        
        OWSTableSection *membersSection = [OWSTableSection new];
        
        if (hasSearchText) {
            // Group Members
            if (self.searchedGroupMemberArr.count > 0) {
                membersSection.customHeaderView = [self sectionHeaderWithWithGroupSection:YES];
                membersSection.customHeaderHeight = @40;
                [self addMembers:self.searchedGroupMemberArr
                       toSection:membersSection
                needForwardTopic:YES
                 useVerifyAction:NO
                        internal:YES];
            } else {
                membersSection.customHeaderView = nil;
            }
        } else {
            // Group Members
            membersSection.customHeaderView = [self sectionHeaderWithWithGroupSection:YES];
            membersSection.customHeaderHeight = @40;
            [self addALLAsSpecialMemberToSection:membersSection];
            [self addMembers:self.defaultGroupMemberArr
                   toSection:membersSection
            needForwardTopic:YES
             useVerifyAction:NO
                    internal:YES];
            
            
        }
        [contents addSection:membersSection];
    }
    
    OWSTableSection *otherContactsSection = [OWSTableSection new];
    
    if (hasSearchText) {
        if (self.searchedOtherMemberArr.count > 0) {
            
            UIView *headerView = [self sectionHeaderWithWithGroupSection:NO];
            if (headerView) {
                otherContactsSection.customHeaderView = headerView;
                otherContactsSection.customHeaderHeight = @40;
            }
            
            [self addMembers:self.searchedOtherMemberArr
                   toSection:otherContactsSection
            needForwardTopic:NO
             useVerifyAction:NO
                    internal:NO];
        } else {
            otherContactsSection.customHeaderView = nil;
            
        }
        [contents addSection:otherContactsSection];
        self.contents = contents;
        
    } else {
        UIView *headerView = [self sectionHeaderWithWithGroupSection:NO];
        if (headerView) {
            otherContactsSection.customHeaderView = headerView;
            otherContactsSection.customHeaderHeight = @40;
        }
        [self addMembers:self.defaultOtherMemberArr
               toSection:otherContactsSection
        needForwardTopic:NO
         useVerifyAction:NO
                internal:NO];
        [contents addSection:otherContactsSection];
        self.contents = contents;
    }
}

- (void)filteredSignalAccountsWithSearchString:(NSString *)searchString
                             sortResultHandler:(void(^)(NSString *, NSArray<SignalAccount *> *))sortResultHandler
                                   transaction:(SDSAnyReadTransaction *)transaction
{
    ContactsViewHelper *helper = self.contactsViewHelper;
    NSArray<SignalAccount *> *matchingAccounts = [helper signalAccountsMatchingSearchString:searchString transaction:transaction];
    NSArray<SignalAccount *> * result = [matchingAccounts
                                         filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SignalAccount *signalAccount,
                                                                                                           NSDictionary<NSString *, id> *_Nullable bindings) {
        return ![self.memberRecipientIds containsObject:signalAccount.recipientId];
    }]];
    if(sortResultHandler){
        sortResultHandler(searchString, result);
    }
}

- (void)addALLAsSpecialMemberToSection:(OWSTableSection *)section {
    
    if (!self.thread.isGroupThread ||
        ChooseMemberPageTypeSendContact == self.pageType) {
        return;
    }
    
    SignalAccount *specialAccount = [[SignalAccount alloc] initWithRecipientId:MENTIONS_ALL];
    specialAccount.contact = [[Contact alloc] initWithFullName:Localized(@"SPECIAL_ACCOUNT_NAME_ALL", nil)
                                                   phoneNumber:MENTIONS_ALL];
    __weak ChooseAtMembersViewController *weakSelf = self;
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        ContactTableViewCell *cell = [ContactTableViewCell new];
        [cell configureWithSpecialAccount:specialAccount];
        
        return cell;
    } customRowHeight:70
                                               actionBlock:^{
        if ([weakSelf.resultDelegate respondsToSelector:@selector(chooseAtPeronsDidSelectRecipientId:name:mentionType:pageType:)]) {
            [weakSelf.resultDelegate chooseAtPeronsDidSelectRecipientId:specialAccount.recipientId
                                                                   name:specialAccount.contactFullName
                                                            mentionType:DSKProtoDataMessageMentionTypeInternal
                                                               pageType:self.pageType];
        }
    }]];
}

- (void)addMembers:(NSArray<SignalAccount *> *)accounts
         toSection:(OWSTableSection *)section
  needForwardTopic:(BOOL)needForwardTopic
   useVerifyAction:(BOOL)useVerifyAction
          internal:(BOOL)internal
{
    OWSAssertDebug(accounts);
    OWSAssertDebug(section);
    
    @weakify(self)
    /*
     ContactsViewHelper *helper = self.contactsViewHelper;
     // Sort the group members using contacts manager.
     NSArray<SignalAccount *> *sortedAccounts =
     [accounts sortedArrayUsingComparator:^NSComparisonResult(SignalAccount *signalAccountA, SignalAccount *signalAccountB) {
     return [helper.contactsManager compareSignalAccount:signalAccountA withSignalAccount:signalAccountB];
     }];
     */
    for (SignalAccount *signalAccount in accounts) {
        [section addItem:[OWSTableItem
                          itemWithCustomCellBlock:^{
            @strongify(self)
            ContactTableViewCell *cell = [ContactTableViewCell new];
            //            OWSVerificationState verificationState =
            //            [[OWSIdentityManager sharedManager] verificationStateForRecipientId:signalAccount.recipientId];
            //            BOOL isVerified = verificationState == OWSVerificationStateVerified;
            //                                                    BOOL isNoLongerVerified = verificationState == OWSVerificationStateNoLongerVerified;
            //                                                    BOOL isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
            //                                                    if (isNoLongerVerified) {
            //                                                        cell.accessoryMessage = Localized(@"CONTACT_CELL_IS_NO_LONGER_VERIFIED",
            //                                                                                                  @"An indicator that a contact is no longer verified.");
            //                                                    } else if (isBlocked) {
            //                                                        cell.accessoryMessage = Localized(
            //                                                                                                  @"CONTACT_CELL_IS_BLOCKED", @"An indicator that a contact has been blocked.");
            //                                                    }
            
            if (signalAccount) {
                cell.cellView.type = UserOfSelfIconTypeRealAvater;
                cell.cellView.isMentionOtherContacts = self.thread.isGroupThread ? !internal : (![signalAccount.recipientId isEqualToString:TSAccountManager.localNumber] && ![signalAccount.recipientId isEqualToString:self.thread.contactIdentifier]);
                [cell configureWithThread:self.thread signalAccount:signalAccount
                          contactsManager:self.contactsViewHelper.contactsManager];
            }
            if (needForwardTopic) {
                if (signalAccount.recipientId.length <= 6) {
                    cell.cellView.needForwardTopic = true;
                } else {
                    cell.cellView.needForwardTopic = false;
                }
            }
            //            if (isVerified) {
            //                [cell setAttributedSubtitle:cell.verifiedSubtitle];
            //            } else {
            //                [cell setAttributedSubtitle:nil];
            //            }
            
            return cell;
        }
                          customRowHeight:70
                          actionBlock:^{
            @strongify(self)
            NSString *nameDisplay = [self.contactsViewHelper.contactsManager rawDisplayNameForPhoneIdentifier:signalAccount.recipientId];
            if ([self.resultDelegate respondsToSelector:@selector(chooseAtPeronsDidSelectRecipientId:name:mentionType:pageType:)]) {
                DSKProtoDataMessageMentionType type = DSKProtoDataMessageMentionTypeInternal;
                if (self.thread.isGroupThread) {
                    type = internal ? DSKProtoDataMessageMentionTypeInternal : DSKProtoDataMessageMentionTypeExternal;
                } else {
                    type = ([signalAccount.recipientId isEqualToString:TSAccountManager.localNumber] || [signalAccount.recipientId isEqualToString:self.thread.contactIdentifier]) ? DSKProtoDataMessageMentionTypeInternal : DSKProtoDataMessageMentionTypeExternal;
                }
                
                [self.resultDelegate chooseAtPeronsDidSelectRecipientId:signalAccount.recipientId
                                                                   name:nameDisplay
                                                            mentionType:type
                                                               pageType:self.pageType];
            }
        }]];
    }
}

- (void)offerResetAllNoLongerVerified
{
    OWSAssertIsOnMainThread();
    
    UIAlertController *actionSheetController = [UIAlertController
                                                alertControllerWithTitle:nil
                                                message:Localized(@"GROUP_MEMBERS_RESET_NO_LONGER_VERIFIED_ALERT_MESSAGE",
                                                                          @"Label for the 'reset all no-longer-verified group members' confirmation alert.")
                                                preferredStyle:UIAlertControllerStyleAlert];
    
    __weak ChooseAtMembersViewController *weakSelf = self;
    UIAlertAction *verifyAction = [UIAlertAction actionWithTitle:Localized(@"OK", nil)
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *_Nonnull action) {
        [weakSelf resetAllNoLongerVerified];
    }];
    [actionSheetController addAction:verifyAction];
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)resetAllNoLongerVerified
{
    OWSAssertIsOnMainThread();
    
    OWSIdentityManager *identityManger = [OWSIdentityManager sharedManager];
    NSArray<NSString *> *recipientIds = [self noLongerVerifiedRecipientIds];
    for (NSString *recipientId in recipientIds) {
        OWSVerificationState verificationState = [identityManger verificationStateForRecipientId:recipientId];
        if (verificationState == OWSVerificationStateNoLongerVerified) {
            NSData *identityKey = [identityManger identityKeyForRecipientId:recipientId];
            if (identityKey.length < 1) {
                OWSFailDebug(@"Missing identity key for: %@", recipientId);
                continue;
            }
            [identityManger setVerificationState:OWSVerificationStateDefault
                                     identityKey:identityKey
                                     recipientId:recipientId
                           isUserInitiatedChange:YES isSendSystemMessage:NO];
        }
    }
    
    [self updateTableContents];
}

// Returns a collection of the group members who are "no longer verified".
- (NSArray<NSString *> *)noLongerVerifiedRecipientIds
{
    NSMutableArray<NSString *> *result = [NSMutableArray new];
    for (NSString *recipientId in self.thread.recipientIdentifiers) {
        if ([[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId]
            == OWSVerificationStateNoLongerVerified) {
            [result addObject:recipientId];
        }
    }
    return [result copy];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return self.thread.isGroupThread ? YES : NO;
}

#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    [self updateTableContents];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self searchTextDidChange];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self searchTextDidChange];
}

- (void)searchTextDidChange
{
    self.searchText = [self convertToEnglish:[self.searchBar text]];
    [self addOpreationAsTask];
}

- (void)addOpreationAsTask {
    NSBlockOperation *taskOperation = [NSBlockOperation blockOperationWithBlock:^{
        // 执行需要进行的操作...
        [self refreshUIData];
    }];
    
    BOOL isExistSameTask = NO;
    for (NSOperation *op in self.operationsArr) {
        if ([op isEqual:taskOperation]) {
            isExistSameTask = YES;
            break;
        }
    }
    
    if (!isExistSameTask) {
        // 添加新操作到队列中
        [self.operationQueue cancelAllOperations];
        [self.operationsArr addObject:taskOperation];
        [self.operationQueue addOperation:taskOperation];
    }
}



- (void)refreshUIData {
    NSString *searchText = self.searchText;
    BOOL hasSearchText = searchText.length > 0;
    if (hasSearchText) {
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            
            // Group Members
            if(self.thread.isGroupThread){
                NSMutableSet *memberRecipientIds = [self.memberRecipientIds mutableCopy];
                NSMutableArray<SignalAccount *> *memberAccounts = @[].mutableCopy;
                for (NSString *member in memberRecipientIds) {
                    SignalAccount *account = [self.contactsViewHelper signalAccountForRecipientId: member];
                    if (!account) {
                        account = [[SignalAccount alloc] initWithRecipientId:member];
                    }
                    [memberAccounts addObject:account];
                }
                if (memberAccounts.count > 0) {
                    [self.fullTextSearcher filterAtSignalAccounts:memberAccounts withSearchText:searchText searchResultClosure:^(NSString * _Nonnull searchKeyWord, NSArray<SignalAccount *> * _Nonnull filterResultAccounts) {
                        if(self.searchText.ows_stripped.lowercaseString != searchKeyWord.ows_stripped.lowercaseString) return;
                        
                        @synchronized(self.searchedGroupMemberArr) {
                            self.searchedGroupMemberArr = filterResultAccounts;
                        }
                        
                    } transaction:transaction];
                }
            }
            
            ///other
            [self filteredSignalAccountsWithSearchString:searchText sortResultHandler:^(NSString * _Nonnull searchKeyWord, NSArray<SignalAccount *> * _Nonnull defaultSortOtherAccounts) {
                if(self.searchText.ows_stripped.ows_stripped.lowercaseString != searchKeyWord.ows_stripped.lowercaseString) return;
                @synchronized(self.searchedOtherMemberArr) {
                    self.searchedOtherMemberArr = [defaultSortOtherAccounts filter:^BOOL(SignalAccount * _Nonnull item) {
                        return !item.contact.isExternal;
                    }];
                }
            }  transaction:transaction];
            
        } completion:^{
            DispatchMainThreadSafe(^{
                [self updateTableContents];
            });
            
        }];
        
    } else {
        if(self.thread.isGroupThread){
            // Group Members
            NSMutableSet *memberRecipientIds = [self.memberRecipientIds mutableCopy];
            NSMutableArray<SignalAccount *> *memberAccounts = @[].mutableCopy;
            for (NSString *member in memberRecipientIds) {
                SignalAccount *account = [self.contactsViewHelper signalAccountForRecipientId: member];
                if (!account) {
                    account = [[SignalAccount alloc] initWithRecipientId:member];
                }
                [memberAccounts addObject:account];
            }
            
            [self.contactsViewHelper getGroupAccountsByDefaultSortMethod:memberAccounts withSearchText:searchText sortResultHandler:^(NSString * _Nonnull searchKeyWord, NSArray<SignalAccount *> * _Nonnull defaultSortResultAccounts) {
                if(self.searchText.ows_stripped.ows_stripped.lowercaseString != searchKeyWord.ows_stripped.lowercaseString) return;
                @synchronized(self.defaultGroupMemberArr) {
                    self.defaultGroupMemberArr = defaultSortResultAccounts;
                }
            }];
        }
        
        ///other
        [self.contactsViewHelper getGroupAccountsByDefaultSortMethod:self.otherSignalAccounts withSearchText:searchText sortResultHandler:^(NSString * _Nonnull searchKeyWord, NSArray<SignalAccount *> * _Nonnull defaultSortResultAccounts) {
            @synchronized(self.defaultOtherMemberArr) {
                self.defaultOtherMemberArr = [defaultSortResultAccounts filter:^BOOL(SignalAccount * _Nonnull item) {
                    return !item.contact.isExternal;
                }];
            }
            if(self.searchText.ows_stripped.ows_stripped.lowercaseString != searchKeyWord.ows_stripped.lowercaseString) return;
        }];
        DispatchMainThreadSafe(^{
            [self updateTableContents];
        });
    }
}


- (NSAttributedString *)attributeTitleWithGroupSection:(BOOL)isGroupSection {
    NSString *prefix = Localized(isGroupSection ? @"MENTIONS_GROUP_MEMBERS_LIST_TITLE" : @"MENTIONS_OTHER_CONTACTS_LIST_TITLE", @"");
    NSString *suffix = Localized(isGroupSection ? @"MENTIONS_GROUP_MEMBERS_LIST_SUBTITLE" : @"MENTIONS_OTHER_CONTACTS_LIST_SUBTITLE", @"");
    
    NSAttributedString *attributePrefix = [[NSAttributedString alloc] initWithString:prefix attributes:@{NSForegroundColorAttributeName : Theme.primaryTextColor}];
    NSAttributedString *attributeSuffix = [[NSAttributedString alloc] initWithString:suffix attributes:@{NSForegroundColorAttributeName : Theme.ternaryTextColor}];
    NSMutableAttributedString *mutableAttributeText = [NSMutableAttributedString new];
    [mutableAttributeText appendAttributedString:attributePrefix];
    [mutableAttributeText appendAttributedString:attributeSuffix];
    
    return mutableAttributeText.copy;
}

- (UIView *)sectionHeaderWithWithGroupSection:(BOOL)isGroupSection {
    UIView *headerView = nil;
    
    if (ChooseMemberPageTypeMention == self.pageType) {
        
        headerView = [UIView new];
        headerView.backgroundColor = Theme.tableCellBackgroundColor;
        
        UILabel *lbTitle = [UILabel new];
        lbTitle.font = [UIFont systemFontOfSize:13];
        lbTitle.attributedText = [self attributeTitleWithGroupSection:isGroupSection];
        [headerView addSubview:lbTitle];
        [lbTitle autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:16];
        [lbTitle autoVCenterInSuperview];
    }
    
    return headerView;
}

- (NSOperationQueue *)operationQueue {
    if(!_operationQueue) {
        _operationQueue = [NSOperationQueue new];
        [_operationQueue setMaxConcurrentOperationCount:3];
    }
    return _operationQueue;
}

- (NSMutableArray *)operationsArr {
    if(!_operationsArr){
        _operationsArr = [NSMutableArray array];
    }
    return _operationsArr;
}

@end

NS_ASSUME_NONNULL_END
