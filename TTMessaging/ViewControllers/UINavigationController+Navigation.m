//
//  UINavigationController+Navigation.m
//  TTMessaging
//
//  Created by hornet on 2021/12/5.
//
#define kBlockSafeRun(block, ...)   !block ?: block(__VA_ARGS__)

#import "UINavigationController+Navigation.h"

@implementation UINavigationController (Navigation)
- (void)removeToViewController:(NSString * __nullable)className {
    if (!className && className.length <= 0) {
        return;
    }
    
    OWSLogDebug(@"Navigation remove to %@", className);
    
    __block NSInteger indexOfController = -1;
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController *obj, NSUInteger idx, BOOL *stop) {
        if ([NSStringFromClass([obj class]) isEqualToString:className]) {
            indexOfController = (NSInteger)idx;
            *stop = YES;
        }
    }];
    //如果移动到中间节点
    if (indexOfController >= 0 && indexOfController < (NSInteger)self.viewControllers.count - 1 && self.viewControllers.count>=3) {
        NSInteger length = (NSInteger)self.viewControllers.count -(NSInteger)(indexOfController+1) -1;
        if (length==0) {
            return;
        }
        NSMutableArray *tempControllers = [self.viewControllers mutableCopy];
        [tempControllers removeObjectsInRange:NSMakeRange((NSUInteger)indexOfController+1, (NSUInteger)length)];
        self.viewControllers = tempControllers;
    }
}
@end
