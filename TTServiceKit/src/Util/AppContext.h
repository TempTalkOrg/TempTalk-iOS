//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

static inline BOOL OWSIsDebugBuild(void)
{
#ifdef DEBUG
    return YES;
#else
    return NO;
#endif
}

static inline BOOL OWSIsTestableBuild(void)
{
#ifdef TESTABLE_BUILD
    return YES;
#else
    return NO;
#endif
}

// These are fired whenever the corresponding "main app" or "app extension"
// notification is fired.
//
// 1. This saves you the work of observing both.
// 2. This allows us to ensure that any critical work (e.g. re-opening
//    databases) has been done before app re-enters foreground, etc.
extern NSString *const OWSApplicationDidEnterBackgroundNotification;
extern NSString *const OWSApplicationWillEnterForegroundNotification;
extern NSString *const OWSApplicationWillResignActiveNotification;
extern NSString *const OWSApplicationDidBecomeActiveNotification;

typedef void (^BackgroundTaskExpirationHandler)(void);

NSString *NSStringForUIApplicationState(UIApplicationState value);

@class ActionSheetAction;
@class SSKAES256Key;
@protocol SSKKeychainStorage;

@protocol AppContext <NSObject>

@property (nonatomic, readonly) BOOL isMainApp;
@property (nonatomic, readonly) BOOL isMainAppAndActive;
@property (nonatomic, readonly) BOOL isNSE;
//TODO:temptalk need handle
@property (nonatomic, readonly) BOOL isColdStart;

// Whether the user is using a right-to-left language like Arabic.
@property (nonatomic, readonly) BOOL isRTL;

@property (nonatomic, readonly) BOOL isRunningTests;

@property (atomic, nullable) UIWindow *mainWindow;

@property (nonatomic, readonly) CGRect frame;

@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, readonly) BOOL isInMeeting;

// Unlike UIApplication.applicationState, this is thread-safe.
// It contains the "last known" application state.
//
// Because it is updated in response to "will/did-style" events, it is
// conservative and skews toward less-active and not-foreground:
//
// * It doesn't report "is active" until the app is active
//   and reports "inactive" as soon as it _will become_ inactive.
// * It doesn't report "is foreground (but inactive)" until the app is
//   foreground & inactive and reports "background" as soon as it _will
//   enter_ background.
//
// This conservatism is useful, since we want to err on the side of
// caution when, for example, we do work that should only be done
// when the app is foreground and active.
@property (atomic, readonly) UIApplicationState reportedApplicationState;

// A convenience accessor for reportedApplicationState.
//
// This method is thread-safe.
- (BOOL)isInBackground;

// A convenience accessor for reportedApplicationState.
//
// This method is thread-safe.
- (BOOL)isAppForegroundAndActive;

// Should start a background task if isMainApp is YES.
// Should just return UIBackgroundTaskInvalid if isMainApp is NO.
- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:
    (BackgroundTaskExpirationHandler)expirationHandler;

// Should be a NOOP if isMainApp is NO.
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier;

// Should be a NOOP if isMainApp is NO.
- (void)ensureSleepBlocking:(BOOL)shouldBeBlocking blockingObjectsDescription:(NSString *)blockingObjectsDescription;

// Should only be called if isMainApp is YES.
- (void)setMainAppBadgeNumber:(NSInteger)value;

- (void)setStatusBarHidden:(BOOL)isHidden animated:(BOOL)isAnimated;

- (void)setColdStart:(BOOL)isColdStart;

@property (nonatomic, readonly) CGFloat statusBarHeight;

// Returns the VC that should be used to present alerts, modals, etc.
- (nullable UIViewController *)frontmostViewController;

// Returns nil if isMainApp is NO
// TODO: ⚠️废弃
@property (nullable, nonatomic, readonly) UIAlertAction *openSystemSettingsAction;
// Returns nil if isMainApp is NO
- (nullable ActionSheetAction *)openSystemSettingsActionWithCompletion:(void (^_Nullable)(void))completion;

// Should only be called if isMainApp is YES,
// but should only be necessary to call if isMainApp is YES.
- (void)doMultiDeviceUpdateWithProfileKey:(SSKAES256Key *)profileKey;

// Should be a NOOP if isMainApp is NO.
- (void)setNetworkActivityIndicatorVisible:(BOOL)value;

@property (atomic, readonly) NSDate *appLaunchTime;

@property (nonatomic, readonly) BOOL shouldProcessIncomingMessages;

- (id<SSKKeychainStorage>)keychainStorage;

// This method should only be called by the main app.
- (UIApplicationState)mainApplicationStateOnLaunch;

- (BOOL)canPresentNotifications;

- (NSString *)appDocumentDirectoryPath;

- (NSString *)appSharedDataDirectoryPath;

- (NSString *)appDatabaseBaseDirectoryPath;

- (NSUserDefaults *)appUserDefaults;

@property (nonatomic, readonly) BOOL hasUI;

@property (nonatomic, readonly) NSString *debugLogsDirPath;

@end

id<AppContext> CurrentAppContext(void);
void SetCurrentAppContext(id<AppContext> appContext, BOOL isRunningTests);

void ExitShareExtension(void);

NS_ASSUME_NONNULL_END
