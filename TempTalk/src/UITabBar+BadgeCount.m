//
//  UITabBar+BadgeCount.m
//  Wea
//
//  Created by hornet on 2022/1/22.
//

#import "UITabBar+BadgeCount.h"
#import <TTMessaging/Theme.h>
#import <PureLayout/PureLayout.h>

#define TabbarItemNums 4.0
@implementation UITabBar (BadgeCount)
// 显示红点
- (void)showBadgeOnItemIndex:(int)index {

    [self removeBadgeOnItemIndex:index];
    // 新建小红点
    UIView *bview = [[UIView alloc]init];
    bview.tag = 888 + index;
    bview.layer.cornerRadius = 5;
    bview.clipsToBounds = YES;
    bview.backgroundColor = Theme.redBgroundColor;
    CGRect tabFram = self.frame;
    
    float percentX = (float)((index+0.6) / TabbarItemNums);
    float x = ceilf((float)(percentX * tabFram.size.width));
    float y = ceilf((float)(0.06 * tabFram.size.height));
    bview.frame = CGRectMake(x, y, 10, 10);
    [self addSubview:bview];
    [self bringSubviewToFront:bview];
}

- (void)updateBadgeOnItem:(NSUInteger)index 
               badgeValue:(NSUInteger)badgeValue {

    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [self removeBadgeOnItemIndex:(int)index];

    if (badgeValue == 0) return;
    
    UIView *backgroundView = [UIView new];
    backgroundView.tag = 888 + (NSInteger)index;
    backgroundView.layer.cornerRadius = 9;
    backgroundView.clipsToBounds = YES;
    backgroundView.backgroundColor = Theme.redBgroundColor;
    
    [self addSubview:backgroundView];
    [self bringSubviewToFront:backgroundView];
    
    UILabel *lb = [UILabel new];
    lb.textColor = UIColor.whiteColor;
    lb.textAlignment = NSTextAlignmentCenter;
    lb.font = [UIFont systemFontOfSize:13];
    if (badgeValue <= 99) {
        lb.text = [NSString stringWithFormat:@"%lu", badgeValue];
    } else {
        lb.text = @"99+";
    }
    [backgroundView addSubview:lb];
    
    CGRect tabFram = self.frame;
    float percentX = (float)((index+0.55) / TabbarItemNums);
    float x = ceilf((float)(percentX * tabFram.size.width));
    
    [backgroundView autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:x];
    [backgroundView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:3];
    [backgroundView autoSetDimension:ALDimensionHeight
                              toSize:18];
    [backgroundView autoSetDimension:ALDimensionWidth 
                              toSize:18
                            relation:NSLayoutRelationGreaterThanOrEqual];
    [backgroundView autoMatchDimension:ALDimensionWidth 
                           toDimension:ALDimensionWidth
                                ofView:lb
                            withOffset:10];

    [lb autoCenterInSuperview];
}

// 隐藏红点
- (void)hideBadgeOnItemIndex:(int)index {

    [self removeBadgeOnItemIndex:index];
}
// 移除控件
- (void)removeBadgeOnItemIndex:(int)index {

    for (UIView *subView in self.subviews) {
        if (subView.tag == 888 + index) {
            [subView removeFromSuperview];
        }
    }
}
@end
