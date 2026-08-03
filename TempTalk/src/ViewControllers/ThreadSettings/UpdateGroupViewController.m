//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "UpdateGroupViewController.h"
#import "AddToGroupViewController.h"
#import "AvatarViewHelper.h"
#import "Yelling-Swift.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSTableViewController.h>
//
#import <TTMessaging/UIUtil.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIViewController+OWS.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupModel.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import "DTUpdateGroupInfoAPI.h"
#import "DTAddMembersToAGroupAPI.h"
#import "DTSelectedAccountToolView.h"
#import <TTMessaging/OWSSearchBar.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import "SVProgressHUD.h"
#import <TTServiceKit/DTGroupUtils.h>
#import <TTServiceKit/DTGroupAvatarUpdateProcessor.h>
#import <TTServiceKit/DTParamsBaseUtils.h>


NS_ASSUME_NONNULL_BEGIN
extern  CGFloat const kAvatarSize;

// Selected-members row height (mirrors AddToGroupViewController).
static CGFloat const kSelectedRowHeight = 100;
// Divider under the selected-members row.
static CGFloat const kHeaderDividerHeight = 1;
static CGFloat const kHeaderDividerInset = 16;

@interface UpdateGroupViewController () <UIImagePickerControllerDelegate,
    UITextFieldDelegate,
    ContactsViewHelperDelegate,
    AvatarViewHelperDelegate,
    AddToGroupViewControllerDelegate,
    OWSTableViewControllerDelegate,
    UINavigationControllerDelegate,
    OWSNavigationChildController,
    DTSelectedAccountToolViewDelegate,
    UISearchBarDelegate,
    OWSTableViewControllerDelegate>

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) AvatarViewHelper *avatarViewHelper;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
@property (nonatomic, readonly) DTAvatarImageView *avatarView;
@property (nonatomic, readonly) UITextField *groupNameTextField;

@property (nonatomic, nullable) UIImage *groupAvatar;
@property (nonatomic, strong) NSArray <NSString *> *sortedMemberRecipientIds;
@property (nonatomic, strong) NSMutableSet <NSString *> *handledMemberRecipientIds;
// Members currently shown in the list, in row order (maps recipientId -> table row).
@property (nonatomic, strong) NSArray <NSString *> *displayMemberIds;
// Ordered selection driving the selected-members row.
@property (nonatomic, strong) NSMutableArray <NSString *> *selectedMemberOrder;

// Remove-members mode UI (mirrors AddToGroupViewController). The fixed header
// (search bar + selected-members row + divider) does not scroll with the list.
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, strong) OWSSearchBar *memberSearchBar;
@property (nonatomic, strong) DTSelectedAccountToolView *selectedAccountToolView;
@property (nonatomic, strong) UIView *fixedHeaderContainer;
@property (nonatomic, strong) NSLayoutConstraint *fixedHeaderHeightConstraint;
@property (nonatomic, strong) UIView *headerDivider;
@property (nonatomic, assign) BOOL selectedRowVisible;


@property (nonatomic) BOOL hasUnsavedChanges;

@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;
@property (nonatomic, strong) DTAddMembersToAGroupAPI *addMembersToAGroupAPI;
@property (nonatomic, strong) DTGroupAvatarUpdateProcessor *groupAvatarUpdateProcessor;
@property (nonatomic, strong) FullTextSearchFinder *finder;

@end

#pragma mark -

@implementation UpdateGroupViewController

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI{
    if(!_updateGroupInfoAPI){
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}

- (DTAddMembersToAGroupAPI *)addMembersToAGroupAPI{
    if(!_addMembersToAGroupAPI){
        _addMembersToAGroupAPI = [DTAddMembersToAGroupAPI new];
    }
    return _addMembersToAGroupAPI;
}

- (DTGroupAvatarUpdateProcessor *)groupAvatarUpdateProcessor{
    if(!_groupAvatarUpdateProcessor){
        _groupAvatarUpdateProcessor = [[DTGroupAvatarUpdateProcessor alloc] initWithGroupThread:self.thread];
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
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _avatarViewHelper = [AvatarViewHelper new];
    _avatarViewHelper.delegate = self;
    _selectedMemberOrder = [NSMutableArray array];
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];

    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMemberIds);

    self.view.backgroundColor = Theme.bgpageSecondaryColor;
    
    switch (self.mode) {
        case UpdateGroupMode_RemoveGroupMembers:
        {
            self.title = Localized(@"REMOVE_MEMBER_GROUP_ACTION", nil);
        }
            break;
        default:
        {
            self.title = Localized(@"EDIT_GROUP_DEFAULT_TITLE", @"The navbar title for the 'update group' view.");
        }
            break;
    }

    // First section.
    UIView *firstSection = [self firstSectionHeader];
    [self.view addSubview:firstSection];
    [firstSection autoSetDimension:ALDimensionHeight toSize:100.f];
    [firstSection autoPinWidthToSuperview];
    [firstSection autoPinEdgeToSuperviewSafeArea:ALEdgeTop];

    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    self.tableViewController.tableView.allowsMultipleSelection = YES;
    self.tableViewController.tableView.allowsMultipleSelectionDuringEditing = YES;
    if(self.mode == UpdateGroupMode_EditGroupName){

        [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstSection];
    } else if (self.mode == UpdateGroupMode_RemoveGroupMembers) {
        [self setupFixedHeader];
        [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.fixedHeaderContainer];
    } else {
        [_tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
        if (@available(iOS 11.0, *)) {
            _tableViewController.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
        }
    }
//    [self autoPinViewToBottomOfViewControllerOrKeyboard:self.tableViewController.view avoidNotch:false];
    [_tableViewController.view autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    if (self.mode == UpdateGroupMode_RemoveGroupMembers){
        firstSection.hidden = YES;
        self.tableViewController.tableView.rowHeight = 70;
        self.tableViewController.canEditRow = NO;
        // No editing mode: the trailing square checkbox replaces UIKit's left selection circles.
        self.tableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableViewController.view.backgroundColor = Theme.bgpagePrimaryColor;
        self.tableViewController.tableView.backgroundColor = Theme.bgpagePrimaryColor;
        [self setupDoneButton];
        [self sortGroupMemberByLastMessageTimestamp];
    } else {
        self.tableViewController.view.hidden = YES;
    }
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
    _hasUnsavedChanges = hasUnsavedChanges;

    [self updateNavigationBar];
}

- (void)updateNavigationBar {
    if (self.mode == UpdateGroupMode_RemoveGroupMembers) {
        // Remove mode uses a persistent Done button instead of the conditional Update button.
        BOOL hasSelection = self.handledMemberRecipientIds.count > 0;
        self.doneButton.selected = hasSelection;
        self.doneButton.userInteractionEnabled = hasSelection;
        return;
    }
    self.navigationItem.rightBarButtonItem = (self.hasUnsavedChanges
            ? [[UIBarButtonItem alloc] initWithTitle:Localized(@"EDIT_GROUP_UPDATE_BUTTON",
                                                         @"The title for the 'update group' button.")
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(updateGroupPressed)]
            : nil);
}

// Top-right Done button (same as AddToGroup): gray when empty, primary blue with a selection.
- (void)setupDoneButton {
    self.doneButton = [[UIButton alloc] init];
    self.doneButton.titleLabel.font = [UIFont ows_regularFontWithSize:17];
    self.doneButton.userInteractionEnabled = NO;
    self.doneButton.selected = NO;
    [self.doneButton setTitle:Localized(@"BUTTON_DONE", @"") forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.tthirdColor forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.primaryColor forState:UIControlStateSelected];
    [self.doneButton addTarget:self action:@selector(updateGroupPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
}

- (void)showEditView {
    switch (self.mode) {
        case UpdateGroupMode_EditGroupName:
            [self.groupNameTextField becomeFirstResponder];
            break;
        default:
            break;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(groupCryptoKeyDidArrive:)
                                                 name:DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(groupAvatarDidChange:)
                                                 name:TSGroupThreadAvatarChangedNotification
                                               object:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showEditView];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)groupCryptoKeyDidArrive:(NSNotification *)notify {
    OWSAssertIsOnMainThread();
    NSString *gid = notify.userInfo[DTGroupCryptoConstants.groupCryptoKeyGidKey];
    if (!gid.length) { return; }
    if (![gid isEqualToString:self.thread.serverThreadId]) { return; }
    if (self.hasUnsavedChanges) { return; }

    [self refreshHeaderForEncryptedGroup];
}

- (void)groupAvatarDidChange:(NSNotification *)notify {
    OWSAssertIsOnMainThread();
    NSString *threadId = notify.userInfo[TSGroupThread_NotificationKey_UniqueId];
    if (![threadId isEqualToString:self.thread.uniqueId]) { return; }
    if (self.hasUnsavedChanges) { return; }

    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull tx) {
        [self.thread anyReloadWithTransaction:tx];
    }];
    _groupAvatar = self.thread.groupModel.groupImage;
    [self updateAvatarView];
}

- (void)refreshHeaderForEncryptedGroup {
    if (!self.thread.groupModel.isEncryptedGroup) { return; }

    __block NSString *decryptedName = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull tx) {
        [self.thread anyReloadWithTransaction:tx];
        NSString *cachedEncryptedName = [DTGroupBaseInfoEntity anyFetchWithUniqueId:self.thread.serverThreadId transaction:tx].encryptedName;
        decryptedName = [DTGroupCryptoDisplayHelper.shared displayGroupNameWithGid:self.thread.serverThreadId
                                                                    groupCryptoMode:self.thread.groupModel.groupCryptoMode
                                                                      encryptedName:cachedEncryptedName
                                                                       originalName:self.thread.groupModel.groupName
                                                                        transaction:tx];
    }];
    if (decryptedName.length > 0) {
        self.groupNameTextField.text = [decryptedName ows_stripped];
    }
    _groupAvatar = self.thread.groupModel.groupImage;
    [self updateAvatarView];
}

- (UIView *)firstSectionHeader
{
    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);

    UIView *firstSectionHeader = [UIView new];
    firstSectionHeader.userInteractionEnabled = YES;
    [firstSectionHeader
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerWasTapped:)]];
    firstSectionHeader.backgroundColor = Theme.bgpageSecondaryColor;
    UIView *threadInfoView = [UIView new];
    [firstSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

    BOOL isEncryptedGroup = self.thread.groupModel.isEncryptedGroup;
    DTAvatarImageView *avatarView = nil;
    if (isEncryptedGroup) {
        avatarView = [DTAvatarImageView new];
        _avatarView = avatarView;

        [threadInfoView addSubview:avatarView];
        [avatarView autoVCenterInSuperview];
        [avatarView autoPinLeadingToSuperviewMargin];
        [avatarView autoSetDimension:ALDimensionWidth toSize:kAvatarSize];
        [avatarView autoSetDimension:ALDimensionHeight toSize:kAvatarSize];
        _groupAvatar = self.thread.groupModel.groupImage;
        [self updateAvatarView];
    }

    UITextField *groupNameTextField = [UITextField new];
    _groupNameTextField = groupNameTextField;
    NSString *displayName = self.thread.groupModel.groupName;
    if (isEncryptedGroup) {
        __block NSString *decryptedName = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
            NSString *cachedEncryptedName = [DTGroupBaseInfoEntity anyFetchWithUniqueId:self.thread.serverThreadId transaction:transaction].encryptedName;
            decryptedName = [DTGroupCryptoDisplayHelper.shared
                displayGroupNameWithGid:self.thread.serverThreadId
                        groupCryptoMode:self.thread.groupModel.groupCryptoMode
                          encryptedName:cachedEncryptedName
                           originalName:self.thread.groupModel.groupName
                            transaction:transaction];
        }];
        if (decryptedName.length > 0) {
            displayName = decryptedName;
        }
    }
    self.groupNameTextField.text = [displayName ows_stripped];
    groupNameTextField.textColor = Theme.tprimaryColor;
    groupNameTextField.font = [UIFont ows_dynamicTypeTitle2Font];
    groupNameTextField.placeholder
        = Localized(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"Placeholder text for group name field");
    groupNameTextField.delegate = self;
    [groupNameTextField addTarget:self
                           action:@selector(groupNameDidChange:)
                 forControlEvents:UIControlEventEditingChanged];
    [threadInfoView addSubview:groupNameTextField];
    [groupNameTextField autoVCenterInSuperview];
    [groupNameTextField autoPinTrailingToSuperviewMargin];
    if (avatarView) {
        [groupNameTextField autoPinLeadingToTrailingEdgeOfView:avatarView offset:16.f];
        [avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTouched:)]];
        avatarView.userInteractionEnabled = YES;
    } else {
        [groupNameTextField autoPinLeadingToSuperviewMargin];
    }

    return firstSectionHeader;
}

- (void)headerWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        self.mode = UpdateGroupMode_EditGroupName;
        [self.groupNameTextField becomeFirstResponder];
    }
}

- (void)avatarTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.groupNameTextField endEditing:YES];
        [self showChangeAvatarUI];
    }
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSAssertDebug(self.thread);
    
    if (self.mode != UpdateGroupMode_RemoveGroupMembers) {
        return;
    }

    OWSTableContents *contents = [OWSTableContents new];
    ContactsViewHelper *contactsViewHelper = self.contactsViewHelper;

    OWSTableSection *section = [OWSTableSection new];
    // No section title, matching the add-members page.
    section.customFooterHeight = @20;

    NSMutableArray <NSString *> *memberRecipientIds = [self.sortedMemberRecipientIds mutableCopy];
    NSString *localNumber = [TSAccountManager localNumber];
    if (DTParamsUtils.validateString(localNumber)){
        [memberRecipientIds removeObject:self.thread.groupModel.groupOwner];
        [memberRecipientIds removeObject:localNumber];
        if (![localNumber isEqualToString:self.thread.groupModel.groupOwner]) {
            for (NSString *memberId in self.thread.groupModel.groupAdmin) {
                if ([memberRecipientIds containsObject:memberId]) {
                    [memberRecipientIds removeObject:memberId];
                }
            }
        }
    }

    // Filter members by the search text.
    NSString *searchText = [self.memberSearchBar.text ows_stripped];
    if (searchText.length > 0) {
        NSMutableArray <SignalAccount *> *accounts = [NSMutableArray array];
        NSMutableSet <NSString *> *matchedIds = [NSMutableSet set];
        for (NSString *memberId in memberRecipientIds) {
            SignalAccount *account = [contactsViewHelper signalAccountForRecipientId:memberId];
            if (account) {
                [accounts addObject:account];
            } else if ([memberId localizedCaseInsensitiveContainsString:searchText]) {
                // No account info: match the raw id.
                [matchedIds addObject:memberId];
            }
        }
        if (accounts.count > 0) {
            __block NSArray <SignalAccount *> *filteredAccounts = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                filteredAccounts = [ConversationSearcher.shared filterSignalAccounts:accounts
                                                                      withSearchText:searchText
                                                                         transaction:transaction];
            }];
            for (SignalAccount *account in filteredAccounts) {
                if (account.recipientId) {
                    [matchedIds addObject:account.recipientId];
                }
            }
        }
        // Preserve the original member ordering.
        NSMutableArray <NSString *> *filteredMemberIds = [NSMutableArray array];
        for (NSString *memberId in memberRecipientIds) {
            if ([matchedIds containsObject:memberId]) {
                [filteredMemberIds addObject:memberId];
            }
        }
        memberRecipientIds = filteredMemberIds;
    }

    self.displayMemberIds = [memberRecipientIds copy];

    @weakify(self)
    self.hasUnsavedChanges = (self.handledMemberRecipientIds.count > 0);

    for (NSString *recipientId in memberRecipientIds) {
        [section
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            @strongify(self)
                            ContactTableViewCell *cell = [ContactTableViewCell new];
                            if(self.mode == UpdateGroupMode_RemoveGroupMembers){
                                if([self.handledMemberRecipientIds containsObject:recipientId]) {
                                    cell.selectionStatus = ContactCellSelectionStatusSelected;
                                }else{
                                    cell.selectionStatus = ContactCellSelectionStatusUnselected;
                                }
                            }
                            SignalAccount *signalAccount = [contactsViewHelper signalAccountForRecipientId:recipientId];
                            BOOL isPreviousMember = [self.sortedMemberRecipientIds containsObject:recipientId];
                            BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:recipientId];
                            if (isPreviousMember) {
                                if (isBlocked) {
                                    cell.accessoryMessage = Localized(
                                        @"CONTACT_CELL_IS_BLOCKED", @"An indicator that a contact has been blocked.");
                                } else {
                                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                                }
                            } else {
                                cell.accessoryMessage = Localized(@"EDIT_GROUP_NEW_MEMBER_LABEL",
                                    @"An indicator that a user is a new member of the group.");
                            }

                            if (signalAccount) {
                                cell.cellView.type = UserOfSelfIconTypeRealAvater;
                                [cell configureWithThread:self.thread signalAccount:signalAccount  contactsManager:contactsViewHelper.contactsManager];
                            } else {
                                cell.cellView.type = UserOfSelfIconTypeRealAvater;
                                [cell configureWithThread:self.thread recipientId:recipientId  contactsManager:contactsViewHelper.contactsManager];
                            }

                            return cell;
                        }
                        customRowHeight:70
                        actionBlock:^{
                            @strongify(self)
                            SignalAccount *signalAccount = [contactsViewHelper signalAccountForRecipientId:recipientId];
                            BOOL isPreviousMember = [self.sortedMemberRecipientIds containsObject:recipientId];
                            BOOL isBlocked = [contactsViewHelper isRecipientIdBlocked:recipientId];
                            if (isPreviousMember) {
                                if(self.mode == UpdateGroupMode_RemoveGroupMembers){
                                    if (isBlocked) {
                                        if (signalAccount) {
                                            [self showUnblockAlertForSignalAccount:signalAccount];
                                        } else {
                                            [self showUnblockAlertForRecipientId:recipientId];
                                        }
                                    } else {
                                        if(![self.handledMemberRecipientIds containsObject:recipientId]){
                                            [self addRecipientId:recipientId];
                                        }
                                    }
                                }
                            } else {
                                [self removeRecipientId:recipientId];
                            }
                        }
                        deselectActionBlock:^{
                            @strongify(self)
                            if(self.mode == UpdateGroupMode_RemoveGroupMembers){
                                if([self.handledMemberRecipientIds containsObject:recipientId]){
                                    [self removeRecipientId:recipientId];

                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        // Re-assert via the row mapping (cells of non-contact members have no signalAccount).
                                        NSUInteger row = [self.displayMemberIds indexOfObject:recipientId];
                                        if (row == NSNotFound) {
                                            return;
                                        }
                                        UITableViewCell *cell = [self.tableViewController.tableView
                                            cellForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]];
                                        if ([cell isKindOfClass:ContactTableViewCell.class]) {
                                            ((ContactTableViewCell *)cell).selectionStatus = ContactCellSelectionStatusUnselected;
                                        }
                                    });
                                }
                            }
                        }]];
    }
    [contents addSection:section];

    self.tableViewController.contents = contents;
}

- (void)showUnblockAlertForSignalAccount:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);

    __weak UpdateGroupViewController *weakSelf = self;
    [BlockListUIUtils showUnblockSignalAccountActionSheet:signalAccount
                                       fromViewController:self
                                          blockingManager:self.contactsViewHelper.blockingManager
                                          contactsManager:self.contactsViewHelper.contactsManager
                                          completionBlock:^(BOOL isBlocked) {
                                              if (!isBlocked) {
                                                  [weakSelf updateTableContents];
                                              }
                                          }];
}

- (void)showUnblockAlertForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    __weak UpdateGroupViewController *weakSelf = self;
    [BlockListUIUtils showUnblockPhoneNumberActionSheet:recipientId
                                     fromViewController:self
                                        blockingManager:self.contactsViewHelper.blockingManager
                                        contactsManager:self.contactsViewHelper.contactsManager
                                        completionBlock:^(BOOL isBlocked) {
                                            if (!isBlocked) {
                                                [weakSelf updateTableContents];
                                            }
                                        }];
}

- (void)removeRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.handledMemberRecipientIds removeObject:recipientId];
    [self.selectedMemberOrder removeObject:recipientId];
    self.hasUnsavedChanges = (self.handledMemberRecipientIds.count > 0);
    [self refreshSelectedRow];
}

- (void)addRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.handledMemberRecipientIds addObject:recipientId];
    if (![self.selectedMemberOrder containsObject:recipientId]) {
        [self.selectedMemberOrder addObject:recipientId];
    }
    self.hasUnsavedChanges = (self.handledMemberRecipientIds.count > 0);
    [self refreshSelectedRow];
}

#pragma mark - Selected-members header (remove mode, mirrors AddToGroupViewController)

// Non-scrolling header above the table: search bar + selected-members row + divider.
- (void)setupFixedHeader {
    UIView *fixedHeader = [UIView new];
    _fixedHeaderContainer = fixedHeader;
    fixedHeader.backgroundColor = Theme.bgpagePrimaryColor;
    fixedHeader.clipsToBounds = YES;
    [self.view addSubview:fixedHeader];
    [fixedHeader autoPinWidthToSuperview];
    [fixedHeader autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    _fixedHeaderHeightConstraint = [fixedHeader autoSetDimension:ALDimensionHeight
                                                          toSize:kSelectRecipientSearchBarHeight];

    OWSSearchBar *searchBar = [OWSSearchBar new];
    _memberSearchBar = searchBar;
    searchBar.customPlaceholder = Localized(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT",
        @"Placeholder text indicating the user can search for contacts by name or phone number.");
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
}

// Reloads the selected-members row; toggles its visibility and the header height on empty <-> non-empty.
- (void)refreshSelectedRow {
    if (self.mode != UpdateGroupMode_RemoveGroupMembers) {
        return;
    }
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

    NSUInteger row = [self.displayMemberIds indexOfObject:recipientId];
    [self removeRecipientId:recipientId];
    if (row == NSNotFound) {
        return;
    }

    // Deselect the row and re-assert its checkbox via the row mapping (works for
    // non-contact members whose cell has no signalAccount).
    NSIndexPath *rowIndexPath = [NSIndexPath indexPathForRow:(NSInteger)row inSection:0];
    [self.tableViewController.tableView deselectRowAtIndexPath:rowIndexPath animated:NO];
    UITableViewCell *cell = [self.tableViewController.tableView cellForRowAtIndexPath:rowIndexPath];
    if ([cell isKindOfClass:ContactTableViewCell.class]) {
        ((ContactTableViewCell *)cell).selectionStatus = ContactCellSelectionStatusUnselected;
    }
}

#pragma mark - Methods


- (void)updateGroup
{
    OWSAssertDebug(self.conversationSettingsViewDelegate);
    
    __block TSGroupThread *latestGroupThread = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        latestGroupThread = (TSGroupThread *)[TSThread anyFetchWithUniqueId:self.thread.uniqueId transaction:transaction];
    }];

    TSGroupModel *groupModel = latestGroupThread.groupModel;
    
    NSString *newGroupName = [self.groupNameTextField.text ows_stripped];
    newGroupName = newGroupName.length ? newGroupName : Localized(@"NEW_GROUP_DEFAULT_TITLE", @"");
    
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:self.thread.groupModel.groupId];
    
    void (^nextBlock)(TSGroupModel *, NSString *, BOOL) = ^(TSGroupModel *newGroupModel, NSString *updateGroupInfo, BOOL shouldAffectThreadSorting) {
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [self.thread anyUpdateGroupThreadWithTransaction:writeTransaction
                                                       block:^(TSGroupThread * instance) {
                instance.groupModel = newGroupModel;
            }];
            TSInfoMessage *systemMsg = [[TSInfoMessage alloc] initWithTimestamp:now
                                             inThread:self.thread
                                          messageType:TSInfoMessageTypeGroupUpdate
                                                                  customMessage:updateGroupInfo];
            systemMsg.shouldAffectThreadSorting = shouldAffectThreadSorting;
            [systemMsg anyInsertWithTransaction:writeTransaction];

            if (self.mode == UpdateGroupMode_RemoveGroupMembers && self.removeGroupMemberFinished) {
                [writeTransaction addAsyncCompletionOnMain:^{
                    self.removeGroupMemberFinished();
                }];
            }
        });
        DispatchMainThreadSafe(^{
            [self.conversationSettingsViewDelegate popAllConversationSettingsViews];
        });
    };
    
    NSSet *newMembers = [self.handledMemberRecipientIds copy];
    NSSet *oldMembers = [NSSet setWithArray:groupModel.groupMemberIds];
    __block BOOL tmpShouldAffectSorting = NO;
    
    if(self.mode == UpdateGroupMode_EditGroupName){
        if(groupModel.groupName != newGroupName) {
//            NSString *localNumber = self.contactsViewHelper.localNumber;
            if (!groupModel.isSelfGroupOwner &&
               !groupModel.isSelfGroupModerator && !groupModel.anyoneChangeName) {
                [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
                return;
            }

            [SVProgressHUD show];

            // Encrypted group: encrypt group name
            NSDictionary *updateInfo;
            if (groupModel.isEncryptedGroup) {
                DTGroupCryptoManager *cryptoManager = DTGroupCryptoManager.shared;
                __block NSString *encryptedName = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                    encryptedName = [cryptoManager encryptGroupNameWithGid:serverGId plainName:newGroupName transaction:transaction];
                }];
                if (!encryptedName) {
                    [SVProgressHUD dismiss];
                    [DTToastHelper toastWithText:Localized(@"GROUP_CRYPTO_NO_KEY_TOAST", @"") inView:self.view durationTime:3 afterDelay:0.2];
                    // 缺 R_group，input 还原成当前群名
                    self.groupNameTextField.text = [self.thread.groupModel.groupName ows_stripped];
                    return;
                }
                updateInfo = @{@"encryptedName": encryptedName};
            } else {
                updateInfo = @{@"name": newGroupName};
            }

            [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:serverGId
                                                     updateInfo:updateInfo
                                                        success:^(DTAPIMetaEntity * _Nonnull entity) {
                [SVProgressHUD dismiss];
                TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:groupModel];
                newGroupModel.groupName = newGroupName;
                __block NSString *updateGroupInfo = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                    updateGroupInfo = [DTGroupUtils getBaseInfoStringWithOldGroupModel:self.thread.groupModel
                                                                              newModel:newGroupModel
                                                                                source:self.contactsViewHelper.localNumber
                                                             shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                           transaction:transaction];
                }];
                nextBlock(newGroupModel, updateGroupInfo, YES);
            } failure:^(NSError * _Nonnull error) {
                [SVProgressHUD dismiss];
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                // 服务端拒绝，input 还原成当前群名
                self.groupNameTextField.text = [self.thread.groupModel.groupName ows_stripped];
            }];
        }
    } else if (self.mode == UpdateGroupMode_RemoveGroupMembers){
        if(self.handledMemberRecipientIds.count > 0){

            if (!groupModel.isSelfGroupOwner && !groupModel.isSelfGroupModerator && !groupModel.anyoneRemove) {
                [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
                return;
            }

            [SVProgressHUD show];

            NSMutableSet <NSString *> *membersWhoRemoved = [self.handledMemberRecipientIds mutableCopy];
            NSMutableSet <NSString *> *remainingMembers = [NSMutableSet setWithArray:groupModel.groupMemberIds];
            [remainingMembers minusSet:membersWhoRemoved];

            void(^successBlock)(void) = ^{
                TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:groupModel];
                // 新的成员列表 = 剩余的成员（移除后的）
                newGroupModel.groupMemberIds = remainingMembers.allObjects;
                NSMutableArray <NSString *> *groupAdmin = [newGroupModel.groupAdmin mutableCopy];
                [membersWhoRemoved enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                    if ([groupAdmin containsObject:obj]) {
                        [groupAdmin removeObject:obj];
                    }
                    [newGroupModel removeRapidRole:obj];
                }];
                newGroupModel.groupAdmin = [groupAdmin copy];
                
                __block NSString *updateGroupInfo = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                    updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:nil removedMemberIds:membersWhoRemoved.allObjects leftMemberIds:nil shouldAffectThreadSorting:&tmpShouldAffectSorting transaction:transaction];
                }];
                nextBlock(newGroupModel, updateGroupInfo, NO);
                
                [DTGroupUtils postRapidRoleChangeNotificationWithGroupModel:newGroupModel
                                                                 targedMemberIds:membersWhoRemoved.allObjects];
                
                NSString *channelName = [DTCallManager generateGroupChannelNameBy:self.thread];
                [[DTCallManager sharedInstance] putMeetingGroupMemberKickBychannelName:channelName users:membersWhoRemoved.allObjects success:^(id _Nonnull responseObject) {
                    NSNumber *statusNumber = responseObject[@"status"];
                    NSInteger status = [statusNumber integerValue];
                    if (status != 0 || !DTParamsUtils.validateDictionary(responseObject[@"data"])) {
                        OWSLogError(@"[call] kick group member fail, channelName: %@, status: %ld", channelName, status);
                        return;
                    }
                    NSDictionary *data = responseObject[@"data"];
                    NSString *calendar = data[@"calendar"];
                    if (!DTParamsUtils.validateString(calendar)) {
                        return;
                    }
                       
                    OWSLogInfo(@"[call] kick group member success, channelName: %@", channelName);
                    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        [DTCallManager sendGroupMemberChangeMeetingSystemMessageWithThread:self.thread
                                                                          meetingDetailUrl:calendar
                                                                               transaction:transaction];
                    });
                } failure:^(NSError * _Nonnull error) {
                    OWSLogError(@"[call] kick group member fail, channelName: %@, reason: %@", channelName, error.localizedDescription);
                }];
            };
            
            self.addMembersToAGroupAPI.transformToRemove = YES;
            [self.addMembersToAGroupAPI sendRequestWithWithGroupId:serverGId
                                                           numbers:membersWhoRemoved.allObjects
                                                           success:^(DTAPIMetaEntity * _Nonnull entity) {
                [SVProgressHUD dismiss];
                successBlock();
            } failure:^(NSError * _Nonnull error) {
                [SVProgressHUD dismiss];
                if(error.code == DTAPIRequestResponseStatusNoSuchGroupMember){
                    successBlock();
                }else{
                    [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                }
            }];
        }
    }

}

#pragma mark - Group Avatar

- (void)showChangeAvatarUI
{
    [self.groupNameTextField resignFirstResponder];
    [self.avatarViewHelper showChangeAvatarUI];
}

- (void)setGroupAvatar:(nullable UIImage *)groupAvatar
{
    OWSAssertIsOnMainThread();

    _groupAvatar = groupAvatar;

    [self updateAvatarView];
}

- (void)autoUploadGroupAvatar:(UIImage *)newAvatar
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(newAvatar);

    TSGroupModel *groupModel = self.thread.groupModel;
    if (!groupModel.isSelfGroupOwner &&
        !groupModel.isSelfGroupModerator &&
        !groupModel.anyoneChangeName) {
        [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
        return;
    }

    UIImage *oldAvatar = self.groupAvatar;
    self.groupAvatar = newAvatar;

    [SVProgressHUD show];
    NSData *data = UIImagePNGRepresentation(newAvatar);
    id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:data fileExtension:@"png"];

    @weakify(self);
    [self.groupAvatarUpdateProcessor updateWithAttachment:dataSource
                                              contentType:OWSMimeTypeImagePng
                                           sourceFilename:nil
                                                  success:^(DTAPIMetaEntity * _Nonnull entity) {
        @strongify(self);
        if (!self) { return; }
        [SVProgressHUD dismiss];

        TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:self.thread.groupModel];
        newGroupModel.groupImage = newAvatar;
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            // Compute the update string before mutating the thread, so it still
            // diffs the old model against the new one. Reuse writeTransaction for
            // the display-name lookup to avoid opening a nested read transaction.
            BOOL shouldAffectSorting = NO;
            NSString *updateGroupInfo = [DTGroupUtils getBaseInfoStringWithOldGroupModel:self.thread.groupModel
                                                                                newModel:newGroupModel
                                                                                  source:self.contactsViewHelper.localNumber
                                                               shouldAffectThreadSorting:&shouldAffectSorting
                                                                             transaction:writeTransaction];
            [self.thread anyUpdateGroupThreadWithTransaction:writeTransaction
                                                       block:^(TSGroupThread *instance) {
                instance.groupModel = newGroupModel;
            }];
            TSInfoMessage *systemMsg = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                       inThread:self.thread
                                                                    messageType:TSInfoMessageTypeGroupUpdate
                                                                  customMessage:updateGroupInfo];
            systemMsg.shouldAffectThreadSorting = shouldAffectSorting;
            [systemMsg anyInsertWithTransaction:writeTransaction];
        });
        [self.thread fireAvatarChangedNotification];
    } failure:^(NSError * _Nonnull error) {
        @strongify(self);
        if (!self) { return; }
        [SVProgressHUD dismiss];
        self.groupAvatar = oldAvatar;
        if (DTParamsUtils.validateString(error.localizedDescription)) {
            [SVProgressHUD showErrorWithStatus:error.localizedDescription];
        }
    }];
}

- (void)updateAvatarView
{
    self.avatarView.image = (self.groupAvatar ?: [UIImage imageNamed:@"empty-group-avatar"]);
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
        alertControllerWithTitle:Localized(@"EDIT_GROUP_VIEW_UNSAVED_CHANGES_TITLE",
                                     @"The alert title if user tries to exit update group view without saving changes.")
                         message:
                             Localized(@"EDIT_GROUP_VIEW_UNSAVED_CHANGES_MESSAGE",
                                 @"The alert message if user tries to exit update group view without saving changes.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [controller
        addAction:[UIAlertAction actionWithTitle:Localized(@"ALERT_SAVE",
                                                     @"The label for the 'save' button in action sheets.")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                             OWSAssertDebug(self.conversationSettingsViewDelegate);

                                             [self updateGroup];

                                             [self.conversationSettingsViewDelegate popAllConversationSettingsViews];
                                         }]];
    [controller addAction:[UIAlertAction actionWithTitle:Localized(@"ALERT_DONT_SAVE",
                                                             @"The label for the 'don't save' button in action sheets.")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)updateGroupPressed
{
    OWSAssertDebug(self.conversationSettingsViewDelegate);

    [self updateGroup];
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

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateTableContents];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self updateTableContents];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self updateTableContents];
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    [self.groupNameTextField resignFirstResponder];
    [self.memberSearchBar resignFirstResponder];
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

    [self autoUploadGroupAvatar:image];
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

- (BOOL)isRecipientGroupMember:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    return [self.sortedMemberRecipientIds containsObject:recipientId];
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack
{
    // Remove mode: back simply discards the selection (same as the add-members page).
    if (self.mode == UpdateGroupMode_RemoveGroupMembers) {
        return NO;
    }
    BOOL result = self.hasUnsavedChanges;
    if (result) {
        [self backButtonPressed];
    }
    return result;
}

- (void)applyTheme {
    [super applyTheme];
    if (_doneButton) {
        [_doneButton setTitleColor:Theme.tthirdColor forState:UIControlStateNormal];
        [_doneButton setTitleColor:Theme.primaryColor forState:UIControlStateSelected];
    }
    if (_headerDivider) {
        _headerDivider.backgroundColor = Theme.dividerColor;
    }
    if (_fixedHeaderContainer) {
        _fixedHeaderContainer.backgroundColor = Theme.bgpagePrimaryColor;
    }
    if (self.mode == UpdateGroupMode_RemoveGroupMembers) {
        self.tableViewController.view.backgroundColor = Theme.bgpagePrimaryColor;
        self.tableViewController.tableView.backgroundColor = Theme.bgpagePrimaryColor;
    }
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    // Remove mode uses the default navbar color, same as the add-members page.
    if (self.mode == UpdateGroupMode_RemoveGroupMembers) {
        return nil;
    }
    return Theme.bgpageSecondaryColor;
}

- (BOOL)prefersNavigationBarHidden {
    return false;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
}


- (FullTextSearchFinder *)finder {
    if (!_finder) {
        _finder = [FullTextSearchFinder new];
    }
    
    return _finder;
}

- (void)sortGroupMemberByLastMessageTimestamp {
    
#if DEBUG
    NSTimeInterval start = CACurrentMediaTime();
#endif
    
    NSArray <NSString *> *groupMemberIds = self.thread.groupModel.groupMemberIds;
    BOOL showHUD = groupMemberIds.count > 100;
    if (showHUD) {
        [SVProgressHUD show];
    }
    
    
    
    NSMutableArray <NSString *> *tmpNoMessageMemberIds = @[].mutableCopy;
    NSMutableArray <TSIncomingMessage *> *messages = @[].mutableCopy;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        [groupMemberIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            __block TSIncomingMessage *targetMessage = nil;
            [self.finder enumerateMessagesWith:obj
                                      threadId:self.thread.uniqueId
                                            at:transaction
                                         block:^(id _Nullable message, NSString * _Nonnull snippet) {
                if (![message isKindOfClass:TSIncomingMessage.class]) {
                    return;
                }
                targetMessage = (TSIncomingMessage *)message;;
//                TSIncomingMessage *incomingMessage = (TSIncomingMessage *)message;
//                NSDictionary *memberJoinDateMap = self.thread.groupModel.memberJoinDateMap;
//                if (DTParamsUtils.validateDictionary(memberJoinDateMap)) {
//                    uint64_t timestamp = incomingMessage.timestampForSorting;
//                    uint64_t joinGroupTime = [memberJoinDateMap[obj] unsignedLongLongValue];
//                    if (timestamp > joinGroupTime) {
//                        targetMessage = incomingMessage;
//                    }
//                } else {
//                    targetMessage = incomingMessage;
//                }
            }];
            if (!targetMessage) {
                [tmpNoMessageMemberIds addObject:obj];
            } else {
                [messages addObject:targetMessage];
            }
        }];
    } completion:^{
        if (showHUD) {
            [SVProgressHUD dismissWithDelay:0.2];
        }
#if DEBUG
        NSTimeInterval end = CACurrentMediaTime() - start;
        OWSLogDebug(@">>>>>%@\n-----%.2f-----\n%@", messages, end, tmpNoMessageMemberIds);
#endif
        NSArray <NSString *> *noMessageMemberIds = [tmpNoMessageMemberIds sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull obj1, NSString * _Nonnull obj2) {
            SignalAccount *signalAccount1 = [self.contactsViewHelper.contactsManager signalAccountForRecipientId:obj1];
            SignalAccount *signalAccount2 = [self.contactsViewHelper.contactsManager signalAccountForRecipientId:obj2];
            return [self.contactsViewHelper.contactsManager compareSignalAccount:signalAccount1 withSignalAccount:signalAccount2];
        }];
        
        NSArray <TSIncomingMessage *> *sortedMessages = [messages sortedArrayUsingComparator:^NSComparisonResult(TSIncomingMessage * _Nonnull obj1, TSIncomingMessage * _Nonnull obj2) {
            return [obj1 compareForSorting:obj2];
        }];
        NSMutableArray <NSString *> *messageMemberIds = @[].mutableCopy;
        [sortedMessages enumerateObjectsUsingBlock:^(TSIncomingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [messageMemberIds addObject:obj.authorId];
        }];
        
        NSMutableArray <NSString *> *tmpSortedMemberRecipientIds = @[].mutableCopy;
        [tmpSortedMemberRecipientIds addObjectsFromArray:noMessageMemberIds];
        [tmpSortedMemberRecipientIds addObjectsFromArray:messageMemberIds];
        self.sortedMemberRecipientIds = tmpSortedMemberRecipientIds.copy;
        self.handledMemberRecipientIds = [NSMutableSet set];
        [self.selectedMemberOrder removeAllObjects];

        [self updateTableContents];
    }];
}

#pragma mark - OWSTableViewControllerDelegate

// Re-assert the checkbox after UITableView's setSelected: flips it on display.
- (void)originalTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.mode != UpdateGroupMode_RemoveGroupMembers) {
        return;
    }
    if (![cell isKindOfClass:ContactTableViewCell.class]) {
        return;
    }
    ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
    // signalAccount is nil for non-contact members; fall back to the row mapping.
    NSString *recipientId = contactCell.signalAccount.recipientId
        ?: (indexPath.row < (NSInteger)self.displayMemberIds.count ? self.displayMemberIds[(NSUInteger)indexPath.row] : nil);
    if (!recipientId.length) {
        return;
    }
    if ([self.handledMemberRecipientIds containsObject:recipientId]) {
        contactCell.selectionStatus = ContactCellSelectionStatusSelected;
        // Re-establish the table selection state lost on reload, so a tap deselects.
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    } else {
        contactCell.selectionStatus = ContactCellSelectionStatusUnselected;
    }
}

- (void)originalTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:ContactTableViewCell.class]) {
        ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
        contactCell.selectionStatus = ContactCellSelectionStatusSelected;
    }
}

@end

NS_ASSUME_NONNULL_END
