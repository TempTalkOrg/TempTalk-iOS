//
//  UIButton+DTSExtend.h
//  DTSClassRoom
//
//  Created by hornet on 2021/11/16.
//

#import <UIKit/UIKit.h>

@interface UIButton (DTSExtend)

/**
 设置不同状态下的按钮背景颜色
 */
- (void)setBackgroundColor:(UIColor *)backgroundColor forState:(UIControlState)state;
    
@end
