//
//  DTScopeOfNoticeController.m
//  Wea
//
//  Created by hornet on 2021/12/27.
//

#import "DTScopeOfNoticeController.h"
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/TTServiceKit-swift.h>
#import <TTServiceKit/Localize_Swift.h>
#import <TTServiceKit/DTParamsBaseUtils.h>

extern NSString *const kGlobalNotificationInfoPublicKey;
@interface DTScopeOfNoticeController ()
@property(nonatomic,strong) Contact *contact;
@property(nonatomic,strong) NSNumber *globalNotification;
@property(nonatomic,assign) DTGlobalNotificationType type;

@end

@implementation DTScopeOfNoticeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
    
    [self setTitle:Localized(@"SETTINGS_SECTION_MESSAGE_NOTIFYCATION", nil)];
    [self prepareUIdata];
    [self requestUserMessage];
}

- (void)signalAccountsDidChange:(NSNotification *)notify {
    [self prepareUIdata];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OWSContactsManagerSignalAccountsDidChangeNotification object:nil];
}

- (void)prepareUIdata {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
    self.contact = account.contact;
    if (self.contact && self.contact.privateConfigs) {
        if (DTParamsUtils.validateNumber(self.contact.privateConfigs.globalNotification)) {
            self.globalNotification = self.contact.privateConfigs.globalNotification;
            self.type = [self getGlobalNotificationType];
        }
    }
    [self updateTableContents];
}

- (void)requestUserMessage {
    NSString*recipientId = [TSAccountManager sharedInstance].localNumber;
    if (!recipientId) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TSAccountManager sharedInstance] getContactMessageByReceptid:recipientId success:^(Contact* contact) {
        if (!contact) {
            return;
        }
        weakSelf.contact = contact;
        if(weakSelf.contact){
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:writeTransaction];
                if (!account) {
                    account = [[SignalAccount alloc] initWithRecipientId:recipientId];
                }
                account.contact = weakSelf.contact;
                SignalAccount *newAccount = [account copy];
                [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:newAccount withTransaction:writeTransaction];
                if (weakSelf.contact && weakSelf.contact.privateConfigs) {
                    self.globalNotification = self.contact.privateConfigs.globalNotification;
                    self.type = [self getGlobalNotificationType];
                    if (self.type == DTGlobalNotificationTypeMENTION) {
                        [weakSelf updateTableContents];
                    }
                }
            });
        }
    } failure:^(NSError * _Nonnull error) {

    }];
}

- (void)setProfileWithGlobalNotification:(NSNumber *)globalNotification {
    OWSLogInfo(@"(DTScopeOfNoticeController):putV1ProfileWithParams: \n %@",globalNotification);
    [DTToastHelper showHudInView:self.view];
    
    NSDictionary *parms = @{@"privateConfigs":@{kGlobalNotificationInfoPublicKey:globalNotification}};
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        [DTToastHelper hide];
        
        NSDictionary *responseObject = response.responseBodyJson;
        if (DTParamsUtils.validateDictionary(responseObject)) {
            
            NSNumber *status = (NSNumber *)responseObject[@"status"];
            if (DTParamsUtils.validateNumber(status) && [status intValue] == 0) {
                
                [TSAccountManager sharedInstance].isChangeGlobalNotificationType = true;//作为全局的标识使用
                self.globalNotification = globalNotification;
                self.type = [self getGlobalNotificationType];
                //更新本地的contact缓存  方便在设置页即时查看设置的信息
                
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
                    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:writeTransaction];
                    if (self.contact && self.contact.privateConfigs) {
                        self.contact.privateConfigs.globalNotification = globalNotification;
                    }
                    account.contact = self.contact;
                    SignalAccount *newAccount = [account copy];
                    [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:newAccount withTransaction:writeTransaction];
                    
                    [self updateTableContents];
                });
                
            } else {
                [DTToastHelper toastWithText:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") durationTime:2];
            }
        } else {
            [DTToastHelper toastWithText:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") durationTime:2];
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        [DTToastHelper hide];
        [DTToastHelper toastWithText:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") durationTime:2];
    }];
}

#pragma mark - Table Contents
#pragma mark setter & getter

- (void)updateTableContents {
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *notitySection = [OWSTableSection new];
    @weakify(self)
    [notitySection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE",@"") actionBlock:^{
       @strongify(self)
        [self changeCustomMesssageTypeWithType:DTGlobalNotificationTypeALL];
    } accessoryType: ([self getGlobalNotificationType] == DTGlobalNotificationTypeALL) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [notitySection addItem:[OWSTableItem itemHasSepline:NO text:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT",@"") actionBlock:^{
        @strongify(self)
        if ([self getGlobalNotificationType] != DTGlobalNotificationTypeMENTION) {
            [self showChangeAtMeAlert];
        }
    } accessoryType: ([self getGlobalNotificationType] == DTGlobalNotificationTypeMENTION) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [notitySection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self custonTipCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:nil]];
    
    [notitySection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF",@"") actionBlock:^{
        @strongify(self)
        [self changeCustomMesssageTypeWithType:DTGlobalNotificationTypeOFF];
    } accessoryType:([self getGlobalNotificationType] == DTGlobalNotificationTypeOFF) ? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [contents addSection:notitySection];
    self.contents = contents;
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
//
- (void)showChangeAtMeAlert {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:Localized(@"SETTINGS_SECTION_TIPMESSAGE", @"") message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:CommonStrings.cancelButton style:UIAlertActionStyleDefault handler:nil];
    UIAlertAction *alerAction = [UIAlertAction actionWithTitle:Localized(@"TXT_CONFIRM_TITLE", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self changeCustomMesssageTypeWithType:DTGlobalNotificationTypeMENTION];
    }];
    
    [alertVC addAction:cancelAction];
    [alertVC addAction:alerAction];
    [self presentViewController:alertVC animated:true completion:nil];
}

- (DTGlobalNotificationType)getGlobalNotificationType {
    if (!self.globalNotification) return DTGlobalNotificationTypeALL;
    if ([self.globalNotification intValue] == 0 ) {
        return DTGlobalNotificationTypeALL;
    }else if([self.globalNotification intValue] == 1 ){
        return DTGlobalNotificationTypeMENTION;
    }else if([self.globalNotification intValue] == 2 ){
        return DTGlobalNotificationTypeOFF;
    }else {
        return DTGlobalNotificationTypeALL;
    }
}

- (void)changeCustomMesssageTypeWithType:(DTGlobalNotificationType)type {
    OWSLogInfo(@"(DTScopeOfNoticeController):changeCustomMesssageTypeWithType: type = %ld ",(long)type);
    if (self.type == type) {
        return;
    }
    switch (type) {
        case DTGlobalNotificationTypeALL:
            [self setProfileWithGlobalNotification:@0];
            break;
        case DTGlobalNotificationTypeMENTION:
            [self setProfileWithGlobalNotification:@1];
            break;
        case DTGlobalNotificationTypeOFF:
            [self setProfileWithGlobalNotification:@2];
            break;
        default:
            break;
    }
}

@end
