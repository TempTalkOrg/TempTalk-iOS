//
//  DTCallModel.h
//  Signal
//
//  Created by Felix on 2021/8/6.
//

#import <Foundation/Foundation.h>
#import "DTCallConstants.h"
#import <TTServiceKit/DTCallManager.h>
#import <TTServiceKit/DTSafeMutableArray.h>
#import <TTServiceKit/DTCardMessageEntity.h>

NS_ASSUME_NONNULL_BEGIN

@class TSThread;
@class DTListMeeting;
@class TSIncomingMessage;

@interface DTCallModel : NSObject

@property (nonatomic, assign) BOOL isCaller;
@property (nonatomic, assign) BOOL is1v1CallEachOther;
@property (nonatomic, assign) DTCallState callState;
@property (nonatomic, assign) DTCallType callType;
@property (nonatomic, copy) NSString *caller;
@property (nonatomic, assign) NSUInteger localUid;//当前用户的uid
@property (nonatomic, copy) NSString *callerRecipientId;
@property (nonatomic, strong) NSArray<NSString *> *callees;
@property (nonatomic, strong) NSArray<NSString *> *calleeRecipientIds;
@property (nonatomic, copy) NSString *calleeDisplayName;
@property (nonatomic, copy) NSString *meetingName;
@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, strong) TSThread *thread;
@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, copy) NSString *channelToken;
@property (nonatomic, copy, nullable) NSString *meetingId;
@property (nonatomic, strong, nullable) DTCardMessageEntity *privateCallCard;

@property (nonatomic, copy) NSString *meetingKey;
@property (nonatomic, copy) NSString *publicKey;//加密的公钥
@property (nonatomic, copy) NSString *encryptMeetingKey;//ECC加密后的会议密钥
@property (nonatomic, assign) int meetingVersion;//meeting版本号

/// 是否多人会议(群会议/即时会议/预约会议...)
@property (nonatomic, assign, readonly) BOOL isMultiPersonMeeting;
@property (nonatomic, assign, readonly) BOOL is1On1Meeting;
@property (nonatomic, assign) BOOL isGroupMeeting;
@property (nonatomic, assign) BOOL isSchedule;

/// 忽略会议没人讲话自动结束逻辑
@property (nonatomic, assign) BOOL ignoreLeavePopups;


/// 当前是否有人分享屏幕
@property (nonatomic, assign, getter=isInScreenShare) BOOL inScreenShare;
@property (nonatomic, assign, getter=isOpenCamera) BOOL openCamera;
/// 分享屏幕用户account
@property (nonatomic, copy, nullable) NSString *sharingAccount;
/// 当前主持人
@property (nonatomic, copy, nullable) NSString *host;
@property (nonatomic, assign, readonly) BOOL hasHost;
@property (nonatomic, copy) NSString *hostEmail;

/// 预约会议提醒弹窗持续时间(仅预约会议弹窗使用)
@property (nonatomic, assign) NSInteger lasting;
//MARK: 预约会议开始时间(仅预约会议弹窗使用)
@property (nonatomic, assign) uint64_t startAt;

@property (nonatomic, assign, getter=isAutoAccept) BOOL autoAccept;

@property (nonatomic, strong, nullable) DTListMeeting *event;

@property (nonatomic, strong, nullable) TSIncomingMessage *incomingMessage;

@property (nonatomic, assign, getter=isTurnOnCC) BOOL turnOnCC;

/** live stream */

/// 是否是直播
@property (nonatomic, assign) BOOL isLiveStream;
/// 是否已经go live
@property (nonatomic, assign) BOOL isLiveStarted;
/// guest是否暂停了直播
@property (nonatomic, assign) BOOL isPaused;
/// 直播event id
@property (nonatomic, copy, nullable) NSString *eid;
/// 当前客户端身份
@property (nonatomic, assign) LiveStreamRole role;
/// guest人数
//@property (nonatomic, strong) NSNumber *audienceCnt;

@property (nonatomic, copy) NSString *totalUserInTitle;

@property (nonatomic, strong) DTSafeMutableArray *handupGuests;


@end

NS_ASSUME_NONNULL_END
