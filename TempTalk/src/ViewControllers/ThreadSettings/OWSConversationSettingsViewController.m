//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSConversationSettingsViewController.h"
#import "BlockListUIUtils.h"
#import "ContactsViewHelper.h"
#import "ContactEditingViewController.h"
#import "FingerprintViewController.h"
#import "OWSBlockingManager.h"
#import "OWSSoundSettingsViewController.h"

#import "ShowGroupMembersViewController.h"
#import "TempTalk-Swift.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import "UpdateGroupViewController.h"
#import "AddToGroupViewController.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSAvatarBuilder.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSProfileManager.h>
#import <TTMessaging/OWSSounds.h>
//#import <TTMessaging/OWSUserProfile.h>
#import <TTMessaging/UIUtil.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/DTConversationConfig.h>
#import "DTRemoveMembersOfAGroupAPI.h"
#import "SVProgressHUD.h"
#import "DTChangeYourSettingsInAGroupAPI.h"
#import "DTDismissAGroupAPI.h"
#import <TTServiceKit/DTToastHelper.h>
#import "DTGroupNoticeSettingController.h"
#import "DTGroupMangerViewController.h"
#import "DTGroupTranslateSettingController.h"
#import "DTInviteToGroupAPI.h"
#import "OWSConversationSettingsViewController+ConversationFeature.h"
#import "DTImageBrowserView.h"
#import "DTArchiveMessageSettingController.h"
#import "NewGroupViewController.h"
#import <TTServiceKit/TTServiceKit-swift.h>
#import "DTGroupSettingChangedProcessor.h"
#import "DTCommonGroupContext.h"
#import "DTConversationSettingHelper.h"

extern const NSTimeInterval kDayInterval;
CGFloat const kAvatarSize = 68;
@import ContactsUI;

NS_ASSUME_NONNULL_BEGIN

const CGFloat kIconViewLength = 24;

@interface OWSConversationSettingsViewController () <ContactEditingDelegate,
    ContactsViewHelperDelegate, AddToGroupViewControllerDelegate>

@property (nonatomic) TSThread *thread;

@property (nonatomic) NSArray<NSNumber *> *disappearingMessagesDurations;
@property (nonatomic) OWSDisappearingMessagesConfiguration *disappearingMessagesConfiguration;
@property (nullable, nonatomic) MediaGalleryViewController *mediaGalleryViewController;
@property (nonatomic, readonly) TSAccountManager *accountManager;
@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) OWSBlockingManager *blockingManager;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) UILabel *disappearingMessagesDurationLabel;
@property (nonatomic, readwrite) DTAvatarImageView *avatarView;
@property (nonatomic, strong) UIButton *leaveOrDeleteBtn;

@property (nonatomic, strong) DTChangeYourSettingsInAGroupAPI *changeYourSettingsInAGroupAPI;
@property (nonatomic, strong) DTGroupSettingChangedProcessor *groupSettingChangedProcessor;

@property (nonatomic, copy) NSString *serverGid;
@property (nonatomic, strong) UISwitch *mutedSwitch;
@property (nonatomic, strong) UISwitch *blockSwitch;
@property (nonatomic, strong) DTDisappearanceTimeIntervalEntity *disappearanceTimeIntervalEntity;

@property (nonatomic, assign) BOOL isEmergencyContact;

@property (nonatomic, strong) NSArray <NSString *> *sortedGroupMemberIds;

@property (nonatomic, strong) DTCommonGroupContext *commonGroupContext;

@end

#pragma mark -

@implementation OWSConversationSettingsViewController

- (NSString *)serverGid {
    
    if (!_serverGid) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        _serverGid = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    }
    
    return _serverGid;
}

- (DTChangeYourSettingsInAGroupAPI *)changeYourSettingsInAGroupAPI{
    if(!_changeYourSettingsInAGroupAPI){
        _changeYourSettingsInAGroupAPI = [DTChangeYourSettingsInAGroupAPI new];
    }
    return _changeYourSettingsInAGroupAPI;
}

- (DTGroupSettingChangedProcessor *)groupSettingChangedProcessor{
    if(!_groupSettingChangedProcessor){
        _groupSettingChangedProcessor = [[DTGroupSettingChangedProcessor alloc] initWithGroupThread:(TSGroupThread *)self.thread];
    }
    return _groupSettingChangedProcessor;
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
    _accountManager = [TSAccountManager sharedInstance];
    _contactsManager = Environment.shared.contactsManager;
    _messageSender = Environment.shared.messageSender;
    _blockingManager = [OWSBlockingManager sharedManager];
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];

    [self observeNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DTGroupMessageExpiryConfigChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationName_OtherUsersProfileDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversationSettingDidChange:)
                                                 name:kConversationUpdateFromSocketMessageNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageExpiryConfigChanged:)
                                                 name:DTGroupMessageExpiryConfigChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(groupReminderCycleChanged:)
                                                 name:DTGroupPeriodicRemindNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageExpiryConfigChanged:)
                                                 name:DTConversationSharingConfigurationChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversationBlockUserDidChange:)
                                                 name:@"kConversationDidChangeNotification"
                                               object:nil];

}

- (BOOL)isGroupThread
{
    return self.thread.isGroupThread;
}

- (void)configureWithThread:(TSThread *)thread
{
    OWSAssertDebug(thread);
    self.thread = thread;
}

- (void)refreshTitle {
    if ([self.thread isKindOfClass:[TSContactThread class]]) {
        self.title = [self.contactsManager displayNameForPhoneIdentifier:self.thread.contactIdentifier];
    } else {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        NSString *groupName = groupThread.groupModel.groupName;
        NSUInteger groupMemberCount = groupThread.groupModel.groupMemberIds.count;
        self.title = [groupName stringByAppendingFormat:@"(%ld)", groupMemberCount];
    }
}

- (void)updateEditButton
{
    OWSAssertDebug(self.thread);
    
    if (![self isGroupThread]
        && self.hasExistingContact
        && !self.isLocalNumber) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:Localized(@"EDIT_TXT", nil)
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(didTapEditButton)];
    }
}

- (BOOL)isLocalNumber
{
    OWSAssertDebug(self.thread);
    
    return self.thread.isNoteToSelf;
}

- (BOOL)hasExistingContact
{
    OWSAssertDebug([self.thread isKindOfClass:[TSContactThread class]]);
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    NSString *recipientId = contactThread.contactIdentifier;
    return [self.contactsManager hasSignalAccountForRecipientId:recipientId];
}

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    [self updateTableContents];

    DDLogDebug(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.disappearanceTimeIntervalEntity = [DTDisappearanceTimeIntervalConfig fetchDisappearanceTimeInterval];
    self.tableView.estimatedRowHeight = 45;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _disappearingMessagesDurationLabel = [UILabel new];
    self.disappearingMessagesDurations = [OWSDisappearingMessagesConfiguration validDurationsSeconds];

    self.sortedGroupMemberIds = @[];
    
    if (self.thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        if (groupThread.groupModel.isSelfGroupOwner || groupThread.groupModel.isSelfGroupModerator) {
            @weakify(self)
            [[DTServerConfigManager sharedManager] fetchConfigFromServerCompletion:^{
                @strongify(self)
                [self updateTableContents];
            }];
        }
        [self reloadHeader];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(personalGroupConfigChangedNotification:)
                                                     name:DTPersonalGroupConfigChangedNotification
                                                   object:nil];
    } else {
        self.sortedGroupMemberIds = @[self.thread.contactIdentifier];
    }
    
    if (!self.thread.isGroupThread) {
        @weakify(self);
        self.commonGroupContext = [[DTCommonGroupContext alloc] initWithContactThread:(TSContactThread *)self.thread completion:^{
            @strongify(self);
            [self updateTableContents];
        }];
        [self.commonGroupContext fetchInCommonGroupsData];
    }
    
    [self updateTableContents];    
}

- (void)reloadHeader {
    @weakify(self);
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        @strongify(self);
        TSThread *thread = [TSThread anyFetchWithUniqueId:self.thread.uniqueId transaction:transaction];
        self.thread = thread;
        self.sortedGroupMemberIds = [DTCommonGroupContext sortedGroupMemberIdsWithGroup:(TSGroupThread *)thread transaction:transaction];
    } completion:^{
        @strongify(self);
        [self updateTableContents];
        if (self.thread.isGroupThread) {
            TSGroupThread *groupThread = (TSGroupThread *)self.thread;
            NSString *groupName = groupThread.groupModel.groupName;
            NSUInteger groupMemberCount = groupThread.groupModel.groupMemberIds.count;
            self.title = [groupName stringByAppendingFormat:@"(%ld)", groupMemberCount];
        }
    }];
}

- (void)messageExpiryConfigChanged:(NSNotification *)notify {
    [self updateTableContents];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.showVerificationOnAppear) {
        self.showVerificationOnAppear = NO;
        if (self.isGroupThread) {
            [self showGroupMembersView];
        } else {
            [self showVerificationView];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)applyTheme {
    
    [super applyTheme];
    [self updateTableContents];
}

- (void)personalGroupConfigChangedNotification:(NSNotification *)notification
{
    @weakify(self)
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        @strongify(self)
        self.thread = [TSGroupThread threadWithGroupId:((TSGroupThread *)self.thread).groupModel.groupId transaction:transaction];
    } completion:^{
        @strongify(self)
        [self updateTableContents];
    }];
}

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];
    contents.title = Localized(@"CONVERSATION_SETTINGS", @"title for conversation settings screen");

    @weakify(self);

    // Main section.

    OWSTableSection *mainSection = [OWSTableSection new];

    mainSection.customHeaderView = [self mainSectionHeader];
    if (!self.isGroupThread) {
        mainSection.customHeaderHeight =  @(114.f);
    } else {
        NSUInteger memberCount = self.sortedGroupMemberIds.count;
        if (memberCount < 4) {
            mainSection.customHeaderHeight = @(146.f);
        } else {
            if (memberCount == 4 || memberCount == 5) {
                mainSection.customHeaderHeight = @(208.f);
            } else {
                mainSection.customHeaderHeight = @(228.f);
            }
        }
    }
    [mainSection addItem:self.blankItem];

    [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self);
        return [self disclosureCellWithName:MediaStrings.allMedia iconName:@"actionsheet_camera_roll_black"];
    } actionBlock:^{
        @strongify(self);
        [self showMediaGallery];
    }]];
    
    [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self);
        return [self disclosureCellWithName:Localized(@"CONVERSATION_SETTINGS_SEARCH_HISTORY", @"table cell label in conversation settings") iconName:@"table_ic_search_history"];
    }
                                                   actionBlock:^{
        @strongify(self);
        DTSearchMessageListController *searchResultsController = [DTSearchMessageListController new];
        searchResultsController.currentThread = self.thread;
        searchResultsController.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:searchResultsController animated:YES];
    }]];
    [mainSection addItem:self.blankItem];
    
    [contents addSection:mainSection];

    //MARK: group in common
    if (!self.thread.isGroupThread && !self.isLocalNumber) {
        OWSTableSection *groupInCommonSection = [OWSTableSection new];
        [groupInCommonSection addItem:self.groupInCommonItem];
        [groupInCommonSection addItem:self.blankItem];
        [contents addSection:groupInCommonSection];
    }
    
    // Group settings section.
    if (self.isGroupThread) { // 管理群聊 section
        
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        NSMutableArray *mGroupItems = @[].mutableCopy;
        
        //群主展示群管理的配置项
        if (groupThread.groupModel.isSelfGroupOwner) {
            OWSTableItem *mangeGroupItem = [OWSTableItem itemWithCustomCellBlock:^{
                @strongify(self);
                return [self disclosureCellWithName:Localized(@"LIST_GROUP_MEMBERS_MANAGER",
                                                            @"table cell label in conversation settings")
                                               iconName:@"table_ic_group_members"];
            } actionBlock:^ {
                @strongify(self);
                [self showGroupManagement];
            }];
            
            [mGroupItems addObject:mangeGroupItem];
        }
        
        OWSTableItem *editGroupInfoItem = [OWSTableItem itemWithCustomCellBlock:^{
            @strongify(self);
            return [self disclosureCellWithName:Localized(@"EDIT_GROUP_DEFAULT_TITLE",
                                                                      @"table cell label in conversation settings")
                                           iconName:@"table_ic_group_members"];
        } actionBlock:^ {
            @strongify(self);
            [self toEditGroupInfo];
        }];
        
        [mGroupItems addObject:editGroupInfoItem];
        
        [mGroupItems addObject:self.blankItem];
        
        OWSTableSection *groupManagementSection = [OWSTableSection new];
        [groupManagementSection addTableItems:mGroupItems.copy];

        [contents addSection:groupManagementSection];
    }
    
    OWSTableSection *otherSection = [OWSTableSection new];
    
    [otherSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self);
        UITableViewCell *cell = [self disclosureCellWithName:Localized(@"CONVERSATION_SETTINGS_STICKY_ON_TOP", @"table cell label in conversation settings") iconName:@"table_ic_conversation_top"];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *stickSwitch = [UISwitch new];
        stickSwitch.on = self.thread.isSticked;
        [stickSwitch addTarget:self
                        action:@selector(stickyOnTopDidChange:)
              forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = stickSwitch;
        return cell;
    }
                                                   actionBlock:nil]];
    
    if (!self.thread.isNoteToSelf) {
        [otherSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            @strongify(self);
            UITableViewCell *cell = [self disclosureCellWithName:Localized(@"CONVERSATION_SETTINGS_MUTE", @"table cell label in conversation settings") iconName:@"table_ic_mute_thread"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            self.mutedSwitch = [UISwitch new];
            self.mutedSwitch.on = self.thread.isMuted;
            [self.mutedSwitch addTarget:self
                                 action:@selector(mutedSwitchClick:)
                       forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = self.mutedSwitch;
            return cell;
        } actionBlock:nil]];
    }
    
#ifdef CONVERSATION_COLORS_ENABLED
    [otherSection addItem:[OWSTableItem
                             itemWithCustomCellBlock:^{
                                 NSString *colorName = weakSelf.thread.conversationColorName;
                                 UIColor *currentColor = [UIColor ows_conversationColorForColorName:colorName];
                                 NSString *title = Localized(@"CONVERSATION_SETTINGS_CONVERSATION_COLOR",
                                     @"Label for table cell which leads to picking a new conversation color");
                                 return [weakSelf disclosureCellWithName:title iconColor:currentColor];
                             }
                             actionBlock:^{
//                                 [weakSelf showColorPicker];
                             }]];
#endif
    
    if (!self.thread.isNoteToSelf) {
        [otherSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            @strongify(self);
            return [self disclosureCellWithName:Localized(@"SETTINGS_SECTION_TRANSLATE", @"table cell label in conversation settings")
                                       iconName:@"ic_inputbar_translate"];
        } actionBlock:^ {
            @strongify(self);
            [self showGroupTranslateSettingController];
        }]];
        
        [otherSection addItem:self.messageArchiveItem];
    }
    
    if (!self.isLocalNumber) {
        [otherSection
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            UITableViewCell *cell =
                                [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                            @strongify(self);
                            cell.preservesSuperviewLayoutMargins = YES;
                            cell.contentView.preservesSuperviewLayoutMargins = YES;
                            cell.accessoryView = self.accessoryArrow;
                            cell.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);

//                            UIImageView *iconView = [strongSelf viewForIconWithName:@"table_ic_notification_sound"];

                            UILabel *rowLabel = [UILabel new];
                            rowLabel.text = Localized(@"SETTINGS_ITEM_NOTIFICATION_SOUND_NM",
                                @"Label for settings view that allows user to change the notification sound.");
                            rowLabel.textColor = Theme.primaryTextColor;
                            rowLabel.font = self.primaryFont;
                            rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;

                            UIStackView *contentRow =
                                [[UIStackView alloc] initWithArrangedSubviews:@[ rowLabel ]];
                            contentRow.spacing = self.iconSpacing;
                            contentRow.alignment = UIStackViewAlignmentCenter;
                            [cell.contentView addSubview:contentRow];
                            [contentRow autoPinEdgesToSuperviewMargins];

                            OWSSound sound = [OWSSounds notificationSoundForThread:self.thread];
                            cell.detailTextLabel.font = self.primaryFont;
                            cell.detailTextLabel.text = [OWSSounds displayNameForSound:sound];
                            cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
                            cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
                            UIView *view = [UIView new];
                            view.backgroundColor = Theme.tableSettingCellBackgroundColor;
                            cell.selectedBackgroundView = view;
                            return cell;
                        }
                        customRowHeight:UITableViewAutomaticDimension
                        actionBlock:^{
                            @strongify(self);
                            OWSSoundSettingsViewController *vc = [OWSSoundSettingsViewController new];
                            vc.thread = self.thread;
                            [self.navigationController pushViewController:vc animated:YES];
                        }]];
        
        //群通知
        if (self.thread.isGroupThread) {
            TSGroupThread *groupThread = (TSGroupThread *)self.thread;
            TSGroupNotificationType notificationType = groupThread.groupModel.notificationType.integerValue;
            int useGlobal = groupThread.groupModel.useGlobal.intValue;
            
            [otherSection
                addItem:[OWSTableItem
                            itemWithCustomCellBlock:^{
                                UITableViewCell *cell =
                                    [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                                @strongify(self);
                                cell.preservesSuperviewLayoutMargins = YES;
                                cell.contentView.preservesSuperviewLayoutMargins = YES;
                                cell.accessoryView = self.accessoryArrow;

//                                UIImageView *iconView = [strongSelf viewForIconWithName:@"mute_icon"];

                                UILabel *rowLabel = [UILabel new];
                                rowLabel.text = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_NM", nil);
                                rowLabel.textColor = Theme.primaryTextColor;
                                rowLabel.font = self.primaryFont;
                                rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
                                NSString *notificationTypeString = nil;
                                if (useGlobal == 1) {//开启了全局通知
                                    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                                    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
                                    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
                                    Contact *contact = account.contact;
                                    if (contact && contact.privateConfigs) {
                                        NSNumber *globalNotification = contact.privateConfigs.globalNotification;
                                        if ([globalNotification intValue] == 0) {
                                            notificationTypeString = [NSString stringWithFormat:@"%@(%@)",Localized(@"SETTINGS_COMMON_GLOBAL", nil),Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE", nil)];
                                        }else if ([globalNotification intValue] == 1){
                                            notificationTypeString = [NSString stringWithFormat:@"%@(%@)",Localized(@"SETTINGS_COMMON_GLOBAL", nil),Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT", nil)];
                                        }else if ([globalNotification intValue] == 2){
                                            notificationTypeString = [NSString stringWithFormat:@"%@(%@)",Localized(@"SETTINGS_COMMON_GLOBAL", nil),Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF", nil)];
                                        }else {
                                            notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT", nil);
                                        }
                                    } else {
                                        OWSLogError(@"contact or contact.privateConfigs data error %@", contact.privateConfigs);
                                    }
                                } else {//未开启全局通知
                                    switch (notificationType) {
                                        case TSGroupNotificationTypeAll:
                                            notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE", nil);
                                            break;
                                        case TSGroupNotificationTypeAtMe:
                                            notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT", nil);
                                            break;
                                        case TSGroupNotificationTypeOff:
                                            notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF", nil);
                                            break;
                                        default:
                                            notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE", nil);
                                            break;
                                    }
                                }

                                UIStackView *contentRow =
                                    [[UIStackView alloc] initWithArrangedSubviews:@[ rowLabel ]];
                                contentRow.spacing = self.iconSpacing;
                                contentRow.alignment = UIStackViewAlignmentCenter;
                                [cell.contentView addSubview:contentRow];
                                [contentRow autoPinEdgesToSuperviewMargins];

                                cell.detailTextLabel.font = self.primaryFont;
                                cell.detailTextLabel.text = notificationTypeString;
                                cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
                                cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
                                UIView *view = [UIView new];
                                view.backgroundColor = Theme.tableSettingCellBackgroundColor;
                                cell.selectedBackgroundView = view;
                                return cell;
                            }
                            customRowHeight:UITableViewAutomaticDimension
                            actionBlock:^{
                @strongify(self);
                DTGroupNoticeSettingController *noticeSettingVC = [DTGroupNoticeSettingController new];
                [noticeSettingVC configureWithThread:self.thread];
                
                [self.navigationController pushViewController:noticeSettingVC animated:true];
            }]];
        }
    }
    
    [otherSection addItem:self.blankItem];
    [contents addSection:otherSection];
    
    if (self.thread.isGroupThread) {
        OWSTableSection *leaveGroupSection = [self addLeaveGroupSection];
        [contents addSection:leaveGroupSection];
    } else if (!self.thread.isNoteToSelf ) {
        OWSTableSection *deleteContactSection = [self deleteContactSection];
        if (deleteContactSection) {
            [contents addSection:deleteContactSection];
        }
    }
    
    self.contents = contents;
}

- (UIFont *)primaryFont {
    return [UIFont systemFontOfSize:16];
}

- (UIImageView *)accessoryArrow {
    UIImage *arrow = [[UIImage imageNamed:@"ic_accessory_arrow"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:arrow];
    arrowView.tintColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x474D57];
    
    return arrowView;
}

- (OWSTableItem *)blankItem {
    return [OWSTableItem blankItemWithcustomRowHeight:16.f];
}


- (BOOL)isGroupManger {
    if (!self.thread.isGroupThread) {return false;}
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
    return [groupThread.groupModel.groupOwner isEqualToString:localNumber] || [groupThread.groupModel.groupAdmin containsObject:localNumber];
}

- (void)mutedSwitchClick:(UISwitch *)switchBtn {
    NSString * conversationID = nil;
    NSNumber * muteStatus = nil;
    if (self.thread.isGroupThread) {
        conversationID = [TSGroupThread transformToServerGroupIdWithLocalGroupId: ((TSGroupThread  *)self.thread).groupModel.groupId];
    } else {
        TSContactThread *contactThread = (TSContactThread *)self.thread;
        conversationID = contactThread.serverThreadId;
    }
    muteStatus = switchBtn.on ? @(1) : @(0);
    [self requestConfigMuteStatusWithConversationID:conversationID
                                         muteStatus:muteStatus
                                            success:nil
                                            failure:^{
        switchBtn.on = !switchBtn.on;
        [DTToastHelper toastWithText:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",
                                                       @"config Mute statues failed") durationTime:3];
    }];
}

- (OWSTableItem *)messageArchiveItem {

    @weakify(self)
    return [OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self)
        UITableViewCell *cell =
        [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.preservesSuperviewLayoutMargins = YES;
        cell.contentView.preservesSuperviewLayoutMargins = YES;
        cell.accessoryView = self.accessoryArrow;
        cell.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);
        
        UILabel *rowLabel = [UILabel new];
        rowLabel.text = Localized(@"CONVERSATION_SETTINGS_ARCHIVE",
                                          @"Label for settings view that allows user to change the message archive.");
        rowLabel.textColor = Theme.primaryTextColor;
        rowLabel.font = self.primaryFont;
        rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        
        UIStackView *contentRow =
        [[UIStackView alloc] initWithArrangedSubviews:@[rowLabel]];
        contentRow.spacing = self.iconSpacing;
        contentRow.alignment = UIStackViewAlignmentCenter;
        [cell.contentView addSubview:contentRow];
        [contentRow autoPinEdgesToSuperviewMargins];
        
        __block uint32_t messageExpiry;
        __block NSString *tipmessage = nil;
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            TSThread *lastestThread = [TSThread anyFetchWithUniqueId:self.thread.uniqueId
                                                         transaction:transaction];
            messageExpiry = [lastestThread messageExpiresInSeconds];
        } completion:^{
            NSString *defaultString = @"";
            
            if ([self.thread isGroupThread] &&
                messageExpiry == [self.disappearanceTimeIntervalEntity.messageGroup floatValue]) {
                defaultString = Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DEFAULT",@"");
            } else if (![self.thread isGroupThread] && messageExpiry == [self.disappearanceTimeIntervalEntity.messageOthers floatValue]) {
                defaultString = Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DEFAULT",@"");
            }
           
            int minuteNum = (int)(messageExpiry/kMinuteInterval);
            int hourNum = (int)(messageExpiry/kHourInterval);
            int dayNum = (int)(messageExpiry/kDayInterval);
            if(minuteNum > 0 && hourNum == 0){
                NSString *minute = nil;
                if (minuteNum > 1) {
                    minute = [NSString stringWithFormat:@"%d%@", minuteNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_MINUTERS",@"")];
                } else {
                    minute = [NSString stringWithFormat:@"%d%@", minuteNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_MINUTER",@"")];
                }
               
                tipmessage = minute;
            }else {
                if(dayNum == 0 && hourNum > 0){
                    NSString *hours = nil;
                    if (hourNum > 1) {
                        hours = [NSString stringWithFormat:@"%d%@", hourNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_HOURS",@"")];
                    } else {
                        hours = [NSString stringWithFormat:@"%d%@", hourNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_HOUR",@"")];
                    }
                   
                    tipmessage = hours;
                } else {
                    NSString *days = nil;
                    if (dayNum > 1) {
                        days = [NSString stringWithFormat:@"%d%@", dayNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DAYS",@"")];
                    } else {
                        days = [NSString stringWithFormat:@"%d%@", dayNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DAY",@"")];
                    }
                    tipmessage = days;
                }
            }
            
            cell.detailTextLabel.font = self.primaryFont;
            if (defaultString.length) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)",defaultString,tipmessage];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",tipmessage];
            }
            
            cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
            cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
            UIView *view = [UIView new];
            view.backgroundColor = Theme.tableSettingCellBackgroundColor;
            cell.selectedBackgroundView = view;
        }];
        
        return cell;
    } actionBlock:^{
        @strongify(self)
        [self showArchiveMessageSettingController];
    }];
}

- (void)showArchiveMessageSettingController {
    DTArchiveMessageSettingController *archiveMessageSettingVC = [DTArchiveMessageSettingController new];
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        
        TSThread *lastestThread = [TSThread anyFetchWithUniqueId:self.thread.uniqueId
                                                     transaction:transaction];
        archiveMessageSettingVC.durationSeconds = [lastestThread messageExpiresInSeconds];
        archiveMessageSettingVC.conversationSettingsViewDelegate = self.conversationSettingsViewDelegate;
        archiveMessageSettingVC.thread = lastestThread;
        [self.navigationController pushViewController:archiveMessageSettingVC animated:true];
    }];
}

- (OWSTableItem *)groupInCommonItem {
    
    NSArray *inCommonGroups = self.commonGroupContext.inCommonGroups;
    
    NSString *itemTitle = Localized(@"CONVERSATION_SETTINGS_GROUP_IN_COMMON", @"");
    if (!DTParamsUtils.validateArray(inCommonGroups)) {
        NSString *detailText = inCommonGroups ? @"0" : @"";
        return [OWSTableItem labelItemWithText:itemTitle accessoryText:detailText];
    }
    @weakify(self)
    NSString *detailText = [NSString stringWithFormat:@"%ld", inCommonGroups.count];
    return [OWSTableItem disclosureItemWithText:itemTitle detailText:detailText actionBlock:^{
        @strongify(self);
        [self.commonGroupContext showCommonViewWithNavigationController:self.navigationController];
    }];
}

- (void)pushToGroupReminderSetController {
    @weakify(self)
    DTGroupReminderController *groupReminderVC = [DTGroupReminderController new];
    groupReminderVC.thread = self.thread;
    groupReminderVC.updateCompleteBlock = ^{
        @strongify(self)
        [self updateTableContents];
    };
    [self.navigationController pushViewController:groupReminderVC animated:YES];
}

- (OWSTableSection *)addLeaveGroupSection {
        
    OWSTableSection *leaveGroupSection = [OWSTableSection new];
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    
    NSString *title = Localized(@"LEAVE_GROUP_ACTION", @"table cell label in conversation settings");
    if([groupThread.groupModel.groupOwner isEqualToString:[TSAccountManager localNumber]]){
        title = Localized(@"DISMISS_GROUP_ACTION", @"table cell label in conversation settings");
    }
    
    [leaveGroupSection addItem:[self reportedButtonItem]];
    
    @weakify(self)
    [leaveGroupSection addItem:[self destructiveButtonItemWithTitle:title actionBlock:^{
        @strongify(self)
        [DTLeaveOrDisbandGroup leaveOrDisbandGroup:groupThread viewController:self needAlert:YES completion:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }]];
    
    return leaveGroupSection;
}

- (OWSTableSection *)deleteContactSection {
    if (self.thread.isGroupThread) {
        return nil;
    }
    SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.thread.contactIdentifier];
    if(!account.contact || (account.contact && account.contact.isExternal) || account.isBot){
        return nil;
    }
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    if([contactThread.contactIdentifier isEqualToString:[TSAccountManager sharedInstance].localNumber]){
        return nil;
    }

    OWSTableSection *userBlockSection = [OWSTableSection new];
    
    OWSTableItem *deleteContactItem = [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [self destructiveCellWithName:Localized(@"REMOVE_CONTACT", @"table cell label in conversation settings")
                                    iconName:nil];
    } actionBlock:^{
        [self deleteContact:contactThread.contactIdentifier];
    }];
    
    [userBlockSection addItem:[self reportedButtonItem]];
    [userBlockSection addItem:[self blockUserButtonItem]];
    [userBlockSection addItem:deleteContactItem];
    return userBlockSection;
}

- (void)deleteContact:(NSString *)uid {
    
    UIAlertController *deleteController =
    [UIAlertController alertControllerWithTitle:Localized(@"CONTACT_DELETE_TITLE", @"")
                                        message:Localized(@"CONTACT_REMOVE_ALERT_REASON", @"")
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"TXT_CANCEL_TITLE", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    @weakify(self);
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:Localized(@"CONTACT_DELETE", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        @strongify(self);
        //    按钮发生变化
        if(uid.length <= 6){return;}
        [DTToastHelper show];
        DTRemoveFriendsApi *api = [DTRemoveFriendsApi new];
        [api removeContact:uid sucess:^(DTAPIMetaEntity * _Nullable entity) {
            [DTToastHelper hide];
            [DTToastHelper toastWithText:Localized(@"CONTACT_REMOVEED", @"") durationTime:3.0 afterDelay:0.2];
            @strongify(self);
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                TSContactThread * contactThread = [TSContactThread getThreadWithContactId:uid transaction:writeTransaction];
                if (!contactThread) {
                    [TTNavigator goToHomePage];
                    return;
                }
                
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                SignalAccount *account = [contactsManager signalAccountForRecipientId:uid transaction:writeTransaction];
                if (account) {
                    [contactsManager removeAccountWithRecipientId:uid transaction:writeTransaction];
                }
                [contactThread removeAllThreadInteractionsWithTransaction:writeTransaction];
                [contactThread anyRemoveWithTransaction:writeTransaction];
                
                [writeTransaction addAsyncCompletionOnMain:^{
                    [TTNavigator goToHomePage];
                }];
                
            });
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
            [DTToastHelper dismiss];
            NSString *errorString = [NSError errorDesc:error errResponse:entity];
            [DTToastHelper toastWithText:errorString];
        }];
    }];
    [deleteController addAction:cancelAction];
    [deleteController addAction:confirmAction];
    [self.navigationController presentViewController:deleteController animated:true completion:nil];
    
}

- (OWSTableItem *)destructiveButtonItemWithTitle:(NSString *)title
                                     actionBlock:(void(^)(void))actionBlock {
    
    return [OWSTableItem itemWithCustomCellBlock:^{
          
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCellStyleDefault"];
        cell.preservesSuperviewLayoutMargins = YES;
        cell.contentView.preservesSuperviewLayoutMargins = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = title;
        cell.textLabel.font = OWSTableItem.textLabelFont;
        cell.textLabel.textColor = [UIColor colorWithRGBHex:0xF84135];
        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
        return cell;
    } customRowHeight:45 actionBlock:^{
        if (actionBlock) actionBlock();
    }];
}


- (OWSTableItem *)reportedButtonItem {
    OWSTableItem *reportItem = [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [self destructiveCellWithName:Localized(@"REPORT_CONTACT_TITLE", @"table cell label in conversation settings")
                                    iconName:nil];
    } actionBlock:^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:Localized(@"REPORT_CONTACT_TITLE", @"table cell label in conversation settings")
                                                                       message:Localized(@"REPORT_CONTACT_TIPS_DESCRIPTION", @"table cell label in conversation settings")
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:Localized(@"REPORT_CONTACT_TITLE", @"table cell label in conversation settings")];
        [title addAttribute:NSFontAttributeName
                      value:[UIFont boldSystemFontOfSize:17]
                      range:NSMakeRange(0, title.length)];
        [title addAttribute:NSForegroundColorAttributeName
                      value:[UIColor colorWithRGBHex:0x1E2329]
                      range:NSMakeRange(0, title.length)];

        // 利用 KVC 设置 alert 的标题富文本
        [alert setValue:title forKey:@"attributedTitle"];
        

        UIAlertAction *reportAction = [UIAlertAction actionWithTitle:Localized(@"REPORT_CONTACT_TIPS_CONFIRM", @"table cell label in conversation settings")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            
            DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
                TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                             inThread:self.thread
                                                                          messageType:TSInfoMessageReportedMessage
                                                                     expiresInSeconds:self.thread.messageExpiresInSeconds
                                                                        customMessage:Localized(@"REPORT_INFO_TIPS_TITLE",nil)];
                [infoMessage anyInsertWithTransaction:writeTransaction];
            }));
            
            [DTToastHelper showInfo:Localized(@"REPORT_INFO_REPORTED_SUCCESS", @"table cell label in conversation settings")];
            
        }];
        [reportAction setValue:[UIColor colorWithRGBHex:0xD9271E] forKey:@"_titleTextColor"];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"REPORT_CONTACT_TIPS_CANCEL", @"table cell label in conversation settings")
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
        UIColor *buttonColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329];
        [cancelAction setValue:buttonColor forKey:@"_titleTextColor"];
        
        [alert addAction:reportAction];
        [alert addAction:cancelAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        
    }];
    
    return reportItem;
}

#pragma mark - Block/Unblock User Item

- (OWSTableItem *)blockUserButtonItem {
    NSString *conversationID = [self.thread serverThreadId];
    
    if (self.thread.isBlocked) {
        // 当前已被拉黑，显示“取消拉黑”
        return [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
            return [self destructiveCellWithName:Localized(@"BLOCK_USER_UNBLOCK", nil)
                                        iconName:nil];
        } actionBlock:^{
            [self requestConfigBlockStatusWithConversationID:conversationID
                                                 blockStatus:@(0)
                                                     success:^{
                [DTToastHelper showInfo:Localized(@"CONVERSATION_SETTINGS_STICKY_UNBLOCK_TIP", nil)];
            } failure:^{
                [DTToastHelper showInfo:Localized(@"UNBLOCK_USER_BLOCK_FAILURE_TIPS", nil)];
            }];
        }];
        
    } else {
        // 当前未拉黑，显示“拉黑”
        return [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
            return [self destructiveCellWithName:Localized(@"BLOCK_USER_TITLE", nil)
                                        iconName:nil];
        } actionBlock:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:Localized(@"BLOCK_USER_TITLE", nil)
                                                                           message:Localized(@"BLOCK_USER_DESCRIPTION", nil)
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            
            NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:Localized(@"BLOCK_USER_TITLE", nil)];
            [title addAttributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:17],
                NSForegroundColorAttributeName: [UIColor colorWithRGBHex:0x1E2329]
            } range:NSMakeRange(0, title.length)];
            [alert setValue:title forKey:@"attributedTitle"];

            UIAlertAction *blockAction = [UIAlertAction actionWithTitle:Localized(@"BLOCK_USER_CONFIRM", nil)
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
                [self requestConfigBlockStatusWithConversationID:conversationID
                                                     blockStatus:@(1)
                                                         success:^{
                    [DTToastHelper showInfo:Localized(@"CONVERSATION_SETTINGS_STICKY_BLOCK_TIP", nil)];
                } failure:^{
                    [DTToastHelper showInfo:Localized(@"BLOCK_USER_BLOCK_FAILURE_TIPS", nil)];
                }];
            }];
            [blockAction setValue:[UIColor colorWithRGBHex:0xD9271E] forKey:@"_titleTextColor"];

            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"BLOCK_USER_CANCEL", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:nil];
            UIColor *buttonColor = Theme.isDarkThemeEnabled
                ? [UIColor colorWithRGBHex:0xEAECEF]
                : [UIColor colorWithRGBHex:0x1E2329];
            [cancelAction setValue:buttonColor forKey:@"_titleTextColor"];

            [alert addAction:blockAction];
            [alert addAction:cancelAction];

            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
}

- (CGFloat)iconSpacing
{
    return 12.f;
}

- (UITableViewCell *)disclosureCellWithName:(NSString *)name iconColor:(UIColor *)iconColor
{
    OWSAssertDebug(name.length > 0);

    UIView *iconView = [UIView containerView];
    [iconView autoSetDimensionsToSize:CGSizeMake(kIconViewLength, kIconViewLength)];

    UIView *swatchView = [NeverClearView new];
    const CGFloat kSwatchWidth = 20;
    [swatchView autoSetDimensionsToSize:CGSizeMake(kSwatchWidth, kSwatchWidth)];
    swatchView.layer.cornerRadius = kSwatchWidth / 2;
    swatchView.backgroundColor = iconColor;
    [iconView addSubview:swatchView];
    [swatchView autoCenterInSuperview];

    return [self cellWithName:name iconView:iconView];
}

- (UITableViewCell *)destructiveCellWithName:(NSString *)name iconName:(nullable NSString *)iconName
{
    UITableViewCell *cell = [self cellWithName:name nameColor:[UIColor colorWithRGBHex:0xF84035] iconName:iconName];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UITableViewCell *)cellWithName:(NSString *)name nameColor:(nullable UIColor *)nameColor iconName:(NSString *)iconName
{
    return [self cellWithName:name nameColor:nameColor iconView:nil];
}

- (UITableViewCell *)cellWithName:(NSString *)name nameColor:(nullable UIColor *)nameColor iconView:(nullable UIView *)iconView
{
    UITableViewCell *cell = [UITableViewCell new];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);

    UILabel *rowLabel = [UILabel new];
    rowLabel.text = name;
    if(nameColor){
        rowLabel.textColor = nameColor;
    }
//    rowLabel.textColor = Theme.primaryTextColor;
    rowLabel.font = [UIFont systemFontOfSize:16.0];
    rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    UIStackView *contentRow = [[UIStackView alloc] init];
    if(iconView){
        [contentRow addArrangedSubview:iconView];
        [contentRow addArrangedSubview:rowLabel];
    } else {
        [contentRow addArrangedSubview:rowLabel];
    }
    contentRow.spacing = self.iconSpacing;

    [cell.contentView addSubview:contentRow];
    [contentRow autoPinEdgesToSuperviewMargins];

    return cell;
}

- (UITableViewCell *)cellWithName:(NSString *)name iconName:(NSString *)iconName
{
    OWSAssertDebug(iconName.length > 0);
//    UIImageView *iconView = [self viewForIconWithName:iconName];
    return [self cellWithName:name iconView:nil];
}

- (UITableViewCell *)cellWithName:(NSString *)name iconView:(nullable UIView *)iconView
{
    OWSAssertDebug(name.length > 0);

    UITableViewCell *cell = [UITableViewCell new];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);

    UILabel *rowLabel = [UILabel new];
    rowLabel.text = name;
    rowLabel.textColor = Theme.primaryTextColor;
    rowLabel.font = self.primaryFont;
    rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    UIStackView *contentRow = [[UIStackView alloc] initWithArrangedSubviews:@[rowLabel]]; //iconView
    contentRow.spacing = self.iconSpacing;

    [cell.contentView addSubview:contentRow];
    [contentRow autoPinEdgesToSuperviewMargins];

    return cell;
}

- (UITableViewCell *)disclosureCellWithName:(NSString *)name iconName:(NSString *)iconName
{
    UITableViewCell *cell = [self cellWithName:name iconName:iconName];
    cell.accessoryView = self.accessoryArrow;
    return cell;
}

- (UITableViewCell *)labelCellWithName:(NSString *)name iconName:(NSString *)iconName
{
    UITableViewCell *cell = [self cellWithName:name iconName:iconName];
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UIView *)mainSectionHeader {
    
    if (!DTParamsUtils.validateArray(self.sortedGroupMemberIds)) {
        return nil;
    }

    @weakify(self)
    DTConversationSettingHeader *header = [[DTConversationSettingHeader alloc] initWithMemberIds:self.sortedGroupMemberIds isGroup:self.isGroupThread addMember:^{
        @strongify(self)
        if (self.isGroupThread) {
            if (![DTGroupPermissions hasPermissionToAddGroupMembersWithGroupModel:((TSGroupThread *)self.thread).groupModel]) {
                [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
                return;
            }
            [self addGroupMember];
        } else {
            NewGroupViewController *newGroupVC = [NewGroupViewController new];
            newGroupVC.createType = DTCreateGroupTypeContact;
            newGroupVC.thread = self.thread;
            [self.navigationController pushViewController:newGroupVC animated:YES];
        }
    } removeMember:^{
        @strongify(self)
        if (!self.isGroupThread) { return; }
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        if (![DTGroupPermissions hasPermissionToRemoveGroupMembersWithGroupModel:groupThread.groupModel]){
            [DTToastHelper showWithInfo:@"No permission, please contact the group moderators"];
            return;
        }
        [self showUpdateGroupView:UpdateGroupMode_RemoveGroupMembers];
    } viewMember:^(NSInteger index) {
        @strongify(self)
        NSString *recipientId = nil;
        if (self.isGroupThread) {
            recipientId = self.sortedGroupMemberIds[(NSUInteger)index];
        } else {
            recipientId = self.thread.contactIdentifier;
        }
        
        [self showProfileCardInfo:recipientId];
    } viewAll:^{
        @strongify(self)
        if (!self.isGroupThread) { return; }
        [self showGroupMembersView];
    }];
    header.backgroundColor = Theme.tableSettingCellBackgroundColor;
    
    return header;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        // Text Color
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        [header.textLabel setTextColor:Theme.primaryTextColor];
        header.backgroundColor = Theme.tableSettingCellBackgroundColor;
        header.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
   }
}

- (void)tapCopyNumberAction:(UIGestureRecognizer *)sender {
    NSString *recipientId = self.thread.contactIdentifier;
    
    if (recipientId) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = recipientId;
        
        NSString *fullPrefix = Localized(@"CONTACT_NUMBER_DESCRIPTION_HEADER", @"copy to pastboard");
        NSString *prefix = [fullPrefix substringToIndex:fullPrefix.length - 2];

        [DTToastHelper toastWithText:[prefix stringByAppendingString:Localized(@"COPY_TO_PASTBOARD", @"copy to pastboard")] durationTime:2];
    }
}

- (void)tapCopyEmailGesture:(UIGestureRecognizer *)sender {
    NSString *recipientId = self.thread.contactIdentifier;
    SignalAccount* signalAccount = [self.contactsManager signalAccountForRecipientId:recipientId];
    NSString *email = signalAccount.contact.email;
    
    if (email) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = email;

        NSString *fullPrefix = Localized(@"CONTACT_EMAIL_DESCRIPTION_HEADER", @"copy to pastboard");
        NSString *prefix = [fullPrefix substringToIndex:fullPrefix.length - 2];
        [DTToastHelper toastWithText:[prefix stringByAppendingString:Localized(@"COPY_TO_PASTBOARD", @"copy to pastboard")] durationTime:2];
    }
}

- (void)toEditGroupInfo
{
    if (!self.isGroupThread) {
        return;
    }
    
    [self showUpdateGroupView:UpdateGroupMode_EditGroupName];
}

/*
- (UIImageView *)viewForIconWithName:(NSString *)iconName
{
    UIImage *icon = [UIImage imageNamed:iconName];

    OWSAssertDebug(icon);
    UIImageView *iconView = [UIImageView new];
    iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iconView.tintColor = Theme.secondaryTextAndIconColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.minificationFilter = kCAFilterTrilinear;
    iconView.layer.magnificationFilter = kCAFilterTrilinear;

    [iconView autoSetDimensionsToSize:CGSizeMake(kIconViewLength, kIconViewLength)];

    return iconView;
}
*/

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.thread.isGroupThread) {
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            [self.thread anyReloadWithTransaction:readTransaction];
        }];
    }
    
    [self refreshTitle];
   
    // HACK to unselect rows when swiping back
    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];

    [self updateTableContents];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.disappearingMessagesConfiguration.isNewRecord && !self.disappearingMessagesConfiguration.isEnabled) {
        // don't save defaults, else we'll unintentionally save the configuration and notify the contact.
        return;
    }
}

#pragma mark - Actions

- (void)showVerificationView
{
    NSString *recipientId = self.thread.contactIdentifier;
    OWSAssertDebug(recipientId.length > 0);

    [FingerprintViewController presentFromViewController:self recipientId:recipientId];
}

- (void)showGroupMembersView
{
    ShowGroupMembersViewController *showGroupMembersViewController = [ShowGroupMembersViewController new];
    [showGroupMembersViewController configWithThread:(TSGroupThread *)self.thread];
    [self.navigationController pushViewController:showGroupMembersViewController animated:YES];
}

//展示群管理页面
- (void)showGroupManagement {
    DTGroupMangerViewController *groupMangerVC = [DTGroupMangerViewController new];
    [groupMangerVC configWithThread:(TSGroupThread*)self.thread];
    [self.navigationController pushViewController:groupMangerVC animated:YES];
}

- (void)showUpdateGroupView:(UpdateGroupMode)mode
{
    OWSAssertDebug(self.conversationSettingsViewDelegate);

    UpdateGroupViewController *updateGroupViewController = [UpdateGroupViewController new];
    updateGroupViewController.conversationSettingsViewDelegate = self.conversationSettingsViewDelegate;
    updateGroupViewController.thread = (TSGroupThread *)self.thread;
    updateGroupViewController.mode = mode;
    if (mode == UpdateGroupMode_RemoveGroupMembers) {
        @weakify(self)
        updateGroupViewController.removeGroupMemberFinished = ^{
            @strongify(self);
            [self reloadHeader];
        };
    }
    [self.navigationController pushViewController:updateGroupViewController animated:YES];
}

- (void)addGroupMember { //添加群成员
    OWSAssertDebug(self.conversationSettingsViewDelegate);
    AddToGroupViewController *addToGroupViewController = [AddToGroupViewController new];
    addToGroupViewController.addToGroupDelegate = self;
    addToGroupViewController.conversationSettingsViewDelegate = self.conversationSettingsViewDelegate;
    addToGroupViewController.thread = (TSGroupThread *)self.thread;
    [self.navigationController pushViewController:addToGroupViewController animated:YES];
}

- (void)presentContactInfoViewController
{
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    ContactEditingViewController *viewController = [ContactEditingViewController new];
    [viewController configureWithRecipientId:contactThread.contactIdentifier];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)didTapEditButton
{
    [self presentContactInfoViewController];
}

- (void)disappearingMessagesSwitchValueDidChange:(UISwitch *)sender
{
    UISwitch *disappearingMessagesSwitch = (UISwitch *)sender;

    [self toggleDisappearingMessages:disappearingMessagesSwitch.isOn];

    [self updateTableContents];
}

- (void)stickyOnTopDidChange:(id)sender {
    
    if (![sender isKindOfClass:[UISwitch class]]) {
        OWSFailDebug(@"%@ Unexpected sender for block user switch: %@", self.logTag, sender);
    }
    
//    __weak OWSConversationSettingsViewController *weakSelf = self;
    
    NSUInteger maxNumberOfStickThread = [DTStickyConfig maxStickCount];
    __block NSUInteger numberOfStickThread = 0;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
        NSError *error;
        [finder enumerateVisibleThreadsWithIsArchived:NO
                                          transaction:readTransaction
                                                error:&error
                                                block:^(TSThread * object) {
            if (object.isSticked) {
                numberOfStickThread ++;
            }
        }];
    }];

    BOOL isSticked = self.thread.isSticked;
    DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
        if (!isSticked) {
            
            if (numberOfStickThread >= maxNumberOfStickThread) {
                UISwitch *stickSwitch = (UISwitch *)sender;
                [SVProgressHUD showInfoWithStatus:[NSString stringWithFormat:Localized(@"NUMBER_OF_STICK_THREAD_MAX", @""), maxNumberOfStickThread]];
                [SVProgressHUD dismissWithDelay:1 completion:^{
                    [stickSwitch setOn:NO animated:YES];
                }];
            } else {
                
                [self.thread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                    [t stickThread];
                }];
            }
        } else {
            
            [self.thread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                [t unstickThread];
            }];
        }
    }));
}

- (void)conversationSettingDidChange:(NSNotification *)notify {
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransation) {
        [self.thread anyReloadWithTransaction:readTransation];
        self.mutedSwitch.on = self.thread.isMuted;
        if (self.blockSwitch) {
            self.blockSwitch.on = self.thread.isBlocked;
        }
    }];
}

- (void)conversationBlockUserDidChange:(NSNotification *)notify {
    [self updateTableContents];
}

- (void)blockUserSwitchDidChange:(id)sender
{
    OWSAssertDebug(!self.isGroupThread);

    if (![sender isKindOfClass:[UISwitch class]]) {
        OWSFailDebug(@"%@ Unexpected sender for block user switch: %@", self.logTag, sender);
    }
    UISwitch *blockUserSwitch = (UISwitch *)sender;

    BOOL isCurrentlyBlocked = [[_blockingManager blockedPhoneNumbers] containsObject:self.thread.contactIdentifier];

    if (blockUserSwitch.isOn) {
        OWSAssertDebug(!isCurrentlyBlocked);
        if (isCurrentlyBlocked) {
            return;
        }
        [BlockListUIUtils showBlockPhoneNumberActionSheet:self.thread.contactIdentifier
                                       fromViewController:self
                                          blockingManager:_blockingManager
                                          contactsManager:_contactsManager
                                          completionBlock:^(BOOL isBlocked) {
                                              // Update switch state if user cancels action.
                                              blockUserSwitch.on = isBlocked;
                                          }];
    } else {
        OWSAssertDebug(isCurrentlyBlocked);
        if (!isCurrentlyBlocked) {
            return;
        }
        [BlockListUIUtils showUnblockPhoneNumberActionSheet:self.thread.contactIdentifier
                                         fromViewController:self
                                            blockingManager:_blockingManager
                                            contactsManager:_contactsManager
                                            completionBlock:^(BOOL isBlocked) {
                                                // Update switch state if user cancels action.
                                                blockUserSwitch.on = isBlocked;
                                            }];
    }
}

- (void)toggleDisappearingMessages:(BOOL)flag
{
    self.disappearingMessagesConfiguration.enabled = flag;

    [self updateTableContents];
}

- (void)durationSliderDidChange:(UISlider *)slider
{
    // snap the slider to a valid value
    NSUInteger index = (NSUInteger)(slider.value + 0.5);
    [slider setValue:index animated:YES];
    NSNumber *numberOfSeconds = self.disappearingMessagesDurations[index];
    self.disappearingMessagesConfiguration.durationSeconds = [numberOfSeconds unsignedIntValue];

    [self updateDisappearingMessagesDurationLabel];
}

- (void)updateDisappearingMessagesDurationLabel
{
    if (self.disappearingMessagesConfiguration.isEnabled) {
        NSString *keepForFormat = Localized(@"KEEP_MESSAGES_DURATION",
            @"Slider label embeds {{TIME_AMOUNT}}, e.g. '2 hours'. See *_TIME_AMOUNT strings for examples.");
        self.disappearingMessagesDurationLabel.text =
            [NSString stringWithFormat:keepForFormat, self.disappearingMessagesConfiguration.durationString];
    } else {
        self.disappearingMessagesDurationLabel.text
            = Localized(@"KEEP_MESSAGES_FOREVER", @"Slider label when disappearing messages is off");
    }

    [self.disappearingMessagesDurationLabel setNeedsLayout];
    [self.disappearingMessagesDurationLabel.superview setNeedsLayout];
}

- (void)setThreadMutedUntilDate:(nullable NSDate *)value
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.thread updateWithMutedUntilDate:value transaction:writeTransaction];
    });
    
    [self updateTableContents];
}

- (void)showMediaGallery
{
    DDLogDebug(@"%@ in showMediaGallery", self.logTag);

    MediaGalleryViewController *vc =
        [[MediaGalleryViewController alloc] initWithThread:self.thread
                                                   options:MediaGalleryOptionSliderEnabled];

    // although we don't present the mediaGalleryViewController directly, we need to maintain a strong
    // reference to it until we're dismissed.
    self.mediaGalleryViewController = vc;

    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);
    [vc pushTileViewFromNavController:(OWSNavigationController *)self.navigationController];
    
}
#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    OWSAssertDebug(recipientId.length > 0);

    if (recipientId.length > 0 && [self.thread isKindOfClass:[TSContactThread class]] &&
        [self.thread.contactIdentifier isEqualToString:recipientId]) {
        [self updateTableContents];
    }
}

- (void)groupReminderCycleChanged:(NSNotification *)noti {
    OWSAssertIsOnMainThread();
    
    if (!noti.object) return;

    BOOL isChanged = [noti.userInfo[@"isChanged"] boolValue];
    if (!isChanged) return;
    
    TSGroupThread *groupThread = (TSGroupThread *)noti.object;
    self.thread = groupThread;
    [self updateTableContents];
}

//MARK: AddToGroupViewControllerDelegate
- (void)recipientIdsWasAdded:(NSSet<NSString *> *)recipientIds {
    [self reloadHeader];
}

- (void)presentGroupLinkQrcodeController {
    if (!self.thread.isGroupThread) return;
    
    DTGroupLinkQrcodeController *groupLinkQrcodeVC = [[DTGroupLinkQrcodeController alloc] initWithGThread:(TSGroupThread *)self.thread];
    OWSNavigationController *navigationController = [[OWSNavigationController alloc] initWithRootViewController:groupLinkQrcodeVC];
    navigationController.modalPresentationStyle = UIModalPresentationAutomatic;
    [self.navigationController presentViewController:navigationController animated:true completion:nil];
    
}

//展示全局翻译的配置
- (void)showGroupTranslateSettingController {
    DTGroupTranslateSettingController *groupTranslateSettingVC = [DTGroupTranslateSettingController new];
    [groupTranslateSettingVC configureWithThread:self.thread];
    [self.navigationController pushViewController:groupTranslateSettingVC animated:true];
}

#pragma mark - actions

- (void)btnTipsAtion:(id)sender {
    
    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil message:Localized(@"SETTINGS_ITEM_GROUP_REMINDER_TIP", @"")];
    actionSheet.messageAlignment = ActionSheetContentAlignmentLeading;
    [actionSheet addAction:[OWSActionSheets cancelAction]];
    
    [self presentActionSheet:actionSheet];
}

@end

NS_ASSUME_NONNULL_END
