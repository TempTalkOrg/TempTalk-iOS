//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationItemMacro.h"

NS_ASSUME_NONNULL_BEGIN

@class AccountManager;
//@class CallService;
//@class CallUIAdapter;
@class HomeViewController;
@class OWSNavigationController;
//@class OWSWebRTCCallMessageHandler;
@class OutboundCallInitiator;
@class TSThread;
@class OWSViewController;

@interface SignalApp : NSObject

@property (nonatomic, nullable, weak) OWSViewController *homeViewController;
@property (nonatomic, nullable, weak) OWSNavigationController *signUpFlowNavigationController;

// TODO: Convert to singletons?
//@property (nonatomic, readonly) OWSWebRTCCallMessageHandler *callMessageHandler;
//@property (nonatomic, readonly) CallService *callService;
//@property (nonatomic, readonly) CallUIAdapter *callUIAdapter;
//@property (nonatomic, readonly) OutboundCallInitiator *outboundCallInitiator;
@property (nonatomic, readonly) AccountManager *accountManager;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedApp;

#pragma mark - View Convenience Methods

- (void)presentConversationForRecipientId:(NSString *)recipientId;
- (void)presentConversationForRecipientId:(NSString *)recipientId action:(ConversationViewAction)action;
- (void)presentConversationForThreadId:(NSString *)threadId;
- (void)presentConversationForThread:(TSThread *)thread;
- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action;
- (void)presentConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                      focusMessageId:(nullable NSString *)focusMessageId;
- (void)presentTargetConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                            focusMessageId:(nullable NSString *)focusMessageId;

#pragma mark - Methods

// 换登不同账号会清数据: database, userdefault, meeting, OWSTemporaryDirectory
+ (void)resetAppDataWithUI;

+ (void)resetAppData;

+ (void)resetAppDataNoExit;

+ (void)clearAllNotifications;

@end

NS_ASSUME_NONNULL_END
