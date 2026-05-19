//
//  DTCallKitManager+CallerMapTool.m
//  Wea
//
//  Created by user on 2022/8/9.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCallKitManager+CallerMapTool.h"

@implementation DTCallKitManager (CallerMapTool)

#pragma mark - 线程安全访问器

- (WeaCallKitCaller *__nullable)callerForUUID:(NSString *)uuidString {
    [self.callerMapLock lock];
    WeaCallKitCaller *caller = [self.callerMap objectForKey:uuidString];
    [self.callerMapLock unlock];
    return caller;
}

#pragma mark - UUID 查找

- (NSString *__nullable)uuidStringFromNSUUID:(NSUUID *)uuid {
    NSString *uuidStr = uuid.UUIDString;
    [self.callerMapLock lock];
    BOOL exists = [self.callerMap objectForKey:uuidStr] != nil;
    [self.callerMapLock unlock];
    return exists ? uuidStr : nil;
}

- (NSString *__nullable)uuidStringFromRoomId:(NSString *)roomId {
    if (!roomId || roomId.length == 0) {
        return nil;
    }
    [self.callerMapLock lock];
    NSDictionary *snapshot = [self.callerMap copy];
    [self.callerMapLock unlock];
    for (NSString *key in snapshot) {
        WeaCallKitCaller *caller = snapshot[key];
        if ([caller.meetingId isEqualToString:roomId]) {
            return key;
        }
    }
    return nil;
}

#pragma mark - Getter

- (NSString *__nullable)callerAccountFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].callerAccount;
}

- (NSString *__nullable)channelNameFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].channelName;
}

- (BOOL)isLiveStreamFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].isLiveStream;
}

- (BOOL)isScheduleFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].isSchedule;
}

- (NSString *__nullable)eidFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].eid;
}

- (NSString *__nullable)meetingIdFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].meetingId;
}

- (NSString *__nullable)meetingNameFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].meetingName;
}

- (NSString *__nullable)modeFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].mode;
}

- (NSString *__nullable)encryptMeetingKeyFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].encryptMeetingKey;
}

- (int)meetingVersionKeyFromUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    return caller.meetingVersion ? [caller.meetingVersion intValue] : 1;
}

- (BOOL)answerStateFromUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    return caller != nil && caller.answered;
}

- (BOOL)hungupStateFromUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    return caller != nil && caller.hungup;
}

#pragma mark - Setter

- (void)setMode:(NSString *)mode byUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    caller.mode = mode;
}

- (void)setCallerAccount:(NSString *)callerAccount byUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    caller.callerAccount = callerAccount;
}

- (void)setChannelName:(NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(NSString *)meetingName
          isLiveStream:(BOOL)isLiveStream
            isSchedule:(BOOL)isSchedule
                   eid:(nullable NSString *)eid
                byUUID:(NSString *)uuidString {
    WeaCallKitCaller *caller = [self callerForUUID:uuidString];
    if (!caller) {
        return;
    }
    caller.channelName = channelName;
    caller.meetingId = meetingId;
    caller.meetingName = meetingName;
    caller.isLiveStream = isLiveStream;
    caller.isSchedule = isSchedule;
    caller.eid = eid;
}

- (void)setEncryptMeetingKey:(NSString *)emk byUUID:(NSString *)uuidString {
    [self callerForUUID:uuidString].encryptMeetingKey = emk;
}

- (void)setMeetingVersionKey:(NSNumber *)meetingVersion byUUID:(NSString *)uuidString {
    [self callerForUUID:uuidString].meetingVersion = meetingVersion;
}

- (void)setAnswerState:(BOOL)state byUUID:(NSString *)uuidString {
    [self callerForUUID:uuidString].answered = state;
}

- (void)setHungupState:(BOOL)state byUUID:(NSString *)uuidString {
    [self callerForUUID:uuidString].hungup = state;
}

- (void)setCalling:(DSKProtoCallMessageCalling *)calling uuid:(NSString *)uuidString {
    [self callerForUUID:uuidString].calling = calling;
}

- (DSKProtoCallMessageCalling *__nullable)callingFromUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].calling;
}

#pragma mark - 多通话管理

- (NSArray<NSString *> *)getAllActiveUUIDs {
    [self.callerMapLock lock];
    NSArray *keys = [self.callerMap.allKeys copy];
    [self.callerMapLock unlock];
    return keys;
}

- (NSUInteger)getActiveCallsCount {
    [self.callerMapLock lock];
    NSUInteger count = self.callerMap.count;
    [self.callerMapLock unlock];
    return count;
}

- (NSUInteger)getActiveCallsCountFromCallerMap {
    [self.callerMapLock lock];
    NSArray<WeaCallKitCaller *> *snapshot = [self.callerMap.allValues copy];
    [self.callerMapLock unlock];
    NSUInteger count = 0;
    for (WeaCallKitCaller *caller in snapshot) {
        if (!caller.isEnded) {
            count++;
        }
    }
    return count;
}

- (BOOL)hasActiveCalls {
    [self.callerMapLock lock];
    BOOL result = self.callerMap.count > 0;
    [self.callerMapLock unlock];
    return result;
}

- (nullable NSString *)getFirstActiveUUID {
    [self.callerMapLock lock];
    NSString *first = [self.callerMap.allKeys firstObject];
    [self.callerMapLock unlock];
    return first;
}

- (BOOL)hasCallWithUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString] != nil;
}

- (BOOL)isCallAcceptedWithUUID:(NSString *)uuidString {
    return [self callerForUUID:uuidString].isAccepted;
}

- (BOOL)hasAnyAcceptedCall {
    [self.callerMapLock lock];
    NSArray<WeaCallKitCaller *> *snapshot = [self.callerMap.allValues copy];
    [self.callerMapLock unlock];
    for (WeaCallKitCaller *caller in snapshot) {
        if (caller.isAccepted && !caller.isEnded) {
            return YES;
        }
    }
    return NO;
}

- (NSUInteger)getAcceptedCallsCount {
    [self.callerMapLock lock];
    NSArray<WeaCallKitCaller *> *snapshot = [self.callerMap.allValues copy];
    [self.callerMapLock unlock];
    NSUInteger count = 0;
    for (WeaCallKitCaller *caller in snapshot) {
        if (caller.isAccepted && !caller.isEnded) {
            count++;
        }
    }
    return count;
}

- (NSArray<NSString *> *)getAcceptedUUIDs {
    [self.callerMapLock lock];
    NSDictionary *snapshot = [self.callerMap copy];
    [self.callerMapLock unlock];
    NSMutableArray *acceptedIds = [NSMutableArray array];
    for (NSString *key in snapshot) {
        WeaCallKitCaller *caller = snapshot[key];
        if (caller.isAccepted && !caller.isEnded) {
            [acceptedIds addObject:key];
        }
    }
    return [acceptedIds copy];
}

- (void)cleanupEndedCalls {
    [self.callerMapLock lock];
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSString *key in self.callerMap) {
        WeaCallKitCaller *caller = [self.callerMap objectForKey:key];
        if (caller.isEnded) {
            [keysToRemove addObject:key];
        }
    }
    [self.callerMap removeObjectsForKeys:keysToRemove];
    [self.callerMapLock unlock];
    OWSLogInfo(@"[call][callkit] Cleaned up %lu ended calls", keysToRemove.count);
}

@end

@implementation WeaCallKitCaller
@end
