//
//  DTConversationInfoEntity.m
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

#import "DTConversationInfoEntity.h"

@implementation DTConversationInfoEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end
