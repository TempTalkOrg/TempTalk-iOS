//
//  DTStickCallModel.m
//  Wea
//
//  Created by Felix on 2021/12/25.
//

#import "DTStickCallModel.h"

@implementation DTRTMMessage

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

// 'create', 'destroy', 'change', 'start-meeting'
+ (NSValueTransformer *)eventJSONTransformer {
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{
        @"create": @(MeetingEventCreate),
        @"destroy": @(MeetingEventDestroy),
        @"change": @(MeetingEventChange),
        @"start-meeting": @(MeetingEventStartMeeting),
        @"join-start": @(MeetingEventJoinStart),
        @"join-end": @(MeetingEventJoinEnd),
        @"popups": @(MeetingEventPopups),
        @"host": @(MeetingEventHost),
        @"host-end": @(MeetingEventHostEnd),
        @"video": @(MeetingEventVideo),
    } defaultValue:@(MeetingEventUnknow) reverseDefaultValue:@"unknow"];
}

- (NSString *)channelName {
    
    if (self.room != nil) {
        return self.room.channelName;
    }
    return _channelName;
}

- (NSString *)meetingName {
    if (self.room != nil) {
        return self.room.meetingName;
    }
    return _meetingName;
}

@end


@implementation DTStickCallModel

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *map = [[NSDictionary mtl_identityPropertyMapWithModel:[self class]] mutableCopy];
    map[@"meetingName"] = @"name";
    return map;
}

// 'private', 'instant', 'group', 'external'
+ (NSValueTransformer *)meetingTypeJSONTransformer {
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{
        @"private": @(MeetingTypePrivate),
        @"instant": @(MeetingTypeInstant),
        @"group": @(MeetingTypeGroup),
        @"external": @(MeetingTypeExternal),
        @"room": @(MeetingTypeRoom)
    } defaultValue:@(MeetingTypeUnknow) reverseDefaultValue:@"unknow"];
}

@end
