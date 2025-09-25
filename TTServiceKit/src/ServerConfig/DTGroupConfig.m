//
//  DTGroupConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/30.
//

#import "DTGroupConfig.h"
#import "DTServerConfigManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTGroupReminderConfig

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end


@implementation DTGroupConfigEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

//+ (NSValueTransformer *)messageArchivingTimeOptionValuesJSONTransformer {
//    return [MTLJSONAdapter arrayTransformerWithModelClass:[NSNumber class]];
//}
@end

@implementation DTGroupConfig

+ (NSDictionary *)defaultConfig{
    return @{
        @"largeGroupThreshold": @(50),
        @"meetingWithoutRingThreshold": @(50),
        @"chatWithoutReceiptThreshold": @(50),
        @"membersMaxSize": @(200),
        @"messageArchivingTimeOptionValues": @[@(3600), @(172800), @(604800)],
    };
}

+ (DTGroupConfigEntity *)fetchGroupConfig{
    
    __block DTGroupConfigEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"group"
                                                                  completion:^(id  _Nonnull config, NSError * _Nonnull error) {
        NSDictionary *recallConfig = [self defaultConfig];
        if(!error && config){
            NSMutableDictionary *result = recallConfig.mutableCopy;
            [result addEntriesFromDictionary:config];
            recallConfig = result.copy;
        }
        
        NSError *jsonError;
        DTGroupConfigEntity *entity = [MTLJSONAdapter modelOfClass:[DTGroupConfigEntity class] fromJSONDictionary:recallConfig error:&jsonError];
        if(!jsonError){
            result = entity;
        }else{
            DTGroupConfigEntity *entity = [DTGroupConfigEntity new];
            [self.defaultConfig enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [entity setValue:obj forKey:key];
            }];
            result = entity;
        }
        
    }];
    
    return result;
}

@end
