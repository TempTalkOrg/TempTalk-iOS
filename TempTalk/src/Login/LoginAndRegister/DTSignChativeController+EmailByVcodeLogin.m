//
//  DTSignChativeController+EmailByVcodeLogin.m
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTSignChativeController+EmailByVcodeLogin.h"
#import "DTSignChativeController+internal.h"
#import <TTServiceKit/Localize_Swift.h>

@implementation DTSignChativeController (EmailByVcodeLogin)

- (void)requestLoginViaEmail:(NSString *)email shouldErrorToast:(BOOL) toast{
    OWSLogInfo(@"requestLoginViaEmail: shouldErrorToast: email -> %@ toast -> %d", email, toast);
    [self.loginWithEmailApi login:email sucess:^(id<HTTPResponse> _Nonnull _) {
        [DTToastHelper hide];
        [DTChatLoginUtils checkOrResetTimeStampWith:email key:kSendEmailCodeForLoginSucess];
        DTVerificationCodeController *verificationCodeVC = [[DTVerificationCodeController alloc] initWithEmail:email];
        verificationCodeVC.loginModeType = DTLoginModeTypeLoginViaEmail;
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
            UIWindow *keyWindow = OWSWindowManager.sharedManager.rootWindow;
            [DTToastHelper toastWithText:errorMessage inView:keyWindow durationTime:2.5 afterDelay:0];
            return;
        }
        if(errorMessage.length > 0){
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }
       
    }];
}

@end
