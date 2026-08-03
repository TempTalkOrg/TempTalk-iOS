//
//  DTCallKitManager.m
//  CalendarTest-Finn
//
//  Created by user on 2022/7/22.
//

#import "DTCallKitManager.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <TTServiceKit/NSString+SSK.h>
#import <TTServiceKit/TSConstants.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <SignalCoreKit/Threading.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import "NSNotificationCenter+OWS.h"
#import "DTCallKitManager+CallerMapTool.h"
#import "MainAppContext.h"
#import "DTCallModel.h"
#import <TTServiceKit/DTCallManager.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import "Yelling-Swift.h"
#import <LiveKitWebRTC/LiveKitWebRTC.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UserNotifications/UserNotifications.h>

static dispatch_queue_t callKitQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.temptalk.callkit.call", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static BOOL TTCallKitCriticalFlagValue(id value) {
    if ([value isKindOfClass:NSNumber.class]) {
        return [value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [(NSString *)value lowercaseString];
        return [normalized isEqualToString:@"1"] || [normalized isEqualToString:@"true"] || [normalized isEqualToString:@"yes"];
    }
    return NO;
}

static NSDictionary *TTCallKitDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? (NSDictionary *)value : nil;
}

static BOOL TTCallKitCallTypeValue(id value) {
    NSInteger type = -1;
    if ([value isKindOfClass:NSNumber.class]) {
        type = [(NSNumber *)value integerValue];
    } else if ([value isKindOfClass:NSString.class]) {
        type = [(NSString *)value integerValue];
    }

    switch (type) {
        case 3:  // PERSONAL_CALL
        case 4:  // PERSONAL_CALL_CANCEL
        case 5:  // PERSONAL_CALL_TIMEOUT
        case 13: // GROUP_CALL
        case 14: // GROUP_CALL_COLSE
        case 15: // GROUP_CALL_OVER
        case 22: // ENC_CALL
            return YES;
        default:
            return NO;
    }
}

static BOOL TTCallKitUserInfoIsCallNotification(NSDictionary *userInfo) {
    NSDictionary *aps = TTCallKitDictionary(userInfo[@"aps"]);
    NSDictionary *alert = TTCallKitDictionary(aps[@"alert"]);
    NSString *locKey = [alert[@"loc-key"] isKindOfClass:NSString.class] ? alert[@"loc-key"] : nil;

    static NSSet<NSString *> *callLocKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        callLocKeys = [NSSet setWithObjects:@"PERSONAL_CALL",
                                           @"PERSONAL_CALL_CANCEL",
                                           @"PERSONAL_CALL_TIMEOUT",
                                           @"GROUP_CALL",
                                           @"GROUP_CALL_COLSE",
                                           @"GROUP_CALL_OVER",
                                           @"MEETING-POPUPS",
                                           @"ENC_CALL",
                                           nil];
    });

    if (locKey.length > 0 && [callLocKeys containsObject:locKey]) {
        return YES;
    }

    return TTCallKitCallTypeValue(aps[@"type"] ?: userInfo[@"type"]);
}

static BOOL TTCallKitUserInfoHasCriticalAlert(NSDictionary *userInfo) {
    NSDictionary *aps = TTCallKitDictionary(userInfo[@"aps"]);
    id interruptionLevel = aps[@"interruption-level"] ?: userInfo[@"interruption-level"] ?: userInfo[@"interruptionLevel"];
    if ([interruptionLevel isKindOfClass:NSString.class] &&
        [(NSString *)interruptionLevel caseInsensitiveCompare:@"critical"] == NSOrderedSame) {
        return YES;
    }

    id sound = aps[@"sound"] ?: userInfo[@"sound"];
    NSDictionary *soundDict = TTCallKitDictionary(sound);
    return TTCallKitCriticalFlagValue(soundDict[@"critical"]);
}

static BOOL TTCallKitUserInfoHasCallCriticalAlert(NSDictionary *userInfo) {
    return TTCallKitUserInfoIsCallNotification(userInfo) && TTCallKitUserInfoHasCriticalAlert(userInfo);
}

static BOOL TTCallKitStringContainsCallHint(NSString *value, NSString *callHint) {
    return [value isKindOfClass:NSString.class] &&
           [callHint isKindOfClass:NSString.class] &&
           value.length > 0 &&
           callHint.length > 0 &&
           [value containsString:callHint];
}

static BOOL TTCallKitNotificationMatchesCallHint(UNNotification *notification, NSString *callHint) {
    if (TTCallKitStringContainsCallHint(notification.request.identifier, callHint)) {
        return YES;
    }
    if (TTCallKitStringContainsCallHint(notification.request.content.threadIdentifier, callHint)) {
        return YES;
    }

    NSDictionary *userInfo = notification.request.content.userInfo;
    NSDictionary *aps = TTCallKitDictionary(userInfo[@"aps"]);
    NSString *passthrough = [aps[@"passthrough"] isKindOfClass:NSString.class] ? aps[@"passthrough"] : nil;
    return TTCallKitStringContainsCallHint(passthrough, callHint);
}

static BOOL TTCallKitShouldRemoveDeliveredCriticalAlert(UNNotification *notification, NSString *callHint) {
    NSDictionary *userInfo = notification.request.content.userInfo;
    if (TTCallKitUserInfoHasCallCriticalAlert(userInfo)) {
        return YES;
    }

    if (!TTCallKitUserInfoHasCriticalAlert(userInfo)) {
        return NO;
    }

    // Some server-driven critical ring alerts do not carry call metadata in the
    // delivered notification. Remove only the currently ringing/recent alert when
    // it can be correlated to the caller, instead of leaving it to compete with
    // CallKit audio.
    NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:notification.date];
    return age >= 0 && age <= 90 && TTCallKitNotificationMatchesCallHint(notification, callHint);
}

static void TTCallKitRemoveCriticalNotifications(NSString *reason, NSString *uuidString, NSString *callHint) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (UNNotification *notification in notifications) {
            if (TTCallKitShouldRemoveDeliveredCriticalAlert(notification, callHint)) {
                [identifiers addObject:notification.request.identifier];
            }
        }
        if (identifiers.count > 0) {
            OWSLogInfo(@"[call][callkit] removing delivered critical notifications, reason=%@, uuid=%@, callHint=%@, ids=%@",
                       reason,
                       uuidString,
                       callHint,
                       identifiers);
            [center removeDeliveredNotificationsWithIdentifiers:identifiers];
        }
    }];

    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (UNNotificationRequest *request in requests) {
            if (TTCallKitUserInfoHasCallCriticalAlert(request.content.userInfo)) {
                [identifiers addObject:request.identifier];
            }
        }
        if (identifiers.count > 0) {
            OWSLogInfo(@"[call][callkit] removing pending critical notifications, reason=%@, uuid=%@, ids=%@",
                       reason,
                       uuidString,
                       identifiers);
            [center removePendingNotificationRequestsWithIdentifiers:identifiers];
        }
    }];
}

/// How long to hold a CXAnswerCallAction waiting for the LiveKit room to connect.
@interface DTCallKitManager () <CXCallObserverDelegate, CXProviderDelegate>

@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXProviderConfiguration *configuration;
@property (nonatomic, strong) CXCallController *callController;

@property (nonatomic, strong) NSMutableDictionary *callerMap;
@property (nonatomic, strong) NSRecursiveLock *callerMapLock;

/// Per-call timeout timers (key: uuidString, value: NSTimer)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTimer *> *timeoutTimers;

@end

@implementation DTCallKitManager

+ (NSString *)logTag {
    return @"[call][callkit]";
}

+ (DTCallKitManager*)shared
{
    static DTCallKitManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [DTCallKitManager new];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _callerMapLock = [[NSRecursiveLock alloc] init];
        _callerMapLock.name = @"com.temptalk.callkit.callerMap";
        self.provider = [[CXProvider alloc] initWithConfiguration:self.configuration];
        [_provider setDelegate:self queue:callKitQueue()];
        [self.callController.callObserver setDelegate:self queue:callKitQueue()];
        _callerMap = [[NSMutableDictionary alloc] init];
        _timeoutTimers = [NSMutableDictionary dictionary];

        // Register Darwin notification for background call termination
        [[NotificationHandler shared] registerDarwinNotification];
    }

    // Pre-init RTC / AudioSession to reduce PushKit callback latency
    (void)[DTRTCAudioSession shared];

    return self;
}

- (NSUInteger)callsCount {
    return _callController.callObserver.calls.count;
}

- (BOOL)haveAcceptCall {
    return [self hasAnyAcceptedCall];
}

- (void)reportFakeCallCompletion:(void (^__nullable)(void))completion{
    @weakify(self)
    NSUUID *uuid = [NSUUID UUID];
    [_provider reportNewIncomingCallWithUUID:uuid update:[CXCallUpdate new] completion:^(NSError * _Nullable error) {
        @strongify(self)
        if (completion) { completion(); }
        [self.provider reportCallWithUUID:uuid endedAtDate:nil reason:CXCallEndedReasonFailed];
    }];
}

/// 立即上报一个占位 incoming call。completion 会在 CallKit 回执后回传 UUID 与成功标志;
/// 调用方必须据此决定后续路径 —— 若 succeeded==NO,CallKit 并未记录该 UUID,
/// 不能再走 reportCallWithUUID:updated: 更新流程,否则会在 callerMap 里留下无 UI 的幽灵条目。
- (void)reportPlaceholderIncomingCallWithCompletion:(void (^)(NSUUID *uuid, BOOL succeeded))completion {
    NSUUID *uuid = [NSUUID UUID];
    [_provider reportNewIncomingCallWithUUID:uuid
                                      update:[CXCallUpdate new]
                                  completion:^(NSError * _Nullable error) {
        if (error) {
            OWSLogError(@"%@ placeholder reportNewIncomingCall failed: %@", DTCallKitManager.logTag, error);
        }
        if (completion) {
            completion(uuid, error == nil);
        }
    }];
}

/// 结束指定占位 UUID (fake / 过期 / 解密失败 / 重复等场景)。
- (void)endPlaceholderCall:(nullable NSUUID *)uuid
                completion:(void (^__nullable)(void))completion {
    if (completion) { completion(); }
    if (uuid) {
        [_provider reportCallWithUUID:uuid endedAtDate:nil reason:CXCallEndedReasonFailed];
    }
}

#pragma mark - Receive Call

- (void)didReceiveCall:(NSString *)callerName
         callerAccount:(NSString *)callerAccount
           channelName:(NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(NSString *)meetingName
                  mode:(NSString *)mode
                   emk:(NSString *)emkString
        meetingVersion:(NSNumber *)meetingVersion
            isSchedule:(BOOL)isSchedule
          isLiveStream:(BOOL)isLiveStream
                   eid:(NSString *)eid
        liveKitCalling:(DSKProtoCallMessageCalling *)calling
       preReportedUUID:(NSUUID *)preReportedUUID
            completion:(void (^)(void))completion
{
    NSString *callerID = [callerAccount transforUserAccountToCallNumber];

    OWSLogInfo(@"%@ mode:%@ didReceiveCall has calling: %@ preReported: %@", self.logTag, mode, calling ? @"YES" : @"NO", preReportedUUID ? @"YES" : @"NO");

    [self.callerMapLock lock];

    // Reject if already at max active calls
    NSUInteger activeCount = [self getActiveCallsCountFromCallerMap];
    if (activeCount >= 2) {
        [self.callerMapLock unlock];
        OWSLogInfo(@"%@ didReceiveCall rejected: activeCalls=%lu", self.logTag, activeCount);
        if (preReportedUUID) {
            [self endPlaceholderCall:preReportedUUID completion:completion];
        } else {
            [self reportFakeCallCompletion:completion];
        }
        if (calling) {
            [self rejectCallFromCallKit:calling];
        }
        return;
    }

    // Check if same callerAccount already has an active call (by roomId, not just account)
    NSString *incomingRoomId = meetingId;
    for (WeaCallKitCaller *existingCaller in self.callerMap.allValues) {
        BOOL sameRoom = incomingRoomId && existingCaller.meetingId && [existingCaller.meetingId isEqualToString:incomingRoomId];
        BOOL sameCallerNotEnded = [existingCaller.callerAccount isEqualToString:callerID] && !existingCaller.isEnded;
        if (sameRoom || sameCallerNotEnded) {
            [self.callerMapLock unlock];
            OWSLogWarn(@"%@ duplicate call detected (sameRoom=%d, sameCallerNotEnded=%d), rejecting", self.logTag, sameRoom, sameCallerNotEnded);
            if (preReportedUUID) {
                [self endPlaceholderCall:preReportedUUID completion:completion];
            } else {
                [self reportFakeCallCompletion:completion];
            }
            if (calling) {
                [self rejectCallFromCallKit:calling];
            }
            return;
        }
    }

    OWSLogInfo(@"%@ didReceiveCall processing: callerMapCount=%lu", self.logTag, self.callerMap.count);

    NSUUID *uuid = preReportedUUID ?: [NSUUID UUID];
    NSString *uuidString = uuid.UUIDString;

    WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
    newCaller.uuid = uuid;
    newCaller.callerAccount = callerID;
    // Pre-populate meetingId so concurrent code won't see a half-initialized caller (B3 fix)
    newCaller.meetingId = meetingId;
    [self.callerMap setObject:newCaller forKey:uuidString];

    [self.callerMapLock unlock];

    // Determine call type and display name
    newCaller.isPrivateCall = NO;
    NSString *value = nil;
    NSString *nameForDisplay = nil;
    if (calling.conversationID.hasNumber) {
        NSString *callerNumber = calling.conversationID.number;
        value = [callerNumber stringByAppendingFormat:@".%@", meetingVersion];
        nameForDisplay = [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerAccount];
        newCaller.isPrivateCall = YES;
    } else if (calling.conversationID.hasGroupID) {
        value = [NSString stringWithFormat:@"group.%@.%@", callerID, meetingVersion];
        NSString *serverGid = [TSGroupThread transformToServerGroupIdWithLocalGroupId:calling.conversationID.groupID];
        __block NSString *resolvedName = nil;
        [SDSDatabaseStorage.shared readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            resolvedName = [DTGroupCryptoDisplayHelper.shared resolveGroupCallDisplayNameWithTrustedPlaintextName:meetingName
                                                                                                   serverGroupId:serverGid
                                                                                                     transaction:transaction];
        }];
        nameForDisplay = resolvedName;
    } else {
        value = [NSString stringWithFormat:@"instant.%@.%@", callerID, meetingVersion];
        nameForDisplay = [NSString stringWithFormat:@"%@'s instant call", [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerID]];
    }

    if (!DTParamsUtils.validateString(nameForDisplay)) {
        nameForDisplay = @"Call";
    }

    CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric
                                                value:value];

    CXCallUpdate *callUpdate = [CXCallUpdate new];
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsDTMF = NO;
    callUpdate.remoteHandle = handle;
    callUpdate.hasVideo = NO;
    callUpdate.localizedCallerName = nameForDisplay;

    [DTRTCAudioSession.shared callkitReceiveCall:!newCaller.isPrivateCall];

    OWSLogInfo(@"%@ reporting incoming call - %@ - %@", self.logTag, uuidString, NSThread.currentThread);

    // Success callback: populate callerMap + start timeout timer
    @weakify(self)
    void (^onReportSuccess)(void) = ^{
        @strongify(self)
        newCaller.backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

        [self setChannelName:channelName
                   meetingId:meetingId
                 meetingName:meetingName
                isLiveStream:isLiveStream
                  isSchedule:isSchedule
                         eid:eid
                      byUUID:uuidString];
        [self setMode:mode byUUID:uuidString];
        [self setEncryptMeetingKey:emkString byUUID:uuidString];
        [self setMeetingVersionKey:meetingVersion byUUID:uuidString];
        [self setCallerAccount:callerAccount byUUID:uuidString];
        [self setCalling:calling uuid:uuidString];

        WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
        caller.systemState = CKCallSystemStateReported;

        OWSLogInfo(@"%@ didReceiveCall data ready: callerMapCount=%lu", self.logTag, self.callerMap.count);

        if (completion) { completion(); }

        if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
            [self.delegate refreshCurrentCallStatus:CallStatusNone uuidString:uuidString];
        }

        [self startTimeoutTimerForUUID:uuidString];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[DTMeetingManager shared] startCallTimeoutTimer];
        });
    };

    if (preReportedUUID) {
        // 已由 handleVoipCallNotify 预先 report
        [_provider reportCallWithUUID:uuid updated:callUpdate];
        onReportSuccess();
    } else {
        [_provider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError * _Nullable error) {
            @strongify(self)
            if (!error) {
                onReportSuccess();
                return;
            }

            OWSLogError(@"%@ reportNewIncomingCall failed: %@ (code=%ld, domain=%@)",
                        self.logTag, error.localizedDescription, (long)error.code, error.domain);
            if (completion) { completion(); }

            if (calling && [self getActiveCallsCountFromCallerMap] > 0) {
                OWSLogWarn(@"%@ report rejected with active call, forwarding to in-app UI", self.logTag);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[DTMeetingManager shared] handleIncomingCallRejectedByCallKit:calling];
                });
            }

            [self resetVariableData:uuidString];
        }];
    }
}

#pragma mark - Start Call

- (void)starCall:(NSString *)callerId {
    if (!callerId || callerId.length == 0) {
        OWSLogError(@"%@ starCall - invalid callerId", self.logTag);
        if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
            [self.delegate refreshCurrentCallStatus:CallStatusBuildCallerFail uuidString:nil];
        }
        return;
    }

    NSUInteger activeCallCount = [self getActiveCallsCountFromCallerMap];
    OWSLogInfo(@"%@ starCall - current active calls: %lu", self.logTag, activeCallCount);

    NSUUID *uuid = [NSUUID UUID];
    NSString *uuidString = uuid.UUIDString;

    WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
    newCaller.uuid = uuid;
    newCaller.callerAccount = callerId;

    [self.callerMapLock lock];
    [self.callerMap setObject:newCaller forKey:uuidString];
    [self.callerMapLock unlock];

    CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:callerId];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:handle];
    startCallAction.video = NO;
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:startCallAction];

    [DTRTCAudioSession.shared callkitStartCall:NO];

    __weak __typeof(self) wself = self;
    [_callController requestTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error != nil) {
            [wself resetVariableData:uuidString];
        }
    }];
}

#pragma mark - Answer Call

- (void)answerCallAction:(NSString *)uuidString {
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    NSUUID *currentUUID = caller.uuid;
    if (currentUUID == nil) {
        OWSLogWarn(@"%@ answerCallAction - failed:%@", self.logTag, uuidString);
        return;
    }
    if (caller.answered) {
        OWSLogWarn(@"%@ answerCallAction From callkit:%@", self.logTag, uuidString);
        return;
    }
    OWSLogInfo(@"%@ answerCallAction - success", self.logTag);
    [self setAnswerState:YES byUUID:uuidString];
    CXAnswerCallAction *answerCallAction = [[CXAnswerCallAction alloc] initWithCallUUID:currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:answerCallAction];
    [_callController requestTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error == nil) {
            caller.isAccepted = YES;
            OWSLogInfo(@"%@ CXAnswerCallAction - success", self.logTag);
        } else {
            OWSLogError(@"%@ CXAnswerCallAction - failed", self.logTag);
        }
    }];
}

#pragma mark - Mute Call

- (void)muteCurrentCall:(BOOL)isMute uuidString:(NSString *)uuidString
{
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    NSUUID *currentUUID = caller.uuid;
    if (currentUUID == nil) {
        OWSLogError(@"%@ currentUUID == nil", self.logTag);
        return;
    }
    if (!caller.isAccepted) {
        OWSLogError(@"%@ call not accepted yet", self.logTag);
        return;
    }
    if (caller.isMutedByApp) {
        OWSLogError(@"%@ isMutedByApp == YES", self.logTag);
        return;
    }
    caller.isMutedByApp = YES;
    OWSLogInfo(@"%@ muteCurrentCall", self.logTag);
    CXSetMutedCallAction *muteCallAction = [[CXSetMutedCallAction alloc] initWithCallUUID:currentUUID muted:isMute];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:muteCallAction];
    [_callController requestTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error == nil) {
            OWSLogInfo(@"%@ CXSetMutedCallAction - success isMute=%d", self.logTag, isMute);
        } else {
            OWSLogError(@"%@ CXSetMutedCallAction - failed isMute=%d", self.logTag, isMute);
        }
    }];
}

- (nullable NSNumber *)callKitMuteIntentForUUID:(NSString *)uuidString
{
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    BOOL callerExists = caller != nil;
    BOOL hasIntent = caller.hasCallKitMuteIntent;
    BOOL isMuted = caller.isMuted;
    [self.callerMapLock unlock];

    if (!callerExists || !hasIntent) { return nil; }
    return @(isMuted);
}

#pragma mark - End Call

- (void)endCallAction:(NSString *)uuidString onlyForCallKit:(BOOL)onlyForCallKit
{
    if (onlyForCallKit) {
        [self removeCallKitUIOnly:uuidString];
        return;
    }
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    NSUUID *currentUUID = caller.uuid;
    OWSLogInfo(@"%@ endCallAction uuid: %@", self.logTag, uuidString);
    if (currentUUID == nil) {
        OWSLogWarn(@"%@ error: no currentUUID", self.logTag);
        return;
    }
    CXCall *currentCall = [self findCallByUUID:currentUUID];
    if (currentCall == nil) {
        OWSLogWarn(@"%@ error: no currentCall", self.logTag);
        return;
    }
    if (caller.hungup) {
        OWSLogWarn(@"%@ hungup, no need to report to callkit", self.logTag);
        return;
    }
    OWSLogInfo(@"%@ end call UUID: %@", self.logTag, currentUUID.UUIDString);
    [self setHungupState:YES byUUID:uuidString];
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:endCallAction];
    [_callController requestTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error) {
            OWSLogError(@"%@ endcall complete error:%@", self.logTag, error);
        } else {
            OWSLogInfo(@"%@ end complete", self.logTag);
        }
    }];
    DSKProtoCallMessageCalling *calling = [self callingFromUUID:uuidString];
    DispatchMainThreadSafe(^{
        if (!CurrentAppContext().isMainAppAndActive && !calling) {
            OWSLogInfo(@"%@ oldcall rtm logout", self.logTag);
        }
    });
}

#pragma mark - Outgoing Call State

- (void)startedConnectingOutgoingCall:(NSString *)uuidString {
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    if (caller.uuid == nil) return;
    [_provider reportOutgoingCallWithUUID:caller.uuid startedConnectingAtDate:nil];
}

- (void)connectedOutgoingCall:(NSString *)uuidString {
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    if (caller.uuid == nil) return;
    [_provider reportOutgoingCallWithUUID:caller.uuid connectedAtDate:nil];
}

#pragma mark - Pending Answer Action (delayed fulfill)

- (void)fulfillPendingAnswerAction:(NSString *)uuidString {
    [self resolvePendingAnswerActionForUUID:uuidString fulfilled:YES];
}

/// Resolve a held CXAnswerCallAction exactly once: fulfill on connect success, fail
/// when the call is torn down before it connected. Idempotent and thread-safe; a
/// no-op when nothing is being held (caller side / non-CallKit answer / already resolved).
- (void)resolvePendingAnswerActionForUUID:(NSString *)uuidString fulfilled:(BOOL)fulfilled {
    if (uuidString.length == 0) { return; }

    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    CXAnswerCallAction *action = caller.pendingAnswerAction;
    NSString *callerAccount = [caller.callerAccount copy];
    caller.pendingAnswerAction = nil;
    [self.callerMapLock unlock];

    if (!action) { return; }

    if (fulfilled) {
        OWSLogInfo(@"%@ fulfilling held answer action (connected), uuid: %@", self.logTag, uuidString);
        TTCallKitRemoveCriticalNotifications(@"before fulfill answer", uuidString, callerAccount);
        [action fulfill];
    } else {
        OWSLogInfo(@"%@ failing held answer action (torn down before connect), uuid: %@", self.logTag, uuidString);
        [action fail];
    }
}

/// End a call that was answered via CallKit but never finished connecting. Fails the
/// held answer action, dismisses the system UI, and tears down the in-flight LiveKit
/// connect via the normal end path. Idempotent. Only reached when CallKit times out
/// its own held answer action; the normal connect-failure give-up goes through the
/// app's connection-phase timeout + caller teardown, which resolves the held action.
- (void)endHeldAnswerConnectForUUID:(NSString *)uuidString reason:(NSString *)reason {
    if (uuidString.length == 0) { return; }

    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    // Guard on pendingAnswerAction: a fast .connected may have already resolved
    // (fulfilled) the action, so bail rather than tearing down a live call.
    // Read pendingAnswerAction under the lock: this method runs on callKitQueue()
    // (via provider:timedOutPerformingAction:), concurrently with
    // resolvePendingAnswerActionForUUID: nil-ing the same nonatomic strong property
    // from the main queue — an unguarded read here would be a data race.
    [self.callerMapLock lock];
    BOOL hasPendingAnswerAction = caller.pendingAnswerAction != nil;
    [self.callerMapLock unlock];
    if (!caller || caller.isEnded || !hasPendingAnswerAction) {
        // Already resolved/torn down elsewhere (or never held); nothing to end.
        [self resolvePendingAnswerActionForUUID:uuidString fulfilled:NO];
        return;
    }
    OWSLogError(@"%@ ending held answer before connect, reason=%@ uuid=%@", self.logTag, reason, uuidString);
    caller.isEnded = YES;
    caller.hungup = YES;
    caller.systemState = CKCallSystemStateRemoved;
    NSUUID *currentUUID = caller.uuid;

    // Fail the held answer action (resolves the outstanding CXAction), then report the
    // call ended so the system UI is dismissed even if failing alone didn't remove it.
    [self resolvePendingAnswerActionForUUID:uuidString fulfilled:NO];
    if (currentUUID) {
        [_provider reportCallWithUUID:currentUUID endedAtDate:nil reason:CXCallEndedReasonFailed];
    }

    // Tear down the in-flight LiveKit connect + app state via the normal end handling.
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusEnd uuidString:uuidString];
    }
    [self finalizeCallerCleanupForUUID:uuidString];
}

#pragma mark - CXCallObserverDelegate

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
    OWSLogInfo(@"%@ call state changed: isOutgoing=%d, hasConnected=%d, hasEnded=%d, callUUID=%@", self.logTag,
               call.isOutgoing, call.hasConnected, call.hasEnded, call.UUID.UUIDString);
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(CXProvider *)provider {
    if (provider != self.provider) {
        OWSLogInfo(@"%@ providerDidReset from old provider - skipping", self.logTag);
        return;
    }
    OWSLogInfo(@"%@ providerDidReset - cleaning up all state", self.logTag);

    [self stopAllTimeoutTimers];

    [self.callerMapLock lock];
    NSArray *allUUIDs = [self.callerMap.allKeys copy];
    for (NSString *uuidString in allUUIDs) {
        WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
        caller.backgroundTask = nil;
        // Provider is gone; drop the held action reference (do not fulfill/fail — the
        // action is already invalid) so it doesn't outlive the reset.
        caller.pendingAnswerAction = nil;
        [self.callerMap removeObjectForKey:uuidString];
    }
    [self.callerMapLock unlock];

    // Clear stale CallKit UUID to prevent operating on invalidated calls.
    // Do NOT disconnect LiveKit — media connections are independent of CallKit.
    // Re-sync server calls to recover JoinBar if needed.
    dispatch_async(dispatch_get_main_queue(), ^{
        [DTMeetingManager shared].currentCall.callKitUUID = nil;
        [[DTMeetingManager shared] syncServerCalls];
    });
    OWSLogInfo(@"%@ providerDidReset completed", self.logTag);
}

- (void)providerDidBegin:(CXProvider *)provider
{
    OWSLogInfo(@"%@ provider begin", self.logTag);
}

- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction
{
    OWSLogInfo(@"%@ executeTransaction", self.logTag);
    return NO;
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    OWSLogInfo(@"%@ performStartCallAction - uuid: %@", self.logTag, uuidString);
    [DTRTCAudioSession.shared callkitHandleCall:NO];
    [self startedConnectingOutgoingCall:uuidString];
    [action fulfill];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusReadyStart uuidString:uuidString];
    }
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    OWSLogInfo(@"%@ performAnswerCallAction uuid=%@", self.logTag, uuidString);
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    NSString *callerAccount = [caller.callerAccount copy];
    [self.callerMapLock unlock];
    if (!caller) {
        OWSLogError(@"%@ performAnswerCallAction caller not found", self.logTag);
        [action fulfill];
        return;
    }
    caller.isAccepted = YES;
    caller.answered = YES;
    TTCallKitRemoveCriticalNotifications(@"answer action", uuidString, callerAccount);
    [DTRTCAudioSession.shared callkitHandleCall:YES];
    [self stopTimeoutTimerForUUID:uuidString];

    // Do NOT fulfill yet. Hold the answer action so the system call UI stays in the
    // "Connecting…" state until LiveKit actually connects; -fulfillPendingAnswerAction:
    // (driven by the .connected lifecycle transition) resolves it. Principle: connect →
    // answered, can't connect → cancelled. If the room never connects, the app's own
    // connection-phase timeout ends the call and the caller teardown resolves the held
    // action (fail), so we never present a fake connected state.
    [self.callerMapLock lock];
    caller.pendingAnswerAction = action;
    [self.callerMapLock unlock];

    OWSLogInfo(@"%@ answer held (not fulfilled), waiting for room connect, uuid=%@", self.logTag, uuidString);

    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusAccept uuidString:uuidString];
    }
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    OWSLogInfo(@"%@ performEndCallAction uuid=%@", self.logTag, uuidString);

    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];

    if (!caller) {
        [action fulfill];
        return;
    }
    if (caller.isEnded) {
        OWSLogInfo(@"%@ performEndCallAction already handled, cleanup only uuid=%@", self.logTag, uuidString);
        [self finalizeCallerCleanupForUUID:uuidString];
        [action fulfill];
        return;
    }
    caller.isEnded = YES;
    caller.hungup = YES;
    caller.systemState = CKCallSystemStateRemoved;
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusEnd uuidString:uuidString];
    }
    [self finalizeCallerCleanupForUUID:uuidString];
    [action fulfill];
    OWSLogInfo(@"%@ performEndCallAction done: uuid=%@, remaining=%lu", self.logTag, uuidString, [self getActiveCallsCount]);
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    OWSLogInfo(@"%@ performSetMutedCallAction - muted: %d", self.logTag, action.muted);
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    if (!caller || caller.isEnded) {
        [action fulfill];
        return;
    }
    [action fulfill];
    if (caller.isMutedByApp) {
        caller.isMutedByApp = NO;
        return;
    }
    caller.hasCallKitMuteIntent = YES;
    caller.isMuted = action.muted;
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallMuteState:uuidString:)]) {
        [self.delegate refreshCurrentCallMuteState:action.muted uuidString:uuidString];
    }
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    OWSLogInfo(@"%@ timedOutPerformingAction - action: %@", self.logTag, action);
    if ([action isKindOfClass:[CXSetMutedCallAction class]]) {
        CXSetMutedCallAction *muteAction = (CXSetMutedCallAction *)action;
        NSString *uuidString = muteAction.callUUID.UUIDString;
        if (![self hasCallWithUUID:uuidString]) {
            OWSLogInfo(@"%@ Ignoring timeout for ended call: %@", self.logTag, uuidString);
            [action fulfill];
            return;
        }
    }
    if ([action isKindOfClass:[CXAnswerCallAction class]]) {
        // CallKit timed out our held answer action. Principle: never show in-call
        // unless connected — end the call (which fails this action) instead of
        // fulfilling into a fake connected state.
        NSString *uuidString = ((CXAnswerCallAction *)action).callUUID.UUIDString;
        OWSLogError(@"%@ answer action timed out (CallKit) before connect, ending call, uuid: %@", self.logTag, uuidString);
        [self endHeldAnswerConnectForUUID:uuidString reason:@"callkit-action-timeout"];
        return;
    }
    OWSLogWarn(@"%@ CallKit action timed out, fulfilling: %@", self.logTag, action);
    [action fulfill];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    OWSLogInfo(@"%@ didActivateAudioSession", self.logTag);

    // Find the most recently accepted, non-ended caller for audio routing (D1 fix)
    [self.callerMapLock lock];
    NSArray<WeaCallKitCaller *> *snapshot = [self.callerMap.allValues copy];
    [self.callerMapLock unlock];

    BOOL isPrivate = NO;
    WeaCallKitCaller *activeCaller = nil;
    for (WeaCallKitCaller *caller in snapshot) {
        if (caller.isAccepted && !caller.isEnded) {
            activeCaller = caller;
        }
    }
    if (activeCaller) {
        isPrivate = activeCaller.isPrivateCall;
    }

    BOOL speaker = [DTRTCAudioSession.shared shouldUseSpeaker:!isPrivate];
    [DTRTCAudioSession.shared callkitDidActivateAudioSession:audioSession speaker:speaker];
    [[DTMeetingManager shared] callKitAudioSessionDidActivate];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    OWSLogInfo(@"%@ didDeactivateAudioSession", self.logTag);
    [DTRTCAudioSession.shared callkitDidDeactivateAudioSession:audioSession];
}

#pragma mark - Private

/// Shared local-state teardown for a caller: stop its timeout timer, drop it
/// from the callerMap, and restore the audio route when no active call remains.
/// Intentionally excludes UI dismissal (reportCallWithUUID:) and the
/// refreshCurrentCallStatus: delegate hop — callers decide those per semantics.
- (void)finalizeCallerCleanupForUUID:(NSString *)uuidString {
    [self stopTimeoutTimerForUUID:uuidString];
    [self resetVariableData:uuidString];
    if ([self getActiveCallsCountFromCallerMap] == 0) {
        [DTRTCAudioSession.shared callkitHandleCall:NO];
    }
}

/// Remove only the system CallKit UI for a placeholder/stale incoming call.
/// Reports the call ended to CXProvider (idempotent, no-op if system no longer
/// tracks it) WITHOUT issuing a CXEndCallAction, so performEndCallAction —
/// and therefore handleCallKitEnd's reject path — is never triggered.
- (void)removeCallKitUIOnly:(NSString *)uuidString {
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    if (caller == nil) {
        [self.callerMapLock unlock];
        OWSLogInfo(@"%@ removeCallKitUIOnly - no caller for uuid: %@", self.logTag, uuidString);
        return;
    }
    if (caller.uuid == nil) {
        [self.callerMapLock unlock];
        OWSLogWarn(@"%@ removeCallKitUIOnly - caller has no uuid: %@", self.logTag, uuidString);
        return;
    }
    if (caller.isEnded) {
        [self.callerMapLock unlock];
        OWSLogInfo(@"%@ removeCallKitUIOnly - already ended, cleanup only: %@", self.logTag, uuidString);
        [self finalizeCallerCleanupForUUID:uuidString];
        return;
    }
    caller.isEnded = YES;
    caller.hungup = YES;
    caller.systemState = CKCallSystemStateRemoved;
    NSUUID *currentUUID = caller.uuid;
    [self.callerMapLock unlock];

    [_provider reportCallWithUUID:currentUUID endedAtDate:nil reason:CXCallEndedReasonRemoteEnded];
    [self finalizeCallerCleanupForUUID:uuidString];
    OWSLogInfo(@"%@ removed callkit UI uuid: %@", self.logTag, currentUUID.UUIDString);
}

- (void)resetVariableData:(NSString *)uuidString {
    if (uuidString) {
        // Always stop the timeout timer when cleaning up a caller (F3 fix)
        [self stopTimeoutTimerForUUID:uuidString];

        // Resolve any held answer action so we never leak an un-fulfilled CXAction when
        // the caller is torn down before the room connected. No-op if already fulfilled.
        [self resolvePendingAnswerActionForUUID:uuidString fulfilled:NO];

        [self.callerMapLock lock];
        WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
        caller.backgroundTask = nil;
        [self.callerMap removeObjectForKey:uuidString];
        [self.callerMapLock unlock];
    }
}

- (void)recreateProvider {
    // Clean stale callerMap entries before recreating (C2 fix)
    // Old provider's calls won't be findable after invalidation
    [self.callerMapLock lock];
    NSMutableArray *staleKeys = [NSMutableArray array];
    for (NSString *key in self.callerMap) {
        WeaCallKitCaller *caller = [self.callerMap objectForKey:key];
        if (caller.isEnded) {
            [staleKeys addObject:key];
        }
    }
    if (staleKeys.count > 0) {
        for (NSString *key in staleKeys) {
            WeaCallKitCaller *caller = [self.callerMap objectForKey:key];
            caller.backgroundTask = nil;
            [self.callerMap removeObjectForKey:key];
        }
        OWSLogInfo(@"%@ cleaned %lu stale callerMap entries before provider recreate", self.logTag, staleKeys.count);
    }
    [self.callerMapLock unlock];

    CXProvider *oldProvider = self.provider;
    CXProvider *newProvider = [[CXProvider alloc] initWithConfiguration:self.configuration];
    [newProvider setDelegate:self queue:callKitQueue()];
    self.provider = newProvider;
    [oldProvider invalidate];
    OWSLogInfo(@"%@ CXProvider recreated to refresh XPC connection", self.logTag);
}

#pragma mark - Configuration

- (CXProviderConfiguration *)configuration
{
    if (!_configuration) {
        _configuration = [[CXProviderConfiguration alloc] init];
        _configuration.supportedHandleTypes = [[NSSet alloc] initWithObjects:@(CXHandleTypeGeneric), nil];
        UIImage *iconMaskImage = [UIImage imageNamed:@"callKit_icon"];
        _configuration.iconTemplateImageData = UIImagePNGRepresentation(iconMaskImage);
        _configuration.ringtoneSound = @"calling.caf";
        _configuration.maximumCallGroups = 1;
        _configuration.supportsVideo = YES;
    }
    return _configuration;
}

- (CXCallController *)callController
{
    if (!_callController) {
        _callController = [[CXCallController alloc] init];
    }
    return _callController;
}

- (nullable CXCall *)findCallByUUID:(NSUUID *)uuid {
    for (CXCall *call in _callController.callObserver.calls) {
        if ([call.UUID.UUIDString isEqualToString:uuid.UUIDString]) {
            return call;
        }
    }
    return nil;
}

#pragma mark - VoIP Push

- (void)handleVoipCallNotify:(NSDictionary *)apnsInfo completion:(void (^__nullable)(void))completion {

    OWSLogInfo(@"========>CallKit: apnsInfo:%@", apnsInfo);
    if ([self getActiveCallsCountFromCallerMap] == 0) {
        [self recreateProvider];
    }

    @weakify(self)
    [self reportPlaceholderIncomingCallWithCompletion:^(NSUUID *uuid, BOOL succeeded) {
        @strongify(self)
        if (!self) { return; }
        if (!succeeded) {
            OWSLogWarn(@"%@ placeholder report failed, falling back to non-placeholder flow", DTCallKitManager.logTag);
        }
        NSUUID *placeholderUUID = succeeded ? uuid : nil;
        dispatch_async(callKitQueue(), ^{
            [self processVoipPushWithInfo:apnsInfo
                          placeholderUUID:placeholderUUID
                               completion:completion];
        });
    }];
}

- (void)processVoipPushWithInfo:(NSDictionary *)apnsInfo
                placeholderUUID:(NSUUID *)placeholderUUID
                     completion:(void (^__nullable)(void))completion {
    NSDictionary *callInfo = apnsInfo[@"callInfo"];
    NSString *encMsg = apnsInfo[@"msg"];

    if (DTParamsUtils.validateDictionary(callInfo)) {
        NSString *channelName = callInfo[@"channelName"];
        if (!channelName || !channelName.length) {
            OWSLogError(@"========>CallKit: channelName invalid, ending placeholder");
            [self endPlaceholderCall:placeholderUUID completion:completion];
            return;
        }

        NSString *caller = callInfo[@"caller"];
        NSString *callerRecipientId = [caller transforUserAccountToCallNumber];

        NSString *mode = callInfo[@"mode"];
        caller = caller ?: callInfo[@"host"];
        NSString *meetingId = callInfo[@"meetingId"];
        NSString *meetingName = callInfo[@"meetingName"];
        NSNumber *number_startAt = callInfo[@"startAt"];
        NSNumber *number_isLiveStream = callInfo[@"isLiveStream"];
        NSString *eid = callInfo[@"eid"];
        NSString *name = apnsInfo[@"callerName"];
        if (DTParamsUtils.validateString(name)) {
            name = [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerRecipientId];
        }

        OWSLogDebug(@"%@ startAt: %@", self.logTag, number_startAt);

        if (number_startAt) {
            NSTimeInterval startAt = [number_startAt doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

            if (now - startAt > 70) {
                OWSLogWarn(@"========>CallKit: unexpected voip: %.0f", startAt);
                [self endPlaceholderCall:placeholderUUID completion:completion];
                return;
            }
        }

        BOOL isSchedule = [callInfo[@"type"] isEqualToString:@"meeting-popups"];
        BOOL isLiveStream = NO;
        if (number_isLiveStream) {
            isLiveStream = [number_isLiveStream boolValue];
        }

        NSString *emkString = callInfo[@"emk"];
        NSNumber *meetingVersion = callInfo[@"meetingVersion"];

        [self didReceiveCall:name
               callerAccount:caller
                 channelName:channelName
                   meetingId:meetingId
                 meetingName:meetingName
                        mode:mode
                         emk:emkString
              meetingVersion:meetingVersion
                  isSchedule:isSchedule
                isLiveStream:isLiveStream
                         eid:eid
              liveKitCalling:nil
             preReportedUUID:placeholderUUID
                  completion:completion];
    } else if (DTParamsUtils.validateString(encMsg)) {
        DSKProtoCallMessageCalling *calling = [self decryptMsg:encMsg];
        if (!calling) {
            [self endPlaceholderCall:placeholderUUID completion:completion];
        } else {
            // Apply startAt filter for encrypted path too (G2 fix)
            if ([calling hasTimestamp]) {
                NSTimeInterval startAt = (NSTimeInterval)[calling timestamp] / 1000.0;
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                if (now - startAt > 70) {
                    OWSLogWarn(@"========>CallKit: encrypted call expired: %.0fs ago", now - startAt);
                    [self endPlaceholderCall:placeholderUUID completion:completion];
                    return;
                }
            }

            NSString *roomId = calling.roomID;
            if (DTParamsUtils.validateString(roomId)) {
                [self didReceiveCall:nil
                       callerAccount:calling.caller
                         channelName:nil
                           meetingId:calling.roomID
                         meetingName:calling.roomName
                                mode:nil
                                 emk:nil
                      meetingVersion:@10
                          isSchedule:NO
                        isLiveStream:NO
                                 eid:nil
                      liveKitCalling:calling
                     preReportedUUID:placeholderUUID
                          completion:completion];
            } else {
                OWSLogError(@"========>CallKit: roomId invalid, ending placeholder");
                [self endPlaceholderCall:placeholderUUID completion:completion];
            }
        }
    } else {
        OWSLogInfo(@"========>CallKit: callInfo/msg empty, ending placeholder");
        [self endPlaceholderCall:placeholderUUID completion:completion];
    }
}

#pragma mark - LiveKit Call Check

- (BOOL)isLiveKitCall:(CXSetMutedCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    DSKProtoCallMessageCalling *calling = [self callingFromUUID:uuidString];
    return calling != nil;
}

@end
