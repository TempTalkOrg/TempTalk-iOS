//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ScreenLockViewController.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import "SignalApp.h"

NSString *NSStringForScreenLockUIState(ScreenLockUIState value)
{
    switch (value) {
        case ScreenLockUIStateNone:
            return @"ScreenLockUIStateNone";
        case ScreenLockUIStateScreenProtection:
            return @"ScreenLockUIStateScreenProtection";
        case ScreenLockUIStateScreenLock:
            return @"ScreenLockUIStateScreenLock";
        case ScreenLockUIStateOffline:
            return @"ScreenLockUIStateOffline";
    }
}

@interface ScreenLockViewController ()

@property (nonatomic) UIView *screenBlockingImageView;
@property (nonatomic) UIView *screenBlockingButton;
@property (nonatomic) UIView *btnDeregistered;
@property (nonatomic) UILabel *screenBlockingLabel;
@property (nonatomic) NSArray<NSLayoutConstraint *> *screenBlockingConstraints;
@property (nonatomic) NSString *screenBlockingSignature;

@end

#pragma mark -

@implementation ScreenLockViewController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeRight;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait | UIInterfaceOrientationLandscapeRight;
}


- (void)loadView
{
    [super loadView];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UIView *edgesView = [UIView containerView];
    [self.view addSubview:edgesView];
    [edgesView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [edgesView autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [edgesView autoPinWidthToSuperview];

    UIImage *image = [UIImage imageNamed:TSConstants.appLogoName];
    UIImageView *imageView = [UIImageView new];
    imageView.image = image;
    [edgesView addSubview:imageView];
    [imageView autoHCenterInSuperview];

    const CGSize screenSize = UIScreen.mainScreen.bounds.size;
    const CGFloat shortScreenDimension = MIN(screenSize.width, screenSize.height);
    const CGFloat imageSize = round(shortScreenDimension / 3.f);
    [imageView autoSetDimension:ALDimensionWidth toSize:imageSize];
    [imageView autoSetDimension:ALDimensionHeight toSize:imageSize];

    const CGFloat kButtonHeight = 40.f;
    OWSFlatButton *button =
        [OWSFlatButton buttonWithTitle:[NSString stringWithFormat:Localized(@"SCREEN_LOCK_UNLOCK_SIGNAL",
                                                                            @"Label for button on lock screen that lets users unlock Signal."), TSConstants.appDisplayName]
                                  font:[OWSFlatButton fontForHeight:kButtonHeight]
                            titleColor:[UIColor ows_materialBlueColor]
                       backgroundColor:[UIColor clearColor]
                                target:self
                              selector:@selector(showUnlockUI)];
    [button setBackgroundColorsWithUpColor:[UIColor clearColor]
                                 downColor:[UIColor clearColor]];
    [edgesView addSubview:button];

    [button autoSetDimension:ALDimensionHeight toSize:kButtonHeight];
    [button autoPinLeadingToSuperviewMarginWithInset:50.f];
    [button autoPinTrailingToSuperviewMarginWithInset:50.f];
    const CGFloat kVMargin = 110.f;
    [button autoPinBottomToSuperviewMarginWithInset:kVMargin];
    
    NSString *btnDeregisteredTitle = Localized(@"NETWORK_STATUS_DEREGISTERED", @"Error indicating that this device is no longer registered.");
    OWSFlatButton *btnDeregistered =
        [OWSFlatButton buttonWithTitle:btnDeregisteredTitle
                                  font:[OWSFlatButton fontForHeight:kButtonHeight]
                            titleColor:[UIColor ows_redColor]
                       backgroundColor:[UIColor whiteColor]
                                target:self
                              selector:@selector(popToRegistered)];
    btnDeregistered.hidden = YES;
    [btnDeregistered addBorderWithColor:[UIColor ows_redColor]];
    [btnDeregistered.layer setCornerRadius:5];
    [btnDeregistered.layer setMasksToBounds:YES];
    [edgesView addSubview:btnDeregistered];
    CGFloat btnDeregisteredWidth = [btnDeregisteredTitle sizeWithAttributes:@{NSFontAttributeName : [OWSFlatButton fontForHeight:kButtonHeight]}].width + 10;
    [btnDeregistered setSizeWithWidth:btnDeregisteredWidth height:30];
    [btnDeregistered autoHCenterInSuperview];
    [btnDeregistered autoPinBottomToSuperviewMarginWithInset:110.f];
    
    UILabel *accessoryLabel = [UILabel new];
    accessoryLabel.font = [UIFont ows_regularFontWithSize:18.f];
    [edgesView addSubview:accessoryLabel];
    [accessoryLabel autoHCenterInSuperview];
    [accessoryLabel sizeToFit];
    [accessoryLabel autoPinBottomToSuperviewMarginWithInset:110.f];

    self.screenBlockingImageView = imageView;
    self.screenBlockingButton = button;
    self.screenBlockingLabel = accessoryLabel;
    self.btnDeregistered = btnDeregistered;

    [self updateUIWithState:ScreenLockUIStateScreenProtection isLogoAtTop:NO animated:NO];
}

// The "screen blocking" window has three possible states:
//
// * "Just a logo".  Used when app is launching and in app switcher.  Must match the "Launch Screen"
//    storyboard pixel-for-pixel.
// * "Screen Lock, local auth UI presented". Move the Signal logo so that it is visible.
// * "Screen Lock, local auth UI not presented". Move the Signal logo so that it is visible,
//    show "unlock" button.
- (void)updateUIWithState:(ScreenLockUIState)uiState isLogoAtTop:(BOOL)isLogoAtTop animated:(BOOL)animated
{
    OWSAssertIsOnMainThread();

    if (!self.isViewLoaded) {
        return;
    }

    BOOL shouldShowBlockWindow = uiState != ScreenLockUIStateNone;
    BOOL shouldHaveScreenLock = uiState == ScreenLockUIStateScreenLock;

    self.screenBlockingImageView.hidden = !shouldShowBlockWindow;
    self.screenBlockingLabel.hidden = uiState != ScreenLockUIStateOffline;
    
    if (uiState == ScreenLockUIStateOffline) {
        if (TSAccountManager.sharedInstance.isDeregistered) {
            self.screenBlockingLabel.hidden = YES;
            self.btnDeregistered.hidden = NO;
        } else {
            self.screenBlockingLabel.hidden = NO;
            self.btnDeregistered.hidden = YES;
            switch (self.socketManager.socketState) {
                case OWSWebSocketStateClosed:
                    self.screenBlockingLabel.text = Localized(@"NETWORK_STATUS_OFFLINE", @"");
                    self.screenBlockingLabel.textColor = [UIColor ows_redColor];
                    break;
                case OWSWebSocketStateConnecting:
//                    NETWORK_STATUS_CONNECTING
                    self.screenBlockingLabel.text = Localized(@"NETWORK_STATUS_OFFLINE", @"");
                    self.screenBlockingLabel.textColor = [UIColor ows_redColor];
                    break;
                case OWSWebSocketStateOpen:
                    self.screenBlockingLabel.text = Localized(@"NETWORK_STATUS_CONNECTED", @"");
                    self.screenBlockingLabel.textColor = [UIColor ows_greenColor];
                    break;
            }
        }
    }

    NSString *signature = [NSString stringWithFormat:@"%d %d", shouldHaveScreenLock, isLogoAtTop];
    if ([NSObject isNullableObject:self.screenBlockingSignature equalTo:signature]) {
        // Skip redundant work to avoid interfering with ongoing animations.
        return;
    }

    [NSLayoutConstraint deactivateConstraints:self.screenBlockingConstraints];

    NSMutableArray<NSLayoutConstraint *> *screenBlockingConstraints = [NSMutableArray new];

    self.screenBlockingButton.hidden = !shouldHaveScreenLock;

    if (isLogoAtTop) {
        const CGFloat kVMargin = 60.f;
        [screenBlockingConstraints addObject:[self.screenBlockingImageView autoPinEdge:ALEdgeTop
                                                                                toEdge:ALEdgeTop
                                                                                ofView:self.view
                                                                            withOffset:kVMargin]];
    } else {
        [screenBlockingConstraints addObject:[self.screenBlockingImageView autoVCenterInSuperview]];
    }

    self.screenBlockingConstraints = screenBlockingConstraints;
    self.screenBlockingSignature = signature;

    if (animated) {
        [UIView animateWithDuration:0.35f
                         animations:^{
                             [self.view layoutIfNeeded];
                         }];
    } else {
        [self.view layoutIfNeeded];
    }
}

- (void)userTakeScreenshotEvent:(NSNotification *)notify {

}
- (void)showUnlockUI
{
    OWSAssertIsOnMainThread();

    [self.delegate unlockButtonWasTapped];
}

- (void)popToRegistered {
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
