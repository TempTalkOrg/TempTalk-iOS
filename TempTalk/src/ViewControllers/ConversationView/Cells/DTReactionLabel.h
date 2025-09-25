//
//  DTReactionLabel.h
//  Wea
//
//  Created by Ethan on 2022/5/24.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTReactionLabel : UILabel

@property (nonatomic, strong) UIColor *normalBackgroundColor;
@property (nonatomic, strong) UIColor *highlightBackgroundColor;

+ (DTReactionLabel *)lableWithEmojiTitle:(NSString *)emojiTitle;
+ (CGSize)sizeWithText:(NSString *)text;

+ (CGFloat)lbHeight;

@end

NS_ASSUME_NONNULL_END
