//
//  DTToastHelper.m
//  TTServiceKit
//
//  Created by hornet on 2021/11/11.
//

#import "DTToastHelper.h"
#import "DifftMBProgressHUD.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <Lottie/Lottie-Swift.h>
#import <TTServiceKit/TTServiceKit-Swift.h>


#define UIColorFromHex(value)           [UIColor colorWithRed:((float)((value & 0xFF0000) >> 16))/255.0 green:((float)((value & 0xFF00) >> 8))/255.0 blue:((float)(value & 0xFF))/255.0 alpha:1.0]
#define UIColorFromHexA(value,alphaNum) [UIColor colorWithRed:((float)((value & 0xFF0000) >> 16))/255.0 green:((float)((value & 0xFF00) >> 8))/255.0 blue:((float)(value & 0xFF))/255.0 alpha:alphaNum]
#define UIColorFromRGB(r,g,b)           UIColorFromRGBA(r,g,b,1.0f)
#define UIColorFromRGBA(r,g,b,a)        [UIColor colorWithRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:a]

#define Color_BezelViewBackGroundColor UIColorFromHexA(0x000000, 0.8)
#define Color_TipTextColor UIColorFromHexA(0xFFFFFF,1.0)
#define kDefaultDurationTime 2.0
@interface DTToastHelper()
@property(nonatomic,strong) DifftMBProgressHUD *hud;
@property (assign, nonatomic) UIWindowLevel maxSupportedWindowLevel;
@end


@implementation DTToastHelper

+ (DTToastHelper *)sharedHelper {
    static dispatch_once_t onceToken;
    static DTToastHelper *toastHelper;
    dispatch_once(&onceToken, ^{
        toastHelper = [[self alloc] init];
        toastHelper.maxSupportedWindowLevel = UIWindowLevelNormal;
    });

    return toastHelper;
}

+ (void)setupSVProgressHUDAppearence {
    
    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    [SVProgressHUD setHapticsEnabled:YES];
    [SVProgressHUD setMinimumDismissTimeInterval:1.5];
    [SVProgressHUD setMinimumSize:CGSizeMake(80, 0)];
    [SVProgressHUD.appearance setCornerRadius:10.f];
    [SVProgressHUD setMaxSupportedWindowLevel:UIWindowLevelStatusBar + 1.f];
}

+ (void)show {
    UIWindow *topWindow = [[self sharedHelper] frontWindow];
    [self showHudInView:topWindow];
}
+ (void)hide {
    DTToastHelper *roastHelper = [self sharedHelper];
    if (roastHelper.hud) { [roastHelper.hud hideAnimated:true];}
}

+ (void)show01LoadingHudIsDark:(BOOL)isDark inView:(nullable UIView *)view {
    if (!view) {
        UIWindow *topWindow = [[self sharedHelper] frontWindow];
        view = topWindow;
    }
    
    DTToastHelper *roastHelper = [self sharedHelper];
    if (roastHelper.hud) {[roastHelper.hud removeFromSuperview];}
    
    DifftMBProgressHUD *hud = [[DifftMBProgressHUD alloc] initWithView:view];
    hud.bezelView.style = DifftMBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = UIColor.clearColor;
    hud.removeFromSuperViewOnHide = true;
    hud.mode = DifftMBProgressHUDModeCustomView;
    [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[DifftMBProgressHUD class]]].color = [UIColor whiteColor];
    
    NSString *lottiePath = isDark ? @"tt_loading_dark" : @"tt_loading_light";
    LottieAnimationView *animationView = [DTToastHelper animationViewWithName:lottiePath];
    hud.customView = animationView;
    
    [view addSubview:hud];
    roastHelper.hud = hud;
    [hud showAnimated:true];
}


+ (void)showHudInView:(UIView *)view {
    DTToastHelper *roastHelper = [self sharedHelper];
    if (roastHelper.hud) {[roastHelper.hud removeFromSuperview];}
    
    DifftMBProgressHUD *hud = [[DifftMBProgressHUD alloc] initWithView:view];
    hud.bezelView.style = DifftMBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = Color_BezelViewBackGroundColor;
    hud.removeFromSuperViewOnHide = true;
    hud.mode = DifftMBProgressHUDModeIndeterminate;
    [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[DifftMBProgressHUD class]]].color = [UIColor whiteColor];
    [view addSubview:hud];
    roastHelper.hud = hud;
    [hud showAnimated:true];
}

+ (void)showHudWithMessage:(NSString *)message inView:(UIView *)view {
    DTToastHelper *roastHelper = [self sharedHelper];
    if (roastHelper.hud) {[roastHelper.hud removeFromSuperview];}
    
    DifftMBProgressHUD *hud = [[DifftMBProgressHUD alloc] initWithView:view];
    hud.bezelView.style = DifftMBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = Color_BezelViewBackGroundColor;
    hud.removeFromSuperViewOnHide = true;
    hud.mode = DifftMBProgressHUDModeIndeterminate;
    hud.label.text = message;
    hud.label.textColor = [UIColor whiteColor];
    hud.label.numberOfLines = 2;
    [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[DifftMBProgressHUD class]]].color = [UIColor whiteColor];
    [view addSubview:hud];
    roastHelper.hud = hud;
    [hud showAnimated:true];
}


+ (void)toastWithText:(NSString *)message {
    [self toastWithText:message durationTime:kDefaultDurationTime];
}

+ (void)toastWithText:(NSString *)message durationTime:(NSTimeInterval) duration {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [SVProgressHUD setInfoImage:nil];
#pragma clang diagnostic pop
    [SVProgressHUD showInfoWithStatus:message];
    [SVProgressHUD dismissWithDelay:duration];
}
+ (void)toastWithText:(NSString *)message durationTime:(NSTimeInterval) duration afterDelay:(NSTimeInterval) delayTime {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self toastWithText:message durationTime:duration];
    });
}

+ (void)toastWithText:(NSString *)message durationTime:(NSTimeInterval)duration completion:(void(^)(void))completion {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [SVProgressHUD setInfoImage:nil];
#pragma clang diagnostic pop
    [SVProgressHUD showInfoWithStatus:message];
    [SVProgressHUD dismissWithDelay:duration completion:completion];
}


+ (void)toastWithText:(NSString *)message
               inView:(UIView *)view
         durationTime:(NSTimeInterval) duration
           afterDelay:(NSTimeInterval) delayTime {
    DifftMBProgressHUD *hud = [[DifftMBProgressHUD alloc] initWithView:view];
    hud.bezelView.style = DifftMBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = Color_BezelViewBackGroundColor;
    hud.removeFromSuperViewOnHide = true;
    hud.mode = DifftMBProgressHUDModeText;
    hud.userInteractionEnabled = NO;
    hud.label.text = message;
    hud.label.textColor = Color_TipTextColor;
    hud.label.numberOfLines = 2;
    [view addSubview:hud];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud showAnimated:true];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delayTime + duration)* NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud hideAnimated:true];
    });
    
}

- (UIWindow *)frontWindow {
    NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
    for (UIWindow *window in frontToBackWindows) {
        BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
        BOOL windowIsVisible = !window.hidden && window.alpha > 0;
        BOOL windowLevelSupported = (window.windowLevel >= UIWindowLevelNormal && window.windowLevel <= self.maxSupportedWindowLevel);
        BOOL windowKeyWindow = window.isKeyWindow;
            
        if(windowOnMainScreen && windowIsVisible && windowLevelSupported && windowKeyWindow) {
            return window;
        }
    }
    return nil;
}

+ (void)setMaxSupportedWindowLevel:(UIWindowLevel)windowLevel {
    [self sharedHelper].maxSupportedWindowLevel = windowLevel;
}

+ (void)svShow {
    [SVProgressHUD show];
}

+ (void)allowInteraction:(BOOL)isAllow {
    if (isAllow) {
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
        return;
    }
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
}

+ (void)dismiss {
    [SVProgressHUD dismiss];
}

+ (void)dismissWithDelay:(NSTimeInterval)delay {
    [SVProgressHUD dismissWithDelay:delay];
}

+ (void)dismissWithInfo:(NSString *)info {
    [[self class] dismissWithInfo:info delay:0];
}

+ (void)dismissWithInfo:(NSString *)info
                  delay:(NSTimeInterval)delay {
    [[self class] dismissWithInfo:info delay:delay completion:nil];
}

+ (void)dismissWithInfo:(NSString *)info
             completion:(void(^)(void))completion {
    [[self class] dismissWithInfo:info delay:0 completion:completion];
}

+ (void)dismissWithDelay:(NSTimeInterval)delay
              completion:(void(^)(void))completion {
    [SVProgressHUD dismissWithDelay:delay completion:^{
        if (completion) completion();
    }];
}

+ (void)dismissWithInfo:(NSString *)info
                  delay:(NSTimeInterval)delay
             completion:(void(^)(void))completion {
    [SVProgressHUD dismissWithDelay:delay completion:^{
        [[self class] showWithInfo:info];
        if (completion) completion();
    }];
}

+ (void)_showError:(NSString *)error {
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
    [SVProgressHUD showErrorWithStatus:error];
}

+ (void)_showSuccess:(NSString *)success {
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
    [SVProgressHUD showSuccessWithStatus:success];
}

+ (void)showWithInfo:(NSString *)info {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [SVProgressHUD setInfoImage:nil];
#pragma clang diagnostic pop
    [SVProgressHUD showInfoWithStatus:info];
}

+ (void)showInfo:(NSString *)info {
    
//    NSBundle *bundle = [NSBundle bundleForClass:[SVProgressHUD class]];
//    NSURL *url = [bundle URLForResource:@"SVProgressHUD" withExtension:@"bundle"];
//    NSBundle *imageBundle = [NSBundle bundleWithURL:url];
//    UIImage *infoImage = [UIImage imageWithContentsOfFile:[imageBundle pathForResource:@"info" ofType:@"png"]];
    UIImage *image = [UIImage imageNamed:@"ic_hud_tips"];
    [SVProgressHUD setInfoImage:image];
    [SVProgressHUD showInfoWithStatus:info];
}

+ (void)showWithStatus:(NSString *)status {
    [SVProgressHUD showWithStatus:status];
}

+ (void)showSuccess:(NSString *)success {
    if ([self isVisible]) {
        [SVProgressHUD dismissWithCompletion:^{
            [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
            [SVProgressHUD showSuccessWithStatus:success];
        }];
        
        return;
    }
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
    [SVProgressHUD showSuccessWithStatus:success];
}

+ (void)showFailure:(NSString *)failure {
    if ([self isVisible]) {
        [SVProgressHUD dismissWithCompletion:^{
            [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
            [SVProgressHUD showErrorWithStatus:failure];
        }];
        
        return;
    }
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeNone];
    [SVProgressHUD showErrorWithStatus:failure];
}

+ (BOOL)isVisible {
    return SVProgressHUD.isVisible;
}

@end
