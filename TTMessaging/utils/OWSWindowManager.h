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

extern const UIWindowLevel UIWindowLevel_Background;

//@class DTCallModel;

@interface OWSWindowManager : NSObject

@property (nonatomic, readonly) UIWindow *rootWindow;
@property (nonatomic, readonly) UIWindow *callViewWindow;

@property (nonatomic, copy, nullable) void(^callWindowBecomeKeyWindow)(void);

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)setupWithRootWindow:(UIWindow *)rootWindow screenBlockingWindow:(UIWindow *)screenBlockingWindow;

- (void)setIsScreenBlockActive:(BOOL)isScreenBlockActive;

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

/*
- (void)startShowAlertCallView:(UIViewController *)alertCallViewController;
- (void)endAlertCallView:(UIViewController *)alertCallViewController;

- (BOOL)hasAlertCall;
 */

@property (nonatomic, readonly, nullable) UIViewController *alertCallViewController;

- (UIWindow *)getToastSuitableWindow;

@end

NS_ASSUME_NONNULL_END
