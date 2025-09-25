//
//  DTServersEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServersEntity.h"
#import "DTParamsBaseUtils.h"

/*
 call = "/call";
 chat = "/chat";
 fileSharing = "/fileshare";
 miniProgram = "/mp";
 voice = "/voice";
 whisperX = "/whisperX";
 */

NSString *const DTServerToChat = @"chat";
NSString *const DTServerToCall = @"call";
NSString *const DTServerToFileSharing = @"fileSharing";
NSString *const DTServerToSpeech2text = @"speech2text";
NSString *const DTServerToAvatar = @"avatar";

@implementation DTServersEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

+ (NSValueTransformer *)hostsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTServerHostEntity class]];
}

+ (NSValueTransformer *)srvsJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTServerServEntity class]];
}

+ (NSValueTransformer *)servicesJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTServerServiceEntity class]];
}

+ (NSValueTransformer *)domainsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTServerDomainEntity class]];
}

#pragma mark - public

- (NSString *)servURLPath:(NSString *)server {
    NSString *srvsPath = [self.srvs valueForKey:server];
    if (DTParamsUtils.validateString(srvsPath)) {
        return srvsPath;
    }
    return nil;
}

@end


@implementation DTServerHostEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end


@implementation DTServerServEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@implementation DTServerDomainEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@implementation DTServerServiceEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end
