//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSRequest.h"

NS_ASSUME_NONNULL_BEGIN

// TODO: refactor remove to OWSRequestFacroty
@interface TSVerifyCodeRequest : TSRequest

@property (nonatomic, readonly) NSString *numberToValidate;

- (instancetype)init NS_UNAVAILABLE;

- (TSRequest *)initWithVerificationCode:(NSString *)verificationCode
                              forNumber:(NSString *)phoneNumber
                                    pin:(nullable NSString *)pin
                           signalingKey:(NSString *)signalingKey
                                authKey:(NSString *)authKey
                               passcode:(nullable NSString *)passcode;

@end

NS_ASSUME_NONNULL_END
