//
//  DTUploadSecretAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTUploadSecretAPI : DTBaseAPI

- (void)sendRequestWithSecretText:(NSString *)secretText
                        signature:(NSString *)signature
                            nonce:(NSString *)nonce
                       deviceInfo:(NSString *)deviceInfo
                          success:(void(^)(void))success
                          failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
