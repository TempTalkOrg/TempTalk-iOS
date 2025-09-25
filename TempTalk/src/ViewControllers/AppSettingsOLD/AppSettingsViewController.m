//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AppSettingsViewController.h"
#import "AboutTableViewController.h"
#import "AdvancedSettingsTableViewController.h"
#import "DebugUITableViewController.h"
#import "NotificationSettingsViewController.h"
#import "OWSLinkedDevicesTableViewController.h"
#import "PrivacySettingsTableViewController.h"
#import "PushManager.h"
#import "RegistrationUtils.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/UIUtil.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/DTToastHelper.h>
#import "DTEditPersonInfoController.h"
#import "TempTalk-Swift.h"

extern CGFloat const kAvatarSize;
@interface AppSettingsViewController () <DTActiveStateDelegate, OWSNavigationChildController>

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, strong) NSDictionary *avatar;
@property (nonatomic, strong) SignalAccount *account;
@property (nonatomic, strong) DTAvatarImageView *avatarView;
@property (nonatomic, strong) DTActiveStateView *stateView;

@end

#pragma mark -

@implementation AppSettingsViewController

/**
 * We always present the settings controller modally, from within an OWSNavigationController
 */
+ (OWSNavigationController *)inModalNavigationController
{
    AppSettingsViewController *viewController = [AppSettingsViewController new];
    OWSNavigationController *navController =
        [[OWSNavigationController alloc] initWithRootViewController:viewController];

    return navController;
}

+ (OWSNavigationController *)inNormalNavigationController
{
    AppSettingsViewController *viewController = [AppSettingsViewController new];
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    OWSNavigationController *navController =
        [[OWSNavigationController alloc] initWithRootViewController:viewController];

    return navController;
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _contactsManager = Environment.shared.contactsManager;

    return self;
}

- (void)loadView
{
    self.tableViewStyle = UITableViewStylePlain;
    [super loadView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);

//    self.leftTitle = Localized(@"SETTINGS_NAV_BAR_TITLE", @"Title for settings activity");
    
    self.tableView.backgroundColor = Theme.backgroundColor;
    [self requestUserMessage];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    OWSContactsManager *contactManager = Environment.shared.contactsManager;
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    SignalAccount *account = [contactManager signalAccountForRecipientId:recipientId];
    self.avatar = account.contact.avatar;
    [self updateTableContents];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak AppSettingsViewController *weakSelf = self;

#ifdef INTERNAL
    OWSTableSection *internalSection = [OWSTableSection new];
    [section addItem:[OWSTableItem softCenterLabelItemWithText:@"Internal Build"]];
    [contents addSection:internalSection];
#endif

    OWSTableSection *section = [OWSTableSection new];
    section.customHeaderView = [UIView new];
    section.customHeaderHeight = @40;
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return [weakSelf profileHeaderCell];
    }
                         customRowHeight:UITableViewAutomaticDimension
                         actionBlock:^{
        [weakSelf showPersonCardViewController];
                         }]];
    
    [section addItem:[OWSTableItem blankItemWithcustomRowHeight:10.f backgroundColor:Theme.blankBackgroundColor]];
    
    // added: add invite friends button
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_invite" title:Localized(@"SETTINGS_INVITE_TITLE", @"Settings table view cell label")];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showInviteFlow];
    }]];
    
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_advance" title:Localized(@"SETTINGS_PRIVACY_TITLE", @"Settings table view cell label")];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showPrivacy];
    }]];

    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_notification" title:Localized(@"SETTINGS_NOTIFICATIONS", nil)];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showNotifications];
    }]];
    
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_device" title:Localized(@"LINKED_DEVICES_TITLE", @"Menu item and navbar title for the device manager")];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showLinkedDevices];
    }]];
    
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_privacy" title:Localized(@"SETTINGS_ADVANCED_TITLE", @"")];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showAdvanced];
    }]];
    
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        return [weakSelf iconItemWithIconName:@"appsetting_about" title:Localized(@"SETTINGS_ABOUT", @"")];
    }
                                           customRowHeight:60
                                               actionBlock:^{
        [weakSelf showAbout];
    }]];

#ifdef USE_DEBUG_UI
    
    [section addItem:[OWSTableItem disclosureItemWithText:@"Debug UI"
                                              actionBlock:^{
                                                  [weakSelf showDebugUI];
                                              }]];
    
    [section addItem:[OWSTableItem disclosureItemWithText:@"Clear local data"
                                              actionBlock:^{
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [DTWorkspaceSecurityDataStoreService clearDataWithTransaction:transaction];
        });
    }]];
    
#endif

    if (TSAccountManager.sharedInstance.isDeregistered) {
        [section addItem:[self destructiveButtonItemWithTitle:Localized(@"SETTINGS_REREGISTER_BUTTON",
                                                                  @"Label for re-registration button.")
                                                     selector:@selector(reregisterUser)
                                                        color:[UIColor ows_materialBlueColor]]];
//        [section addItem:[self destructiveButtonItemWithTitle:Localized(@"SETTINGS_DELETE_DATA_BUTTON",
//                                                                  @"Label for 'delete data' button.")
//                                                     selector:@selector(deleteUnregisterUserData)
//                                                        color:[UIColor ows_destructiveRedColor]]];
    } else {
        if (!TSConstants.isUsingProductionService) {
            [section addItem:[self destructiveButtonItemWithTitle:Localized(@"SETTINGS_DELETE_ACCOUNT_BUTTON", @"")
                                                         selector:@selector(unregisterUser)
                                                            color:[UIColor ows_destructiveRedColor]]];
        }
        
    }

    [contents addSection:section];

    self.contents = contents;
}

- (UITableViewCell *)iconItemWithIconName:(NSString *)iconName title:(NSString *)title {
    UITableViewCell *cell = [self newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.separatorInset = UIEdgeInsetsMake(0, 55, 0, 0);
    
    UIImage *iconImage = [UIImage imageNamed:iconName];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImage];
    [iconView autoSetDimensionsToSize:CGSizeMake(31, 31)];
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.textColor = Theme.primaryTextColor;
    titleLabel.font = [UIFont ows_regularFontWithSize:17.f];
    [titleLabel setContentHuggingLow];
    [titleLabel setCompressionResistanceHigh];
    
    UIImage *disclosureImage = [UIImage imageNamed:(CurrentAppContext().isRTL ? @"NavBarBack" : @"NavBarBackRTL")];
    OWSAssertDebug(disclosureImage);
    UIImageView *disclosureButton =
        [[UIImageView alloc] initWithImage:disclosureImage];
//    disclosureButton.tintColor = [UIColor colorWithRGBHex:0xcccccc];
    [disclosureButton setContentHuggingHigh];
    [disclosureButton setCompressionResistanceHigh];
    
    UIStackView *contentRow = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, titleLabel, disclosureButton]];
    contentRow.axis = UILayoutConstraintAxisHorizontal;
    contentRow.alignment = UIStackViewAlignmentCenter;
    contentRow.spacing = 12;
    [cell.contentView addSubview:contentRow];
    
    [contentRow setContentHuggingHigh];
    [contentRow autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [contentRow autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [contentRow autoPinEdgeToSuperviewMargin:ALEdgeLeading];
    [contentRow autoPinEdgeToSuperviewMargin:ALEdgeTrailing];
//    contentRow.autoSetDimension(.height, toSize: iconSize, relation: .greaterThanOrEqual)
    return cell;
}

- (OWSTableItem *)destructiveButtonItemWithTitle:(NSString *)title selector:(SEL)selector color:(UIColor *)color
{
    return [OWSTableItem
        itemWithCustomCellBlock:^{
            UITableViewCell *cell = [self newCell];
            cell.preservesSuperviewLayoutMargins = YES;
            cell.contentView.preservesSuperviewLayoutMargins = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            const CGFloat kButtonHeight = 40.f;
            OWSFlatButton *button = [OWSFlatButton buttonWithTitle:title
                                                              font:[OWSFlatButton fontForHeight:kButtonHeight]
                                                        titleColor:[UIColor whiteColor]
                                                   backgroundColor:color
                                                            target:self
                                                          selector:selector];
            [cell.contentView addSubview:button];
            [button autoSetDimension:ALDimensionHeight toSize:kButtonHeight];
            [button autoVCenterInSuperview];
            [button autoPinLeadingAndTrailingToSuperviewMargin];

            return cell;
        }
                customRowHeight:90.f
                    actionBlock:nil];
}

- (void)applyTheme {
    [super applyTheme];
    self.tableView.backgroundColor = Theme.backgroundColor;
    [self updateTableContents];
}

- (void)applyLanguage {
    [super applyLanguage];
    [self updateTableContents];
}

- (void)requestUserMessage {
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    __weak typeof(self) weakSelf = self;
    [[TSAccountManager sharedInstance] getContactMessageV1ByPhoneNumber:@[recipientId] success:^(NSArray *contacts) {
        if (!contacts) {
            return;
        }
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            OWSContactsManager *contactsManager = Environment.shared.contactsManager;
            SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:writeTransaction];
            if (!account) {
                account = [[SignalAccount alloc] initWithRecipientId:recipientId];
            }
            
            Contact *contact = contacts.firstObject;
            account.contact = contact;
            SignalAccount *newAccount = [account copy];
            [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:newAccount withTransaction:writeTransaction];
            
            OWSSound currentSound = [OWSSounds globalNotificationSoundWithTransaction:writeTransaction];
            NSString *localSoundFileName = [OWSSounds filenameForSound:currentSound];
            NSString *serverSoundFileName = contact.privateConfigs.notificationSound;
            if (DTParamsUtils.validateString(localSoundFileName) &&
                DTParamsUtils.validateString(serverSoundFileName) &&
                ![localSoundFileName isEqualToString:serverSoundFileName]) {
                
                OWSSound sound = [OWSSounds soundForFilename:serverSoundFileName];
                [OWSSounds setGlobalNotificationSound:sound transaction:writeTransaction];
                OWSLogInfo(@"sync apn sound success, %@ -> %@.", localSoundFileName, serverSoundFileName);
            } else {
                OWSLogInfo(@"not sync apn sound, local:%@, server:%@.", localSoundFileName, serverSoundFileName);
            }
            
            [writeTransaction addAsyncCompletionOnMain:^{
                [weakSelf updateTableContents];
            }];
        });
    } failure:^(NSError * _Nonnull error) {
        
    }];
}

- (UITableViewCell *)profileHeaderCell
{
    OWSContactsManager *contactManager = Environment.shared.contactsManager;
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    SignalAccount *account = [contactManager signalAccountForRecipientId:recipientId];
    
    UITableViewCell *cell = [self newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.separatorInset = UIEdgeInsetsMake(0, UIScreen.mainScreen.bounds.size.width, 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIView *conTainView = [UIView new];
    [cell.contentView addSubview:conTainView];
    conTainView.backgroundColor = [UIColor clearColor];
    [conTainView autoPinEdgesToSuperviewMarginsExcludingEdge:ALEdgeBottom];
    [conTainView autoSetDimension:ALDimensionHeight toSize:100];
    
    self.avatarView = [DTAvatarImageView new];
    [conTainView addSubview:self.avatarView];
    self.avatarView.imageForSelfType = DTAvatarImageForSelfTypeOriginal;
    [self.avatarView autoVCenterInSuperview];
    [self.avatarView autoPinEdgeToSuperviewEdge:ALEdgeLeft];
    [self.avatarView autoSetDimensionsToSize:CGSizeMake(kAvatarSize, kAvatarSize)];
    
    [self.avatarView setImageWithAvatar:account.contact.avatar recipientId:recipientId displayName:account.contactFullName completion:nil];
    
    UIImage *disclosureImage = [UIImage imageNamed:(CurrentAppContext().isRTL ? @"NavBarBack" : @"NavBarBackRTL")];
    OWSAssertDebug(disclosureImage);
    UIImageView *disclosureButton =
        [[UIImageView alloc] initWithImage:disclosureImage];
//    disclosureButton.tintColor = [UIColor colorWithRGBHex:0xcccccc];
    [conTainView addSubview:disclosureButton];
    [disclosureButton autoVCenterInSuperview];
    [disclosureButton autoPinTrailingToEdgeOfView:conTainView];
    [disclosureButton setContentHuggingHigh];
    [disclosureButton setCompressionResistanceHigh];
   
    UIStackView *nameView = [UIStackView new];
    nameView.axis = UILayoutConstraintAxisVertical;
    nameView.alignment = UIStackViewAlignmentCenter;
    nameView.distribution = UIStackViewDistributionFillProportionally;
    [conTainView addSubview:nameView];
    [nameView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:conTainView];
    [nameView autoPinTrailingToLeadingEdgeOfView:disclosureButton offset:12.f];
    [nameView autoPinLeadingToTrailingEdgeOfView:self.avatarView offset:12.f];

    UILabel *titleLabel = [UILabel new];
    titleLabel.numberOfLines = 3;
    titleLabel.font = [UIFont ows_semiboldFontWithSize:20];
    NSString *_Nullable localProfileName = account.contact.fullName;
    if (localProfileName.length > 0) {
        titleLabel.text = localProfileName;
        titleLabel.textColor = Theme.primaryTextColor;
    } else {
        titleLabel.text = Localized(
            @"APP_SETTINGS_EDIT_PROFILE_NAME_PROMPT", @"Text prompting user to edit their profile name.");
        titleLabel.textColor = Theme.accentBlueColor; //[UIColor ows_materialBlueColor];
    }
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [nameView addArrangedSubview:titleLabel];
    [titleLabel autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [titleLabel autoPinWidthToSuperview];

    UIView *lineView = [[UIView alloc] init];
    lineView.backgroundColor = Theme.cellSeparatorColor;
    [cell.contentView addSubview:lineView];
    [lineView autoSetDimension:ALDimensionHeight toSize:1];
    [lineView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:conTainView withOffset:0];
    [lineView autoPinLeadingToSuperviewMargin];
    [lineView autoPinTrailingToSuperviewMargin];
    
    UIView *bottomContainView = [UIView new];
    [cell.contentView addSubview:bottomContainView];
    bottomContainView.backgroundColor = [UIColor clearColor];

    [cell.contentView addSubview:bottomContainView];
    [bottomContainView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lineView];
    [bottomContainView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [bottomContainView autoPinEdgeToSuperviewMargin:ALEdgeRight];
    [bottomContainView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView];
    
    UILabel *signatureLabel = [[UILabel alloc] init];
    signatureLabel.textColor = Theme.primaryTextColor;
    signatureLabel.textAlignment = NSTextAlignmentLeft;
    signatureLabel.numberOfLines = 0;
    [bottomContainView addSubview:signatureLabel];

    void (^nextBlock)(NSString *) = ^(NSString *statusSignature){
        NSString *signature = @"";
        if (DTParamsUtils.validateString(statusSignature)) {
            signature = statusSignature;
        } else {
            if (account.contact.signature && account.contact.signature.length > 0) {
                signature = account.contact.signature;
            } else {
                NSString *localizedStringKey = nil;
                localizedStringKey = @"APP_ADD_SIGNATURE";
                signature = Localized(localizedStringKey, @"");
            }
        }
        NSAttributedString *attributedSignature = [self getAttributedString:signature image:[UIImage imageNamed:@"setting_edit"] font:[UIFont systemFontOfSize:13]];
        signatureLabel.attributedText = attributedSignature;
    };
    
    SignalUserStatesModel *statusModel = [[DTSUserStateManager sharedManager] fetchUserStateModelWithReceptid:recipientId];
    nextBlock(statusModel.signature);
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editSignatureClick:)];
    [bottomContainView addGestureRecognizer:tap];

    self.stateView = [[DTActiveStateView alloc] initWithStyle:DTActiveStateStylePlentiful recipientId:[TSAccountManager localNumber]];
    self.stateView.delegate = self;
    self.stateView.setSignatureHandler = ^(NSString * _Nullable statusSignsture) {
        nextBlock(statusSignsture);
    };
    [bottomContainView addSubview:self.stateView];
    [self.stateView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeBottom];
    [self.stateView autoSetDimension:ALDimensionHeight toSize:60];
            
    NSString *statusString = [[DTSUserStateManager sharedManager] getUserStateStringWithUserStateType:statusModel.status];
    BOOL isManualStatus = [[DTSUserStateManager sharedManager] isManualStatus:statusModel.status];
    if (isManualStatus) {
        NSString *timeStampString = [DTSUserStateManager getManualStatusEndDescWithTimestamp:[statusModel.timeStamp integerValue]];
        [self.stateView updateStateWithTitle:statusString
                                    subtitle:timeStampString
                                notification:!statusModel.pauseNotification];
    } else {
        [self.stateView updateStateWithTitle:statusString
                                    subtitle:nil
                                notification:YES];
    }
    
    [signatureLabel autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [signatureLabel autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [signatureLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:20];
    [signatureLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stateView withOffset:0];
    
    return cell;
}

- (UITableViewCell *)newCell {
    return [OWSTableItem newCellWithBackgroundColor:Theme.backgroundColor];
}

- (void)gotoActiveStateSetting {
//    DTPersonActiveStateViewController *activeStateVC = [DTPersonActiveStateViewController new];
    SignalUserStatesModel *localModel = [[DTSUserStateManager sharedManager] fetchUserStateModelWithReceptid:TSAccountManager.localNumber];
    DTStatusSettingController *statusVC = [DTStatusSettingController new];
    BOOL isManualStatus = [[DTSUserStateManager sharedManager] isManualStatus:localModel.status];
    if (isManualStatus) {
        statusVC.stateModel = localModel;
    }
    [self.navigationController pushViewController:statusVC animated:YES];
}

- (void)editSignatureClick:(UITapGestureRecognizer *)tap {
    OWSContactsManager *contactManager = Environment.shared.contactsManager;
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    SignalAccount *account = [contactManager signalAccountForRecipientId:recipientId];
    Contact *contact = account.contact;
    
    SignalUserStatesModel *statusModel = [[DTSUserStateManager sharedManager] fetchUserStateModelWithReceptid:recipientId];
    
    DTEditPersonInfoController *editNameVC = [DTEditPersonInfoController new];
    NSString *defaultEditText = nil;
    
    if (DTParamsUtils.validateString(statusModel.signature)) {
        defaultEditText = statusModel.signature;
    } else {
        defaultEditText = DTParamsUtils.validateString(contact.signature) ? contact.signature : @"";
    }
    [editNameVC configureWithRecipientId:[TSAccountManager sharedInstance].localNumber withType:DTEditPersonInfoTypeSignature defaultEditText:defaultEditText];
    [self.navigationController pushViewController:editNameVC animated:true];
}

- (void)tapCopyNumberAction:(UIGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    NSString *recipientId = [TSAccountManager localNumber];
    
    if (recipientId) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = recipientId;
        
        NSString *fullPrefix = Localized(@"CONTACT_NUMBER_DESCRIPTION_HEADER", @"copy to pastboard");
        NSString *prefix = [fullPrefix substringToIndex:fullPrefix.length - 2];
        [DTToastHelper toastWithText:[prefix stringByAppendingString:Localized(@"COPY_TO_PASTBOARD", @"copy to pastboard")] durationTime:2];
    }
}

- (void)tapCopyEmailGesture:(UIGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    SignalAccount *account = [Environment.shared.contactsManager signalAccountForRecipientId:[TSAccountManager localNumber]];
    NSString *email = account.contact.email;
    
    if (email) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = email;

        NSString *fullPrefix = Localized(@"CONTACT_EMAIL_DESCRIPTION_HEADER", @"copy to pastboard");
        NSString *prefix = [fullPrefix substringToIndex:fullPrefix.length - 2];
        [DTToastHelper toastWithText:[prefix stringByAppendingString:Localized(@"COPY_TO_PASTBOARD", @"copy to pastboard")] durationTime:2];
    }
}

- (void)presentAlertWithErrorDescription:(NSString *)description
{
    UIAlertController *alert;
    alert = [UIAlertController
        alertControllerWithTitle:Localized(@"COMMON_NOTICE_TITLE", @"Alert view title")
                         message:description
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:Localized(@"OK", @"")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                // do nothing
                                            }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showInviteFlow
{
    DDLogDebug(@"%@ Inviting friends", self.logTag);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            // get invite code
            [[TSAccountManager sharedInstance] getInviteCodeSuccess:^(id responseObject){
                BOOL        codeFormatOk = FALSE;
                NSString    *inviteCode  = nil;
                // invite code chars must be in 0-9,a-z,A-Z with fixed length 32.
                NSUInteger  fixedCodeLen = 32;
                NSNumber    *remained    = nil;
                NSNumber    *total       = nil;
                
                do {
                    if (![responseObject isKindOfClass:[NSDictionary class]]) {
                        DDLogError(@"%@ Failed retrieval of invite code. Response had unexpected format.", self.logTag);
                        break;
                    }
                    
                        inviteCode = [(NSDictionary *)responseObject objectForKey:@"code"];
                    if (!inviteCode) {
                        DDLogError(@"%@ Failed retrieval of invite code. Response had no code.", self.logTag);
                        break;
                    }
                
                    // trim invite code whitespace and newline
                    inviteCode = [inviteCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (0 < inviteCode.length && fixedCodeLen != inviteCode.length) {
                        DDLogError(@"%@ Error format of invite code: %@", self.logTag, inviteCode);
                        break;
                    }

                    total = [(NSDictionary *)responseObject objectForKey:@"total"];
                    if (!total) {
                        DDLogError(@"%@ Failed retrieval of invite code. Response had no total.", self.logTag);
                        break;
                    }
                    
                    remained = [(NSDictionary *)responseObject objectForKey:@"remaining"];
                    if (!remained) {
                        DDLogError(@"%@ Failed retrieval of invite code. Response had no remaining.", self.logTag);
                        break;
                    }
                    codeFormatOk = TRUE;
                } while (FALSE);
                
                __weak AppSettingsViewController *weakSelf = self;

                if (FALSE == codeFormatOk) {
                    // invite code format is incorrect.
                    [weakSelf presentAlertWithErrorDescription:OWSErrorMakeUnableToProcessServerResponseError().localizedDescription];
                } else if ([remained isEqualToNumber:[NSNumber numberWithInt:0]] && inviteCode.length == 0) {
                    // there is no more avaliable invite code.
                    [weakSelf presentAlertWithErrorDescription:Localized(@"SETTINGS_NO_MORE_INVITE_CODE", @"Invite code")];
                } else {
                    // got invite code successfully.
                
                    NSString* inviteMessage = [[NSString alloc] initWithString:[NSString stringWithFormat:@"Welcome to Wea: https://testflight.apple.com/join/OMjRPVyN \nYour invite code：%@", inviteCode]];
                    
                    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[ inviteMessage ] applicationActivities:@[]];
                    
                    activityController.completionWithItemsHandler = ^void(UIActivityType __nullable activityType,
                                                                          BOOL completed,
                                                                          NSArray *__nullable returnedItems,
                                                                          NSError *__nullable activityError) {
                        // complete handler
                        DDLogDebug(@"share result:%d", completed);
                    };
                    
                    [weakSelf presentViewController:activityController animated:YES completion:nil];
                }
            } failure:^(NSError *error){
                // should be network problems.
                __weak AppSettingsViewController *weakSelf = self;
                [weakSelf presentAlertWithErrorDescription:error.localizedDescription];
            }];
        });
    });
 
    //InviteFriendsViewController *vc = [[InviteFriendsViewController alloc] init];
    //[self.navigationController pushViewController:vc animated:YES];
}

- (void)showPrivacy
{
    PrivacySettingsTableViewController *vc = [[PrivacySettingsTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showNotifications
{
    NotificationSettingsViewController *vc = [[NotificationSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showLinkedDevices
{
    OWSLinkedDevicesTableViewController *vc =
        [[UIStoryboard main] instantiateViewControllerWithIdentifier:@"OWSLinkedDevicesTableViewController"];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAdvanced
{
    AdvancedSettingsTableViewController *vc = [[AdvancedSettingsTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAbout
{
    AboutTableViewController *vc = [[AboutTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showDebugUI
{
    [DebugUITableViewController presentDebugUIFromViewController:self];
}

#pragma mark - Unregister & Re-register

- (void)unregisterUser
{
    [self showDeleteAccountUI:YES];
}

- (void)deleteUnregisterUserData
{
    [self showDeleteAccountUI:NO];
}

- (void)showDeleteAccountUI:(BOOL)isRegistered
{
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:Localized(@"CONFIRM_ACCOUNT_DESTRUCTION_TITLE", @"")
                                            message:Localized(@"CONFIRM_ACCOUNT_DESTRUCTION_TEXT", @"")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"PROCEED_BUTTON", @"")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                          [self deleteAccount:isRegistered];
                                                      }]];
    [alertController addAction:[OWSAlerts cancelAction]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)deleteAccount:(BOOL)isRegistered
{
    if (isRegistered) {
        [ModalActivityIndicatorViewController
         presentFromViewController:self
         canCancel:NO
         backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
//            [TSAccountManager
//             unregisterTextSecureWithSuccess:^{
//                [SignalApp resetAppData];
//            }
//             failure:^(NSError *error) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [modalActivityIndicator dismissWithCompletion:^{
//                        [OWSAlerts
//                         showAlertWithTitle:Localized(@"UNREGISTER_SIGNAL_FAIL", @"")];
//                    }];
//                });
//            }];
            DispatchMainThreadSafe(^{
                [RegistrationUtils kickedOffToRegistration];
            });
        }];
    } else {
        [SignalApp resetAppData];
    }
}

- (void)reregisterUser
{
    [RegistrationUtils showReregistrationUIFromViewController:self];
}

-(BOOL)hidesBottomBarWhenPushed
{
    return NO;
}

- (NSMutableAttributedString *)getAttributedString:(NSString *)content image:(UIImage *)image font:(UIFont *)font {
    NSMutableAttributedString *contentAtt = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  ",content] attributes:@{NSFontAttributeName : font}];
    NSTextAttachment *imageMent = [[NSTextAttachment alloc] init];
    imageMent.image = image;
    CGFloat paddingTop = font.lineHeight - font.pointSize + 2;
    imageMent.bounds = CGRectMake(0, -paddingTop, font.lineHeight, font.lineHeight);
    NSAttributedString *imageAtt = [NSAttributedString attributedStringWithAttachment:imageMent];
    [contentAtt appendAttributedString:imageAtt];
    return contentAtt;
}

#pragma mark - OWSNavigationChildController

- (BOOL)prefersNavigationBarHidden {
    return YES;
}

@end

