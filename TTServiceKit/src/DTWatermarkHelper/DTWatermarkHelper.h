//
//  DTWatermarkHelper.h
//  TTServiceKit
//
//  Created by hornet on 2021/11/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTWatermarkHelper : NSObject
+ (void)addWatermarkToTheVisiableWindow;
+ (void)removeWatermarkFromWindow;


+ (void)addWatermarkToTheView:(UIView *)view;
+ (void)removeWatermarkFromView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
