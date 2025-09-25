//
//  UINavigationController+Navigation.h
//  TTMessaging
//
//  Created by hornet on 2021/12/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UINavigationController (Navigation)

- (void)removeToViewController:(NSString * __nullable)className;
@end

NS_ASSUME_NONNULL_END
