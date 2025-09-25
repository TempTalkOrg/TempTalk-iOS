//
//  DTStickyConfig.m
//  TTServiceKit
//
//  Created by Ethan on 2022/2/9.
//

#import "DTStickyConfig.h"
#import "DTServerConfigManager.h"

@implementation DTStickyConfig

+ (NSUInteger)maxStickCount {
    
    //MARK: 默认置顶6个会话
    __block NSUInteger numberOfSticky = 6;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"maxStickCount" completion:^(id  _Nullable config, NSError * _Nullable error) {
        
        NSNumber *serverStickyNumber = (NSNumber *)config;
        if (!error && config) {
            numberOfSticky = [serverStickyNumber unsignedIntegerValue];
        }
    }];
    
    return numberOfSticky;
}

@end
