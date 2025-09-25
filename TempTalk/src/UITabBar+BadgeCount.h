//
//  UITabBar+BadgeCount.h
//  Wea
//
//  Created by hornet on 2022/1/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITabBar (BadgeCount)
- (void)showBadgeOnItemIndex:(int)index;
- (void)hideBadgeOnItemIndex:(int)index;

- (void)updateBadgeOnItem:(NSUInteger)index
               badgeValue:(NSUInteger)badgeValue;

@end

NS_ASSUME_NONNULL_END
