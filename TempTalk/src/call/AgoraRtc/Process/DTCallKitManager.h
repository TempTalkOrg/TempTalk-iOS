//
//  DTCallKitManager.h
//  CalendarTest-Finn
//
//  Created by user on 2022/7/22.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>
@class DSKProtoCallMessageCalling;

typedef enum : NSUInteger {
    CallStatus_None,
    CallStatus_BuildCallerFail, //拨打方创建通话失败
    CallStatus_BuildAnswerFail,//接听方创建通话失败
    CallStatus_End,//结束通话
    CallStatus_ReadyToEnd,//准备结束通话 （手动调用结束的 api）
    CallStatus_TimeOut,//等待超时
    CallStatus_Accept,// 按下接听按钮
    CallStatus_ReadyStart,// 准备拨出
    CallStatus_Busy,//正在忙碌
    CallStatus_StartConnect,//开始连接
    CallStatus_Connected,//连接成功 显示时间
} CallStatus;


@protocol DTCallKitManagerDelegate <NSObject>

@required
- (void)refreshCurrentCallStatus:(CallStatus)status callerId:(NSString *_Nullable)callerId;

@optional
- (void)refreshCurrentCallMuteState:(BOOL)isMute;

@end


NS_ASSUME_NONNULL_BEGIN

@interface DTCallKitManager : NSObject

+ (DTCallKitManager *)shared;

@property (nonatomic, weak) id<DTCallKitManagerDelegate>delegate;

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
- (void)endCallAction:(NSString *)callerId;

- (void)endCallActionWithCallerId:(NSString *)callerId;

/****静音按钮事件 (app 同步到 callkit) ****/
- (void)muteCurrentCall:(BOOL)isMute callerId:(NSString *)callerId;

- (void)handleVoipCallNotify:(NSDictionary *)apnsInfo completion:(void (^__nullable)(void))completion;

@end

NS_ASSUME_NONNULL_END
