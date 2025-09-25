//
//  DTSignInController.h
//  Signal
//
//  Created by hornet on 2022/10/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>
#import "DTChativeMacro.h"

NS_ASSUME_NONNULL_BEGIN
extern NSString *const kSendEmailCodeSucess;
extern NSString *const kSendEmailCodeForLoginSucess;
extern NSString *const kSendPhoneCodeForLoginSucess;
@interface DTSignInController : OWSViewController
@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, assign) DTSignInModeType signInModeType;
@end
NS_ASSUME_NONNULL_END
