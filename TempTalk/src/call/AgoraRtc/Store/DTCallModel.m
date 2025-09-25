//
//  DTCallModel.m
//  Signal
//
//  Created by Felix on 2021/8/6.
//

#import "DTCallModel.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>

@implementation DTCallModel

- (NSString *)meetingName {
    if (_meetingName) {
        return  _meetingName;
    } else {
        return @"";
    }
}

- (void)setCalleeRecipientIds:(NSArray<NSString *> *)calleeRecipientIds {
    if (calleeRecipientIds) {
        _calleeRecipientIds = calleeRecipientIds;
        
        OWSContactsManager *contactManager = Environment.shared.contactsManager;
        NSString *calleeRecipientId = calleeRecipientIds.firstObject;
        NSString *calleeName = [contactManager displayNameForPhoneIdentifier:calleeRecipientId] ? : @"";
        _calleeDisplayName = calleeName;
    }
}

- (BOOL)isMultiPersonMeeting {
    return (self.callType == DTCallTypeMulti ||
            self.callType == DTCallTypeExternal);
}

- (BOOL)is1On1Meeting {
    return self.callType == DTCallType1v1;
}

- (BOOL)isGroupMeeting {
    return self.callType == DTCallTypeMulti;
}

- (BOOL)hasHost {
    return self.host != nil && self.host.length > 0;
}

- (DTSafeMutableArray *)handupGuests {
    if (!_handupGuests) {
        _handupGuests = [DTSafeMutableArray new];
    }
    
    return _handupGuests;
}

@end
