//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSViewController.h"
#import "Theme.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/DTWatermarkHelper.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSViewController ()

@property (nonatomic, nullable, weak) UIView *bottomLayoutView;
@property (nonatomic, nullable) NSLayoutConstraint *bottomLayoutConstraint;
@property (nonatomic) BOOL shouldAnimateBottomLayout;
@property (nonatomic) BOOL hasObservedNotifications;
@property (nonatomic) CGFloat lastBottomLayoutInset;
@property (nonatomic, strong) UILabel *lbLeftTitle;

@end

#pragma mark -

@implementation OWSViewController

- (void)dealloc
{
    // Surface memory leaks by logging the deallocation of view controllers.
    OWSLogInfo(@"Dealloc: %@", self.class);

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        self.shouldUseTheme = YES;
        return self;
    }

    [self observeActivation];

    return self;
}

#pragma mark - View Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.tabBarController) {
        [DTWatermarkHelper addWatermarkToTheView:self.tabBarController.view];
    }else {
        [DTWatermarkHelper addWatermarkToTheView:self.view];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userTakeScreenshotEvent:)
                                                 name:UIApplicationUserDidTakeScreenshotNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(languageDidChange:)
                                                 name:LCLLanguageChangeNotification
                                               object:nil];

}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationUserDidTakeScreenshotNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    self.shouldAnimateBottomLayout = YES;
#ifdef DEBUG
    [self ensureNavbarAccessibilityIds];
#endif
    
}
- (void)userTakeScreenshotEvent:(NSNotification *)notify {
    UIImage *image = [self snapshotImage];
    if(!image){
        OWSLogError(@"userTakeScreenshotEvent: image = nil");
        return;
    }
    NSData *imgData = UIImageJPEGRepresentation(image, 1.0f);
    NSString *encodedImageStr = [imgData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    OWSLogInfo(@"userTakeScreenshotEvent: %@ %@", [self class], [NSDate date]);
    [DTMTAManager screenShotEventWithPicture:encodedImageStr page:NSStringFromClass([self class]) details:nil];
}

#ifdef DEBUG
- (void)ensureNavbarAccessibilityIds
{
    UINavigationBar *_Nullable navigationBar = self.navigationController.navigationBar;
    if (!navigationBar) {
        return;
    }
    // There isn't a great way to assign accessibilityIdentifiers to default
    // navbar buttons, e.g. the back button.  As a (DEBUG-only) hack, we
    // assign accessibilityIds to any navbar controls which don't already have
    // one.  This should offer a reliable way for automated scripts to find
    // these controls.
    //
    // UINavigationBar often discards and rebuilds new contents, e.g. between
    // presentations of the view, so we need to do this every time the view
    // appears.  We don't do any checking for accessibilityIdentifier collisions
    // so we're counting on the fact that navbar contents are short-lived.
    __block int accessibilityIdCounter = 0;
    [navigationBar traverseViewHierarchyDownwardWithVisitor:^(UIView *view) {
        if ([view isKindOfClass:[UIControl class]] && view.accessibilityIdentifier == nil) {
            // The view should probably be an instance of _UIButtonBarButton or _UIModernBarButton.
            view.accessibilityIdentifier = [NSString stringWithFormat:@"navbar-%d", accessibilityIdCounter];
            accessibilityIdCounter++;
        }
    }];
}
#endif

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    self.shouldAnimateBottomLayout = NO;
    
    if (self.tabBarController) {
        
    } else {
        [DTWatermarkHelper removeWatermarkFromView:self.view];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.backButtonTitle = Localized(@"BACK_BUTTON", @"");

    if (self.shouldUseTheme) {
        self.view.backgroundColor = Theme.backgroundColor;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:ThemeDidChangeNotification
                                               object:nil];
}

#pragma mark -

- (NSLayoutConstraint *)autoPinViewToBottomOfViewControllerOrKeyboard:(UIView *)view avoidNotch:(BOOL)avoidNotch
{
    OWSAssertDebug(view);
    OWSAssertDebug(!self.bottomLayoutConstraint);

    [self observeNotificationsForBottomView];

    self.bottomLayoutView = view;
    if (avoidNotch) {
        self.bottomLayoutConstraint = [view autoPinEdgeToSuperviewSafeArea:ALEdgeBottom withInset:self.lastBottomLayoutInset];

    } else {
        self.bottomLayoutConstraint = [view autoPinEdge:ALEdgeBottom
                                                 toEdge:ALEdgeBottom
                                                 ofView:self.view
                                             withOffset:self.lastBottomLayoutInset];
    }
    return self.bottomLayoutConstraint;
}

- (void)observeNotificationsForBottomView
{
    OWSAssertIsOnMainThread();

    if (self.hasObservedNotifications) {
        return;
    }
    self.hasObservedNotifications = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidChangeFrame:)
                                                 name:UIKeyboardDidChangeFrameNotification
                                               object:nil];
}

- (void)removeBottomLayout
{
    [self.bottomLayoutConstraint autoRemove];
    self.bottomLayoutView = nil;
    self.bottomLayoutConstraint = nil;
}

- (void)observeActivation
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(owsViewControllerApplicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)owsViewControllerApplicationDidBecomeActive:(NSNotification *)notification
{
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)themeDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *windowLevel = userInfo[@"windowLevel"];
    if (userInfo != nil && windowLevel.floatValue != 0.0) return;

    [self applyTheme];
}

- (void)languageDidChange:(NSNotification *)notification {
    [self applyLanguage];
}

- (void)applyTheme
{
    OWSAssertIsOnMainThread();

    self.view.backgroundColor = Theme.backgroundColor;
    
    if (self.leftTitle) {
        self.lbLeftTitle.textColor = Theme.primaryTextColor;
    }
    // Do nothing; this is a convenience hook for subclasses.
}

- (void)applyLanguage
{
    OWSAssertIsOnMainThread();
    self.navigationItem.backButtonTitle = Localized(@"BACK_BUTTON", @"");;
    // Do nothing; this is a convenience hook for subclasses.
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

- (void)keyboardDidHide:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

- (void)keyboardDidChangeFrame:(NSNotification *)notification
{
    [self handleKeyboardNotificationBase:notification];
}

// We use the name `handleKeyboardNotificationBase` instead of
// `handleKeyboardNotification` to avoid accidentally
// calling similarly methods with that name in subclasses,
// e.g. ConversationViewController.
- (void)handleKeyboardNotificationBase:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    if (self.shouldIgnoreKeyboardChanges) {
        return;
    }

    NSDictionary *userInfo = [notification userInfo];

    NSValue *_Nullable keyboardEndFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey];
    if (!keyboardEndFrameValue) {
        OWSFailDebug(@"Missing keyboard end frame");
        return;
    }

    CGRect keyboardEndFrame = [keyboardEndFrameValue CGRectValue];
    if (CGRectEqualToRect(keyboardEndFrame, CGRectZero)) {
        // If reduce motion+crossfade transitions is on, in iOS 14 UIKit vends out a keyboard end frame
        // of CGRect zero. This breaks the math below.
        //
        // If our keyboard end frame is CGRectZero, build a fake rect that's translated off the bottom edge.
        CGRect deviceBounds = UIScreen.mainScreen.bounds;
        keyboardEndFrame = CGRectOffset(deviceBounds, 0, deviceBounds.size.height);
    }

    CGRect keyboardEndFrameConverted = [self.view convertRect:keyboardEndFrame fromView:nil];
    // Adjust the position of the bottom view to account for the keyboard's
    // intrusion into the view.
    //
    // On iPhoneX, when no keyboard is present, we include a buffer at the bottom of the screen so the bottom view
    // clears the floating "home button". But because the keyboard includes it's own buffer, we subtract the length
    // (height) of the bottomLayoutGuide, else we'd have an unnecessary buffer between the popped keyboard and the input
    // bar.
    CGFloat newInset = MAX(0, (self.view.height - self.bottomLayoutGuide.length - keyboardEndFrameConverted.origin.y));
    self.lastBottomLayoutInset = newInset;

    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    // Should we ignore keyboard changes if they're coming from somewhere out-of-process?
    // BOOL isOurKeyboard = [notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];

    dispatch_block_t updateLayout = ^{
        if (self.shouldBottomViewReserveSpaceForKeyboard && newInset <= 0) {
            // To avoid unnecessary animations / layout jitter,
            // some views never reclaim layout space when the keyboard is dismissed.
            //
            // They _do_ need to relayout if the user switches keyboards.
            return;
        }
        [self updateBottomLayoutConstraintFromInset:-self.bottomLayoutConstraint.constant toInset:newInset];
    };


    if (self.shouldAnimateBottomLayout && duration > 0 && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView beginAnimations:@"keyboardStateChange" context:NULL];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationCurve:curve];
        [UIView setAnimationDuration:duration];
        updateLayout();
        [UIView commitAnimations];
    } else {
        // UIKit by default (sometimes? never?) animates all changes in response to keyboard events.
        // We want to suppress those animations if the view isn't visible,
        // otherwise presentation animations don't work properly.
        [UIView performWithoutAnimation:updateLayout];
    }
}

- (void)updateBottomLayoutConstraintFromInset:(CGFloat)before toInset:(CGFloat)after
{
    self.bottomLayoutConstraint.constant = -after;
    [self.bottomLayoutView.superview layoutIfNeeded];
}

- (BOOL)hidesBottomBarWhenPushed
{
    return self.navigationController.viewControllers.firstObject != self;
}

- (void)showAlertStyle:(UIAlertControllerStyle)alertStyle
                 title:(NSString *_Nullable)title
                   msg:(NSString *_Nullable)msg
           cancelTitle:(NSString * _Nullable)cancelTitle
          confirmTitle:(NSString *)confirmTitle
          confirmStyle:(UIAlertActionStyle)confirmStyle
        confirmHandler:(void (^ _Nullable)(void))confirmHandler {
    
    [self showAlertStyle:alertStyle
                   title:title
                     msg:msg
             cancelTitle:cancelTitle
            confirmTitle:confirmTitle
            confirmStyle:confirmStyle
          confirmHandler:confirmHandler
           cancelHandler:nil];
}

- (void)showAlertStyle:(UIAlertControllerStyle)alertStyle
                 title:(NSString *_Nullable)title
                   msg:(NSString *_Nullable)msg
           cancelTitle:(NSString * _Nullable)cancelTitle
          confirmTitle:(NSString *)confirmTitle
          confirmStyle:(UIAlertActionStyle)confirmStyle
        confirmHandler:(void (^ _Nullable)(void))confirmHandler
         cancelHandler:(void (^ _Nullable)(void))cancelHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:alertStyle];
    if (alertStyle == UIAlertControllerStyleAlert && DTParamsUtils.validateString(msg)) {
        NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:msg attributes:@{NSFontAttributeName : [UIFont ows_dynamicTypeBody2Font]}];
        [alert setValue:attributedMessage forKey:@"attributedMessage"];
    }
    
    if (cancelTitle && cancelTitle.length > 0) {
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (cancelHandler) cancelHandler();
        }];
        
        if ([self isKindOfClass:NSClassFromString(@"DTMultiCallViewController")]) {
            [cancelAction setValue:UIColor.ows_alertCancelDarkColor forKey:@"_titleTextColor"];
        } else {
            [cancelAction setValue:Theme.alertCancelColor forKey:@"_titleTextColor"];
        }
        
        [alert addAction:cancelAction];
    }
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmTitle style:confirmStyle handler:^(UIAlertAction * _Nonnull action) {
        if (confirmHandler) confirmHandler();
    }];
    if ([self isKindOfClass:NSClassFromString(@"DTMultiCallViewController")]) {
        [confirmAction setValue:UIColor.ows_alertConfirmDarkBlueColor forKey:@"_titleTextColor"];
    } else {
        [confirmAction setValue:Theme.alertConfirmColor forKey:@"_titleTextColor"];
    }
    
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)shouldAutorotate {
    
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return NO;
}

- (void)setLeftTitle:(NSString *)leftTitle {
    _leftTitle = leftTitle;
    self.lbLeftTitle.text = leftTitle;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.lbLeftTitle];
}

- (UILabel *)lbLeftTitle {
    if (!_lbLeftTitle) {
        _lbLeftTitle = [UILabel new];
        _lbLeftTitle.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
        _lbLeftTitle.textColor = Theme.primaryTextColor;
    }
    return _lbLeftTitle;
}

- (BOOL)isUserDeregistered {
    if (TSAccountManager.sharedInstance.isDeregistered) {
        [self showAlertStyle:UIAlertControllerStyleAlert
                       title:Localized(@"COMMON_NOTICE_TITLE", @"")
                         msg:Localized(@"DEREGISTRATION_WARNING", @"Label warning the user that they have been de-registered.")
                 cancelTitle:nil
                confirmTitle:Localized(@"ok", @"")
                confirmStyle:UIAlertActionStyleDefault
              confirmHandler:nil];
        
        return YES;
    }
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (!CurrentAppContext().isMainApp) {
        return super.preferredStatusBarStyle;
    } else {
        UIViewController *presentedViewController = self.presentedViewController;
        if (presentedViewController != nil && !presentedViewController.isBeingDismissed) {
            return presentedViewController.preferredStatusBarStyle;
        } else {
            return (Theme.isDarkThemeEnabled ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent);
        }
    }
}

//- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
//
//    if (self.presentedViewController != nil) {
//        if (self.presentedViewController.isBeingPresented) {
//            return self.presentedViewController.supportedInterfaceOrientations;
//        }
//        if (self.presentedViewController.isBeingDismissed) {
//            return self.supportedInterfaceOrientations_ ? (UIInterfaceOrientationMask)(self.supportedInterfaceOrientations_.unsignedIntegerValue) : UIInterfaceOrientationMaskPortrait;
//        }
//        return self.presentedViewController.supportedInterfaceOrientations;
//    }
//
//    return self.supportedInterfaceOrientations_ ? (UIInterfaceOrientationMask)(self.supportedInterfaceOrientations_.unsignedIntegerValue) : UIInterfaceOrientationMaskPortrait;
//}
//
//- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
//    if (self.presentedViewController != nil) {
//        if (self.presentedViewController.isBeingPresented) {
//            return self.presentedViewController.preferredInterfaceOrientationForPresentation;
//        }
//        if (self.presentedViewController.isBeingDismissed) {
//            return self.preferredInterfaceOrientationForPresentation_ ? (UIInterfaceOrientation)(self.preferredInterfaceOrientationForPresentation_.unsignedIntegerValue) : UIInterfaceOrientationPortrait;
//        }
//        return self.presentedViewController.preferredInterfaceOrientationForPresentation;
//    }
//
//    return self.preferredInterfaceOrientationForPresentation_ ? (UIInterfaceOrientation)(self.preferredInterfaceOrientationForPresentation_.unsignedIntegerValue) : UIInterfaceOrientationPortrait;
//}


@end

NS_ASSUME_NONNULL_END

