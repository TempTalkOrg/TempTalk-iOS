//
//  DTDisappearanceTimeIntervalConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import "DTDisappearanceTimeIntervalConfig.h"
#import "DTServerConfigManager.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/TTServiceKit-swift.h>

@implementation DTDisappearanceTimeIntervalConfig

+ (void)fetchConfigWithCompletion:(void (^)(DTDisappearanceTimeIntervalEntity * _Nonnull, NSError * _Nonnull))completion{
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"disappearanceTimeInterval"
                                                                  completion:^(id  _Nonnull config, NSError * _Nonnull error) {
        if(error || config == nil){
            NSError *transformError;
            DTDisappearanceTimeIntervalEntity *entity = [MTLJSONAdapter modelOfClass:[DTDisappearanceTimeIntervalEntity class]
                                                                  fromJSONDictionary:[self defaultConfig]
                                                                               error:&transformError];
            completion(entity, transformError);
            
        }else{
            NSError *error;
            DTDisappearanceTimeIntervalEntity *entity = [MTLJSONAdapter modelOfClass:[DTDisappearanceTimeIntervalEntity class] fromJSONDictionary:config error:&error];
            completion(entity, error);
        }
        
    }];
    
}

+ (DTDisappearanceTimeIntervalEntity *)fetchDisappearanceTimeInterval{
    
    __block DTDisappearanceTimeIntervalEntity *entity = nil;
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"disappearanceTimeInterval"
                                                                  completion:^(id  _Nonnull config, NSError * _Nonnull error) {
        
        NSError *transformError = nil;
        if(error || config == nil){
            entity = [MTLJSONAdapter modelOfClass:[DTDisappearanceTimeIntervalEntity class]
                                                                  fromJSONDictionary:[self defaultConfig]
                                                                               error:&transformError];
        }else{
            entity = [MTLJSONAdapter modelOfClass:[DTDisappearanceTimeIntervalEntity class] fromJSONDictionary:config error:&transformError];
        }
        
        if(!entity || transformError){
            entity = [DTDisappearanceTimeIntervalEntity new];
            
            entity.globalDefault = @(kMonthInterval);
            entity.messageDefault = @(kMonthInterval);
            entity.messageOthers = @(kMonthInterval);
            entity.messageGroup = @(kMonthInterval);
            
            entity.messageMe = @(0);
            entity.conversationDefault = @(kMonthInterval);
            entity.conversationMe = @(0);
            entity.conversationOthers = @(kMonthInterval);
            entity.conversationGroup = @(kMonthInterval);
        }
    }];
    
    return entity;
    
}

+ (NSDictionary *)defaultConfig{
    return @{
        @"default":@(2*kDayInterval),
        @"message":@{
            @"default":@(2*kDayInterval),
            @"me":@(0)
        },
        @"conversation":@{
            @"default":@(kMonthInterval),
            @"me":@(0),
            @"other":@(kMonthInterval),
            @"group":@(kMonthInterval)
        },
        @"messageArchivingTimeOptionValues": @[
                   @(3600),
                   @(172800),
                   @(604800)
             ],
    };
    /*
    @{
        @"default":@(604800),
        @"message":@{
            @"default":@(604800),
            @"me":@(0)
        },
        @"conversation":@{
            @"default":@(2592000),
            @"me":@(0),
            @"other":@(2592000),
            @"group":@(2592000)
        }
    };
     */
}

@end
