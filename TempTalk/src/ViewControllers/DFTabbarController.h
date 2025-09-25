//
//  DFTabbarController.h
//  Signal
//
//  Created by Felix on 2021/7/12.
//

#import <UIKit/UIKit.h>
@class TSThread;
NS_ASSUME_NONNULL_BEGIN

extern NSString *const kTabBarItemDoubleClickNotification;

@interface DFTabbarController : UITabBarController

- (void)reloadTodayScheduleEventCount:(NSUInteger)eventCount;

@end

NS_ASSUME_NONNULL_END
