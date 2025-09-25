//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "MainAppContext.h"
#import "TempTalk-Swift.h"
#include <sys/utsname.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSProfileManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/OWSIdentityManager.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface MainAppContext ()

@property (atomic) UIApplicationState reportedApplicationState;

// POST GRDB TODO: Remove this
@property (nonatomic) NSUUID *disposableDatabaseUUID;

@property (nonatomic, readonly) UIApplicationState mainApplicationStateOnLaunch;

@property (nonatomic, readwrite) BOOL isColdStart;

@end

#pragma mark -

@implementation MainAppContext

@synthesize mainWindow = _mainWindow;
@synthesize appLaunchTime = _appLaunchTime;

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    self.reportedApplicationState = UIApplicationStateInactive;

    _appLaunchTime = [NSDate new];
    _disposableDatabaseUUID = [NSUUID UUID];
    _mainApplicationStateOnLaunch = [UIApplication sharedApplication].applicationState;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    self.reportedApplicationState = UIApplicationStateInactive;

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    [NSNotificationCenter.defaultCenter postNotificationName:OWSApplicationWillEnterForegroundNotification object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    self.reportedApplicationState = UIApplicationStateBackground;

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [DDLog flushLog];

    [NSNotificationCenter.defaultCenter postNotificationName:OWSApplicationDidEnterBackgroundNotification object:nil];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    self.reportedApplicationState = UIApplicationStateInactive;

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [DDLog flushLog];

    [NSNotificationCenter.defaultCenter postNotificationName:OWSApplicationWillResignActiveNotification object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    self.reportedApplicationState = UIApplicationStateActive;

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    [NSNotificationCenter.defaultCenter postNotificationName:OWSApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [DDLog flushLog];
}

#pragma mark -

- (BOOL)isMainApp
{
    return YES;
}

- (BOOL)isMainAppAndActive
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}

- (BOOL)isNSE {
    return NO;
}

- (BOOL)isRTL
{
    static BOOL isRTL = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DispatchMainThreadSafe(^{
            isRTL = [[UIApplication sharedApplication] userInterfaceLayoutDirection] == UIUserInterfaceLayoutDirectionRightToLeft;
        });
    });
    return isRTL;
}

- (BOOL)isInMeeting {
    
    return [DTMeetingManager shared].inMeeting;
}

- (void)setStatusBarHidden:(BOOL)isHidden animated:(BOOL)isAnimated
{
    [[UIApplication sharedApplication] setStatusBarHidden:isHidden animated:isAnimated];
}

- (void)setColdStart:(BOOL)isColdStart {
    _isColdStart = isColdStart;
}

- (CGRect)frame
{
    return self.mainWindow.frame;
}

- (UIInterfaceOrientation)interfaceOrientation
{
    OWSAssertIsOnMainThread();
    return [UIApplication sharedApplication].statusBarOrientation;
}

- (BOOL)isInBackground
{
    return self.reportedApplicationState == UIApplicationStateBackground;
}

- (BOOL)isAppForegroundAndActive
{
    return self.reportedApplicationState == UIApplicationStateActive;
}

- (CGFloat)statusBarHeight {
    return UIApplication.sharedApplication.statusBarFrame.size.height;
}

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:
    (BackgroundTaskExpirationHandler)expirationHandler
{
    return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:expirationHandler];
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier
{
    [UIApplication.sharedApplication endBackgroundTask:backgroundTaskIdentifier];
}

- (void)ensureSleepBlocking:(BOOL)shouldBeBlocking blockingObjectsDescription:(NSString *)blockingObjectsDescription {
    if ([[UIApplication sharedApplication] isIdleTimerDisabled] != shouldBeBlocking) {
        if (shouldBeBlocking) {
            OWSLogInfo(@"Blocking sleep because of: %@", blockingObjectsDescription);
        } else {
            
            OWSLogInfo(@"Unblocking sleep.");
        }
    }
    [[UIApplication sharedApplication] setIdleTimerDisabled:shouldBeBlocking];
}
// changed: just keep notification count as app icon badge count number,
//          and donot update app icon badge count number with unread message changed count.
- (void)setMainAppBadgeNumber:(NSInteger)value
{
    //[[UIApplication sharedApplication] setApplicationIconBadgeNumber:value];
}

- (nullable UIViewController *)frontmostViewController
{
    return UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
}

- (nullable UIAlertAction *)openSystemSettingsAction
{
    return [UIAlertAction actionWithTitle:CommonStrings.openSettingsButton
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *_Nonnull action) {
                                      [UIApplication.sharedApplication openSystemSettings];
                                  }];
}

- (nullable ActionSheetAction *)openSystemSettingsActionWithCompletion:(void (^_Nullable)(void))completion
{
    return [[ActionSheetAction alloc] initWithTitle:CommonStrings.openSettingsButton
                            accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"system_settings")
                                              style:ActionSheetActionStyleDefault
                                            handler:^(ActionSheetAction *_Nonnull action) {
        [UIApplication.sharedApplication openSystemSettings];
        if (completion != nil) {
            completion();
        }
    }];
}

- (void)doMultiDeviceUpdateWithProfileKey:(SSKAES256Key *)profileKey
{
    OWSAssertDebug(profileKey);

    [MultiDeviceProfileKeyUpdateJob runWithProfileKey:profileKey
                                      identityManager:OWSIdentityManager.sharedManager
                                        messageSender:Environment.shared.messageSender
                                       profileManager:OWSProfileManager.sharedManager];
}

- (BOOL)isRunningTests
{
    return getenv("runningTests_dontStartApp");
}

- (void)setNetworkActivityIndicatorVisible:(BOOL)value
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:value];
}

- (BOOL)shouldProcessIncomingMessages {
    return YES;
}

- (BOOL)canPresentNotifications {
    return YES;
}

- (id<SSKKeychainStorage>)keychainStorage
{
    return [SSKDefaultKeychainStorage shared];
}

- (NSString *)appDocumentDirectoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL =
    [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentDirectoryURL path];
}

- (NSString *)appSharedDataDirectoryPath
{
    NSURL *groupContainerDirectoryURL =
    [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:TSConstants.applicationGroup];
    return [groupContainerDirectoryURL path];
}

- (NSString *)appDatabaseBaseDirectoryPath
{
    return self.appSharedDataDirectoryPath;
}

- (NSUserDefaults *)appUserDefaults
{
    NSString *applicationGroup = TSConstants.applicationGroup;
    OWSLogDebug(@"applicationGroup = %@.", applicationGroup);
    return [[NSUserDefaults alloc] initWithSuiteName:applicationGroup];
}

- (BOOL)hasUI
{
    return YES;
}

- (NSString *)debugLogsDirPath
{
    return DebugLogger.mainAppDebugLogsDirPath;
}

@end

NS_ASSUME_NONNULL_END
