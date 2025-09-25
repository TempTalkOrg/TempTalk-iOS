//
//  DTSignChativeController.h
//  TTMessaging
//
//  Created by hornet on 2022/10/1.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>


typedef enum : NSUInteger {
    DTSignTypeLogin = 0,//登录
    DTSignTypeRegister = 1,//注册
} DTSignType;

NS_ASSUME_NONNULL_BEGIN

@interface DTSignChativeController : OWSViewController
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *phoneNumber;
//用于区分当前页面是登录页面还是注册页面
@property (nonatomic, assign) DTSignType signType;
@end

NS_ASSUME_NONNULL_END
