//
//  DTUnreadEntity.m
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

#import "DTUnreadEntity.h"

@implementation DTUnreadEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"unreadFlag"] = @"flag";
    return map.copy;
}

+ (NSValueTransformer *)covnersationJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:DTConversationInfoEntity.class];
}
@end
