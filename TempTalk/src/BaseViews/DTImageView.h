//
//  DTImageView.h
//  Signal
//
//  Created by Kris.s on 2021/9/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTImageView : UIImageView

@property (nonatomic, strong) void (^tapBlock)(DTImageView *imageView);
@property (nonatomic, strong) UILabel *titleLable;

@end

NS_ASSUME_NONNULL_END
