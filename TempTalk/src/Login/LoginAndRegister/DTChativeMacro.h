//
//  DTChativeMacro.h
//  Signal
//
//  Created by hornet on 2022/10/12.
//  Copyright © 2022 Difft. All rights reserved.
//

#ifndef DTChativeMacro_h
#define DTChativeMacro_h

typedef enum : NSUInteger {
    DTSignInModeTypeLogin = 0,//登陆
    DTSignInModeTypeFromMeRebind = 1,//从我的进入绑定
    DTSignInModeTypeRegisterViaInviteCode = 2,//邀请码注册
} DTSignInModeType;

typedef enum : NSUInteger {
    DTLoginModeTypeRegisterEmailFromLogin = 0,//通过邮箱注册
    DTLoginModeTypeChangeEmailFromMe,//修改邮箱/绑定邮箱
    
    DTLoginModeTypeRegisterPhoneNumberFromLogin,//通过手机号注册
    DTLoginModeTypeChangePhoneNumberFromMe,//修改手机号/绑定手机号
    
    DTLoginModeTypeLoginViaEmail,//通过邮箱登录
    DTLoginModeTypeLoginViaPhone, //通过手机号登录
    
    DTLoginModeTypeLoginViaEmailByPasskeyAuth,//通过邮箱和passkey验证登录
    DTLoginModeTypeLoginViaPhoneByPasskeyAuth, //通过手机号passkey验证登录
    
    DTLoginModeTypeViaRegisterPasskeyAuthFromMe //在me页面开启Passkey
} DTLoginModeType;

typedef enum : NSUInteger {
    DTLoginStateTypePreLogin,
    DTLoginStateTypeLogging,
    DTLoginStateTypeLoginSucessed,
    DTLoginStateTypeLoginFailed,
} DTLoginState;

static CGFloat kTextFiledHeight = 48.f;

#endif /* DTChativeMacro_h */
