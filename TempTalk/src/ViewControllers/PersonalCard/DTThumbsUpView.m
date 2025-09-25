//
//  DTThumbsUpView.m
//  Wea
//
//  Created by hornet on 2022/7/28.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTThumbsUpView.h"
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <PureLayout/PureLayout.h>
#import <TTServiceKit/UIButton+DTAppEnlargeEdge.h>

@interface DTThumbsUpView()
@property (nonatomic, strong) UIButton *thumpUpIconButton;
@property (nonatomic, strong) UILabel *thumpNumbersLabel;
@end

@implementation DTThumbsUpView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpSubViews];
        [self configLayout];
        self.thumpNumbersLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x707A8A];
        self.thumpNumbersLabel.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setUpSubViews {
    [self addSubview:self.thumpUpIconButton];
    [self addSubview:self.thumpNumbersLabel];
}

- (void)configLayout {
    [self.thumpUpIconButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.thumpUpIconButton autoSetDimension:ALDimensionWidth toSize:20];
    [self.thumpUpIconButton autoSetDimension:ALDimensionHeight toSize:20];
    [self.thumpUpIconButton autoVCenterInSuperview];
    
    [self.thumpNumbersLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:self.thumpUpIconButton withOffset:6];
    [self.thumpNumbersLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self withOffset:0];
    [self.thumpNumbersLabel autoVCenterInSuperview];
}

- (void)setThumbsUpCount:(NSString *)thumbsUpCount {
    _thumbsUpCount = thumbsUpCount;
    self.thumpNumbersLabel.text = [NSString stringWithFormat:@"%@",thumbsUpCount];
}

- (void)thumpUpIconButtonClick:(UIButton *)sender {
    if (self.thumbsUpViewDelegate && [self.thumbsUpViewDelegate respondsToSelector:@selector(thumbsUpView:thumpUpIconBtnClick:)]) {
        [self.thumbsUpViewDelegate thumbsUpView:self thumpUpIconBtnClick:sender];
    }
}

- (UIButton *)thumpUpIconButton {
    if (!_thumpUpIconButton) {
        _thumpUpIconButton = [UIButton new];
        [_thumpUpIconButton addTarget:self action:@selector(thumpUpIconButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_thumpUpIconButton dtApp_setEnlargeEdgeWithTop:10 right:20 bottom:0 left:10];
        [_thumpUpIconButton setBackgroundImage:[UIImage imageNamed:@"vector_small_icon"] forState:UIControlStateNormal];
        [_thumpUpIconButton setBackgroundImage:[UIImage imageNamed:@"vector_small_icon"] forState:UIControlStateSelected];
    }
    return _thumpUpIconButton;
}

- (UILabel *)thumpNumbersLabel {
    if (!_thumpNumbersLabel) {
        _thumpNumbersLabel = [UILabel new];
        _thumpNumbersLabel.font = [UIFont systemFontOfSize:14];
    }
    return _thumpNumbersLabel;
}

@end
