//
//  DTDBKeyExceptionWrapper.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const DBKeyExceptionWrapperErrorDomain;
typedef NS_ERROR_ENUM(DBKeyExceptionWrapperErrorDomain, DBKeyExceptionWrapperError) {
    DBKeyExceptionWrapperErrorThrown = 20100
};

extern NSErrorUserInfoKey const DBKeyExceptionWrapperUnderlyingExceptionKey;

NSError *DBKeyExceptionWrapperErrorMake(NSException *exception);

NS_SWIFT_UNAVAILABLE("throws objc exceptions")
@interface DTDBKeyExceptionWrapper : NSObject

+ (BOOL)tryBlock:(void (^)(void))block error:(NSError **)outError;

@end

void DBKeyRaiseIfExceptionWrapperError(NSError *_Nullable error) NS_SWIFT_UNAVAILABLE("throws objc exceptions");

NS_ASSUME_NONNULL_END
