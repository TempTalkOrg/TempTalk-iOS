//
//  DTUploadSecretGetNonceAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTUploadSecretGetNonceAPI : DTBaseAPI

- (void)sendRequestWithPK:(NSString *)pk
                  success:(void(^)(NSString *nonce))success
                  failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
