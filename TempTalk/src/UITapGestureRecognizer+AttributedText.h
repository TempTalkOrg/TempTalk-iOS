//
//  UITapGestureRecognizer+AttributedText.h
//  Wea
//
//  Created by Kris.s on 2021/12/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITapGestureRecognizer (AttributedText)

- (BOOL)didTapAttributedTextInLabel:(UILabel *)label inRanges:(NSArray *)ranges;

@end

NS_ASSUME_NONNULL_END
