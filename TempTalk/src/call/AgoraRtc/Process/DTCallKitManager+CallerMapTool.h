//
//  DTCallKitManager+CallerMapTool.h
//  Wea
//
//  Created by user on 2022/8/9.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCallKitManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTCallKitManager (CallerMapTool)

- (NSString *__nullable)callerIDFromUUID:(NSUUID *)uuid;

- (NSUUID *__nullable)uuidFromCallerID:(NSString *)callerID;

- (NSString *__nullable)channelNameFromCallerID:(NSString *)callerID;

- (BOOL)isLiveStreamFromCallerID:(NSString *)callerID;

- (BOOL)isScheduleFromCallerID:(NSString *)callerID;

- (NSString *__nullable)eidFromCallerID:(NSString *)callerID;

- (NSString *__nullable)meetingIdFromCallerID:(NSString *)callerID;

- (NSString *__nullable)meetingNameFromCallerID:(NSString *)callerID;

- (NSString *__nullable)modeFromCallerID:(NSString *)callerID;

- (NSString *__nullable)encryptMeetingKeyFromCallerID:(NSString *)callerID;

- (int)meetingVersionKeyFromCallerID:(NSString *)callerID;

- (NSString *__nullable)callerAccountFromCallerID:(NSString *)callerID;

- (BOOL)answerStateFromCallerID:(NSString *)callerID;

- (BOOL)hungupStateFromCallerID:(NSString *)callerID;

- (void)setMode:(NSString *)mode byCallerID:(NSString *)callerID;

- (void)setEncryptMeetingKey:(NSString *)emk byCallerID:(NSString *)callerID;

- (void)setMeetingVersionKey:(NSNumber *)meetingVersion byCallerID:(NSString *)callerID;

- (void)setCallerAccount:(NSString *)callerAccount byCallerID:(NSString *)callerID;

- (void)setUUID:(NSUUID *)uuid byCallerID:(NSString *)callerID;

- (void)setChannelName:(NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(NSString *)meetingName
          isLiveStream:(BOOL)isLiveStream
            isSchedule:(BOOL)isSchedule
                   eid:(nullable NSString *)eid
            byCallerID:(NSString *)callerID;

- (void)setAnswerState:(BOOL)state byCallerID:(NSString *)callerID;

- (void)setHungupState:(BOOL)state byCallerID:(NSString *)callerID;


/// 缓存本次callKit incoming call
/// - Parameters:
///   - calling: LiveKitCalling
///   - callerId: caller
- (void)setCalling:(DSKProtoCallMessageCalling *)calling callerId:(NSString *)callerID;
- (DSKProtoCallMessageCalling *__nullable)callingFromCallerId:(NSString *)callerId;

@end


@interface WeaCallKitCaller : NSObject

@property (nonatomic, strong) NSUUID *uuid;
@property (nonatomic, strong) NSString *channelName;
@property (nonatomic, strong) NSString *meetingName;
@property (nonatomic, strong) NSString *meetingId;
@property (nonatomic, strong) NSString *mode;
@property (nonatomic, strong) NSString *callerAccount;
@property (nonatomic, assign) BOOL answered;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL hungup;

@property (nonatomic, strong, nullable) NSString *encryptMeetingKey;
@property (nonatomic, strong, nullable) NSNumber *meetingVersion;

@property (nonatomic, assign) BOOL isLiveStream;
@property (nonatomic, strong, nullable) NSString *eid;
@property (nonatomic, assign) BOOL isSchedule;

@property (nonatomic, strong, nullable) DSKProtoCallMessageCalling *calling;

@end
NS_ASSUME_NONNULL_END
