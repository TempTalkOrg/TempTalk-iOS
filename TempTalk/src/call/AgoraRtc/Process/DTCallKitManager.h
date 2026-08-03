//
//  DTCallKitManager.h
//  CalendarTest-Finn
//
//  Created by user on 2022/7/22.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>
#import "DTCallKitManagerDelegate.h"
@class DSKProtoCallMessageCalling;
@class OWSBackgroundTask;

NS_ASSUME_NONNULL_BEGIN

@interface DTCallKitManager : NSObject

@property (nonatomic, weak, nullable) id<DTCallKitManagerDelegate> delegate;

+ (DTCallKitManager *)shared;

/// 是否有任何已接听的通话（计算属性，基于 callerMap）
@property (nonatomic, assign, readonly) BOOL haveAcceptCall;

/// CXCallController 中的活跃通话数
@property (nonatomic, assign, readonly) NSUInteger callsCount;

/// callerMap（key: uuid.UUIDString, value: WeaCallKitCaller）
/// ⚠️ 所有读写必须持有 callerMapLock
@property (nonatomic, strong, readonly) NSMutableDictionary *callerMap;

/// 保护 callerMap 的递归锁（同一线程可重入，跨线程互斥）
@property (nonatomic, strong, readonly) NSRecursiveLock *callerMapLock;

/// Per-call timeout timers (key: uuidString, value: NSTimer)
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSTimer *> *timeoutTimers;

- (nullable CXCall *)findCallByUUID:(NSUUID *)uuid;

/*** 防止崩溃，报告一个假的 Call ****/
- (void)reportFakeCallCompletion:(void (^__nullable)(void))completion;

/*** 接收方 展示电话呼入等待接收界面 ****/
- (void)didReceiveCall:(nullable NSString *)callerName
         callerAccount:(nullable NSString *)callerAccount
           channelName:(nullable NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(nullable NSString *)meetingName
                  mode:(nullable NSString *)mode
                   emk:(nullable NSString *)emkString
        meetingVersion:(NSNumber *)meetingVersion
            isSchedule:(BOOL)isSchedule
          isLiveStream:(BOOL)isLiveStream
                   eid:(nullable NSString *)eid
        liveKitCalling:(nullable DSKProtoCallMessageCalling *)calling
       preReportedUUID:(nullable NSUUID *)preReportedUUID
            completion:(void (^__nullable)(void))completion;

/**** 拨打方 呼出电话（仍传 callerId，内部生成 UUID）****/
- (void)starCall:(NSString *)callerId;

/****接电话 (app内接通，同步到 callkit) ****/
- (void)answerCallAction:(NSString *)uuidString;

//拨打方 开始连接
- (void)startedConnectingOutgoingCall:(NSString *)uuidString;
//拨打方 通话连接成功 显示通话时间
- (void)connectedOutgoingCall:(NSString *)uuidString;

/// Fulfill the held answer action once the LiveKit room actually connects, so the
/// system call UI flips from "Connecting…" to answered in sync with real media.
/// No-op when no action is being held (caller side / non-CallKit answer).
- (void)fulfillPendingAnswerAction:(NSString *)uuidString;

/****结束通话 (app 同步到 callkit) ****/
- (void)endCallAction:(NSString *)uuidString onlyForCallKit:(BOOL)onlyForCallKit;

/****静音按钮事件 (app 同步到 callkit) ****/
- (void)muteCurrentCall:(BOOL)isMute uuidString:(NSString *)uuidString;
- (nullable NSNumber *)callKitMuteIntentForUUID:(NSString *)uuidString;

- (void)handleVoipCallNotify:(NSDictionary *)apnsInfo completion:(void (^__nullable)(void))completion;

- (void)rejectCallFromCallKit:(DSKProtoCallMessageCalling *)calling;

@end

NS_ASSUME_NONNULL_END
