//
//  DTToastHelper.h
//  TTServiceKit
//
//  Created by hornet on 2021/11/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTToastHelper : NSObject


+ (DTToastHelper *)sharedHelper;
- (UIWindow *)frontWindow;

/// 展示Hub 默认会展示在最顶层的window 上
+ (void)show;

/// 展示loading   showHudInView
/// @param view 父view
+ (void)showHudInView:(UIView *)view;

///隐藏Hub
+ (void)hide;

/// 展示loading   showHudInView
/// @param message 消息
/// @param view 父view
+ (void)showHudWithMessage:(NSString *)message inView:(UIView *)view;

+ (void)toastWithText:(NSString *)message;

/// toast 弹窗 不含loading页面
/// @param message toast 提示信息
/// @param duration 持续时间
+ (void)toastWithText:(NSString *)message
         durationTime:(NSTimeInterval) duration;

///  toast 弹窗 不含loading页面
/// @param message  toast 提示信息
/// @param duration 持续时间
/// @param delayTime 延迟执行时间
+ (void)toastWithText:(NSString *)message
         durationTime:(NSTimeInterval) duration
           afterDelay:(NSTimeInterval) delayTime;

/// toast 弹窗 不含loading页面
/// @param message toast 提示信息
/// @param duration 持续时间
/// @param completion 完成回调
+ (void)toastWithText:(NSString *)message
         durationTime:(NSTimeInterval)duration
           completion:(void(^)(void))completion;

/// toast 弹窗 仅包含文字提示
/// @param message 提示信息
/// @param view 父view
/// @param duration   文字提示的持续时间
/// @param delayTime  单位s    延迟**s之后进行展示
+ (void)toastWithText:(NSString *)message
               inView:(UIView *)view
         durationTime:(NSTimeInterval) duration
           afterDelay:(NSTimeInterval) delayTime;

/// 设置HUD样式
+ (void)setupSVProgressHUDAppearence;

/// loading
+ (void)svShow;

+ (void)_showError:(NSString *)error;

+ (void)_showSuccess:(NSString *)success;

/// loading dimiss
+ (void)dismiss;

/// loading dimiss after N seconds
/// - Parameter delay: loading duration
+ (void)dismissWithDelay:(NSTimeInterval)delay;

/// loading dimiss then show info
/// - Parameter info: info
+ (void)dismissWithInfo:(NSString *)info;

/// loading dimiss after N seconds then show info
/// - Parameters:
///   - info: info
///   - delay: loading duration
+ (void)dismissWithInfo:(NSString *)info
                  delay:(NSTimeInterval)delay;

/// loading dimiss then show info and do something
/// - Parameters:
///   - info: info
///   - completion: completion
+ (void)dismissWithInfo:(NSString *)info
             completion:(void(^)(void))completion;

/// loading dimiss after N seconds then show info and do something
/// - Parameters:
///   - info: info
///   - delay: loading duration
///   - completion: completion
+ (void)dismissWithInfo:(NSString *)info
                  delay:(NSTimeInterval)delay
             completion:(void(^ _Nullable)(void))completion;

+ (void)dismissWithDelay:(NSTimeInterval)delay
              completion:(void(^)(void))completion;

/// toast
/// - Parameter info: toast string
+ (void)showWithInfo:(NSString *)info;

/// loading with text
/// - Parameter status: text
+ (void)showWithStatus:(NSString *)status;

/// 带图标
+ (void)showSuccess:(nullable NSString *)success;
+ (void)showFailure:(nullable NSString *)failure;
+ (void)showInfo:(NSString *)info;

+ (void)allowInteraction:(BOOL)isAllow;

+ (BOOL)isVisible;
// 展示01 lottie的视图
+ (void)show01LoadingHudIsDark:(BOOL)isDark inView:(nullable UIView *)view;

@end

NS_ASSUME_NONNULL_END
