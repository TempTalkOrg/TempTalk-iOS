//
//  DTServersConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServersConfig.h"
#import "DTServerConfigManager.h"
#import "DTParamsBaseUtils.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTServersConfig

+ (DTServersEntity *)fetchServersConfig{
    __block DTServersEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchServersConfigCompletion:^(id _Nonnull config, NSError * _Nonnull error) {
        if(error || config == nil){
            DTServersEntity *entity = [self fetchServersDefaultConfig];
            result = entity;
            
        }else{
            NSError *error;
            DTServersEntity *entity = [MTLJSONAdapter modelOfClass:[DTServersEntity class] fromJSONDictionary:config error:&error];
            if(!error && [self isValidateEntity:entity]){
                result = entity;
            }else{
                DTServersEntity *entity = [self fetchServersDefaultConfig];
                result = entity;
                OWSLogError(@"Multi-server ：%@ using config from disk error: %@",self.logTag, error.localizedDescription);
            }
        }
    }];
    
    return result;
}

+ (DTServersEntity *)fetchServersDefaultConfig {
    NSData *data = [DTBundleConfigLoader loadBundleConfig];
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

    NSError *error = nil;
    DTServersEntity *entity = [MTLJSONAdapter modelOfClass:[DTServersEntity class] fromJSONDictionary:jsonObject error:&error];
    if (entity && [self isValidateEntity:entity]) {
        return entity;
    }

    entity = [DTServersEntity new];
    DTServerHostEntity *hostEntity = [DTServerHostEntity new];
#if POD_CONFIGURATION_RELEASE_CHATIVETEST || POD_CONFIGURATION_RELEASE_TEST || POD_CONFIGURATION_DEBUG_TEST
    hostEntity.name = @"chat.test.chative.im";
#else
    hostEntity.name = @"chat.chative.im";
#endif
    hostEntity.certType = @"self";
    hostEntity.servTo = @"chat";
    entity.hosts = @[hostEntity];
    return entity;
}


+ (BOOL)isValidateEntity:(DTServersEntity *)entity{
    if (!DTParamsUtils.validateArray(entity.hosts) ||
        !entity.srvs ||
        !DTParamsUtils.validateString(entity.avatarFile)) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)hasLegalUrl:(NSArray *)array{
    __block BOOL hasLegalUrl = NO;
    [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *url = [NSURL URLWithString:obj];
        if(DTParamsUtils.validateString(url.host)){
            hasLegalUrl = YES;
        }
    }];
    return hasLegalUrl;
}

+ (NSString *)convertToWebSocketUrlWithOriginUrl:(NSString *)originUrl serverType:(DTServerType)serverType{
    
    NSString *urlString = originUrl;
    
    if ([urlString hasPrefix:@"http"] ||
        [urlString hasPrefix:@"https"]) {
        
        NSURL *url = [NSURL URLWithString:urlString];
        urlString = [NSString stringWithFormat:@"wss://%@", url.host];
        if (DTParamsUtils.validateString(url.path)) {
            urlString = [urlString stringByAppendingString:url.path];
        }
        if (url.port) {
            urlString = [urlString stringByAppendingFormat:@":%@", url.port];
        }
    } else {
        urlString = [NSString stringWithFormat:@"wss://%@", originUrl];
    }
    
    if(serverType == DTServerTypeChat){
        return [NSString stringWithFormat:@"%@/v1/websocket/",urlString];
    }else if(serverType == DTServerTypeUserStatus){
        return [NSString stringWithFormat:@"%@/ws?token=",urlString];
    }else{
        return urlString;
    }
}

@end
