//
//  DTCallConstants.h
//  Signal
//
//  Created by Felix on 2021/9/9.
//

#ifndef DTCallConstants_h
#define DTCallConstants_h

typedef enum : NSUInteger {
    DTLoginStatusOffline = 0,
    DTLoginStatusDisconnecting,
    DTLoginStatusConnecting,
    DTLoginStatusOnline,
    DTLoginStatusTokenExpire,
} DTLoginStatus;

static NSString *DTCallModeGroup = @"group";
static NSString *DTCallModePrivate = @"private";


typedef NS_ENUM(NSInteger, DTCallState) {
    DTCallState_Idle,
    DTCallState_Outgoing,
    DTCallState_Alerting,
    DTCallState_Answering,
    DTCallState_Connecting
};

// 通话类型
typedef NS_ENUM(NSInteger, DTCallType) {
    DTCallTypeUnknow = 0,// 未知类型
    DTCallType1v1,     //1v1
    DTCallTypeMulti,   //多人
    DTCallTypeExternal //外部
};

//通话结束原因
typedef NS_ENUM(NSInteger, DTCallEndReason) {
    DTCallEndReasonRemoteTimeOut, // 对方超时
//    DTCallEndReasonHangup,// 挂断通话
    DTCallEndReasonLocalCancel,// 取消呼叫
    DTCallEndReasonRemoteCancel,// 对方取消呼叫
    DTCallEndReasonRemoteRefuse,// 对方拒绝呼叫
    DTCallEndReasonLocalBusy,// 忙碌
    DTCallEndReasonNoResponse,// 无响应
    DTCallEndReasonRemoteNoResponse,// 对方无响应
    DTCallEndReasonHandleOnOtherDevice// 已在其他设备处理
};

#endif /* DTCallConstants_h */
