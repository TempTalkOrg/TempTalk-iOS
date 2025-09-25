//
//  UIWindow+OWS.m
//  TTMessaging
//
//  Created by Ethan on 2022/8/20.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "UIWindow+OWS.h"

@implementation UIWindow (OWS)

// 获取当前最上层的控制器
- (UIViewController *)findTopViewController {
    UIViewController *topVC = self.rootViewController;
    //循环之前tempVC和topVC是一样的
    UIViewController *tempVC = topVC;
    while (1) {
        if ([topVC isKindOfClass:[UITabBarController class]]) {
            topVC = ((UITabBarController*)topVC).selectedViewController;
        }
        if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = ((UINavigationController*)topVC).visibleViewController;
        }
        if (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        //如果两者一样，说明循环结束了
        if ([tempVC isEqual:topVC] || !tempVC) {
            break;
        } else {
            //如果两者不一样，继续循环
            tempVC = topVC;
        }
    }
    return topVC;
}

@end
