//
//  DTConversationNotifyEntity.m
//  TTServiceKit
//
//  Created by hornet on 2022/6/23.
//

#import "DTConversationNotifyEntity.h"

@implementation DTConversationEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

- (void)setNilValueForKey:(NSString *)key {
    
    if ([key isEqualToString:@"muteStatus"]) {
        self.muteStatus = 0;
    } else if ([key isEqualToString:@"blockStatus"]) {
        self.blockStatus = 0;
    } else {
        [super setNilValueForKey:key];
    }
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[DTConversationEntity class]]) {
        return NO;
    }
    DTConversationEntity *other = (DTConversationEntity *)object;
    return [self.number isEqual:other.number] &&
    [self.conversation isEqualToString:other.conversation] &&
    self.muteStatus == other.muteStatus &&
    [self.sourceDescribe isEqualToString:other.sourceDescribe] &&
    [self.findyouDescribe isEqualToString:other.findyouDescribe] &&
    self.version == other.version &&
    self.confidentialMode == other.confidentialMode &&
    [self.remark isEqualToString:other.remark];
}

@end

@implementation DTConversationNotifyEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"source"] = @"operator";
    map[@"sourceDeviceId"] = @"operatorDeviceId";
    return map.copy;
}

+ (NSValueTransformer *)conversationJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:DTConversationEntity.class];
}


@end

