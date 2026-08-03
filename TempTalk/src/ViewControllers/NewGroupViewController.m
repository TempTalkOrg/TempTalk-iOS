//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NewGroupViewController.h"
#import "AddToGroupViewController.h"
#import "AvatarViewHelper.h"
#import "Yelling-Swift.h"
#import "SignalApp.h"
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSTableViewController.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIUtil.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIViewController+OWS.h>
#import <TTMessaging/UINavigationController+Navigation.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupModel.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import "DTCreateANewGroupAPI.h"
#import <TTServiceKit/DTGroupConfig.h>
#import "DTSelectedAccountToolView.h"
#import "DTAddToGroupItem.h"

NS_ASSUME_NONNULL_BEGIN

const NSUInteger kNewGroupViewControllerAvatarWidth = 58;
const NSUInteger kNewGroupTitleMaxLength = 64;

// Selected-members row height.
static CGFloat const kSelectedRowHeight = 100;
// Divider under the selected-members row.
static CGFloat const kHeaderDividerHeight = 1;
static CGFloat const kHeaderDividerInset = 16;

@interface NewGroupViewController () <UIImagePickerControllerDelegate,
    UITextFieldDelegate,
    ContactsViewHelperDelegate,
    AvatarViewHelperDelegate,
    AddToGroupViewControllerDelegate,
    OWSTableViewControllerDelegate,
    UINavigationControllerDelegate,
    OWSNavigationChildController,
    DTSelectedAccountToolViewDelegate,
    UISearchBarDelegate>

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) AvatarViewHelper *avatarViewHelper;
@property (nonatomic, readonly) ConversationSearcher *fullTextSearcher;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
@property (nonatomic, readonly) UIView *firstSection;
@property (nonatomic, readonly) AvatarImageView *avatarView;
@property (nonatomic, readonly) UITextField *groupNameTextField;
@property (nonatomic, readonly) OWSSearchBar *searchBar;

@property (nonatomic, nullable) UIImage *groupAvatar;
@property (nonatomic) NSMutableSet<NSString *> *memberRecipientIds;
@property (nonatomic) NSMutableArray<NSString *> *memberIds;
// Ordered, removable selection shown in the selected-members row (see isNonRemovableRecipientId:).
@property (nonatomic) NSMutableArray<NSString *> *selectedMemberOrder;

@property (nonatomic) BOOL hasUnsavedChanges;
@property (nonatomic) BOOL hasAppeared;
@property (nonatomic, strong) DTCreateANewGroupAPI *createANewGroupAPI;
@property (nonatomic, strong) DTGroupAvatarUpdateProcessor *groupAvatarUpdateProcessor;

// Non-scrolling header between the group-name section and the table:
// search bar + selected-members row + divider.
@property (nonatomic, strong) DTSelectedAccountToolView *selectedAccountToolView;
@property (nonatomic, strong) UIView *fixedHeaderContainer;
@property (nonatomic, strong) NSLayoutConstraint *fixedHeaderHeightConstraint;
@property (nonatomic, strong) UIView *headerDivider;
@property (nonatomic, assign) BOOL selectedRowVisible;

@end

#pragma mark -

@implementation NewGroupViewController

- (DTCreateANewGroupAPI *)createANewGroupAPI{
    if(!_createANewGroupAPI){
        _createANewGroupAPI = [DTCreateANewGroupAPI new];
    }
    return _createANewGroupAPI;
}

- (DTGroupAvatarUpdateProcessor *)groupAvatarUpdateProcessor{
    if(!_groupAvatarUpdateProcessor){
        _groupAvatarUpdateProcessor = [[DTGroupAvatarUpdateProcessor alloc] init];
    }
    return _groupAvatarUpdateProcessor;
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _messageSender = Environment.shared.messageSender;
    _fullTextSearcher = ConversationSearcher.shared;
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _avatarViewHelper = [AvatarViewHelper new];
    _avatarViewHelper.delegate = self;
    self.memberRecipientIds = [NSMutableSet new];
    self.memberIds = @[self.contactsViewHelper.localNumber].mutableCopy;
    self.selectedMemberOrder = [NSMutableArray array];
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];

    self.title = self.createType == DTCreateGroupTypeConvenient ? Localized(@"NEW_GROUP_CONVENIENT_TITLE", @"") : [MessageStrings newGroupDefaultTitle];

    self.view.backgroundColor = Theme.bg1Color;
    
    if (self.createType == DTCreateGroupTypeConvenient) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(dismissViewController)];
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:Localized(@"NEW_GROUP_CREATE_BUTTON", @"The title for the 'create group' button.")
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(createGroupAction)];
    self.navigationItem.rightBarButtonItem.imageInsets = UIEdgeInsetsMake(0, -10, 0, 10);
    self.navigationItem.rightBarButtonItem.accessibilityLabel
        = Localized(@"FINISH_GROUP_CREATION_LABEL", @"Accessibility label for finishing new group");

    // First section.

    UIView *firstSection = [self firstSectionHeader];
    _firstSection = firstSection;
    [self.view addSubview:firstSection];
    [firstSection autoSetDimension:ALDimensionHeight toSize:100.f];
    [firstSection autoPinWidthToSuperview];
    [firstSection autoPinEdgeToSuperviewSafeArea:ALEdgeTop];

    // Non-scrolling header: search bar + selected-members row + divider.
    UIView *fixedHeader = [UIView new];
    _fixedHeaderContainer = fixedHeader;
    fixedHeader.backgroundColor = Theme.bgpagePrimaryColor;
    fixedHeader.clipsToBounds = YES;
    [self.view addSubview:fixedHeader];
    [fixedHeader autoPinWidthToSuperview];
    [fixedHeader autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstSection];
    _fixedHeaderHeightConstraint = [fixedHeader autoSetDimension:ALDimensionHeight
                                                          toSize:kSelectRecipientSearchBarHeight];

    OWSSearchBar *searchBar = [OWSSearchBar new];
    _searchBar = searchBar;
    searchBar.customPlaceholder = Localized(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT",
        @"Placeholder text for search bar which filters contacts.");
    searchBar.delegate = self;
    [fixedHeader addSubview:searchBar];
    [searchBar autoPinWidthToSuperview];
    [searchBar autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [searchBar autoSetDimension:ALDimensionHeight toSize:kSelectRecipientSearchBarHeight];

    [fixedHeader addSubview:self.selectedAccountToolView];
    [self.selectedAccountToolView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:kSelectRecipientSearchBarHeight];
    [self.selectedAccountToolView autoPinWidthToSuperviewWithMargin:kHeaderDividerInset];
    [self.selectedAccountToolView autoSetDimension:ALDimensionHeight toSize:kSelectedRowHeight];

    [fixedHeader addSubview:self.headerDivider];
    [self.headerDivider autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.selectedAccountToolView];
    [self.headerDivider autoPinWidthToSuperviewWithMargin:kHeaderDividerInset];
    [self.headerDivider autoSetDimension:ALDimensionHeight toSize:kHeaderDividerHeight];

    self.selectedAccountToolView.hidden = YES;
    self.headerDivider.hidden = YES;
    self.selectedRowVisible = NO;

    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:fixedHeader];
    [self autoPinViewToBottomOfViewControllerOrKeyboard:self.tableViewController.view avoidNotch:NO];
    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableViewController.tableView.estimatedRowHeight = 70;
    self.tableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableViewController.tableView.backgroundColor = Theme.bgpagePrimaryColor;

    [self updateTableContents];
}

- (UIView *)firstSectionHeader
{
    UIView *firstSectionHeader = [UIView new];
    // Match the contact cells' background (design spec).
    firstSectionHeader.backgroundColor = Theme.bgpagePrimaryColor;
    firstSectionHeader.userInteractionEnabled = YES;
    [firstSectionHeader
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerWasTapped:)]];
    UIView *threadInfoView = [UIView new];
    [firstSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

    AvatarImageView *avatarView = [AvatarImageView new];
    _avatarView = avatarView;

    [threadInfoView addSubview:avatarView];
    [avatarView autoVCenterInSuperview];
    [avatarView autoPinLeadingToSuperviewMargin];
    [avatarView autoSetDimension:ALDimensionWidth toSize:kNewGroupViewControllerAvatarWidth];
    [avatarView autoSetDimension:ALDimensionHeight toSize:kNewGroupViewControllerAvatarWidth];
    [self updateAvatarView];

    UITextField *groupNameTextField = [UITextField new];
    _groupNameTextField = groupNameTextField;
    groupNameTextField.textColor = Theme.tprimaryColor;
    groupNameTextField.font = [UIFont ows_dynamicTypeTitle2Font];
    
    switch (self.createType) {
        case DTCreateGroupTypeConvenient: {
            TSGroupThread *groupThread = (TSGroupThread *)self.thread;
            // 加密群不能直接读 groupName,会是密文;nameWithTransaction: 会走解密流程
            __block NSString *fromThreadName = @"";
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
                fromThreadName = [groupThread nameWithTransaction:transaction] ?: @"";
            }];
            groupNameTextField.placeholder = [NSString stringWithFormat:Localized(@"NEW_GROUP_CONVENIENT_NAME", @""), fromThreadName];
        }
            break;
        case DTCreateGroupTypeContact: {
            NSString *lcoalName = [self.contactsViewHelper.contactsManager rawDisplayNameForPhoneIdentifier:TSAccountManager.localNumber];
            NSString *otherName = [self.contactsViewHelper.contactsManager rawDisplayNameForPhoneIdentifier:self.thread.contactIdentifier];
            groupNameTextField.placeholder
                = [lcoalName stringByAppendingFormat:@",%@", otherName];
        }
            break;
        case DTCreateGroupTypeByMeeting: {
            groupNameTextField.placeholder = self.meetingGroupName ?: Localized(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"Placeholder text for group name field");
        }
            break;
        case DTCreateGroupTypeDefault: {
            groupNameTextField.placeholder
                = Localized(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"Placeholder text for group name field");
        }
            break;
    }
    groupNameTextField.delegate = self;
    [groupNameTextField addTarget:self
                           action:@selector(groupNameDidChange:)
                 forControlEvents:UIControlEventEditingChanged];
    [threadInfoView addSubview:groupNameTextField];
    [groupNameTextField autoVCenterInSuperview];
    [groupNameTextField autoPinTrailingToSuperviewMargin];
    [groupNameTextField autoPinLeadingToTrailingEdgeOfView:avatarView offset:16.f];

    [avatarView
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTouched:)]];
    avatarView.userInteractionEnabled = YES;

    return firstSectionHeader;
}

- (void)headerWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.groupNameTextField becomeFirstResponder];
    }
}

- (void)avatarTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self showChangeAvatarUI];
    }
}

#pragma mark - Selected-members header

// Reloads the selected-members row; toggles its visibility and the header height on empty <-> non-empty.
- (void)refreshSelectedRow {
    [self.selectedAccountToolView reloadWithData:self.selectedMemberOrder];
    BOOL hasSelection = self.selectedMemberOrder.count > 0;
    if (hasSelection == self.selectedRowVisible) {
        return;
    }
    self.selectedRowVisible = hasSelection;
    self.selectedAccountToolView.hidden = !hasSelection;
    self.headerDivider.hidden = !hasSelection;
    self.fixedHeaderHeightConstraint.constant = hasSelection
        ? kSelectRecipientSearchBarHeight + kSelectedRowHeight + kHeaderDividerHeight
        : kSelectRecipientSearchBarHeight;
}

- (UIView *)headerDivider {
    if (!_headerDivider) {
        _headerDivider = [[UIView alloc] init];
        _headerDivider.backgroundColor = Theme.dividerColor;
    }
    return _headerDivider;
}

- (DTSelectedAccountToolView *)selectedAccountToolView {
    if (!_selectedAccountToolView) {
        _selectedAccountToolView = [[DTSelectedAccountToolView alloc] initWithDataSource:@[]];
        _selectedAccountToolView.toolViewDelegate = self;
    }
    return _selectedAccountToolView;
}

#pragma mark - DTSelectedAccountToolViewDelegate

// Tapping a selected avatar's ✕ removes that member from the selection.
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath || indexPath.row >= (NSInteger)self.selectedMemberOrder.count) {
        return;
    }
    NSString *recipientId = [self.selectedMemberOrder objectAtIndex:(NSUInteger)indexPath.row];
    if (!recipientId.length) {
        return;
    }
    [self removeRecipientId:recipientId];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak NewGroupViewController *weakSelf = self;
    ContactsViewHelper *contactsViewHelper = self.contactsViewHelper;

    NSArray<SignalAccount *> *signalAccounts = [self.contactsViewHelper.signalAccounts filter:^BOOL(SignalAccount * _Nonnull item) {
        return !item.isBot;
    }];
    
    NSMutableSet *nonContactMemberRecipientIds = [self.memberRecipientIds mutableCopy];
    for (SignalAccount *signalAccount in signalAccounts) {
        [nonContactMemberRecipientIds removeObject:signalAccount.recipientId];
    }
    NSString *searchText = [self.searchBar text];
    BOOL hasSearchText = searchText.length > 0;
    
    if (hasSearchText) {
        if (nonContactMemberRecipientIds.count > 0 || signalAccounts.count < 1) {

            OWSTableSection *nonContactsSection = [OWSTableSection new];
            NSArray *sortNonContactMemberRecipientIds = [nonContactMemberRecipientIds.allObjects sortedArrayUsingSelector:@selector(compare:)];
            
            NSMutableArray<SignalAccount *> *sortNonContactMemberAccounts = @[].mutableCopy;
            for (NSString *nonContactMemberRecipientId in sortNonContactMemberRecipientIds) {
                SignalAccount *account = [contactsViewHelper signalAccountForRecipientId:nonContactMemberRecipientId];
                if (account) { [sortNonContactMemberAccounts addObject:account]; }
            }
            
            if (sortNonContactMemberAccounts.count) {
                // 搜索
                __block NSArray<SignalAccount *> *filtedNonContactMemberAccounts = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                    filtedNonContactMemberAccounts = [self.fullTextSearcher filterSignalAccounts:sortNonContactMemberAccounts
                                                                                  withSearchText:searchText
                                                                                     transaction:transaction];
                }];
                
                for (SignalAccount *account in filtedNonContactMemberAccounts) {
                    if (account.isLocalSignalAccount) {
                        continue;;
                    }
                    [nonContactsSection
                        addItem:[OWSTableItem
                                    itemWithCustomCellBlock:^{
                                        NewGroupViewController *strongSelf = weakSelf;
                                        OWSCAssertDebug(strongSelf);

                                        return [strongSelf newCellWithAccount:account recipientId:nil];
                                    }
                                    customRowHeight:70
                                    actionBlock:^{
                                        BOOL isCurrentMember = [weakSelf.memberRecipientIds containsObject:account.recipientId];
                                        BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:account.recipientId];
                                        if (isCurrentMember) {
                                            [weakSelf removeRecipientId:account.recipientId];
                                        } else if (isBlocked) {
                                            [BlockListUIUtils
                                                showUnblockPhoneNumberActionSheet:account.recipientId
                                                               fromViewController:weakSelf
                                                                  blockingManager:contactsViewHelper.blockingManager
                                                                  contactsManager:contactsViewHelper.contactsManager
                                                                  completionBlock:^(BOOL isStillBlocked) {
                                                                      if (!isStillBlocked) {
                                                                          [weakSelf addRecipientId:account.recipientId];
                                                                      }
                                                                  }];
                                        } else {

                                            BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
                                                presentAlertIfNecessaryWithRecipientId:account.recipientId
                                                                      confirmationText:Localized(
                                                                                           @"SAFETY_NUMBER_CHANGED_CONFIRM_"
                                                                                           @"ADD_TO_GROUP_ACTION",
                                                                                           @"button title to confirm adding "
                                                                                           @"a recipient to a group when "
                                                                                           @"their safety "
                                                                                           @"number has recently changed")
                                                                       contactsManager:contactsViewHelper.contactsManager
                                                                            completion:^(BOOL didConfirmIdentity) {
                                                                                if (didConfirmIdentity) {
                                                                                    [weakSelf addRecipientId:account.recipientId];
                                                                                }
                                                                            }];
                                            if (didShowSNAlert) {
                                                return;
                                            }


                                            [weakSelf addRecipientId:account.recipientId];
                                        }
                                    }]];
                }
                [contents addSection:nonContactsSection];
            }
        }
        
        // Contacts (no section header per the redesigned selector)

        OWSTableSection *signalAccountSection = [OWSTableSection new];
        if (signalAccounts.count > 0) {

            // modified: disable invite friends by system contacts and phone sms.
            if (nonContactMemberRecipientIds.count < 1) {
                // If the group contains any non-contacts or has not contacts,
                // the "add non-contact user" will show up in the previous section
                // of the table. However, it's more attractive to hide that section
                // for the common case where people want to create a group from just
                // their contacts.  Therefore, when that section is hidden, we want
                // to allow people to add non-contacts.

                //[signalAccountSection addItem:[self createAddNonContactItem]];
            }


            __block NSArray<SignalAccount *> *filtedSignalAccounts = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
//                filtedSignalAccounts = [self.fullTextSearcher filterSignalAccounts:signalAccounts withSearchText:searchText transaction:transaction];
                
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                [self.fullTextSearcher queryWithSearchText:searchText
                                                   threads:@[]
                                               transaction:transaction
                                           contactsManager:contactsManager
                                                     block:^(NSArray<TSThread *> * _Nonnull recentConversationsResult, NSArray<SignalAccount *> * _Nonnull contactsResult) {
                    filtedSignalAccounts = contactsResult;
                }];
            }];

            for (SignalAccount *signalAccount in filtedSignalAccounts) {
                if (signalAccount.contact.isExternal || signalAccount.isLocalSignalAccount || signalAccount.isBot) {
                    continue;
                }
                [signalAccountSection
                    addItem:[OWSTableItem
                                itemWithCustomCellBlock:^{
                                    NewGroupViewController *strongSelf = weakSelf;
                                    OWSCAssertDebug(strongSelf);

                                    return [strongSelf newCellWithAccount:signalAccount recipientId:nil];
                                }
                                customRowHeight:70
                                actionBlock:^{
                                    NSString *recipientId = signalAccount.recipientId;
                                    BOOL isCurrentMember = [weakSelf.memberRecipientIds containsObject:recipientId];
                                    BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:recipientId];
                                    if (isCurrentMember) {
                                        [weakSelf removeRecipientId:recipientId];
                                    } else if (isBlocked) {
                                        [BlockListUIUtils
                                            showUnblockSignalAccountActionSheet:signalAccount
                                                             fromViewController:weakSelf
                                                                blockingManager:contactsViewHelper.blockingManager
                                                                contactsManager:contactsViewHelper.contactsManager
                                                                completionBlock:^(BOOL isStillBlocked) {
                                                                    if (!isStillBlocked) {
                                                                        [weakSelf addRecipientId:recipientId];
                                                                    }
                                                                }];
                                    } else {
                                        BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
                                            presentAlertIfNecessaryWithRecipientId:signalAccount.recipientId
                                                                  confirmationText:Localized(
                                                                                       @"SAFETY_NUMBER_CHANGED_CONFIRM_"
                                                                                       @"ADD_TO_GROUP_ACTION",
                                                                                       @"button title to confirm adding "
                                                                                       @"a recipient to a group when "
                                                                                       @"their safety "
                                                                                       @"number has recently changed")
                                                                   contactsManager:contactsViewHelper.contactsManager
                                                                        completion:^(BOOL didConfirmIdentity) {
                                                                            if (didConfirmIdentity) {
                                                                                [weakSelf addRecipientId:recipientId];
                                                                            }
                                                                        }];
                                        if (didShowSNAlert) {
                                            return;
                                        }

                                        [weakSelf addRecipientId:recipientId];
                                    }
                                }]];
            }
        } else {
            [signalAccountSection
                addItem:[OWSTableItem
                            softCenterLabelItemWithText:Localized(@"SETTINGS_BLOCK_LIST_NO_CONTACTS",
                                                            @"A label that indicates the user has no Signal contacts.")]];
        }
        [contents addSection:signalAccountSection];
        
    } else {
        
        // Non-contact Members

        if (nonContactMemberRecipientIds.count > 0 || signalAccounts.count < 1) {

            OWSTableSection *nonContactsSection = [OWSTableSection new];
            //nonContactsSection.headerTitle = Localized(
            //    @"NEW_GROUP_NON_CONTACTS_SECTION_TITLE", @"a title for the non-contacts section of the 'new group' view.");

            //[nonContactsSection addItem:[self createAddNonContactItem]];

            for (NSString *recipientId in
                [nonContactMemberRecipientIds.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
                if ([recipientId isEqualToString:[TSAccountManager localNumber]]) {
                    continue;;
                }
                [nonContactsSection
                    addItem:[OWSTableItem
                                itemWithCustomCellBlock:^{
                                    NewGroupViewController *strongSelf = weakSelf;
                                    OWSCAssertDebug(strongSelf);

                                    return [strongSelf newCellWithAccount:nil recipientId:recipientId];
                                }
                                customRowHeight:70
                                actionBlock:^{
                                    BOOL isCurrentMember = [weakSelf.memberRecipientIds containsObject:recipientId];
                                    BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:recipientId];
                                    if (isCurrentMember) {
                                        [weakSelf removeRecipientId:recipientId];
                                    } else if (isBlocked) {
                                        [BlockListUIUtils
                                            showUnblockPhoneNumberActionSheet:recipientId
                                                           fromViewController:weakSelf
                                                              blockingManager:contactsViewHelper.blockingManager
                                                              contactsManager:contactsViewHelper.contactsManager
                                                              completionBlock:^(BOOL isStillBlocked) {
                                                                  if (!isStillBlocked) {
                                                                      [weakSelf addRecipientId:recipientId];
                                                                  }
                                                              }];
                                    } else {

                                        BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
                                            presentAlertIfNecessaryWithRecipientId:recipientId
                                                                  confirmationText:Localized(
                                                                                       @"SAFETY_NUMBER_CHANGED_CONFIRM_"
                                                                                       @"ADD_TO_GROUP_ACTION",
                                                                                       @"button title to confirm adding "
                                                                                       @"a recipient to a group when "
                                                                                       @"their safety "
                                                                                       @"number has recently changed")
                                                                   contactsManager:contactsViewHelper.contactsManager
                                                                        completion:^(BOOL didConfirmIdentity) {
                                                                            if (didConfirmIdentity) {
                                                                                [weakSelf addRecipientId:recipientId];
                                                                            }
                                                                        }];
                                        if (didShowSNAlert) {
                                            return;
                                        }


                                        [weakSelf addRecipientId:recipientId];
                                    }
                                }]];
            }
            [contents addSection:nonContactsSection];
        }

        // Contacts (no section header per the redesigned selector)

        OWSTableSection *signalAccountSection = [OWSTableSection new];
        if (signalAccounts.count > 0) {
            
            // modified: disable invite friends by system contacts and phone sms.
            if (nonContactMemberRecipientIds.count < 1) {
                // If the group contains any non-contacts or has not contacts,
                // the "add non-contact user" will show up in the previous section
                // of the table. However, it's more attractive to hide that section
                // for the common case where people want to create a group from just
                // their contacts.  Therefore, when that section is hidden, we want
                // to allow people to add non-contacts.
                
                //[signalAccountSection addItem:[self createAddNonContactItem]];
            }

            for (SignalAccount *signalAccount in signalAccounts) {
                if (signalAccount.contact.isExternal || signalAccount.isLocalSignalAccount) {
                    continue;
                }
                [signalAccountSection
                    addItem:[OWSTableItem
                                itemWithCustomCellBlock:^{
                                    NewGroupViewController *strongSelf = weakSelf;
                                    OWSCAssertDebug(strongSelf);

                                    return [strongSelf newCellWithAccount:signalAccount recipientId:nil];
                                }
                                customRowHeight:70
                                actionBlock:^{
                                    NSString *recipientId = signalAccount.recipientId;
                                    BOOL isCurrentMember = [weakSelf.memberRecipientIds containsObject:recipientId];
                                    BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:recipientId];
                                    if (isCurrentMember) {
                                        [weakSelf removeRecipientId:recipientId];
                                    } else if (isBlocked) {
                                        [BlockListUIUtils
                                            showUnblockSignalAccountActionSheet:signalAccount
                                                             fromViewController:weakSelf
                                                                blockingManager:contactsViewHelper.blockingManager
                                                                contactsManager:contactsViewHelper.contactsManager
                                                                completionBlock:^(BOOL isStillBlocked) {
                                                                    if (!isStillBlocked) {
                                                                        [weakSelf addRecipientId:recipientId];
                                                                    }
                                                                }];
                                    } else {
                                        BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
                                            presentAlertIfNecessaryWithRecipientId:signalAccount.recipientId
                                                                  confirmationText:Localized(
                                                                                       @"SAFETY_NUMBER_CHANGED_CONFIRM_"
                                                                                       @"ADD_TO_GROUP_ACTION",
                                                                                       @"button title to confirm adding "
                                                                                       @"a recipient to a group when "
                                                                                       @"their safety "
                                                                                       @"number has recently changed")
                                                                   contactsManager:contactsViewHelper.contactsManager
                                                                        completion:^(BOOL didConfirmIdentity) {
                                                                            if (didConfirmIdentity) {
                                                                                [weakSelf addRecipientId:recipientId];
                                                                            }
                                                                        }];
                                        if (didShowSNAlert) {
                                            return;
                                        }

                                        [weakSelf addRecipientId:recipientId];
                                    }
                                }]];
            }
        } else {
            [signalAccountSection
                addItem:[OWSTableItem
                            softCenterLabelItemWithText:Localized(@"SETTINGS_BLOCK_LIST_NO_CONTACTS",
                                                            @"A label that indicates the user has no Signal contacts.")]];
        }
        [contents addSection:signalAccountSection];
    }

    self.tableViewController.contents = contents;
}

- (OWSTableItem *)createAddNonContactItem
{
    __weak NewGroupViewController *weakSelf = self;
    return [OWSTableItem
        disclosureItemWithText:Localized(@"NEW_GROUP_ADD_NON_CONTACT",
                                   @"A label for the cell that lets you add a new non-contact member to a group.")
               customRowHeight:UITableViewAutomaticDimension
                   actionBlock:^{
                       AddToGroupViewController *viewController = [AddToGroupViewController new];
                       viewController.addToGroupDelegate = weakSelf;
                       viewController.hideContacts = YES;
                       [weakSelf.navigationController pushViewController:viewController animated:YES];
                   }];
}

- (ContactTableViewCell *)newCellWithAccount:(nullable SignalAccount *)signalAccount
                                 recipientId:(nullable NSString *)recipientId {
    ContactTableViewCell *cell = [ContactTableViewCell new];

    if (!signalAccount) {
        signalAccount = [self.contactsViewHelper signalAccountForRecipientId:recipientId];
    }
    if (!recipientId) {
        recipientId = signalAccount ? signalAccount.recipientId : recipientId;
    }
    BOOL isContainMember = [self.memberRecipientIds containsObject:recipientId];
    BOOL isBlocked = [self.contactsViewHelper isRecipientIdBlocked:recipientId];
    if (isContainMember) {
        // Pre-seeded, non-removable members show the gray DisabledSelected box.
        BOOL nonRemovable = [self isNonRemovableRecipientId:recipientId];
        if (nonRemovable) {
            cell.selectionStatus = ContactCellSelectionStatusDisabledSelected;
            cell.userInteractionEnabled = NO;
        } else {
            cell.selectionStatus = ContactCellSelectionStatusSelected;
        }
    } else if (isBlocked) {
        cell.selectionStatus = ContactCellSelectionStatusUnselected;
        cell.accessoryMessage = Localized(
            @"CONTACT_CELL_IS_BLOCKED", @"An indicator that a contact has been blocked.");
    } else {
        cell.selectionStatus = ContactCellSelectionStatusUnselected;
    }

    if (signalAccount) {
        [cell configureWithSignalAccount:signalAccount
                         contactsManager:self.contactsViewHelper.contactsManager];
    } else {
        [cell configureWithRecipientId:recipientId
                       contactsManager:self.contactsViewHelper.contactsManager];
    }

    return cell;
}

// Re-assert the checkbox after UITableView's setSelected: flips it on display.
- (void)originalTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![cell isKindOfClass:ContactTableViewCell.class]) {
        return;
    }
    ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
    NSString *recipientId = contactCell.signalAccount.recipientId;
    if (!recipientId.length) {
        return;
    }
    if ([self.memberRecipientIds containsObject:recipientId]) {
        BOOL nonRemovable = [self isNonRemovableRecipientId:recipientId];
        contactCell.selectionStatus = nonRemovable ? ContactCellSelectionStatusDisabledSelected : ContactCellSelectionStatusSelected;
    } else {
        contactCell.selectionStatus = ContactCellSelectionStatusUnselected;
    }
}

// Non-removable: the local user, the contact a group is created with, or pre-seeded meeting members.
- (BOOL)isNonRemovableRecipientId:(NSString *)recipientId
{
    if (!recipientId.length) {
        return YES;
    }
    if ([recipientId isEqualToString:[TSAccountManager localNumber]]) {
        return YES;
    }
    if (self.createType == DTCreateGroupTypeContact && [recipientId isEqualToString:self.thread.contactIdentifier]) {
        return YES;
    }
    if (self.createType == DTCreateGroupTypeByMeeting && [self.meetingMemberIds containsObject:recipientId]) {
        return YES;
    }
    return NO;
}

- (void)removeRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.memberRecipientIds removeObject:recipientId];
    [self.memberIds removeObject:recipientId];
    [self.selectedMemberOrder removeObject:recipientId];
    [self updateTableContents];
    [self generateNewGroupAvatar];
    [self refreshSelectedRow];
}

- (void)addRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.memberRecipientIds addObject:recipientId];
    [self.memberIds addObject:recipientId];
    if (![self isNonRemovableRecipientId:recipientId] && ![self.selectedMemberOrder containsObject:recipientId]) {
        [self.selectedMemberOrder addObject:recipientId];
    }
    self.hasUnsavedChanges = YES;
    [self updateTableContents];
    [self generateNewGroupAvatar];
    [self refreshSelectedRow];
}

- (void)generateNewGroupAvatar {
    
    if (self.memberIds.count <= 1) {
        self.groupAvatar = nil;
        return;
    }
    
    NSMutableArray *letters = @[].mutableCopy;
    NSMutableDictionary *colorMap = [UIColor ows_conversationThreadColorMap].mutableCopy;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        for (NSString *memberId in self.memberIds) {
            NSString *recipientId = memberId;
            BOOL unexpectedId = [memberId.lowercaseString isEqualToString:@"unknown"] || !DTParamsUtils.validateString(memberId);
            if (unexpectedId) {
                recipientId = @"#";
            }
            NSString *colorName = [TSThread stableConversationColorNameForString:recipientId];
            [colorMap removeObjectForKey:colorName];
            UIColor *color = [UIColor ows_conversationColorForColorName:colorName];
            NSString *displayName = [Environment.shared.contactsManager rawDisplayNameForPhoneIdentifier:recipientId transaction:transaction];
            TTLetterItem *item = [[TTLetterItem alloc] initWithChar:displayName color:color];
            [letters addObject:item];
        }
    }];
    
    if (letters.count <= 1) {
        self.groupAvatar = nil;
        return;
    }
    
    NSArray *remainColors = colorMap.allValues;
    if (remainColors.count == 0) {
        remainColors = [UIColor ows_conversationThreadColorMap].allValues;
    }
    UIColor *bgColor = remainColors[arc4random_uniform((uint32_t)remainColors.count)];
    self.groupAvatar = [TTGroupAvatarGenerator generateWith:letters.copy backgroundColor:bgColor sizePx:48];
}

#pragma mark - Methods
- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.createType == DTCreateGroupTypeContact) {
        [self.memberRecipientIds addObject:self.thread.contactIdentifier];
        [self.memberIds addObject:self.thread.contactIdentifier];
        [self generateNewGroupAvatar];
    } else if (self.createType == DTCreateGroupTypeByMeeting) {
        NSArray *tmpRecipientIds = [self.meetingMemberIds allObjects];
        [self.memberRecipientIds addObjectsFromArray:tmpRecipientIds];
    }
    
    BOOL isFromPresent = self.navigationController.presentingViewController;
    if (isFromPresent) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(dismissAction)];
    }
}

- (void)dismissAction {
    
    [self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (!self.hasAppeared) {
        [self.groupNameTextField becomeFirstResponder];
        self.hasAppeared = YES;
    }
}

- (void)dealloc {
}

#pragma mark - Actions

- (void)dismissViewController {
    
    [self.groupNameTextField resignFirstResponder];
    
    if (!self.hasUnsavedChanges) {
        // If user made no changes, return to conversation settings view.
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    UIAlertController *controller = [UIAlertController
        alertControllerWithTitle:
            Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_TITLE",
                @"The alert title if user tries to exit the new group view without saving changes.")
                         message:
                             Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_MESSAGE",
                                 @"The alert message if user tries to exit the new group view without saving changes.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [controller
        addAction:[UIAlertAction actionWithTitle:Localized(@"ALERT_DISCARD_BUTTON",
                                                     @"The label for the 'discard' button in alerts and action sheets.")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
       
                                                    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }]];
    [controller addAction:[OWSAlerts cancelAction]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)uploadGroupAvatarSuccess:(void (^)(NSString * _Nullable))successHandler
                         failure:(void (^)(NSError *error))failureHandler{

    if (!self.groupAvatar) {
        // No avatar selected: create without avatar (not a failure).
        successHandler(nil);
        return;
    }

    // OWSUploadToOSSOperation retries internally and OWSOperation fires the failure
    // callback once per attempt (OWSOperation.reportError:), so the handler can be
    // invoked many times for one upload. Run it at most once, otherwise group
    // creation would fire repeatedly (duplicate groups / stacked error toasts).
    __block BOOL handlerCalled = NO;
    void (^finishOnce)(NSString * _Nullable, NSError * _Nullable) = ^(NSString * _Nullable avatar, NSError * _Nullable error) {
        @synchronized (self) {
            if (handlerCalled) {
                return;
            }
            handlerCalled = YES;
        }
        if (error) {
            if (failureHandler) {
                failureHandler(error);
            }
        } else if (successHandler) {
            successHandler(avatar);
        }
    };

    NSData *data = UIImagePNGRepresentation(self.groupAvatar);
    id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:data fileExtension:@"png"];
    [self.groupAvatarUpdateProcessor uploadAttachment:dataSource
                                          contentType:OWSMimeTypeImagePng
                                       sourceFilename:nil
                                              success:^(NSString * avatar) {
        if (!DTParamsUtils.validateString(avatar)) {
            OWSLogError(@"uploadGroupAvatar avatar is empty!");
        }
        finishOnce(avatar, nil);
    } failure:^(NSError * _Nonnull error) {
        // Avatar upload failed: abort creation; caller shows a single toast.
        OWSLogError(@"uploadGroupAvatar failed, abort group creation. error: %@", error.localizedDescription);
        finishOnce(nil, error);
    }];
}

- (void)createGroupAction {
    
    [self.groupNameTextField resignFirstResponder];
    [DTToastHelper svShow];
    
    NSString *defaultGroupName = self.createType == DTCreateGroupTypeDefault ? Localized(@"NEW_GROUP_DEFAULT_TITLE", @"") : self.groupNameTextField.placeholder;
    NSString *groupName = [self.groupNameTextField.text ows_stripped];
    groupName = groupName.length ? groupName : defaultGroupName;
    if (groupName.length > kNewGroupTitleMaxLength) {
        groupName = [groupName substringToIndex:kNewGroupTitleMaxLength];
    }

    NSArray *members = self.memberRecipientIds.allObjects;
    members = members ? members : @[];
 
    if (self.createType == DTCreateGroupTypeByMeeting) {
        [[DTCallManager sharedInstance] createGroupV1WithGroupName:groupName 
                                                         meetingId:self.meetingId
                                                         memberIds:members
                                                           success:^(id  _Nonnull responseObject) {
            
            NSNumber *numberStatus = responseObject[@"status"];
            if (numberStatus.intValue != 0) {
                OWSLogError(@"%@ create group error: %@, reason: %@", self.logTag, numberStatus, responseObject[@"reason"]);
                [DTToastHelper dismiss];
                return;
            }
            
            NSDictionary *data = responseObject[@"data"];
            if (!DTParamsUtils.validateDictionary(data)) {
                [DTToastHelper dismiss];
                return;
            }
            
            [DTToastHelper dismiss];
            NSString *gid = data[@"gid"];
            NSString *inviteCode = data[@"inviteCode"];
            BOOL isGroupAlreadyExist = NO;
            if (data[@"type"]) {
                NSNumber *number_type = (NSNumber *)(data[@"type"]);
                isGroupAlreadyExist = (number_type.intValue == 1);
            }
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                
                if (!isGroupAlreadyExist) {
                    TSGroupModel *model = [self makeGroupWithId:gid groupName:groupName transaction:writeTransaction];
                    TSGroupThread *thread = [TSGroupThread getOrCreateThreadWithGroupModel:model transaction:writeTransaction];
                    [thread anyInsertWithTransaction:writeTransaction];
                    [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread transaction:writeTransaction];
                    
                    DTGroupBaseInfoEntity *groupBaseInfo = [DTGroupBaseInfoEntity new];
                    groupBaseInfo.name = groupName;
                    groupBaseInfo.gid = gid;
                    [DTGroupUtils addGroupBaseInfo:groupBaseInfo transaction:writeTransaction];
                }
                
                DispatchMainThreadSafe(^{
                    [self.navigationController dismissViewControllerAnimated:YES
                                                                  completion:^{
                        if (self.createGroupFinish) {
                            self.createGroupFinish(gid, inviteCode, isGroupAlreadyExist);
                        }
                    }];
                });
            });
        } failure:^(NSError * _Nonnull error) {
            [DTToastHelper dismissWithInfo:error.localizedDescription];
        }];
    } else {
        
        [self uploadGroupAvatarSuccess:^(NSString * avatar) {
            BOOL encryptionEnabled = [DTGroupConfig fetchGroupConfig].encryptionEnabled;
            if (encryptionEnabled) {
                [self createEncryptedGroupWithName:groupName avatar:avatar members:members];
            } else {
                [self createPlainGroupWithName:groupName avatar:avatar members:members];
            }
        } failure:^(NSError *error) {
            // Avatar upload failed: abort creation. finishOnce dedups retries, so one toast.
            [DTToastHelper dismissWithInfo:error.localizedDescription];
        }];
    }
}

- (void)createPlainGroupWithName:(NSString *)groupName
                          avatar:(NSString *)avatar
                         members:(NSArray *)members
{
    [self.createANewGroupAPI sendRequestWithName:groupName
                                          avatar:avatar ?: @""
                                         numbers:members
                                         success:^(DTCreateANewGroupDataEntity * _Nonnull entity) {

        __block TSGroupThread *thread = nil;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {

            TSGroupModel *model = [self makeGroupWithId:entity.gid groupName:groupName transaction:writeTransaction];
            thread = [TSGroupThread getOrCreateThreadWithGroupModel:model transaction:writeTransaction];
            [thread anyInsertWithTransaction:writeTransaction];
            [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread transaction:writeTransaction];

            NSString *updateGroupInfo = Localized(@"GROUP_CREATED", nil);
            uint64_t now = [NSDate ows_millisecondTimeStamp];

            TSInfoMessage *systemMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                           inThread:thread
                                                                        messageType:TSInfoMessageTypeGroupUpdate
                                                                      customMessage:updateGroupInfo];
            systemMessage.shouldAffectThreadSorting = YES;
            [systemMessage anyInsertWithTransaction:writeTransaction];

            DTGroupBaseInfoEntity *groupBaseInfo = [DTGroupBaseInfoEntity new];
            groupBaseInfo.name = groupName;
            groupBaseInfo.gid = entity.gid;
            groupBaseInfo.avatar = avatar ?: @"";
            [DTGroupUtils addGroupBaseInfo:groupBaseInfo transaction:writeTransaction];
        });

        if (!thread) {
            OWSLogError(@"[group] create plain group: thread is nil after write, abort entering conversation");
            [DTToastHelper dismiss];
            return;
        }

        // Enter the conversation only after the write has committed. Otherwise the VC is created
        // inside the open transaction and its initial load reads a pre-commit snapshot, so the
        // just-inserted group-created info message is missing until the conversation is re-entered.
        DispatchMainThreadSafe(^{
            if (self.createType == DTCreateGroupTypeConvenient) {
                DTInviteToGroupAPI *inviteCodeApi = [DTInviteToGroupAPI new];
                [inviteCodeApi getInviteCodeWithGId:entity.gid success:^(NSString * _Nonnull inviteCode) {
                    [DTToastHelper dismiss];
                    [self.navigationController dismissViewControllerAnimated:YES completion:^{

                    }];
                } failure:^(NSError * _Nonnull error) {
                    [DTToastHelper dismissWithInfo:error.localizedDescription delay:0.2];
                }];
            } else {
                [DTToastHelper dismiss];
                ConversationViewController *conversationVC = [[ConversationViewController alloc] initWithThread:thread
                                                                                                         action:ConversationViewActionNone
                                                                                                 focusMessageId:nil
                                                                                                    botViewItem:nil
                                                                                                       viewMode:ConversationViewMode_Main isFromPersonalCard:false];
                OWSNavigationController *nav = (OWSNavigationController *)self.navigationController;

                [nav pushViewController:conversationVC animated:YES completion:^{
                    [nav removeToViewController:@"HomeViewController"];
                }];
            }
        });

    } failure:^(NSError * _Nonnull error) {
        NSString *logError = error.localizedDescription;
        if(error.code == DTAPIRequestResponseStatusGroupIsFull) {
            logError = Localized(@"ENTER_GROUP_FAILURE_FULL", @"");
        }
        [DTToastHelper dismissWithInfo:logError];
    }];
}

- (void)createEncryptedGroupWithName:(NSString *)groupName
                              avatar:(NSString *)avatar
                             members:(NSArray *)members
{
    DTGroupCryptoManager *cryptoManager = DTGroupCryptoManager.shared;
    NSString *localNumber = self.contactsViewHelper.localNumber;
    NSMutableArray *allMemberUids = [members mutableCopy];
    if (localNumber && ![allMemberUids containsObject:localNumber]) {
        [allMemberUids addObject:localNumber];
    }
    OWSLogInfo(@"[GroupCrypto] createEncryptedGroup start, groupName.len: %lu, avatar.len: %lu, members: %lu", (unsigned long)groupName.length, (unsigned long)avatar.length, (unsigned long)allMemberUids.count);
    DTEncryptedGroupCreationParams *params = [cryptoManager prepareEncryptedGroupCreationObjCWithGroupName:groupName
                                                                                                    avatar:avatar
                                                                                                memberUids:allMemberUids];
    if (!params) {
        OWSLogError(@"[GroupCrypto] Failed to prepare encrypted group creation params");
        [DTToastHelper dismissWithInfo:Localized(@"GROUP_CRYPTO_UPGRADE_FAILED", @"")];
        return;
    }
    OWSLogInfo(@"[GroupCrypto] prepareEncryptedGroupCreation ok, encryptedAvatar.len: %lu", (unsigned long)params.encryptedAvatar.length);

    // 加密群：明文 avatar URL 不上传给服务端，也不写本地 baseInfo.avatar（端到端加密要求）。
    [self.createANewGroupAPI sendRequestWithName:groupName
                                          avatar:@""
                                         numbers:members
                                 groupCryptoMode:params.groupCryptoMode
                                   encryptedName:params.encryptedName
                                 encryptedAvatar:params.encryptedAvatar
                      groupMemberVerifyPublicKey:params.groupMemberVerifyPublicKey
                                  memberBindings:params.memberBindingDicts
                                         success:^(DTCreateANewGroupDataEntity * _Nonnull entity) {
        OWSLogInfo(@"[GroupCrypto] createEncryptedGroup server ok, gid: %@", entity.gid);

        __block TSGroupThread *thread = nil;
        __block NSData *groupId = nil;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {

            TSGroupModel *model = [self makeGroupWithId:entity.gid groupName:groupName transaction:writeTransaction];
            model.groupCryptoMode = params.groupCryptoMode;
            groupId = model.groupId;
            thread = [TSGroupThread getOrCreateThreadWithGroupModel:model transaction:writeTransaction];
            if (thread.groupModel.groupCryptoMode != params.groupCryptoMode) {
                [thread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                    ((TSGroupThread *)t).groupModel.groupCryptoMode = params.groupCryptoMode;
                }];
            }
            [thread anyInsertWithTransaction:writeTransaction];
            [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread transaction:writeTransaction];

            NSString *updateGroupInfo = Localized(@"GROUP_CREATED", nil);
            uint64_t now = [NSDate ows_millisecondTimeStamp];

            TSInfoMessage *systemMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                           inThread:thread
                                                                        messageType:TSInfoMessageTypeGroupUpdate
                                                                      customMessage:updateGroupInfo];
            systemMessage.shouldAffectThreadSorting = YES;
            [systemMessage anyInsertWithTransaction:writeTransaction];

            DTGroupBaseInfoEntity *groupBaseInfo = [DTGroupBaseInfoEntity new];
            groupBaseInfo.name = groupName;
            groupBaseInfo.gid = entity.gid;
            groupBaseInfo.avatar = @"";
            groupBaseInfo.groupCryptoMode = params.groupCryptoMode;
            groupBaseInfo.encryptedName = params.encryptedName;
            groupBaseInfo.encryptedAvatar = params.encryptedAvatar;
            [DTGroupUtils addGroupBaseInfo:groupBaseInfo transaction:writeTransaction];

            [cryptoManager saveRGroupIfNeededWithGid:entity.gid
                                                rGroup:params.rGroup
                                           transaction:writeTransaction];

            [DTGroupKeyMessageHandler downloadEncryptedAvatarIfNeededWithGid:entity.gid
                                                                  transaction:writeTransaction];
        });

        if (!thread) {
            OWSLogError(@"[group] create encrypted group: thread is nil after write, abort entering conversation");
            [DTToastHelper dismiss];
            return;
        }

        // Enter the conversation only after the write has committed (see plain-group path):
        // creating the VC inside the open transaction makes its initial load miss the
        // just-inserted group-created info message until the conversation is re-entered.
        DispatchMainThreadSafe(^{
            [DTGroupKeyMessageHandler.shared sendGroupKeyMessageWithThread:thread
                                                                   groupId:groupId
                                                                    rGroup:params.rGroup];

            if (self.createType == DTCreateGroupTypeConvenient) {
                DTInviteToGroupAPI *inviteCodeApi = [DTInviteToGroupAPI new];
                [inviteCodeApi getInviteCodeWithGId:entity.gid success:^(NSString * _Nonnull inviteCode) {
                    [DTToastHelper dismiss];
                    [self.navigationController dismissViewControllerAnimated:YES completion:^{

                    }];
                } failure:^(NSError * _Nonnull error) {
                    [DTToastHelper dismissWithInfo:error.localizedDescription delay:0.2];
                }];
            } else {
                [DTToastHelper dismiss];
                ConversationViewController *conversationVC = [[ConversationViewController alloc] initWithThread:thread
                                                                                                         action:ConversationViewActionNone
                                                                                                 focusMessageId:nil
                                                                                                    botViewItem:nil
                                                                                                       viewMode:ConversationViewMode_Main isFromPersonalCard:false];
                OWSNavigationController *nav = (OWSNavigationController *)self.navigationController;

                [nav pushViewController:conversationVC animated:YES completion:^{
                    [nav removeToViewController:@"HomeViewController"];
                }];
            }
        });

    } failure:^(NSError * _Nonnull error) {
        NSString *logError = error.localizedDescription;
        if(error.code == DTAPIRequestResponseStatusGroupIsFull) {
            logError = Localized(@"ENTER_GROUP_FAILURE_FULL", @"");
        }
        [DTToastHelper dismissWithInfo:logError];
    }];
}

- (NSString *)localUserName {
    
    if (![TSAccountManager localNumber]) {
        return @"";
    }
    return [Environment.shared.contactsManager contactOrProfileNameForPhoneIdentifier:[TSAccountManager localNumber]];
}

- (TSGroupModel *)makeGroupWithId:(NSString *)gId groupName:(NSString *)groupName transaction:(SDSAnyWriteTransaction *)transaction
{
    NSMutableArray<NSString *> *recipientIds = [self.memberRecipientIds.allObjects mutableCopy];
    [recipientIds addObject:[self.contactsViewHelper localNumber]];
    NSData *groupId = [gId dataUsingEncoding:NSUTF8StringEncoding];
    return [[TSGroupModel alloc] initWithTitle:groupName memberIds:recipientIds image:self.groupAvatar groupId:groupId groupOwner:[self.contactsViewHelper localNumber] groupAdmin:nil transaction:transaction];
}

#pragma mark - Group Avatar

- (void)showChangeAvatarUI
{
    [self.avatarViewHelper showChangeAvatarUI];
}

- (void)setGroupAvatar:(nullable UIImage *)groupAvatar
{
    OWSAssertIsOnMainThread();

    _groupAvatar = groupAvatar;

    self.hasUnsavedChanges = YES;

    [self updateAvatarView];
}

- (void)updateAvatarView
{
    self.avatarView.image = (self.groupAvatar ?: [UIImage imageNamed:@"empty-group-avatar"]);
}

- (void)applyTheme {
    [super applyTheme];
    self.firstSection.backgroundColor = Theme.bgpagePrimaryColor;
    self.tableViewController.tableView.backgroundColor = Theme.bgpagePrimaryColor;
    if (_headerDivider) {
        _headerDivider.backgroundColor = Theme.dividerColor;
    }
    if (_fixedHeaderContainer) {
        _fixedHeaderContainer.backgroundColor = Theme.bgpagePrimaryColor;
    }
}

#pragma mark - Event Handling

- (void)backButtonPressed
{
    [self.groupNameTextField resignFirstResponder];

    if (!self.hasUnsavedChanges) {
        // If user made no changes, return to conversation settings view.
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UIAlertController *controller = [UIAlertController
        alertControllerWithTitle:
            Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_TITLE",
                @"The alert title if user tries to exit the new group view without saving changes.")
                         message:
                             Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_MESSAGE",
                                 @"The alert message if user tries to exit the new group view without saving changes.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [controller
        addAction:[UIAlertAction actionWithTitle:Localized(@"ALERT_DISCARD_BUTTON",
                                                     @"The label for the 'discard' button in alerts and action sheets.")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self.navigationController popViewControllerAnimated:YES];
                                         }]];
    [controller addAction:[OWSAlerts cancelAction]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)groupNameDidChange:(id)sender
{
    self.hasUnsavedChanges = YES;
}

#pragma mark - Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.groupNameTextField resignFirstResponder];
    return NO;
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    [self allResignFirstResponder];
}

- (void)allResignFirstResponder {
    [self.groupNameTextField resignFirstResponder];
    [self.searchBar resignFirstResponder];
}
#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return YES;
}

#pragma mark - AvatarViewHelperDelegate

- (NSString *)avatarActionSheetTitle
{
    return Localized(
        @"NEW_GROUP_ADD_PHOTO_ACTION", @"Action Sheet title prompting the user for a group avatar");
}

- (void)avatarDidChange:(UIImage *)image
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(image);

    self.groupAvatar = image;
}

- (UIViewController *)fromViewController
{
    return self;
}

- (BOOL)hasClearAvatarAction
{
    return NO;
}

#pragma mark - AddToGroupViewControllerDelegate

- (void)recipientIdWasAdded:(NSString *)recipientId
{
    [self addRecipientId:recipientId];
}

- (BOOL)isRecipientGroupMember:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    return [self.memberRecipientIds containsObject:recipientId];
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack
{
    BOOL result = self.hasUnsavedChanges;
    if (self.hasUnsavedChanges) {
        [self backButtonPressed];
    }
    return result;
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    return nil;
}

- (BOOL)prefersNavigationBarHidden {
    return false;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
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
    [self updateTableContents];
}

- (BOOL)canBecomeFirstResponder {
    
    return YES;
}

- (BOOL)becomeFirstResponder {
    
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    
    return [super resignFirstResponder];
}

@end

NS_ASSUME_NONNULL_END

