//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN


// This VC can become first responder
// when presented to ensure that the input accessory is updated.
@interface OWSWindowRootViewController : UIViewController

@end

#pragma mark -

extern NSString *const OWSWindowManagerCallDidChangeNotification;

const CGFloat OWSWindowManagerCallBannerHeight(void);
const UIWindowLevel UIWindowLevel_CallView(void);
const UIWindowLevel UIWindowLevel_AlertCallView(void);
const UIWindowLevel UIWindowLevel_ScreenBlocking(void);
const UIWindowLevel UIWindowLevel_ScreenProtection(void);

extern const UIWindowLevel UIWindowLevel_Background;

//@class DTCallModel;

@interface OWSWindowManager : NSObject

@property (nonatomic, readonly) UIWindow *rootWindow;
@property (nonatomic, readonly) UIWindow *callViewWindow;

@property (nonatomic, copy, nullable) void(^callWindowBecomeKeyWindow)(void);

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)setupWithRootWindow:(UIWindow *)rootWindow screenBlockingWindow:(UIWindow *)screenBlockingWindow;

- (void)setIsScreenBlockActive:(BOOL)isScreenBlockActive isForegroundLock:(BOOL)isForegroundLock;

- (void)setIsPhotoLibraryAuth:(BOOL)isPhotoLibraryAuth;

#pragma mark - Message Actions

//@property (nonatomic, readonly) BOOL isPresentingMenuActions;
//
//- (void)showMenuActionsWindow:(UIViewController *)menuActionsViewController;
//- (void)hideMenuActionsWindow;

#pragma mark - Calls

@property (nonatomic, readonly) BOOL shouldShowCallView;

- (void)startCall:(UIViewController *)callViewController animated:(BOOL)animated;;
- (void)endCall:(nullable UIViewController *)callViewController
     completion:(void(^)(void))completion;
- (void)showCallView;
- (void)leaveCallView;

- (void)showFloatingCallView:(UIView *)floatingView;
- (BOOL)hasCall;

// YES when a screen block is active but it is the foreground passcode lock AND the call
// view is floated above it and interactive. In this state UI can still be presented on the
// call window, so callers should NOT defer presentation the way they do for the background
// privacy cover (which hides the call behind it).
- (BOOL)isCallViewFrontmostAboveScreenLock;

/*
- (void)startShowAlertCallView:(UIViewController *)alertCallViewController;
- (void)endAlertCallView:(UIViewController *)alertCallViewController;

- (BOOL)hasAlertCall;
 */

@property (nonatomic, readonly, nullable) UIViewController *alertCallViewController;

- (UIWindow *)getToastSuitableWindow;

@end

NS_ASSUME_NONNULL_END
