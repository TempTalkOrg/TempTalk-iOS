//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "RegistrationUtils.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/TSAccountManager.h>
#import "TempTalk-Swift.h"
#import "DTSignChativeController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation RegistrationUtils

+ (void)showReregistrationUIFromViewController:(UIViewController *)fromViewController
{
    UIAlertController *actionSheetController =
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [actionSheetController
        addAction:[UIAlertAction
                      actionWithTitle:Localized(@"DEREGISTRATION_REREGISTER_WITH_RE_LOGIN",
                                          @"Label for button that lets users re-register using the same number.")
                                style:UIAlertActionStyleDestructive
                              handler:^(UIAlertAction *action) {
                                  [RegistrationUtils reregisterWithFromViewController:fromViewController];
                              }]];

    [actionSheetController addAction:[OWSAlerts cancelAction]];

    [fromViewController presentViewController:actionSheetController animated:YES completion:nil];
}

+ (void)kickedOffToRegistration {
    [RegistrationUtils reregisterWithFromViewController:CurrentAppContext().frontmostViewController];
}

+ (void)showNewLoginView:(UIViewController *)fromViewController {
    [ModalActivityIndicatorViewController
     presentFromViewController:fromViewController
     canCancel:NO
     backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [modalActivityIndicator dismissWithCompletion:^{
                UIViewController *viewController = [LoginViewController new];
                OWSNavigationController *navigationController = [[OWSNavigationController alloc] initWithRootViewController:viewController];
                navigationController.navigationBarHidden = YES;
                
                [UIApplication sharedApplication].delegate.window.rootViewController
                = navigationController;
            }];
        });
    }];
}

+ (void)reregisterWithFromViewController:(UIViewController *)fromViewController
{
    OWSLogInfo(@"reregister clean data!");

    if (![[TSAccountManager sharedInstance] resetForReregistration]) {
        OWSFailDebug(@"could not reset for re-registration.");
        return;
    }

    // meeting
    [Environment.shared.preferences unsetRecordedAPNSTokens];
    // 重新登录前重置需要拉取通讯录标识
    [Environment.shared.contactsManager clearShouldBeInitializedTag];
    [DTCalendarManager.shared removeLocalMeetings];
    [DTCalendarManager.shared cancelEventLocalNotification:nil];
    [AppEnvironment.shared.notificationPresenter clearAllNotificationsExceptCategoryIdentifiers:nil];
    
    //screen lock
    [[ScreenLock sharedManager] removePasscode];
    
    [self showNewLoginView:fromViewController];
}

@end

NS_ASSUME_NONNULL_END
