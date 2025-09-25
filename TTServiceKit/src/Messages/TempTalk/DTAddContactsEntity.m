//
//  DTAddContactsEntity.m
//  TTServiceKit
//
//  Created by hornet on 2022/11/16.
//

#import "DTAddContactsEntity.h"

@implementation DTOperatorEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"source"] = @"operatorId";
    map[@"sourceDeviceId"] = @"operatorDeviceId";
    map[@"sourceName"] = @"operatorName";
    return map;
}
+ (NSValueTransformer *)publicConfigsJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:ContactPublicConfigs.class];
}
@end

@implementation DTAddContactsEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
}

+ (NSValueTransformer *)operatorInfoJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:DTOperatorEntity.class];
}

@end
