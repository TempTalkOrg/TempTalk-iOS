//
//  DTGroupMemberEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/2.
//

#import "DTGroupMemberEntity.h"

@implementation DTGroupMemberEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (NSString *)rapidDescription {
    
    switch (self.rapidRole) {
        case DTGroupRAPIDRoleRecommend:
            return @"Recommend";
        case DTGroupRAPIDRoleAgree:
            return @"Agree";
        case DTGroupRAPIDRolePerform:
            return @"Perform";
        case DTGroupRAPIDRoleInput:
            return @"Input";
        case DTGroupRAPIDRoleDecider:
            return @"Decider";
        case DTGroupRAPIDRoleObserver:
            return @"Observer";
        case DTGroupRAPIDRoleNone:
            return @"None";
        default: break;
    }
}

@end
