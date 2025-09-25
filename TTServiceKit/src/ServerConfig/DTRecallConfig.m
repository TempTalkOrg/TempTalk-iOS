//
//  DTRecallConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/1.
//

#import "DTRecallConfig.h"
#import "DTServerConfigManager.h"
#import <SignalCoreKit/NSDate+OWS.h>

@implementation DTRecallConfig

+ (NSDictionary *)defaultConfig{
    return @{
        @"timeoutInterval":@(kDayInterval),
        @"editableInterval":@(5 * kMinuteInterval)
    };
}

+ (DTRecallConfigEntity *)fetchRecallConfig{
    
    __block DTRecallConfigEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"recall"
                                                                  completion:^(id  _Nonnull config, NSError * _Nonnull error) {
        NSDictionary *recallConfig = config;
        if(error || config == nil){
            recallConfig = [self defaultConfig];
        }
        
        NSError *jsonError;
        DTRecallConfigEntity *entity = [MTLJSONAdapter modelOfClass:[DTRecallConfigEntity class] fromJSONDictionary:recallConfig error:&jsonError];
        if(!jsonError){
            result = entity;
        }else{
            DTRecallConfigEntity *entity = [DTRecallConfigEntity new];
            [self.defaultConfig enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [entity setValue:obj forKey:key];
            }];
            result = entity;
        }
        
    }];
    
    return result;
}

@end
