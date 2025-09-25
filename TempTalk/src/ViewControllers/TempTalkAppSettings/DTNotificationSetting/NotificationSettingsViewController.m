//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NotificationSettingsViewController.h"
#import "NotificationSettingsOptionsViewController.h"
#import "OWSSoundSettingsViewController.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSPreferences.h>
#import <TTMessaging/OWSSounds.h>
#import "DTScopeOfNoticeController.h"
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/Localize_Swift.h>
#import <TTServiceKit/DTParamsBaseUtils.h>

//TODO:temptalk need handle
extern NSString *const kGlobalNotificationInfoPublicKey;
NSString *const kGlobalNotificationInfoPublicKey = @"globalNotification";

@interface NotificationSettingsViewController()
@property(nonatomic,strong) Contact *contact;
@property(nonatomic,strong) NSNumber *globalNotification;
@end
@implementation NotificationSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
    self.globalNotification = @(-1000);
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
        SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
        self.contact = account.contact;
        if (self.contact && self.contact.privateConfigs) {
            if (DTParamsUtils.validateNumber(self.contact.privateConfigs.globalNotification)) {
                self.globalNotification = self.contact.privateConfigs.globalNotification;
            }
        }
}
#pragma mark - Table Contents

- (void)updateTableContents
{
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

    self.contents = contents;
}

#pragma mark - Events

- (void)didToggleSoundNotificationsSwitch:(UISwitch *)sender
{
    [Environment.preferences setSoundInForeground:sender.on];
}

@end
