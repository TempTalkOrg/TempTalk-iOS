//
//  DTGetSecretAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGetSecretAPI : DTBaseAPI

- (void)sendRequestWithSignature:(NSString *)signature
                           nonce:(NSString *)nonce
                         success:(void(^)(NSString *secretText))success
                         failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
