//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "PrivacySettingsTableViewController.h"
#import "BlockListViewController.h"
#import "OWS2FASettingsViewController.h"
#import "TempTalk-Swift.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSPreferences.h>
#import <SignalMessaging/ThreadUtil.h>
#import <SignalServiceKit/NSString+SSK.h>
#import <SignalServiceKit/OWS2FAManager.h>
#import <SignalServiceKit/OWSReadReceiptManager.h>

NS_ASSUME_NONNULL_BEGIN

@implementation PrivacySettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = Localized(@"SETTINGS_PRIVACY_TITLE", @"");

    [self observeNotifications];

    [self updateTableContents];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateTableContents];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenLockDidChange:)
                                                 name:ScreenLock.ScreenLockDidChange
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak PrivacySettingsTableViewController *weakSelf = self;

    OWSTableSection *screenLockSection = [OWSTableSection new];
    screenLockSection.headerTitle = Localized(
        @"SETTINGS_SCREEN_LOCK_SECTION_TITLE", @"Title for the 'screen lock' section of the privacy settings.");
    NSString *appDisplayName = TSConstants.appDisplayName;
    screenLockSection.footerTitle = [NSString stringWithFormat:Localized(
                                                                         @"SETTINGS_SCREEN_LOCK_SECTION_FOOTER", @"Footer for the 'screen lock' section of the privacy settings."), appDisplayName, appDisplayName];
    [screenLockSection
        addItem:[OWSTableItem
                    switchItemWithText:Localized(@"SETTINGS_SCREEN_LOCK_SWITCH_LABEL",
                                           @"Label for the 'enable screen lock' switch of the privacy settings.")
                                  isOn:ScreenLock.sharedManager.isScreenLockEnabled
                                target:self
                              selector:@selector(isScreenLockEnabledDidChange:)]];
    [contents addSection:screenLockSection];

    if (ScreenLock.sharedManager.isScreenLockEnabled) {
        OWSTableSection *screenLockTimeoutSection = [OWSTableSection new];
        uint32_t screenLockTimeout = (uint32_t)round(ScreenLock.sharedManager.screenLockTimeout);
        NSString *screenLockTimeoutString = [self formatScreenLockTimeout:screenLockTimeout useShortFormat:YES];
        [screenLockTimeoutSection
            addItem:[OWSTableItem
                        disclosureItemWithText:
                            Localized(@"SETTINGS_SCREEN_LOCK_ACTIVITY_TIMEOUT",
                                @"Label for the 'screen lock activity timeout' setting of the privacy settings.")
                                    detailText:screenLockTimeoutString
                                   actionBlock:^{
                                       [weakSelf showScreenLockTimeoutUI];
                                   }]];
        [contents addSection:screenLockTimeoutSection];
    }

    self.contents = contents;
}

#pragma mark - Events

- (void)showBlocklist
{
    BlockListViewController *vc = [BlockListViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clearHistoryLogs
{
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:nil
                                            message:Localized(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION",
                                                        @"Alert message before user confirms clearing history")
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[OWSAlerts cancelAction]];

    UIAlertAction *deleteAction = [UIAlertAction
        actionWithTitle:Localized(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION_BUTTON",
                            @"Confirmation text for button which deletes all message, calling, attachments, etc.")
                  style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *_Nonnull action) {
                    [self deleteThreadsAndMessages];
                }];
    [alertController addAction:deleteAction];

    [self presentViewController:alertController animated:true completion:nil];
}

- (void)deleteThreadsAndMessages
{
    [ThreadUtil deleteAllContent];
}


- (void)didToggleReadReceiptsSwitch:(UISwitch *)sender
{
    BOOL enabled = sender.isOn;
    OWSLogInfo(@"%@ toggled areReadReceiptsEnabled: %@", self.logTag, enabled ? @"ON" : @"OFF");
    [OWSReadReceiptManager.sharedManager setAreReadReceiptsEnabled:enabled];
}

- (void)didToggleCallsHideIPAddressSwitch:(UISwitch *)sender
{
    BOOL enabled = sender.isOn;
    OWSLogInfo(@"%@ toggled callsHideIPAddress: %@", self.logTag, enabled ? @"ON" : @"OFF");
    [Environment.preferences setDoCallsHideIPAddress:enabled];
}

- (void)didToggleEnableSystemCallLogSwitch:(UISwitch *)sender
{
    OWSLogInfo(@"%@ user toggled call kit preference: %@", self.logTag, (sender.isOn ? @"ON" : @"OFF"));
    [Environment.shared.preferences setIsSystemCallLogEnabled:sender.isOn];

    // rebuild callUIAdapter since CallKit configuration changed.
//    [SignalApp.sharedApp.callService createCallUIAdapter];
}

- (void)didToggleEnableCallKitSwitch:(UISwitch *)sender
{
    OWSLogInfo(@"%@ user toggled call kit preference: %@", self.logTag, (sender.isOn ? @"ON" : @"OFF"));
    [Environment.shared.preferences setIsCallKitEnabled:sender.isOn];

    // rebuild callUIAdapter since CallKit vs not changed.
//    [SignalApp.sharedApp.callService createCallUIAdapter];

    // Show/Hide dependent switch: CallKit privacy
    [self updateTableContents];
}

- (void)didToggleEnableCallKitPrivacySwitch:(UISwitch *)sender
{
    OWSLogInfo(@"%@ user toggled call kit privacy preference: %@", self.logTag, (sender.isOn ? @"ON" : @"OFF"));
    [Environment.shared.preferences setIsCallKitPrivacyEnabled:!sender.isOn];

    // rebuild callUIAdapter since CallKit configuration changed.
//    [SignalApp.sharedApp.callService createCallUIAdapter];
}

- (void)show2FASettings
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    OWS2FASettingsViewController *vc = [OWS2FASettingsViewController new];
    vc.mode = OWS2FASettingsMode_Status;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)isScreenLockEnabledDidChange:(UISwitch *)sender
{
    [self screenLockEnabledChangeActionWithSender:sender];
}

- (void)screenLockDidChange:(NSNotification *)notification
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    [self updateTableContents];
}

- (void)showScreenLockTimeoutUI
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    UIAlertController *controller = [UIAlertController
        alertControllerWithTitle:Localized(@"SETTINGS_SCREEN_LOCK_ACTIVITY_TIMEOUT",
                                     @"Label for the 'screen lock activity timeout' setting of the privacy settings.")
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *timeoutValue in ScreenLock.sharedManager.screenLockTimeouts) {
        uint32_t screenLockTimeout = (uint32_t)round(timeoutValue.doubleValue);
        NSString *screenLockTimeoutString = [self formatScreenLockTimeout:screenLockTimeout useShortFormat:NO];

        [controller addAction:[UIAlertAction actionWithTitle:screenLockTimeoutString
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
            [DTToastHelper show];
            DTScreenLockSetPasscodeApi *setPasscodeApi = [DTScreenLockSetPasscodeApi new];
            NSString *passcode = ScreenLock.sharedManager.passcode;
            [setPasscodeApi sendSetPasscodeRequestWithPasscode:passcode
                                             screenLockTimeout:screenLockTimeout
                                                        sucess:^(DTAPIMetaEntity * _Nonnull _) {
                [DTToastHelper hide];
                [ScreenLock.sharedManager setScreenLockTimeout:screenLockTimeout];
            } failure:^(NSError * _Nonnull error) {
                [DTToastHelper hide];
                [DTToastHelper toastWithText:error.localizedDescription inView:self.view durationTime:3.0 afterDelay:0.2];
            }];
        }]];
    }
    [controller addAction:[OWSAlerts cancelAction]];
    UIViewController *fromViewController = [[UIApplication sharedApplication] frontmostViewController];
    [fromViewController presentViewController:controller animated:YES completion:nil];
}

- (NSString *)formatScreenLockTimeout:(NSInteger)value useShortFormat:(BOOL)useShortFormat
{
    if (value <= 1) {
        return Localized(@"SCREEN_LOCK_ACTIVITY_TIMEOUT_NONE",
            @"Indicates a delay of zero seconds, and that 'screen lock activity' will timeout immediately.");
    }
    return [NSString formatDurationLosslessWithDurationSeconds:(uint32_t)value];
}

@end

NS_ASSUME_NONNULL_END
