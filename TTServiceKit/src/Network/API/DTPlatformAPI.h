//
//  DTPlatformAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/25.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTPlatformAPI : DTBaseAPI

- (void)sendRequestWithAppId:(NSString *)appId
                     success:(DTAPISuccessBlock)success
                     failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
