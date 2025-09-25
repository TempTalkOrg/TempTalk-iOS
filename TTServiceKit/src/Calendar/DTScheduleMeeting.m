//
//  DTMeetingModel.m
//  TTServiceKit
//
//  Created by Ethan on 28/08/2023.
//

#import "DTScheduleMeeting.h"

@implementation DTScheduleMeeting

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    NSMutableDictionary *keyValues = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    keyValues[@"describe"] = @"description";
    return keyValues;
}

- (void)setNilValueForKey:(NSString *)key {
    if ([key isEqualToString:@"isGroup"]) {
        self.isGroup = (self.group != nil);
    } else {
        return [super setNilValueForKey:key];
    }
}

+ (NSValueTransformer *)groupJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingGroup class]];
}

+ (NSValueTransformer *)recurringRuleJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingRecurringRule class]];
}

+ (NSValueTransformer *)attendeesJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTMeetingAttendee class]];
}

+ (NSValueTransformer *)attachmentJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTMeetingAttachment class]];
}

+ (NSValueTransformer *)meetingLinksJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTMeetingAttachment class]];
}

+ (NSValueTransformer *)hostInfoJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingHostInfo class]];
}

+ (NSValueTransformer *)creatorJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingHostInfo class]];
}

@end

@implementation DTMeetingAttendee

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTLiveStreamGuests

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTMeetingHostInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTMeetingGroup

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end


@implementation DTMeetingAttachment

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end


@implementation DTMeetingRepeatOption

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value {
    
    self = [super init];
    if (self) {
        self.label = label;
        self.value = value;
    }
    
    return self;
}

@end

@implementation DTMeetingRecurringRule

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)repeatOptionsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTMeetingRepeatOption class]];
}

@end

@implementation DTListMeeting

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)hostInfoJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingHostInfo class]];
}

+ (NSValueTransformer *)creatorJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTMeetingHostInfo class]];
}

+ (NSValueTransformer *)sourceJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        return value;
    } reverseBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        if (value == nil) {
            return @"";
        }
        return value;
    }];
}

@end

@implementation DTUserEvents

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)eventsJSONTransformer {
   
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTListMeeting class]];
}

@end

@implementation DTSchedulePermission

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)defaultValueTransformer {
    
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{
        @"readwrite" : @(DTScheduleEditModeReadWrite),
        @"read" : @(DTScheduleEditModeReadonly),
        @"-" : @(DTScheduleEditModeHidden)
    } defaultValue:@(DTScheduleEditModeReadWrite) reverseDefaultValue:@"-"];
}

+ (NSValueTransformer *)buttonDeleteJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonEditJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonUpdateJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)checkboxEveryoneCanInviteOthersJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)checkboxEveryoneCanModifyMeetingJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)checkboxReceiveNotificationJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)checkboxSendInvitationToTheChatRoomJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)editorAttachmentJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)pickerStartDateTimeJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)selectorAttendeeJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)selectorDurationJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)selectorRepeatJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)textFieldDescJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)textFieldTitleJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)textHostJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)toggleGoingOrNotJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonCopyJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonAddLiveStreamJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonCopyLiveStreamJSONTransformer {
    
    return [self defaultValueTransformer];
}

+ (NSValueTransformer *)buttonJoinJSONTransformer {
    
    return [self defaultValueTransformer];
}

@end
