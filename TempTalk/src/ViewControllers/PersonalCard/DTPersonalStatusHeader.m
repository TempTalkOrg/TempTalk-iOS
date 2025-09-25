//
//  DTPersonalStatusHeader.m
//  Wea
//
//  Created by user on 2022/9/2.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTPersonalStatusHeader.h"
#import "Theme.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import <TTMessaging/UIView+SignalUI.h>
#import <TTServiceKit/Localize_Swift.h>
#import <PureLayout/PureLayout.h>

@interface DTPersonalStatusHeader()

@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *clearLabel;
@property (nonatomic, strong) UIButton *clearButton;
@end

@implementation DTPersonalStatusHeader

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
        [self setupLayout];
    }
    return self;
}

- (void)updateInfo:(NSString *_Nullable)title {
    if (title && title.length > 0) {
        self.infoLabel.text = title;
        self.clearLabel.textColor = Theme.primaryTextColor;
    } else {
        self.infoLabel.text = Localized(@"PERSON_CARD_STATE_SETTING_TIME", @"");
        self.clearLabel.textColor = Theme.ternaryTextColor;
    }
}

- (void)setupViews {
    _infoLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.textColor = Theme.ternaryTextColor;
        label.font = [UIFont ows_regularFontWithSize:16.f];
        label.text = Localized(@"PERSON_CARD_STATE_SETTING_TIME", @"");
        label;
    });
    
    _clearLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.textColor = Theme.ternaryTextColor;
        label.font = [UIFont ows_regularFontWithSize:18.f];
        label.text = Localized(@"PERSON_CARD_STATE_CLEAR", @"");
        label;
    });
    
    _clearButton = [[UIButton alloc] init];
    [_clearButton addTarget:self action:@selector(didClickClearButton) forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:_infoLabel];
    [self addSubview:_clearLabel];
    [self addSubview:_clearButton];
}

- (void)setupLayout {
    [self.infoLabel autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:20];
    [self.infoLabel autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.infoLabel autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [self.infoLabel autoSetDimension:ALDimensionHeight toSize:60];
    
    [self.clearLabel autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:20];
    [self.clearLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.infoLabel];
    [self.clearLabel autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [self.clearLabel autoSetDimension:ALDimensionHeight toSize:60];
    
    [self.clearButton autoPinToEdgesOfView:self.clearLabel];
}

- (void)didClickClearButton{
    if (self.delegate && [self.delegate respondsToSelector:@selector(clearCurrentSetting)]) {
        [self.delegate clearCurrentSetting];
    }
}
@end
