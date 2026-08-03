//
//  DTCallKitManager+CallerMapTool.h
//  Wea
//
//  Created by user on 2022/8/9.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCallKitManager.h"
#import "DTCallKitManagerDelegate.h"
@class OWSBackgroundTask;
@class WeaCallKitCaller;

NS_ASSUME_NONNULL_BEGIN

@interface DTCallKitManager (CallerMapTool)

#pragma mark - UUID 查找

- (NSString *__nullable)uuidStringFromNSUUID:(NSUUID *)uuid;
- (NSString *__nullable)uuidStringFromRoomId:(NSString *)roomId;

#pragma mark - Getter（by UUID）

- (NSString *__nullable)callerAccountFromUUID:(NSString *)uuidString;
- (NSString *__nullable)channelNameFromUUID:(NSString *)uuidString;
- (BOOL)isLiveStreamFromUUID:(NSString *)uuidString;
- (BOOL)isScheduleFromUUID:(NSString *)uuidString;
- (NSString *__nullable)eidFromUUID:(NSString *)uuidString;
- (NSString *__nullable)meetingIdFromUUID:(NSString *)uuidString;
- (NSString *__nullable)meetingNameFromUUID:(NSString *)uuidString;
- (NSString *__nullable)modeFromUUID:(NSString *)uuidString;
- (NSString *__nullable)encryptMeetingKeyFromUUID:(NSString *)uuidString;
- (int)meetingVersionKeyFromUUID:(NSString *)uuidString;
- (BOOL)answerStateFromUUID:(NSString *)uuidString;
- (BOOL)hungupStateFromUUID:(NSString *)uuidString;

#pragma mark - Setter（by UUID）

- (void)setMode:(NSString *)mode byUUID:(NSString *)uuidString;
- (void)setEncryptMeetingKey:(NSString *)emk byUUID:(NSString *)uuidString;
- (void)setMeetingVersionKey:(NSNumber *)meetingVersion byUUID:(NSString *)uuidString;
- (void)setCallerAccount:(NSString *)callerAccount byUUID:(NSString *)uuidString;
- (void)setChannelName:(NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(NSString *)meetingName
          isLiveStream:(BOOL)isLiveStream
            isSchedule:(BOOL)isSchedule
                   eid:(nullable NSString *)eid
                byUUID:(NSString *)uuidString;
- (void)setAnswerState:(BOOL)state byUUID:(NSString *)uuidString;
- (void)setHungupState:(BOOL)state byUUID:(NSString *)uuidString;

- (void)setCalling:(DSKProtoCallMessageCalling *)calling uuid:(NSString *)uuidString;
- (DSKProtoCallMessageCalling *__nullable)callingFromUUID:(NSString *)uuidString;

#pragma mark - 线程安全访问器（供 Swift 使用）

/// 线程安全地获取 caller 对象（内部持有 callerMapLock）
- (WeaCallKitCaller *__nullable)callerForUUID:(NSString *)uuidString;

#pragma mark - 多通话管理

- (NSArray<NSString *> *)getAllActiveUUIDs;
- (NSUInteger)getActiveCallsCount;
- (NSUInteger)getActiveCallsCountFromCallerMap;
- (BOOL)hasActiveCalls;
- (nullable NSString *)getFirstActiveUUID;
- (BOOL)hasCallWithUUID:(NSString *)uuidString;
- (BOOL)isCallAcceptedWithUUID:(NSString *)uuidString;
- (BOOL)hasAnyAcceptedCall;
- (NSUInteger)getAcceptedCallsCount;
- (NSArray<NSString *> *)getAcceptedUUIDs;
- (void)cleanupEndedCalls;

@end


@interface WeaCallKitCaller : NSObject

// 身份信息
@property (nonatomic, strong) NSUUID *uuid;
@property (nonatomic, strong) NSString *callerAccount;
@property (nonatomic, strong) NSString *channelName;
@property (nonatomic, strong) NSString *meetingName;
@property (nonatomic, strong) NSString *meetingId;
@property (nonatomic, strong) NSString *mode;

// 加密
@property (nonatomic, strong, nullable) NSString *encryptMeetingKey;
@property (nonatomic, strong, nullable) NSNumber *meetingVersion;

// 通话类型
@property (nonatomic, assign) BOOL isLiveStream;
@property (nonatomic, assign) BOOL isSchedule;
@property (nonatomic, assign) BOOL isPrivateCall;
@property (nonatomic, strong, nullable) NSString *eid;

// 通话状态（per-call）
@property (nonatomic, assign) NSTimeInterval timing;
// Consecutive nil check-call results; end the CallKit ring only after 2 in a row.
@property (nonatomic, assign) NSInteger invalidCheckCount;
@property (nonatomic, assign) BOOL answered;
@property (nonatomic, assign) BOOL isAccepted;
@property (nonatomic, assign) BOOL isEnded;
@property (nonatomic, assign) BOOL hungup;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isMutedByApp;
@property (nonatomic, assign) BOOL hasCallKitMuteIntent;
@property (nonatomic, assign) CallStatus status;
@property (nonatomic, assign) CKCallSystemState systemState;

// 后台保活（per-call）
@property (nonatomic, strong, nullable) OWSBackgroundTask *backgroundTask;

// Calling proto 缓存
@property (nonatomic, strong, nullable) DSKProtoCallMessageCalling *calling;

// Held answer action: stored (not fulfilled) while the room is still connecting,
// so the system UI stays in "Connecting…" until LiveKit actually connects.
@property (nonatomic, strong, nullable) CXAnswerCallAction *pendingAnswerAction;

@end

NS_ASSUME_NONNULL_END
