//
//  DTGIFSearchResult.m
//  TempTalk
//
//  GIF search/trending response model (proxy over GIPHY).
//

#import "DTGIFSearchResult.h"

@implementation DTGIFSearchAsset

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTGIFSearchAssetInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        @"identifier": @"id",
        @"title": @"title",
        @"previewAsset": @"preview",
        @"originalAsset": @"original"
    };
}

@end

@implementation DTGIFSearchPagination

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        @"count": @"count",
        @"offset": @"offset",
        @"totalCount": @"total_count"
    };
}

@end

@implementation DTGIFSearchResult

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)dataJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTGIFSearchAssetInfo class]];
}

@end
