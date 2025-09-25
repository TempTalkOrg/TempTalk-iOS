//
//  DTDBKeyExceptionWrapper.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/22.
//

#import "DTDBKeyExceptionWrapper.h"

NSErrorDomain const DBKeyExceptionWrapperErrorDomain = @"DBKey.ExceptionWrapper";
NSErrorUserInfoKey const DBKeyExceptionWrapperUnderlyingExceptionKey = @"DBKeyExceptionWrapperUnderlyingExceptionKey";

NSError *DBKeyExceptionWrapperErrorMake(NSException *exception)
{
    return [NSError errorWithDomain:DBKeyExceptionWrapperErrorDomain
                               code:DBKeyExceptionWrapperErrorThrown
                           userInfo:@{ DBKeyExceptionWrapperUnderlyingExceptionKey : exception }];
}

@implementation DTDBKeyExceptionWrapper

+ (BOOL)tryBlock:(void (^)(void))block error:(NSError **)outError
{
    OWSAssertDebug(outError);
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (outError) {
            *outError = DBKeyExceptionWrapperErrorMake(exception);
        }
        return NO;
    }
}

@end

void DBKeyRaiseIfExceptionWrapperError(NSError *_Nullable error)
{
    if (error && [error.domain isEqualToString:DBKeyExceptionWrapperErrorDomain]
        && error.code == DBKeyExceptionWrapperErrorThrown) {
        NSException *_Nullable exception = error.userInfo[DBKeyExceptionWrapperUnderlyingExceptionKey];
        OWSCAssert(exception);
        @throw exception;
    }
}
