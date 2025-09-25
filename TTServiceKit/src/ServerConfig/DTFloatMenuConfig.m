//
//  DTFloatMenuConfig.m
//  TTServiceKit
//
//  Created by Jaymin on 2024/1/11.
//

#import "DTFloatMenuConfig.h"
#import "DTServerConfigManager.h"
#import "DTParamsBaseUtils.h"
#import <Mantle/Mantle.h>

@implementation DTFloatMenuConfig

+ (NSArray<DTFloatMenuActionConfigEntity *> *)fetchFloatMenuConfig {
    __block NSArray *result = @[];
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"floatMenuActions" completion:^(id  _Nullable config, NSError * _Nullable error) {

        NSArray *floatMenuActions = nil;
        if (DTParamsUtils.validateArray(config)) {
            floatMenuActions = config;
        }
        if (floatMenuActions == nil || floatMenuActions.count == 0) {
            return;
        }
        
        NSError *jsonError;
        result = [MTLJSONAdapter modelsOfClass:[DTFloatMenuActionConfigEntity class] fromJSONArray:floatMenuActions error:&jsonError];
        if (jsonError) {
            result = @[];
        }
    }];
    
    return result;
}

+ (NSString *)fetchCoworkerAppid {
    __block NSString *coworkerAppid = @"";
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"coworkerAppid" completion:^(id  _Nullable config, NSError * _Nullable error) {

        coworkerAppid = config;
    }];
    
    return coworkerAppid;
}
@end
