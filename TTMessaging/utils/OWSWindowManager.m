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

// In front of the root window, behind the screen blocking window.
const UIWindowLevel UIWindowLevel_CallView(void);
const UIWindowLevel UIWindowLevel_CallView(void)
{
    return UIWindowLevelNormal + 1.f;
}

// In front of the status bar and CallView
const UIWindowLevel UIWindowLevel_AlertCallView(void);
const UIWindowLevel UIWindowLevel_AlertCallView(void)
{
    return UIWindowLevelStatusBar - 1.f;
}

// In front of the status bar, alertCallView and CallView
const UIWindowLevel UIWindowLevel_ScreenBlocking(void);
const UIWindowLevel UIWindowLevel_ScreenBlocking(void)
{
    return UIWindowLevelStatusBar + 2.f;
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

// UIWindowLevel_AlertCallView
//@property (nonatomic) UIWindow *alertCallViewWindow;
//@property (nonatomic) UINavigationController *alertCallNavigationController;
//@property (nonatomic, nullable) UIViewController *alertCallViewController;

// UIWindowLevel_MessageActions
//@property (nonatomic) UIWindow *menuActionsWindow;
//@property (nonatomic, nullable) UIViewController *menuActionsViewController;

// UIWindowLevel_Background if inactive,
// UIWindowLevel_ScreenBlocking() if active.
@property (nonatomic) UIWindow *screenBlockingWindow;

@property (nonatomic) BOOL isScreenBlockActive;
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
    window.backgroundColor = Theme.backgroundColor;

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

- (void)setIsScreenBlockActive:(BOOL)isScreenBlockActive
{
    OWSAssertIsOnMainThread();

    _isScreenBlockActive = isScreenBlockActive;

    [self ensureWindowState];
}

#pragma mark - Message Actions

//- (BOOL)isPresentingMenuActions
//{
//    return self.menuActionsViewController != nil;
//}

//- (void)showMenuActionsWindow:(UIViewController *)menuActionsViewController
//{
//    OWSAssertDebug(self.menuActionsViewController == nil);

//    self.menuActionsViewController = menuActionsViewController;
//    self.menuActionsWindow.rootViewController = menuActionsViewController;
//
//    [self ensureWindowState];
//}

//- (void)hideMenuActionsWindow
//{
//    if (self.menuActionsWindow.rootViewController || self.menuActionsViewController) {
//        
//        self.menuActionsWindow.rootViewController = nil;
//        self.menuActionsViewController = nil;
//        
//        [self ensureWindowState];
//    }
//}

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

    [self ensureWindowState];
    
    if (!animated) {
        [self ensureRootWindowHidden];
    } else {
        [self ensureRootWindowShown];
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.callViewWindow.frame = CGRectOffset(screenBounds, 0, -screenBounds.size.height);

        [UIView animateWithDuration:0.4
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.callViewWindow.frame = screenBounds;
        } completion:^(BOOL finished) {
            if (self.shouldShowCallView) {
                [self ensureRootWindowHidden];
            }
        }];
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
        
        OWSLogWarn(@"[call] has ended early!");
        return;
    }

//    if (self.callViewController != callViewController) {
//        OWSLogWarn(@"[call] %@ Ignoring end call request from obsolete call view controller.", self.logTag);
//        return;
//    }

    // Dettach callViewController from window.
//    [self.callNavigationController popToRootViewControllerAnimated:NO];
    
    UIViewController *presentedVC = self.callNavigationController.presentedViewController;
    if (presentedVC) {
        [presentedVC dismissViewControllerAnimated:NO completion:nil];
    }
    UIViewController *viewController = [OWSWindowRootViewController new];
    viewController.view.backgroundColor = [UIColor blackColor];
    self.callNavigationController.viewControllers = @[viewController];
    
    self.callViewController = nil;

    self.shouldShowCallView = NO;

    [self ensureWindowState];
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
//    OWSAssertDebug(self.returnToCallWindow);
    OWSAssertDebug(self.callViewWindow);
    OWSAssertDebug(self.screenBlockingWindow);

    // To avoid bad frames, we never want to hide the blocking window, so we manipulate
    // its window level to "hide" it behind other windows.  The other windows have fixed
    // window level and are shown/hidden as necessary.
    //
    // Note that we always "hide" before we "show".
    
    if (self.isPhotoLibraryAuth) {
        return;
    }
    
    if (self.isScreenBlockActive) {
        // Show Screen Block.

        [self ensureScreenBlockWindowShown];
        [self ensureRootWindowHidden];
        [self ensureCallViewWindowHidden];
//        [self ensureMessageActionsWindowHidden];
    } else if (self.callViewController && self.shouldShowCallView) {
        // Show Call View.

        [self ensureCallViewWindowShown];
        [self ensureRootWindowHidden];
//        [self ensureMessageActionsWindowHidden];
        [self ensureScreenBlockWindowHidden];
    } else if (self.callViewController) {
        // Show Root Window

        [self ensureRootWindowShown];
        [self ensureCallViewWindowHidden];
        [self ensureScreenBlockWindowHidden];
        
    } else {
        // Show Root Window

        [self ensureRootWindowShown];
        [self ensureCallViewWindowHidden];
//        [self ensureMessageActionsWindowHidden];
        [self ensureScreenBlockWindowHidden];
    }
    
    if (@available(iOS 16, *)) {
        [self.rootWindow.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
        [self.callViewWindow.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
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

/*
- (void)ensureAlertCallViewWindowShown
{
    OWSAssertIsOnMainThread();

    if (self.alertCallViewWindow.hidden) {
        OWSLogInfo(@"%@ showing alert call view window.", self.logTag);
    }

    self.alertCallViewWindow.hidden = NO;
}

- (void)ensureAlertCallViewWindowHidden
{
    OWSAssertIsOnMainThread();

    if (!self.alertCallViewWindow.hidden) {
        OWSLogInfo(@"%@ hiding call window.", self.logTag);
    }

    self.alertCallViewWindow.hidden = YES;
}
 */

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

//- (void)ensureMessageActionsWindowShown
//{
//    OWSAssertIsOnMainThread();
//
//    if (self.menuActionsWindow.hidden) {
//        OWSLogInfo(@"%@ showing message actions window.", self.logTag);
//    }
//
//    // Do not make key, we want the keyboard to stay popped.
//    self.menuActionsWindow.hidden = NO;
//}
//
//- (void)ensureMessageActionsWindowHidden
//{
//    OWSAssertIsOnMainThread();
//
//    if (!self.menuActionsWindow.hidden) {
//        OWSLogInfo(@"%@ hiding message actions window.", self.logTag);
//    }
//
//    self.menuActionsWindow.hidden = YES;
//}

- (void)ensureScreenBlockWindowShown
{
    OWSAssertIsOnMainThread();

    if (self.screenBlockingWindow.windowLevel != UIWindowLevel_ScreenBlocking()) {
        OWSLogInfo(@"%@ showing block window.", self.logTag);
    }

    self.screenBlockingWindow.windowLevel = UIWindowLevel_ScreenBlocking();
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
