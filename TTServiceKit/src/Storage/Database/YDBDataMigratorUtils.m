//
//  YDBDataMigratorUtils.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/12.
//

#import "YDBDataMigratorUtils.h"

@implementation YDBDataMigratorUtils

+ (nullable id)unarchivedObject:(NSData *)data {
    if (![data isKindOfClass:[NSData class]] || data.length <= 0) {
        OWSLogWarn(@"unarchivedObject data type error or empty");
        return nil;
    }
    id object = nil;
    @try {
        object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch (NSException *exception) {
        OWSLogError(@"unarchivedObject Caught exception: %@, Reason: %@", exception.name, exception.reason);
    }
    return object;
}

@end
