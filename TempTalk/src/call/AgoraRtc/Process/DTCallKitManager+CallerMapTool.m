//
//  DTCallKitManager+CallerMapTool.m
//  Wea
//
//  Created by user on 2022/8/9.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCallKitManager+CallerMapTool.h"
#import <objc/runtime.h>

//static const void *DTCallKitManagerCallAction = @"DTCallKitManagerCallAction";

@implementation DTCallKitManager (CallerMapTool)

- (NSString *__nullable)callerIDFromUUID:(NSUUID *)uuid {
    for (WeaCallKitCaller *caller in self.callerMap.allValues) {
        if ([caller.uuid.UUIDString isEqualToString:uuid.UUIDString]) {
            return [[self.callerMap allKeysForObject:caller] firstObject];
        }
    }
    return nil;
}

- (NSUUID *__nullable)uuidFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.uuid;
}

- (NSString *__nullable)channelNameFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.channelName;
}

- (BOOL)isLiveStreamFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.isLiveStream;
}

- (BOOL)isScheduleFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.isSchedule;
}

- (NSString *__nullable)eidFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.eid;
}

- (NSString *__nullable)meetingIdFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.meetingId;
}

- (NSString *__nullable)meetingNameFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.meetingName;
}

- (NSString *__nullable)modeFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.mode;
}

- (NSString *__nullable)callerAccountFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.callerAccount;
}

- (BOOL)answerStateFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller == nil) {
        return NO;
    }
    return caller.answered;
}

- (BOOL)hungupStateFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller == nil) {
        return NO;
    }
    return caller.hungup;
}

- (NSString *__nullable)encryptMeetingKeyFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.encryptMeetingKey;
}

- (int)meetingVersionKeyFromCallerID:(NSString *)callerID {
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    return caller.meetingVersion ? [caller.meetingVersion intValue] : 1;
}

- (void)setMode:(NSString *)mode byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.mode = mode;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.mode = mode;
        [self.callerMap setObject:newCaller forKey:callerID];
    }
}

- (void)setCallerAccount:(NSString *)callerAccount byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.callerAccount = callerAccount;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.callerAccount = callerAccount;
        [self.callerMap setObject:newCaller forKey:callerID];
    }
}

- (void)setUUID:(NSUUID *)uuid byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.uuid = uuid;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.uuid = uuid;
        [self.callerMap setObject:newCaller forKey:callerID];
    }
}

- (void)setChannelName:(NSString *)channelName
             meetingId:(NSString *)meetingId
           meetingName:(NSString *)meetingName
          isLiveStream:(BOOL)isLiveStream
            isSchedule:(BOOL)isSchedule
                   eid:(nullable NSString *)eid
            byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    BOOL existCaller = YES;
    if (!caller) {
        existCaller = NO;
        caller = [[WeaCallKitCaller alloc] init];
    }
    caller.channelName = channelName;
    caller.meetingId = meetingId;
    caller.meetingName = meetingName;
    caller.isLiveStream = isLiveStream;
    caller.isSchedule = isSchedule;
    caller.eid = eid;
    if (!existCaller) {
        [self.callerMap setObject:caller forKey:callerID];
    }
}

- (void)setEncryptMeetingKey:(NSString *)emk byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.encryptMeetingKey = emk;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.encryptMeetingKey = emk;
        [self.callerMap setObject:newCaller forKey:callerID];
    }
}

- (void)setMeetingVersionKey:(NSNumber *)meetingVersion byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.meetingVersion = meetingVersion;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.meetingVersion = meetingVersion;
        [self.callerMap setObject:newCaller forKey:callerID];
    }
}

- (void)setAnswerState:(BOOL)state byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.answered = state;
    }
}

- (void)setHungupState:(BOOL)state byCallerID:(NSString *)callerID {
    if (callerID == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerID];
    if (caller) {
        caller.hungup = state;
    }
}

- (void)setCalling:(DSKProtoCallMessageCalling *)calling callerId:(NSString *)callerId {
    if (callerId == nil) {
        return;
    }
    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerId];
    if (caller) {
        caller.calling = calling;
    } else {
        WeaCallKitCaller *newCaller = [[WeaCallKitCaller alloc] init];
        newCaller.calling = calling;
        [self.callerMap setObject:newCaller forKey:callerId];
    }
}

- (DSKProtoCallMessageCalling *__nullable)callingFromCallerId:(NSString *)callerId {

    WeaCallKitCaller *caller = [self.callerMap objectForKey:callerId];
    return caller.calling;
}

@end

@implementation WeaCallKitCaller

@end

