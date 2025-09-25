//
//  DTMessageConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/20.
//

#import "DTMessageConfig.h"
#import "DTServerConfigManager.h"

@implementation DTMessageConfigEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

- (BOOL)hitTheTunnelEncryptionEndsWithNumber:(NSString *)number{
    __block BOOL result = NO;
    [self.tunnelSecurityEnds enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([number hasSuffix:obj]){
            result = YES;
            *stop = YES;
        }
    }];
    return result;
    
}

@end

@implementation DTMessageConfig

+ (DTMessageConfigEntity *)fetchMessageConfig{
    
    __block DTMessageConfigEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"message"
                                                                  completion:^(id  _Nonnull config, NSError * _Nonnull error) {
        NSDictionary *messageConfig = config;
        if(!error){
            NSError *jsonError;
            DTMessageConfigEntity *entity = [MTLJSONAdapter modelOfClass:[DTMessageConfigEntity class] fromJSONDictionary:messageConfig error:&jsonError];
            if(!jsonError){
                result = entity;
            }
        }
        
    }];
    
    return result;
    
}

@end
