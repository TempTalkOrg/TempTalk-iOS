//
//  DTFloatMenuActionConfigEntity.m
//  TTServiceKit
//
//  Created by Jaymin on 2024/1/11.
//

#import "DTFloatMenuActionConfigEntity.h"

@implementation DTFloatMenuActionNameModel

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        @"zhCN": @"zh-cn",
        @"enUS": @"en-us"
    };
}

@end

@implementation DTFloatMenuActionConfigEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end
