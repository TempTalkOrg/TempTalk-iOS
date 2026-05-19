//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSScreenLockUI.h"
#import "OWSWindowManager.h"
#import "Yelling-Swift.h"
#import <TTMessaging/ScreenLockViewController.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIView+SignalUI.h>

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const ScreenLockDidUnlockNotification = @"ScreenLockDidUnlockNotification";

@interface OWSScreenLockUI () <ScreenLockViewDelegate>

@property (nonatomic) UIWindow *screenBlockingWindow;
@property (nonatomic, readwrite) BOOL isShowingScreenLockUI;
@property (nonatomic) ScreenLockViewController *screenBlockingViewController;

// Unlike UIApplication.applicationState, this state reflects the
// notifications, i.e. "did become active", "will resign active",
// "will enter foreground", "did enter background".
//
// We want to update our state to reflect these transitions and have
// the "update" logic be consistent with "last reported" state. i.e.
// when you're responding to "will resign active", we need to behave
// as though we're already inactive.
//
// Secondly, we need to show the screen protection _before_ we become
// inactive in order for it to be reflected in the app switcher.
@property (nonatomic) BOOL appIsInactiveOrBackground;
@property (nonatomic) BOOL appIsInBackground;

@property (nonatomic) BOOL didLastUnlockAttemptFail;

// We want to remain in "screen lock" mode while "local auth"
// UI is dismissing. So we lazily clear isShowingScreenLockUI
// using this property.
@property (nonatomic) BOOL shouldClearAuthUIWhenActive;

// Indicates whether or not the user is currently locked out of
// the app.  Should only be set if OWSScreenLock.isScreenLockEnabled.
//
// * The user is locked out by default on app launch.
// * The user is also locked out if they spend more than
//   "timeout" seconds outside the app.  When the user leaves
//   the app, a "countdown" begins.
@property (nonatomic) BOOL isScreenLockLocked;

// The "countdown" until screen lock takes effect.
@property (nonatomic, nullable) NSDate *screenLockCountdownDate;

@property (nonatomic) ScreenLockUIState lastState;
@property (nonatomic) ScreenLockUIState socketLockState;
@property (nonatomic, strong, nullable) NSTimer *offlineTimer;

@property (nonatomic) Reachability *reachability;

@property (nonatomic) BOOL meetingScreenLockBypassed;
@property (nonatomic, strong, nullable) DTScreenLockBaseViewController *unlockScreenVc;
@end

#pragma mark -

@implementation OWSScreenLockUI

+ (instancetype)sharedManager
{
    static OWSScreenLockUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initDefault];
    });
    return instance;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSAssertIsOnMainThread();

    OWSSingletonAssert();

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:OWSApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenLockDidChange:)
                                                 name:ScreenLock.ScreenLockDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenLockPatternDidChange:)
                                                 name:ScreenLock.ScreenLockPatternDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clockDidChange:)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketStateDidChange)
                                                 name:OWSWebSocket.webSocketStateDidChange
                                               object:nil];
}

- (void)setupWithRootWindow:(UIWindow *)rootWindow
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(rootWindow);

    [self createScreenBlockingWindowWithRootWindow:rootWindow];
    OWSAssertDebug(self.screenBlockingWindow);
}

- (void)startObserving
{
    _appIsInactiveOrBackground = [UIApplication sharedApplication].applicationState != UIApplicationStateActive;

    self.reachability = [Reachability reachabilityForInternetConnection];
    
    [self observeNotifications];

    // Hide the screen blocking window until "app is ready" to
    // avoid blocking the loading view.
    [self updateScreenBlockingWindow:ScreenLockUIStateNone animated:NO];
    self.socketLockState = ScreenLockUIStateNone;
    // Initialize the screen lock state.
    //
    // It's not safe to access ScreenLock.isScreenLockEnabled
    // until the app is ready.
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        self.isScreenLockLocked = ScreenLock.sharedManager.isScreenLockOpened;
        
        [self ensureUI];
    });
}

#pragma mark - Methods

- (void)tryToActivateScreenLockBasedOnCountdown
{
    OWSAssertDebug(!self.appIsInBackground);
    OWSAssertIsOnMainThread();

    if (!AppReadiness.isAppReady) {
        // It's not safe to access ScreenLock.isScreenLockEnabled
        // until the app is ready.
        //
        // We don't need to try to lock the screen lock;
        // It will be initialized by `setupWithRootWindow`.
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 0", self.logTag);
        return;
    }
    if (!ScreenLock.sharedManager.isScreenLockOpened) {
        // Screen lock is not enabled.
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 1", self.logTag);
        return;
    }
    if (self.isScreenLockLocked) {
        // Screen lock is already activated.
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 2", self.logTag);
        return;
    }
    
    BOOL hasMeeting = [self isInAnyMeetingState];
    if (hasMeeting && self.meetingScreenLockBypassed) {
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 3 (meeting bypass active)", self.logTag);
        return;
    }
    
    if (hasMeeting && [DTMeetingManager shared].isFromCallkit) {
        self.isScreenLockLocked = YES;
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive YES 4 (forced lock for CallKit meeting)", self.logTag);
        return;
    }
    
    if (!self.screenLockCountdownDate) {
        // We became inactive, but never started a countdown.
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 5", self.logTag);
        return;
    }
    
    NSTimeInterval countdownInterval = fabs([self.screenLockCountdownDate timeIntervalSinceNow]);
    OWSAssertDebug(countdownInterval >= 0);
    NSTimeInterval screenLockTimeout = ScreenLock.sharedManager.screenLockTimeout;
    OWSAssertDebug(screenLockTimeout >= 0);
    if (countdownInterval >= screenLockTimeout) {
        self.isScreenLockLocked = YES;

        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive YES 6 (%0.3f >= %0.3f)",
            self.logTag,
            countdownInterval,
            screenLockTimeout);
    } else {
        DDLogVerbose(@"%@ tryToActivateScreenLockUponBecomingActive NO 7 (%0.3f < %0.3f)",
            self.logTag,
            countdownInterval,
            screenLockTimeout);
    }
}

// Setter for property indicating that the app is either
// inactive or in the background, e.g. not "foreground and active."
- (void)setAppIsInactiveOrBackground:(BOOL)appIsInactiveOrBackground
{
    OWSAssertIsOnMainThread();

    _appIsInactiveOrBackground = appIsInactiveOrBackground;

    if (appIsInactiveOrBackground) {
        if (!self.isShowingScreenLockUI) {
            [self startScreenLockCountdownIfNecessary];
        }
    } else {
        [self tryToActivateScreenLockBasedOnCountdown];

        // Always clear countdown when returning to foreground
        // The countdown is only relevant while the app is in background
        // Once we're back, we've already determined lock state in tryToActivateScreenLockBasedOnCountdown
        OWSLogInfo(@"%@ setAppIsInactiveOrBackground clear screenLockCountdownDate.", self.logTag);
        self.screenLockCountdownDate = nil;
    }

    [self ensureUI];
}

// Setter for property indicating that the app is in the background.
// If true, by definition the app is not active.
- (void)setAppIsInBackground:(BOOL)appIsInBackground
{
    OWSAssertIsOnMainThread();

    _appIsInBackground = appIsInBackground;

    if (self.appIsInBackground) {
        [self startScreenLockCountdownIfNecessary];
    } else {
        [self tryToActivateScreenLockBasedOnCountdown];
    }

    [self ensureUI];
}

- (void)startScreenLockCountdownIfNecessary
{
    DDLogVerbose(@"%@ startScreenLockCountdownIfNecessary: %d", self.logTag, self.screenLockCountdownDate != nil);

    if (!self.screenLockCountdownDate) {
        OWSLogInfo(@"%@ startScreenLockCountdown.", self.logTag);
        self.screenLockCountdownDate = [NSDate new];
    }

    self.didLastUnlockAttemptFail = NO;
    
    if ([self isInAnyMeetingState] && ![DTMeetingManager shared].isFromCallkit && !self.meetingScreenLockBypassed) {
        self.meetingScreenLockBypassed = YES;
        DDLogVerbose(@"%@ startScreenLockCountdownIfNecessary: set meetingScreenLockBypassed (non-CallKit meeting)", self.logTag);
    }
}

// added: flag for screen lock result
bool bScreenLockDone = false;

// Ensure that:
//
// * The blocking window has the correct state.
// * That we show the "iOS auth UI to unlock" if necessary.
- (void)ensureUI
{
    OWSAssertIsOnMainThread();

    if (!AppReadiness.isAppReady) {
        AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
            [self ensureUI];
        });
        return;
    }

    if (self.meetingScreenLockBypassed && ![self isInAnyMeetingState]) {
        self.meetingScreenLockBypassed = NO;
        DDLogVerbose(@"%@ ensureUI: reset meetingScreenLockBypassed (no active meeting)", self.logTag);
    }

    ScreenLockUIState desiredUIState = self.desiredUIState;
    self.lastState = desiredUIState;

    DDLogVerbose(@"%@, ensureUI: %@", self.logTag, NSStringForScreenLockUIState(desiredUIState));

    BOOL isLockActive = (desiredUIState == ScreenLockUIStateScreenLock || desiredUIState == ScreenLockUIStateScreenProtection)
                        && self.isScreenLockLocked;
    if (isLockActive && !self.didLastUnlockAttemptFail) {
        [self tryToPresentAuthUIToUnlockScreenLock];
    }

    [self updateScreenBlockingWindow:desiredUIState animated:YES];
}

- (void)tryToPresentAuthUIToUnlockScreenLock
{
    OWSAssertIsOnMainThread();

    if (self.isShowingScreenLockUI) {
        return;
    }

    OWSLogInfo(@"%@, ows try to unlock screen lock", self.logTag);

    self.isShowingScreenLockUI = YES;
    
    DTScreenLockBaseViewController *unlockScreenVc = [DTScreenLockBaseViewController buildScreenLockViewWithViewType:DTScreenLockViewTypeUnlockScreen doneCallback:^(NSString * _Nullable passcode) {
            OWSLogInfo(@"%@ unlock screen lock succeeded.", self.logTag);

            self.isShowingScreenLockUI = NO;

            self.isScreenLockLocked = NO;
        
            if ([self isInAnyMeetingState]) {
                self.meetingScreenLockBypassed = YES;
                DDLogVerbose(@"%@ unlock during meeting: set meetingScreenLockBypassed", self.logTag);
            }

            self.screenLockCountdownDate = nil;

            bScreenLockDone = true;

            [self removeUnlockScreenVc];

            [self ensureUI];

            [[NSNotificationCenter defaultCenter] postNotificationName:ScreenLockDidUnlockNotification object:nil];
    }];

    self.unlockScreenVc = unlockScreenVc;

    [unlockScreenVc loadViewIfNeeded];
    UIViewController *parentVc = self.screenBlockingViewController;
    [parentVc addChildViewController:unlockScreenVc];
    unlockScreenVc.view.frame = parentVc.view.bounds;
    unlockScreenVc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [parentVc.view addSubview:unlockScreenVc.view];
    [unlockScreenVc didMoveToParentViewController:parentVc];
}

- (void)removeUnlockScreenVc
{
    if (!self.unlockScreenVc) {
        return;
    }
    [self.unlockScreenVc willMoveToParentViewController:nil];
    [self.unlockScreenVc.view removeFromSuperview];
    [self.unlockScreenVc removeFromParentViewController];
    self.unlockScreenVc = nil;
}

// Determines what the state of the app should be.
- (ScreenLockUIState)desiredUIState
{
    if ([self isInAnyMeetingState] && self.meetingScreenLockBypassed) {
        DDLogVerbose(@"%@ desiredUIState: in meeting with bypass active", self.logTag);
        return ScreenLockUIStateNone;
    }
    
    if (self.isScreenLockLocked && [TSAccountManager sharedInstance].isRegistered) {
        if (self.appIsInactiveOrBackground) {
            DDLogVerbose(@"%@ desiredUIState: screen protection 1.", self.logTag);
            return ScreenLockUIStateScreenProtection;
        } else {
            DDLogVerbose(@"%@ desiredUIState: screen lock 2.", self.logTag);
            return ScreenLockUIStateScreenLock;
        }
    }
//MARK: 需要锁屏移除
    if (self.appIsInactiveOrBackground) {
        if (self.lastState == ScreenLockUIStateOffline) {
            return ScreenLockUIStateOffline;
        }

    } else {
        return ScreenLockUIStateNone;
    }

    if (Environment.preferences.screenSecurityIsEnabled) {
        DDLogVerbose(@"%@ desiredUIState: screen protection 4.", self.logTag);
        return ScreenLockUIStateScreenProtection;
    } else {
        DDLogVerbose(@"%@ desiredUIState: none 5.", self.logTag);
        return ScreenLockUIStateNone;
    }
}

- (void)showScreenLockFailureAlertWithMessage:(NSString *)message
{
    OWSAssertIsOnMainThread();

    [OWSAlerts showAlertWithTitle:Localized(@"SCREEN_LOCK_UNLOCK_FAILED",
                                      @"Title for alert indicating that screen lock could not be unlocked.")
                          message:message
                      buttonTitle:nil
                     buttonAction:^(UIAlertAction *action) {
                         // After the alert, update the UI.
                         [self ensureUI];
                     }
               fromViewController:self.screenBlockingWindow.rootViewController];
}

// 'Screen Blocking' window obscures the app screen:
//
// * In the app switcher.
// * During 'Screen Lock' unlock process.
- (void)createScreenBlockingWindowWithRootWindow:(UIWindow *)rootWindow
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(rootWindow);

    UIWindow *window = [[OWSWindow alloc] initWithFrame:rootWindow.bounds];
    window.hidden = NO;
    window.windowLevel = UIWindowLevel_Background;
    window.opaque = YES;
    window.backgroundColor = Theme.launchScreenBackgroundColor;

    ScreenLockViewController *viewController = [ScreenLockViewController new];
    viewController.delegate = self;
    window.rootViewController = viewController;

    self.screenBlockingWindow = window;
    self.screenBlockingViewController = viewController;
}

// The "screen blocking" window has three possible states:
//
// * "Just a logo".  Used when app is launching and in app switcher.  Must match the "Launch Screen"
//    storyboard pixel-for-pixel.
// * "Screen Lock, local auth UI presented". Move the Signal logo so that it is visible.
// * "Screen Lock, local auth UI not presented". Move the Signal logo so that it is visible,
//    show "unlock" button.
- (void)updateScreenBlockingWindow:(ScreenLockUIState)desiredUIState animated:(BOOL)animated
{
    OWSAssertIsOnMainThread();

    BOOL shouldShowBlockWindow = desiredUIState != ScreenLockUIStateNone;

    [OWSWindowManager.sharedManager setIsScreenBlockActive:shouldShowBlockWindow];
    [self.screenBlockingViewController updateUIWithState:desiredUIState
                                             isLogoAtTop:self.isShowingScreenLockUI
                                                animated:animated];
}

#pragma mark - Events

- (void)screenLockDidChange:(NSNotification *)notification
{
    [self ensureUI];
}

- (void)screenLockPatternDidChange:(NSNotification *)notification
{
    [self ensureUI];
}

- (void)clearAuthUIWhenActive
{
    // For continuity, continue to present blocking screen in "screen lock" mode while
    // dismissing the "local auth UI".
    if (self.appIsInactiveOrBackground) {
        self.shouldClearAuthUIWhenActive = YES;
    } else {
        self.isShowingScreenLockUI = NO;
        [self ensureUI];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.shouldClearAuthUIWhenActive) {
        self.shouldClearAuthUIWhenActive = NO;
        self.isShowingScreenLockUI = NO;
    }

    self.appIsInactiveOrBackground = NO;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    self.appIsInactiveOrBackground = YES;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    self.appIsInBackground = NO;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    self.appIsInBackground = YES;
}

// Whenever the device date/time is edited by the user,
- (void)clockDidChange:(NSNotification *)notification
{
    OWSLogInfo(@"%@ clock did change", self.logTag);

    if (!AppReadiness.isAppReady) {
        // It's not safe to access ScreenLock.isScreenLockEnabled
        // until the app is ready.
        //
        // We don't need to try to lock the screen lock;
        // It will be initialized by `setupWithRootWindow`.
        DDLogVerbose(@"%@ clockDidChange 0", self.logTag);
        return;
    }
    
    // 只有当有活跃的倒计时且应用不在后台时才检查是否需要锁定
    // 修复：防止在后台时调用 tryToActivateScreenLockBasedOnCountdown 导致断言失败
    if (self.screenLockCountdownDate && !self.appIsInBackground) {
        [self tryToActivateScreenLockBasedOnCountdown];
    }

    // NOTE: this notifications fires _before_ applicationDidBecomeActive,
    // which is desirable.  Don't assume that though; call ensureUI
    // just in case it's necessary.
    [self ensureUI];
}

- (BOOL)hasActiveMeeting {
    BOOL haveMeeting = [DTMeetingManager shared].inMeeting;
    BOOL isCallKitActive = DTCallKitManager.shared.callsCount > 0;
    
    return haveMeeting || isCallKitActive;
}

- (BOOL)isInAnyMeetingState {
    return [DTMeetingManager shared].hasMeeting || DTCallKitManager.shared.callsCount > 0;
}

- (void)socketStateDidChange
{
//MARK: 需要锁屏删掉
    self.socketLockState = ScreenLockUIStateNone;
    [self ensureUI];
    return;
    
    if (!self.reachability.isReachable) {
        self.socketLockState = ScreenLockUIStateOffline;
        [self ensureUI];
        if (self.offlineTimer) {
            [self.offlineTimer invalidate];
            self.offlineTimer = nil;
        }
        return;
    }
    
    if (![[TSAccountManager sharedInstance] isRegistered]) {
        
        self.socketLockState = ScreenLockUIStateOffline;
        [self ensureUI];
        if (self.offlineTimer) {
            [self.offlineTimer invalidate];
            self.offlineTimer = nil;
        }
        return;
    }
    
    OWSWebSocketState socketState = self.socketManager.socketState;
    
    if (socketState != OWSWebSocketStateConnecting) {
        
        if (socketState == OWSWebSocketStateClosed) {
            
            if (self.offlineTimer != nil) return;
            __block NSInteger seconds = 0;
            self.offlineTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                OWSLogInfo(@"%ld", seconds);
                if (CurrentAppContext().reportedApplicationState != UIApplicationStateActive) {

                    if (self.offlineTimer) {
                        [self.offlineTimer invalidate];
                        self.offlineTimer = nil;
                    }
                    return;
                }

                if (seconds >= 10) {
                    if (self.socketManager.socketState == OWSWebSocketStateClosed) {
                        self.socketLockState = ScreenLockUIStateOffline;
                    } else {
                        self.socketLockState = ScreenLockUIStateNone;
                    }
                    [self ensureUI];
                    [self.offlineTimer invalidate];
                    self.offlineTimer = nil;
                }
                seconds ++;
            }];
            [[NSRunLoop currentRunLoop] addTimer:self.offlineTimer forMode:NSRunLoopCommonModes];
            [self.offlineTimer fire];
        } else {
            
            if (self.offlineTimer) {
                [self.offlineTimer invalidate];
                self.offlineTimer = nil;
            }
            self.socketLockState = ScreenLockUIStateNone;
            [self ensureUI];
        }
    }
}

#pragma mark - ScreenLockViewDelegate

- (void)unlockButtonWasTapped
{
    OWSAssertIsOnMainThread();

    if (self.appIsInactiveOrBackground) {
        // This button can be pressed while the app is inactive
        // for a brief window while the iOS auth UI is dismissing.
        return;
    }

    OWSLogInfo(@"%@ unlockButtonWasTapped", self.logTag);

    self.didLastUnlockAttemptFail = NO;

    [self ensureUI];
}

@end

NS_ASSUME_NONNULL_END
