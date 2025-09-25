//
//  DTSensitiveWordsConfig.m
//  TTServiceKit
//
//  Created by Ethan on 2022/5/2.
//

#import "DTSensitiveWordsConfig.h"
#import "DTServerConfigManager.h"

@implementation DTSensitiveWordsConfig

+ (NSArray <NSString *> *)defaultConfig {
    
    return @[@"制裁", @"sanction"];
}

+ (NSArray<NSString *> *)fetchSensitiveWords {
    
    __block NSArray <NSString *> *result = self.defaultConfig;
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"audit" completion:^(id  _Nullable config, NSError * _Nullable error) {
            
        NSArray <NSString *> *serverConfig = config;
        if (!error && serverConfig) {
            result = serverConfig;
        }
    }];
    
    return result;
}

+ (NSString * _Nullable)checkSensitiveWords:(NSString *)targetText {
    
    NSArray <NSString *> *sensitiveWords = [DTSensitiveWordsConfig fetchSensitiveWords];
    __block NSString *word = nil;
    [sensitiveWords enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([targetText containsString:obj]) {
            word = obj;
            *stop = YES;
        }
    }];
    
    return word;
}

@end
