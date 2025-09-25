//
//  DTVerificationCodeController.h
//  Signal
//
//  Created by hornet on 2022/10/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>
#import "DTChativeMacro.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTVerificationCodeController : OWSViewController
@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, assign) DTLoginModeType loginModeType;
@property (nonatomic, assign) DTSignInModeType signInModeType;

@property (nonatomic, copy, nullable) NSString *nonce;
- (instancetype)initWithEmail:(NSString *)email;
- (instancetype)initWithPhone:(NSString *)phone dialingCode:(nullable NSString *)dialingCode;
@end

NS_ASSUME_NONNULL_END
