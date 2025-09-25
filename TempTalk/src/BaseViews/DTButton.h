//
//  DTButton.h
//  Signal
//
//  Created by Kris.s on 2021/9/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTButton : UIButton

@property (nonatomic, assign) CGVector insetVector;

@property (nonatomic, strong) void (^clickActionBlock)(DTButton *button);

@end

NS_ASSUME_NONNULL_END
