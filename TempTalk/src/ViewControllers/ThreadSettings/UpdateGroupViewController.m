//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "UpdateGroupViewController.h"
#import "AddToGroupViewController.h"
#import "AvatarViewHelper.h"
#import "TempTalk-Swift.h"
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
#import "SVProgressHUD.h"
#import <TTServiceKit/DTGroupUtils.h>
#import <TTServiceKit/DTGroupAvatarUpdateProcessor.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import "DTImageBrowserView.h"


NS_ASSUME_NONNULL_BEGIN
extern  CGFloat const kAvatarSize;
@interface UpdateGroupViewController () <UIImagePickerControllerDelegate,
    UITextFieldDelegate,
    ContactsViewHelperDelegate,
    AvatarViewHelperDelegate,
    AddToGroupViewControllerDelegate,
    OWSTableViewControllerDelegate,
    UINavigationControllerDelegate,
    OWSNavigationChildController,
    OWSTableViewControllerDelegate>

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) AvatarViewHelper *avatarViewHelper;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
//@property (nonatomic, readonly) DTAvatarImageView *avatarView;
@property (nonatomic, readonly) UITextField *groupNameTextField;

@property (nonatomic, nullable) UIImage *groupAvatar;
@property (nonatomic, strong) NSArray <NSString *> *sortedMemberRecipientIds;
@property (nonatomic, strong) NSMutableSet <NSString *> *handledMemberRecipientIds;


@property (nonatomic) BOOL hasUnsavedChanges;

@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;
@property (nonatomic, strong) DTAddMembersToAGroupAPI *addMembersToAGroupAPI;
@property (nonatomic, strong) DTGroupAvatarUpdateProcessor *groupAvatarUpdateProcessor;
@property (nonatomic, strong)  DTImageBrowserView *photoBrowser;
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
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];

    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMemberIds);

    self.view.backgroundColor = Theme.backgroundColor;
    
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
    if(self.mode == UpdateGroupMode_EditGroupName){
        
        [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstSection];
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
    self.navigationItem.rightBarButtonItem = (self.hasUnsavedChanges
            ? [[UIBarButtonItem alloc] initWithTitle:Localized(@"EDIT_GROUP_UPDATE_BUTTON",
                                                         @"The title for the 'update group' button.")
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(updateGroupPressed)]
            : nil);
}

- (void)showEditView {
    switch (self.mode) {
        case UpdateGroupMode_EditGroupName:
            [self.groupNameTextField becomeFirstResponder];
            break;
        case UpdateGroupMode_EditGroupAvatar:{
            
//            [self showChangeAvatarUI];
//            if (self.mode == UpdateGroupMode_EditGroupAvatar) {
//                [self showAvatarBrowserViewAnimate:true];
//            }
        }
            break;
        default:
            break;
    }
}

- (void)showAvatarBrowserViewAnimate:(BOOL)animate {
//        NSMutableArray *items = [NSMutableArray new];
//        DTImageViewModel *item = [DTImageViewModel new];
//        item.thumbView = self.avatarView;
//        item.largeImageSize = CGSizeMake(180, 180);
//        item.receptid = [self.thread serverThreadId];
//        item.thread = self.thread;
//        item.image = self.groupAvatar;
//        [items addObject:item];
//        self.photoBrowser = [[DTImageBrowserView alloc] initWithGroupItems:items];
//        [self.photoBrowser presentFromImageView:self.avatarView toContainer:self.view.window animated:animate completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showEditView];
    });
}

- (UIView *)firstSectionHeader
{
    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);

    UIView *firstSectionHeader = [UIView new];
    firstSectionHeader.userInteractionEnabled = YES;
    [firstSectionHeader
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerWasTapped:)]];
    firstSectionHeader.backgroundColor = Theme.tableCellBackgroundColor;
    UIView *threadInfoView = [UIView new];
    [firstSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

//    DTAvatarImageView *avatarView = [DTAvatarImageView new];
//    _avatarView = avatarView;

//    [threadInfoView addSubview:avatarView];
//    [avatarView autoVCenterInSuperview];
//    [avatarView autoPinLeadingToSuperviewMargin];
//    [avatarView autoSetDimension:ALDimensionWidth toSize:kAvatarSize];
//    [avatarView autoSetDimension:ALDimensionHeight toSize:kAvatarSize];
//    _groupAvatar = self.thread.groupModel.groupImage;
//    [self updateAvatarView];

    TTPaddedTextField *groupNameTextField = [[TTPaddedTextField alloc] init];
    _groupNameTextField = groupNameTextField;
    self.groupNameTextField.text = [self.thread.groupModel.groupName ows_stripped];
    groupNameTextField.textColor = Theme.primaryTextColor;
    groupNameTextField.font = [UIFont ows_dynamicTypeTitle2Font];
    groupNameTextField.borderStyle = UITextBorderStyleNone;
    groupNameTextField.layer.borderWidth = 1.0;
    groupNameTextField.layer.borderColor = (Theme.isDarkThemeEnabled ? [UIColor colorWithRgbHex:0x474D57].CGColor : [UIColor colorWithRgbHex:0xEAECEF].CGColor);
    groupNameTextField.layer.cornerRadius = 4.0;
    [groupNameTextField setTextPaddingWithTop:12 left:16 bottom:12 right:16];
    groupNameTextField.placeholder
        = Localized(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"Placeholder text for group name field");
    groupNameTextField.delegate = self;
    [groupNameTextField addTarget:self
                           action:@selector(groupNameDidChange:)
                 forControlEvents:UIControlEventEditingChanged];
    [threadInfoView addSubview:groupNameTextField];
    [groupNameTextField autoVCenterInSuperview];
    [groupNameTextField autoPinTrailingToSuperviewMargin];
    [groupNameTextField autoPinLeadingToSuperviewMargin];

//    if(self.mode == UpdateGroupMode_EditGroupAvatar){
//        [avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTouched:)]];
//        avatarView.userInteractionEnabled = YES;
//        groupNameTextField.userInteractionEnabled = NO;
//    }

    return firstSectionHeader;
}

- (void)headerWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        self.mode = UpdateGroupMode_EditGroupName;
        [self.groupNameTextField becomeFirstResponder];
    }
}

//- (void)avatarTouched:(UIGestureRecognizer *)sender
//{
//    if (sender.state == UIGestureRecognizerStateRecognized) {
//        self.mode = UpdateGroupMode_EditGroupAvatar;
//        [self.groupNameTextField endEditing:YES];
//        NSString *localNumber = self.contactsViewHelper.localNumber;
//        if([self.thread.groupModel.groupOwner isEqualToString:localNumber] ||
//           [self.thread.groupModel.groupAdmin containsObject:localNumber]){
//            [self showAvatarBrowserViewAnimate:true];
//            [self showChangeAvatarUI];
//        }
//    }
//}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSAssertDebug(self.thread);
    
    if (self.mode != UpdateGroupMode_RemoveGroupMembers) {
        return;
    }

    OWSTableContents *contents = [OWSTableContents new];
    ContactsViewHelper *contactsViewHelper = self.contactsViewHelper;

    // Group Members

    OWSTableSection *section = [OWSTableSection new];
    section.headerTitle = Localized(
        @"EDIT_GROUP_MEMBERS_SECTION_TITLE", @"a title for the members section of the 'new/update group' view.");
    section.customFooterHeight = @20;
    //memberRecipientIds use to show，self.memberRecipientIds use to calculate
    NSMutableArray <NSString *> *memberRecipientIds = [self.sortedMemberRecipientIds mutableCopy];
    NSString *localNumber = [TSAccountManager localNumber];
    if (DTParamsUtils.validateString(localNumber)){
        [memberRecipientIds removeObject:self.thread.groupModel.groupOwner];
        [memberRecipientIds removeObject:localNumber];
        /// 如果不是群主就不可以移除群协调人
        if (![localNumber isEqualToString:self.thread.groupModel.groupOwner]) {
            for (NSString *memberId in self.thread.groupModel.groupAdmin) {
                if ([memberRecipientIds containsObject:memberId]) {
                    [memberRecipientIds removeObject:memberId];
                }
            }
        }
    }
        
    @weakify(self)
    NSSet <NSString *> *newMemberIds = [NSSet setWithArray:self.sortedMemberRecipientIds];
    self.hasUnsavedChanges = ![newMemberIds isEqualToSet:self.handledMemberRecipientIds];
    for (NSString *recipientId in memberRecipientIds) {
        [section
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            @strongify(self)
                            ContactTableViewCell *cell = [ContactTableViewCell new];
                            if(self.mode == UpdateGroupMode_RemoveGroupMembers){
                                if(![self.handledMemberRecipientIds containsObject:recipientId]) {
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
                                // In the "members" section, we label "new" members as such when editing an existing
                                // group.
                                //
                                // The only way a "new" member could be blocked is if we blocked them on a linked device
                                // while in this dialog.  We don't need to worry about that edge case.
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
                                        if([self.handledMemberRecipientIds containsObject:recipientId]){
                                            [self removeRecipientId:recipientId];
                                        }else{
                                            [self addRecipientId:recipientId];
                                        }
                                    }
                                }
                                
                            } else {
                                [self removeRecipientId:recipientId];
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
    [self updateTableContents];
}

- (void)addRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.handledMemberRecipientIds addObject:recipientId];
    [self updateTableContents];
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
            [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:serverGId
                                                     updateInfo:@{@"name" : newGroupName}
                                                        success:^(DTAPIMetaEntity * _Nonnull entity) {
                [SVProgressHUD dismiss];
                TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:groupModel];
                newGroupModel.groupName = newGroupName;
                NSString *updateGroupInfo = [DTGroupUtils getBaseInfoStringWithOldGroupModel:self.thread.groupModel
                                                                                    newModel:newGroupModel
                                                                                      source:self.contactsViewHelper.localNumber
                                                                   shouldAffectThreadSorting:&tmpShouldAffectSorting];
                nextBlock(newGroupModel, updateGroupInfo, YES);
            } failure:^(NSError * _Nonnull error) {
                [SVProgressHUD dismiss];
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
            }];
        }
    } else if (self.mode == UpdateGroupMode_RemoveGroupMembers){
        if(newMembers.count < oldMembers.count){
            
            if (!groupModel.isSelfGroupOwner && !groupModel.isSelfGroupModerator && !groupModel.anyoneRemove) {
                [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
                return;
            }
            
            [SVProgressHUD show];
            
            NSMutableSet <NSString *> *membersWhoRemoved = [NSMutableSet setWithSet:oldMembers];
            [membersWhoRemoved minusSet:newMembers];
            
            void(^successBlock)(void) = ^{
                TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:groupModel];
                newGroupModel.groupMemberIds = self.handledMemberRecipientIds.allObjects;
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
                
                //MARK: 移除成员预约会议相关逻辑
                [DTCalendarManager.shared groupChangeWithGid:self.thread.serverThreadId
                                                  actionCode:4
                                                      target:membersWhoRemoved.allObjects];
                
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
    } else if (self.mode == UpdateGroupMode_EditGroupAvatar) {
        
        if (!groupModel.isSelfGroupOwner &&
           !groupModel.isSelfGroupModerator) {
            [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
            return;
        }
        
        [SVProgressHUD show];
        
        NSData *data = UIImagePNGRepresentation(self.groupAvatar);
        id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:data fileExtension:@"png"];
        [self.groupAvatarUpdateProcessor updateWithAttachment:dataSource
                                                  contentType:OWSMimeTypeImagePng
                                               sourceFilename:nil
                                                      success:^(DTAPIMetaEntity * _Nonnull entity) {
            [SVProgressHUD dismiss];
            TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:groupModel];
            newGroupModel.groupImage = self.groupAvatar;
            NSString *updateGroupInfo = [DTGroupUtils getBaseInfoStringWithOldGroupModel:self.thread.groupModel
                                                                                newModel:newGroupModel
                                                                                  source:self.contactsViewHelper.localNumber
                                                               shouldAffectThreadSorting:&tmpShouldAffectSorting];
            nextBlock(newGroupModel, updateGroupInfo, NO);
            [self.thread fireAvatarChangedNotification];
            
        } failure:^(NSError * _Nonnull error) {
            [SVProgressHUD dismiss];
            if(DTParamsUtils.validateString(error.localizedDescription)){
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
            }
        }];
    }
    
}

#pragma mark - Group Avatar

//- (void)showChangeAvatarUI
//{
//    [self.groupNameTextField resignFirstResponder];
//
//    [self.avatarViewHelper showChangeAvatarUI];
//}
//
//- (void)setGroupAvatar:(nullable UIImage *)groupAvatar
//{
//    OWSAssertIsOnMainThread();
//
//    _groupAvatar = groupAvatar;
//
//    self.hasUnsavedChanges = YES;
//
//    [self updateAvatarView];
//    if (self.mode == UpdateGroupMode_EditGroupAvatar){
//        [self.photoBrowser updateCurrentImage:groupAvatar];
//    }
//}
//
//- (void)updateAvatarView
//{
//    self.avatarView.image = (self.groupAvatar ?: [UIImage imageNamed:@"empty-group-avatar"]);
//}

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

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    [self.groupNameTextField resignFirstResponder];
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
    BOOL result = self.hasUnsavedChanges;
    if (result) {
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
        self.handledMemberRecipientIds = [NSMutableSet setWithArray:tmpSortedMemberRecipientIds.copy];

        [self updateTableContents];
    }];
}

@end

NS_ASSUME_NONNULL_END
