//
//  DTQuickActionCell.m
//  Wea
//
//  Created by hornet on 2022/5/27.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTQuickActionCell.h"
#import "DTLayoutButton.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTServiceKit/Localize_Swift.h>

@interface DTQuickActionCell()
@property (nonatomic, strong) UIStackView *quickActionStackView;
@property (nonatomic, strong) DTLayoutButton *shareButton;//分享
@property (nonatomic, strong) DTLayoutButton *callButton;//语音
@property (nonatomic, strong) DTLayoutButton *messageButton;//消息
@end

@implementation DTQuickActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
    }
    return self;
}

- (void)setupAllSubViews {
    [self setupUI];
}

- (void)setupUI {
    [self.contentView addSubview:self.quickActionStackView];
    
    [self.quickActionStackView addArrangedSubview:self.messageButton];
    if (self.haveCall) {
        [self.quickActionStackView addArrangedSubview:self.callButton];
        self.callButton.hidden = false;
    } else {
        self.callButton.hidden = true;
    }
    [self.quickActionStackView addArrangedSubview:self.shareButton];
    [self.quickActionStackView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self];
    [self.quickActionStackView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self withOffset:-24];
    [self.quickActionStackView autoPinLeadingToEdgeOfView:self.contentView offset:16.0];
    [self.quickActionStackView autoHCenterInSuperview];
}

- (void)setIsFriend:(BOOL)isFriend {
    _isFriend = isFriend;
    if (isFriend) {
        [self.shareButton setImage:[[UIImage imageNamed:@"user_share_contact"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [self.shareButton setTitle:Localized(@"PERSON_CARD_SHARE_CARD",@"") forState:UIControlStateNormal];
    } else {
        [self.shareButton setImage:[[UIImage imageNamed:@"ask_friend"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [self.shareButton setTitle:Localized(@"Add Contact",@"") forState:UIControlStateNormal];
    }
}

- (void)shareButtonAction:(DTLayoutButton *)sender {
    if ([self.cellDelegate respondsToSelector:@selector(quickActionCell:button:actionType:)]) {
        [self.cellDelegate quickActionCell:self button:sender actionType:DTQuickActionTypeShare];
    }
}

- (void)callButtonAction:(DTLayoutButton *)sender {
    if ([self.cellDelegate respondsToSelector:@selector(quickActionCell:button:actionType:)]) {
        [self.cellDelegate quickActionCell:self button:sender actionType:DTQuickActionTypeCall];
    }
}

- (void)messageButtonAction:(DTLayoutButton *)sender {
    if ([self.cellDelegate respondsToSelector:@selector(quickActionCell:button:actionType:)]) {
        [self.cellDelegate quickActionCell:self button:sender actionType:DTQuickActionTypeMessage];
    }
}

- (DTLayoutButton *)shareButton {
    if (!_shareButton) {
        _shareButton = [DTLayoutButton new];
        [_shareButton setImage:[[UIImage imageNamed:@"user_share_contact"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _shareButton.layer.cornerRadius = 8;
        _shareButton.clipsToBounds = true;
        _shareButton.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xFFFFFF];
        _shareButton.titleAlignment = DTButtonTitleAlignmentTypeBottom;
        _shareButton.spacing = 13;
        _shareButton.tintColor = Theme.isDarkThemeEnabled ? UIColor.whiteColor : UIColor.blackColor;
        [_shareButton setTitleColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329] forState:UIControlStateNormal];
        [_shareButton addTarget:self action:@selector(shareButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _shareButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_shareButton setTitle:Localized(@"PERSON_CARD_SHARE_CARD",@"") forState:UIControlStateNormal];
    }
    return _shareButton;
}

- (DTLayoutButton *)callButton {
    if (!_callButton) {
        _callButton = [DTLayoutButton new];
        [_callButton setImage:[UIImage imageNamed:@"user_voice_call"] forState:UIControlStateNormal];
        _callButton.layer.cornerRadius = 8;
        _callButton.clipsToBounds = true;
        _callButton.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xFFFFFF];
        _callButton.titleAlignment = DTButtonTitleAlignmentTypeBottom;
        _callButton.tintColor = Theme.isDarkThemeEnabled ? UIColor.whiteColor : UIColor.blackColor;
        [_callButton setTitleColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329] forState:UIControlStateNormal];
        [_callButton addTarget:self action:@selector(callButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _callButton.spacing = 13;
        _callButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_callButton setTitle:Localized(@"PERSON_CARD_VOICE_CALL",@"") forState:UIControlStateNormal];
    }
    return _callButton;
}

- (DTLayoutButton *)messageButton {
    if (!_messageButton) {
        _messageButton = [DTLayoutButton new];
        _messageButton.layer.cornerRadius = 8;
        _messageButton.clipsToBounds = true;
        [_messageButton setImage:[[UIImage imageNamed:@"user_send_message"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _messageButton.layer.cornerRadius = 8;
        _messageButton.clipsToBounds = true;
        _messageButton.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xFFFFFF];
        [_messageButton addTarget:self action:@selector(messageButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _messageButton.spacing = 13;
        _messageButton.tintColor = Theme.isDarkThemeEnabled ? UIColor.whiteColor : UIColor.blackColor;
        [_messageButton setTitleColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329] forState:UIControlStateNormal];
        _messageButton.titleAlignment = DTButtonTitleAlignmentTypeBottom;
        _messageButton.titleLabel.font = [UIFont systemFontOfSize:12];
        [_messageButton setTitle:Localized(@"PERSON_CARD_SEND_MESSAGE",@"") forState:UIControlStateNormal];
    }
    return _messageButton;
}

- (UIStackView *)quickActionStackView {
    if (!_quickActionStackView) {
        _quickActionStackView = [[UIStackView alloc] init];
        _quickActionStackView.axis = UILayoutConstraintAxisHorizontal;
        _quickActionStackView.alignment = UIStackViewAlignmentFill;
        _quickActionStackView.distribution = UIStackViewDistributionFillEqually;
        _quickActionStackView.layoutMargins = UIEdgeInsetsMake(0, 0, 0, 0);
        _quickActionStackView.spacing = 8;
    }
    return _quickActionStackView;
}

@end
