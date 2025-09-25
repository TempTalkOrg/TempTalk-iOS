//
//  DTScreenLockEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2024/8/30.
//

#import "DTScreenLockEntity.h"

@implementation DTScreenLockEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *keyValues = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    return keyValues;
}

@end
