//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//
#import "OWSViewController.h"

typedef NS_ENUM(NSUInteger, ScreenLockUIState) {
    ScreenLockUIStateNone,
    // Shown while app is inactive or background, if enabled.
    ScreenLockUIStateScreenProtection,
    // Shown while app is active, if enabled.
    ScreenLockUIStateScreenLock,
    // Shown while app socket disconnected or unregistered
    ScreenLockUIStateOffline,
};

NSString *NSStringForScreenLockUIState(ScreenLockUIState value);

@protocol ScreenLockViewDelegate <NSObject>

- (void)unlockButtonWasTapped;

@end

#pragma mark -

@interface ScreenLockViewController : OWSViewController

@property (nonatomic, weak) id<ScreenLockViewDelegate> delegate;

- (void)updateUIWithState:(ScreenLockUIState)uiState isLogoAtTop:(BOOL)isLogoAtTop animated:(BOOL)animated;

@end
