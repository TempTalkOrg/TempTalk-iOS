//
//  DTCallInviteMemberVC.m
//  Signal
//
//  Created by Felix on 2021/9/13.
//


#import "DTCallInviteMemberVC.h"
#import "AddToGroupViewController.h"
#import "TempTalk-Swift.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSTableViewController.h>
#import <TTMessaging/UIUtil.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIViewController+OWS.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import "DTCallModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTCallInviteMemberVC () <UIImagePickerControllerDelegate,
    UITextFieldDelegate,
    ContactsViewHelperDelegate,
    AddToGroupViewControllerDelegate,
    OWSTableViewControllerDelegate,
    UINavigationControllerDelegate,
    OWSNavigationChildController>

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
@property (nonatomic, readonly) UILabel *lbHeaderTitle;
@property (nonatomic, readonly) UIView *firstSection;
@property (nonatomic, readonly) UITextField *instantMeetingNameTextField;

@property (nonatomic, nullable) NSSet<NSString *> *previousMemberRecipientIds;
@property (nonatomic) NSMutableSet<NSString *> *memberRecipientIds;

@property (nonatomic) BOOL hasUnsavedChanges;

@end

#pragma mark -

@implementation DTCallInviteMemberVC

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
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

    self.memberRecipientIds = [NSMutableSet new];
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];

    self.view.backgroundColor = Theme.backgroundColor;
    
    self.title = Localized(@"CALL_INVITE_MEMBERS_TITLE", @"The navbar title for the 'invite group' view.");
    
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                  target:self
                                                  action:@selector(dismissPressed)];
    
    UIView *firstSection = [self firstSectionHeader];
    [self.view addSubview:firstSection];
    [firstSection autoSetDimension:ALDimensionHeight toSize:28+16*2];
    [firstSection autoPinWidthToSuperview];
    [firstSection autoPinEdgeToSuperviewSafeArea:ALEdgeTop];

    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    if (self.inviteType == CallInviteTypeInstantMeeting) {
        [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstSection];

    } else {
        [_tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    }
    [self autoPinViewToBottomOfViewControllerOrKeyboard:self.tableViewController.view avoidNotch:false];
    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableViewController.tableView.estimatedRowHeight = 70;

    [self updateTableContents];
}

- (void)applyTheme {
    [super applyTheme];
    
    self.firstSection.backgroundColor = Theme.tableSettingCellBackgroundColor;
    self.instantMeetingNameTextField.textColor = Theme.primaryTextColor;
    self.lbHeaderTitle.textColor = Theme.primaryTextColor;
    
    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateNormal];
    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateHighlighted];
    
    if (self.view.window.windowLevel == UIWindowLevel_CallView()) {
        [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.primaryTextColor}];
        self.navigationController.navigationBar.tintColor = Theme.primaryTextColor;
    }
}

- (UIView *)firstSectionHeader {
    UIView *firstSectionHeader = [UIView new];
    _firstSection = firstSectionHeader;
    firstSectionHeader.backgroundColor = Theme.tableSettingCellBackgroundColor;
//    Theme.tableCellBackgroundColor;
    UIView *threadInfoView = [UIView new];
    [firstSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

    UITextField *instantMeetingNameTextField = [UITextField new];
    _instantMeetingNameTextField = instantMeetingNameTextField;
    instantMeetingNameTextField.textColor = Theme.primaryTextColor;
    instantMeetingNameTextField.font = [UIFont ows_dynamicTypeTitle2Font];
    instantMeetingNameTextField.placeholder
        = Localized(@"CALL_INVITE_INSTANT_MEETING_NAME_PLACEHOLDER", @"Placeholder text for instant meeting field");
    
    __block NSString *selfName = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        selfName = [OWSProfileManager.sharedManager localProfileNameWithTransaction:transaction];
    }];
    if (selfName) {
        instantMeetingNameTextField.text = [NSString stringWithFormat:@"%@ meeting", selfName];
    }
    instantMeetingNameTextField.delegate = self;
    [threadInfoView addSubview:instantMeetingNameTextField];
    [instantMeetingNameTextField autoPinEdgesToSuperviewEdges];

    return firstSectionHeader;
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
    _hasUnsavedChanges = hasUnsavedChanges;

    [self updateNavigationBar];
}

- (void)updateNavigationBar
{
    UIBarButtonItem *rightItem = nil;
    if (self.hasUnsavedChanges && self.memberRecipientIds.count > 0) {
        
        NSString *itemTitle = Localized(@"CALL_INVITE_MEMBERS", @"The title for the 'Invite' button.");
        if (self.inviteType == CallInviteTypeInstantMeeting) {
            
            itemTitle = Localized(@"CALL_INVITE_INSTANT_MEETING_START", @"The title for the 'Start' button.");
        }
        
        rightItem = [[UIBarButtonItem alloc] initWithTitle:itemTitle
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(inviteMeetingBtnPressed)];
        [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateNormal];
        [rightItem setTitleTextAttributes:@{NSForegroundColorAttributeName : Theme.themeBlueColor} forState:UIControlStateHighlighted];
    }
    
    self.navigationItem.rightBarButtonItem = rightItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO animated:NO];
    
    if (self.inviteType == CallInviteTypeInstantMeeting) {
        
        self.title = Localized(@"CALL_INVITE_INSTANT_MEETING_TITLE", @"The create instant meeting vc title.");
    } else {
        
        self.title = Localized(@"CALL_INVITE_MEMBERS_TITLE", @"The create instant meeting vc title.");
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.inviteType == CallInviteTypeInstantMeeting) {
        [self.instantMeetingNameTextField becomeFirstResponder];
    }
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    ContactsViewHelper *contactsViewHelper = self.contactsViewHelper;

    // Group Members
    @weakify(self)
    OWSTableSection *section = [OWSTableSection new];
//    section.headerTitle = Localized(
//        @"EDIT_GROUP_MEMBERS_SECTION_TITLE", @"a title for the members section of the 'new/update group' view.");
    section.customHeaderView = ({
        UIView *header = UIView.new;
        UILabel *lbHeaderTitle = UILabel.new;
        _lbHeaderTitle = lbHeaderTitle;
        lbHeaderTitle.text = Localized(@"EDIT_GROUP_MEMBERS_SECTION_TITLE", @"a title for the members section of the 'new/update group' view.");
        lbHeaderTitle.textColor = Theme.primaryTextColor;
        lbHeaderTitle.font = [UIFont systemFontOfSize:13];
        [header addSubview:lbHeaderTitle];
        
        [lbHeaderTitle autoVCenterInSuperview];
        [lbHeaderTitle autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:16];
        
        header;
    });
    section.customHeaderHeight = @44;

    [section addItem:[OWSTableItem
                         disclosureItemWithText:Localized(@"EDIT_GROUP_MEMBERS_ADD_MEMBER",
                                                    @"Label for the cell that lets you add a new member to a group.")
                                customRowHeight:UITableViewAutomaticDimension
                                    actionBlock:^{
                                        @strongify(self)
                                        AddToGroupViewController *viewController = [AddToGroupViewController new];
                                        viewController.thread = (TSGroupThread *)self.thread;
                                        viewController.addToGroupDelegate = self;
                                        viewController.mode = AddToGroupMode_DataBack;
                                        viewController.from = SelectRecipientFrom_Meeting;
                                        [self.navigationController pushViewController:viewController animated:YES];
                                    }]];

    NSMutableSet *memberRecipientIds = [self.memberRecipientIds mutableCopy];
    [memberRecipientIds removeObject:[contactsViewHelper localNumber]];
    for (NSString *recipientId in [memberRecipientIds.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
        [section
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            @strongify(self)
                            ContactTableViewCell *cell = [ContactTableViewCell new];
                            SignalAccount *signalAccount = [contactsViewHelper signalAccountForRecipientId:recipientId];
                            BOOL isPreviousMember = [self.previousMemberRecipientIds containsObject:recipientId];
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
//                                cell.accessoryMessage = Localized(@"EDIT_GROUP_NEW_MEMBER_LABEL",
//                                    @"An indicator that a user is a new member of the group.");
                                cell.cellView.userInteractionEnabled = YES;

                                UIButton *btnDelete = [UIButton buttonWithType:UIButtonTypeCustom];
                                btnDelete.accessibilityLabel = recipientId;
                                UIImage *icon = [[UIImage imageNamed:@"ic_calendar_minus"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                                [btnDelete setImage:icon forState:UIControlStateNormal];
                                [btnDelete setImage:icon forState:UIControlStateHighlighted];
                                btnDelete.imageView.tintColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x474D57];
                                [btnDelete addTarget:self action:@selector(btnDeleteAction:) forControlEvents:UIControlEventTouchUpInside];
                                [btnDelete autoSetDimensionsToSize:CGSizeMake(40, 40)];
                                [cell ows_setAccessoryView:btnDelete];
                            }

                            if (signalAccount) {
                                [cell configureWithSignalAccount:signalAccount
                                                 contactsManager:contactsViewHelper.contactsManager];
                            } else {
                                [cell configureWithRecipientId:recipientId
                                               contactsManager:contactsViewHelper.contactsManager];
                            }

                            return cell;
                        }
                        customRowHeight:70
                        actionBlock:nil]];
    }
    [contents addSection:section];

    self.tableViewController.contents = contents;
}

- (void)btnDeleteAction:(UIButton *)sender {
    
    NSString *recipientId = sender.accessibilityLabel;
    SignalAccount *signalAccount = [self.contactsViewHelper signalAccountForRecipientId:recipientId];
    BOOL isPreviousMember = [self.previousMemberRecipientIds containsObject:recipientId];
    BOOL isBlocked = [self.contactsViewHelper isRecipientIdBlocked:recipientId];
    if (isPreviousMember) {
        if (isBlocked) {
            if (signalAccount) {
                [self showUnblockAlertForSignalAccount:signalAccount];
            } else {
                [self showUnblockAlertForRecipientId:recipientId];
            }
        } else {
            [OWSAlerts
                showAlertWithTitle:
                    Localized(@"UPDATE_GROUP_CANT_REMOVE_MEMBERS_ALERT_TITLE",
                        @"Title for alert indicating that group members can't be removed.")
                           message:Localized(
                                       @"UPDATE_GROUP_CANT_REMOVE_MEMBERS_ALERT_MESSAGE",
                                       @"Title for alert indicating that group members can't "
                                       @"be removed.")];
        }
    } else {
        [self removeRecipientId:recipientId];
    }
}

- (void)showUnblockAlertForSignalAccount:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);

    @weakify(self);
    [BlockListUIUtils showUnblockSignalAccountActionSheet:signalAccount
                                       fromViewController:self
                                          blockingManager:self.contactsViewHelper.blockingManager
                                          contactsManager:self.contactsViewHelper.contactsManager
                                          completionBlock:^(BOOL isBlocked) {
                                              @strongify(self);
                                              if (!isBlocked) {
                                                  [self updateTableContents];
                                              }
                                          }];
}

- (void)showUnblockAlertForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    @weakify(self);
    [BlockListUIUtils showUnblockPhoneNumberActionSheet:recipientId
                                     fromViewController:self
                                        blockingManager:self.contactsViewHelper.blockingManager
                                        contactsManager:self.contactsViewHelper.contactsManager
                                        completionBlock:^(BOOL isBlocked) {
                                            @strongify(self);
                                            if (!isBlocked) {
                                                [self updateTableContents];
                                            }
                                        }];
}

- (void)removeRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [self.memberRecipientIds removeObject:recipientId];
    [self updateNavigationBar];
    [self updateTableContents];
}

#pragma mark - Methods

- (void)dismissPressed {
    
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)inviteToAMeeting {
    //给邀请人发送邀请信息
    [DTMeetingManager.shared inviteUsersToCall:self.memberRecipientIds.allObjects];
    
    [self dismissPressed];
}

- (NSString *)nameSelf {
    
    if (![TSAccountManager localNumber]) {
        return @"";
    }
    return [Environment.shared.contactsManager displayNameForPhoneIdentifier:[TSAccountManager localNumber]];
}

#pragma mark - Event Handling
- (void)inviteMeetingBtnPressed
{
    [self inviteToAMeeting];
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

- (UIViewController *)fromViewController
{
    return self;
}

- (BOOL)hasClearAvatarAction
{
    return NO;
}

#pragma mark - AddToGroupViewControllerDelegate

- (void)recipientIdsWasAdded:(NSSet *)recipientIds
{
    if (recipientIds.count) {
        [self.memberRecipientIds unionSet:recipientIds];
        self.hasUnsavedChanges = YES;
        [self updateTableContents];
    }
}

- (BOOL)isRecipientGroupMember:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);
    
    if (self.isLiveKitCall) {
        NSArray <NSString *> *allParticipantIds = [DTMeetingManager shared].allParticipantIds;
        
        return [allParticipantIds containsObject:recipientId];
    } else {
        return [self.memberRecipientIds containsObject:recipientId];
    }
    
    return NO;
}

- (BOOL)canMeetingMemberBeSelected:(NSString *)recipientId {
    __block BOOL result = YES;
    
    DTMeetingEntity *entity = [DTMeetingConfig fetchMeetingConfig];
    NSArray<NSString *> *meetingInviteForbids = entity.meetingInviteForbid;
    [meetingInviteForbids enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([recipientId hasSuffix:obj]) {
            result = NO;
            *stop = YES;
        }
    }];
    
    return result;
}

- (BOOL)checkShouldToastCannnotBeSelected:(NSString *)recipientId {
    BOOL result = [self canMeetingMemberBeSelected:recipientId];
    
    if (!result) {
        [DTToastHelper toastWithText:@"You are not authorized to invite this user." durationTime:1];
    }
    
    return result;
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    if ([self.instantMeetingNameTextField canResignFirstResponder]) {
        [self.instantMeetingNameTextField resignFirstResponder];
    }
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack
{
    BOOL result = self.hasUnsavedChanges && self.memberRecipientIds.count > 0;

    return !result;
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

@end

NS_ASSUME_NONNULL_END

