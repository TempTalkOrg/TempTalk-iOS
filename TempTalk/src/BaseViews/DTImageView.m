//
//  DTImageView.m
//  Signal
//
//  Created by Kris.s on 2021/9/10.
//

#import "DTImageView.h"

@interface DTImageView ()

@property (nonatomic, strong) UITapGestureRecognizer *tagGesture;

@end

@implementation DTImageView

- (instancetype)init{
    if(self = [super init]){
        self.tagGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
        [self addGestureRecognizer:self.tagGesture];
        
        self.titleLable = [UILabel new];
        self.titleLable.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.titleLable];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect bounds = self.bounds;

    CGFloat widthDelta = MAX(44.0 - bounds.size.width, 0);
    CGFloat heightDelta = MAX(44.0 - bounds.size.height, 0);

    bounds = CGRectInset(bounds, -0.5 * widthDelta, -0.5 * heightDelta);

    return CGRectContainsPoint(bounds, point) && self.alpha > 0 && !self.isHidden ? self : nil;
}

- (void)tapAction:(id)sender{
    if(self.tapBlock){
        self.tapBlock(self);
    }
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.titleLable.frame = self.bounds;
}

@end
