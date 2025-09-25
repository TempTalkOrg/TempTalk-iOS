//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AdvancedSettingsTableViewController.h"
#import "DebugLogger.h"
#import "Pastelog.h"
#import "PushManager.h"
#import "TempTalk-Swift.h"
#import "TSAccountManager.h"
//#import <PromiseKit/AnyPromise.h>
#import <Reachability/Reachability.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSPreferences.h>
#import <SignalMessaging/Theme.h>
#import <SignalServiceKit/OWSSignalService.h>
// export database
#import <SSZipArchive/SSZipArchive.h>
#import "zlib.h"
#import <SignalServiceKit/DTToastHelper.h>
#import "RegistrationUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface AdvancedSettingsTableViewController ()

@property (nonatomic) Reachability *reachability;

@end

#pragma mark -

@implementation AdvancedSettingsTableViewController

- (void)loadView
{
    [super loadView];
    
    self.title = Localized(@"SETTINGS_ADVANCED_TITLE", @"");
    
    self.reachability = [Reachability reachabilityForInternetConnection];
    
    [self observeNotifications];
    
    [self updateTableContents];
}

- (void)applyLanguage {
    [super applyLanguage];
    self.title = Localized(@"SETTINGS_ADVANCED_TITLE", @"");
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketStateDidChange)
                                                 name:OWSWebSocket.webSocketStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)socketStateDidChange
{
    OWSAssertIsOnMainThread();
    
    [self updateTableContents];
}

- (void)reachabilityChanged
{
    OWSAssertIsOnMainThread();
    
    [self updateTableContents];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateTableContents];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];
    
    @weakify(self);
    
    OWSTableSection *loggingSection = [OWSTableSection new];
    loggingSection.headerTitle = Localized(@"LOGGING_SECTION", nil);
    
    if ([OWSPreferences isLoggingEnabled]) {
        [loggingSection
         addItem:[OWSTableItem actionItemWithText:Localized(@"SETTINGS_ADVANCED_SUBMIT_DEBUGLOG", @"")
                                      actionBlock:^{
            @strongify(self);
            OWSLogInfo(@"%@ Submitting debuglogs", self.logTag);
            
            [DTToastHelper show];
            
            [DDLog flushLog];
            [Pastelog submitLogsWithCompletion:^{
                [DTToastHelper hide];
            }];
        }]];
    }
    

    
    [contents addSection:loggingSection];
    
#ifdef THEME_ENABLED
    ThemeMode mode = [Theme getOrFetchCurrentTheme];
    OWSTableSection *themeSection = [OWSTableSection new];
    themeSection.headerTitle = Localized(@"THEME_SECTION", nil);
    
    NSString *modeName = [self nameForTheme:mode];
    OWSTableItem *themeItem = [OWSTableItem disclosureItemWithText:Localized(@"THEME_SECTION", nil) detailText:modeName actionBlock:^{
        @strongify(self);
        [self showThemeSettingPaga];
    }];
    [themeSection addItem:themeItem];
    
    [contents addSection:themeSection];
#endif
    
//    ThemeMode mode = [Theme getOrFetchCurrentTheme];
    OWSTableSection *languageSection = [OWSTableSection new];
    languageSection.headerTitle = Localized(@"LANGUAGE", nil);
    
    NSString *languageName = [Localize isChineseLanguage] ? Localized(@"APPEARANCE_SETTINGS_LANGUAGE_ZH", @"") :
    Localized(@"APPEARANCE_SETTINGS_LANGUAGE_EN", @"");
    OWSTableItem *languageItem = [OWSTableItem disclosureItemWithText:Localized(@"LANGUAGE", nil) detailText:languageName actionBlock:^{
        @strongify(self);
        [self showLanguageSettingPaga];
    }];
    [languageSection addItem:languageItem];
    
    [contents addSection:languageSection];
    
    #ifdef DEBUG
//     导出数据库
        [loggingSection
         addItem:[OWSTableItem actionItemWithText:@"export db"
                                      actionBlock:^{
            [self backupDatabase];
        }]];
    #endif
    
    OWSTableSection *attachmentSection = [OWSTableSection new];
    attachmentSection.headerTitle = Localized(@"ATTACHMENT_SECTION", nil);
    [attachmentSection
     addItem:[OWSTableItem actionItemWithText:Localized(@"ATTACHMENT_SECTION_CLEAR_TITLE", nil)
                                  actionBlock:^{
        [self clearOutdatedAttachments];
    }]];
    [attachmentSection
     addItem:[OWSTableItem
              switchItemWithText:Localized(@"AUTO_DOWNLOAD_PICTURES_SECTION", nil)
              isOn:[OWSAttachmentsProcessor autoDownloadImageEnable]
              target:self
              selector:@selector(autoDownloadPicturesChanged:)]];
    
    [attachmentSection addItem:[OWSTableItem blankItemWithcustomRowHeight:10.f backgroundColor:Theme.blankBackgroundColor]];
    [contents addSection:attachmentSection];
    
    OWSTableSection *logoutSection = [OWSTableSection new];
    [logoutSection
     addItem:[self logOutButtonItemWithTitle:Localized(@"LOG_OUT", nil) actionBlock:^{
        [self logOut];
    }]];
    [contents addSection:logoutSection];
    
    self.contents = contents;
}

- (OWSTableItem *)logOutButtonItemWithTitle:(NSString *)title
                                     actionBlock:(void(^)(void))actionBlock {
    
    return [OWSTableItem itemWithCustomCellBlock:^{
          
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCellStyleDefault"];
        cell.preservesSuperviewLayoutMargins = YES;
        cell.contentView.preservesSuperviewLayoutMargins = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = title;
        cell.textLabel.textColor = [UIColor colorWithRGBHex:0xF84135];
        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;

            return cell;
    } actionBlock:^{
        if (actionBlock) actionBlock();
    }];
}

- (void)clearOutdatedAttachments {
    [DTToastHelper show];
    
    __block NSUInteger byteCount = 0;
    __block NSMutableArray<TSAttachmentStream *> *needDeleteAttachments = @[].mutableCopy;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        NSTimeInterval threeMonthTimeInterval = ([NSDate ows_millisecondTimeStamp] / 1000.0) - kMonthInterval * 3;
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        [AttachmentFinder
         enumerateNeedDeleteAttachmentsBeforeDataTimestamp:threeMonthTimeInterval
         transaction:readTransaction error:nil
         block:^(TSAttachment * _Nonnull attachment, BOOL * _Nonnull stop) {
            if ([attachment isKindOfClass:TSAttachmentStream.class]) {
                
                TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;
                NSString *filePath = attachmentStream.filePath;
                NSString *thumbnailPath = attachmentStream.thumbnailPath;
                
                // TODO: PERF-数据库增加字段及索引标识该附件是否已被清除
                if (DTParamsUtils.validateString(filePath) ||
                    DTParamsUtils.validateString(thumbnailPath)) {
                    BOOL exist = [fileManager fileExistsAtPath:filePath];
                    exist = [fileManager fileExistsAtPath:thumbnailPath];
                    if (exist) {
                        
                        byteCount += attachment.byteCount;
                        [needDeleteAttachments addObject:attachmentStream];
                        OWSLogDebug(@"TSAttachment filePath:%@ ||| thumbnailPath:%@", filePath, thumbnailPath);
                    }
                }
            }
        }];
    } completion:^{
        [DTToastHelper hide];
        
        NSString *fileSize = [OWSFormat formatFileSize:byteCount];
        NSString *message = [NSString stringWithFormat:Localized(@"ATTACHMENT_SECTION_CLEAR_DETAIL", nil), needDeleteAttachments.count, fileSize];
        [self showAlertStyle:UIAlertControllerStyleAlert
                       title:nil
                         msg:message
                 cancelTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", "cancel")
                confirmTitle:NSLocalizedString(@"TXT_DELETE_TITLE", "delete attachments")
                confirmStyle:UIAlertActionStyleDestructive confirmHandler:^{
            
            [self deleteAttachments:needDeleteAttachments.copy];
        }];
    }];
}

- (OWSTableItem *)destructiveButtonItemWithTitle:(NSString *)title selector:(SEL)selector color:(UIColor *)color {
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


- (void)logOut {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:Localized(@"LOG_OUT", @"")
                                            message:Localized(@"ME_LOGOUT_TIPS", @"")
                                     preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"TXT_CANCEL_TITLE", @"") style:UIAlertActionStyleCancel handler:nil]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"TXT_CONFIRM_TITLE", @"")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                          [self deleteAccount:true];
                                                      }]];
    

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)deleteAccount:(BOOL)isRegistered {
    if (isRegistered) {
        
        [ModalActivityIndicatorViewController
         presentFromViewController:self
         canCancel:NO
         backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
           
            [TSAccountManager
             unregisterTextSecureWithSuccess:^{
                [RegistrationUtils kickedOffToRegistration];
            }
             failure:^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [modalActivityIndicator dismissWithCompletion:^{
                        [OWSAlerts
                         showAlertWithTitle:Localized(@"UNREGISTER_SIGNAL_FAIL", @"")];
                    }];
                });
            }];
        }];
        
    } else {
        
        [RegistrationUtils kickedOffToRegistration];
        
    }
}

- (UITableViewCell *)newCell {
    return [OWSTableItem newCellWithBackgroundColor:Theme.backgroundColor];
}


- (void)deleteAttachments:(NSArray<TSAttachmentStream *> *)attachments {
    if (!DTParamsUtils.validateArray(attachments)) {
        return;
    }
    
    [DTToastHelper showWithStatus:@"deleting..."];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [attachments enumerateObjectsUsingBlock:^(TSAttachmentStream * _Nonnull attachment, NSUInteger idx, BOOL * _Nonnull stop) {

        NSMutableArray<NSURL *> *contents = @[].mutableCopy;
        NSString *filePath = attachment.filePath;
        NSString *thumbnailPath = attachment.thumbnailPath;

        if (DTParamsUtils.validateString(filePath)) {
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            [contents addObject:fileURL];
        }

        if (DTParamsUtils.validateString(thumbnailPath)) {
            NSURL *thumbnailURL = [NSURL fileURLWithPath:thumbnailPath];
            [contents addObject:thumbnailURL];
        }

        NSError *error;
        for (NSURL *url in contents) {
            [fileManager removeItemAtURL:url error:&error];
            if (error) {
                OWSFailDebug(@"failed to remove item at path: %@ with error: %@", url, error);
            }
        }
    }];
    
    [DTToastHelper dismissWithDelay:0.3];
}


- (void)backupDatabase {
    OWSLogDebug(@"backup db begin");
    NSError *error;
    NSData *cipherKeySpec = [GRDBDatabaseStorageAdapter debugOnly_keyData];

    if (error) {
        OWSLogDebug(@"can't load DatabaseLegacyPassphrase");
    }

    NSString *keySpecString = nil;
    if (cipherKeySpec) {
        keySpecString = cipherKeySpec.hexadecimalString;
    }
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateFormat:@"yyyy.MM.dd HH.mm.ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate new]];
    NSString *dbName = nil;
    if (keySpecString) {
        dbName = [[dateString stringByAppendingString:@" "] stringByAppendingString:keySpecString];
        
    } else {
        dbName = [[dateString stringByAppendingString:@" "] stringByAppendingString:NSUUID.UUID.UUIDString];
    }
    NSString *dbZipName = [dbName stringByAppendingPathExtension:@"zip"];
    NSString *tempDirectory = NSTemporaryDirectory();
    NSString *zipFilePath =
    [tempDirectory stringByAppendingPathComponent:dbZipName];
    NSString *zipDirPath = [tempDirectory stringByAppendingPathComponent:dbName];
    [OWSFileSystem ensureDirectoryExists:zipDirPath];
    
    NSString *sharedFilePath = SDSDatabaseStorage.grdbDatabaseFileUrl.path;
    NSMutableArray <NSString *> *dbFilePaths = [NSMutableArray array];

    if (sharedFilePath) {
        [dbFilePaths addObject:sharedFilePath];
    }
    
    if (dbFilePaths.count < 1) {
        
        [DTToastHelper showHudWithMessage:@"Can't find database" inView:self.view];
        return;
    }
    
    for (NSString *dbFilePath in dbFilePaths) {
        NSString *copyFilePath = [zipDirPath stringByAppendingPathComponent:dbFilePath.lastPathComponent];
        NSError *copyError;
        [[NSFileManager defaultManager] copyItemAtPath:dbFilePath toPath:copyFilePath error:&copyError];
        if (copyError) {
            OWSLogDebug(@"copyItemAtPath error %@", dbFilePath);
        }
        [OWSFileSystem protectFileOrFolderAtPath:copyFilePath];
    }
    
    // Phase 2. Zip up the log files.
    BOOL zipSuccess = [SSZipArchive createZipFileAtPath:zipFilePath
                                withContentsOfDirectory:zipDirPath
                                    keepParentDirectory:YES
                                       compressionLevel:Z_DEFAULT_COMPRESSION
                                               password:nil
                                                    AES:NO
                                        progressHandler:nil];
    if (!zipSuccess) {
        OWSLogDebug(@"zip fail!");
        return;
    }
    
    [OWSFileSystem protectFileOrFolderAtPath:zipFilePath];
    [OWSFileSystem deleteFile:zipDirPath];
    
    
    [AttachmentSharing showShareUIForURL:[NSURL fileURLWithPath:zipFilePath] completion:^{
        [OWSFileSystem deleteFile:zipFilePath];
        OWSLogDebug(@"deleteFile %@", zipFilePath);
    }];
}

- (void)autoDownloadPicturesChanged:(UISwitch *)sender {
    BOOL autoDownloadPictures = sender.isOn;
    [OWSAttachmentsProcessor changeAutoDownloadImageValue:autoDownloadPictures];
}

- (void)showThemeSettingPaga {
    ThemeSettingsTableViewController *themeSettingVC = [ThemeSettingsTableViewController new];
    [self.navigationController pushViewController:themeSettingVC animated:YES];
}

- (void)showLanguageSettingPaga {
    LanguageSettingsTableViewController *languageSettingVC = [LanguageSettingsTableViewController new];
    [self.navigationController pushViewController:languageSettingVC animated:YES];
}


- (NSString *)nameForTheme:(ThemeMode)mode {
    switch (mode) {
        case ThemeMode_Dark:
            return Localized(@"APPEARANCE_SETTINGS_DARK_THEME_NAME", @"Name indicating that the dark theme is enabled.");
            break;
        case ThemeMode_Light:
            return Localized(@"APPEARANCE_SETTINGS_LIGHT_THEME_NAME", @"Name indicating that the light theme is enabled.");
            break;
        case ThemeMode_System:
            return Localized(@"APPEARANCE_SETTINGS_SYSTEM_THEME_NAME", @"Name indicating that the system theme is enabled.");
            break;
            
        default:
            return @"";
            break;
    }
}

#pragma mark - Actions

- (void)syncPushTokens
{
    OWSSyncPushTokensJob *job = [[OWSSyncPushTokensJob alloc] initWithAccountManager:SignalApp.sharedApp.accountManager
                                                                         preferences:[Environment preferences]];
    job.uploadOnlyIfStale = NO;
    [job run]
        .done(^ (id value) {
            [OWSAlerts showAlertWithTitle:Localized(@"PUSH_REGISTER_SUCCESS",
                                              @"Title of alert shown when push tokens sync job succeeds.")];
        })
        .catch(^(NSError *error) {
            [OWSAlerts showAlertWithTitle:Localized(@"REGISTRATION_BODY",
                                              @"Title of alert shown when push tokens sync job fails.")];
        });
}

- (void)didToggleEnableLogSwitch:(UISwitch *)sender
{
    if (!sender.isOn) {
        [[DebugLogger shared] wipeLogsIfDisabledWithAppContext:CurrentAppContext()];
        [[DebugLogger shared] disableFileLogging];
    } else {
        [[DebugLogger shared] enableFileLoggingWithAppContext:CurrentAppContext() canLaunchInBackground:YES];
    }

    [OWSPreferences setIsLoggingEnabled:sender.isOn];

    [self updateTableContents];
}

- (void)didToggleEnableCensorshipCircumventionSwitch:(UISwitch *)sender
{
    OWSSignalService.sharedInstance.isCensorshipCircumventionManuallyActivated = sender.isOn;

    [self updateTableContents];
}

#ifdef THEME_ENABLED
- (void)didToggleThemeSwitch:(UISwitch *)sender
{
    if (sender.isOn) {
        
        [Theme setCurrentTheme:ThemeMode_Dark];
    } else {
        
        [Theme setCurrentTheme:ThemeMode_Light];
    }
    
    [self updateTableContents];
}
#endif

@end

NS_ASSUME_NONNULL_END
