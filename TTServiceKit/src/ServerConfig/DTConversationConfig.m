//
//  DTConversationConfig.m
//  TTServiceKit
//
//  Created by hornet on 2022/7/6.
//

#import "DTConversationConfig.h"
#import "DTServerConfigManager.h"

@implementation DTConversationConfigEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}
@end

@implementation DTConversationConfig
+ (nullable DTConversationConfigEntity * )fetchConversationConfig {
    __block DTConversationConfigEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"conversation" completion:^(id  _Nullable config, NSError * _Nullable error) {
        NSDictionary *conversationConfig = config;
        if(error || config == nil){
            result = nil;
        }
        
        NSError *jsonError;
        DTConversationConfigEntity *entity = [MTLJSONAdapter modelOfClass:[DTConversationConfigEntity class] fromJSONDictionary:conversationConfig error:&jsonError];
        if(!jsonError){
            result = entity;
        }else{
            result = nil;
        }
    }];
    return result;
}

+ (BOOL)matchBlockRegexWithBotId:(NSString *)botid {
    DTConversationConfigEntity *conversationConfigEntity = [self fetchConversationConfig];
    if (!conversationConfigEntity) {return false;}
    if (!conversationConfigEntity.blockRegex) {return false;}
    NSPredicate *blockPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", conversationConfigEntity.blockRegex];
    if ([blockPredicate evaluateWithObject:botid]) {
        return true;
    }
    return false;
}

@end
