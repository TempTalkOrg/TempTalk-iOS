//
//  DTCallKitManager.h
//  CalendarTest-Finn
//
//  Created by user on 2022/7/22.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>
@class DSKProtoCallMessageCalling;


NS_ASSUME_NONNULL_BEGIN

@interface DTCallKitManager : NSObject

+ (DTCallKitManager *)shared;

@property (nonatomic, strong, nullable) NSTimer *callKitTimeOutTimer;
@property (nonatomic, strong, nullable) NSTimer *detectiveStatusTimer;
@property (nonatomic, assign, readonly) BOOL haveAcceptCall;
@property (nonatomic, assign) NSUInteger callsCount;
@property (nonatomic, strong, readonly) NSMutableDictionary *callerMap;

@property (nonatomic, assign) BOOL isLocalEndCall;

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
                   emk:(nullable NSString * )emkString
        meetingVersion:(NSNumber *)meetingVersion
            isSchedule:(BOOL)isSchedule
          isLiveStream:(BOOL)isLiveStream
                   eid:(nullable NSString *)eid
        liveKitCalling:(nullable DSKProtoCallMessageCalling *)calling
            completion:(void (^__nullable)(void))completion;
/**** 拨打方 呼出电话 ****/
- (void)starCall:(NSString *)callerId;

/****接电话 (app内接通，同步到 callkit) ****/
- (void)answerCallAction:(NSString *)callerId;

//拨打方 开始连接
- (void)startedConnectingOutgoingCall:(NSString *)callerId;
//拨打方 通话连接成功 显示通话时间
- (void)connectedOutgoingCall:(NSString *)callerId;

/****结束通话 (app 同步到 callkit) ****/
- (void)endCallAction:(NSString *)callerId onlyForCallKit:(BOOL)onlyForCallKit;

- (void)endCallActionWithCallerId:(NSString *)callerId onlyForCallKit:(BOOL)onlyForCallKit;

/****静音按钮事件 (app 同步到 callkit) ****/
- (void)muteCurrentCall:(BOOL)isMute callerId:(NSString *)callerId;

- (void)handleVoipCallNotify:(NSDictionary *)apnsInfo completion:(void (^__nullable)(void))completion;

- (void)rejectCallFromCallKit:(DSKProtoCallMessageCalling *)calling;

@end

NS_ASSUME_NONNULL_END
