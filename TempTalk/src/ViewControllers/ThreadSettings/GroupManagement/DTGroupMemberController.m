//
//  DTGroupMemberController.m
//  Wea
//
//  Created by hornet on 2022/1/5.
//

#import "DTGroupMemberController.h"
#import "TempTalk-Swift.h"
#import "SignalApp.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/UIUtil.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupModel.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/DTToastHelper.h>
#import "DTSelectedAccountToolView.h"
#import "DTChangeYourSettingsInAGroupAPI.h"
#import "OWSConversationSettingsViewController.h"

typedef NS_ENUM(NSInteger, DTUserSelectedActionType) {//控制器类型
    DTUserSelectedActionTypeForSelected = 0,//用户行为是选择
    DTUserSelectedActionTypeForUnSelected = 1,//用户行为是删除
};


CGFloat const kGroupMemberBottomViewHeight = 70;
@interface DTGroupMemberController ()<ContactsViewHelperDelegate, OWSTableViewControllerDelegate, DTSelectedAccountToolViewDelegate>
@property (nonatomic, readonly) TSGroupThread *thread;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, nullable) NSSet<NSString *> *memberRecipientIds;
@property (nonatomic, strong) NSMutableArray *sortedMemberRecipientIdsArr;

@property (nonatomic, strong) NSMutableArray *selectedMemberRecipientIdsArr;
@property (nonatomic, strong) NSMutableDictionary *selectedRecipientIdsMap;
@property (nonatomic, strong) UIView *bottomContainView;
@property (nonatomic, strong) DTSelectedAccountToolView *selectedAccountToolView;
@property (nonatomic, strong) NSLayoutConstraint *tableViewBottomLayoutConstraint;
@property (nonatomic, strong) DTChangeYourSettingsInAGroupAPI *changeYourSettingsInAGroupAPI;
@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;
@property (nonatomic, strong) NSIndexPath *currentTapIndexPath;
@property (nonatomic, assign) DTUserSelectedActionType userActionType;
@end

@implementation DTGroupMemberController

- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    [self commonInit];
    return self;
}


- (void)commonInit {
    self.selectedType = DTGroupMemberSelectedType_MultipleChoice;
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    [self observeNotifications];
    self.delegate = self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)observeNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
}

- (void)configWithThread:(TSGroupThread *)thread {
    _thread = thread;
    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMemberIds);
    if (self.controllerType == DTGroupMemberSelectedType_AddAdminPeople) {//添加群协调人
        self.memberRecipientIds = [NSSet setWithArray:self.thread.groupModel.groupMemberIds];
        NSMutableSet *tmpSet = self.memberRecipientIds.mutableCopy;
        for (NSString *receptId in self.memberRecipientIds) {
            if (receptId.length <= 6) {
                [tmpSet removeObject:receptId];
            }
        }
        self.memberRecipientIds = tmpSet.copy;
    }else if(self.controllerType == DTGroupMemberSelectedType_DeleteAdminPeople) {//删除群协调人
        self.memberRecipientIds = [NSSet setWithArray:self.thread.groupModel.groupAdmin];
    }else if(self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople){
        NSMutableArray *groupAdminTmpArr = [self.thread.groupModel.groupAdmin mutableCopy];
        if ([groupAdminTmpArr containsObject:self.thread.groupModel.groupOwner]) {
            [groupAdminTmpArr removeObject:self.thread.groupModel.groupOwner];
        }
        self.memberRecipientIds = [NSSet setWithArray:groupAdminTmpArr.copy];
    }else if(self.controllerType == DTGroupMemberSelectedType_TransferOwer){
        NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
        NSMutableArray *groupMemberIdsTmpArr = self.thread.groupModel.groupMemberIds.mutableCopy;
        [groupMemberIdsTmpArr removeObject:localNumber];
        for (NSString * receptid in groupMemberIdsTmpArr.copy) {
            if (receptid.length <= 6) {
                [groupMemberIdsTmpArr removeObject:receptid];
            }
        }
        self.memberRecipientIds = [NSSet setWithArray:groupMemberIdsTmpArr.copy];
    }
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);
    if (self.controllerType == DTGroupMemberSelectedType_AddAdminPeople) {//添加群管理员
        self.title = Localized(@"LIST_GROUP_MEMBERS_ADD_MANAGER", @"title for show group members view");
    }else if (self.controllerType == DTGroupMemberSelectedType_DeleteAdminPeople) {
        self.title = Localized(@"LIST_GROUP_MEMBERS_DELETE_MANAGER", @"title for show group members view");
    }else if(self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople){//展示群管理员
        self.title = Localized(@"LIST_GROUP_MEMBERS_ADMIN", @"title for show group members view");
    }else {//转让群主
        self.title = Localized(@"LIST_GROUP_MEMBERS_TRADSFAR_OWER", @"title for show group members view");
    }
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 45;
    if (self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople) {
        self.tableView.allowsMultipleSelection = false;
    }else {
        self.tableView.allowsMultipleSelection = true;
        self.canEditRow = YES;
        self.tableView.editing = YES;
        self.tableView.allowsMultipleSelectionDuringEditing = YES;
    }
    self.tableView.backgroundColor = Theme.backgroundColor;
    //处理底部的用户选择框
    [self creatBottomContainView];
    [self configBottomContainViewLayoput];
    [self updateTableContents];
}


- (void)creatBottomContainView {
        [self.view addSubview:self.bottomContainView];
        self.bottomContainView.hidden = true;
        [self.bottomContainView addSubview:self.selectedAccountToolView];
        [self.selectedAccountToolView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.bottomContainView withOffset:10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.bottomContainView withOffset:10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.bottomContainView withOffset:-10];
        [self.selectedAccountToolView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.bottomContainView withOffset:-15];
}

- (void)configBottomContainViewLayoput {
        [self.bottomContainView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
        [self.bottomContainView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view];
        [self.bottomContainView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view];
        [self.bottomContainView autoSetDimension:ALDimensionHeight toSize:kGroupMemberBottomViewHeight];
        [self.bottomContainView autoHCenterInSuperview];
}

//展示底部的选中展示人员的容器
- (void)showBottomSelectedPersonContainView {
    self.tableViewBottomLayoutConstraint = [self.tableView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom withInset:kGroupMemberBottomViewHeight];
    self.bottomContainView.hidden = false;
}
- (void)hideBottomSelectedPersonContainView {
    [NSLayoutConstraint deactivateConstraints:@[self.tableViewBottomLayoutConstraint]];
    
    [self.tableView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.view];
    self.bottomContainView.hidden = true;
}


#pragma mark - Table Contents

- (void)updateTableContents {
    OWSAssertDebug(self.thread);
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *membersSection = [OWSTableSection new];
    NSMutableSet *memberRecipientIds = [self.memberRecipientIds mutableCopy];
    [self addMembers:memberRecipientIds.allObjects toSection:membersSection useVerifyAction:NO];
    [contents addSection:membersSection];
    self.contents = contents;
}

- (void)addMembers:(NSArray<NSString *> *)recipientIds
          toSection:(OWSTableSection *)section
    useVerifyAction:(BOOL)useVerifyAction {
    OWSAssertDebug(recipientIds);
    OWSAssertDebug(section);

    ContactsViewHelper *helper = self.contactsViewHelper;
    // Sort the group members using contacts manager.
    NSArray<NSString *> *sortedRecipientIds =
        [recipientIds sortedArrayUsingComparator:^NSComparisonResult(NSString *recipientIdA, NSString *recipientIdB) {
            SignalAccount *signalAccountA = [helper.contactsManager signalAccountForRecipientId:recipientIdA];
            SignalAccount *signalAccountB = [helper.contactsManager signalAccountForRecipientId:recipientIdB];
            return [helper.contactsManager compareSignalAccount:signalAccountA withSignalAccount:signalAccountB];
        }];
    
    
    NSString *groupOwnerID = ((TSGroupThread *)self.thread).groupModel.groupOwner;
    if (self.controllerType == DTGroupMemberSelectedType_AddAdminPeople) {//添加群管理员
        if (groupOwnerID) {
            //删除群主，不展示群主
            NSMutableArray *mutableSortedRecipientIds = sortedRecipientIds.mutableCopy;
            if ([sortedRecipientIds containsObject:groupOwnerID]) {
                [mutableSortedRecipientIds removeObject:groupOwnerID];
            }
            sortedRecipientIds = mutableSortedRecipientIds.copy;
        }
        NSMutableArray *tmpArr = [sortedRecipientIds mutableCopy];
        for (NSString *recipientId in self.thread.groupModel.groupAdmin) {//删除已经是群管理的人员
            if ([sortedRecipientIds containsObject:recipientId]) {
                [tmpArr removeObject:recipientId];
            }
        }
        self.sortedMemberRecipientIdsArr = tmpArr.mutableCopy;
    }else if (self.controllerType == DTGroupMemberSelectedType_DeleteAdminPeople){
// 剔除自己 剔除群主
        if (groupOwnerID) {
            //删除群主，不展示群主
            NSMutableArray *mutableSortedRecipientIds = sortedRecipientIds.mutableCopy;
            if ([sortedRecipientIds containsObject:groupOwnerID]) {
                [mutableSortedRecipientIds removeObject:groupOwnerID];
            }
            sortedRecipientIds = mutableSortedRecipientIds.copy;
        }
        NSMutableArray *tmpArr = [sortedRecipientIds mutableCopy];
        if ([tmpArr containsObject:[TSAccountManager sharedInstance].localNumber]) {
            [tmpArr removeObject:[TSAccountManager sharedInstance].localNumber];
        }
        self.sortedMemberRecipientIdsArr = tmpArr.mutableCopy;
    }else if(self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople){
        self.sortedMemberRecipientIdsArr = sortedRecipientIds.mutableCopy;
    }else if(self.controllerType == DTGroupMemberSelectedType_TransferOwer){
        self.sortedMemberRecipientIdsArr = sortedRecipientIds.mutableCopy;
    }else {
        
    }
    
    @weakify(self)
    for (NSString *recipientId in self.sortedMemberRecipientIdsArr) {
        [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
                                 ContactTableViewCell *cell = [ContactTableViewCell new];
                                 SignalAccount *signalAccount = [helper signalAccountForRecipientId:recipientId];
                                 OWSVerificationState verificationState =
                                     [[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId];
//                                 BOOL isVerified = verificationState == OWSVerificationStateVerified;
//                                 BOOL isNoLongerVerified = verificationState == OWSVerificationStateNoLongerVerified;
//                                 BOOL isBlocked = [helper isRecipientIdBlocked:recipientId];
//                                 if (isNoLongerVerified) {
//                                     cell.accessoryMessage = Localized(@"CONTACT_CELL_IS_NO_LONGER_VERIFIED",
//                                         @"An indicator that a contact is no longer verified.");
//                                 } else if (isBlocked) {
//                                     cell.accessoryMessage = Localized(
//                                         @"CONTACT_CELL_IS_BLOCKED", @"An indicator that a contact has been blocked.");
//                                 }

                                 if (signalAccount) {
                                     [cell setAccessoryMessage:@""];
                                     [cell configureWithThread:self.thread signalAccount:signalAccount
                                                      contactsManager:helper.contactsManager];
                                 } else {
                                     [cell setAccessoryMessage:@""];
                                     [cell configureWithThread:self.thread recipientId:recipientId contactsManager:helper.contactsManager];
                                 }
                                  cell.cellView.type = UserOfSelfIconTypeRealAvater;
//                                 if (isVerified) {
//                                     [cell setAttributedSubtitle:cell.verifiedSubtitle];
//                                 } else {
//                                     [cell setAttributedSubtitle:nil];
//                                 }
                                    cell.tintColor = [UIColor ows_materialBlueColor];
                                 return cell;
        } customRowHeight:70 actionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath) {
            @strongify(self)
            if (!indexPath) {
                return;
            }
            self.userActionType = DTUserSelectedActionTypeForSelected;
            self.currentTapIndexPath = indexPath;
            if (self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople){
                return;
            }
            NSString *receptedId;
            if (indexPath.row <= (NSInteger)self.sortedMemberRecipientIdsArr.count -1) {
                receptedId = self.sortedMemberRecipientIdsArr[(NSUInteger)indexPath.row];
            }
            if (!receptedId) {
                return;
            }
            if (self.selectedType == DTGroupMemberSelectedType_SingleChoice && self.selectedMemberRecipientIdsArr.count == 1) {
                self.maxSelected = true;
                return;
            }
           
            if (![self.selectedMemberRecipientIdsArr containsObject:receptedId]) {
                [self.selectedMemberRecipientIdsArr addObject:receptedId];
                [self.selectedRecipientIdsMap setValue:indexPath forKey:receptedId];
                [self.selectedAccountToolView reloadWithData:self.selectedMemberRecipientIdsArr];
                switch (self.controllerType) {
                    case DTGroupMemberSelectedType_AddAdminPeople:{
                        [self requestForAddGroupMangerWithReceptId:receptedId];
                    }break;
                    case DTGroupMemberSelectedType_DeleteAdminPeople:{
                        [self requestForDeleteGroupMangerWithReceptId:receptedId];
                    }break;
                    case DTGroupMemberSelectedType_TransferOwer:{
                        [self showConfirmAlert];
                        return;
                    }break;
                    default:
                        break;
                }
               
                [self showBottomSelectedPersonContainView];
            }
            
        } deselectActionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath) {
            @strongify(self)
            if (!indexPath) {
                return;
            }
            self.currentTapIndexPath = indexPath;
            self.userActionType = DTUserSelectedActionTypeForUnSelected;
            if (self.controllerType == DTGroupMemberSelectedType_ShowAdminPeople){
                return;
            }
            NSString *receptedId;
            if (indexPath.row <= (NSInteger)self.sortedMemberRecipientIdsArr.count -1) {
                receptedId = self.sortedMemberRecipientIdsArr[(NSUInteger)indexPath.row];
            }
            if (!receptedId) {
                return;
            }
            
            if ([self.selectedMemberRecipientIdsArr containsObject:receptedId]) {
                [self.selectedMemberRecipientIdsArr removeObject:receptedId];
                [self.selectedRecipientIdsMap removeObjectForKey:receptedId];
                [self.selectedAccountToolView reloadWithData:self.selectedMemberRecipientIdsArr];
                switch (self.controllerType) {
                    case DTGroupMemberSelectedType_AddAdminPeople:{//添加群成员中取消选中
                        [self requestForDeleteGroupMangerWithReceptId:receptedId];
                    }break;
                    case DTGroupMemberSelectedType_DeleteAdminPeople:{
                        [self requestForAddGroupMangerWithReceptId:receptedId];
                    }break;
                    default:
                        break;
                }
                
                if (self.selectedMemberRecipientIdsArr.count == 0) {
                    [self hideBottomSelectedPersonContainView];
                }
            }
        }]];
    }
}

- (void)offerResetAllNoLongerVerified {
    OWSAssertIsOnMainThread();

    UIAlertController *actionSheetController = [UIAlertController
        alertControllerWithTitle:nil
                         message:Localized(@"GROUP_MEMBERS_RESET_NO_LONGER_VERIFIED_ALERT_MESSAGE",
                                     @"Label for the 'reset all no-longer-verified group members' confirmation alert.")
                  preferredStyle:UIAlertControllerStyleAlert];

    __weak DTGroupMemberController *weakSelf = self;
    UIAlertAction *verifyAction = [UIAlertAction actionWithTitle:Localized(@"OK", nil)
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *_Nonnull action) {
                                                             [weakSelf resetAllNoLongerVerified];
                                                         }];
    [actionSheetController addAction:verifyAction];
    [actionSheetController addAction:[OWSAlerts cancelAction]];

    [self presentViewController:actionSheetController animated:YES completion:nil];
}

#pragma mark DTSelectedAccountToolViewDelegate
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {
        return;
    }
   
}

- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView okBtnClick:(UIButton *)sender {
    switch (self.controllerType) {
        case DTGroupMemberSelectedType_AddAdminPeople:{//添加群管理
//            [self requestForAddGroupManger];
            [self.navigationController popViewControllerAnimated:true];
        }
            break;
        case DTGroupMemberSelectedType_DeleteAdminPeople:{//删除群管理
//            NSString *receptId = self.selectedMemberRecipientIdsArr.lastObject;
//            [self requestForDeleteGroupMangerWithReceptId:receptId];
            [self.navigationController popViewControllerAnimated:true];
        }
            break;
        case DTGroupMemberSelectedType_TransferOwer:{
            [self showConfirmAlert];
        }
            break;
        default:
            break;
    }
   
}

//发送请求转让群主
- (void)requesForTranferOwer {
    [self requestForChangeOwer];
}
//请求添加群管理
- (void)requestForAddGroupMangerWithReceptId:(NSString *) receptId{
    if (!receptId) {
        return;
    }
    [self requestForChangeGroupMemberRoleWithRole:@(1) uid:receptId];
}
//请求删除群管理
- (void)requestForDeleteGroupMangerWithReceptId:(NSString *) receptId {
    if (!receptId) {
        return;
    }
    [self requestForChangeGroupMemberRoleWithRole:@(2) uid:receptId];
}

- (void)requestForChangeOwer {
    NSString *tranferId = self.selectedMemberRecipientIdsArr.lastObject;
    if (!tranferId) {
        return;
    }
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:self.thread.groupModel.groupId];
    if ([self.thread.groupModel.groupOwner isEqualToString:tranferId]) {
        return;
    }
    [DTToastHelper showHudInView:self.view];
    [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:serverGId updateInfo:@{@"owner" : tranferId} success:^(DTAPIMetaEntity * _Nonnull entity) {
        [DTToastHelper hide];
        NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
        NSMutableArray *groupAdmin = [self.thread.groupModel.groupAdmin mutableCopy];
        ///目前群主转让成功之后角色自动转成群管理员，需要更新本地缓存
        if (![self.thread.groupModel.groupAdmin containsObject:localNumber]) {
            [groupAdmin addObject:[TSAccountManager sharedInstance].localNumber];
        }
        if([self.thread.groupModel.groupAdmin containsObject:tranferId]){
            [groupAdmin removeObject:tranferId];
        }
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self.thread anyUpdateGroupThreadWithTransaction:transaction
                                                       block:^(TSGroupThread * instance) {
                instance.groupModel.groupAdmin = groupAdmin.copy;
                instance.groupModel.groupOwner = tranferId;
            }];
            BOOL tmpShouldAffectSorting = NO;
            NSString *updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithTransferOwer:tranferId shouldAffectThreadSorting:&tmpShouldAffectSorting transaction:transaction];
            [self generateInfoMessageWithUpdateGroupInfo:updateGroupInfo transaction:transaction];
        });
        [DTToastHelper toastWithText:Localized(@"LIST_GROUP_MEMBERS_TRADSFAR_OWER_SUCESS_TIP",@"") durationTime:2.5];
        if (self.memberControllerDelegate && [self.memberControllerDelegate respondsToSelector:@selector(groupOwerWasChangedWithType:)]) {
            [self.memberControllerDelegate groupOwerWasChangedWithType:self.controllerType];
        }
        OWSConversationSettingsViewController *conversationSettingsVC;
        for (UIViewController *stackVC in self.navigationController.viewControllers) {
            if ([stackVC isKindOfClass:OWSConversationSettingsViewController.class]) {
                conversationSettingsVC = (OWSConversationSettingsViewController *)stackVC;
            }
        }
        if (conversationSettingsVC) {
            [self.navigationController popToViewController:conversationSettingsVC animated:true];
        }else {
            [self.navigationController popToRootViewControllerAnimated:true];
        }
        
    } failure:^(NSError * _Nonnull error) {
        [self recoverCellStateWithUid:tranferId];
        [DTToastHelper hide];
        [DTToastHelper toastWithText:Localized(@"LIST_GROUP_MEMBERS_TRADSFAR_OWER_FAILED_TIP",@"") durationTime:2.5];
    }];
}

- (void)generateInfoMessageWithUpdateGroupInfo:(NSString *)updateGroupInfo
                                 transaction:(SDSAnyWriteTransaction *)transaction{
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    [[[TSInfoMessage alloc] initWithTimestamp:now
                                     inThread:self.thread
                                  messageType:TSInfoMessageTypeGroupUpdate
                                customMessage:updateGroupInfo] anyInsertWithTransaction:transaction];
}

//添加群管理员
- (void)requestForChangeGroupMemberRoleWithRole:(NSNumber *)roleNumber uid:(NSString *)uid{
    [DTToastHelper showHudInView:self.view];
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:self.thread.groupModel.groupId];
    __weak typeof(self)weakSelf = self;
    [self.changeYourSettingsInAGroupAPI sendRequestWithGroupId:serverGId role:roleNumber uid:uid success:^(DTAPIMetaEntity * _Nonnull entity) {
            [DTToastHelper hide];
        TSGroupModel *oldGroupModel = [self.thread.groupModel copy];
        switch (weakSelf.controllerType) {
                //添加群管理员
            case DTGroupMemberSelectedType_AddAdminPeople:{//添加群管理员
                NSMutableArray *oldGroupAdminArr = [weakSelf.thread.groupModel.groupAdmin mutableCopy];
                if (self.userActionType == DTUserSelectedActionTypeForSelected) {//用户行为是添加
                    if (![oldGroupAdminArr containsObject:uid]) {
                        [oldGroupAdminArr addObject:uid];
                    }
                }else {//用户行为是删除
                    if ([oldGroupAdminArr containsObject:uid]) {
                        [oldGroupAdminArr removeObject:uid];
                    }
                }
               
                //更新thread信息
                TSGroupModel *newGroupModel = [self.thread.groupModel copy];
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    [weakSelf.thread anyUpdateGroupThreadWithTransaction:transaction block:^(TSGroupThread * instance) {
                        instance.groupModel.groupAdmin = [oldGroupAdminArr copy];
                    }];
                    NSString *updateGroupInfo = nil;
                    if (self.userActionType == DTUserSelectedActionTypeForSelected) {//用户行为是添加
                        updateGroupInfo = [self getSystermUpdateInfoWithOldGroupModel:oldGroupModel withNewGroupModel:newGroupModel isAdd:true transaction:transaction];
                    }else {
                        updateGroupInfo = [self getSystermUpdateInfoWithOldGroupModel:oldGroupModel withNewGroupModel:newGroupModel isAdd:false transaction:transaction];
                    }
                    [self generateInfoMessageWithUpdateGroupInfo:updateGroupInfo
                                                     transaction:transaction];
                });
                                
                if (weakSelf.memberControllerDelegate && [weakSelf.memberControllerDelegate respondsToSelector:@selector(memberIdsWasAdded:withType:)]) {
                    [weakSelf.memberControllerDelegate memberIdsWasAdded:weakSelf.selectedMemberRecipientIdsArr withType:weakSelf.controllerType];
                }
            } return;
            case DTGroupMemberSelectedType_DeleteAdminPeople:{//删除群管理员
                NSMutableArray *oldGroupAdminArr = [weakSelf.thread.groupModel.groupAdmin mutableCopy];
                if (self.userActionType == DTUserSelectedActionTypeForSelected) {//用户行为是选中，及表示删除
                    if ([oldGroupAdminArr containsObject:uid]) {
                        [oldGroupAdminArr removeObject:uid];
                    }
                }else {//用户行为是不选中，及表示添加为管理员
                    if (![oldGroupAdminArr containsObject:uid]) {
                        [oldGroupAdminArr addObject:uid];
                    }
                }
                //更新thread信息
                TSGroupModel *newGroupModel = self.thread.groupModel;
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    [weakSelf.thread anyUpdateGroupThreadWithTransaction:transaction block:^(TSGroupThread * instance) {
                        instance.groupModel.groupAdmin = [oldGroupAdminArr copy];
                    }];
                    NSString *updateGroupInfo = nil;
                    if (self.userActionType == DTUserSelectedActionTypeForSelected) {//用户行为是添加
                        updateGroupInfo = [self getSystermUpdateInfoWithOldGroupModel:oldGroupModel withNewGroupModel:newGroupModel isAdd:false transaction:transaction];
                    }else {
                        updateGroupInfo = [self getSystermUpdateInfoWithOldGroupModel:oldGroupModel withNewGroupModel:newGroupModel isAdd:true transaction:transaction];
                    }
                    
                    [self generateInfoMessageWithUpdateGroupInfo:updateGroupInfo
                                                     transaction:transaction];
                });
                if (weakSelf.memberControllerDelegate && [weakSelf.memberControllerDelegate respondsToSelector:@selector(memberIdsWasAdded:withType:)]) {
                    [weakSelf.memberControllerDelegate memberIdsWasAdded:weakSelf.selectedMemberRecipientIdsArr withType:weakSelf.controllerType];
                }
            } return;;
           
            default:
                break;
        }
    } failure:^(NSError * _Nonnull error) {
            [DTToastHelper hide];
        switch (weakSelf.controllerType) {
            case DTGroupMemberSelectedType_AddAdminPeople:{//添加群管理员
                [self recoverCellStateWithUid:uid];
            }
                break;
            case DTGroupMemberSelectedType_DeleteAdminPeople:{//删除群管理员
                [self recoverCellStateWithUid:uid];
            }
                break;
                
            default:
                break;
        }
        
            [DTToastHelper toastWithText:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") durationTime:2.5];
    }];
}

- (void)recoverCellStateWithUid:(NSString *)uid {
    if(self.userActionType == DTUserSelectedActionTypeForSelected){//删除
        if ([self.selectedMemberRecipientIdsArr containsObject:uid]) {
            [self.selectedMemberRecipientIdsArr removeObject:uid];
            [self.selectedRecipientIdsMap removeObjectForKey:uid];
            [self.selectedAccountToolView reloadWithData:self.selectedMemberRecipientIdsArr];
            [self.tableView deselectRowAtIndexPath:self.currentTapIndexPath animated:true];
        }
    }else {
        [self.selectedMemberRecipientIdsArr addObject:uid];
        [self.selectedRecipientIdsMap setValue:self.currentTapIndexPath forKey:uid];
        [self.selectedAccountToolView reloadWithData:self.selectedMemberRecipientIdsArr];
        [self.tableView selectRowAtIndexPath:self.currentTapIndexPath animated:true scrollPosition:UITableViewScrollPositionNone];
    }
    if (self.controllerType == DTGroupMemberSelectedType_AddAdminPeople || self.controllerType ==DTGroupMemberSelectedType_DeleteAdminPeople) {
        if (self.selectedMemberRecipientIdsArr.count >0) {
            [self showBottomSelectedPersonContainView];
        }else{
            [self hideBottomSelectedPersonContainView];
        }
    }
    
}

- (NSString *)getSystermUpdateInfoWithOldGroupModel:(TSGroupModel *) oldGroupModel withNewGroupModel:(TSGroupModel *) newGroupModel isAdd:(BOOL) isAdd transaction:(SDSAnyReadTransaction *)transaction{
    NSMutableSet *oldAdminSet = [[NSMutableSet alloc] initWithArray:oldGroupModel.groupAdmin];//老的群管理员的集
    NSMutableSet *newAdminSet = [[NSMutableSet alloc] initWithArray:newGroupModel.groupAdmin];//新的群管理的集合
    
    //获取两个集合的交集
    NSMutableSet *intersectSet = [oldAdminSet mutableCopy];
    [intersectSet intersectSet:newAdminSet];
    
    //删除的用户id集合
    NSMutableSet *removeedSet = [oldAdminSet mutableCopy];
    [removeedSet minusSet:intersectSet];
    
    //增加的用户id集合
    NSMutableSet *addedSet = [newAdminSet mutableCopy];
    [addedSet minusSet:intersectSet];
    NSString *updateGroupInfo;
    if (isAdd) {
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithAddedAdminIds:addedSet.allObjects removedIds:nil transaction:transaction];
    }else {
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithAddedAdminIds:nil removedIds:removeedSet.allObjects transaction:transaction];
    }
    return updateGroupInfo;
}



- (void)showConfirmAlert {
    NSString *receptid = self.selectedMemberRecipientIdsArr.lastObject;
    if (!receptid) {
        return;
    }
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:receptid];
    if (!account) {
        return;
    }
    NSString *tipmessage = [NSString stringWithFormat:Localized(@"LIST_GROUP_MEMBERS_TRADSFAR_OWER_TIP",
                                                                        @""),account.contact.fullName];
    
    UIAlertController *alerVC = [UIAlertController alertControllerWithTitle:nil message:tipmessage preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *actionConfirm = [UIAlertAction actionWithTitle:Localized(@"TXT_CONFIRM_TITLE", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self requesForTranferOwer];
    }];
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:Localized(@"TXT_CANCEL_TITLE",
                                                                                   @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.userActionType = DTUserSelectedActionTypeForSelected;
        [self recoverCellStateWithUid:receptid];
        
    }];
    [alerVC addAction:actionCancel];
    [alerVC addAction:actionConfirm];
    [self presentViewController:alerVC animated:YES completion:nil];
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
                           isUserInitiatedChange:YES
                             isSendSystemMessage:NO];
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

- (void)didSelectRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    ContactsViewHelper *helper = self.contactsViewHelper;
    SignalAccount *signalAccount = [helper signalAccountForRecipientId:recipientId];

    UIAlertController *actionSheetController =
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *contactInfoTitle = signalAccount
        ? Localized(@"GROUP_MEMBERS_VIEW_CONTACT_INFO", @"Button label for the 'show contact info' button")
        : Localized(
              @"GROUP_MEMBERS_ADD_CONTACT_INFO", @"Button label to add information to an unknown contact");
    [actionSheetController addAction:[UIAlertAction actionWithTitle:contactInfoTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *_Nonnull action) {
                                                                [self showProfileCardInfoWith:recipientId isFromSameThread:false isPresent:true];
                                                            }]];

    BOOL isBlocked;
    if (signalAccount) {
        isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
        if (isBlocked) {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_UNBLOCK_BUTTON",
                                                             @"Button label for the 'unblock' button")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showUnblockSignalAccountActionSheet:signalAccount
                                                                          fromViewController:self
                                                                             blockingManager:helper.blockingManager
                                                                             contactsManager:helper.contactsManager
                                                                             completionBlock:^(BOOL ignore) {
                                                                                 [self updateTableContents];
                                                                             }];
                                                 }]];
        } else {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_BLOCK_BUTTON",
                                                             @"Button label for the 'block' button")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showBlockSignalAccountActionSheet:signalAccount
                                                                        fromViewController:self
                                                                           blockingManager:helper.blockingManager
                                                                           contactsManager:helper.contactsManager
                                                                           completionBlock:^(BOOL ignore) {
                                                                               [self updateTableContents];
                                                                           }];
                                                 }]];
        }
    } else {
        isBlocked = [helper isRecipientIdBlocked:recipientId];
        if (isBlocked) {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_UNBLOCK_BUTTON",
                                                             @"Button label for the 'unblock' button")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showUnblockPhoneNumberActionSheet:recipientId
                                                                        fromViewController:self
                                                                           blockingManager:helper.blockingManager
                                                                           contactsManager:helper.contactsManager
                                                                           completionBlock:^(BOOL ignore) {
                                                                               [self updateTableContents];
                                                                           }];
                                                 }]];
        } else {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_BLOCK_BUTTON",
                                                             @"Button label for the 'block' button")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showBlockPhoneNumberActionSheet:recipientId
                                                                      fromViewController:self
                                                                         blockingManager:helper.blockingManager
                                                                         contactsManager:helper.contactsManager
                                                                         completionBlock:^(BOOL ignore) {
                                                                             [self updateTableContents];
                                                                         }];
                                                 }]];
        }
    }

    if (!isBlocked) {
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:Localized(@"GROUP_MEMBERS_SEND_MESSAGE",
                                                         @"Button label for the 'send message to group member' button")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *_Nonnull action) {
                                                 [self showConversationViewForRecipientId:recipientId];
                                             }]];

        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:Localized(@"VERIFY_PRIVACY",
                                                         @"Label for button or row which allows users to verify the "
                                                         @"safety number of another user.")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *_Nonnull action) {
                                                 [self showSafetyNumberView:recipientId];
                                             }]];
    }

    [actionSheetController addAction:[OWSAlerts cancelAction]];

    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)showConversationViewForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [SignalApp.sharedApp presentConversationForRecipientId:recipientId action:ConversationViewActionCompose];
}

- (void)callMember:(NSString *)recipientId
{
    [SignalApp.sharedApp presentConversationForRecipientId:recipientId action:ConversationViewActionAudioCall];
}

- (void)showSafetyNumberView:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [FingerprintViewController presentFromViewController:self recipientId:recipientId];
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

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    DDLogDebug(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
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
        [_selectedAccountToolView showOKBtn:false];
    }
    return _selectedAccountToolView;
}

- (NSMutableArray *)sortedMemberRecipientIdsArr {
    if (!_sortedMemberRecipientIdsArr) {
        _sortedMemberRecipientIdsArr = [NSMutableArray array];
    }
    return _sortedMemberRecipientIdsArr;
}

-(NSMutableArray *)selectedMemberRecipientIdsArr {
    if (!_selectedMemberRecipientIdsArr) {
        _selectedMemberRecipientIdsArr = [NSMutableArray array];
    }
    return _selectedMemberRecipientIdsArr;
}

- (NSMutableDictionary *)selectedRecipientIdsMap {
    if (!_selectedRecipientIdsMap) {
        _selectedRecipientIdsMap = [NSMutableDictionary dictionary];
    }
    return _selectedRecipientIdsMap;
}

- (DTChangeYourSettingsInAGroupAPI *)changeYourSettingsInAGroupAPI{
    if(!_changeYourSettingsInAGroupAPI){
        _changeYourSettingsInAGroupAPI = [DTChangeYourSettingsInAGroupAPI new];
    }
    return _changeYourSettingsInAGroupAPI;
}

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI {
    if (!_updateGroupInfoAPI) {
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}
@end
