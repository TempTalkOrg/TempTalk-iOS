//
//  DTSignChativeController+Login.m
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTSignChativeController+PasskeyLogin.h"
#import "DTSignChativeController+internal.h"
#import "DTSignChativeController+EmailByVcodeLogin.h"
#import "DTSignChativeController+PhoneByVcodeLogin.h"

@implementation DTSignChativeController (PasskeyLogin)

- (void)loginViaEmailByPasskeysAuthWithID:(NSString *)user_id email:(NSString *)email{
    OWSLogInfo(@"[login module] loginViaEmailByPasskeysAuthWithID: email:");
    DTVertifyPasskeysController *vertifyPasskeysVC = [[DTVertifyPasskeysController alloc] initWithLoginType:DTLoginModeTypeLoginViaEmailByPasskeyAuth email:email phoneNumber:nil userId: user_id  callBackHandler:^(BOOL loginViaPassKey) {
        UIWindow *keyWindow = OWSWindowManager.sharedManager.rootWindow;
        [DTToastHelper showHudInView:keyWindow];
        if(loginViaPassKey){
            [self requestPasskeysAuthWithID:user_id email:email anchor:keyWindow];
        } else {
            [self requestLoginViaEmail:email shouldErrorToast:true];
        }
    }];
    [self.navigationController pushViewController:vertifyPasskeysVC animated:true];
}

- (void)requestPasskeysAuthWithID:(NSString *)user_id email:(NSString *)email anchor:(UIWindow *) anchorWindow{
    OWSLogInfo(@"[login module] requestPasskeysAuthWithID: email:");
    //TODO:temptalk Is it necessary
    [TSAccountManager sharedInstance].passkeysUserId = user_id;
    
    if (@available(iOS 16.0, *)) {
        @weakify(self)
        [[TSAccountManager sharedInstance].passKeyManager signInWithUid:user_id anchor:anchorWindow completionHandler:^(DTAPIMetaEntity * _Nullable passkeyLoginEntity, NSError * _Nullable error) {
            @strongify(self)
            OWSLogInfo(@"passkeyLoginEntity = %@ error = %@ errorCode = %zd", [passkeyLoginEntity signal_modelToJSONString], error, error.code);
            if (error){
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:error errResponse:passkeyLoginEntity];
                UIWindow *window = [OWSWindowManager sharedManager].rootWindow;
                [DTToastHelper toastWithText:errorMessage inView:window durationTime:3 afterDelay:0];
                return;
            }
            NSDictionary *data = passkeyLoginEntity.data;
            OWSLogInfo(@"perform login:verificationCode: sucess");
            if (!DTParamsUtils.validateDictionary(data)) {
                [DTToastHelper hide];
                NSError *error_t = [NSError errorWithDomain:@"response error"  code:20000 userInfo:nil];
                NSString *errorMessage = [NSError errorDesc:error_t errResponse:nil];
                [DTToastHelper _showError:errorMessage];
                return;
            }
            BOOL accountOk = FALSE;
            do {
                NSNumber *transferable = [data objectForKey:@"transferable"];
                ///0 表示不支持数据转移，1表示支持数据转移
                NSDictionary *tokens = [data objectForKey:@"tokens"];
                BOOL isCanTranfer = [transferable intValue] == 1 && DTParamsUtils.validateDictionary(tokens);
                if(isCanTranfer && DTParamsUtils.validateDictionary(tokens)){
                    [DTToastHelper hide];
                    DTTransferDataViewController * transferDataVC = [[DTTransferDataViewController alloc] initWithLoginType:DTLoginModeTypeLoginViaEmail email:email phoneNumber:nil   dialingCode:nil logintoken:tokens[@"logintoken"] ? : @"" tdtToken:tokens[@"tdtoken"] ? : @""];
                    DispatchMainThreadSafe(^{
                        [self.navigationController pushViewController:transferDataVC animated:true];
                    });
                    
                    return;
                } else {
                    
                    NSString *number = [data objectForKey:@"account"];
                    if (DTParamsUtils.validateString(number)) {
                        TSAccountManager *manager = [TSAccountManager sharedInstance];
                        manager.phoneNumberAwaitingVerification = number;
                    }
                    NSString *vCode = [data objectForKey:@"verificationCode"];
                    if (!DTParamsUtils.validateString(vCode)) {
                        [DTToastHelper hide];
                        break;
                    }
                    accountOk = TRUE;
                    self.vCode = vCode;
                    NSError *screenLockError;
                    DTScreenLockEntity * screenLock = [MTLJSONAdapter modelOfClass:[DTScreenLockEntity class]
                                                                fromJSONDictionary:data
                                                                             error:&screenLockError];
                    [self submitVerificationWithCode:self.vCode screenLock:screenLock];
                }
            } while(false);
            
            if (FALSE == accountOk) {
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
                OWSLogInfo(@"LoginViaEmail loginWithEmailCodeApi login: verificationCode: sucess call Back accountOk = false  errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else {
        OWSLogInfo(@"[Passkey module] this version unsopport passkey");
        [self requestLoginViaEmail:email shouldErrorToast:true];
    }
}

- (void)loginViaPhoneByPasskeysAuthWithID:(NSString *)user_id phoneNumber:(NSString *)phoneNumber countryCode:(NSString *)countryCode {
    
    DTVertifyPasskeysController *vertifyPasskeysVC = [[DTVertifyPasskeysController alloc] initWithLoginType:DTLoginModeTypeLoginViaEmailByPasskeyAuth email:nil phoneNumber:phoneNumber userId: user_id  callBackHandler:^(BOOL loginViaPassKey){
        if(loginViaPassKey){
            [self requestPasskeysAuthWithID:user_id phoneNumber:phoneNumber countryCode:countryCode];
        } else {
            [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:true];
        }
    }];
    [self.navigationController pushViewController:vertifyPasskeysVC animated:true];
}

- (void)requestPasskeysAuthWithID:(NSString *)user_id phoneNumber:(NSString *)phoneNumber countryCode:(NSString *)countryCode{
    OWSLogInfo(@"[login module] requestPasskeysAuthWithID: phoneNumber:");
    //TODO:temptalk Is it necessary
    [TSAccountManager sharedInstance].passkeysUserId = user_id;
    UIWindow *keyWindow = OWSWindowManager.sharedManager.rootWindow;
    [DTToastHelper showHudInView:keyWindow];
    if (@available(iOS 16.0, *)) {
        [[TSAccountManager sharedInstance].passKeyManager signInWithUid:user_id anchor:keyWindow completionHandler:^(DTAPIMetaEntity * _Nullable passkeyLoginEntity, NSError * _Nullable error) {
            if (error){
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:error errResponse:passkeyLoginEntity];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [DTToastHelper _showError:errorMessage];
                });
                
                return;
            }
            NSDictionary *data = passkeyLoginEntity.data;
            OWSLogInfo(@"perform login:verificationCode: sucess");
            if (!DTParamsUtils.validateDictionary(data)) {
                OWSLogInfo(@"[DTSignChativeController] signInWithUid data error");
                [DTToastHelper hide];
                return;
            }
            BOOL accountOk = FALSE;
            do {
                NSNumber *transferable = [data objectForKey:@"transferable"];
                ///0 表示不支持数据转移，1表示支持数据转移
                NSDictionary *tokens = [data objectForKey:@"tokens"];
                BOOL isCanTranfer = [transferable intValue] == 1 && DTParamsUtils.validateDictionary(tokens);
                if(isCanTranfer && DTParamsUtils.validateDictionary(tokens)){
                    [DTToastHelper hide];
                    DTTransferDataViewController * transferDataVC = [[DTTransferDataViewController alloc] initWithLoginType:DTLoginModeTypeLoginViaEmail email:nil phoneNumber:phoneNumber   dialingCode:countryCode logintoken:tokens[@"logintoken"] ? : @"" tdtToken:tokens[@"tdtoken"] ? : @""];
                    DispatchMainThreadSafe(^{
                        [self.navigationController pushViewController:transferDataVC animated:true];
                    });
                    return;
                } else {
                    NSString *number = [data objectForKey:@"account"];
                    if (DTParamsUtils.validateString(number)) {
                        TSAccountManager *manager = [TSAccountManager sharedInstance];
                        manager.phoneNumberAwaitingVerification = number;
                    }
                    NSString *vCode = [data objectForKey:@"verificationCode"];
                    if (!DTParamsUtils.validateString(vCode)) {
                        [DTToastHelper hide];
                        break;
                    }
                    accountOk = TRUE;
                    self.vCode = vCode;
                    NSError *screenLockError;
                    DTScreenLockEntity * screenLock = [MTLJSONAdapter modelOfClass:[DTScreenLockEntity class]
                                                                fromJSONDictionary:data
                                                                             error:&screenLockError];
                    [self submitVerificationWithCode:self.vCode screenLock:screenLock];
                }
            } while(false);
            if (FALSE == accountOk) {
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
                OWSLogInfo(@"LoginViaEmail loginWithEmailCodeApi login: verificationCode: sucess call Back accountOk = false  errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else {
        OWSLogInfo(@"[Passkey module] this version unsopport passkey");
        [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:true];
    }
}

@end
