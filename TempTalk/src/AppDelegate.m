//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AppDelegate.h"
#import "AppUpdateNag.h"
#import "DebugLogger.h"
#import "MainAppContext.h"
#import "OWS2FASettingsViewController.h"
#import "OWSScreenLockUI.h"
#import "PushManager.h"
#import "TempTalk-Swift.h"
#import "SignalApp.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/AppSetup.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/OWSMath.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/OWSPreferences.h>
#import <TTMessaging/OWSProfileManager.h>
#import <TTMessaging/Release.h>
#import <TTMessaging/TTMessaging.h>
#import <TTServiceKit/AppReadiness.h>
#import <TTServiceKit/NSUserDefaults+OWS.h>
#import <TTServiceKit/OWS2FAManager.h>
#import <TTServiceKit/OWSArchivedMessageJob.h>
#import <TTServiceKit/OWSMessageManager.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/OWSOrphanedDataCleaner.h>
#import <TTServiceKit/OWSReadReceiptManager.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TextSecureKitEnv.h>
#import <sys/sysctl.h>
#import <TTServiceKit/ATAppUpdater.h>
#import "DFTabbarController.h"
#import "DTServerConfigManager.h"
#import <TTServiceKit/DTServerConfigManager.h>
#import <TTServiceKit/DTServerUrlManager.h>
#import <TTServiceKit/DTWatermarkHelper.h>
#import "AppDelegate+UpLoadTimeZone.h"
#import "AppDelegate+ReportBackgroundStatus.h"
#import "DTRecallMessagesJob.h"
#import "DTConversationsJob.h"
#import "UITabBar+BadgeCount.h"
#import <TTServiceKit/DTConversationSettingHelper.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "UIWindow+OWS.h"
#import "DTHomeViewController.h"
#import "DTContactsViewController.h"
#import "DTDBKeyManager.h"
#import <FTS5SimpleTokenizer/FTS5SimpleTokenizer.h>
#import "DTSignChativeController.h"
#import "SMLagMonitor.h"
#import "SMCallTrace.h"

@import FirebaseCrashlytics;
@import FirebaseCore;
@import Intents;

static NSTimeInterval launchStartedAt;

@interface AppDelegate ()

@property (nonatomic) BOOL hasInitialRootViewController;
@property (nonatomic) BOOL areVersionMigrationsComplete;
@property (nonatomic) BOOL didAppLaunchFail;
@property (nonatomic, strong) DFTabbarController *tabbarVC;

@end

#pragma mark -

@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidEnterBackground:(UIApplication *)application {
    OWSLogWarn(@"%@ applicationDidEnterBackground.", self.logTag);
    
    [DDLog flushLog];
    if ([TSAccountManager isRegistered]) {
        [self reportBackgroundStatusByWebSocket:YES];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    OWSLogWarn(@"%@ applicationWillEnterForeground.", self.logTag);
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    OWSLogWarn(@"%@ applicationDidReceiveMemoryWarning.", self.logTag);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    OWSLogWarn(@"%@ applicationWillTerminate.", self.logTag);

    [DDLog flushLog];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // This should be the first thing we do.
    MainAppContext *mainAppContext = [MainAppContext new];
    SetCurrentAppContext(mainAppContext,false);

    launchStartedAt = CACurrentMediaTime();
    BOOL isLoggingEnabled = [self setupCrashAndLogReport];

    OWSLogWarn(@"%@ application: didFinishLaunchingWithOptions.", self.logTag);

    [SSKCryptography seedRandom];

    // XXX - careful when moving this. It must happen before we initialize OWSPrimaryStorage.
    [self verifyDBKeysAvailableBeforeBackgroundLaunch];

#if RELEASE
    // ensureIsReadyForAppExtensions may have changed the state of the logging
    // preference (due to [NSUserDefaults migrateToSharedUserDefaults]), so honor
    // that change if necessary.
    if (isLoggingEnabled && !OWSPreferences.isLoggingEnabled) {
        [DebugLogger.shared disableFileLogging];
    }
#endif
    [NSUserDefaults migrateToSharedUserDefaults];
    [AppVersion shared];
    
    [self setupNSEInteroperation];
    
    [[DTServerConfigManager sharedManager] updateConfig];
    [[DTServerUrlManager sharedManager] startSpeedTestAll];
    
    // Prevent the device from sleeping during database view async registration
    // (e.g. long database upgrades).
    //
    // This block will be cleared in storageIsReady.
    [DeviceSleepManager.shared addBlockWithBlockObject:self];
    
    [FTS5SimpleTokenizer registerTokenizer];
    
    //fix keyspec group issues
    [GRDBDatabaseStorageAdapter runKeyspecMigrations];
    
    [AppSetup setupEnvironmentWithAppSpecificSingletonBlock:^{
        NotificationPresenter *notificationsManager = AppEnvironment.shared.notificationPresenter;
        [TextSecureKitEnv sharedEnv].notificationsManager = notificationsManager;
        SSKEnvironment.shared.notificationsManagerRef = notificationsManager;
        [TextSecureKitEnv sharedEnv].meetingManager = [DTMeetingManager shared];
        [TextSecureKitEnv sharedEnv].settingsManager = [DTSettingsManager shared];
        [SignalApp sharedApp];
    } migrationCompletion:^{
        OWSAssertIsOnMainThread();

        [self versionMigrationsDidComplete];
    }];
    
    //
    LaunchFailure launchFailure = LaunchFailureNone;

    if (![self checkSomeDiskSpaceAvailable]) {
        launchFailure = LaunchFailureLowStorageSpaceAvailable;
    } else if (StorageCoordinator.hasInvalidDatabaseVersion) {
        // Prevent:
        // * Users with an unknown GRDB schema revert to using an earlier GRDB schema.
        launchFailure = LaunchFailureUnknownDatabaseVersion;
    }

    if (launchFailure != LaunchFailureNone) {
//        [InstrumentsMonitor stopSpanWithCategory:@"appstart" hash:monitorId];
        OWSLogError(@"application: didFinishLaunchingWithOptions failed.");
        [self showLaunchFailureUI:[NSError errorWithDomain:@"error.difft.org" code:10000 userInfo:nil]];
//        [self showUIForLaunchFailure:launchFailure];

        return YES;
    }
    
    [UIUtil setupSignalAppearence];

    if (CurrentAppContext().isRunningTests) {
        return YES;
    }

    UIWindow *mainWindow = [[OWSWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window = mainWindow;
    CurrentAppContext().mainWindow = mainWindow;
    // Show LoadingViewController until the async database view registrations are complete.
    mainWindow.rootViewController = [LoadingViewController new];
    [mainWindow makeKeyAndVisible];
    
//    [AppUpdateNag.sharedInstance showAppUpgradeNagIfNecessary];

    [OWSScreenLockUI.sharedManager setupWithRootWindow:self.window];
    [[OWSWindowManager sharedManager] setupWithRootWindow:self.window
                                     screenBlockingWindow:OWSScreenLockUI.sharedManager.screenBlockingWindow];
    [OWSScreenLockUI.sharedManager startObserving];

    // Ensure OWSContactsSyncing is instantiated.
//    [OWSContactsSyncing sharedManager];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storageIsReady)
                                                 name:StorageIsReadyNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(registrationStateDidChange)
                                                 name:NSNotificationNameRegistrationStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(registrationLockDidChange:)
                                                 name:NSNotificationName_2FAStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loginWithNewNumber:)
                                                 name:NSNotificationNameLoginWithNewNumber
                                               object:nil];

    OWSLogInfo(@"%@ application: didFinishLaunchingWithOptions completed.", self.logTag);

    [OWSAnalytics appLaunchDidBegin];
    
    [CurrentAppContext() setColdStart:YES];
    
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if([TSAccountManager sharedInstance].isRegistered){
            [[DTCallManager sharedInstance] requestForConfigMeetingversion];
        }
    });
    
    [self addLocalNotificationDelegate];
    
    return YES;
}

- (BOOL)setupCrashAndLogReport {
    BOOL isLoggingEnabled = TRUE;
    
#ifdef DEBUG
    // Specified at Product -> Scheme -> Edit Scheme -> Test -> Arguments -> Environment to avoid things like
    // the phone directory being looked up during tests.
    [DebugLogger.shared enableTTYLoggingIfNeeded];
#elif RELEASE
    isLoggingEnabled = OWSPreferences.isLoggingEnabled;
#endif
    
    if (isLoggingEnabled) {
        
        [OWSPreferences setIsLoggingEnabled:TRUE];
        [DebugLogger.shared enableFileLoggingWithAppContext:CurrentAppContext() canLaunchInBackground:YES];
    }
        
    
#ifdef RELEASE_TEST
//        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info-chative" ofType:@"plist"];
//        FIROptions *option = [[FIROptions alloc] initWithContentsOfFile:filePath];
//        [FIRApp configureWithOptions:option];
//        
//        OWSLogDebug(@"WeaTest begin begin config firebase");
#elif RELEASE
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info-chative" ofType:@"plist"];
        FIROptions *option = [[FIROptions alloc] initWithContentsOfFile:filePath];
        [FIRApp configureWithOptions:option];
        
        OWSLogDebug(@"tt begin config firebase.");
#endif
    
    return isLoggingEnabled;
}

- (void)showLaunchFailureUI:(NSError *)error
{
    // Disable normal functioning of app.
    self.didAppLaunchFail = YES;

    // We perform a subset of the [application:didFinishLaunchingWithOptions:].
    [AppVersion shared];

    UIWindow *mainWindow = [[OWSWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window = mainWindow;
    CurrentAppContext().mainWindow = mainWindow;

    // Show the launch screen
    self.window.rootViewController =
        [[UIStoryboard storyboardWithName:@"Launch Screen" bundle:nil] instantiateInitialViewController];
    [self.window makeKeyAndVisible];

    NSString *title = [NSString stringWithFormat:Localized(@"APP_LAUNCH_FAILURE_ALERT_TITLE",
                                                           @"Title for the 'app launch failed' alert."), TSConstants.appDisplayName];
    NSString *message = [NSString stringWithFormat:Localized(@"APP_LAUNCH_FAILURE_ALERT_MESSAGE",
                                                             @"Message for the 'app launch failed' alert."), TSConstants.appDisplayName];
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:title
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];

    [controller addAction:[UIAlertAction actionWithTitle:Localized(@"SETTINGS_ADVANCED_SUBMIT_DEBUGLOG", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
        [DTToastHelper toastWithText:@"Not supported and will exit." durationTime:3 completion:^{
            exit(0);
        }];
    }]];
    UIViewController *fromViewController = [[UIApplication sharedApplication] frontmostViewController];
    [fromViewController presentViewController:controller animated:YES completion:nil];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }
    [PushRegistrationManager.sharedManager didReceiveVanillaPushToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }

    OWSLogError(@"%@ failed to register vanilla push token with error: %@", self.logTag, error);
#ifdef DEBUG
    OWSLogWarn(
        @"%@ We're in debug mode. Faking success for remote registration with a fake push identifier", self.logTag);
    [PushRegistrationManager.sharedManager didReceiveVanillaPushToken:[[NSMutableData dataWithLength:32] copy]];
#else
    OWSProdError([OWSAnalyticsEvents appDelegateErrorFailedToRegisterForRemoteNotifications]);
    [PushRegistrationManager.sharedManager didFailToReceiveVanillaPushTokenWithError:error];
#endif
}

//- (void)application:(UIApplication *)application
//    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
//{
//    OWSAssertIsOnMainThread();
//
//    if (self.didAppLaunchFail) {
//        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
//        return;
//    }
//
//    OWSLogInfo(@"%@ registered user notification settings", self.logTag);
//    [PushRegistrationManager.sharedManager didRegisterUserNotificationSettings];
//}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    OWSAssertIsOnMainThread();
    
    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return NO;
    }

//    if (![TSAccountManager isRegistered] || [[TSAccountManager shared] isDeregistered]) {
//        return NO;
//    }
//    
//    if (!AppReadiness.isAppReady) {
//        OWSLogWarn(@"%@ Ignoring openURL: app not ready.", self.logTag);
//        // We don't need to use [AppReadiness runNowOrWhenAppIsReady:];
//        // the only URLs we handle in Signal iOS at the moment are used
//        // for resuming the verification step of the registration flow.
//        return NO;
//    }
    
    if([self handleCustomSchemesWithUrl:url]){
        return YES;
    }
    
    
    return NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }

    OWSLogWarn(@"%@ applicationDidBecomeActive.", self.logTag);
    if (CurrentAppContext().isRunningTests) {
        return;
    }

    [self ensureRootViewController];

    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        [self handleActivation];
        [DTMeetingManager.shared syncServerCalls];
        // There is a sequence of actions a user can take where we present a conversation from a notification
        // multiple times, producing an undesirable "stack" of multiple conversation view controllers.
        // So we ensure that we only present conversations once per activate.
        [PushManager sharedManager].hasPresentedConversationSinceLastDeactivation = NO;
    });

    // Clear all notifications whenever we become active.
    // When opening the app from a notification,
    // AppDelegate.didReceiveLocalNotification will always
    // be called _before_ we become active.
    [self clearAllNotificationsAndRestoreBadgeCount];
    OWSLogInfo(@"%@ applicationDidBecomeActive completed.", self.logTag);
}

//TODO: 待处理
- (void)enableBackgroundRefreshIfNecessary
{
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if (OWS2FAManager.sharedManager.is2FAEnabled && [TSAccountManager isRegistered]) {
            // Ping server once a day to keep-alive 2FA clients.
            const NSTimeInterval kBackgroundRefreshInterval = 24 * 60 * 60;
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:kBackgroundRefreshInterval];
        } else {
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
        }
    });
}

extern bool bScreenLockDone;

- (void)handleActivation
{
    OWSAssertIsOnMainThread();

    OWSLogWarn(@"%@ handleActivation. (memoryUsage: %@)", self.logTag, LocalDevice.memoryUsageString);

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        if ([TSAccountManager isRegistered]) {
            // At this point, potentially lengthy DB locking migrations could be running.
            // Avoid blocking app launch by putting all further possible DB access in async block
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                OWSLogInfo(@"%@ running post launch block for registered user: %@",
                    self.logTag,
                    [TSAccountManager localNumber]);

                // Clean up any messages that expired since last launch immediately
                // and continue cleaning in the background.
                [[OWSArchivedMessageJob sharedJob] startIfNecessary];
                [[DTRecallMessagesJob sharedJob] startIfNecessary];
                [[DTConversationsJob sharedJob] startIfNecessary];

                [self enableBackgroundRefreshIfNecessary];

                // Mark all "attempting out" messages as "unsent", i.e. any messages that were not successfully
                // sent before the app exited should be marked as failures.
                //TODO OWSFailedMessagesJob
//                [[[OWSFailedMessagesJob alloc] initWithPrimaryStorage:[OWSPrimaryStorage sharedManager]] run];
                // Mark all "incomplete" calls as missed, e.g. any incoming or outgoing calls that were not
                // connected, failed or hung up before the app existed should be marked as missed.
//                [[[OWSIncompleteCallsJob alloc] initWithPrimaryStorage:[OWSPrimaryStorage sharedManager]] run];
                [[FailedAttachmentDownloadsJob new] runSync];
                [[FailedMessagesJob new] runSync];
                [self.notificationsManager syncApnSoundIfNeeded];
                
                [self initializeMeetingManager];
                
                // 更新一次网络本地配置
                [[DTSettingsManager shared] syncRemoteProfileInfo];
                // 卡顿检测
#if DEBUG_TEST || RELEASE_TEST || RELEASE_CHATIVETEST
                [SMCallTrace start];
                [[SMLagMonitor shareInstance] beginMonitor];
#endif
                // 将之前打断的数据再次进行
                [[DTSettingsManager shared] checkResetKeyMap];
                // 开始测速
                [[DTMeetingManager shared] startSpeedTest];
            });
            
            [self addUpLoadTimeZonObserver];
            
                        
        } else {
            OWSLogInfo(@"%@ running post launch block for unregistered user.", self.logTag);

            // Unregistered user should have no unread messages. e.g. if you delete your account.
            [self clearAllNotificationsAndRestoreBadgeCount];

        }
    }); // end dispatchOnce for first time we become active

    // Every time we become active...
    // TODO: 梳理出真正需要上报的时机再加回 isRegisteredAndReady
    if ([TSAccountManager isRegistered]) {
        // At this point, potentially lengthy DB locking migrations could be running.
        // Avoid blocking app launch by putting all further possible DB access in async block
        dispatch_async(dispatch_get_main_queue(), ^{
//            [TSSocketManager requestSocketOpen];
            [self reportBackgroundStatusByWebSocket:NO];
            
            [self uploadTimeZone];

            // modified: do not access system contacts.
            //[Environment.shared.contactsManager fetchSystemContactsOnceIfAlreadyAuthorized];
            // This will fetch new messages, if we're using domain fronting.
            if (![UIApplication sharedApplication].isRegisteredForRemoteNotifications) {
                OWSLogInfo(
                    @"%@ Retrying to register for remote notifications since user hasn't registered yet.", self.logTag);
                // Push tokens don't normally change while the app is launched, so checking once during launch is
                // usually sufficient, but e.g. on iOS11, users who have disabled "Allow Notifications" and disabled
                // "Background App Refresh" will not be able to obtain an APN token. Enabling those settings does not
                // restart the app, so we check every activation for users who haven't yet registered.
                __unused AnyPromise *promise =
                    [OWSSyncPushTokensJob runWithAccountManager:SignalApp.sharedApp.accountManager
                                                    preferences:[Environment preferences]];
            }

            if ([OWS2FAManager sharedManager].isDueForReminder) {
                if (!self.hasInitialRootViewController || self.window.rootViewController == nil) {
                    OWSLogDebug(
                        @"%@ Skipping 2FA reminder since there isn't yet an initial view controller", self.logTag);
                } else {
                    UIViewController *rootViewController = self.window.rootViewController;
                    OWSNavigationController *reminderNavController =
                        [OWS2FAReminderViewController wrappedInNavController];

                    [rootViewController presentViewController:reminderNavController animated:YES completion:nil];
                }
            }
            
            [[DTConversationSettingHelper sharedInstance] requestAllActiveThreadsConversationSettingAndSaveResult];
        });
    }

    OWSLogInfo(@"%@ handleActivation completed. (memoryUsage: %@)", self.logTag, LocalDevice.memoryUsageString);
    
    // added: call the update checking after successing to call screenlock
    // otherwise, do it before main window showing
    if ( !ScreenLock.sharedManager.isScreenLockEnabled || (bScreenLockDone&&ScreenLock.sharedManager.isScreenLockEnabled)) {
        [AppUpdateNag.sharedInstance showAppUpgradeNagIfNecessary];
        // reset the flag
        bScreenLockDone = false;
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }
    
    if(CurrentAppContext()){
        [CurrentAppContext() setColdStart:false];
    }
    
    
    [self clearAllNotificationsAndRestoreBadgeCount];
    
    OWSLogWarn(@"%@ applicationWillResignActive.", self.logTag);
    
    [DDLog flushLog];
}

- (void)application:(UIApplication *)application
    performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem
               completionHandler:(void (^)(BOOL succeeded))completionHandler {
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }

    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if (![TSAccountManager isRegistered]) {
            UIAlertController *controller =
                [UIAlertController alertControllerWithTitle:Localized(@"REGISTER_CONTACTS_WELCOME", nil)
                                                    message:Localized(@"REGISTRATION_RESTRICTED_MESSAGE", nil)
                                             preferredStyle:UIAlertControllerStyleAlert];

            [controller addAction:[UIAlertAction actionWithTitle:Localized(@"OK", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *_Nonnull action){

                                                         }]];
            UIViewController *fromViewController = [[UIApplication sharedApplication] frontmostViewController];
            [fromViewController presentViewController:controller
                                             animated:YES
                                           completion:^{
                                               completionHandler(NO);
                                           }];
            return;
        }

        completionHandler(YES);
    });
}

/**
 * Among other things, this is used by "call back" callkit dialog and calling from native contacts app.
 *
 * We always return YES if we are going to try to handle the user activity since
 * we never want iOS to contact us again using a URL.
 *
 * From https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623072-application?language=objc:
 *
 * If you do not implement this method or if your implementation returns NO, iOS tries to
 * create a document for your app to open using a URL.
 */
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    OWSAssertIsOnMainThread();
    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return NO;
    }
    // 处理 universal links difft.optillel.com/meeting/v1?channelname=xxx&meetingname=xxx
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        
        NSURLComponents *component = [[NSURLComponents alloc] initWithURL:userActivity.webpageURL resolvingAgainstBaseURL:YES];
        
        if([self handleUniversalLinkWithUrl:component.URL]){
            return YES;
        }
    }
    
    if ([userActivity.activityType isEqualToString: @"INStartAudioCallIntent"]) {
        INInteraction *interaction = userActivity.interaction;
        INStartAudioCallIntent *startAudioCallIntent = (INStartAudioCallIntent *)interaction.intent;
        INPerson *contact = startAudioCallIntent.contacts[0];
        INPersonHandle *personHandle = contact.personHandle;
        NSString *contactID = personHandle.value;
      
        //MARK: 多人允许不允许回拨
        if (![contactID hasPrefix:@"+"]) return NO;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startCallByCallKitWithID:contactID];
        });
        return YES;
    }
    
    if ([userActivity.activityType isEqualToString: @"INStartVideoCallIntent"]) {
        // TODO：henry基于livekit实现打开的逻辑
//        [[DTMultiCallManager sharedManager] didOpenVideoByCallKit];
        return YES;
    }

    return NO;
}

- (void)startCallByCallKitWithID:(NSString *)contactID {
    /// 点击系统通讯录回拨获取contentID
    if (contactID == nil) {
        return;
    }
    if (contactID.length > 6) {
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            TSThread *thread = [TSContactThread getOrCreateThreadWithContactId: contactID transaction:writeTransaction];
            [writeTransaction addAsyncCompletionOnMain:^{
                NSArray *callAccounts = nil;
                if ([thread isKindOfClass:TSContactThread.class]) {
                    callAccounts = [thread contactIdentifier_containMac_callNumbers];
                } else if ([thread isKindOfClass:TSGroupThread.class]) {
                    callAccounts = [thread recipientIdentifiers_containMac_callNumbers];
                }
                [DTMeetingManager.shared startCallWithThread:thread recipientIds:callAccounts displayLoading:NO];
            }];
        });
    }
}

#pragma mark Push Notifications Delegate Methods


- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    OWSAssertIsOnMainThread();

    if (self.didAppLaunchFail) {
        OWSFailDebug(@"%@ %s app launch failed", self.logTag, __PRETTY_FUNCTION__);
        return;
    }
    
    // It is safe to continue even if the app isn't ready.
    
    [[PushManager sharedManager] application:application
                didReceiveRemoteNotification:userInfo
                      fetchCompletionHandler:completionHandler];
}

//TODO: 待处理
- (void)application:(UIApplication *)application
    performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    OWSLogInfo(@"%@ performing background fetch", self.logTag);
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        
        [self.messageFetcherJob runObjc].done(^(id value) {
            // HACK: Call completion handler after n seconds.
            //
            // We don't currently have a convenient API to know when message fetching is *done* when
            // working with the websocket.
            //
            // We *could* substantially rewrite the TSSocketManager to take advantage of the `empty` message
            // But once our REST endpoint is fixed to properly de-enqueue fallback notifications, we can easily
            // use the rest endpoint here rather than the websocket and circumvent making changes to critical code.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                completionHandler(UIBackgroundFetchResultNewData);
            });
        });
    });
}

- (void)versionMigrationsDidComplete
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"%@ versionMigrationsDidComplete", self.logTag);

    self.areVersionMigrationsComplete = YES;

    [self checkIfAppIsReady];
}


#pragma mark - notification action

- (void)storageIsReady
{
    OWSAssertIsOnMainThread();
    OWSLogInfo(@"%@ storageIsReady", self.logTag);

    [self checkIfAppIsReady];
}

- (void)checkIfAppIsReady
{
    OWSAssertIsOnMainThread();
    
    //GRDB-Kris--
    // If launch failed, the app will never be ready.
    if(_didAppLaunchFail){
        return;
    }

    // App isn't ready until storage is ready AND all version migrations are complete.
    if (!self.areVersionMigrationsComplete) {
        return;
    }
    
    if(![self.storageCoordinator isStorageReady]){
        return;
    }
    
    if ([AppReadiness isAppReady]) {
        // Only mark the app as ready once.
        return;
    }

    OWSLogInfo(@"%@ checkIfAppIsReady", self.logTag);

    // TODO: Once "app ready" logic is moved into AppSetup, move this line there.
    // TODO: write on main thread
    [[OWSProfileManager sharedManager] ensureLocalProfileCached];
    
    // Note that this does much more than set a flag;
    // it will also run all deferred blocks.
    [AppReadiness setAppIsReady];

    if ([TSAccountManager isRegistered]) {
        OWSLogDebug(@"localNumber: %@", [TSAccountManager localNumber]);

        // Fetch messages as soon as possible after launching. In particular, when
        // launching from the background, without this, we end up waiting some extra
        // seconds before receiving an actionable push notification.
        [self.messageFetcherJob runObjc];

        // This should happen at any launch, background or foreground.
        __unused AnyPromise *pushTokenpromise =
            [OWSSyncPushTokensJob runWithAccountManager:SignalApp.sharedApp.accountManager
                                            preferences:[Environment preferences]];
    }

    [DeviceSleepManager.shared removeBlockWithBlockObject:self];

    [AppVersion.shared mainAppLaunchDidComplete];
    
    [Environment.shared.contactsManager loadSignalAccountsFromCache];
    
//    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * transaction) {
//        [TSGroupThread anyEnumerateWithTransaction:transaction
//                                           batched:YES
//                                             block:^(TSThread * thread, BOOL * stop) {
//            if([thread isKindOfClass:[TSGroupThread class]]) {
//                TSGroupThread *groupThread = (TSGroupThread *)thread;
//                if(![groupThread validateGroupId:groupThread.groupModel.groupId]){
//                    [groupThread anyRemoveWithTransaction:transaction];
//                }
//            }
//        }];
//    }];
    

    if (!Environment.preferences.hasGeneratedThumbnails) {
        [self.databaseStorage
            asyncReadWithBlock:^(SDSAnyReadTransaction *transaction) {
                [TSAttachment anyEnumerateWithTransaction:transaction
                                                  batched:YES
                                                    block:^(TSAttachment *attachment, BOOL *stop) {
                                                        // no-op. It's sufficient to initWithCoder: each object.
                                                    }];
            }
            completion:^{
                [Environment.shared.preferences setHasGeneratedThumbnails:YES];
            }];
    }

#ifdef DEBUG
    // A bug in orphan cleanup could be disastrous so let's only
    // run it in DEBUG builds for a few releases.
    //
    // TODO: Release to production once we have analytics.
    // TODO: Orphan cleanup is somewhat expensive - not least in doing a bunch
    //       of disk access.  We might want to only run it "once per version"
    //       or something like that in production.
//    [OWSOrphanedDataCleaner auditAndCleanupAsync:nil];
#endif
    //MARK: 清空未关联消息的reactionMessage
    [DTReactionHelper clearAllReactionMessage];
    
    [OWSProfileManager.sharedManager fetchLocalUsersProfile];
    [[OWSReadReceiptManager sharedManager] prepareCachedValues];

    // Disable the SAE until the main app has successfully completed launch process
    // at least once in the post-SAE world.
    [OWSPreferences setIsReadyForAppExtensions];

    [self ensureRootViewController];
    
//    [self.messageManager startObserving];
    
}

// 登陆状态改变
- (void)registrationStateDidChange
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"registrationStateDidChange");

    [self enableBackgroundRefreshIfNecessary];

    if ([TSAccountManager isRegistered]) {
        OWSLogInfo(@"%@ localNumber: %@", [TSAccountManager localNumber], self.logTag);
        
        [self.messageFetcherJob runObjc];
        [self uploadTimeZone];
        // Start running the disappearing messages job in case the newly registered user
        // enables this feature
        [[OWSArchivedMessageJob sharedJob] startIfNecessary];
        [[DTRecallMessagesJob sharedJob] startIfNecessary];
        [[DTConversationsJob sharedJob] startIfNecessary];
        [[OWSProfileManager sharedManager] ensureLocalProfileCached];

        // For non-legacy users, read receipts are on by default.
        [OWSReadReceiptManager.sharedManager setAreReadReceiptsEnabled:YES];
    }
}

- (void)registrationLockDidChange:(NSNotification *)notification
{
    [self enableBackgroundRefreshIfNecessary];
}

- (void)loginWithNewNumber:(NSNotification *)notification {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:Localized(@"CONFIRM_NEW_ACCOUNT_LOGIN_TITLE", nil) message:Localized(@"CONFIRM_NEW_ACCOUNT_LOGIN_TIP_MESSAGE", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:Localized(@"CONFIRM_NEW_ACCOUNT_LOGIN_CONFIRM", nil)
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
        [SignalApp resetAppData];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:Localized(@"TXT_CANCEL_TITLE", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        [RegistrationUtils showNewLoginView:CurrentAppContext().frontmostViewController];
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *fromViewController = CurrentAppContext().frontmostViewController;
        [fromViewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)resetViewControllerToUnregistered {
    
    OWSAssertDebug([TSAccountManager sharedInstance].localNumber != nil);
    
    [[TSAccountManager sharedInstance] resetForReregistration];
//    [[TSSocketManager sharedManager] deregisteredBrokenSocket];
    [[OWSWindowManager sharedManager] setIsScreenBlockActive:NO];
    OWSScreenLockUI.sharedManager.screenBlockingWindow.windowLevel = UIWindowLevel_Background;
    [SignalApp resetAppDataNoExit];
    
    UIViewController *viewController = [DTSignChativeController new];
    OWSNavigationController *navigationController =
        [[OWSNavigationController alloc] initWithRootViewController:viewController];
    navigationController.navigationBarHidden = YES;
    self.window.rootViewController = navigationController;
}

- (void)ensureRootViewController
{
    OWSAssertIsOnMainThread();
    
    if (!AppReadiness.isAppReady || self.hasInitialRootViewController) {
        return;
    }
    self.hasInitialRootViewController = YES;

    NSTimeInterval startupDuration = CACurrentMediaTime() - launchStartedAt;
    OWSLogInfo(@"%@ Presenting app %.2f seconds after launch started.", self.logTag, startupDuration);

    if ([TSAccountManager isRegistered]) {
        [self switchToTabbarVCFromRegistration:YDBDataMigrator.shared.yapdatabaseRegister];
    } else {
        
        LoginViewController *viewController = [LoginViewController new];
        OWSNavigationController *navigationController =
            [[OWSNavigationController alloc] initWithRootViewController:viewController];
        
        self.window.rootViewController = navigationController;
    }

//    [AppUpdateNag.sharedInstance showAppUpgradeNagIfNecessary];
}

- (void)switchToTabbarVCFromRegistration:(BOOL)isFromRegistration {
    // 首页
    DTHomeViewController *homeVC = [DTHomeViewController new];
    homeVC.isFromRegistration = isFromRegistration;
    homeVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:Localized(@"TABBAR_HOME", @"Title for Tab Home") image:[UIImage imageNamed:@"tabbar_message"] selectedImage:[UIImage imageNamed:@"tabbar_message_selected"]];
    OWSNavigationController *homeNavController =
    [[OWSNavigationController alloc] initWithRootViewController:homeVC];
    
    // 联系人
    DTContactsViewController *contactVC = [DTContactsViewController new];
    contactVC.shouldUseTheme = YES;
    contactVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:Localized(@"TABBAR_CONTACT", @"Title for Tab Contact") image:[UIImage imageNamed:@"tabbar_contact"] selectedImage:[UIImage imageNamed:@"tabbar_contact_selected"]];
    OWSNavigationController *contactNavController =
    [[OWSNavigationController alloc] initWithRootViewController:contactVC];


    // 我的
    AppSettingsViewController *settingVC = [AppSettingsViewController new];
    settingVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:Localized(@"TABBAR_ME", @"Title for Tab Me") image:[UIImage imageNamed:@"tabbar_me"] selectedImage:[UIImage imageNamed:@"tabbar_me_selected"]];
    OWSNavigationController *settingNavController =
    [[OWSNavigationController alloc] initWithRootViewController:settingVC];
    
    self.tabbarVC = [DFTabbarController new];
    
    self.tabbarVC.viewControllers = @[homeNavController,
                                      contactNavController,
                                      settingNavController];

    
    self.window.rootViewController = self.tabbarVC;
    
    if (isFromRegistration || [Environment.shared.contactsManager contactsShouldBeInitialized]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [Environment.shared.contactsManager userRequestedSystemContactsRefreshWithIsUserRequested:YES completion:^(NSError * _Nullable error) {
            }];
            
            [DTGroupUtils syncMyGroupsBaseInfoSuccess:^{
                OWSLogInfo(@"syncMyGroupsBaseInfoSuccess!");
            } failure:^(NSError * _Nonnull error) {
                OWSLogError(@"syncMyGroupsBaseInfoFail:%@.", error);
            }];
        });
    }
}
#pragma mark - status bar touches
//TODO: 待处理
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    CGPoint location = [[[event allTouches] anyObject] locationInView:[self window]];
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    if (CGRectContainsPoint(statusBarFrame, location)) {
        OWSLogDebug(@"%@ touched status bar", self.logTag);
        [[NSNotificationCenter defaultCenter] postNotificationName:TappedStatusBarNotification object:nil];
    }
}

- (void)setupNSEInteroperation
{
    OWSLogInfo(@"");
    // We immediately post a notification letting the NSE know the main app has launched.
    // If it's running it should take this as a sign to terminate so we don't unintentionally
    // try and fetch messages from two processes at once.
    [DarwinNotificationCenter postNotificationName:DarwinNotificationName.mainAppLaunched];

    // We listen to this notification for the lifetime of the application, so we don't
    // record the returned observer token.
    [DarwinNotificationCenter
        addObserverForName:DarwinNotificationName.nseDidReceiveNotification
                     queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
                usingBlock:^(int token) {
                    OWSLogDebug(@"Handling NSE received notification");

                    // Immediately let the NSE know we will handle this notification so that it
                    // does not attempt to process messages while we are active.
                    [DarwinNotificationCenter postNotificationName:DarwinNotificationName.mainAppHandledNotification];

            
                    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
                        [self.messageFetcherJob runObjc];
                    });
                }];
}

// TODO: 待优化
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    
    if (window.windowLevel == UIWindowLevel_CallView() && window.isKeyWindow) {
            
        UIViewController *topVC = [window findTopViewController];
//        OWSLogDebug(@"------ %@ --- %@", window, topVC.class);
        if ([topVC isKindOfClass:UIAlertController.class] || [NSStringFromClass(topVC.class) containsString:@"ZL"]) {
            UIViewController *presentingVC = topVC.presentingViewController;
            if ([NSStringFromClass(presentingVC.class) containsString:@"DTHostingController"]) {
                if ([DTMeetingManager.shared isPresentedShare] && [NSStringFromClass(presentingVC.class) containsString:@"CallScreenShareView"]) {
                    return UIInterfaceOrientationMaskLandscape;
                } else {
                    return UIInterfaceOrientationMaskPortrait;
                }
            } else {
                return [presentingVC supportedInterfaceOrientations];
            }
        }
        
        if ([NSStringFromClass(topVC.class) containsString:@"DTHostingController"]) {
            if ([DTMeetingManager.shared isPresentedShare] && [NSStringFromClass(topVC.class) containsString:@"CallScreenShareView"]) {
                return UIInterfaceOrientationMaskLandscape;
            } else {
                return UIInterfaceOrientationMaskPortrait;
            }
        } else {
            return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape;
        }
    } else if (window.windowLevel == UIWindowLevel_ScreenBlocking() || window.windowLevel == UIWindowLevel_Background) {
        DTMeetingManager *meetingManager = [DTMeetingManager shared];
        if (!meetingManager.hasMeeting) {
            return UIInterfaceOrientationMaskPortrait;
        }
        if (meetingManager.isMinimize) {
            return UIInterfaceOrientationMaskPortrait;
        }
        if (!meetingManager.isPresentedShare) {
            return UIInterfaceOrientationMaskPortrait;
        }

        return UIInterfaceOrientationMaskLandscape;
    } else if (window.windowLevel == UIWindowLevel_AlertCallView()) {

        return UIInterfaceOrientationMaskPortrait;
    } else {
        id topVC = [window findTopViewController];
        if ([topVC isKindOfClass:QLPreviewController.class]) {
            return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape;
        }
        
        return UIInterfaceOrientationMaskPortrait;
    }
}


@end
