//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NotificationSettingsViewController.h"
#import "NotificationSettingsOptionsViewController.h"
#import "OWSSoundSettingsViewController.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSPreferences.h>
#import <SignalMessaging/OWSSounds.h>
#import "DTScopeOfNoticeController.h"
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/SignalAccount.h>
#import <SignalServiceKit/OWSRequestFactory.h>
#import <SignalServiceKit/SignalServiceKit-swift.h>
#import <SignalServiceKit/Localize_Swift.h>
#import <SignalServiceKit/DTToastHelper.h>
#import <SignalServiceKit/DTParamsBaseUtils.h>

@interface NotificationSettingsViewController()

@property(nonatomic, strong) Contact *contact;
@property(nonatomic, strong) NSNumber *globalNotification;
@property (nonatomic, assign) BOOL isVoipAvailable;
@property (nonatomic, assign) BOOL calendarNotification;

@end

@implementation NotificationSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
        
    [self setTitle:Localized(@"SETTINGS_NOTIFICATIONS", nil)];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OWSContactsManagerSignalAccountsDidChangeNotification object:nil];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self prepareUIdata];
    [self updateTableContents];
}

- (void)signalAccountsDidChange:(NSNotification *)notify {
    
    [self prepareUIdata];
    [self updateTableContents];
}

- (void)prepareUIdata {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        
    NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
    __block SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
            
    if (!account) {
        
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
            account = [SignalAccount signalAccountWithRecipientId:localNumber transaction:transaction];
        }];
    }
    
    self.contact = account.contact;
    BOOL voipNotification = self.contact.privateConfigs.voipNotification;
    NSNumber *globalNotification = self.contact.privateConfigs.globalNotification;
  
    BOOL calendarNotification = YES;
    //MARK: wea默认关闭显示, cc及其他默认开启显示
    NSString *appName = TSConstants.appDisplayName;
    if ([appName.lowercaseString containsString:@"wea"]) {
        calendarNotification = NO;
    }
    if (DTParamsUtils.validateNumber(self.contact.privateConfigs.calendarNotification)) {
        calendarNotification = self.contact.privateConfigs.calendarNotification.boolValue;
    }
     
    self.isVoipAvailable = voipNotification;
    self.globalNotification = globalNotification;
    self.calendarNotification = calendarNotification;
}

#pragma mark - Table Contents

- (void)updateTableContents {

    NSString *notificationTypeString;
    if ([self.globalNotification intValue] == 0) {
        notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE", nil);
    }else if ([self.globalNotification intValue] == 1){
        notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_AT", nil);
    }else if ([self.globalNotification intValue] == 2){
        notificationTypeString = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_OFF", nil);
    }else {
        notificationTypeString = @"";
    }
    
    OWSTableContents *contents = [OWSTableContents new];
    OWSPreferences *prefs = [Environment preferences];
    
    OWSTableSection *calendarSection = [OWSTableSection new];
    calendarSection.headerTitle = Localized(@"CALENDAR_BADGE_NOTIFICATION_SECTION_TITLE", @"");
    [calendarSection addItem:[OWSTableItem switchItemWithText:Localized(@"CALENDAR_BADGE_NOTIFICATION_TITLE", @"")
                                                     isOn:self.calendarNotification
                                                   target:self
                                                 selector:@selector(chageCalendarNotificationAvailable:)]];
    calendarSection.footerTitle = Localized(@"CALENDAR_BADGE_NOTIFICATION_DESCRIPTION", @"");
    [contents addSection:calendarSection];
    
    OWSTableSection *voipSection = [OWSTableSection new];
    voipSection.headerTitle = Localized(@"MEETING_VOIP_NOTIFICATION_SECTION_TITLE", @"");
    [voipSection addItem:[OWSTableItem switchItemWithText:Localized(@"MEETING_VOIP_NOTIFICATION_TITLE", @"")
                                                     isOn:self.isVoipAvailable
                                                   target:self
                                                 selector:@selector(chageVoipAvailable:)]];
    voipSection.footerTitle = [prefs voipNotificationDescription];
    [contents addSection:voipSection];
    
    OWSTableSection *notitySection = [OWSTableSection new];
    notitySection.headerTitle = Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS_HEADER",
                                                  @"Label for settings view that allows user to change the notification sound scope.");
    [contents addSection:notitySection];
    @weakify(self)
    [notitySection addItem:[OWSTableItem disclosureItemWithText:Localized(@"SETTINGS_ITEM_NOTIFICATION_APNS",
                                                                                  @"Label for settings view that allows user to change the notification sound scope.") detailText:notificationTypeString actionBlock:^{
        @strongify(self)
        DTScopeOfNoticeController *scopeOfNoticeController = [DTScopeOfNoticeController new];
        [self.navigationController pushViewController:scopeOfNoticeController animated:true];
    }]];
    
    // Sounds section.

    OWSTableSection *soundsSection = [OWSTableSection new];
    soundsSection.headerTitle
        = Localized(@"SETTINGS_SECTION_SOUNDS", @"Header Label for the sounds section of settings views.");
    [soundsSection
        addItem:[OWSTableItem disclosureItemWithText:
                                  Localized(@"SETTINGS_ITEM_NOTIFICATION_SOUND",
                                      @"Label for settings view that allows user to change the notification sound.")
                                          detailText:[OWSSounds displayNameForSound:[OWSSounds globalNotificationSound]]
                                         actionBlock:^{
                                             @strongify(self)
                                             OWSSoundSettingsViewController *vc = [OWSSoundSettingsViewController new];
                                             [self.navigationController pushViewController:vc animated:YES];
                                         }]];

    NSString *inAppSoundsLabelText = Localized(@"NOTIFICATIONS_SECTION_INAPP",
        @"Table cell switch label. When disabled, Signal will not play notification sounds while the app is in the "
        @"foreground.");
    [soundsSection addItem:[OWSTableItem switchItemWithText:inAppSoundsLabelText
                                                       isOn:[prefs soundInForeground]
                                                     target:self
                                                   selector:@selector(didToggleSoundNotificationsSwitch:)]];
    [contents addSection:soundsSection];

    OWSTableSection *backgroundSection = [OWSTableSection new];
    backgroundSection.headerTitle = Localized(@"SETTINGS_NOTIFICATION_CONTENT_TITLE", @"table section header");
    [backgroundSection
        addItem:[OWSTableItem
                    disclosureItemWithText:Localized(@"NOTIFICATIONS_SHOW", nil)
                                detailText:[prefs nameForNotificationPreviewType:[prefs notificationPreviewType]]
                               actionBlock:^{
                                   @strongify(self)
                                   NotificationSettingsOptionsViewController *vc =
                                       [NotificationSettingsOptionsViewController new];
                                   [self.navigationController pushViewController:vc animated:YES];
                               }]];
    backgroundSection.footerTitle
        = Localized(@"SETTINGS_NOTIFICATION_CONTENT_DESCRIPTION", @"table section footer");
    [contents addSection:backgroundSection];
    
    OWSTableSection *alarmSection = [OWSTableSection new];
    alarmSection.headerTitle = Localized(@"SETTING_NOTIFICATION_ALARM_TITLE", @"table section header");
    [alarmSection
        addItem:[OWSTableItem labelItemWithText:Localized(@"SETTING_NOTIFICATION_ALARM_SUBTITLE", nil)]];
    alarmSection.footerTitle
        = Localized(@"SETTING_NOTIFICATION_ALARM_DESCRIPTION", @"table section footer");
    [contents addSection:alarmSection];

    self.contents = contents;
}

#pragma mark - Events

- (void)didToggleSoundNotificationsSwitch:(UISwitch *)sender
{
    [Environment.preferences setSoundInForeground:sender.on];
}

- (void)chageVoipAvailable:(UISwitch *)sender {
    [self changeValueForVoip:YES sender:sender];
}

- (void)chageCalendarNotificationAvailable:(UISwitch *)sender {
    [self changeValueForVoip:NO sender:sender];
}

- (void)changeValueForVoip:(BOOL)isForVoip
                    sender:(UISwitch *)sender {
    [DTToastHelper svShow];
    NSNumber *notificatinAvailable = @(sender.isOn);
    NSDictionary *parameters = nil;
    if (isForVoip) {
        parameters = @{@"voipNotification" : notificatinAvailable};
    } else {
        parameters = @{@"calendarNotification" : notificatinAvailable};
    }
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:@{@"privateConfigs" : parameters}];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        
        NSDictionary *responseObject = response.responseBodyJson;
        if (!DTParamsUtils.validateDictionary(responseObject)) {
            sender.on = !sender.isOn;
            [DTToastHelper dismissWithInfo:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") delay:0.2];
            return;
        }
            
        NSNumber *status = responseObject[@"status"];
        if (DTParamsUtils.validateNumber(status) && [status intValue] != 0) {
            sender.on = !sender.isOn;
            [DTToastHelper dismissWithInfo:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") delay:0.2];
            return;
        }

        [DTToastHelper dismissWithDelay:0.2 completion:^{
            if (isForVoip) {
                self.isVoipAvailable = notificatinAvailable.boolValue;
                [self updateVoipAvailable:notificatinAvailable calendarNotification:nil];
            } else {
                self.calendarNotification = notificatinAvailable.boolValue;
                [self updateVoipAvailable:nil calendarNotification:notificatinAvailable];
            }
        }];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        OWSLogError(@"%@ error: %@", self.logTag, error.asNSError.localizedDescription);
        [DTToastHelper dismissWithInfo:Localized(@"SETTINGS_COMMON_TIP_MESSAGE_FAILE",@"") delay:0.2 completion:^{
            sender.on = !sender.isOn;
        }];
    }];

}

- (void)updateVoipAvailable:(NSNumber *)voipAvailable 
       calendarNotification:(NSNumber *)calendarNotification {
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transation) {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
        SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId transaction:transation];
        if (self.contact && self.contact.privateConfigs) {
            if (DTParamsUtils.validateNumber(voipAvailable)) {
                self.contact.privateConfigs.voipNotification = voipAvailable.boolValue;
            }
            if (DTParamsUtils.validateNumber(calendarNotification)) {
                self.contact.privateConfigs.calendarNotification = calendarNotification;
            }
        }
        account.contact = self.contact;

        [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:account withTransaction:transation];
        OWSLogInfo(@"%@ update voip: %@, calendar: %@", self.logTag, voipAvailable, calendarNotification);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateTableContents];
        });
    });
}

@end
