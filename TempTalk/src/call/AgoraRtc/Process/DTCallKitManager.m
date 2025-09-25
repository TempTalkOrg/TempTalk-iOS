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
#import "TempTalk-Swift.h"
#import <LiveKitWebRTC/LiveKitWebRTC.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#define TTCallQueue  dispatch_queue_create("TT_CallKit_Queue", 0)

@interface DTCallKitManager () <CXCallObserverDelegate, CXProviderDelegate>

@property (nonatomic, strong) CXProvider *provider;
@property (nonatomic, strong) CXCallUpdate *callUpdate;
@property (nonatomic, strong) CXProviderConfiguration *configuration;
@property (nonatomic, strong) CXCallController *callController;

@property (nonatomic, assign) BOOL haveAcceptCall;
@property (nonatomic, assign) BOOL isMutedByApp;
@property (nonatomic, strong) NSMutableDictionary *callerMap;
@property (nonatomic, strong) NSString *currentChannelName;

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
        
        self.provider = [[CXProvider alloc] initWithConfiguration:self.configuration];
        [_provider setDelegate:self queue:nil];
        [self.callController.callObserver setDelegate:self queue:TTCallQueue];
        self.callerMap = [[NSMutableDictionary alloc] init];
        self.isLocalEndCall = false;
    }
    return self;
}

- (NSUInteger)callsCount {
    return _callController.callObserver.calls.count;
}

- (void)reportFakeCallCompletion:(void (^__nullable)(void))completion{
    @weakify(self)
    NSUUID *uuid = [NSUUID UUID];
    [_provider reportNewIncomingCallWithUUID:uuid update:[CXCallUpdate new] completion:^(NSError * _Nullable error) {
        @strongify(self)
        completion();
        [self.provider reportCallWithUUID:uuid endedAtDate:nil reason:CXCallEndedReasonFailed];
    }];
}

#pragma mark - 收到呼叫
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
            completion:(void (^)(void))completion
{
    NSString *callerID = [callerAccount transforUserAccountToCallNumber];
    
    if (calling) {
        OWSLogInfo(@"%@ mode:%@ didReceiveCall has calling", self.logTag, mode);
    } else {
        OWSLogInfo(@"%@ no calling", self.logTag);
    }
    // 一个周期内，重复的来电，不响应。
    if (self.callerMap.allValues.count > 0) {
        OWSLogError(@"%@ callerMap is not empty = %@", self.logTag, self.callerMap);
        
        completion();
        return;
    }
    if ([self.callerMap objectForKey:callerID] != nil) {
        OWSLogError(@"%@ callerMap has the same caller = %@", self.logTag, self.callerMap);
        
        completion();
    } else {

        NSUUID *uuid = [NSUUID UUID];
        [self setUUID:uuid byCallerID:callerID];
        [self setChannelName:channelName
                   meetingId:meetingId
                 meetingName:meetingName
                isLiveStream:isLiveStream
                  isSchedule:isSchedule
                         eid:eid
                  byCallerID:callerID];
        [self setMode:mode byCallerID:callerID];
        [self setEncryptMeetingKey:emkString byCallerID:callerID];
        [self setMeetingVersionKey:meetingVersion byCallerID:callerID];
        [self setCallerAccount:callerAccount byCallerID:callerID];
        
        BOOL isLiveKitCall = NO;
        if (calling) {
            isLiveKitCall = YES;
            [self setCalling:calling callerId:callerID];
        }

        //MARK: 群呼不允许回拨
        NSString *value = callerID;
        NSString *nameForDisplay = nil;
        if (isLiveKitCall) {
            // 如果是群会或instant会议, value == @"unknown"
            value = [callerID stringByAppendingFormat:@".%@", meetingVersion];
            if (!DTParamsUtils.validateString(calling.conversationID.number) && !calling.conversationID.groupID) {
                nameForDisplay = [NSString stringWithFormat:@"%@'s instant call", [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerID]];
            } else {
                if (DTParamsUtils.validateString(calling.conversationID.number)) {
                    nameForDisplay = [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerAccount];
                } else if (calling.conversationID.groupID) {
                    NSData *groupId = calling.conversationID.groupID;
                    TSGroupThread *groupThread = [TSGroupThread getThreadWithGroupId:groupId];
                    nameForDisplay = [groupThread nameWithTransaction:nil];
                    if (!DTParamsUtils.validateString(nameForDisplay)) {
                        nameForDisplay = meetingName;
                    }
                }
            }
            if (!DTParamsUtils.validateString(nameForDisplay)) {
                nameForDisplay = @"Call";
            }
        } else {
            BOOL isGroupCall = [mode isEqualToString:DTCallModeGroup];
            value = isGroupCall ? @"unknown" : callerID;
            if (isGroupCall) {
                nameForDisplay = meetingName ?: [DTCallManager defaultMeetingName];
            } else {
                NSString *callerRecipientId = [callerAccount transforUserAccountToCallNumber];
                nameForDisplay = callerName ?: [Environment.shared.contactsManager displayNameForPhoneIdentifier:callerRecipientId];
            }
        }
        
        CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric
                                                    value:value];
        
        self.callUpdate.remoteHandle = handle;
        self.callUpdate.hasVideo = NO;

        self.callUpdate.localizedCallerName = nameForDisplay;
    
        [DTRTCAudioSession.shared callkitConfig];

        OWSLogInfo(@"%@ 准备展示系统 UI - %@ - %@", self.logTag, callerID, NSThread.currentThread);

        @weakify(self)
        [_provider reportNewIncomingCallWithUUID:uuid update:self.callUpdate completion:^(NSError * _Nullable error) {
            //Report completion to CallKit
            OWSLogInfo(@"%@ Report completion to CallKit - %@", self.logTag, callerID);
            
            @strongify(self)
            [self startTimeoutTimerWithCallerId:callerID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[DTMeetingManager shared] startCallTimeoutTimer];
            });

            OWSLogInfo(@"[call]========>CallKit: startCallTimeoutTimer");
            
            completion();
            if (error) {
                OWSLogError(@"[call]========>CallKit: Current error %@",error.userInfo);
                
                [self resetVariableData:callerID];
                //通话创建失败
                DispatchMainThreadSafe(^{
                    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
                        [self.delegate refreshCurrentCallStatus:CallStatus_BuildAnswerFail callerId:callerID];
                    }
                });
            }
        }];
    }
}

#pragma mark - 打电话
- (void)starCall:(NSString *)callerId {
    if (self.haveAcceptCall) {
        //已有正在进行中通话  busy
        if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
            [self.delegate refreshCurrentCallStatus:CallStatus_Busy callerId:callerId];
        }
        return;
    }
    
    //创建新会话
    NSUUID *uuid = [NSUUID UUID];
    [self setUUID:uuid byCallerID:callerId];
    
    CXHandle *handle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value: callerId];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:handle];
    startCallAction.video = NO;
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:startCallAction];

    [DTRTCAudioSession.shared callkitConfig];
    
    __weak __typeof(self) wself = self;
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error){
        if (error !=nil) {
            [wself resetVariableData:callerId];
            if (wself.delegate && [wself.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
                [wself.delegate refreshCurrentCallStatus:CallStatus_BuildCallerFail callerId:callerId];
            }
        }
    }];
}

#pragma mark - 接电话 (app内接通，同步到 callkit)
- (void)answerCallAction:(NSString *)callerId {
    // 不存在 CallKit 电话
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    if (currentUUID == nil) {
        
        OWSLogWarn(@"%@ answerCallAction - failed:%@", self.logTag, callerId);
        return;
    }
    
    // 来自 CallKit 的接听，不需要再通知 CallKit
    BOOL answerd = [self answerStateFromCallerID:callerId];
    if (answerd) {
        OWSLogWarn(@"%@ answerCallAction From callkit:%@", self.logTag, callerId);
        return;
    }
    
    OWSLogInfo(@"%@ answerCallAction - success", self.logTag);
    [self setAnswerState:YES byCallerID:callerId];
    CXAnswerCallAction *answerCallAction = [[CXAnswerCallAction alloc] initWithCallUUID: currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:answerCallAction];
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error){
        if (error == nil) {
            
            self.haveAcceptCall = YES;
            OWSLogInfo(@"%@ CXAnswerCallAction - success", self.logTag);
        } else {
            OWSLogError(@"%@ CXAnswerCallAction - failed", self.logTag);
        }
    }];
}

- (void)muteCurrentCall:(BOOL)isMute callerId:(NSString *)callerId
{
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    if (currentUUID == nil) {
        OWSLogError(@"%@ currentUUID == nil", self.logTag);
        return;
    }
    
    if (!self.haveAcceptCall) {
        OWSLogError(@"%@ haveAcceptCall == NO", self.logTag);
        return;
    }
    
    // 来自 CallKit 的 Mute，不需要再通知 CallKit
    if (self.isMutedByApp) {
        OWSLogError(@"%@ isMutedByApp == YES", self.logTag);
        return;
    }

    self.isMutedByApp = YES;
    OWSLogInfo(@"%@ muteCurrentCall", self.logTag);
    CXSetMutedCallAction *muteCallAction = [[CXSetMutedCallAction alloc] initWithCallUUID:currentUUID muted:isMute];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:muteCallAction];
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error){
        if (error == nil) {
            OWSLogInfo(@"%@ CXSetMutedCallAction - success isMute=%d", self.logTag, isMute);
        } else {
            OWSLogError(@"%@ CXSetMutedCallAction - failed isMute=%d", self.logTag, isMute);
        }
    }];
}

- (void)endCallAction:(NSString *)callerId
{
    // 不存在 CallKit 电话
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    
    OWSLogInfo(@"%@ callerId: %@, callMap: %@", self.logTag, callerId, self.callerMap);
    
    if (currentUUID == nil) {
        
        OWSLogWarn(@"%@ error: no currentUUID", self.logTag);
        return;
    }
    
    CXCall *cuttentCall = [self findCallByUUID:currentUUID];
    if (cuttentCall == nil) {
        OWSLogWarn(@"%@ error: no currentCall", self.logTag);
        return;
    }
    
    // 来自 CallKit 的挂断，不需要再通知 CallKit
    BOOL hungup = [self hungupStateFromCallerID:callerId];
    if (hungup) {
        OWSLogWarn(@"%@ hungup, no need to report to callkit", self.logTag);
        return;
    }
    
    OWSLogInfo(@"%@ end call UUid", self.logTag, currentUUID.UUIDString);
    
    [self setHungupState:YES byCallerID:callerId];
    self.isLocalEndCall = YES;
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:endCallAction];
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error) {
        if (error) {
            OWSLogError(@"%@ endcall complete error:%@", self.logTag, error);
        } else {
            OWSLogInfo(@"%@ end complete", self.logTag);
        }
    }];
    
    DSKProtoCallMessageCalling *calling = [self callingFromCallerId:callerId];
    DispatchMainThreadSafe(^{
        if (!CurrentAppContext().isMainAppAndActive && !calling) {
            OWSLogInfo(@"%@ oldcall rtm logout", self.logTag);
        }
    });
}

- (void)endCallActionWithCallerId:(NSString *)callerId
{
    OWSLogInfo(@"%@ callerid:%@", self.logTag, callerId);
    
    // 不存在 CallKit 电话
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    if (currentUUID == nil) {
        
        OWSLogError(@"%@ no currentUUID", self.logTag);
        return;
    }
    
    CXCall *cuttentCall = [self findCallByUUID:currentUUID];
    if (cuttentCall == nil) {
        OWSLogInfo(@"%@ no currentCall", self.logTag);
        return;
    }
    
    OWSLogInfo(@"%@ callerUUID:%@", self.logTag, currentUUID.UUIDString);
    
    [self setHungupState:YES byCallerID:callerId];
    self.isLocalEndCall = YES;
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:endCallAction];
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error) {
        if (error) {
            OWSLogError(@"%@ source:timeout error:%@", self.logTag, error);
        } else {
            OWSLogInfo(@"%@ source:timeout complete", self.logTag);
        }
    }];
    
    DSKProtoCallMessageCalling *calling = [self callingFromCallerId:callerId];
    if (!CurrentAppContext().isMainAppAndActive && !calling) {
        OWSLogInfo(@"%@ oldcall rtm logout", self.logTag);
    }
}

//开始连接
- (void)startedConnectingOutgoingCall:(NSString *)callerId
{
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    if (currentUUID == nil) {
        return;
    }
    [_provider reportOutgoingCallWithUUID:currentUUID startedConnectingAtDate:nil];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_StartConnect callerId:callerId];
    }
}

//通话连接成功 显示通话时间 作为拨打方
- (void)connectedOutgoingCall:(NSString *)callerId
{
    NSUUID *currentUUID = [self uuidFromCallerID:callerId];
    if (currentUUID == nil) {
        return;
    }
    [_provider reportOutgoingCallWithUUID:currentUUID connectedAtDate:nil];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_Connected callerId:callerId];
    }
}

#pragma mark - CXCallObserverDelegate
- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
    OWSLogInfo(@"%@ 通话状态变更: isOutgoing=%d, hasConnected=%d, hasEnded=%d, callUUid%@", self.logTag,
               call.isOutgoing, call.hasConnected, call.hasEnded, call.UUID.UUIDString);
}

#pragma mark - CXProviderDelegate
- (void)providerDidReset:(CXProvider *)provider
{
    OWSLogInfo(@"%@ resetedUUID:%ld", self.logTag, provider.pendingTransactions.count);
}

- (void)providerDidBegin:(CXProvider *)provider
{
    OWSLogInfo(@"%@ provider begin", self.logTag);
}


- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction
{
    //返回true 不执行系统通话界面 直接End
    OWSLogInfo(@"%@ executeTransaction", self.logTag);
    
    return NO;
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action
{
    //通话开始
    OWSLogInfo(@"%@ start call action uuid %@", self.logTag, action.callUUID.UUIDString);
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:callerId:)]) {
        NSString *callerID = [self callerIDFromUUID: action.callUUID];
        [self.delegate refreshCurrentCallStatus:CallStatus_ReadyStart callerId:callerID];
    }
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    OWSLogInfo(@"%@ provider--answer callUUid%@", self.logTag, action.callUUID.UUIDString);
    
    self.haveAcceptCall = YES;
    NSString *callerId = [self callerIDFromUUID: action.callUUID];
    DSKProtoCallMessageCalling *calling = [self callingFromCallerId:callerId];
    
    [self stopTimeroutTimer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DTMeetingManager shared] stopCallTimeoutTimer];
    });
    
    // 1on1 默认开麦, 不触发关麦操作
    BOOL is1on1Call = NO;
    DSKProtoConversationId *conversationID = calling.conversationID;
    if (conversationID.hasNumber) {
        is1on1Call = YES;
    }

    if (!is1on1Call) {
        self.isMutedByApp = NO;
        [self muteCurrentCall:YES callerId:callerId];
    }
    
    [action fulfill];

    [self acceptCallWithCalling:calling];
}

//拨打方挂断或被叫方拒绝接听 锁屏情况下接通通话到最后挂断
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    OWSLogInfo(@"%@ end call action 收到挂断指令 UUID: %@", self.logTag, action.callUUID.UUIDString);
    
    //结束通话
    self.haveAcceptCall = NO;

    NSString *callerId = [self callerIDFromUUID:action.callUUID];
    DSKProtoCallMessageCalling *calling = [self callingFromCallerId:callerId];
        
    [self stopTimeroutTimer];
    if (self.isLocalEndCall) {
        // 本地触发挂断 会议中的时候不再挂断
        if (!DTMeetingManager.shared.inMeeting) {
            [self hangupFromCallKit:calling.roomID];
            self.isLocalEndCall = false;
            OWSLogInfo(@"%@ local code trigger end call", self.logTag);
        }
    } else {
        // 系统UI触发,自己手动挂断的
        [self hangupFromCallKit:calling.roomID];
        OWSLogInfo(@"%@ system UI trigger end call", self.logTag);
    }
    
    [self resetVariableData:callerId];//通话结束
    [action fulfill]; //通话结束立即执行 时间也可以选
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action
{
    [action fulfill];
    //静音
    if (!self.isMutedByApp) {
        OWSLogInfo(@"%@ Notice app should mute - %d", self.logTag, action.muted);
        [self muteAudioFromCallKit:action.muted];
    } else {
        OWSLogInfo(@"%@ Mute action is from app", self.logTag);
    }
    self.isMutedByApp = NO;
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action
{
    //超时
    OWSLogInfo(@"%@ action:%@ timeOut", self.logTag, action);
//    [action fulfill];
}

/// Called when the provider's audio session activation state changes.
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
    //audio session 设置
    OWSLogInfo(@"%@ didActivateAudioSession", self.logTag);
    [DTRTCAudioSession.shared callkitDidActivateAudioSession:audioSession];
}
- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    //call end
    OWSLogInfo(@"%@ didDeactivateAudioSession", self.logTag);
    [DTRTCAudioSession.shared callkitDidDeactivateAudioSession:audioSession];
}

#pragma mark - mainPrivate

//重置变量
- (void)resetVariableData:(NSString *)callerId
{
    if (callerId) {
        [self.callerMap removeObjectForKey:callerId];
    }
    self.haveAcceptCall = NO;
}

#pragma mark - 配置
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

- (CXCallUpdate *)callUpdate
{
    if (!_callUpdate) {
        _callUpdate = [CXCallUpdate new];
        _callUpdate.supportsGrouping = false;
        _callUpdate.supportsUngrouping = false;
        _callUpdate.supportsHolding = false;
        _callUpdate.supportsDTMF = false;
    }
    return _callUpdate;
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
            return  call;
        }
    }
    return nil;
}

- (void)handleVoipCallNotify:(NSDictionary *)apnsInfo completion:(void (^__nullable)(void))completion {

    OWSLogDebug(@"========>CallKit: apnsInfo:%@", apnsInfo);
    
    NSDictionary *callInfo = apnsInfo[@"callInfo"];
    NSString *encMsg = apnsInfo[@"msg"];
    [self registerDarwinNotification];
    
    if (DTParamsUtils.validateDictionary(callInfo)) {
        NSString *channelName = callInfo[@"channelName"];
        if (!channelName || !channelName.length) {
            OWSLogError(@"========>CallKit:❌ channelName reportFakeCall");
            [self reportFakeCallCompletion:completion];
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
                OWSLogWarn(@"========>CallKit:❌ unexpected voip: %.0f", startAt);
                [self reportFakeCallCompletion:completion];
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
                  completion:completion];
    } else if (DTParamsUtils.validateString(encMsg)) {
        DSKProtoCallMessageCalling *calling = [self decryptMsg:encMsg];
        if (!calling) {
            [self reportFakeCallCompletion:completion];
        } else {
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
                          completion:completion];
            }
        }
    } else {
        [self reportFakeCallCompletion:completion];
        OWSLogInfo(@"========>CallKit:❌ callInfo/msg reportFakeCall");
    }
    
}

#pragma mark - private

- (BOOL)isLiveKitCall:(CXSetMutedCallAction *)action {
    NSString *callerId = [self callerIDFromUUID: action.callUUID];
    DSKProtoCallMessageCalling *calling = [self callingFromCallerId:callerId];
    
    return calling != nil;
}

#pragma mark - notification
void DarwinNotificationCallback(CFNotificationCenterRef center,
                                void *observer,
                                CFStringRef name,
                                const void *object,
                                CFDictionaryRef userInfo) {
    if (name) {
        OWSLogInfo(@"[CallKit] receive callkit end action");
        [[DTMeetingManager shared] endCallActionWithForceEndGroupMeeting:NO completionHandler:^{
                    
        }];
    }
}

- (void)registerDarwinNotification {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center,
                                    NULL,
                                    DarwinNotificationCallback,
                                    CFSTR("com.temptalk.nseCallkitStop"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

@end
