//
//  DTMentionMsgsIndicatorView.m
//  Signal
//
//  Created by Kris.s on 2022/7/21.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTMentionMsgsIndicatorView.h"
#import <PureLayout/PureLayout.h>
#import "UIColor+OWS.h"
#import "UIView+SignalUI.h"
#import "Theme.h"

@interface DTMentionMsgsIndicatorView ()

@property (nonatomic, strong) UIButton *titleBtn;
@property (nonatomic, strong) UILabel *badgeLabel;

@end

@implementation DTMentionMsgsIndicatorView

- (UIButton *)titleBtn{
    if(!_titleBtn){
        _titleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_titleBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_titleBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
        _titleBtn.layer.masksToBounds = YES;
        _titleBtn.backgroundColor = [UIColor ows_materialBlueColor];
        [_titleBtn setTitle:@"@" forState:UIControlStateNormal];
        [_titleBtn addTarget:self action:@selector(tapAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _titleBtn;
}

- (UILabel *)badgeLabel{
    if(!_badgeLabel){
        _badgeLabel = [UILabel new];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.font = [UIFont systemFontOfSize:10.0];
        _badgeLabel.layer.masksToBounds = YES;
        _badgeLabel.backgroundColor = Theme.redBgroundColor;
    }
    return _badgeLabel;
}

- (instancetype)init{
    if(self = [super init]){
        [self setup];
    }
    return self;
}

+ (CGFloat)circleSize
{
    return ScaleFromIPhone5To7Plus(35.f, 40.f);
}

- (void)setup{
    self.backgroundColor = [UIColor clearColor];
    
    [self addSubview:self.titleBtn];
    [self addSubview:self.badgeLabel];
    
//    [self.titleBtn autoCenterInSuperview];
    [self.titleBtn autoHCenterInSuperview];
    [self.titleBtn autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self];
    [self.titleBtn autoSetDimensionsToSize:CGSizeMake([[self class] circleSize], [[self class] circleSize])];

//    [self.badgeLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.titleBtn];
//    [self.badgeLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.titleBtn];
//    [self.badgeLabel autoSetDimensionsToSize:CGSizeMake(16.0, 16.0)];
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.titleBtn.layer.cornerRadius = CGRectGetWidth(self.titleBtn.bounds) / 2.0;
    
    CGFloat minSize = 16.0;
    CGFloat width = minSize + (self.badgeLabel.text.length - 1) * 4.0;
    self.badgeLabel.frame = CGRectMake(CGRectGetMaxX(self.titleBtn.frame) - width/2.0 - 4.0, CGRectGetMinY(self.titleBtn.frame), width, minSize);
    
    self.badgeLabel.layer.cornerRadius = CGRectGetHeight(self.badgeLabel.bounds) / 2.0;
    
}

- (void)tapAction:(id)sender{
    if(self.tapBlock){
        self.tapBlock();
    }
}

- (void)setBadgeCount:(NSString *)badgeCount{
    _badgeCount = badgeCount;
    self.badgeLabel.text = badgeCount;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

@end
