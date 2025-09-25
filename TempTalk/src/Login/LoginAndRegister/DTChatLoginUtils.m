//
//  DTChatLoginUtils.m
//  Signal
//
//  Created by hornet on 2022/10/13.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTChatLoginUtils.h"
#import <TTServiceKit/DTTokenKeychainStore.h>

@implementation DTChatLoginUtils
+ (void)checkOrResetTimeStampWith:(NSString *)email key:(NSString *)key {
    NSString *accountKey = [self accountWithEmail:email key:key];
    NSString *timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:accountKey];
    uint64_t timeStamp = (uint64_t)[NSDate ows_millisecondTimeStamp]/1000;
    if(timeStampString ){
        uint64_t timeStampNumber = (uint64_t)[timeStampString longLongValue];
        uint64_t diff = timeStamp - timeStampNumber;
        if (diff > 60){
            [DTTokenKeychainStore setPassword:[NSString stringWithFormat:@"%llu",timeStamp] forAccount:accountKey];
        }
    } else {
        [DTTokenKeychainStore setPassword:[NSString stringWithFormat:@"%llu",timeStamp] forAccount:accountKey];
    }
}

+ (NSString *)accountWithEmail:(NSString *)email key:(NSString *)key {
    return [NSString stringWithFormat:@"%@_%@",key,[email ows_stripped]];
}

@end
