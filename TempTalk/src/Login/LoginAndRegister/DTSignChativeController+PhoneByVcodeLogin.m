//
//  DTSignChativeController+PhoneByVcodeLogin.m
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTSignChativeController+PhoneByVcodeLogin.h"
#import "DTSignChativeController+internal.h"
#import <TTServiceKit/Localize_Swift.h>

@implementation DTSignChativeController (PhoneByVcodeLogin)

- (void)requestLoginViaPhoneNumber:(NSString *)phoneNumber countryCode: countryCode shouldErrorToast:(BOOL) toast{
    [self.loginWithPhoneApi login:phoneNumber dialingCode:countryCode sucess:^(id<HTTPResponse> _Nonnull _) {
        [DTToastHelper hide];
        [DTChatLoginUtils checkOrResetTimeStampWith:phoneNumber key:kSendPhoneCodeForLoginSucess];
        DTVerificationCodeController *verificationCodeVC = [[DTVerificationCodeController alloc] initWithPhone:phoneNumber dialingCode:countryCode];
        verificationCodeVC.loginModeType = DTLoginModeTypeLoginViaPhone;
        if(self.signType == DTSignTypeLogin){
            verificationCodeVC.titleString =  [NSString stringWithFormat:Localized(@"CHATIVE_LOGIN_OTP_TITLE", @""), TSConstants.appDisplayName];
            [self.navigationController pushViewController:verificationCodeVC animated:true];
        } else if (self.signType == DTSignTypeRegister){
            verificationCodeVC.titleString =  [NSString stringWithFormat:Localized(@"CHATIVE_LOGIN_OTP_CREAT_TITLE", @""), TSConstants.appDisplayName];
            [self.navigationController pushViewController:verificationCodeVC animated:true];
        } else {
            OWSLogInfo(@"signType error");
        }
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
        [DTToastHelper hide];
        NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
        if(toast && DTParamsUtils.validateString(errorMessage)){
            [DTToastHelper toastWithText:errorMessage];
            return;
        }
        if(errorMessage.length > 0){
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }
    }];
}

@end
