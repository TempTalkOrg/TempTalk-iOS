//
//  DTThreadHeadView.m
//  Wea
//
//  Created by hornet on 2022/3/17.
//

#import "DTThreadHeadView.h"
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIView+SignalUI.h>

@interface DTThreadHeadView()

@end

@implementation DTThreadHeadView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
        [self setupLayout];
    }
    return self;
}

- (void)setupViews {
    [self addSubview:self.titleLabel];
}

- (void)setupLayout {
    [self.titleLabel autoPinEdgesToSuperviewEdges];
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:17];
        _titleLabel.textColor = Theme.primaryTextColor;
        _titleLabel.numberOfLines = 2;
    }
    return _titleLabel;
}
@end
