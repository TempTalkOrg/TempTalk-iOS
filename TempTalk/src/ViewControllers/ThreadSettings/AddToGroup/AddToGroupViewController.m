//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AddToGroupViewController.h"
#import "BlockListUIUtils.h"
#import "ContactsViewHelper.h"
#import "TempTalk-Swift.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/DTToastHelper.h>
#import "DTAddMembersToAGroupAPI.h"
#import "DTAddToGroupItem.h"
#import "DTSelectedAccountToolView.h"

static CGFloat const kBottomViewHeight = 70;

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
@property(nonatomic,strong) UIView *bottomContainView;
@property(nonatomic,strong) DTSelectedAccountToolView *selectedAccountToolView;

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
    
    [self.doneButton setTitleColor:Theme.themeBlueColor forState:UIControlStateSelected];
    if (self.presentingViewController) {
        [self.navigationItem.leftBarButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateNormal];
        [self.navigationItem.leftBarButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateHighlighted];
    }
    
    if (self.view.window.windowLevel == UIWindowLevel_CallView()) {
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.primaryTextColor}];
        self.navigationController.navigationBar.tintColor = Theme.primaryTextColor;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = Theme.isDarkThemeEnabled?[UIColor colorWithRgbHex:0x282828]:[UIColor colorWithRgbHex:0xFFFFFF];
    self.tableViewController.view.backgroundColor = Theme.isDarkThemeEnabled?[UIColor colorWithRgbHex:0x282828]:[UIColor colorWithRgbHex:0xFFFFFF];
    
    self.doneButton = [[UIButton alloc] init];
    self.doneButton.titleLabel.font = [UIFont ows_regularFontWithSize:17];
    self.doneButton.userInteractionEnabled = NO;
    self.doneButton.selected = NO;
    [self.doneButton setTitle:Localized(@"BUTTON_DONE", @"") forState:UIControlStateNormal];
    [self.doneButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [self.doneButton setTitleColor:Theme.themeBlueColor forState:UIControlStateSelected];
    [self.doneButton addTarget:self action:@selector(doneAction) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.doneButton];
    self.tableViewController.tableView.allowsMultipleSelection = true;
    self.tableViewController.tableView.allowsMultipleSelectionDuringEditing = true;
    self.tableViewController.canEditRow = NO;
    self.tableViewController.tableView.editing = YES;
    //处理底部的用户选择框
    [self creatBottomContainView];
    [self configBottomContainViewLayoput];
    self.memberRecipientIds = [NSMutableSet new];
    self.virtualUserIdOrEmails = [NSMutableSet new];
    self.memberRecipientIdsArr = [NSMutableArray array];
    if (self.thread) {
        [self.memberRecipientIds addObjectsFromArray:self.thread.groupModel.groupMemberIds];
        self.previousMemberRecipientIds = [NSSet setWithArray:self.thread.groupModel.groupMemberIds];
    }
    
    if (self.presentingViewController) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelItemAction)];
    }
    
    [self applyTheme];
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

- (void)creatBottomContainView {
    if (self.addToGroupStyle == DTAddToGroupStyleShowSelectedPerson) {
        [self.view addSubview:self.bottomContainView];
        self.bottomContainView.hidden = true;
        [self.bottomContainView addSubview:self.selectedAccountToolView];
        [self.selectedAccountToolView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.bottomContainView withOffset:10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.bottomContainView withOffset:10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.bottomContainView withOffset:-10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.bottomContainView withOffset:-15];
    }else {
#warning 待处理
    }
}

- (void)configBottomContainViewLayoput {
    if (self.addToGroupStyle == DTAddToGroupStyleShowSelectedPerson) {
        [self.bottomContainView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
        [self.bottomContainView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view];
        [self.bottomContainView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view];
        [self.bottomContainView autoSetDimension:ALDimensionHeight toSize:kBottomViewHeight];
        [self.bottomContainView autoHCenterInSuperview];
    }
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
    return Localized(
        @"ADD_GROUP_MEMBER_VIEW_CONTACT_TITLE", @"Title for the 'add contact' section of the 'add group member' view.");
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
    [self.selectedAccountToolView reloadWithData:self.memberRecipientIdsArr];
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
        OWSLogDebug(@"recipientId:%@ cannot invite user to a meeting", signalAccount.recipientId);
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
    if (self.addToGroupStyle == DTAddToGroupStyleShowSelectedPerson) {
        [self showBottomSelectedPersonContainView];
        [self.selectedAccountToolView reloadWithData:self.memberRecipientIdsArr];
    }
    //如果业务方实现了 recipientIdWasAdded 这个代理，表明业务方想要自己对数据进行处理，本VC就不再做处理
    if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(recipientIdWasAdded:)]) {
        [self.addToGroupDelegate recipientIdWasAdded:recipientId];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
}

//展示底部的选中展示人员的容器
- (void)showBottomSelectedPersonContainView {
    [self.tableViewController.tableView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom withInset:kBottomViewHeight];
    self.bottomContainView.hidden = false;
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
        
        //MARK: 添加成员预约会议相关
        [DTCalendarManager.shared groupChangeWithGid:self.thread.serverThreadId
                                          actionCode:3
                                              target:newJoinMember];

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
        [self.addMembersToAGroupAPI sendRequestWithWithGroupId:serverGId
                                                       numbers:membersWhoJoined.allObjects
                                                       success:^(DTAPIMetaEntity * _Nonnull entity) {
            [DTToastHelper hide];
            __block NSString *updateGroupInfo = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                BOOL tmpShouldAffectSorting = NO;
                updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:membersWhoJoined.allObjects removedMemberIds:nil leftMemberIds:nil shouldAffectThreadSorting:&tmpShouldAffectSorting transaction:transaction];
            }];
            nextBlock(updateGroupInfo, membersWhoJoined.allObjects);
            
            DispatchMainThreadSafe(^{
                [self.conversationSettingsViewDelegate popAllConversationSettingsViews];
            });
//            [self.navigationController popViewControllerAnimated:true];
        } failure:^(NSError * _Nonnull error) {
            NSString *logError = error.localizedDescription;;
            if(error.code == DTAPIRequestResponseStatusGroupIsFull) {
                logError = Localized(@"ENTER_GROUP_FAILURE_FULL", @"");
            }
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

    if (self.addToGroupDelegate && [self.addToGroupDelegate respondsToSelector:@selector(isRecipientGroupMember:)]) {
        if ([self.addToGroupDelegate isRecipientGroupMember:signalAccount.recipientId]) {
            return Localized(@"NEW_GROUP_MEMBER_LABEL", @"An indicator that a user is a member of the new group.");
        }
    }

    return nil;
}

- (BOOL)customUserConditions:(NSString *)userIdOrEmail {
    if (!self.addToGroupDelegate || ![self.addToGroupDelegate respondsToSelector:@selector(customUserConditions:)]) {
        return NO;
    }
    
    return [self.addToGroupDelegate customUserConditions:userIdOrEmail];
}

#pragma mark DTSelectedAccountToolViewDelegate
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!indexPath) {
        return;
    }
    NSString *receptid;
    if (indexPath.row <= (NSInteger)self.memberRecipientIdsArr.count) {
        receptid = [self.memberRecipientIdsArr objectAtIndex:(NSUInteger)indexPath.row];
    }
    if (!receptid) {
        return;
    }
    NSIndexPath *unSelectedIndexPath = [self.indexPathMap objectForKey:receptid];
    [self.tableViewController.tableView deselectRowAtIndexPath:unSelectedIndexPath animated:false];
    [self.memberRecipientIdsArr removeObject:receptid];
    [self.selectedAccountToolView reloadWithData:self.memberRecipientIdsArr];
    if (self.memberRecipientIdsArr.count == 0) {
        
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

- (UIView *)bottomContainView {
    if (!_bottomContainView) {
        _bottomContainView = [[UIView alloc] init];
        _bottomContainView.backgroundColor = [UIColor clearColor];
    }
    return _bottomContainView;
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
@end

NS_ASSUME_NONNULL_END
