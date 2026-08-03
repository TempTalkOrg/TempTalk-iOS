//
//  DTTextInsetsLabel.h
//  Wea
//
//  Created by hornet on 2022/1/12.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTTextInsetsLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets; // 控制字体与控件边界的间隙
@property (nonatomic, copy, nullable) void (^onCopy)(void);
@end

NS_ASSUME_NONNULL_END
