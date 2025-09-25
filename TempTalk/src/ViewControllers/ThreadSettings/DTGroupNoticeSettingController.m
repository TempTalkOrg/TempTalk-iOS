//
//  DTGroupNoticeSettingController.m
//  Wea
//
//  Created by hornet on 2021/12/29.
//

#import "DTGroupNoticeSettingController.h"
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/TTServiceKit-swift.h>
#import "DTScopeOfNoticeController.h"
#import "DTChangeYourSettingsInAGroupAPI.h"
#import <TTServiceKit/Localize_Swift.h>

extern NSString *const DTPersonalGroupConfigChangedNotification;

@interface DTGroupNoticeSettingController ()<UITextViewDelegate>
@property(nonatomic,strong) Contact *contact;
@property(nonatomic,strong) NSNumber *globalNotification;//全局的配置信息
@property(nonatomic,assign) DTGlobalNotificationType type;//全局的配置类型

@property(nonatomic,assign) BOOL isOpenGlobalNotification;//用户是否打开全局配置
@property(nonatomic,strong) NSNumber* customNotification;//自定义消息的值
@property(nonatomic,assign) TSGroupNotificationType grouptype;//自定义消息的类型
@property(nonatomic,strong) DTChangeYourSettingsInAGroupAPI *changeYourSettingsInAGroupAPI;
@property(nonatomic,strong) TSThread *thread;
@property(nonatomic,strong) UISwitch *switchBtn;
@end

@implementation DTGroupNoticeSettingController

- (void)configureWithThread:(TSThread *)thread {
    self.thread = thread;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:Localized(@"SETTINGS_GROUP_MESSAGE_NOTIFYCATION", nil)];
    if(self.thread.isGroupThread){
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(personalGroupConfigChangedNotification:)
                                                     name:DTPersonalGroupConfigChangedNotification
                                                   object:nil];
    }
}

- (void)personalGroupConfigChangedNotification:(NSNotification *)notification {
    self.thread = [TSGroupThread getThreadWithGroupId:((TSGroupThread *)self.thread).groupModel.groupId];
    [self preapreUIData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self preapreUIData];
}

- (void)preapreUIData {
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    int useGlobal = groupThread.groupModel.useGlobal.intValue;
    self.isOpenGlobalNotification = (useGlobal == 1);
    //用户使用自定义的  群配置
    if (!self.isOpenGlobalNotification) {
        self.grouptype = [self transformToGroupNotificationTypeWithIntValue:[groupThread.groupModel.notificationType intValue]];
        //需要获取全局配置
        self.globalNotification = groupThread.groupModel.notificationType;
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
            SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:transation];
            self.contact = account.contact;
            if (self.contact && self.contact.privateConfigs) {
                self.globalNotification = self.contact.privateConfigs.globalNotification;
            }
        }];
        self.type = [self getGlobalNotificationType];
        [self updateTableContents];
    } else {
        //用户使用了全局配置 作为群配置
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
            SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:transation];
            self.contact = account.contact;
            if (self.contact && self.contact.privateConfigs) {
                if (self.contact.privateConfigs) {
                    self.globalNotification = self.contact.privateConfigs.globalNotification;
                    self.type = [self getGlobalNotificationType];
                    self.grouptype = [self transformToGroupNotificationTypeWith:self.type];
                }
            }
            [self updateTableContents];
        }];
        [self requestUserMessage];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self name:DTPersonalGroupConfigChangedNotification object:nil];
}
- (void)requestUserMessage {
    NSString*recipientId = [TSAccountManager sharedInstance].localNumber;
    if (!recipientId) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TSAccountManager sharedInstance] getContactMessageV1ByPhoneNumber:@[recipientId] success:^(NSArray *contacts) {
        if (!contacts) {
            return;
        }
        weakSelf.contact = contacts.firstObject;
        if(weakSelf.contact){
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transation) {
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:transation];
                if (!account) {
                    account = [[SignalAccount alloc] initWithRecipientId:recipientId];
                }
                account.contact = weakSelf.contact;
                SignalAccount *newAccount = [account copy];
                [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:newAccount withTransaction:transation];
                if (weakSelf.contact.privateConfigs) {
                    weakSelf.globalNotification = weakSelf.contact.privateConfigs.globalNotification;
                    weakSelf.type = [weakSelf getGlobalNotificationType];
                    if (weakSelf.isOpenGlobalNotification) {//用户打开了全局配置即使用全局配置
                        weakSelf.grouptype = [weakSelf transformToGroupNotificationTypeWith:weakSelf.type];
                    }else {//用户关闭了全局配置,获取自定义配置信息,展示自定义的用户配置信息
                        TSGroupThread *groupThread = (TSGroupThread *)weakSelf.thread;
                        weakSelf.grouptype = [weakSelf transformToGroupNotificationTypeWithIntValue:[groupThread.groupModel.notificationType intValue]];
                    }
                }
                
                [weakSelf updateTableContents];
            });
        }
    } failure:^(NSError * _Nonnull error) {

    }];
}

#pragma mark - Table Contents
- (void)updateTableContents {
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *globalNotitySection = [OWSTableSection new];
    @weakify(self)
    [globalNotitySection addItem: [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self globalNotifyCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:nil]];
    [contents addSection:globalNotitySection];
    if (!self.isOpenGlobalNotification) {//未打开全局通知
        OWSTableSection *notitySection = [self getNotitySection];
        [contents addSection:notitySection];
    }
    self.contents = contents;
}

- (OWSTableSection *)getNotitySection {
    OWSTableSection *notitySection = [OWSTableSection new];
    notitySection.headerTitle = Localized(@"SETTINGS_NOTITY_CUSTOM", @"Header Label for the notification section of settings views.");
    @weakify(self)
    [notitySection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE",@"") actionBlock:^{
        @strongify(self)
        [self changeGroupNotifationConfigWithType:TSGroupNotificationTypeAll isForbiddenUpdate:false];
    } accessoryType: (self.grouptype == TSGroupNotificationTypeAll) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [notitySection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT",@"") actionBlock:^{
        @strongify(self)
        if (self.grouptype != TSGroupNotificationTypeAtMe) {
            [self showChangeAtMeAlert];
        }
    } accessoryType: (self.grouptype == TSGroupNotificationTypeAtMe) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [notitySection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self custonTipCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:nil]];
    
    [notitySection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF",@"") actionBlock:^{
        @strongify(self)
        [self changeGroupNotifationConfigWithType:TSGroupNotificationTypeOff isForbiddenUpdate:false];
    } accessoryType:(self.grouptype == TSGroupNotificationTypeOff) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    return notitySection;
}

- (void)showChangeAtMeAlert {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:Localized(@"SETTINGS_SECTION_TIPMESSAGE", @"") message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[CommonStrings cancelButton] style:UIAlertActionStyleDefault handler:nil];
    UIAlertAction *alerAction = [UIAlertAction actionWithTitle:Localized(@"TXT_CONFIRM_TITLE", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self changeGroupNotifationConfigWithType:TSGroupNotificationTypeAtMe isForbiddenUpdate:false];
    }];
    
    [alertVC addAction:cancelAction];
    [alertVC addAction:alerAction];
    [self presentViewController:alertVC animated:true completion:nil];
}

- (UITableViewCell *)custonTipCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.backgroundColor = Theme.tableCellBackgroundColor;
    
    UILabel *detailTextLabel = [UILabel new];
    detailTextLabel.font = [UIFont ows_regularFontWithSize:14.f];
    detailTextLabel.textColor = Theme.accentBlueColor;
    [cell.contentView addSubview:detailTextLabel];
    [detailTextLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:cell.contentView withOffset:0];
    [detailTextLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView withOffset:-10];
    [detailTextLabel autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [detailTextLabel autoPinEdgeToSuperviewMargin:ALEdgeRight];
    detailTextLabel.text = Localized(@"SETTINGS_COMMON_ONLY_@MENSION_BOTTOM_TIP", @"");
    detailTextLabel.numberOfLines = 0;

    return cell;
}

- (DTGlobalNotificationType)getGlobalNotificationType {
    if ([self.globalNotification intValue] == 0 ) {
        return DTGlobalNotificationTypeALL;
    }else if([self.globalNotification intValue] == 1 ){
        return DTGlobalNotificationTypeMENTION;
    }else if([self.globalNotification intValue] == 2 ){
        return DTGlobalNotificationTypeOFF;
    }else {
        return DTGlobalNotificationTypeMENTION;
    }
}

- (TSGroupNotificationType)getCustomNotificationType {//获取自定义消息类型
    if ([self.globalNotification intValue] == 0 ) {
        return TSGroupNotificationTypeAll;
    }else if([self.globalNotification intValue] == 1 ){
        return TSGroupNotificationTypeAtMe;
    }else if([self.globalNotification intValue] == 2 ){
        return TSGroupNotificationTypeOff;
    }else {
        return TSGroupNotificationTypeAtMe;
    }
}

//关闭全局配置，使用群组配置
- (void)changeGroupNotifationConfigWithType:(TSGroupNotificationType )type isForbiddenUpdate:(BOOL)isForbidden{
    if (self.grouptype == type && !isForbidden) {
        return;
    }
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    [DTToastHelper showHudInView:self.view];
    __weak typeof(self) weakSelf = self;
    [self.changeYourSettingsInAGroupAPI sendRequestWithGroupId:serverGId
                                              notificationType:@(type)
                                                     useGlobal:@(0)
                                                       success:^(DTAPIMetaEntity * _Nonnull entity) {
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            
            [groupThread anyUpdateGroupThreadWithTransaction:transaction
                                                       block:^(TSGroupThread * instance) {
                instance.groupModel.notificationType = @(type);
                instance.groupModel.useGlobal = @(0);
                weakSelf.thread  = instance;
            }];
        });
        [DTToastHelper hide];
        weakSelf.grouptype = type;
        [weakSelf updateTableContents];
    } failure:^(NSError * _Nonnull error) {
        [DTToastHelper hide];
    }];
}
//打开全局配置，默认关闭了群组配置
- (void)changeToGlobalConfig {
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    [DTToastHelper showHudInView:self.view];
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    __weak typeof(self) weakSelf = self;
    [self.changeYourSettingsInAGroupAPI sendRequestWithGroupId:serverGId
                                              notificationType:nil
                                                     useGlobal:@(1)
                                                       success:^(DTAPIMetaEntity * _Nonnull entity) {
        weakSelf.isOpenGlobalNotification = true;
        weakSelf.grouptype = [weakSelf transformToGroupNotificationTypeWith:weakSelf.type];
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [groupThread anyUpdateGroupThreadWithTransaction:transaction
                                                       block:^(TSGroupThread * instance) {
                instance.groupModel.useGlobal = @(1);
                weakSelf.thread  = instance;
            }];
        });
        [DTToastHelper hide];
        [weakSelf updateTableContents];
    } failure:^(NSError * _Nonnull error) {
        weakSelf.isOpenGlobalNotification = false;
        weakSelf.switchBtn.on = false;
        [DTToastHelper hide];
    }];
}

- (UITableViewCell *)globalNotifyCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.backgroundColor = Theme.tableCellBackgroundColor;
    UIStackView *contentColumnView = [[UIStackView alloc]init];
    contentColumnView.axis = UILayoutConstraintAxisVertical;
    contentColumnView.alignment = UIStackViewAlignmentCenter;
    contentColumnView.spacing = 12;
    [cell.contentView addSubview:contentColumnView];
    [contentColumnView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:cell.contentView withOffset:0];
    [contentColumnView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView withOffset:0];
    [contentColumnView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [contentColumnView autoPinEdgeToSuperviewMargin:ALEdgeRight];
    
    
    UIStackView *contentTopRowView = [[UIStackView alloc]init];
    contentTopRowView.axis = UILayoutConstraintAxisHorizontal;
    contentTopRowView.alignment = UIStackViewAlignmentCenter;
    contentTopRowView.distribution = UIStackViewDistributionEqualCentering;
    contentTopRowView.spacing = 12;
    [contentColumnView addArrangedSubview:contentTopRowView];
    [contentTopRowView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:contentColumnView withOffset:0];
    [contentTopRowView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:contentColumnView withOffset:0];
    [contentTopRowView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:contentColumnView withOffset:0];
    [contentTopRowView autoSetDimension:ALDimensionHeight toSize:44];
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.font = [UIFont ows_regularFontWithSize:18.f];
    titleLabel.textColor = Theme.primaryTextColor;
    titleLabel.text = Localized(@"SETTINGS_COMMON_GLOBAL_NOTIFICSTION", @"");
    [contentTopRowView addArrangedSubview:titleLabel];
    
    UILabel *notityLabel = [UILabel new];
    notityLabel.font = [UIFont ows_regularFontWithSize:18.f];
    if (self.isOpenGlobalNotification) {
        notityLabel.textColor = Theme.accentBlueColor;
    }else {
        notityLabel.textColor = Theme.ternaryTextColor;
    }
    notityLabel.text = [NSString stringWithFormat:@"(%@)",[self getGlobleString]];
    [contentTopRowView addArrangedSubview:notityLabel];
    [notityLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:titleLabel withOffset:5];
    
    
    if (!self.switchBtn) {
        self.switchBtn = [UISwitch new];
    }
    UISwitch *cellSwitch = self.switchBtn;
    [cellSwitch setOn:self.isOpenGlobalNotification];
    [cellSwitch addTarget:self action:@selector(switchBtnClick:) forControlEvents:UIControlEventValueChanged];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [contentTopRowView addArrangedSubview:cellSwitch];
    
    if (self.isOpenGlobalNotification) {//打开全局通知
        UITextView *textView;
        NSString *content = Localized(@"SETTINGS_COMMON_GLOBAL_NOTIFICSTION_TIP", @"");
        if ([content containsString:@"Update Default Group Setting"]) {
            textView = [self attributedViewWithString:Localized(@"SETTINGS_COMMON_GLOBAL_NOTIFICSTION_TIP", @"") lastTipLength:28];
        }else {
            textView = [self attributedViewWithString:Localized(@"SETTINGS_COMMON_GLOBAL_NOTIFICSTION_TIP", @"") lastTipLength:7];
        }
       
        [contentColumnView addArrangedSubview:textView];
        [textView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:contentTopRowView withOffset:0];
        [textView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:contentTopRowView withOffset:0];
        [textView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:contentTopRowView withOffset:0];
        [textView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:contentColumnView withOffset:0];
    }
    return cell;
}

- (void)switchBtnClick:(UISwitch *)switchBtn {
    self.isOpenGlobalNotification = switchBtn.isOn;
    if (self.isOpenGlobalNotification) {//如果打开了全局通知
        [self changeToGlobalConfig];
    }else{//如果关闭了全局通知
        [self changeGroupNotifationConfigWithType:[self transformToGroupNotificationTypeWith:self.type] isForbiddenUpdate:true];
        
    }
}

- (NSString *)getGlobleString {
    switch (self.type) {
        case DTGlobalNotificationTypeALL:
            return Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE", @"Header Label for the notification section of settings views.");
        case DTGlobalNotificationTypeMENTION:
            return Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT", @"Header Label for the notification section of settings views.");
        case DTGlobalNotificationTypeOFF:
            return Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF", @"Header Label for the notification section of settings views.");
        default:
            return @"";
    }
}

- (TSGroupNotificationType )transformToGroupNotificationTypeWith:(DTGlobalNotificationType)type {
    //⚠️DTGlobalNotificationType目前两种type类型是一致的，default未返回
    switch (type) {
        case DTGlobalNotificationTypeALL:
            return TSGroupNotificationTypeAll;
        case DTGlobalNotificationTypeMENTION:
            return TSGroupNotificationTypeAtMe;
        case DTGlobalNotificationTypeOFF:
            return TSGroupNotificationTypeOff;
        default:
            break;
    }
}

- (TSGroupNotificationType )transformToGroupNotificationTypeWithIntValue:(int)type {
    switch (type) {
        case DTGlobalNotificationTypeALL:
            return TSGroupNotificationTypeAll;
        case DTGlobalNotificationTypeMENTION:
            return TSGroupNotificationTypeAtMe;
        case DTGlobalNotificationTypeOFF:
            return TSGroupNotificationTypeOff;
        default:
            return TSGroupNotificationTypeAll;
    }
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction  {
    if ([[URL scheme] isEqualToString:@"localNotificationAddress"]) {
        //《隐私政策》
        DTScopeOfNoticeController *scopeVC = [DTScopeOfNoticeController new];
        [self.navigationController pushViewController:scopeVC animated:true];
        return NO;
    }
    return YES;
}

- (UITextView *)attributedViewWithString:(NSString *) content lastTipLength:(NSUInteger)length{
    UITextView *contentTextView = [[UITextView alloc] initWithFrame:CGRectMake(30, 100, 345, 200)];
    contentTextView.backgroundColor = [UIColor clearColor];
    contentTextView.attributedText = [self getContentLabelAttributedText:content lastTipLength:length];
    contentTextView.linkTextAttributes = @{NSForegroundColorAttributeName:Theme.accentBlueColor};
    contentTextView.textAlignment = NSTextAlignmentLeft;
    contentTextView.delegate = self;
    contentTextView.editable = NO;
    contentTextView.scrollEnabled = NO;
    return contentTextView;
}

- (NSAttributedString *)getContentLabelAttributedText:(NSString *)text lastTipLength:(NSUInteger)length{
    if (!text) {
        text = @"";
    }
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.lineSpacing = 10;
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName:[UIFont systemFontOfSize:12],
        NSForegroundColorAttributeName:Theme.secondaryTextAndIconColor,
        NSParagraphStyleAttributeName:paragraphStyle
    }];
    [attrStr addAttribute:NSLinkAttributeName value:@"localNotificationAddress://" range:NSMakeRange(text.length-length, length)];
    [attrStr addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(text.length-length, length)];
    return attrStr;
}

#pragma mark setter & getter

- (DTChangeYourSettingsInAGroupAPI *)changeYourSettingsInAGroupAPI{
    if(!_changeYourSettingsInAGroupAPI){
        _changeYourSettingsInAGroupAPI = [DTChangeYourSettingsInAGroupAPI new];
    }
    return _changeYourSettingsInAGroupAPI;
}
@end
