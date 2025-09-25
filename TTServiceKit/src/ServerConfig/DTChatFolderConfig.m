//
//  DTChatFolderConfig.m
//  TTServiceKit
//
//  Created by Ethan on 2022/4/27.
//

#import "DTChatFolderConfig.h"
#import "DTServerConfigManager.h"

@implementation DTChatFolderConfigEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end


@implementation DTChatFolderConfig

+ (NSDictionary *)defaultConfig {
    return @{
        @"maxFolderCount" : @10
    };
}

+ (DTChatFolderConfigEntity *)fetchChatFolderConfig {
    
    __block DTChatFolderConfigEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"chatFolder" completion:^(id  _Nullable config, NSError * _Nullable error) {
            
        NSDictionary *chatFolderConfig = config;
        if (error || !config) {
            chatFolderConfig = self.defaultConfig;
        }
        
        NSError *mtlError;
        DTChatFolderConfigEntity *entity = [MTLJSONAdapter modelOfClass:[DTChatFolderConfigEntity class] fromJSONDictionary:chatFolderConfig error:&mtlError];
        if (!mtlError) {
            result = entity;
        } else {
            DTChatFolderConfigEntity *entity = [DTChatFolderConfigEntity new];
            [self.defaultConfig enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [entity setValue:obj forKey:key];
            }];
            result = entity;
        }
    }];
    
    return result;
}


@end
