//
//  UIButton+DTAppEnlargeEdge.h
//  TTServiceKit
//
//  Created by hornet on 2022/2/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIButton (DTAppEnlargeEdge)

#pragma mark - usingMethods
- (void)dtApp_setEnlargeEdgeWithTop:(CGFloat)top right:(CGFloat)right bottom:(CGFloat)bottom left:(CGFloat)left;


#pragma mark - deprecatedMethods
/**
 增大按钮点击区域扩展

 @param size 增大大小
 */
- (void)setEnlargeEdge:(CGFloat) size;

@end

NS_ASSUME_NONNULL_END
