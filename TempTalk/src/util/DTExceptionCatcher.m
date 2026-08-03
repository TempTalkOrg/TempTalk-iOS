//
//  Copyright (c) 2024 Difft. All rights reserved.
//

#import "DTExceptionCatcher.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const DTExceptionCatcherErrorDomain = @"DTExceptionCatcherError";

@implementation DTExceptionCatcher

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block error:(NSError **)outError {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (outError) {
            NSString *description = [NSString stringWithFormat:@"%@: %@",
                                     exception.name ?: @"NSException",
                                     exception.reason ?: @""];
            *outError = [NSError errorWithDomain:DTExceptionCatcherErrorDomain
                                            code:1
                                        userInfo:@{
                                            NSLocalizedDescriptionKey : description,
                                            @"callStackSymbols" : exception.callStackSymbols ?: @[]
                                        }];
        }
        return NO;
    }
}

@end

NS_ASSUME_NONNULL_END
