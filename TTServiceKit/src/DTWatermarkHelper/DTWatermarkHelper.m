//
//  DTWatermarkHelper.m
//  TTServiceKit
//
//  Created by hornet on 2021/11/24.
//

#import "DTWatermarkHelper.h"
#import "DTWatermarkLayer.h"
#import "TSAccountManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTWatermarkHelper


//在当前显示的window上添加水印
+ (void)addWatermarkToTheVisiableWindow {

    UIWindow *visiableWindow = [self frontWindow];
    if (!visiableWindow) {
        return;
    }
    //包含水印了，不再重复添加
    __block DTWatermarkLayer *preWatermarkLayer;
    [visiableWindow.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:DTWatermarkLayer.class]) {
                preWatermarkLayer = (DTWatermarkLayer *)obj;
                *stop = YES;
            }
    }];
    if (preWatermarkLayer) {
        [preWatermarkLayer removeFromSuperlayer];
    }
    NSString *string = [TSAccountManager sharedInstance].localNumber;
    DTWatermarkLayer *watermarkLayer = [[DTWatermarkLayer alloc] initWithFrame:visiableWindow.bounds LayeString:string?:TSConstants.appDisplayName];
    watermarkLayer.backgroundColor = [UIColor redColor].CGColor;
    watermarkLayer.zPosition = 1000;
    [visiableWindow.layer addSublayer:watermarkLayer];
    
}

+ (void)addWatermarkToTheView:(UIView *)view {
    if (!view) {
        return;
    }
    
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        __block DTWatermarkLayer *preWatermarkLayer;
        [view.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:DTWatermarkLayer.class]) {
                preWatermarkLayer = (DTWatermarkLayer *)obj;
                *stop = YES;
            }
        }];
        
        if (preWatermarkLayer) { // 包含水印了，不再重复添加
            return;
        }
        
        NSString *string = [TSAccountManager sharedInstance].localNumber;
        DTWatermarkLayer *watermarkLayer = [[DTWatermarkLayer alloc] initWithFrame:view.bounds LayeString:string ?: TSConstants.appDisplayName];
        watermarkLayer.backgroundColor = [UIColor redColor].CGColor;
        watermarkLayer.zPosition = 1000;
        [view.layer addSublayer:watermarkLayer];
    });
}

+ (void)removeWatermarkFromView:(UIView *)view {
    if (!view) {
        return;
    }
    
    __block DTWatermarkLayer *preWatermarkLayer;
    [view.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:DTWatermarkLayer.class]) {
            preWatermarkLayer = (DTWatermarkLayer *)obj;
            *stop = YES;
        }
    }];
    [preWatermarkLayer removeFromSuperlayer];
}


+ (void)removeWatermarkFromWindow {
    UIWindow *visiableWindow = [self frontWindow];
    if (!visiableWindow) {
        return;
    }
    //包含水印了，不再重复添加
    __block DTWatermarkLayer *preWatermarkLayer;
    [visiableWindow.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:DTWatermarkLayer.class]) {
            preWatermarkLayer = (DTWatermarkLayer *)obj;
            *stop = YES;
        }
    }];
    [preWatermarkLayer removeFromSuperlayer];
    
}

+ (UIWindow *)frontWindow {
    NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
    for (UIWindow *window in frontToBackWindows) {
        BOOL windowOnMainScreen = window.screen == UIScreen.mainScreen;
        BOOL windowIsVisible = !window.hidden && window.alpha > 0;
        BOOL windowLevelSupported = (window.windowLevel >= UIWindowLevelNormal && window.windowLevel <= UIWindowLevelNormal);
        BOOL windowKeyWindow = window.isKeyWindow;
            
        if(windowOnMainScreen && windowIsVisible && windowLevelSupported && windowKeyWindow) {
            return window;
        }
    }
    return nil;
}

@end
