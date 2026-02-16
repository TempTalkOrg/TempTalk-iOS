//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const ScreenLockDidUnlockNotification;

@interface OWSScreenLockUI : NSObject

@property (nonatomic, readonly) UIWindow *screenBlockingWindow;
@property (nonatomic, readonly) BOOL isShowingScreenLockUI;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)setupWithRootWindow:(UIWindow *)rootWindow;

- (void)startObserving;

@end

NS_ASSUME_NONNULL_END
