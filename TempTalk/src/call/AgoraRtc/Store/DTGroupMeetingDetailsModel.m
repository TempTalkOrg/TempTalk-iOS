//
//  DTGroupMeetingDetailsModel.m
//  Signal
//
//  Created by Ethan on 2022/8/18.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTGroupMeetingDetailsModel.h"
#import <TTMessaging/Theme.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/NSString+SSK.h>
#import "UIFont+OWS.h"
#import <TTServiceKit/Localize_Swift.h>

@implementation DTGroupMeetingDetailsModel

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (NSAttributedString *)logsDescription {

    NSDate *logsDate = [NSDate ows_dateWithMillisecondsSince1970:self.timestamp];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *logsTimestamp = [formatter stringFromDate:logsDate];
    logsTimestamp = [logsTimestamp stringByAppendingString:@"  "];
    
    NSString *name = nil;
    if ([self.account hasPrefix:MeetingAccoutPrefix_Web]) {
        name = [self.account getWebUserName];
    } else {
        NSString *uid = [self.account transforUserAccountToCallNumber];
        if ([uid isEqualToString:[TSAccountManager localNumber]]) {
            name = Localized(@"YOU", @"you");
        } else {
            name = [[Environment shared].contactsManager displayNameForPhoneIdentifier:uid];
        }
    }
    NSString *eventString = nil;
    if ([self.event isEqualToString:@"join"]) {
        eventString = [NSString stringWithFormat:@"%@%@", name, Localized(@"MEETING_MEMBER_JOIN_INFO_MESSAGE", @"")];
    } else if ([self.event isEqualToString:@"leave"]) {
        eventString = [NSString stringWithFormat:@"%@%@", name, Localized(@"MEETING_MEMBER_LEFT_INFO_MESSAGE", @"")];
    }
    
    NSString *logs = [logsTimestamp stringByAppendingString:eventString];
    CGFloat fontSize = [UIFont ows_dynamicTypeBodyFont].pointSize;
    NSMutableAttributedString *attributeLogs = [[NSMutableAttributedString alloc] initWithString:logs];
    [attributeLogs addAttributes:@{NSFontAttributeName : [UIFont systemFontOfSize:fontSize - 4], NSForegroundColorAttributeName : Theme.placeholderColor} range:NSMakeRange(0, logsTimestamp.length)];
    [attributeLogs addAttributes:@{NSFontAttributeName : [UIFont systemFontOfSize:fontSize - 2], NSForegroundColorAttributeName : Theme.primaryTextColor} range:NSMakeRange(logsTimestamp.length, logs.length - logsTimestamp.length)];

    return [attributeLogs copy];
}

- (NSString *)userName {
   
    NSString *name = nil;
    if ([self.account hasPrefix:MeetingAccoutPrefix_Web]) {
        name = [self.account getWebUserName];
    } else {
        NSString *uid = [self.account transforUserAccountToCallNumber];
//        if ([uid isEqualToString:[TSAccountManager localNumber]]) {
//            name = Localized(@"YOU", @"you");
//        } else {
        name = [[Environment shared].contactsManager displayNameForPhoneIdentifier:uid];
//        }
    }
    
    return name;
}

- (NSString *)userEmail {
    
    NSString *email = nil;
    if ([self.account hasPrefix:MeetingAccoutPrefix_Web]) {
        email = self.account;
    } else {
        NSString *uid = [self.account transforUserAccountToCallNumber];
        Contact *contact = [[Environment shared].contactsManager signalAccountForRecipientId:uid].contact;
        email = DTParamsUtils.validateString(contact.email) ? contact.email : uid;
    }
    
    return email;
}

- (NSString *)logsTime {
    
    NSDate *logsDate = [NSDate ows_dateWithMillisecondsSince1970:self.timestamp];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *logsTimestamp = [formatter stringFromDate:logsDate];
    
    return logsTimestamp;
}

@end
