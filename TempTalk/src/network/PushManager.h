//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DTApnsInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class UILocalNotification;

extern NSString *const Signal_Thread_UserInfo_Key;
extern NSString *const Signal_Message_UserInfo_Key;

extern NSString *const Signal_Full_New_Message_Category;
extern NSString *const Signal_Full_New_Message_Category_No_Longer_Verified;

extern NSString *const Signal_Message_Reply_Identifier;
extern NSString *const Signal_Message_MarkAsRead_Identifier;

#pragma mark Signal Calls constants

extern NSString *const PushManagerCategoriesIncomingCall;
extern NSString *const PushManagerCategoriesMissedCall;
extern NSString *const PushManagerCategoriesMissedCallFromNoLongerVerifiedIdentity;

extern NSString *const PushManagerActionsAcceptCall;
extern NSString *const PushManagerActionsDeclineCall;
extern NSString *const PushManagerActionsCallBack;
extern NSString *const PushManagerActionsShowThread;

extern NSString *const PushManagerUserInfoKeysCallBackSignalRecipientId;
extern NSString *const PushManagerUserInfoKeysLocalCallId;

extern NSString *const kDTDidReceiveRemoteNotification;
extern NSString *const kDTDidReceiveScheduleLocalNotification;

typedef void (^failedPushRegistrationBlock)(NSError *error);
typedef void (^pushTokensSuccessBlock)(NSString *pushToken, NSString *voipToken);

/**
 * The Push Manager is responsible for handling received push notifications.
 */
@interface PushManager : NSObject

@property (nonatomic) BOOL hasPresentedConversationSinceLastDeactivation;

@property (nonatomic, strong, nullable) DTApnsInfo *apnsInfo;

- (instancetype)init NS_UNAVAILABLE;

+ (PushManager *)sharedManager;

#pragma mark Push Notifications Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)application:(UIApplication *)application didReceiveRemoteVoIPNotification:(NSDictionary *)userInfo completion:(void (^__nullable)(void))completion;

- (DTApnsInfo *)apnsInfoWithUserInfo:(NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
