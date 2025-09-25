//
//  DTReactionLabel.m
//  Wea
//
//  Created by Ethan on 2022/5/24.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTReactionLabel.h"
#import <TTMessaging/TTMessaging.h>

@interface DTReactionLabel ()

@end

@implementation DTReactionLabel

- (instancetype)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = YES;
        self.textAlignment = NSTextAlignmentCenter;
        self.textColor = Theme.ternaryTextColor;
        self.backgroundColor = Theme.secondaryBackgroundColor;
        self.font = [DTReactionLabel emojiLabelFont];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = [DTReactionLabel lbHeight] / 2;
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 6, 0, 6);
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

+ (DTReactionLabel *)lableWithEmojiTitle:(NSString *)emojiTitle {
        
    DTReactionLabel *lb = [DTReactionLabel new];
    lb.text = emojiTitle;
    
    [lb autoSetDimension:ALDimensionHeight toSize:[DTReactionLabel lbHeight]];
    [lb setCompressionResistanceHigh];
    [lb setContentHuggingHigh];
    
    return lb;
}

+ (UIFont *)emojiLabelFont {
    
    return [UIFont systemFontOfSize:13];
}

+ (CGFloat)lbHeight {
    
    return 24;
}

+ (CGSize)sizeWithText:(NSString *)text {
    
    CGFloat pointSize = [DTReactionLabel emojiLabelFont].pointSize;
    CGSize contentSize = [text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, [DTReactionLabel lbHeight]) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName : [DTReactionLabel emojiLabelFont]} context:nil].size;
    CGFloat finalWidth = MIN(contentSize.width, pointSize * 8);
    contentSize.width = finalWidth + 13;
    
    return contentSize;
}


@end
