//
//  DTConversationArchiveEntity.m
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

#import "DTConversationArchiveEntity.h"

@implementation DTConversationArchiveEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

+ (NSValueTransformer *)covnersationJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:DTConversationInfoEntity.class];
}
@end
