//
//  DTSignChativeController+Interal.h
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/UIButton+DTExtend.h>
#import <TTMessaging/Theme.h>
#import "DTTextField.h"
#import <TTServiceKit/DTPatternHelper.h>
#import <TTServiceKit/DTToastHelper.h>
#import "TempTalk-Swift.h"
#import <TTServiceKit/TSConstants.h>

#import <TTServiceKit/DTCountryLocationManger.h>
#import <TTServiceKit/OWSError.h>
#import "TSAccountManager.h"
#import "AppDelegate.h"
#import <AFNetworking/AFURLSessionManager.h>
#import "DTStepTextFiled.h"
#import "DTVerificationCodeController.h"
#import "DTSignInController.h"
#import "DTChatLoginUtils.h"
#import "MainAppContext.h"
#import <TTMessaging/UINavigationController+Navigation.h>
#import <TTMessaging/OWSWindowManager.h>

NS_ASSUME_NONNULL_BEGIN
@interface DTSignChativeController ()
@property (nonatomic, strong, nullable) NSString *vCode;
@property (nonatomic, strong) DTLoginWithEmailApi *loginWithEmailApi;
@property (nonatomic, strong) DTLoginWithPhoneNumberApi *loginWithPhoneApi;

- (void)submitVerificationWithCode:(NSString *)code screenLock:(DTScreenLockEntity * __nullable)screenlock;
- (void)resetSubviewsLayoutWithState:(DTLoginState)state errorMesssage:(NSString * __nullable) message;
@end
NS_ASSUME_NONNULL_END
