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

static dispatch_queue_t callKitQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.temptalk.callkit.call", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

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
        OWSLogInfo(@"[CALLKIT_DEBUG] didReceiveCall - already %lu active calls, rejecting", activeCount);
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

    OWSLogInfo(@"[CALLKIT_DEBUG] didReceiveCall - processing call, current callerMap count: %lu, keys: %@",
               self.callerMap.count, [self.callerMap allKeys]);

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
            resolvedName = [DTGroupCryptoDisplayHelper.shared resolveGroupDisplayNameWithServerGroupId:serverGid
                                                                                          fallbackName:meetingName
                                                                                           transaction:transaction];
        }];
        nameForDisplay = resolvedName;
        if (!DTParamsUtils.validateString(nameForDisplay)) {
            nameForDisplay = meetingName;
        }
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

        OWSLogInfo(@"[CALLKIT_DEBUG] didReceiveCall - call data set, callerMap.count: %lu",
                   self.callerMap.count);

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

            OWSLogError(@"[CALLKIT_DEBUG] didReceiveCall - reportNewIncomingCall error: %@ (code: %ld, domain: %@)",
                        error.localizedDescription, (long)error.code, error.domain);
            if (completion) { completion(); }

            if (calling && [self getActiveCallsCountFromCallerMap] > 0) {
                OWSLogWarn(@"[CALLKIT_DEBUG] didReceiveCall - report rejected with active call, forwarding to in-app UI");
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

#pragma mark - End Call

- (void)endCallAction:(NSString *)uuidString onlyForCallKit:(BOOL)onlyForCallKit
{
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
    OWSLogInfo(@"[CALLKIT_DEBUG] providerDidReset completed");
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
    OWSLogInfo(@"[CALLKIT_DEBUG] performAnswerCallAction - UUID: %@", uuidString);
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    if (!caller) {
        OWSLogError(@"[CALLKIT_DEBUG] performAnswerCallAction - caller not found");
        [action fulfill];
        return;
    }
    caller.isAccepted = YES;
    caller.answered = YES;
    [DTRTCAudioSession.shared callkitHandleCall:YES];
    [self stopTimeoutTimerForUUID:uuidString];
    [action fulfill];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusAccept uuidString:uuidString];
    }
    OWSLogInfo(@"[CALLKIT_DEBUG] performAnswerCallAction - done, uuid: %@", uuidString);
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    NSString *uuidString = action.callUUID.UUIDString;
    OWSLogInfo(@"[CALLKIT_DEBUG] performEndCallAction - UUID: %@", uuidString);

    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];

    if (!caller) {
        [action fulfill];
        return;
    }
    if (caller.isEnded) {
        OWSLogInfo(@"[CALLKIT_DEBUG] performEndCallAction - already handled for %@, cleanup only", uuidString);
        [self stopTimeoutTimerForUUID:uuidString];
        [self resetVariableData:uuidString];
        NSUInteger activeCallCount = [self getActiveCallsCountFromCallerMap];
        if (activeCallCount == 0) {
            [DTRTCAudioSession.shared callkitHandleCall:NO];
        }
        [action fulfill];
        return;
    }
    caller.isEnded = YES;
    caller.hungup = YES;
    caller.systemState = CKCallSystemStateRemoved;
    [self stopTimeoutTimerForUUID:uuidString];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:uuidString:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatusEnd uuidString:uuidString];
    }
    [self resetVariableData:uuidString];
    NSUInteger activeCallCount = [self getActiveCallsCountFromCallerMap];
    if (activeCallCount == 0) {
        [DTRTCAudioSession.shared callkitHandleCall:NO];
    }
    [action fulfill];
    OWSLogInfo(@"[CALLKIT_DEBUG] performEndCallAction - done, uuid: %@, remaining: %lu", uuidString, [self getActiveCallsCount]);
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
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    OWSLogInfo(@"%@ didDeactivateAudioSession", self.logTag);
    [DTRTCAudioSession.shared callkitDidDeactivateAudioSession:audioSession];
}

#pragma mark - Private

- (void)resetVariableData:(NSString *)uuidString {
    if (uuidString) {
        // Always stop the timeout timer when cleaning up a caller (F3 fix)
        [self stopTimeoutTimerForUUID:uuidString];

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
