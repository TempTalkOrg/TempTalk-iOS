/*
 Created by Jean-Pierre Fourie
 Copyright (c) 2015-2017 emotality <jp@emotality.com>
 Website: https://www.emotality.com
 GitHub: https://github.com/apptality
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

#import "ATAppUpdater.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSConstants.h"
#import "DTParamsBaseUtils.h"

@implementation ATAppUpdater


#pragma mark - Init


+ (id)sharedUpdater
{
    static ATAppUpdater *sharedUpdater;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedUpdater = [[ATAppUpdater alloc] init];
    });
    return sharedUpdater;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.alertTitle = @"New Version";
        self.alertMessage = @"Version %@ is available on the AppStore.";
        self.alertUpdateButtonTitle = @"Update";
        self.alertCancelButtonTitle = @"Not Now";
    }
    return self;
}


#pragma mark - Instance Methods


- (void)showUpdateWithForce
{
    [self checkNewAppVersion:^(BOOL newVersion, BOOL needForceUpdate, NSString *version) {
        if (newVersion) [self alertUpdateForVersion:version withForce:YES];
    }];
}

- (void)showUpdateWithConfirmation
{
    [self checkNewAppVersion:^(BOOL newVersion, BOOL needForceUpdate, NSString *version) {
        if (newVersion) {
            
            [self alertUpdateForVersion:version withForce:needForceUpdate];
        } else {
            
            [self alertNomoreNewVersion];
        }
    }];
}

- (void)showUpdate:(BOOL)needShow{
    
    [self checkNewAppVersion:^(BOOL newVersion, BOOL needForceUpdate, NSString *version) {
        
        //强制升级
        if(needForceUpdate){
            [self alertUpdateForVersion:version withForce:needForceUpdate];
        }else if (newVersion && needShow){//普通升级
            [self alertUpdateForVersion:version withForce:NO];
        }
        
    }];
}

- (void)showForceUpdateWithoutVerifyVersion {
    [self checkNewAppVersion:^(BOOL newVersion, BOOL needForceUpdate, NSString  * _Nullable version) {
        // 请求成功失败均提示强制升级
        [self alertUpdateForVersion:version withForce:YES];
    }];
}

#pragma mark - Private Methods

- (void)alertUpdateForVersion:(nullable NSString *)version withForce:(BOOL)force
{
    NSString *alertMessage = nil;
    if (DTParamsUtils.validateString(version)) {
        alertMessage = [NSString stringWithFormat:self.alertMessage, version];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *updateAction = [UIAlertAction actionWithTitle:self.alertUpdateButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        NSURL *appstoreURL = [NSURL URLWithString:self.appStoreURL];
        if (appstoreURL) {
            [[UIApplication sharedApplication] openURL:appstoreURL options:@{} completionHandler:^(BOOL success) {
                if (success) {
                    if ([self.delegate respondsToSelector:@selector(appUpdaterUserDidLaunchAppStore)]) {
                        [self.delegate appUpdaterUserDidLaunchAppStore];
                    }
                }
            }];
        } else {
            // TODO: 给出异常没有获取到 appstoreURL 情况下的处理方案
        }
    }];
    [alert addAction:updateAction];
    
    if (!force) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:self.alertCancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            if ([self.delegate respondsToSelector:@selector(appUpdaterUserDidCancel)]) {
                [self.delegate appUpdaterUserDidCancel];
            }
        }];
        [alert addAction:cancelAction];
    }
    
    // 获取当前视图，将update窗口展示在前端。
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *currentVC = [self getCurrentVCFrom:rootViewController];
    [currentVC presentViewController:alert animated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(appUpdaterDidShowUpdateDialog)]) {
            [self.delegate appUpdaterDidShowUpdateDialog];
        }
    }];
}

- (void)alertNomoreNewVersion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:self.noUpdateAlertMessage preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *doneAction = [UIAlertAction actionWithTitle:self.alertDoneTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }];
    [alert addAction:doneAction];
    
    // 获取当前视图，将update窗口展示在前端。
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *currentVC = [self getCurrentVCFrom:rootViewController];
    [currentVC presentViewController:alert animated:YES completion:^{
    }];
    
}


- (UIViewController *)getCurrentVCFrom:(UIViewController *)rootVC
{
    UIViewController *currentVC;
    
    if ([rootVC presentedViewController]) {
        // 视图是被presented出来的
        
        rootVC = [rootVC presentedViewController];
    }
    
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        // 根视图为UITabBarController
        
        currentVC = [self getCurrentVCFrom:[(UITabBarController *)rootVC selectedViewController]];
        
    } else if ([rootVC isKindOfClass:[UINavigationController class]]){
        // 根视图为UINavigationController
        
        currentVC = [self getCurrentVCFrom:[(UINavigationController *)rootVC visibleViewController]];
        
    } else {
        // 根视图为非导航类
        
        currentVC = rootVC;
    }
    
    return currentVC;
}

@end
