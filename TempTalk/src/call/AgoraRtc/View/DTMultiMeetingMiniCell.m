//
//  DTMultiMeetingMiniCell.m
//  Signal
//
//  Created by Ethan on 2022/7/29.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTMultiMeetingMiniCell.h"
#import <PureLayout/PureLayout.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIColor+OWS.h>
#import <Lottie/Lottie-Swift.h>
#import "TempTalk-Swift.h"

@interface DTMultiMeetingMiniCell ()

@property (nonatomic, strong) AvatarImageView *headImage;
@property (nonatomic, strong) UILabel *lbName;
@property (nonatomic, strong) UILabel *lbHost;
@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIImageView *sharingIcon;
@property (nonatomic, strong) UIView *spacer;
@property (nonatomic, strong) UIButton *btnMenu;
@property (nonatomic, strong) LottieAnimationView *animationSpeaking;

@end

@implementation DTMultiMeetingMiniCell

+ (NSString *)reuseIdentifier {
    
    return [NSString stringWithFormat:@"%@ID", NSStringFromClass([self class])];
}

- (void)prepareForReuse {
    
    [super prepareForReuse];
    
    self.headImage.image = nil;
    self.lbName.text = nil;
    self.muteIcon.image = nil;
    self.sharingIcon.hidden = YES;
}

- (void)setItemModel:(DTMultiChatItemModel *)itemModel {
    _itemModel = itemModel;
    
    NSString *recipientId = [itemModel.recipientId componentsSeparatedByString:@"."].firstObject;
    
    [self.headImage setImageWithRecipientId:recipientId
                                displayName:itemModel.displayName
                               asyncMaxSize:5 * 1024 * 1024];
    self.lbName.text = itemModel.displayName;
    self.sharingIcon.hidden = !itemModel.isSharing;
    self.lbHost.hidden = !itemModel.isHost;
    self.spacer.hidden = itemModel.isSharing;
    self.animationSpeaking.hidden = !itemModel.isSpeaking;
    if (!itemModel.isSpeaking) {
        if (itemModel.isMute) {
            self.muteIcon.image = [UIImage imageNamed:@"ic_call_muted"];
        } else {
            self.muteIcon.image = [UIImage imageNamed:@"ic_call_unmuted"];
        }
    }
    
    BOOL isLiveStreamGuest = (itemModel.role == LiveStreamRoleAudience);
    self.muteIcon.hidden = isLiveStreamGuest;
}

- (void)setDisplayBackground:(BOOL)needBackground
               displayCorner:(BOOL)displayCorner {
    
    if (needBackground) {
        self.contentView.backgroundColor = [UIColor ows_tabbarNormalColor];
    } else {
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    
    self.contentView.layer.cornerRadius = displayCorner ? 8 : 0;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initUI];
    }
    return self;
}

- (void)initUI {
    
    self.backgroundColor = [UIColor clearColor];
    self.contentView.layer.masksToBounds = YES;
    self.contentView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    
    [self.contentView addSubview:self.headImage];
    [self.muteIcon addSubview:self.animationSpeaking];
    UIStackView *vStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.lbName, self.lbHost]];
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.spacing = 2;

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[vStackView, self.spacer, self.sharingIcon, self.muteIcon]];
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.spacing = 6;
    [self.contentView addSubview:stackView];
    
    [self.headImage autoSetDimensionsToSize:CGSizeMake(32, 32)];
    [self.headImage autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:8];
    [self.headImage autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    
    [self.sharingIcon autoSetDimensionsToSize:CGSizeMake(20, 28)];
    [self.muteIcon autoSetDimensionsToSize:CGSizeMake(20, 28)];
    [self.spacer autoSetDimensionsToSize:CGSizeMake(12, 28)];
    [self.animationSpeaking autoPinEdgesToSuperviewEdges];
    
    [stackView autoPinEdge:ALEdgeLeading toEdge:ALEdgeTrailing ofView:self.headImage withOffset:8];
    [stackView autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [stackView autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:8];
}

- (void)setupMuteGesture:(UIView *)view {
    view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMuteClick)];
    [view addGestureRecognizer:tapGesture];
}

- (void)handleMuteClick {
    if (!self.itemModel.isMute) {
        [[DTMeetingManager shared] showScreenShareAlertVC:self.itemModel.recipientId];
    }
}

#pragma mark - lazy layout

- (AvatarImageView *)headImage {
    if (!_headImage) {
        _headImage = [AvatarImageView new];
        _headImage.image = [UIImage imageNamed:@"profile_avatar_default"];
    }
    
    return _headImage;
}

- (UILabel *)lbName {
    if (!_lbName) {
        _lbName = [UILabel new];
        _lbName.textAlignment = NSTextAlignmentLeft;
        _lbName.font = [UIFont systemFontOfSize:14];
        _lbName.textColor = [UIColor whiteColor];
        [_lbName setCompressionResistanceHorizontalLow];
        [_lbName setContentHuggingHorizontalLow];
    }
    
    return _lbName;
}

- (UILabel *)lbHost {
    if (!_lbHost) {
        _lbHost = [UILabel new];
        _lbHost.text = @"Host";
        _lbHost.textColor = [UIColor ows_tabbarNormalDarkColor];
        _lbHost.font = [UIFont systemFontOfSize:12];
    }
    return _lbHost;
}

- (UIImageView *)muteIcon {
    if (!_muteIcon) {
        _muteIcon = [UIImageView new];
        _muteIcon.image = [UIImage imageNamed:@"ic_call_muted"];
        _muteIcon.contentMode = UIViewContentModeCenter;
        [self setupMuteGesture:_muteIcon];
    }
    
    return _muteIcon;
}

- (UIImageView *)sharingIcon {
    if (!_sharingIcon) {
        _sharingIcon = [UIImageView new];
        _sharingIcon.image = [UIImage imageNamed:@"ic_call_list_sharing"];
        _sharingIcon.contentMode = UIViewContentModeCenter;
        _sharingIcon.hidden = YES;
    }
    
    return _sharingIcon;
}

- (UIView *)spacer {
    if (!_spacer) {
        _spacer = [UIView new];
        _spacer.hidden = YES;
    }
    return _spacer;
}

- (LottieAnimationView *)animationSpeaking {
    if (!_animationSpeaking) {
        _animationSpeaking = [DTLottieBridge animationViewWithName:@"Meeting_audio"];
        _animationSpeaking.hidden = YES;
        [self setupMuteGesture:_animationSpeaking];
    }
    
    return _animationSpeaking;
}


@end
