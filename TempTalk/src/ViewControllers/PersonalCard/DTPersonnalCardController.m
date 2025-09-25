//
//  DTPersonalCardController.m
//  Signal
//
//  Created by hornet on 2021/11/3.
//

#import "DTPersonalCardController.h"
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSAccountManager.h>
#import "DTPersonalCardToolView.h"
#import "DTPersonalGenderController.h"
#import "DTSUserStateManager.h"
#import <SignalServiceKit/SignalAccount.h>
#import <SignalServiceKit/UIImage+OWS.h>
#import "AvatarViewHelper.h"
#import <SignalServiceKit/OWSRequestFactory.h>
#import <SignalServiceKit/TSNetworkManager.h>
#import <SignalServiceKit/DTToastHelper.h>
#import <SignalServiceKit/DTParamsBaseUtils.h>
#import <SignalServiceKit/OWSUploadOperation.h>
#import <SignalServiceKit/TSAttachmentStream.h>
#import "DTProfileAttachmentEntity.h"
#import <SignalServiceKit/SSKCryptography.h>
#import <SignalServiceKit/MIMETypeUtil.h>
#import <SignalServiceKit/NSError+MessageSending.h>
#import <SignalServiceKit/OWSError.h>
#import <SignalCoreKit/Threading.h>
#import <SignalServiceKit/SignalServiceKit-swift.h>
#import <SignalMessaging/Theme.h>
#import "ConversationViewController.h"
#import "DTMultiCallManager.h"
#import "DTEditPersonInfoController.h"
#import "DTPersonalCardController+ShareContact.h"
#import "DTQuickActionCell.h"
#import "DTCardAlertViewController.h"
#import <SignalServiceKit/UIButton+DTAppEnlargeEdge.h>


NSString *kDTPersonnalCardHeaderCellIdentifier = @"DTPersonnalCardHeaderCellIdentifier";
NSString *kDTPersonnalCardMainCellIdentifier = @"DTPersonnalCardMainCellIdentifier";

// 通话类型
typedef NS_ENUM(NSInteger, DTLongPressType) {
    DTLongPressTypeEmail = 0,//eamil
    DTLongPressTypeID,//id
    DTLongPressTypeName,//Name
    DTLongPressTypeLeader,//Leader
    DTLongPressTypeDotLeader,//DotLeader
};


/// 个人名片页面
@interface DTPersonalCardController ()<OWSTableViewControllerDelegate,AvatarViewHelperDelegate,DTSUserStateProtocol,DTQuickActionCellDelegate,DTCardAlertViewControllerDelegate>
@property (nonatomic, strong) OWSTableViewController *tableViewController;
@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) NSString *recipientId;
@property (nonatomic, strong) AvatarImageView *iconImage;
@property (nonatomic, strong) UIImageView *userStateImageView;
@property (nonatomic, readonly) AvatarViewHelper *avatarViewHelper;
@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, strong) UIImage *avatarImage;
@property (nonatomic, strong) DTProfileAttachmentEntity *attachmentEntity;
@property (nonatomic, assign) DTPersonnalCardType type;
@property (nonatomic, strong) TSContactThread *contactThread;
@property (nonatomic, assign) BOOL viewDidAppear;//view是否已经渲染完成
@property (nonatomic, strong) UIButton *backBtn;//view是否已经渲染完成
@end

@implementation DTPersonalCardController
#pragma mark life cycle

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFAFAFA];
    [self creatNav];
    
    [self createViews];
    _avatarViewHelper = [AvatarViewHelper new];
    _avatarViewHelper.delegate = self;
}

- (void)creatNav {
    [self.view addSubview:self.backBtn];
    [self.backBtn autoPinTopToSuperviewMarginWithInset:10];
    [self.backBtn autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view withOffset:21];
    [self.backBtn autoSetDimension:ALDimensionHeight toSize:24];
    [self.backBtn autoSetDimension:ALDimensionWidth toSize:24];
    [self.backBtn dtApp_setEnlargeEdgeWithTop:10 right:10 bottom:10 left:10];
}
- (void)createViews {
    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    _tableViewController.view.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFAFAFA];
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.backBtn];
    [_tableViewController.view autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.view];
    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableViewController.tableView.estimatedRowHeight = 60;
    self.tableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableViewController.tableView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFAFAFA];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[DTSUserStateManager sharedManager] addDelegate:self];
    [self updateTableContents];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
}


- (void)dealloc {
    OWSLogInfo(@"");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[DTSUserStateManager sharedManager] removeDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = true;
    [self requestUserMessage];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.viewDidAppear = true;
    [self performReloadUserStateSelectorWithDelayTime:0.0];
}

- (void)applyTheme {
    [super applyTheme];
    [self updateTableContents];
    self.view.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFAFAFA];
    self.tableViewController.tableView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFAFAFA];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.viewDidAppear = false;
    self.navigationController.navigationBar.hidden = false;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)configureWithRecipientId:(NSString *)recipientId withType:(DTPersonnalCardType)type {
//    self.title = NSLocalizedString(@"CONTACT_PERSONAL_CARD_VIEW_TITLE", @"Title for personnal card view.");
    self.type = type;
    self.recipientId = recipientId;
    self.contactThread = [TSContactThread getOrCreateThreadWithContactId:self.recipientId];
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        self.contact = account.contact;
    }];
}

- (void)signalAccountsDidChange:(NSNotification *)notify {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        self.contact = account.contact;
    }];
    [self performUpdateTableContentsWithDelayTime:0.5];
}

- (void)performUpdateTableContentsWithDelayTime:(NSTimeInterval)time {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTableContents) object:nil];
    [self performSelector:@selector(updateTableContents) withObject:nil afterDelay:time inModes:@[NSDefaultRunLoopMode]];
}

- (void)updateTableContents {
    
    @weakify(self)
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *topSection = [OWSTableSection new];
    
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId];
    NSString *sigString = account.contact.signature;
    
    [topSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self personCardHeaderCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:^{
    }]];
    if (sigString.length) {
        [topSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
            @strongify(self)
            return [self signatureInfoCell];
        } customRowHeight:UITableViewAutomaticDimension actionBlock:^{
            @strongify(self)
            if (self.type == DTPersonnalCardTypeSelf_CanEdit) {
                [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_SIGNATURE",@"") detail:sigString type:DTCardAlertViewTypeTextView maxLength:80 tag:10002];
            } else {
                [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_SIGNATURE",@"") detail:sigString type:DTCardAlertViewTypeDefault maxLength:80 tag:10002];
            }
        }]];
    }
    //分享名片 语音通话 发消息的快捷回复
    [topSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self quickActionCell];
    } customRowHeight:96 actionBlock:^{
        
    }]];
    
    OWSTableSection *contactsSection = [OWSTableSection new];
    [contactsSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self cornerRadiusCell];
    } customRowHeight:16 actionBlock:^{
        
    }]];
    
    [contactsSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self sectionHeaderCellWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_CONTACT_INFO",@"")];
    } customRowHeight:40 actionBlock:^{
        
    }]];
    [contactsSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        SEL selector = @selector(longPressIDClick:);
        return [self personCardForOtherWithTitle:NSLocalizedString(@"PERSON_CARD_ID",@"") detaileText:self.recipientId longPressSel:selector accessory:UITableViewCellAccessoryNone];
    } customRowHeight:36 actionBlock:^{
        
    }]];
    
    NSString *email = self.contact.email;
    if (email && email.length >0) {
        [contactsSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
            SEL selector = @selector(longPressEmailClick:);
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"PERSON_CARD_EMAIL",@"") detaileText:self.contact.email longPressSel:selector accessory:UITableViewCellAccessoryNone];
        } customRowHeight:36 actionBlock:^{
            
        }]];
    }
    contactsSection = [self addTimeZoneWith:contactsSection];
    OWSTableSection *organizationInfoSection = [OWSTableSection new];
    [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self sectionHeaderCellWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_ORGANIZATION_INFO",@"")];
    } customRowHeight:36 actionBlock:^{
        
    }]];
    NSArray *roleNames = self.contact.protectedConfigs.binancians.roleNames;
    //    NSArray *roleNames = @[@"Product Manager",@"Front-end Dev",@"Back-end Dev",@"Product Owner",@"Release Management"];
    if (roleNames.count) {
        NSString *roleNameString = nil;
        for (NSString *roleName in roleNames) {
            if (roleName.length && !roleNameString.length) {
                roleNameString = [NSString stringWithFormat:@"%@",roleName];
            } else if (roleName.length && roleNameString.length) {
                roleNameString = [NSString stringWithFormat:@"%@ | %@",roleNameString,roleName];
            }
        }
        
        [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull {
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_ROLE",@"") detaileText:roleNameString longPressSel:nil accessory:UITableViewCellAccessoryDisclosureIndicator];
        } customRowHeight:36 actionBlock:^{
            @strongify(self)
            [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_ROLES",@"") detail:roleNameString type:DTCardAlertViewTypeDefault maxLength:0 tag:0];
        }]];
    }
    
    NSArray *buNamePaths = self.contact.protectedConfigs.binancians.buNamePaths;
    if (buNamePaths.count) {
        [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull {
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_BU",@"") detaileText:buNamePaths.lastObject longPressSel:nil accessory:UITableViewCellAccessoryDisclosureIndicator];
        } customRowHeight:36 actionBlock:^{
            @strongify(self)
            NSString *buNameString = nil;
            for (NSString *buName in buNamePaths) {
                if (buName.length && !buNameString.length) {
                    buNameString = buName;
                } else if (buName.length && buNameString.length) {
                    buNameString = [NSString stringWithFormat:@"%@ > %@",buNameString,buName];
                }
            }
            [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_UNIT",@"") detail:buNameString type:DTCardAlertViewTypeDefault maxLength:0 tag:0];
        }]];
    }
    
    NSArray *groupNamePaths = self.contact.protectedConfigs.binancians.groupNamePaths;
    if (groupNamePaths.count) {
        [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull {
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_DEPT",@"") detaileText:groupNamePaths.lastObject longPressSel:nil accessory:UITableViewCellAccessoryDisclosureIndicator];
        } customRowHeight:36 actionBlock:^{
            @strongify(self)
            NSString *groupNameString = nil;
            for (NSString *groupName in groupNamePaths) {
                if (groupName.length && !groupNameString.length) {
                    groupNameString = groupName;
                } else if (groupName.length && groupNameString.length) {
                    groupNameString = [NSString stringWithFormat:@"%@ > %@",groupNameString,groupName];
                }
            }
            [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_DEPARTMENT",@"") detail:groupNameString type:DTCardAlertViewTypeDefault maxLength:0 tag:0];
        }]];
    }
    
    NSString *directParentName = self.contact.protectedConfigs.binancians.directParentName;
    if (directParentName.length) {
        [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull {
            SEL longPressLeaderClick = @selector(longPressLeaderClick:);
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_LEADER",@"") detaileText:directParentName longPressSel:longPressLeaderClick accessory:UITableViewCellAccessoryDisclosureIndicator];
        } customRowHeight:36 actionBlock:^{
            @strongify(self)
            [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_TITLE_LEADER",@"") detail:directParentName type:DTCardAlertViewTypeDefault maxLength:0 tag:0];
        }]];
    }
    NSString *DotLineLeader = self.contact.protectedConfigs.binancians.localParentName;
    if (DotLineLeader.length) {
        [organizationInfoSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull {
            SEL longPressDotLineLeaderClick = @selector(longPressDotLineLeaderClick:);
            @strongify(self)
            return [self personCardForOtherWithTitle:NSLocalizedString(@"CONTACT_PROFILE_Dot_Line_LEADER",@"") detaileText:DotLineLeader longPressSel:longPressDotLineLeaderClick accessory:UITableViewCellAccessoryDisclosureIndicator];
        } customRowHeight:36 actionBlock:^{
            @strongify(self)
            [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_TITLE_DOT_LINE_LEADER",@"") detail:DotLineLeader type:DTCardAlertViewTypeDefault maxLength:0 tag:0];
        }]];
    }
    
    [contents addSection:topSection];
    [contents addSection:contactsSection];
    ContactProtectedBinanciansConfigs *configs = self.contact.protectedConfigs.binancians;
    if (configs) {
        [contents addSection:organizationInfoSection];
    }
    self.tableViewController.contents = contents;
}

- (void)showDetailAlertViewControllerWithTitle:(NSString *)title detail:(NSString *) contentString type:(DTCardAlertViewType)type maxLength:(NSUInteger) maxLength tag:(int)tag{
    DTCardAlertViewController *alertViewController = [[DTCardAlertViewController alloc] init:self.recipientId type:type];
    alertViewController.titleString = title;
    alertViewController.contentString = contentString;
    if (maxLength > 0) {
        alertViewController.maxLength = maxLength;
    }
    alertViewController.tag = tag;
    alertViewController.alertDelegate = self;
    alertViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [self.navigationController presentViewController:alertViewController animated: false completion:nil];
}

- (UITableViewCell *)cornerRadiusCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCellSectionRadiusStyleIdentifier"];
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFAFAFA];
    
    return cell;
}

- (UITableViewCell *)sectionHeaderCellWithTitle:(NSString *)title{
    UITableViewCell *sectionHeaderCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCellSectionHeaderStyleIdentifier"];
    UILabel *titleLabel = [UILabel new];
    [sectionHeaderCell.contentView addSubview:titleLabel];
    [titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:sectionHeaderCell.contentView];
    [titleLabel autoPinLeadingToSuperviewMargin];
    [titleLabel autoPinTrailingToSuperviewMargin];
    [titleLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:sectionHeaderCell.contentView];
    titleLabel.text = title;
    titleLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:16];
    sectionHeaderCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIColor *lightBgColor = [UIColor colorWithRGBHex:0xFFFFFF];
    UIColor *darkBgColor = [UIColor colorWithRGBHex:0x181A20];
    sectionHeaderCell.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    sectionHeaderCell.contentView.backgroundColor =  Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    return sectionHeaderCell;
}

- (DTQuickActionCell *)quickActionCell {
    DTQuickActionCell *cell = [[DTQuickActionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:@"UITableViewCellStyleQuickActionCell"];
    cell.cellDelegate = self;
    UIColor *lightBgColor = [UIColor colorWithRGBHex:0xFAFAFA];
    UIColor *darkBgColor = [UIColor colorWithRGBHex:0x2B3139];
    cell.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    cell.contentView.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    if (self.type == DTPersonnalCardTypeOther && self.recipientId.length > 6) {
        cell.haveCall = true;
    } else {
        cell.haveCall = false;
    }
    [cell setupAllSubViews];
    return cell;
}

- (UITableViewCell *)signatureInfoCell {
    UIColor *lightBgColor = [UIColor colorWithRGBHex:0xFAFAFA];
    UIColor *darkBgColor = [UIColor colorWithRGBHex:0x2B3139];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:@"UITableViewCellStyleSignatureInfo"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UILabel *signatureLabel = [UILabel new];
    [cell.contentView addSubview:signatureLabel];
    
    cell.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    cell.contentView.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    __block SignalAccount *account;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:readTransaction];
    }];
    NSString *sigString = account.contact.signature;
    NSMutableAttributedString *sigAttString = [self getAttributesString:sigString withFont:14];
    signatureLabel.attributedText = sigAttString;
//    signatureLabel.font = [UIFont systemFontOfSize:14];
    signatureLabel.numberOfLines = 2;
    [signatureLabel autoPinLeadingAndTrailingToSuperviewMargin];
    [signatureLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:cell.contentView ];
    [signatureLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView withOffset:-24];
    return cell;
}

- (NSMutableAttributedString *)getAttributesString:(nonnull NSString *)string withFont:(int)fontSize{
    string = string?:@"";
    if (string.length ==0 || !string) {
        return nil;
    }
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 5;// 行间隔
    paragraphStyle.firstLineHeadIndent = 0;// 行间隔
    paragraphStyle.headIndent = 0;// 行间隔
    NSMutableAttributedString *attributes = [[NSMutableAttributedString alloc] initWithString:string];
    [attributes addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:fontSize] range:NSMakeRange(0, string.length)];
    [attributes addAttribute:NSForegroundColorAttributeName value:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x707A8A] range:NSMakeRange(0, string.length)];
    [attributes addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, string.length)];
    return attributes;
}

- (UITableViewCell *)personInfoForCallWithImage:(NSString *) iconImageName actionTitle:(NSString *)actionTitle {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:@"UITableViewCellStyleCallAction"];
    
    UIStackView *contentRow = [[UIStackView alloc]init];
    contentRow.axis = UILayoutConstraintAxisHorizontal;
    contentRow.alignment = UIStackViewAlignmentCenter;
    contentRow.spacing = 12;
    [cell.contentView addSubview:contentRow];
    [contentRow autoCenterInSuperview];
    
    UIButton *actionBtn = [[UIButton alloc] init];
    UIImage *image = [[UIImage imageNamed:iconImageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [actionBtn setBackgroundImage:image forState:UIControlStateNormal];
    [actionBtn setBackgroundImage:image forState:UIControlStateHighlighted];
    actionBtn.tintColor = Theme.hyperLinkColor;
    [contentRow addArrangedSubview:actionBtn];
    [actionBtn autoSetDimensionsToSize:CGSizeMake(19, 19)];
    
    UILabel *actionLabel = [[UILabel alloc] init];
    actionLabel.text = actionTitle;
    actionLabel.font = [UIFont ows_semiboldFontWithSize:18];
    actionLabel.textColor = Theme.hyperLinkColor;
    [contentRow addArrangedSubview:actionLabel];
    
    return cell;
}

- (UITableViewCell *)personCardForOtherWithTitle:(NSString *)title detaileText:(NSString *)detail longPressSel:(nullable SEL)seletor accessory:(UITableViewCellAccessoryType )accessoryType{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:@"UITableViewCellStyleValue1"];
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont ows_regularFontWithSize:14.f];
    cell.textLabel.textColor = Theme.primaryTextColor;
    
    UIColor *lightBgColor = [UIColor colorWithRGBHex:0xFFFFFF];
    UIColor *darkBgColor = [UIColor colorWithRGBHex:0x181A20];
    cell.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    cell.contentView.backgroundColor =  Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    
    UILabel *detailTextLabel = [UILabel new];
    detailTextLabel.font = [UIFont systemFontOfSize:14];
    detailTextLabel.textColor = Theme.secondaryTextAndIconColor;
    detailTextLabel.text = detail;
    detailTextLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:detailTextLabel];
    [detailTextLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:cell.contentView withOffset:120];
    [detailTextLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:cell.contentView withOffset:-25];
    [detailTextLabel autoVCenterInSuperview];
    if (seletor) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:seletor];
        longPress.minimumPressDuration = 1;
        [cell.contentView addGestureRecognizer:longPress];
    }
    cell.detailTextLabel.textColor = Theme.secondaryTextAndIconColor;
    cell.accessoryType = accessoryType;
    return cell;
}

- (UITableViewCell *)personCardForSelfWithTitle:(NSString *)title detaileText:(NSString *)detail longPressSel:(nullable SEL)seletor longPressDuration:(NSTimeInterval)interval accessoryType:(UITableViewCellAccessoryType)type{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:@"UITableViewCellStyleValue1"];
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont ows_regularFontWithSize:14.f];
    cell.textLabel.textColor = Theme.primaryTextColor;
    cell.backgroundColor = Theme.tableCellBackgroundColor;
    cell.contentView.backgroundColor = Theme.tableCellBackgroundColor;
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.font = [UIFont ows_regularFontWithSize:14.f];
    cell.detailTextLabel.textColor = Theme.secondaryTextAndIconColor;
    cell.detailTextLabel.numberOfLines = 2;
    if (seletor) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:seletor];
        longPress.minimumPressDuration = interval;
        [cell.contentView addGestureRecognizer:longPress];
    }
    [cell setAccessoryType:type];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)longPressNameClick:(UILongPressGestureRecognizer *)longPress {
    if (self.contact) {
        NSString *fullName = self.contact.fullName;
        if (fullName && fullName.length >0) {
            [self longPressAction:longPress withType:DTLongPressTypeName];
        }
    }
}

- (void)longPressEmailClick:(UILongPressGestureRecognizer *)longPress {
    if (self.contact) {
        NSString *email = self.contact.email;
        if (email && email.length >0) {
            [self longPressAction:longPress withType:DTLongPressTypeEmail];
        }
    }
}

- (void)longPressIDClick:(UILongPressGestureRecognizer *)longPressGesture {
    if (self.recipientId) {
        [self longPressAction:longPressGesture withType:DTLongPressTypeID];
    }
}

- (void)longPressLeaderClick:(UILongPressGestureRecognizer *)longPressGesture {
    if (self.recipientId) {
        [self longPressAction:longPressGesture withType:DTLongPressTypeLeader];
    }
}

- (void)longPressDotLineLeaderClick:(UILongPressGestureRecognizer *)longPressGesture{
    if (self.recipientId) {
        [self longPressAction:longPressGesture withType:DTLongPressTypeDotLeader];
    }
}


- (void)longPressAction:(UILongPressGestureRecognizer *)longPressGesture withType:(DTLongPressType) type{
    UIMenuItem *copyMenuItem = nil;
    if (longPressGesture.state == UIGestureRecognizerStateBegan && type == DTLongPressTypeEmail) {
        //        [self becomeFirstResponder];
        //        copyMenuItem = [[UIMenuItem alloc]initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyEmail)];
        [self copyEmail];
        
    } else if (longPressGesture.state == UIGestureRecognizerStateBegan && type == DTLongPressTypeID) {
        //        copyMenuItem = [[UIMenuItem alloc]initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyID)];
        [self copyID];
    } else if (longPressGesture.state == UIGestureRecognizerStateBegan && type == DTLongPressTypeName) {
        //        copyMenuItem = [[UIMenuItem alloc]initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyName)];
        [self copyName];
    } else if (longPressGesture.state == UIGestureRecognizerStateBegan && type == DTLongPressTypeLeader) {
        //        copyMenuItem = [[UIMenuItem alloc]initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyLeader)];
        [self copyLeader];
    }else if (longPressGesture.state == UIGestureRecognizerStateBegan && type == DTLongPressTypeDotLeader) {
        //        copyMenuItem = [[UIMenuItem alloc]initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyDotLeader)];
        [self copyDotLeader];
    } else {
        return;
    }
    return;
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:[NSArray arrayWithObjects:copyMenuItem, nil]];
    [menuController setTargetRect:longPressGesture.view.frame inView:longPressGesture.view.superview];
    [menuController setMenuVisible:YES animated:YES];
}

- (void)copyEmail {
    if (self.contact) {
        NSString *email = self.contact.email;
        if (email && email.length >0) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = self.contact.email;
            [DTToastHelper toastWithText:NSLocalizedString(@"COPYID", @"copy to pastboard") inView:self.view durationTime:2];
        }
    }
}

- (void)copyName {
    if (self.contact.fullName.length) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.contact.fullName;
        [DTToastHelper toastWithText:NSLocalizedString(@"COPYID", @"copy to pastboard") inView:self.view durationTime:2];
    }
}

- (void)copyID {
    if (self.recipientId) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.recipientId;
        [DTToastHelper toastWithText:NSLocalizedString(@"COPYID", @"copy to pastboard") inView:self.view durationTime:2];
    }
}

//warning 待处理
- (void)copyLeader {
    NSString *directParentName = self.contact.protectedConfigs.binancians.directParentName;
    if (directParentName) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = directParentName;
        [DTToastHelper toastWithText:NSLocalizedString(@"COPYID", @"copy to pastboard") inView:self.view durationTime:2];
    }
}

- (void)copyDotLeader {
    NSString *directParentName = self.contact.protectedConfigs.binancians.localParentName;
    if (directParentName) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = directParentName;
        [DTToastHelper toastWithText:NSLocalizedString(@"COPYID", @"copy to pastboard") inView:self.view durationTime:2];
    }
}

- (void)tapNameClick:(UITapGestureRecognizer *)tapRecognizer {
    if (self.type == DTPersonnalCardTypeSelf_CanEdit) {
        if (self.contact) {
            NSString *fullName = self.contact.fullName;
            if (fullName && fullName.length >0) {
                [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_NAME", @"copy to pastboard") detail:fullName type:DTCardAlertViewTypeTextView maxLength:30 tag:10001];
            }
        }
    } else {
        if (self.contact) {
            NSString *fullName = self.contact.fullName;
            if (fullName && fullName.length >0) {
                [self showDetailAlertViewControllerWithTitle:NSLocalizedString(@"CONTACT_PROFILE_BUSINESS_NAME", @"copy to pastboard") detail:fullName type:DTCardAlertViewTypeDefault maxLength:30 tag:0];
            }
        }
    }
}


- (BOOL)isvalid:(NSString *)string {
    return string && string.length>0;
}
- (OWSTableSection *)addTimeZoneWith:(OWSTableSection *)contactsSection {
    if (self.contact) {
        NSNumber *remoteTimeZoneValue;
        NSTimeZone *localZone = [NSTimeZone localTimeZone];
        NSInteger localTimeZoneValue = [localZone secondsFromGMT]/(60*60);//获取当地时间和UTC时间的差值，并转成中间差的小时数
        NSDate *currentDate = [NSDate date];
        if (self.type != DTPersonnalCardTypeOther) {
            remoteTimeZoneValue = @(localTimeZoneValue);//这么写只是为了保证本人直接取用户本地时区
        }else{
            remoteTimeZoneValue = [self convertStringToNumber:self.contact.timeZone];
        }
        NSString* dateStr;
        if (!remoteTimeZoneValue) {
            dateStr = @"";
        }else {
            if ([remoteTimeZoneValue integerValue] == localTimeZoneValue) {//表示当前时区
                NSCalendar *calendar = [NSCalendar currentCalendar];
                NSUInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitTimeZone;
                NSDateComponents *components = [calendar components:unitFlags fromDate:currentDate];
                dateStr = [NSString stringWithFormat:@"%ld:%02ld",(long)components.hour,(long)components.minute];
                NSInteger hour = components.hour;
                NSInteger minute = components.minute;
                if ([self isChineseLanguage] && dateStr) {//用户语言是中文
                    if (hour < 12) {//表示上午
                        if (components.hour == 0 ) {
                            dateStr = [NSString stringWithFormat:@"午夜 %lu:%02lu",hour,minute];
                        }else if(hour >= 1 && hour <12){
                            dateStr = [NSString stringWithFormat:@"%@ %lu:%02lu",NSLocalizedString(@"TIME_AM",@""),hour,minute];
                        }
                    }else if (hour>=12 && hour<24) {//表示下午
                        if (components.hour == 12) {
                            dateStr = [NSString stringWithFormat:@"中午 %lu:%02lu",hour,minute];
                        }else {
                            dateStr = [NSString stringWithFormat:@"%@ %lu:%02lu",NSLocalizedString(@"TIME_PM",@""),hour-12,minute];
                        }
                    }
                }else {//用户语言是其他语言
                    if (hour < 12) {//表示上午
                        if (components.hour == 0 ) {//表示上午0点
                            dateStr = [NSString stringWithFormat:@"12:%02lu MIDNIGHT",minute];
                        }else if(hour >= 1 && hour <12){//表示上午1点到12点
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu %@",hour,minute,NSLocalizedString(@"TIME_AM",@"")];
                        }
                    }else if (hour>=12 && hour<24) {//表示下午
                        if (components.hour == 12) {
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu NOON",hour,minute];
                        }else {
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu %@",hour-12,minute,NSLocalizedString(@"TIME_PM",@"")];
                        }
                    }
                }
            }else {//表示被查看者的时区和用户当前时区不是同一个时区
                NSInteger timeZoneInterval = [remoteTimeZoneValue integerValue] - localTimeZoneValue;
                NSInteger timeInterval = timeZoneInterval * 60 *60;
                NSDate *remoteDate = [self getResultDate:currentDate timeInterval:timeInterval];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                NSUInteger unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitTimeZone;
                //                currentDate = [self getResultDate:currentDate timeInterval:3*60*60];
                NSDateComponents *components = [calendar components:unitFlags fromDate:remoteDate];
                dateStr = [NSString stringWithFormat:@"%ld:%ld",(long)components.hour,(long)components.minute];
                NSInteger hour = components.hour;
                NSInteger minute = components.minute;
                
                if ([self isChineseLanguage] && dateStr) {//表示使用者当前使用的是中文
                    if (hour < 12) {//表示上午
                        if (components.hour == 0 ) {
                            dateStr = [NSString stringWithFormat:@"午夜 12:%02lu",minute];
                        }else if(hour >= 1 && hour <12){
                            dateStr = [NSString stringWithFormat:@"%@ %lu:%02lu",NSLocalizedString(@"TIME_AM",@""),hour,minute];
                        }
                    }else if (hour>=12 && hour<24) {//表示下午
                        if (components.hour == 12) {
                            dateStr = [NSString stringWithFormat:@"中午 %lu:%02lu",hour,minute];
                        }else {
                            dateStr = [NSString stringWithFormat:@"%@ %lu:%02lu",NSLocalizedString(@"TIME_PM",@""),hour-12,minute];
                        }
                    }
                }else {
                    if (hour < 12) {//表示上午
                        if (components.hour == 0 ) {//表示上午0点
                            dateStr = [NSString stringWithFormat:@"12:%02lu MIDNIGHT",minute];
                        }else if(hour >= 1 && hour <12){//表示上午1点到12点
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu %@",hour,minute,NSLocalizedString(@"TIME_AM",@"")];
                        }
                    }else if (hour>=12 && hour<24) {//表示下午
                        if (components.hour == 12) {
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu NOON",hour,minute];
                        }else {
                            dateStr = [NSString stringWithFormat:@"%lu:%02lu %@",hour-12,minute,NSLocalizedString(@"TIME_PM",@"")];
                        }
                    }
                }
            }
        }
        if (dateStr.length >0) {
            @weakify(self)
            [contactsSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
                @strongify(self)
                return [self personCardForOtherWithTitle:NSLocalizedString(@"PERSON_CARD_TIMEZONE",@"") detaileText:dateStr longPressSel:nil accessory:UITableViewCellAccessoryNone];
            } customRowHeight:36 actionBlock:^{
                
            }]];
        }
    }
    return contactsSection;
}

- (void)setAvatarImage:(UIImage *)avatarImage {
    _avatarImage = avatarImage;
    [self updateAvatarView];
}

- (void)updateAvatarView {
    [self uploadAvaterToTheServer];
}

#pragma mark DTSUserStateProtocol
- (void)onUserStatesWebSoketDidConnect {
    OWSLogInfo(@"DTPersonalCardController onUserStatesWebSoketDidConnect: viewDidAppear:%d", _viewDidAppear);
    if (self.viewDidAppear) {
        [self performReloadUserStateSelectorWithDelayTime:0];
    }else {
        [self performReloadUserStateSelectorWithDelayTime:.2];
    }
}
/// 监听服务端指定用户的状态更新
/// @param message 获取到的消息体
- (void)onListenUpdateUserStatusFromServer:(SignalWebSocketRecieveUpdateUserStatusModel *)message {
    OWSLogInfo(@"DTPersonalCardController onListenUpdateUserStatusFromServer: 消息体 :%@ viewDidAppear:%d",[message signal_modelToJSONString], _viewDidAppear);
    if (!self) return;
    NSString *localNumber = self.recipientId;
    if(!localNumber){
        return;
    }
    if (!message.data) {
        return;
    }
    
    if (_viewDidAppear) {
        DispatchMainThreadSafe(^{
            [self dealUserStateWithCache];
        });
    }else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dealUserStateWithCache];
        });
    }
}

- (void)performReloadUserStateSelectorWithDelayTime:(double) time {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateUserState) object:nil];
    [self performSelector:@selector(updateUserState) withObject:nil afterDelay:time inModes:@[NSDefaultRunLoopMode]];
}

- (void)updateUserState {
    OWSLogInfo(@"DTPersonalCardController updateUserState");
    NSString *localNumber = self.recipientId;
    if (!localNumber) {return;}
    DTSUserStateRequestModel *requestModel = [DTSUserStateRequestModel new];
    requestModel.indexpath = nil;
    requestModel.contactIdentifier = localNumber;
    if (!localNumber) {return;}
    __weak typeof(self) weakSelf = self;
    [[DTSUserStateManager sharedManager] getUserStatusActionWithRecipientIdParams:@[requestModel] sucessCallback:^(SignalWebSocketBaseModel *socketResponseModel, id requestParmas) {
        if (!socketResponseModel) {
            weakSelf.userStateImageView.hidden = true;
        }else {
            SignalUserStatesModel *statesModel  = [[DTSUserStateManager sharedManager].userStatusCacheSet objectForKey:localNumber];
            if (!statesModel) {
                weakSelf.userStateImageView.hidden = true;
            }else {
                [weakSelf dealUserStateImage];
                weakSelf.userStateImageView.image = [[DTSUserStateManager sharedManager] getUserStateImageWithUserStateType:statesModel.status];
            }
        }
    }];
    [[DTSUserStateManager sharedManager] addListenUserStatusActionWithIncrementalRecipientIdParams:@[requestModel] sucessCallback:nil];
}

- (void)dealUserStateImage {
    self.userStateImageView.hidden = false;
}
- (void)dealUserStateWithCache {
    OWSLogInfo(@"DTPersonalCardController dealUserStateWithCache: viewDidAppear:%d", _viewDidAppear);
    NSString *localNumber = self.recipientId;
    if (!localNumber) return;
    SignalUserStatesModel *model = [DTSUserStateManager sharedManager].userStatusCacheSet[localNumber];
    if (!model) {return;}
    UIImage *image = [[DTSUserStateManager sharedManager]getUserStateImageWithUserStateType:model.status];
    self.userStateImageView.image = image;
    self.userStateImageView.hidden = false;
}

- (BOOL)canCall {
    NSString *localNumber = [TSAccountManager localNumber];
    NSString *contactIdentifier = self.recipientId;
    return ![contactIdentifier isEqualToString:localNumber] && contactIdentifier.length > 6;
}

- (void)agoraRTMCall {
    [[DTMultiCallManager sharedManager] startCallWithThread:self.contactThread withCallType:DTCallType1v1Video];
}

#pragma mark request
- (void)requestUserMessage {
    if (!self.recipientId) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TSAccountManager sharedInstance] getContactMessageV1ByPhoneNumber:@[self.recipientId] success:^(NSArray *contacts) {
        if (!contacts) {
            return;
        }
        weakSelf.contact = contacts.firstObject;
        DDLogInfo(@"DTPersonalCardController requestUserMessage ::::\n%@",[self.contact signal_modelToJSONString]);
        if(weakSelf.contact){
            [weakSelf.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                SignalAccount *account = [contactsManager signalAccountForRecipientId:weakSelf.recipientId transaction:transation];
                if (!account) {
                    account = [[SignalAccount alloc] initWithRecipientId:weakSelf.recipientId];
                }
                if ([account.contact isEqualToContact:weakSelf.contact]) return;
                account.contact = weakSelf.contact;
                SignalAccount *newAccount = [account copy];
                [contactsManager updateSignalAccountWithRecipientId:weakSelf.recipientId withNewSignalAccount:newAccount withTransaction:transation.transitional_yapWriteTransaction];
            }];
        }
    } failure:^(NSError * _Nonnull error) {
        
    }];
}

- (void)extracted:(DTPersonalCardController *const __weak)weakSelf {
    [[OWSProfileManager sharedManager] updateLocalProfileName:self.contact.fullName avatarImage:self.avatarImage success:^{
        [DTToastHelper hide];
        [weakSelf.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
            OWSContactsManager *contactsManager = Environment.shared.contactsManager;
            SignalAccount *account = [contactsManager signalAccountForRecipientId:weakSelf.recipientId transaction:transation];
            Contact *contact = account.contact;
            NSDictionary *avatar = [[OWSProfileManager sharedManager] localAvatar];
            DDLogInfo(@"DTPersonalCardController uploadAvaterToTheServer ::::\n%@",avatar);
            contact.avatar = avatar;
            SignalAccount *newAccount = [account copy];
            [contactsManager updateSignalAccountWithRecipientId:weakSelf.recipientId withNewSignalAccount:newAccount withTransaction:transation.transitional_yapWriteTransaction];
            [weakSelf.iconImage setImageWithContactAvatar:contact.avatar recipientId:weakSelf.recipientId];
        }];
        
        
    } failure:^{
        [DTToastHelper hide];
        [DTToastHelper toastWithText:NSLocalizedString(@"PROFILE_VIEW_ERROR_UPDATE_FAILED",
                                                       @"Error message shown when a "
                                                       @"profile update fails.")
                              inView:weakSelf.view durationTime:3
                          afterDelay:1];
    }];
}

- (void)uploadAvaterToTheServer {
    [DTToastHelper showHudWithMessage:NSLocalizedString(@"PROFILE_VIEW_SAVING", @"Alert title that indicates the user's profile view is being saved.") inView:self.view];
    __weak typeof(self) weakSelf = self;
    [self extracted:weakSelf];
}

#pragma mark - AvatarViewHelperDelegate
- (NSString *)avatarActionSheetTitle
{
    return NSLocalizedString(
                             @"PROFILE_VIEW_AVATAR_ACTIONSHEET_TITLE", @"Action Sheet title prompting the user for a profile avatar");
}

- (void)avatarDidChange:(UIImage *)image
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(image);
    self.avatarImage = [image resizedImageToFillPixelSize:CGSizeMake(kOWSProfileManager_MaxAvatarDiameter,kOWSProfileManager_MaxAvatarDiameter)];
}


- (UIViewController *)fromViewController {
    return self;
}

- (BOOL)hasClearAvatarAction {
    return false;
}

- (NSString *)clearAvatarActionLabel {
    return NSLocalizedString(@"PROFILE_VIEW_CLEAR_AVATAR", @"Label for action that clear's the user's profile avatar");
}

- (void)clearAvatar {
    
    //    self.iconImage.image = (self.avatarImage
    //            ?: [[UIImage imageNamed:@"profile_avatar_default"]
    //                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);
    //    self.iconImage.tintColor = (self.avatarImage ? nil : [UIColor colorWithRGBHex:0x888888]);
    //    self.iconImage.hidden = self.avatarImage != nil;
    //    self.iconImage.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImage = nil;
    
}


- (void)originalTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.row == 0) {
        CAShapeLayer *normalLayer = [CAShapeLayer new];
        UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(10, 10)];
        normalLayer.path = bezierPath.CGPath;
        normalLayer.fillColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20].CGColor : [UIColor colorWithRGBHex:0xFFFFFF].CGColor;
        UIView *normalBgView = [[UIView alloc] initWithFrame:cell.bounds];
        [normalBgView.layer insertSublayer:normalLayer atIndex:0];
        [cell.contentView addSubview:normalBgView];
    }
}

#pragma mark quickActionCell delegate
- (void)quickActionCell:(DTQuickActionCell *)cell button:(DTLayoutButton *)sender actionType:(DTQuickActionType)type {
    switch (type) {
            //分享
        case DTQuickActionTypeShare:{
            [self showSelectThreadController];
        }
            break;
            //语音通话
        case DTQuickActionTypeCall:{
            if ([self canCall]) {
                [self agoraRTMCall];
            }
        }
            break;
            //消息
        case DTQuickActionTypeMessage:{
            DispatchMainThreadSafe(^{
                TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactId:self.recipientId];
                ConversationViewController *viewController = [ConversationViewController new];
                [viewController configureForThread:contactThread action:ConversationViewActionNone focusMessageId:nil];
                OWSNavigationController *navigationController = (OWSNavigationController *)self.navigationController;
                @weakify(navigationController);
                [navigationController pushViewController:viewController animated:true completion:^{
                    @strongify(navigationController);
                    [navigationController removeToViewController:@"HomeViewController"];
                }];
            });
            
        }
            break;
        default:
            break;
    }
}

- (void)cardAlert:(DTCardAlertViewController * _Nullable)alert actionType:(DTCardAlertActionType)actionType changedText:(NSString *)changedText defaultText:(NSString *)defaultText{
    if (actionType == DTCardAlertActionTypeCancel) {
        return;
    }
    if ([changedText isEqualToString:defaultText]) {
        return;
    }
    if (alert.tag == 10001) {//name
        NSDictionary *parms = @{@"name":changedText};
        if (!changedText || changedText.length == 0) {
            return;
        }
        [self requestForEditPersonInfoWithParams:parms];
    } else if (alert.tag == 10002) {//signature
        NSString * signature= [changedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSDictionary *parms = @{@"signature":signature};
        [self requestForEditPersonInfoWithParams:parms];
    }
}

- (void)requestForEditPersonInfoWithParams:(NSDictionary *) parms{
    OWSLogInfo(@"(DTPersonalCardController):putV1ProfileWithParams: \n %@",parms);
    [DTToastHelper showHudInView:self.view];
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    [ [TSNetworkManager sharedManager] makeRequest:request success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSNumber *status = (NSNumber *)responseObject[@"status"];
        if (responseObject && [status intValue] == 0 ) {//上报成功，更新本地缓存
            NSString *userName = [parms objectForKey:@"name"];
            NSString *signature = [parms objectForKey:@"signature"];
            if (userName && !signature) {
                [self dealPersonInfoNameResponseWithUserName:userName];
            } else if (!userName && signature) {
                [self dealPersonInfoNameResponseWithSignature:signature];
            }
        } 
        else {//上报失败
            [DTToastHelper toastWithText:NSLocalizedString(@"UPDATENAME_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
        }
        [DTToastHelper hide];
        
    } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {//上报失败
        [DTToastHelper hide];
        if(error.code == 403){
            [DTToastHelper toastWithText:NSLocalizedString(@"UPDATENAME_OPREATION_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
        } else {
            [DTToastHelper toastWithText:NSLocalizedString(@"UPDATENAME_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
        }
    }];
}

- (void)dealPersonInfoNameResponseWithUserName:(NSString *)userName {
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        account.contact.fullName = userName;
        SignalAccount *newAccount = [account copy];
        [contactsManager updateSignalAccountWithRecipientId:self.recipientId withNewSignalAccount:newAccount withTransaction:transation.transitional_yapWriteTransaction];
    }];
}

- (void)dealPersonInfoNameResponseWithSignature:(NSString *)signature {
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull transation) {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        SignalAccount *newAccount = [account copy];
        newAccount.contact = [account.contact copy];
        newAccount.contact.signature = signature;
        [contactsManager updateSignalAccountWithRecipientId:self.recipientId withNewSignalAccount:newAccount withTransaction:transation.transitional_yapWriteTransaction];
    }];
}

#pragma mark setter & getter
- (TSNetworkManager *)networkManager {
    return [TSNetworkManager sharedManager];
}

- (void)closeButtonClick:(UIButton *)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}

- (UITableViewCell *)personCardHeaderCell {
    UIColor *lightBgColor = [UIColor colorWithRGBHex:0xFAFAFA];
    UIColor *darkBgColor = [UIColor colorWithRGBHex:0x2B3139];
    
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.separatorInset = UIEdgeInsetsMake(0, UIScreen.mainScreen.bounds.size.width, 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    cell.contentView.backgroundColor = Theme.isDarkThemeEnabled ? darkBgColor : lightBgColor;
    if (self.type == DTPersonnalCardTypeSelf_CanEdit) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView.tintColor = Theme.secondaryTextAndIconColor;
    }else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    UIStackView *containStackView = [[UIStackView alloc] init];
    containStackView.axis = UILayoutConstraintAxisVertical;
    containStackView.alignment = UIStackViewAlignmentCenter;
    containStackView.distribution = UIStackViewDistributionFill;
    [cell.contentView addSubview:containStackView];
    [containStackView autoPinEdgesToSuperviewEdges];
    
    UIButton *closeButton = [UIButton new];
    [closeButton setTitle:NSLocalizedString(@"APP_TEXT_CLOSE",@"")forState:UIControlStateNormal];
    [closeButton setTitleColor: Theme.primaryTextColor forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [closeButton addTarget:self action:@selector(closeButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [containStackView addSubview:closeButton];
    [closeButton autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:containStackView withOffset:5];
    [closeButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:containStackView withOffset:5] ;
    [closeButton autoSetDimension:ALDimensionWidth toSize:50];
    
    if(self.type == DTPersonnalCardTypeSelf_NoneEditWithPresentModel){
        [closeButton autoSetDimension:ALDimensionHeight toSize:30];
        closeButton.hidden = false;
    }else {
        [closeButton autoSetDimension:ALDimensionHeight toSize:0];
        closeButton.hidden = true;
    }
    
    UIStackView *topContentRow = [UIStackView new];
    topContentRow.spacing = 10;
    topContentRow.axis = UILayoutConstraintAxisHorizontal;
    topContentRow.alignment = UIStackViewAlignmentCenter;
    topContentRow.distribution = UIStackViewDistributionFill;
    topContentRow.layoutMarginsRelativeArrangement = YES;
    topContentRow.layoutMargins = UIEdgeInsetsMake(0, 18, 0, 15);
    [containStackView addArrangedSubview:topContentRow];
    [topContentRow autoPinEdgesToSuperviewMarginsExcludingEdge:ALEdgeBottom];
    [topContentRow autoSetDimension:ALDimensionHeight toSize:112];
    
    UIStackView *top_rightContentView = [UIStackView new];
    top_rightContentView.spacing = 10;
    top_rightContentView.axis = UILayoutConstraintAxisVertical;
    top_rightContentView.alignment = UIStackViewAlignmentLeading;
    top_rightContentView.distribution = UIStackViewDistributionFill;
    
    UILabel *nameLabel = [UILabel new];
    nameLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:20];
    nameLabel.textColor = Theme.primaryTextColor;
    
    [top_rightContentView addArrangedSubview:nameLabel];
    UIView *avatarContentView = [UIView new];
    self.iconImage = [AvatarImageView new];
    self.userStateImageView = [UIImageView new];
    UITapGestureRecognizer *tapAvatarRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeUserAvatarImage:)];
    self.iconImage.userInteractionEnabled = true;
    [self.iconImage addGestureRecognizer:tapAvatarRecognizer];
    
    [avatarContentView addSubview:self.iconImage];
    [avatarContentView addSubview:self.userStateImageView];
    [avatarContentView autoSetDimension:ALDimensionHeight toSize:75];
    [avatarContentView autoSetDimension:ALDimensionWidth toSize:75];
    
    [self.iconImage autoSetDimension:ALDimensionHeight toSize:75];
    [self.iconImage autoSetDimension:ALDimensionWidth toSize:75];
    
    [self.userStateImageView autoSetDimension:ALDimensionWidth toSize:75];
    [self.userStateImageView autoSetDimension:ALDimensionHeight toSize:75];
    [self dealUserStateWithCache];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressNameClick:)];
    longPress.minimumPressDuration = 0.75;
    nameLabel.userInteractionEnabled  = YES;
    [nameLabel addGestureRecognizer:longPress];
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    nameLabel.text = [contactsManager displayNameForPhoneIdentifier:self.recipientId];
    [topContentRow addArrangedSubview:avatarContentView];
    [topContentRow addArrangedSubview:top_rightContentView];
    [self.iconImage setImageWithContactAvatar:self.contact.avatar recipientId:self.recipientId];
    
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapNameClick:)];
    [nameLabel addGestureRecognizer:tap];
    
    
    UILabel *activeLabel = [UILabel new];
    activeLabel.font = [UIFont systemFontOfSize:14];
    activeLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x707A8A] ;
    [topContentRow addArrangedSubview:activeLabel];
    
    SignalUserStatesModel *model = [DTSUserStateManager sharedManager].userStatusCacheSet[self.recipientId];
    NSString *statuesString = [[DTSUserStateManager sharedManager] getUserStateStringFromTimeIntervalWithUserStateType:model.status lastActitiveTimeStamp:[model.timeStamp integerValue]];
    activeLabel.text = statuesString;
    [top_rightContentView addArrangedSubview:nameLabel];
    [top_rightContentView addArrangedSubview:activeLabel];
    return cell;
}

- (void)changeUserAvatarImage:(UITapGestureRecognizer *)tap {
    if (self.type == DTPersonnalCardTypeSelf_CanEdit) {
        [self.avatarViewHelper showChangeAvatarUI];
    }
}

- (NSMutableAttributedString *)getAttributedString:(NSString *)content image:(UIImage *)image font:(UIFont *)font {
    NSMutableAttributedString *contentAtt = [[NSMutableAttributedString alloc] initWithString:content attributes:@{NSFontAttributeName : font}];
    NSTextAttachment *imageMent = [[NSTextAttachment alloc] init];
    imageMent.image = image;
    CGFloat paddingTop = font.lineHeight - font.pointSize + 2;
    imageMent.bounds = CGRectMake(0, -paddingTop, font.lineHeight, font.lineHeight);
    NSAttributedString *imageAtt = [NSAttributedString attributedStringWithAttachment:imageMent];
    [contentAtt appendAttributedString:imageAtt];
    return contentAtt;
}

//时区差值
- (NSNumber *)convertStringToNumber:(NSString *) string{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [numberFormatter numberFromString:string];
}

- (BOOL)isChineseLanguage {
    NSArray *languages = [NSLocale preferredLanguages];
    NSString *pfLanguageCode = [languages objectAtIndex:0];
    if ([pfLanguageCode isEqualToString:@"zh-Hant"] ||
        [pfLanguageCode hasPrefix:@"zh-Hant"] ||
        [pfLanguageCode hasPrefix:@"yue-Hant"] ||
        [pfLanguageCode isEqualToString:@"zh-HK"] ||
        [pfLanguageCode isEqualToString:@"zh-TW"]||
        [pfLanguageCode isEqualToString:@"zh-Hans"] ||
        [pfLanguageCode hasPrefix:@"yue-Hans"] ||
        [pfLanguageCode hasPrefix:@"zh-Hans"]
        ){
        return YES;
    }else{
        return NO;
    }
}


/**
 根据起始时间和时间间隔计算时间
 
 @param startDate 开始时间
 @param timeInterval 时间间隔 以秒为单位
 @return 计算得到的时间
 */
- (NSDate *)getResultDate:(NSDate *)startDate timeInterval:(NSInteger)timeInterval{
    NSDate *resultDate = [NSDate dateWithTimeInterval: timeInterval sinceDate:startDate];
    return resultDate;
}

- (void)backBtnClick:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:true];
}

- (UITableViewCell *)customCellWithTitle:(NSString *)title {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
    cell.textLabel.text = title;
    return cell;
}

- (UIButton *)backBtn {
    if (!_backBtn) {
        _backBtn = [UIButton new];
        [_backBtn setTitleColor:Theme.primaryTextColor forState:UIControlStateNormal];
        [_backBtn setBackgroundImage:[UIImage imageNamed:@"NavBarBackNew"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(backBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}

- (void)setContact:(Contact *)contact {
    _contact = contact;
    
}


@end
