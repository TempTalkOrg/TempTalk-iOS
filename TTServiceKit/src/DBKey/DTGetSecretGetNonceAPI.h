//
//  DTGetSecretGetNonceAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGetSecretGetNonceAPI : DTBaseAPI

- (void)sendRequestWithPK:(NSString *)pk
                  success:(void(^)(NSString *nonce))success
                  failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
