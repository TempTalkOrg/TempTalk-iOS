//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SignalApp.h"
#import "ConversationItemMacro.h"
#import "NewContactThreadViewController.h"
#import "HomeViewController.h"
#import "Yelling-Swift.h"
#import <TTMessaging/DebugLogger.h>
#import <TTMessaging/Environment.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSGroupThread.h>
#import <SignalCoreKit/Threading.h>

NS_ASSUME_NONNULL_BEGIN

@interface SignalApp ()
@property (nonatomic) AccountManager *accountManager;

@end

#pragma mark -

@implementation SignalApp

+ (instancetype)sharedApp
{
    static SignalApp *sharedApp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApp = [[self alloc] initDefault];
    });
    return sharedApp;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

#pragma mark - Singletons
- (AccountManager *)accountManager
{
    @synchronized(self)
    {
        if (!_accountManager) {
            _accountManager = [[AccountManager alloc] initWithTextSecureAccountManager:[TSAccountManager sharedInstance]
                                                                           preferences:Environment.shared.preferences];
        }
    }

    return _accountManager;
}

#pragma mark - View Convenience Methods

- (void)presentConversationForRecipientId:(NSString *)recipientId
{
    [self presentConversationForRecipientId:recipientId action:ConversationViewActionNone];
}

- (void)presentConversationForRecipientId:(NSString *)recipientId action:(ConversationViewAction)action
{
    DispatchMainThreadSafe(^{
        __block TSThread *thread = nil;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            thread = [TSContactThread getOrCreateThreadWithContactId:recipientId transaction:transaction];
        });
        [self presentConversationForThread:thread action:action];
    });
}

- (void)presentConversationForThreadId:(NSString *)threadId
{
    OWSAssertDebug(threadId.length > 0);

    __block TSThread *thread = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
    }];
    if (thread == nil) {
        OWSFailDebug(@"%@ unable to find thread with id: %@", self.logTag, threadId);
        return;
    }

    [self presentConversationForThread:thread];
}

- (void)presentConversationForThread:(TSThread *)thread
{
    [self presentConversationForThread:thread action:ConversationViewActionNone];
}

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action
{
    [self presentConversationForThread:thread action:action focusMessageId:nil];
}

- (void)presentConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                      focusMessageId:(nullable NSString *)focusMessageId
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    if (!thread) {
        OWSFailDebug(@"%@ Can't present nil thread.", self.logTag);
        return;
    }

    DispatchMainThreadSafe(^{
        UIViewController *frontmostVC = [[UIApplication sharedApplication] frontmostViewController];

        if ([frontmostVC isKindOfClass:[ConversationViewController class]]) {
            ConversationViewController *conversationVC = (ConversationViewController *)frontmostVC;
            if ([conversationVC.thread.uniqueId isEqualToString:thread.uniqueId]) {
                [conversationVC popKeyBoard];
                return;
            }
        }

        
        if ([self.homeViewController isKindOfClass:[HomeViewController class]]) {
            
            HomeViewController *homeVC = (HomeViewController *)self.homeViewController;
            [homeVC presentThread:thread action:action focusMessageId:focusMessageId];
            return;
        }
        
        if ([self.homeViewController isKindOfClass:[NewContactThreadViewController class]]) {
            
            NewContactThreadViewController *contactThreadVC = (NewContactThreadViewController *)self.homeViewController;
            [contactThreadVC presentThread:thread action:action focusMessageId:focusMessageId];
        }
    });
}

- (void)presentTargetConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                      focusMessageId:(nullable NSString *)focusMessageId {
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    OWSLogInfo(@"[metris] present target Conversation start");

    if (!thread) {
        OWSFailDebug(@"%@ Can't present nil thread.", self.logTag);
        return;
    }
    
    DispatchMainThreadSafe(^{
        UIViewController *frontmostVC = [[UIApplication sharedApplication] frontmostViewController];
        if ([frontmostVC isKindOfClass:[ConversationViewController class]]) {
            ConversationViewController *conversationVC = (ConversationViewController *)frontmostVC;
            if ([conversationVC.thread.uniqueId isEqualToString:thread.uniqueId]) {
                [conversationVC popKeyBoard];
                return;
            }
        }

        // 查找 DFTabbarController
        DFTabbarController *tabbarVC = nil;
        if ([frontmostVC isKindOfClass:[DFTabbarController class]]) {
            tabbarVC = (DFTabbarController *)frontmostVC;
        } else {
            UIViewController *parentVC = frontmostVC;
            while (parentVC != nil && ![parentVC isKindOfClass:[DFTabbarController class]]) {
                parentVC = parentVC.parentViewController;
            }
            if ([parentVC isKindOfClass:[DFTabbarController class]]) {
                tabbarVC = (DFTabbarController *)parentVC;
            }
        }

        if (!tabbarVC) {
            OWSLogError(@"DFTabbarController not found");
            return;
        }

        UINavigationController *rootNav = tabbarVC.viewControllers.firstObject;
        if (!rootNav) {
            OWSLogError(@"rootNav = nil");
            return;
        }

        // dismiss presented view controller first, then navigate
        void (^navigateToConversation)(void) = ^{
            // 切换到第一个 tab
            if (tabbarVC.selectedIndex != 0) {
                UIViewController *selectedVC = tabbarVC.selectedViewController;
                if ([selectedVC isKindOfClass:[UINavigationController class]]) {
                    UINavigationController *selectedNav = (UINavigationController *)selectedVC;
                    [selectedNav popToRootViewControllerAnimated:NO];
                }
                [tabbarVC setSelectedIndex:0];
            }

            // pop 到 root，然后 present conversation
            [rootNav popToRootViewControllerAnimated:NO];

            // 延迟一帧确保 pop 完成后再 push
            dispatch_async(dispatch_get_main_queue(), ^{
                HomeViewController *homeVC = [rootNav.viewControllers firstObject];
                if ([homeVC isKindOfClass:[HomeViewController class]]) {
                    [homeVC presentThread:thread action:action focusMessageId:focusMessageId];
                } else {
                    OWSLogError(@"HomeViewController not found at rootNav root");
                }
            });
        };

        // 先 dismiss 所有 presented view controller
        if (tabbarVC.presentedViewController != nil) {
            [tabbarVC.presentedViewController dismissViewControllerAnimated:NO completion:navigateToConversation];
        } else {
            navigateToConversation();
        }
    });
}

#pragma mark - Methods

+ (void)resetAppDataWithUI
{
    OWSLogInfo(@"");
    
    DispatchMainThreadSafe(^{
        UIViewController *fromVC = UIApplication.sharedApplication.frontmostViewController;
        [ModalActivityIndicatorViewController
         presentFromViewController:fromVC
         canCancel:YES
         backgroundBlock:^(
                           ModalActivityIndicatorViewController *modalActivityIndicator) { [SignalApp resetAppData]; }];
    });
}

+ (void)resetAppData
{
    [[self class] resetAppDataNoExit];
    exit(0);
}

+ (void)resetAppDataNoExit
{
    // This _should_ be wiped out below.
    OWSLogError(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [DDLog flushLog];
    DispatchSyncMainThreadSafe(^{
        [self.databaseStorage resetAllStorage];
        [[OWSProfileManager sharedManager] resetProfileStorage];
        [Environment.preferences clear];
//        [OWSUserProfile resetProfileStorage];
//        [Environment.shared.preferences removeAllValues];
        [AppEnvironment.shared.notificationPresenter clearAllNotificationsExceptCategoryIdentifiers:nil];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appSharedDataDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appDocumentDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem cachesDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:OWSTemporaryDirectory()];
        [OWSFileSystem deleteContentsOfDirectory:NSTemporaryDirectory()];
        [[TSMessageReadPositionCache shared] clearAllCache];
    });

    [DebugLogger.shared wipeLogsAlwaysWithAppContext:CurrentAppContext()];
}

+ (void)clearAllNotifications
{
    OWSLogInfo(@"%@ clearAllNotifications.", self.logTag);

    // This will cancel all "scheduled" local notifications that haven't
    // been presented yet.
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    // To clear all already presented local notifications, we need to
    // set the app badge number to zero after setting it to a non-zero value.
    [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}

@end

NS_ASSUME_NONNULL_END
