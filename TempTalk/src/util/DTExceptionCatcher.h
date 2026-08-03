//
//  Copyright (c) 2024 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift-callable bridge for catching NSException, which Swift cannot catch directly.
@interface DTExceptionCatcher : NSObject

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block error:(NSError **)outError
    NS_SWIFT_NAME(catchException(_:));

@end

NS_ASSUME_NONNULL_END
