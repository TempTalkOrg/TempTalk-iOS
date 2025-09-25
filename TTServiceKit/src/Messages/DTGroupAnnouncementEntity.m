//
//  DTGroupAnnouncementEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import "DTGroupAnnouncementEntity.h"

@implementation DTGroupAnnouncementEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"aId"] = @"id";
    return map.copy;
}

@end
