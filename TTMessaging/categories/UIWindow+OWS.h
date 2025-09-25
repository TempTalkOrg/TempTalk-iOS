//
//  UIWindow+OWS.h
//  TTMessaging
//
//  Created by Ethan on 2022/8/20.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIWindow (OWS)

// 获取当前最上层的控制器
- (UIViewController *)findTopViewController;

@end

NS_ASSUME_NONNULL_END
