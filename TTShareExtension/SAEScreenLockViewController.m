//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SAEScreenLockViewController.h"
#import "UIColor+OWS.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface SAEScreenLockViewController () <ScreenLockViewDelegate>

@property (nonatomic, readonly, weak) id<ShareViewDelegate> shareViewDelegate;

@property (nonatomic) BOOL hasShownAuthUIOnce;

@property (nonatomic) BOOL isShowingAuthUI;

@end

#pragma mark -

@implementation SAEScreenLockViewController

- (instancetype)initWithShareViewDelegate:(id<ShareViewDelegate>)shareViewDelegate
{
    self = [super init];
    if (!self) {
        return self;
    }

    _shareViewDelegate = shareViewDelegate;

    self.delegate = self;

    return self;
}

- (void)loadView
{
    [super loadView];

    self.view.backgroundColor = [UIColor ows_materialBlueColor];
    
    NSString *shareToPrefix = Localized(@"SHARE_EXTENSION_VIEW_TITLE", @"Title for the 'share extension' view.");
    NSString *shareScreenLockTitle = [NSString stringWithFormat:@"%@%@", shareToPrefix, TSConstants.appDisplayName];
    self.title = shareScreenLockTitle;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                      target:self
                                                      action:@selector(dismissPressed:)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self ensureUI];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self ensureUI];

    // Auto-show the auth UI f
    if (!self.hasShownAuthUIOnce) {
        self.hasShownAuthUIOnce = YES;

        [self tryToPresentAuthUIToUnlockScreenLock];
    }
}

- (void)dealloc
{
    // Surface memory leaks by logging the deallocation of view controllers.
    DDLogVerbose(@"Dealloc: %@", self.class);
}

- (void)tryToPresentAuthUIToUnlockScreenLock
{
    OWSAssertIsOnMainThread();

    if (self.isShowingAuthUI) {
        // We're already showing the auth UI; abort.
        return;
    }
    OWSLogInfo(@"%@, try to unlock screen lock", self.logTag);

    self.isShowingAuthUI = YES;

    DTScreenLockBaseViewController *unlockScreenVc = [DTScreenLockBaseViewController buildScreenLockViewWithViewType:DTScreenLockViewTypeUnlockScreen doneCallback:^(NSString * _Nullable passcode) {
        OWSAssertIsOnMainThread();

        OWSLogInfo(@"%@ unlock screen lock succeeded.", self.logTag);

        self.isShowingAuthUI = NO;

        [self.shareViewDelegate shareViewWasUnlocked];

        [self.navigationController popViewControllerAnimated:NO];
        
    }];
    [self.navigationController pushViewController:unlockScreenVc animated:NO];
    [self ensureUI];
}

- (void)ensureUI
{
    [self updateUIWithState:ScreenLockUIStateScreenLock isLogoAtTop:NO animated:NO];
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
               fromViewController:self];
}

- (void)dismissPressed:(id)sender
{
    DDLogDebug(@"%@ tapped dismiss share button", self.logTag);

    [self cancelShareExperience];
}

- (void)cancelShareExperience
{
    [self.shareViewDelegate shareViewWasCancelled];
}

#pragma mark - ScreenLockViewDelegate

- (void)unlockButtonWasTapped
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"%@ unlockButtonWasTapped", self.logTag);

    [self tryToPresentAuthUIToUnlockScreenLock];
}

@end

NS_ASSUME_NONNULL_END
