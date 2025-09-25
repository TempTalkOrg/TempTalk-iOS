//
//  DTPinnedMessageEntity.m
//  TTServiceKit
//
//  Created by Ethan on 2022/3/17.
//

#import "DTPinnedMessageEntity.h"
#import "DTCardMessageEntity.h"

@implementation DTPinnedMessageEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"pinId"] = @"id";
    
    return map.copy;
}

+ (NSValueTransformer *)refreshedCardJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTCardMessageEntity class]];
}

@end
