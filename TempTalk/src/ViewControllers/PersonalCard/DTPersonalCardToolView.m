//
//  DTPersonalCardToolView.m
//  Wea
//
//  Created by hornet on 2021/11/15.
//

#import "DTPersonalCardToolView.h"
#import "UIView+SignalUI.h"
#import <TTServiceKit/UIButton+DTExtend.h>
//OWSViewController
@interface DTPersonalCardToolView()
@property(nonatomic,strong) UIButton *messageBtn;
@property(nonatomic,strong) UIButton *phoneBtn;
@property(nonatomic,strong) UIButton *shareBtn;
@end


@implementation DTPersonalCardToolView



#pragma mark setter & getter

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubviews];
        [self configUI];
        self.axis  = UILayoutConstraintAxisHorizontal;
        self.spacing = 45;
        self.distribution = UIStackViewDistributionEqualCentering;
    }
    
    return self;
}

- (void)addSubviews {
    [self addArrangedSubview:self.messageBtn];
    [self addArrangedSubview:self.phoneBtn];
//    [self addArrangedSubview:self.shareBtn];
}

- (void)configUI {
    [self.messageBtn autoSetDimension:ALDimensionWidth toSize:49];
    [self.messageBtn autoSetDimension:ALDimensionHeight toSize:49];
    [self.messageBtn autoVCenterInSuperview];
    
    [self.phoneBtn autoSetDimension:ALDimensionWidth toSize:49];
    [self.phoneBtn autoSetDimension:ALDimensionHeight toSize:49];
    [self.phoneBtn autoVCenterInSuperview];
    
//    [self.shareBtn autoSetDimension:ALDimensionWidth toSize:49];
//    [self.shareBtn autoSetDimension:ALDimensionHeight toSize:49];
//    [self.shareBtn autoVCenterInSuperview];
    
}

- (void)messageBtnClick:(UIButton *)sender {
    if (self.toolViewDelegate && [self.toolViewDelegate respondsToSelector:@selector(personalCardTooltoolView:senderClick:btnType:)]) {
        [self.toolViewDelegate personalCardTooltoolView:self senderClick:sender btnType:DTToolViewBtnTypeMessage];
    }
}
- (void)phoneBtnClick:(UIButton *)sender {
    if (self.toolViewDelegate && [self.toolViewDelegate respondsToSelector:@selector(personalCardTooltoolView:senderClick:btnType:)]) {
        [self.toolViewDelegate personalCardTooltoolView:self senderClick:sender btnType:DTToolViewBtnTypePhone];
    }
}

- (void)shareBtnClick:(UIButton *)sender {
    if (self.toolViewDelegate && [self.toolViewDelegate respondsToSelector:@selector(personalCardTooltoolView:senderClick:btnType:)]) {
        [self.toolViewDelegate personalCardTooltoolView:self senderClick:sender btnType:DTToolViewBtnTypeShare];
    }
}


- (UIButton *)messageBtn {
    if (!_messageBtn) {
        _messageBtn = [[UIButton alloc] init];
        [_messageBtn setBackgroundImage:[UIImage imageNamed:@"message_icon"] forState:UIControlStateNormal];
        [_messageBtn addTarget:self action:@selector(messageBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _messageBtn;
}

- (UIButton *)phoneBtn {
    if (!_phoneBtn) {
        _phoneBtn = [[UIButton alloc] init];
        [_phoneBtn setBackgroundImage:[UIImage imageNamed:@"phone_icon"] forState:UIControlStateNormal];
        [_phoneBtn addTarget:self action:@selector(phoneBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _phoneBtn;
}


- (UIButton *)shareBtn {
    if (!_shareBtn) {
        _shareBtn = [[UIButton alloc] init];
        [_shareBtn setBackgroundImage:[UIImage imageNamed:@"share_icon"] forState:UIControlStateNormal];
        [_shareBtn addTarget:self action:@selector(shareBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _shareBtn;
}
@end
