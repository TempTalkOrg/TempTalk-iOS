//
//  DTButton.m
//  Signal
//
//  Created by Kris.s on 2021/9/10.
//

#import "DTButton.h"

@implementation DTButton

- (instancetype)init{
    if(self = [super init]){
        [self addTarget:self action:@selector(clickAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event

{
    CGRect bounds = self.bounds;

    CGFloat widthDelta = MAX(44.0 - bounds.size.width, 0);
    CGFloat heightDelta = MAX(44.0 - bounds.size.height, 0);

    bounds = CGRectInset(bounds, -0.5 * widthDelta, -0.5 * heightDelta);

    return CGRectContainsPoint(bounds, point);

}

- (void)clickAction:(id)sender{
    if(self.clickActionBlock){
        self.clickActionBlock(self);
    }
}

//- (void)layoutSubviews{
//    [super layoutSubviews];
//
//    // the space between the image and text
//    CGFloat spacing = 6.0;
//
//    // lower the text and push it left so it appears centered
//    //  below the image
//    CGSize imageSize = self.imageView.image.size;
//    self.titleEdgeInsets = UIEdgeInsetsMake(
//      0.0, - imageSize.width, 0.0, 0.0);
//
//    // raise the image and push it right so it appears centered
//    //  above the text
//    CGSize titleSize = [self.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: self.titleLabel.font}];
//    self.imageEdgeInsets = UIEdgeInsetsMake(
//      - (titleSize.height + spacing), 0.0, 0.0, - titleSize.width);
//
//    // increase the content height to avoid clipping
//    CGFloat edgeOffset = fabs(titleSize.height - imageSize.height) / 2.0;
//    self.contentEdgeInsets = UIEdgeInsetsMake(edgeOffset, 0.0, edgeOffset, 0.0);
//}

@end
