//
//  DTHealthCheckAPI.h
//  TTServiceKit
//
//  Best-effort no-auth ping used to anchor DTTrustedClock.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTHealthCheckAPI : DTBaseAPI

- (void)sendRequestWithSuccess:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
