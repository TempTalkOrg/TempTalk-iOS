//
//  DTMeetingEntity.m
//  TTServiceKit
//
//  Created by Felix on 2022/2/15.
//

#import "DTMeetingEntity.h"

@implementation DTMeetingEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end
