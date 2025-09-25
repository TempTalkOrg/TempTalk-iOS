//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AboutTableViewController.h"
#import "TempTalk-Swift.h"
#import "UIView+SignalUI.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSPreferences.h>
#import <SignalMessaging/UIUtil.h>
//
//
#import <SignalServiceKit/ATAppUpdater.h>
#import <AVFoundation/AVFoundation.h>

@implementation AboutTableViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = Localized(@"SETTINGS_ABOUT", @"Navbar title");

    [self updateTableContents];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pushTokensDidChange:)
                                                 name:[OWSSyncPushTokensJob PushTokensDidChange]
                                               object:nil];
}

- (void)pushTokensDidChange:(NSNotification *)notification
{
    [self updateTableContents];
}

// added: add update check functions
// TODO: move this function into AppUpdateNag
- (void)doUpdateCheck
{
    //    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://testflight.apple.com/join/mUTQXGkg"]];
    
    ATAppUpdater *updater = [ATAppUpdater sharedUpdater];
    [updater setAlertTitle:[NSString stringWithFormat:Localized(@"APP_UPDATE_NAG_ALERT_TITLE", @"Title for the 'new app version available' alert."), TSConstants.appDisplayName]];
    [updater setAlertMessage:Localized(@"APP_UPDATE_NAG_ALERT_MESSAGE_FORMAT",
                                               @"Message format for the 'new app version available' alert. Embeds: {{The latest app "
                                               @"version number.}}.")];
    [updater setAlertUpdateButtonTitle:Localized(@"APP_UPDATE_NAG_ALERT_UPDATE_BUTTON",
                                                         @"Label for the 'update' button in the 'new app version available' alert.")];
    [updater setAlertCancelButtonTitle:[CommonStrings cancelButton]];
    [updater setNoUpdateAlertMessage:Localized(@"APP_UPDATE_NO_NEW_VERSION", @"")];
    [updater setAlertDoneTitle:Localized(@"OK", @"")];
    
    [updater showUpdateWithConfirmation];
    
}

//- (void)openDesktopApp
//{
    
//    NSString *urlString = DTInstallationGuideConfig.serverDefaultInstallationGuideUrlString;
//    if(DTParamsUtils.validateString(urlString)){
//        if ([[DTMiniProgramManger sharedManager] isMiniApplicationLink:urlString]){
//            
//        } else {
//            NSURL *url = [NSURL URLWithString:urlString];
//            NSDictionary *options = @{UIApplicationOpenURLOptionUniversalLinksOnly: @NO};
//            if ([[UIApplication sharedApplication] canOpenURL:url]) {
//                [[UIApplication sharedApplication] openURL:url options:options completionHandler:^(BOOL success) {
//                    if(success){
//                        OWSLogInfo(@"open url sucess");
//                    } else {
//                        OWSLogError(@"open url fail");
//                    }
//                }];
//            }
//        }
//    }
//}

- (void)helpAndFeedBack
{
    //weabot +10000 ccbot +10003
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction){
        [self pushToConversationVCWithTransaction:transaction];
    });
}

- (void)pushToConversationVCWithTransaction:(SDSAnyWriteTransaction *) transaction{
    TSContactThread* thread = [TSContactThread createThreadWithContactId:@"+10000" transaction:transaction];
    if(thread){
        [SignalApp.sharedApp presentTargetConversationForThread:thread action:ConversationViewActionNone focusMessageId:nil];
    }
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    OWSTableSection *informationSection = [OWSTableSection new];
    informationSection.headerTitle = Localized(@"SETTINGS_INFORMATION_HEADER", @"");
    [informationSection addItem:[OWSTableItem labelItemWithText:Localized(@"SETTINGS_VERSION", @"")
                                                  accessoryText:[[[NSBundle mainBundle] infoDictionary]
                                                                    objectForKey:@"CFBundleShortVersionString"]]];
    [informationSection addItem:[OWSTableItem labelItemWithText:Localized(@"BUILD_SETTINGS_VERSION", @"")
                                                  accessoryText:[[[NSBundle mainBundle] infoDictionary]
                                                                    objectForKey:@"CFBundleVersion"]]];
    @weakify(self)
    [informationSection addItem:[OWSTableItem disclosureItemWithText:Localized(@"CHECK_NEW_VERSION", @"")
                                                    actionBlock:^{
                                                        @strongify(self)
                                                        [self doUpdateCheck];
                                                    }]];
    
    [informationSection addItem:[OWSTableItem disclosureItemWithText:Localized(@"JOIN_DESKTOP_APP", @"")
                                                    actionBlock:^{
                                                        @strongify(self)
                                                        [self openDesktopApp];
                                                    }]];
    
    [informationSection addItem:[OWSTableItem disclosureItemWithText:Localized(@"HELP & FEEDBACK", @"")
                                                    actionBlock:^{
                                                        @strongify(self)
                                                        [self helpAndFeedBack];
                                                    }]];
    

#ifdef SHOW_LEGAL_TERMS_LINK
//    [informationSection addItem:[OWSTableItem disclosureItemWithText:Localized(@"SETTINGS_LEGAL_TERMS_CELL",
//                                                                         @"table cell label")
//                                                         actionBlock:^{
//                                                             [[UIApplication sharedApplication]
//                                                                 openURL:[NSURL URLWithString:kLegalTermsUrlString]];
//                                                         }]];
#endif

    [contents addSection:informationSection];

    // OWSTableSection *helpSection = [OWSTableSection new];
    // helpSection.headerTitle = Localized(@"SETTINGS_HELP_HEADER", @"");
    // [helpSection addItem:[OWSTableItem disclosureItemWithText:Localized(@"SETTINGS_SUPPORT", @"")
    //                                               actionBlock:^{
    //                                                   [[UIApplication sharedApplication]
    //                                                       openURL:[NSURL URLWithString:@"https://support.signal.org"]];
    //                                               }]];
    // [contents addSection:helpSection];

    // UILabel *copyrightLabel = [UILabel new];
    // copyrightLabel.text = Localized(@"SETTINGS_COPYRIGHT", @"");
    // copyrightLabel.textColor = [UIColor ows_darkGrayColor];
    // copyrightLabel.font = [UIFont ows_regularFontWithSize:15.0f];
    // copyrightLabel.numberOfLines = 2;
    // copyrightLabel.lineBreakMode = NSLineBreakByWordWrapping;
    // copyrightLabel.textAlignment = NSTextAlignmentCenter;
    // helpSection.customFooterView = copyrightLabel;
    // helpSection.customFooterHeight = @(60.f);

#ifdef DEBUG
    __block NSUInteger threadCount;
    __block NSUInteger messageCount;
    __block NSUInteger attachmentCount;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        threadCount = [TSThread anyCountWithTransaction:transaction];
        messageCount = [TSInteraction anyCountWithTransaction:transaction];
        attachmentCount = [TSAttachment anyCountWithTransaction:transaction];
    }];

    NSByteCountFormatter *byteCountFormatter = [NSByteCountFormatter new];

    // format counts with thousands separator
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;

    OWSTableSection *debugSection = [OWSTableSection new];

    debugSection.headerTitle = @"Debug";

    NSString *formattedThreadCount = [numberFormatter stringFromNumber:@(threadCount)];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Threads: %@", formattedThreadCount]]];

    NSString *formattedMessageCount = [numberFormatter stringFromNumber:@(messageCount)];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Messages: %@", formattedMessageCount]]];

    NSString *formattedAttachmentCount = [numberFormatter stringFromNumber:@(attachmentCount)];
    [debugSection addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Attachments: %@",
                                                                    formattedAttachmentCount]]];

    NSString *dbSize =
        [byteCountFormatter stringFromByteCount:(long long)[self.databaseStorage databaseFileSize]];
    [debugSection addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Database size: %@", dbSize]]];

    NSString *dbWALSize =
        [byteCountFormatter stringFromByteCount:(long long)[self.databaseStorage databaseWALFileSize]];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Database WAL size: %@", dbWALSize]]];

    NSString *dbSHMSize =
        [byteCountFormatter stringFromByteCount:(long long)[self.databaseStorage databaseSHMFileSize]];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Database SHM size: %@", dbSHMSize]]];

    [contents addSection:debugSection];

    OWSPreferences *preferences = [Environment preferences];
    NSString *_Nullable pushToken = [preferences getPushToken];
    NSString *_Nullable voipToken = [preferences getVoipToken];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Push Token: %@", pushToken ?: @"None"]]];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"VOIP Token: %@", voipToken ?: @"None"]]];

    // Strip prefix from category, otherwise it's too long to fit into cell on a small device.
    NSString *audioCategory =
        [AVAudioSession.sharedInstance.category stringByReplacingOccurrencesOfString:@"AVAudioSessionCategory"
                                                                          withString:@""];
    [debugSection
        addItem:[OWSTableItem labelItemWithText:[NSString stringWithFormat:@"Audio Category: %@", audioCategory]]];
#endif

    self.contents = contents;
}

@end
