//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AddToGroupViewController.h"
#import "BlockListUIUtils.h"
#import "ContactsViewHelper.h"
#import "Yelling-Swift.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/DTToastHelper.h>
#import "DTAddMembersToAGroupAPI.h"
#import "DTAddToGroupItem.h"
#import "DTSelectedAccountToolView.h"
#import <TTServiceKit/TSContactThread.h>

// Selected-members row height.
static CGFloat const kSelectedRowHeight = 100;
// Divider under the selected-members row.
static CGFloat const kHeaderDividerHeight = 1;
static CGFloat const kHeaderDividerInset = 16;

NS_ASSUME_NONNULL_BEGIN
NSString *const kDTAddToGroupItemIdentifier = @"kDTAddToGroupItemIdentifier";
@interface AddToGroupViewController () <SelectRecipientViewControllerDelegate, DTSelectedAccountToolViewDelegate>

@property (nonatomic,assign) BOOL viewDidAppear;//view是否已经渲染完成
@property (nonatomic, nullable) NSSet<NSString *> *previousMemberRecipientIds;
@property (nonatomic) NSMutableSet<NSString *> *memberRecipientIds;
@property (nonatomic) NSMutableSet<NSString *> *virtualUserIdOrEmails;
@property(nonatomic,strong) NSMutableArray <NSString *> *memberRecipientIdsArr;
@property(nonatomic,strong) NSMutableDictionary *indexPathMap;
@property (nonatomic, strong) DTAddMembersToAGroupAPI *addMembersToAGroupAPI;
@property(nonatomic,strong) UIButton *doneButton;
// Selected-members row + divider, installed in the base class's non-scrolling fixedHeaderContainer.
@property(nonatomic,strong) DTSelectedAccountToolView *selectedAccountToolView;
@property(nonatomic,strong) UIView *headerDivider;
@property(nonatomic,assign) BOOL selectedRowVisible;

@end

#pragma mark -

@implementation AddToGroupViewController

- (void)loadView
{
    self.delegate = self;

    [super loadView];
    self.title = Localized(@"ADD_GROUP_MEMBER_VIEW_TITLE", @"Title for the 'add group member' view.");
    _viewDidAppear = false;
    
}

- (void)applyTheme {
    [super applyTheme];
    
    self.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableViewController.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableViewController.tableView.backgroundColor = Theme.bgpageSecondaryColor;
    
    [self.doneButton setTitleColor:Theme.tthirdColor forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.primaryColor forState:UIControlStateSelected];
    if (self.presentingViewController) {
        self.navigationItem.leftBarButtonItem.tintColor = Theme.tprimaryColor;
    }
    if (_headerDivider) {
        _headerDivider.backgroundColor = Theme.dividerColor;
    }

    if (self.view.window.windowLevel == UIWindowLevel_CallView()) {
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.tprimaryColor}];
        self.navigationController.navigationBar.tintColor = Theme.tprimaryColor;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableViewController.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableViewController.tableView.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableViewController.tableView.rowHeight = 70;

    self.doneButton = [[UIButton alloc] init];
    self.doneButton.titleLabel.font = [UIFont ows_regularFontWithSize:17];
    self.doneButton.userInteractionEnabled = NO;
    self.doneButton.selected = NO;
    [self.doneButton setTitle:Localized(@"BUTTON_DONE", @"") forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.tthirdColor forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.primaryColor forState:UIControlStateSelected];
    [self.doneButton addTarget:self action:@selector(doneAction) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
    self.tableViewController.tableView.allowsMultipleSelection = true;
    self.tableViewController.tableView.allowsMultipleSelectionDuringEditing = true;
    self.tableViewController.canEditRow = NO;
    self.tableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.memberRecipientIds = [NSMutableSet new];
    self.virtualUserIdOrEmails = [NSMutableSet new];
    self.memberRecipientIdsArr = [NSMutableArray array];
    if (self.thread) {
        [self.memberRecipientIds addObjectsFromArray:self.thread.groupModel.groupMemberIds];
        self.previousMemberRecipientIds = [NSSet setWithArray:self.thread.groupModel.groupMemberIds];
    }
    
    if (self.presentingViewController) {
        UIImage *closeImage = [[UIImage systemImageNamed:@"xmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:closeImage
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(cancelItemAction)];
        closeItem.accessibilityLabel = Localized(@"TXT_CANCEL_TITLE", @"");
        closeItem.tintColor = Theme.tprimaryColor;
        self.navigationItem.leftBarButtonItem = closeItem;
    }

    [self setupFixedHeaderRows];

    [self applyTheme];
}

// Installs the selected-members row + divider into the fixed header, below the search bar.
- (void)setupFixedHeaderRows {
    UIView *header = self.fixedHeaderContainer;

    [header addSubview:self.selectedAccountToolView];
    [self.selectedAccountToolView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:kSelectRecipientSearchBarHeight];
    [self.selectedAccountToolView autoPinWidthToSuperviewWithMargin:kHeaderDividerInset];
    [self.selectedAccountToolView autoSetDimension:ALDimensionHeight toSize:kSelectedRowHeight];

    [header addSubview:self.headerDivider];
    [self.headerDivider autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.selectedAccountToolView];
    [self.headerDivider autoPinWidthToSuperviewWithMargin:kHeaderDividerInset];
    [self.headerDivider autoSetDimension:ALDimensionHeight toSize:kHeaderDividerHeight];

    self.selectedAccountToolView.hidden = YES;
    self.headerDivider.hidden = YES;
    self.selectedRowVisible = NO;
}

- (void)cancelItemAction {
    
    if (!self.navigationController || ![self.navigationController popViewControllerAnimated:YES]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewDidAppear = true;
}

// Reloads the selected-members row; toggles its visibility and the header height on empty <-> non-empty.
- (void)refreshSelectedRow {
    [self.selectedAccountToolView reloadWithData:self.memberRecipientIdsArr];
    BOOL hasSelection = self.memberRecipientIdsArr.count > 0;
    if (hasSelection == self.selectedRowVisible) {
        return;
    }
    self.selectedRowVisible = hasSelection;
    self.selectedAccountToolView.hidden = !hasSelection;
    self.headerDivider.hidden = !hasSelection;
    CGFloat headerHeight = hasSelection
        ? kSelectRecipientSearchBarHeight + kSelectedRowHeight + kHeaderDividerHeight
        : kSelectRecipientSearchBarHeight;
    [self setFixedHeaderHeight:headerHeight];
}

#pragma mark - action

- (void)doneAction {
    
    if (self.mode == AddToGroupMode_DataBack) {
        
        if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAdded:)]) {
            [self.addToGroupDelegate recipientIdsWasAdded:self.memberRecipientIds.copy];
        }
        if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAdded:virtualUserIdOrEmails:)]) {
            [self.addToGroupDelegate recipientIdsWasAdded:self.memberRecipientIds.copy
                                    virtualUserIdOrEmails:self.virtualUserIdOrEmails];
        }
        if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAddedWithArr:)]) {
            [self.addToGroupDelegate recipientIdsWasAddedWithArr:self.memberRecipientIdsArr.copy];
        }
        if (![self.navigationController popViewControllerAnimated:YES]) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } else {
        
        [self updateGroupMember];
    }
}

#pragma mark - 

- (NSString *)phoneNumberSectionTitle
{
    return Localized(@"ADD_GROUP_MEMBER_VIEW_PHONE_NUMBER_TITLE",
        @"Title for the 'add by phone number' section of the 'add group member' view.");
}

- (NSString *)phoneNumberButtonText
{
    return Localized(@"ADD_GROUP_MEMBER_VIEW_BUTTON",
        @"A label for the 'add by phone number' button in the 'add group member' view");
}

- (NSString *)contactsSectionTitle
{
    // Empty title hides the contacts section header.
    return @"";
}

- (void)phoneNumberWasSelected:(NSString *)phoneNumber
{
    OWSAssertDebug(phoneNumber.length > 0);

    __weak AddToGroupViewController *weakSelf = self;

    ContactsViewHelper *helper = self.contactsViewHelper;
    if ([helper isRecipientIdBlocked:phoneNumber]) {
        [BlockListUIUtils showUnblockPhoneNumberActionSheet:phoneNumber
                                         fromViewController:self
                                            blockingManager:helper.blockingManager
                                            contactsManager:helper.contactsManager
                                            completionBlock:^(BOOL isBlocked) {
                                                if (!isBlocked) {
                                                    [weakSelf addToGroup:phoneNumber withIndexPath:nil];
                                                }
                                            }];
        return;
    }

    BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
        presentAlertIfNecessaryWithRecipientId:phoneNumber
                              confirmationText:
                                  Localized(@"SAFETY_NUMBER_CHANGED_CONFIRM_ADD_TO_GROUP_ACTION",
                                      @"button title to confirm adding a recipient to a group when their safety "
                                      @"number has recently changed")
                               contactsManager:helper.contactsManager
                                    completion:^(BOOL didConfirmIdentity) {
                                        if (didConfirmIdentity) {
                                            [weakSelf addToGroup:phoneNumber withIndexPath:nil];
                                        }
                                    }];
    if (didShowSNAlert) {
        return;
    }

    [self addToGroup:phoneNumber withIndexPath:nil];
}

- (BOOL)canSignalAccountBeSelected:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);
    
    BOOL result = YES;
    
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(isRecipientGroupMember:)]) {
            result = ![self.addToGroupDelegate isRecipientGroupMember:signalAccount.recipientId];
    }
    
    return result;
}

- (BOOL)canMeetingMemberBeSelected:(SignalAccount *)signalAccount {
    BOOL result = YES;
    
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(canMeetingMemberBeSelected:)]) {
        
        result = [self.addToGroupDelegate canMeetingMemberBeSelected:signalAccount.recipientId];
    }
    
    return result;
}

- (void)signalAccountWasUnSelected:(SignalAccount *)signalAccount {
    if (!signalAccount) {
        return;
    }
    if (!signalAccount.recipientId) {
        return;
    }

    [self.memberRecipientIds removeObject:signalAccount.recipientId];
    [self.memberRecipientIdsArr removeObject:signalAccount.recipientId];
    [self.indexPathMap removeObjectForKey:signalAccount.recipientId];
    [self dealDoneButtonState];
    [self refreshSelectedRow];

    // 更新cell的selectionStatus
    NSIndexPath *indexPath = [self.indexPathMap objectForKey:signalAccount.recipientId];
    if (indexPath) {
        UITableViewCell *cell = [self.tableViewController.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:ContactTableViewCell.class]) {
            ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
            contactCell.selectionStatus = ContactCellSelectionStatusUnselected;
        }
    } else {
        // 如果没有indexPath，遍历可见cells查找并更新
        for (ContactTableViewCell *cell in self.tableViewController.tableView.visibleCells) {
            if ([cell isKindOfClass:ContactTableViewCell.class]) {
                if ([cell.signalAccount.recipientId isEqualToString:signalAccount.recipientId]) {
                    cell.selectionStatus = ContactCellSelectionStatusUnselected;
                    break;
                }
            }
        }
    }
}

- (void)signalAccountWasSelected:(SignalAccount *)signalAccount withIndexPath:(nonnull NSIndexPath *)indexPath
{
    OWSAssertDebug(signalAccount);

    ContactsViewHelper *helper = self.contactsViewHelper;
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(isRecipientGroupMember:)] &&
        [self.addToGroupDelegate isRecipientGroupMember:signalAccount.recipientId]) {
        OWSLogDebug(@"Cannot add user to group member if already a member.");
        return;
    }
    
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(checkShouldToastCannnotBeSelected:)] &&
        ![self.addToGroupDelegate checkShouldToastCannnotBeSelected:signalAccount.recipientId]) {
        OWSLogDebug(@"User cannot be invited to meeting");
        return;
    }

    @weakify(self);
    if ([helper isRecipientIdBlocked:signalAccount.recipientId]) {
        [BlockListUIUtils showUnblockSignalAccountActionSheet:signalAccount
                                           fromViewController:self
                                              blockingManager:helper.blockingManager
                                              contactsManager:helper.contactsManager
                                              completionBlock:^(BOOL isBlocked) {
                                                  @strongify(self);
                                                  if (!isBlocked) {
                                                      [self addToGroup:signalAccount.recipientId withIndexPath:indexPath];
                                                  }
                                              }];
        return;
    }

    BOOL didShowSNAlert = [SafetyNumberConfirmationAlert
        presentAlertIfNecessaryWithRecipientId:signalAccount.recipientId
                              confirmationText:
                                  Localized(@"SAFETY_NUMBER_CHANGED_CONFIRM_ADD_TO_GROUP_ACTION",
                                      @"button title to confirm adding a recipient to a group when their safety "
                                      @"number has recently changed")
                               contactsManager:helper.contactsManager
                                    completion:^(BOOL didConfirmIdentity) {
                                        @strongify(self);
                                        if (didConfirmIdentity) {
                                            [self addToGroup:signalAccount.recipientId withIndexPath:indexPath];
                                        }
                                    }];
    if (didShowSNAlert) {
        return;
    }

    [self addToGroup:signalAccount.recipientId withIndexPath:indexPath];
}

- (void)userIdOrEmailWasSelected:(NSString *)userIdOrEmail {
   
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(isRecipientGroupMember:)] &&
        [self.addToGroupDelegate isRecipientGroupMember:userIdOrEmail]) {
        OWSLogDebug(@"Cannot add user to group member if already a member.");
        return;
    }
    [self.virtualUserIdOrEmails addObject:userIdOrEmail];
    [self addToGroup:userIdOrEmail withIndexPath:nil];
}

- (void)userIdOrEmailWasUnselected:(NSString *)userIdOrEmail {
 
    if (!userIdOrEmail) return;
    
    [self.virtualUserIdOrEmails removeObject:userIdOrEmail];
    [self.memberRecipientIds removeObject:userIdOrEmail];
    [self.memberRecipientIdsArr removeObject:userIdOrEmail];

    [self dealDoneButtonState];
    [self refreshSelectedRow];
}

- (BOOL)canUserIdOrEmailBeSelected:(NSString *)userIdOrEmail {
    OWSAssertDebug(userIdOrEmail);
    
    BOOL result = YES;
    
    if (self.addToGroupDelegate &&
        [self.addToGroupDelegate respondsToSelector:@selector(isRecipientGroupMember:)]) {
            result = ![self.addToGroupDelegate isRecipientGroupMember:userIdOrEmail];
    }
    
    return result;

}


- (void)dealDoneButtonState {
    
    if (self.thread) {
        NSSet *newMembers = self.memberRecipientIds;
        TSGroupModel *groupModel = (TSGroupModel *)self.thread.groupModel;
        NSSet *oldMembers = [NSSet setWithArray:groupModel.groupMemberIds];
        NSMutableSet *membersWhoJoined = [NSMutableSet setWithSet:newMembers];
        if (!membersWhoJoined) {
            return;
        }
        [membersWhoJoined minusSet:oldMembers];//只保留新增的元素
        if (membersWhoJoined.count == 0) {
            self.doneButton.selected = false;
            self.doneButton.userInteractionEnabled = false;
        }
    } else {
        if (self.memberRecipientIds.count == 0) {
            self.doneButton.selected = false;
            self.doneButton.userInteractionEnabled = false;
        }
    }
}

- (void)addToGroup:(NSString *)recipientId withIndexPath:(nullable NSIndexPath *)indexPath{
    OWSAssertDebug(recipientId.length > 0);
    [self.memberRecipientIds addObject:recipientId];
    [self.memberRecipientIdsArr addObject: recipientId];
    if (indexPath) {
        [self.indexPathMap setObject:indexPath forKey:recipientId];
    }
    self.doneButton.selected = true;
    self.doneButton.userInteractionEnabled = true;
    [self refreshSelectedRow];
    //如果业务方实现了 recipientIdWasAdded 这个代理，表明业务方想要自己对数据进行处理，本VC就不再做处理
    if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdWasAdded:)]) {
        [self.addToGroupDelegate recipientIdWasAdded:recipientId];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
}

//更新组成员
- (void)updateGroupMember {
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:self.thread.groupModel.groupId];
    NSSet *newMembers = self.memberRecipientIds;
    TSGroupModel *groupModel = (TSGroupModel *)self.thread.groupModel;
    NSSet *oldMembers = [NSSet setWithArray:groupModel.groupMemberIds];
    
    void (^nextBlock)(NSString *, NSArray <NSString *> *) = ^(NSString *updateGroupInfo, NSArray <NSString *> *newJoinMember) {
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self.thread anyUpdateGroupThreadWithTransaction:transaction
                                                       block:^(TSGroupThread * instance) {
                instance.groupModel.groupMemberIds = self.memberRecipientIds.allObjects;
            }];
                        
            uint64_t now = [NSDate ows_millisecondTimeStamp];
            [[[TSInfoMessage alloc] initWithTimestamp:now inThread:self.thread messageType:TSInfoMessageGroupAddMember customMessage:updateGroupInfo] anyInsertWithTransaction:transaction];
            
            [transaction addAsyncCompletionOnMain:^{
                if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAdded:)]) {
                    [self.addToGroupDelegate recipientIdsWasAdded:newMembers];
                }
            }];
        });

        NSString *channelName = [DTCallManager generateGroupChannelNameBy:self.thread];
        [[DTCallManager sharedInstance] putMeetingGroupMemberInviteBychannelName:channelName success:^(id _Nonnull responseObject) {
            NSNumber *statusNumber = responseObject[@"status"];
            NSInteger status = [statusNumber integerValue];
            if (status != 0 || !DTParamsUtils.validateDictionary(responseObject[@"data"])) {
                OWSLogError(@"[call] invite group member fail, channelName: %@, status: %ld", channelName, status);
                return;
            }
            NSDictionary *data = responseObject[@"data"];
            NSString *calendar = data[@"calendar"];
            if (!DTParamsUtils.validateString(calendar)) {
                return;
            }
            OWSLogInfo(@"[call] invite group member success, channelName: %@", channelName);
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [DTCallManager sendGroupMemberChangeMeetingSystemMessageWithThread:self.thread
                                                                  meetingDetailUrl:calendar
                                                                       transaction:transaction];
            });
        } failure:^(NSError * _Nonnull error) {
            OWSLogError(@"[call] invite group member fail, channelName: %@, reason: %@", channelName, error.localizedDescription);
        }];

    };
    
    if(newMembers.count > oldMembers.count){
        [DTToastHelper show];
        NSMutableSet *membersWhoJoined = [NSMutableSet setWithSet:newMembers];
        [membersWhoJoined minusSet:oldMembers];//只保留新增的元素
        
        self.addMembersToAGroupAPI.transformToRemove = NO;

        // Encrypted group: prepare member bindings
        NSArray *memberBindings = nil;
        if (groupModel.isEncryptedGroup) {
            DTGroupCryptoManager *cryptoManager = DTGroupCryptoManager.shared;
            __block NSArray *bindings = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                bindings = [cryptoManager prepareMemberBindingDictsForGid:serverGId
                                                           newMemberUids:membersWhoJoined.allObjects
                                                             transaction:transaction];
            }];

            if (!bindings) {
                OWSLogError(@"[GroupCrypto] add-member ABORT: bindings nil (no/underivable key) gid: %@", serverGId);
                [DTToastHelper hide];
                [DTToastHelper toastWithText:Localized(@"GROUP_CRYPTO_NO_KEY_TOAST", @"") inView:self.view durationTime:3 afterDelay:0.2];
                return;
            }
            memberBindings = bindings;
        }

        [self.addMembersToAGroupAPI sendRequestWithWithGroupId:serverGId
                                                       numbers:membersWhoJoined.allObjects
                                                memberBindings:memberBindings
                                                       success:^(DTAPIMetaEntity * _Nonnull entity) {
            [DTToastHelper hide];
            OWSLogInfo(@"[GroupCrypto] add-member SUCCESS gid: %@, joined: %lu", serverGId, (unsigned long)membersWhoJoined.count);
            __block NSString *updateGroupInfo = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                BOOL tmpShouldAffectSorting = NO;
                updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:membersWhoJoined.allObjects removedMemberIds:nil leftMemberIds:nil shouldAffectThreadSorting:&tmpShouldAffectSorting transaction:transaction];
            }];
            nextBlock(updateGroupInfo, membersWhoJoined.allObjects);

            // Distribute R_group after server confirmed new members joined
            if (groupModel.isEncryptedGroup) {
                __block NSData *rGroupData = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                    rGroupData = [DTGroupCryptoManager.shared getRGroupDataWithGid:serverGId transaction:transaction];
                }];
                if (rGroupData) {
                    [DTGroupKeyMessageHandler.shared sendGroupKeyMessageWithThread:self.thread
                                                                           groupId:groupModel.groupId
                                                                            rGroup:rGroupData];
                }
            }

            DispatchMainThreadSafe(^{
                [self.conversationSettingsViewDelegate popAllConversationSettingsViews];
            });
//            [self.navigationController popViewControllerAnimated:true];
        } failure:^(NSError * _Nonnull error) {
            NSString *logError = error.localizedDescription;;
            if(error.code == DTAPIRequestResponseStatusGroupIsFull) {
                logError = Localized(@"ENTER_GROUP_FAILURE_FULL", @"");
            }
            OWSLogError(@"[GroupCrypto] add-member FAILED gid: %@, code: %ld, err: %@", serverGId, (long)error.code, error.localizedDescription);
            [DTToastHelper hide];
            [DTToastHelper toastWithText:logError inView:self.view durationTime:3 afterDelay:0.2];
        }];
        
    }
}

- (BOOL)shouldHideLocalNumber
{
    if ([self.addToGroupDelegate respondsToSelector:@selector(shouldHideLocalNumber)]) {
        return [self.addToGroupDelegate shouldHideLocalNumber];
    }
    
    return YES;
}

- (BOOL)shouldHideContacts
{
    return self.hideContacts;
}

- (BOOL)shouldValidatePhoneNumbers
{
    return YES;
}

- (nullable NSString *)accessoryMessageForSignalAccount:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);

    // Existing members are indicated by the gray DisabledSelected checkbox, not a text label.
    return nil;
}

- (BOOL)customUserConditions:(NSString *)userIdOrEmail {
    if (!self.addToGroupDelegate || ![self.addToGroupDelegate respondsToSelector:@selector(customUserConditions:)]) {
        return NO;
    }
    
    return [self.addToGroupDelegate customUserConditions:userIdOrEmail];
}

#pragma mark DTSelectedAccountToolViewDelegate
// Tapping a selected avatar's ✕ removes that member from the selection.
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    if (!indexPath || indexPath.row >= (NSInteger)self.memberRecipientIdsArr.count) {
        return;
    }
    NSString *receptid = [self.memberRecipientIdsArr objectAtIndex:(NSUInteger)indexPath.row];
    if (!receptid) {
        return;
    }

    // Deselect the list row so the table selection state stays in sync.
    NSIndexPath *unSelectedIndexPath = [self.indexPathMap objectForKey:receptid];
    if (unSelectedIndexPath) {
        [self.tableViewController.tableView deselectRowAtIndexPath:unSelectedIndexPath animated:NO];
    }

    SignalAccount *account = [self.contactsViewHelper signalAccountForRecipientId:receptid];
    if (account) {
        [self signalAccountWasUnSelected:account];
    } else {
        // Virtual user / email entry.
        [self userIdOrEmailWasUnselected:receptid];
        [self refreshSelectedRow];
    }
}

- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView okBtnClick:(UIButton *)sender {
    if (self.mode == AddToGroupMode_DataBack) {
        
        if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAdded:)]) {
            [self.addToGroupDelegate recipientIdsWasAdded:self.memberRecipientIds.copy];
        }
        if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdsWasAddedWithArr:)]) {
            [self.addToGroupDelegate recipientIdsWasAddedWithArr:self.memberRecipientIdsArr.copy];
        }
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (DTAddMembersToAGroupAPI *)addMembersToAGroupAPI{
    if(!_addMembersToAGroupAPI){
        _addMembersToAGroupAPI = [DTAddMembersToAGroupAPI new];
    }
    return _addMembersToAGroupAPI;
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

- (NSMutableDictionary *)indexPathMap {
    if (!_indexPathMap) {
        _indexPathMap = [NSMutableDictionary dictionary];
    }
    return _indexPathMap;
}

#pragma mark - OWSTableViewControllerDelegate

- (void)originalTableView:(UITableView *)tableView
          willDisplayCell:(UITableViewCell *)cell
        forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (![cell isKindOfClass:ContactTableViewCell.class]) {
        return;
    }

    ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;

    SignalAccount *signalAccount = contactCell.signalAccount;
    NSString *virtualUserId = contactCell.cellView.virtualUserId;
    NSString *recipientId = signalAccount.recipientId ?: virtualUserId;

    // Existing members are not selectable: gray DisabledSelected checkbox, no table selection.
    BOOL isExistingMember = DTParamsUtils.validateString(recipientId) && [self.previousMemberRecipientIds containsObject:recipientId];
    if (isExistingMember) {
        contactCell.selectionStatus = ContactCellSelectionStatusDisabledSelected;
        return;
    }

    contactCell.selectionStatus = ContactCellSelectionStatusUnselected;

    BOOL isSelected = NO;
    if (signalAccount.recipientId) {
        isSelected = [self.memberRecipientIds containsObject:signalAccount.recipientId];
    } else if (DTParamsUtils.validateString(virtualUserId)) {
        isSelected = [self.memberRecipientIds containsObject:virtualUserId];
    }

    if (isSelected) {
        contactCell.selectionStatus = ContactCellSelectionStatusSelected;
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)originalTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:ContactTableViewCell.class]) {
        ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
        // Never flip Disabled / DisabledSelected rows to Selected.
        if (contactCell.selectionStatus == ContactCellSelectionStatusDisabledSelected ||
            contactCell.selectionStatus == ContactCellSelectionStatusDisabled) {
            return;
        }
        contactCell.selectionStatus = ContactCellSelectionStatusSelected;
    }
}

@end

NS_ASSUME_NONNULL_END
