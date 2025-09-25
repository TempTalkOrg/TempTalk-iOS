//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "PushManager.h"
#import "AppDelegate.h"
#import "TempTalk-Swift.h"
#import "SignalApp.h"
#import "ThreadUtil.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/AppReadiness.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/NSString+SSK.h>
#import <TTServiceKit/OWSDevice.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/OWSReadReceiptManager.h>
#import <TTServiceKit/OWSSignalService.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSIncomingMessage.h>
#import <TTServiceKit/TSOutgoingMessage.h>
#import "DTCallKitManager.h"

NSString *const Signal_Thread_UserInfo_Key = @"Signal_Thread_Id";
NSString *const Signal_Message_UserInfo_Key = @"Signal_Message_Id";

NSString *const Signal_Full_New_Message_Category = @"Signal_Full_New_Message";
NSString *const Signal_Full_New_Message_Category_No_Longer_Verified =
    @"Signal_Full_New_Message_Category_No_Longer_Verified";

NSString *const Signal_Message_Reply_Identifier = @"Signal_New_Message_Reply";
NSString *const Signal_Message_MarkAsRead_Identifier = @"Signal_Message_MarkAsRead";

NSString *const kDTDidReceiveRemoteNotification = @"DTDidReceiveRemoteNotification";
NSString *const kDTDidReceiveScheduleLocalNotification = @"kDTDidReceiveScheduleLocalNotification";

@interface PushManager ()
@property (nonatomic) UIBackgroundTaskIdentifier callBackgroundTask;
@property (nonatomic, readonly) OWSMessageSender *messageSender;

@end

@implementation PushManager

+ (instancetype)sharedManager {
    static PushManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] initDefault];
    });
    return sharedManager;
}

- (instancetype)initDefault
{
    return [self initWithMessageFetcherJob:self.messageFetcherJob
                             messageSender:Environment.shared.messageSender];
}

- (instancetype)initWithMessageFetcherJob:(OWSMessageFetcherJob *)messageFetcherJob
                            messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];
    if (!self) {
        return self;
    }

    _messageSender = messageSender;
    _callBackgroundTask = UIBackgroundTaskInvalid;


    OWSSingletonAssert();
    return self;
}


#pragma mark Manage Incoming Push

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    OWSLogInfo(@"%@ received remote notification", self.logTag);

    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        [self.messageFetcherJob runObjc];
    });
}

- (void)application:(UIApplication *)application didReceiveRemoteVoIPNotification:(NSDictionary *)userInfo completion:(void (^__nullable)(void))completion {
    OWSLogInfo(@"=======>CallKit: received VoIP notification: %@",userInfo);
    // Do not need save to PushMessage
    DTApnsInfo *info = [self apnsInfoWithUserInfo:userInfo];
    if (info == nil) {
        info = [DTApnsInfo new];
    }
    
    NSString *callerName = [self callerNameFromVoIP:userInfo];
    NSString *passthroughInfo = userInfo[@"aps"][@"passthrough"];
    NSData *inData = [passthroughInfo dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *passthrough = nil;

    if (inData) {
        NSError *error;
        passthrough = [NSJSONSerialization JSONObjectWithData:inData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            OWSLogError(@"passthroughInfo to dict error:%@", error);
        }
    }

    NSMutableDictionary *infoM = @{}.mutableCopy;

    if (DTParamsUtils.validateDictionary(passthrough)) {
        if (callerName) {
            infoM[@"callerName"] = callerName;
        }
        NSDictionary *callInfo = (NSDictionary *)passthrough[@"callInfo"];
        if (DTParamsUtils.validateDictionary(callInfo)) {
            infoM[@"callInfo"] = callInfo;
        }
    } else {
        NSString *msg = (NSString *)(userInfo[@"aps"][@"msg"]);
        if (DTParamsUtils.validateString(msg)) {
            infoM[@"msg"] = msg;
        }
    }

    [[DTCallKitManager shared] handleVoipCallNotify:infoM.copy completion:completion];
}

- (NSString *)callerNameFromVoIP:(NSDictionary *)info {
    NSDictionary *aps = info[@"aps"];
    if ([aps isKindOfClass:[NSDictionary class]]) {
        NSDictionary *alert = aps[@"alert"];
        if ([alert isKindOfClass:[NSDictionary class]]) {
            NSArray *locArgs = alert[@"loc-args"];
            if ([locArgs isKindOfClass:[NSArray class]] && locArgs.count > 0) {
                return  locArgs.firstObject;
            }
        }
    }
    return @"";
}

/**
 *  This code should in principle never be called. The only cases where it would be called are with the old-style
 * "content-available:1" pushes if there is no "voip" token registered
 *
 */
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    OWSLogInfo(@"%@ received content-available push", self.logTag);
        
    NSDictionary *aps = userInfo[@"aps"];
    if (DTParamsUtils.validateDictionary(aps) &&
        [aps[@"content-available"] intValue] == 1 &&
        [UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        // 静默推送, 如果app在前台不处理
        OWSLogInfo(@"%@ userInfo:\n%@", self.logTag, userInfo);
        NSDictionary *customContent = (NSDictionary *)userInfo[@"custom-content"];
        NSString *type = (NSString *)customContent[@"type"];
        NSDictionary *data = (NSDictionary *)customContent[@"data"];
        if (!DTParamsUtils.validateDictionary(data)) {
            completionHandler(UIBackgroundFetchResultNoData);
            return;
        }
        if ([type isEqualToString:@"CALENDAR_FULL_UPDATE"]) {
            NSInteger serverVersion = [data[@"version"] intValue];
            AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
                [[DTCalendarManager shared] updateLocalNotificationWithServerVersion:serverVersion completion:^{
                    OWSLogInfo(@"%@ processed %@", self.logTag, type);
                    completionHandler(UIBackgroundFetchResultNewData);
                }];
            });
        }
    } else {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
            self.apnsInfo = [self apnsInfoWithUserInfo:userInfo];
            if (self.apnsInfo) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kDTDidReceiveRemoteNotification object:nil userInfo:@{@"apnsInfo":self.apnsInfo}];
            }
            
            AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    completionHandler(UIBackgroundFetchResultNewData);
                });
            });
        } else {
            
            completionHandler(UIBackgroundFetchResultNewData);
        }
    }
    
}

- (void)presentOncePerActivationConversationWithThreadId:(NSString *)threadId
{
    if (self.hasPresentedConversationSinceLastDeactivation) {
        OWSFailDebug(@"%@ in %s refusing to present conversation: %@ multiple times.",
            self.logTag,
            __PRETTY_FUNCTION__,
            threadId);
        return;
    }

    self.hasPresentedConversationSinceLastDeactivation = YES;
    [SignalApp.sharedApp presentConversationForThreadId:threadId];
}

#pragma mark - Signal Calls

NSString *const PushManagerCategoriesIncomingCall = @"PushManagerCategoriesIncomingCall";
NSString *const PushManagerCategoriesMissedCall = @"PushManagerCategoriesMissedCall";
NSString *const PushManagerCategoriesMissedCallFromNoLongerVerifiedIdentity =
    @"PushManagerCategoriesMissedCallFromNoLongerVerifiedIdentity";

NSString *const PushManagerActionsAcceptCall = @"PushManagerActionsAcceptCall";
NSString *const PushManagerActionsDeclineCall = @"PushManagerActionsDeclineCall";
NSString *const PushManagerActionsCallBack = @"PushManagerActionsCallBack";
NSString *const PushManagerActionsIgnoreIdentityChangeAndCallBack =
    @"PushManagerActionsIgnoreIdentityChangeAndCallBack";
NSString *const PushManagerActionsShowThread = @"PushManagerActionsShowThread";

NSString *const PushManagerUserInfoKeysLocalCallId = @"PushManagerUserInfoKeysLocalCallId";
NSString *const PushManagerUserInfoKeysCallBackSignalRecipientId = @"PushManagerUserInfoKeysCallBackSignalRecipientId";

#pragma mark Util

- (UNAuthorizationOptions)allNotificationTypes {
    return UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
}

- (BOOL)applicationIsActive {
    UIApplication *app = [UIApplication sharedApplication];

    if (app.applicationState == UIApplicationStateActive) {
        return YES;
    }

    return NO;
}


- (DTApnsInfo *)apnsInfoWithUserInfo:(NSDictionary *)userInfo{
    
    if(!userInfo){
        OWSLogError(@"construct apnsInfo error no userInfo");
        return nil;
    }
    
    NSError *error;
    DTApnsInfo *apnsInfo = [MTLJSONAdapter modelOfClass:[DTApnsInfo class] fromJSONDictionary:userInfo error:&error];
    if(error){
        OWSLogError(@"construct apnsInfo error:%@", error);
        return nil;
    }
    
    return apnsInfo;
}

@end
