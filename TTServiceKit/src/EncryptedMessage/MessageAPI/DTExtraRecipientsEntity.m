//
//  DTSendGroupMessageAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/18.
//

#import "DTExtraRecipientsEntity.h"
#import "DTPrekeyBundle.h"

@implementation DTExtraRecipientsEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

+ (NSValueTransformer *)missingJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTPrekeyBundle class]];
}

+ (NSValueTransformer *)extraJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTPrekeyBundle class]];
}

+ (NSValueTransformer *)staleJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTPrekeyBundle class]];
}

@end
