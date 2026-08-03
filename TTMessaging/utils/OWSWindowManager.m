//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSWindowManager.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <SignalCoreKit/NSDate+OWS.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSWindowManagerCallDidChangeNotification = @"OWSWindowManagerCallDidChangeNotification";

const CGFloat OWSWindowManagerCallBannerHeight(void)
{
    if ([UIDevice currentDevice].hasIPhoneXNotch) {
        // On an iPhoneX, the system return-to-call banner has been replaced by a much subtler green
        // circle behind the system clock. Instead, we mimic the old system call banner as on older devices,
        // but it has to be taller to fit beneath the notch.
        // IOS_DEVICE_CONSTANT, we'll want to revisit this when new device dimensions are introduced.
        return 64;
    } else {

        return CurrentAppContext().statusBarHeight + 20;
    }
}

// Behind everything, especially the root window.
const UIWindowLevel UIWindowLevel_Background = -1.f;

//const UIWindowLevel UIWindowLevel_ReturnToCall(void);
//const UIWindowLevel UIWindowLevel_ReturnToCall(void)
//{
//    return UIWindowLevelStatusBar - 1;
//}

// In front of the root window and the foreground passcode "screen lock" window,
// but behind the background "screen protection" cover. Placing the call view above
// the passcode lock keeps an active call from being obscured by the unlock screen.
const UIWindowLevel UIWindowLevel_CallView(void);
const UIWindowLevel UIWindowLevel_CallView(void)
{
    return UIWindowLevelStatusBar + 3.f;
}

// In front of the status bar and CallView
const UIWindowLevel UIWindowLevel_AlertCallView(void);
const UIWindowLevel UIWindowLevel_AlertCallView(void)
{
    return UIWindowLevelStatusBar - 1.f;
}

// Foreground passcode "screen lock" page. Sits above the root window but BELOW the
// call view, so an in-progress call floats above the unlock screen.
const UIWindowLevel UIWindowLevel_ScreenBlocking(void);
const UIWindowLevel UIWindowLevel_ScreenBlocking(void)
{
    return UIWindowLevelStatusBar + 2.f;
}

// Background / app-switcher privacy cover. Sits ABOVE the call view so an active
// call cannot leak into the app-switcher snapshot when the app is backgrounded.
const UIWindowLevel UIWindowLevel_ScreenProtection(void);
const UIWindowLevel UIWindowLevel_ScreenProtection(void)
{
    return UIWindowLevelStatusBar + 4.f;
}

@implementation OWSWindowRootViewController

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

@end

#pragma mark -

@interface OWSWindowManager () <ReturnToCallViewControllerDelegate>

// UIWindowLevelNormal
@property (nonatomic) UIWindow *rootWindow;

// UIWindowLevel_ReturnToCall
@property (nonatomic) UIWindow *returnToCallWindow;
@property (nonatomic) ReturnToCallViewController *returnToCallViewController;

// UIWindowLevel_CallView
@property (nonatomic) UIWindow *callViewWindow;
@property (nonatomic) UINavigationController *callNavigationController;

// UIWindowLevel_Background if inactive,
// UIWindowLevel_ScreenBlocking() if active.
@property (nonatomic) UIWindow *screenBlockingWindow;

@property (nonatomic) BOOL isScreenBlockActive;
// YES when the active screen block is the foreground passcode "screen lock" page
// (the call view floats above it); NO when it is the background privacy cover
// (the cover sits above the call view).
@property (nonatomic) BOOL screenBlockIsForegroundLock;
@property (nonatomic) BOOL haveMutilCall;

@property (nonatomic) BOOL shouldShowCallView;
@property (nonatomic) BOOL isLandscape;

@property (nonatomic) BOOL isPhotoLibraryAuth;

@property (nonatomic, nullable) UIViewController *callViewController;

@end

#pragma mark -

@implementation OWSWindowManager

+ (instancetype)sharedManager
{
    static OWSWindowManager *instance = nil;
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

- (void)setupWithRootWindow:(UIWindow *)rootWindow screenBlockingWindow:(UIWindow *)screenBlockingWindow
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(rootWindow);
    OWSAssertDebug(!self.rootWindow);
    OWSAssertDebug(screenBlockingWindow);
    OWSAssertDebug(!self.screenBlockingWindow);

    self.rootWindow = rootWindow;
    self.screenBlockingWindow = screenBlockingWindow;
    
    self.callViewWindow = [self createCallViewWindow:rootWindow];
    self.callViewWindow.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    
    [self ensureWindowState];
}

- (UIWindow *)createCallViewWindow:(UIWindow *)rootWindow
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(rootWindow);

    UIWindow *window = [[OWSWindow alloc] initWithFrame:rootWindow.bounds];
    window.hidden = YES;
    window.windowLevel = UIWindowLevel_CallView();
    window.opaque = YES;
    window.backgroundColor = Theme.bg1Color;

    UIViewController *viewController = [OWSWindowRootViewController new];
    viewController.view.backgroundColor = [UIColor blackColor];

    // NOTE: Do not use OWSNavigationController for call window.
    // It adjusts the size of the navigation bar to reflect the
    // call window.  We don't want those adjustments made within
    // the call window itself.
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:viewController];
    OWSAssertDebug(!self.callNavigationController);
    navigationController.navigationBarHidden = YES;
    self.callNavigationController = navigationController;

    window.rootViewController = navigationController;

    return window;
}

- (void)setIsScreenBlockActive:(BOOL)isScreenBlockActive isForegroundLock:(BOOL)isForegroundLock
{
    OWSAssertIsOnMainThread();

    _isScreenBlockActive = isScreenBlockActive;
    _screenBlockIsForegroundLock = isForegroundLock;

    [self ensureWindowState];
}

- (void)setIsPhotoLibraryAuth:(BOOL)isPhotoLibraryAuth
{
    OWSAssertIsOnMainThread();

    _isPhotoLibraryAuth = isPhotoLibraryAuth;

    // When photo library auth state changes, ensure window state is updated
    // This is important when transitioning back from photo library (isPhotoLibraryAuth=NO)
    // to ensure any pending window state changes are processed
    [self ensureWindowState];
}

#pragma mark - Calls

- (void)setCallViewController:(nullable UIViewController *)callViewController
{
    OWSAssertIsOnMainThread();

    if (callViewController == _callViewController) {
        return;
    }

    _callViewController = callViewController;
}

- (void)startCall:(UIViewController *)callViewController animated:(BOOL)animated
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(callViewController);
//    OWSAssertDebug(!self.callViewController);
    
    OWSLogInfo(@"[Time-consuming] show call vc time %llu.", (uint64_t)[NSDate ows_millisecondTimeStamp]);

    self.callViewController = callViewController;

    // Attach callViewController to window.
//    if (self.callNavigationController.viewControllers.count > 1) {
//        [self.callNavigationController popToRootViewControllerAnimated:NO];
//    }
//    [self.callNavigationController pushViewController:callViewController animated:NO];
    self.callNavigationController.viewControllers = @[callViewController];
    self.shouldShowCallView = YES;

    if (animated)  {
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.callViewWindow.frame = CGRectOffset(screenBounds, 0, -screenBounds.size.height);

        [UIView animateWithDuration:0.4
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.callViewWindow.frame = screenBounds;
        } completion:^(BOOL finished) {
            [self ensureWindowState];
        }];
    } else {
        [self ensureWindowState];
    }
}

- (void)setShouldShowCallView:(BOOL)shouldShowCallView {
    _shouldShowCallView = shouldShowCallView;
    
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:OWSWindowManagerCallDidChangeNotification object:nil userInfo:@{@"isCallWindowHidden" : @(!shouldShowCallView)}];
}

- (void)endCall:(nullable UIViewController *)callViewController
     completion:(void(^)(void))completion;
{
    OWSAssertIsOnMainThread();
//    OWSAssertDebug(callViewController);
//    OWSAssertDebug(self.callViewController);

    if (![self hasCall]) {
        OWSLogError(@"[call] has ended early!");
        if (completion) {
            completion();
        }
        return;
    }

    UIViewController *presentedVC = self.callNavigationController.presentedViewController;
    if (presentedVC) {
        OWSLogInfo(@"[Window] endCall completed, dismiss presentedVC");
        [presentedVC dismissViewControllerAnimated:NO completion:nil];
    }
    UIViewController *viewController = [OWSWindowRootViewController new];
    viewController.view.backgroundColor = [UIColor blackColor];
    self.callNavigationController.viewControllers = @[viewController];

    self.callViewController = nil;

    self.shouldShowCallView = NO;

    [self ensureWindowState];

    OWSLogInfo(@"[Window] endCall completed, rootWindow.hidden=%d, isKeyWindow=%d",
               self.rootWindow.hidden, self.rootWindow.isKeyWindow);
    if (completion) {
        completion();
    }
}

- (void)leaveCallView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.callViewController);
    OWSAssertDebug(self.shouldShowCallView);

    self.shouldShowCallView = NO;

    [self ensureWindowState];
}

- (void)showFloatingCallView:(UIView *)floatingView {
    [self.rootWindow addSubview:floatingView];
    NSValue *tmpLastOrigion = [floatingView valueForKey:@"lastOrigion"];
    
    if (!tmpLastOrigion) return;
    CGPoint lastOrigion = [tmpLastOrigion CGPointValue];

    NSArray <NSLayoutConstraint *> *origionConstraints = [floatingView valueForKey:@"origionConstraints"];
    if (origionConstraints != nil) {
        [NSLayoutConstraint deactivateConstraints:origionConstraints];
    }
    origionConstraints = @[[floatingView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:lastOrigion.x],
                           [floatingView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:lastOrigion.y]];
    [floatingView setValue:origionConstraints forKey:@"origionConstraints"];
}

- (void)showCallView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.callViewController);
    OWSAssertDebug(!self.shouldShowCallView);

    self.shouldShowCallView = YES;
    [self ensureWindowState];
}

- (BOOL)hasCall
{
    OWSAssertIsOnMainThread();
    return self.callViewController != nil;
}

- (BOOL)isCallViewFrontmostAboveScreenLock
{
    // Mirrors the ensureWindowState branch that floats the call view above the foreground
    // passcode lock (see -ensureWindowState). Only true for the foreground lock, never for
    // the background privacy cover (which is placed above the call view to hide it).
    return self.isScreenBlockActive
        && self.screenBlockIsForegroundLock
        && self.callViewController != nil
        && self.shouldShowCallView;
}

- (UIWindow *)getToastSuitableWindow {
    if (!self.callViewWindow.isHidden) {
        return self.callViewWindow;
    } else {
        return self.rootWindow;
    }
}

#pragma mark - Window State

- (void)ensureWindowState
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.rootWindow);
    OWSAssertDebug(self.callViewWindow);
    OWSAssertDebug(self.screenBlockingWindow);

    // To avoid bad frames, we never want to hide the blocking window, so we manipulate
    // its window level to "hide" it behind other windows.  The other windows have fixed
    // window level and are shown/hidden as necessary.
    //
    // Note that we always "hide" before we "show".

    OWSLogInfo(@"[Window] ensureWindowState: isScreenBlockActive=%d, callViewController=%@, shouldShowCallView=%d, isPhotoLibraryAuth=%d",
               self.isScreenBlockActive, self.callViewController, self.shouldShowCallView, self.isPhotoLibraryAuth);

    if (self.isPhotoLibraryAuth) {
        // Reset defer counter when skipping due to photo library auth
        // to prevent accumulation across multiple calls
        return;
    }

    if (self.isScreenBlockActive) {
        // Show Screen Block.
        OWSLogInfo(@"[Window] show screen windows");
        [self ensureScreenBlockWindowShown];
        [self ensureRootWindowHidden];
        if (self.callViewController && self.shouldShowCallView) {
            if (self.screenBlockIsForegroundLock) {
                // Foreground passcode lock: float the call view ABOVE the lock screen
                // (higher window level) so the active call is not obscured. Shown last
                // so the call window becomes key and stays interactive on top.
                OWSLogInfo(@"[Window] keeping call window ABOVE foreground screen lock");
                [self ensureCallViewWindowShown];
            } else {
                // Background privacy cover: keep the call window visible but BEHIND the
                // cover (cover has a higher level) so the call can't leak into the
                // app-switcher snapshot.
                OWSLogInfo(@"[Window] keeping call window behind screen protection cover");
            }
        } else {
            [self ensureCallViewWindowHidden];
        }
    } else if (self.callViewController && self.shouldShowCallView) {
        // Show Call View.
        OWSLogInfo(@"[Window] show call windows");
        [self ensureCallViewWindowShown];
        [self ensureRootWindowHidden];
        [self ensureScreenBlockWindowHidden];
    } else if (self.callViewController) {
        // Show Root Window
        OWSLogInfo(@"[Window] show Root windows call controller");
        [self ensureRootWindowShown];
        [self ensureCallViewWindowHidden];
        [self ensureScreenBlockWindowHidden];
    } else {
        // Show Root Window
        OWSLogInfo(@"[Window] show Root windows default");
        [self ensureRootWindowShown];
        [self ensureCallViewWindowHidden];
        [self ensureScreenBlockWindowHidden];
    }
    
    UIWindow *frontWindow;
    if (self.isScreenBlockActive && self.screenBlockIsForegroundLock
        && self.callViewController && self.shouldShowCallView) {
        // Call view floats above the foreground passcode lock.
        frontWindow = self.callViewWindow;
    } else if (self.isScreenBlockActive) {
        frontWindow = self.screenBlockingWindow;
    } else if (self.callViewController && self.shouldShowCallView) {
        frontWindow = self.callViewWindow;
    } else {
        frontWindow = self.rootWindow;
    }
    [frontWindow.rootViewController setNeedsStatusBarAppearanceUpdate];
    if (@available(iOS 16, *)) {
        [frontWindow.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
    }
}

- (void)ensureRootWindowShown
{
    OWSAssertIsOnMainThread();

    if (self.rootWindow.hidden) {
        OWSLogInfo(@"%@ showing root window.", self.logTag);
    }

    // By calling makeKeyAndVisible we ensure the rootViewController becomes firt responder.
    // In the normal case, that means the SignalViewController will call `becomeFirstResponder`
    // on the vc on top of its navigation stack.
    
    if (!self.rootWindow.isKeyWindow || self.rootWindow.hidden) {
        OWSLogInfo(@"%@ showing root window. makeKeyAndVisible", self.logTag);
        [self.rootWindow makeKeyAndVisible];
    }
}

- (void)ensureRootWindowHidden
{
    OWSAssertIsOnMainThread();

    if (!self.rootWindow.hidden) {
        OWSLogInfo(@"%@ hiding root window.", self.logTag);
    }

    self.rootWindow.hidden = YES;
}

- (void)ensureReturnToCallWindowShown
{
    OWSAssertIsOnMainThread();

    if (!self.returnToCallWindow.hidden) {
        return;
    }

    OWSLogInfo(@"%@ showing 'return to call' window.", self.logTag);
    self.returnToCallWindow.hidden = NO;
    [self.returnToCallViewController startAnimating];
}

- (void)ensureReturnToCallWindowHidden
{
    OWSAssertIsOnMainThread();

    if (self.returnToCallWindow.hidden) {
        return;
    }

    OWSLogInfo(@"%@ hiding 'return to call' window.", self.logTag);
    self.returnToCallWindow.hidden = YES;
    [self.returnToCallViewController stopAnimating];
}

- (void)ensureCallViewWindowShown
{
    OWSAssertIsOnMainThread();

    if (self.callViewWindow.hidden) {
        OWSLogInfo(@"%@ showing call window.", self.logTag);
    }

    [self.callViewWindow makeKeyAndVisible];
    if (self.callWindowBecomeKeyWindow) {
        OWSLogDebug(@"%@ callWindowBecomeKeyWindow", self.logTag);
        self.callWindowBecomeKeyWindow();
        _callWindowBecomeKeyWindow = nil;
    }
}

- (void)ensureCallViewWindowHidden
{
    OWSAssertIsOnMainThread();

    if (!self.callViewWindow.hidden) {
        OWSLogInfo(@"%@ hiding call window.", self.logTag);
    }

    self.callViewWindow.hidden = YES;
}

- (void)ensureScreenBlockWindowShown
{
    OWSAssertIsOnMainThread();

    // Foreground passcode lock sits below the call view (UIWindowLevel_ScreenBlocking);
    // the background privacy cover sits above it (UIWindowLevel_ScreenProtection).
    UIWindowLevel targetLevel = self.screenBlockIsForegroundLock
        ? UIWindowLevel_ScreenBlocking()
        : UIWindowLevel_ScreenProtection();

    if (self.screenBlockingWindow.windowLevel != targetLevel) {
        OWSLogInfo(@"%@ showing block window.", self.logTag);
    }

    self.screenBlockingWindow.windowLevel = targetLevel;
    [self.screenBlockingWindow makeKeyAndVisible];
}

- (void)ensureScreenBlockWindowHidden
{
    OWSAssertIsOnMainThread();

    if (self.screenBlockingWindow.windowLevel != UIWindowLevel_Background) {
        OWSLogInfo(@"%@ hiding block window.", self.logTag);
    }

    // Never hide the blocking window (that can lead to bad frames).
    // Instead, manipulate its window level to move it in front of
    // or behind the root window.
    self.screenBlockingWindow.windowLevel = UIWindowLevel_Background;
}

#pragma mark - ReturnToCallViewControllerDelegate

- (void)returnToCallWasTapped:(ReturnToCallViewController *)viewController
{
    [self showCallView];
}

@end

NS_ASSUME_NONNULL_END
