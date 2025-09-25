//
//  DTHomeVirtualCell.m
//  Wea
//
//  Created by Felix on 2022/5/16.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTHomeVirtualCell.h"
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIFont+OWS.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/DTVirtualThread.h>
#import "TempTalk-Swift.h"

@interface DTHomeVirtualCell()

@property (nonatomic, strong) DTVirtualThread *virtualThread;

@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;

@property (nonatomic) UILabel *callOnlineLabel;
//@property (nonatomic) UIImageView *callParticipateIconView;
@property (nonatomic) UILabel *callDurationLabel;
@property (nonatomic) UIView *callDurationContainer;
@property (nonatomic) UIView *callStateContainer;
@property (nonatomic) UIView *rightCallView;

@end


@implementation DTHomeVirtualCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self commontInit];
    }
    return self;
}

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commontInit];
    }
    
    return self;
}

- (void)commontInit
{
    OWSAssertDebug(!self.avatarView);
    
    self.avatarView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_instant_meeting"]];
    self.avatarView.layer.masksToBounds = YES;
    self.avatarView.layer.cornerRadius = self.avatarSize/2;
    [self.contentView addSubview:self.avatarView];
    [self.avatarView autoSetDimensionsToSize:CGSizeMake(self.avatarSize, self.avatarSize)];
    [self.avatarView autoPinLeadingToSuperviewMargin];
    [self.avatarView autoVCenterInSuperview];
    [self.avatarView setContentHuggingHigh];
    [self.avatarView setCompressionResistanceHigh];
    
    self.nameLabel = [UILabel new];
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.font = self.nameFont;
    [self.nameLabel setContentHuggingHorizontalLow];
    [self.nameLabel setCompressionResistanceHorizontalLow];
    
    self.callOnlineLabel = [UILabel new];
    self.callOnlineLabel.numberOfLines = 1;
    self.callOnlineLabel.hidden = YES;
    self.callOnlineLabel.font = [UIFont systemFontOfSize:15];
    [self.callOnlineLabel setContentHuggingHorizontalHigh];
    [self.callOnlineLabel setCompressionResistanceHorizontalHigh];
    
    self.callDurationLabel = [UILabel new];
    self.callDurationLabel.text = @"Join";
    self.callDurationLabel.textColor = [UIColor ows_whiteColor];
    self.callDurationLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.callDurationLabel.textAlignment = NSTextAlignmentCenter;
    self.callDurationLabel.font = [UIFont systemFontOfSize:12];
    [self.callDurationLabel setContentHuggingHorizontalHigh];
    [self.callDurationLabel setCompressionResistanceHorizontalHigh];
    
    self.callDurationContainer = [UIView new];
    self.callDurationContainer.backgroundColor = [UIColor ows_themeBlueColor];
    self.callDurationContainer.layer.cornerRadius = 4;
    [self.callDurationContainer addSubview:self.callDurationLabel];
    [self.callDurationContainer setContentHuggingHigh];
    [self.callDurationContainer setCompressionResistanceHigh];
    
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:9];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:9];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:5];
    
    self.rightCallView = [UIView containerView];
    [self.rightCallView addSubview:self.callOnlineLabel];
//    [self.rightCallView addSubview:self.callParticipateIconView];
    [self.rightCallView addSubview:self.callDurationContainer];
    [self.rightCallView setContentHuggingHigh];
    [self.rightCallView setCompressionResistanceHigh];
    
    [self.callOnlineLabel autoVCenterInSuperview];
    [self.callOnlineLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10];
    
//    [self.callParticipateIconView autoVCenterInSuperview];
//    [self.callParticipateIconView autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:self.callOnlineLabel withOffset:5];
    
    [self.callDurationContainer autoVCenterInSuperview];
    [self.callDurationContainer autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:self.callOnlineLabel withOffset:5];
    [self.callDurationContainer autoPinEdgeToSuperviewEdge:ALEdgeRight];
    
    UIStackView *hStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameLabel,
        self.rightCallView
    ]];
    hStackView.axis = UILayoutConstraintAxisHorizontal;
    hStackView.spacing = 6.f;
    [self.contentView addSubview:hStackView];
    [hStackView autoPinLeadingToTrailingEdgeOfView:self.avatarView offset:self.avatarHSpacing];
    [hStackView autoVCenterInSuperview];
    // Ensure that the cell's contents never overflow the cell bounds.
    [hStackView autoPinEdgeToSuperviewMargin:ALEdgeTop relation:NSLayoutRelationGreaterThanOrEqual];
    [hStackView autoPinEdgeToSuperviewMargin:ALEdgeBottom relation:NSLayoutRelationGreaterThanOrEqual];
    [hStackView autoPinTrailingToSuperviewMargin];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction)];
    [self.callDurationContainer addGestureRecognizer:tap];
    
    [self configUIStyle];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configUIStyle {
    self.backgroundColor = Theme.tableCellBackgroundColor;
    self.contentView.backgroundColor = Theme.stickBackgroundColor;
    
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = [Theme.secondaryBackgroundColor colorWithAlphaComponent:0.08];
    self.selectedBackgroundView = selectedBackgroundView;
    
    self.nameLabel.font = self.nameFont;
    self.nameLabel.textColor = Theme.primaryTextColor;
    
    self.callOnlineLabel.textColor = Theme.secondaryTextAndIconColor;
    self.callDurationLabel.textColor = [UIColor ows_whiteColor];
    self.callDurationContainer.layer.cornerRadius = 4;
    //(self.callDurationLabel.font.lineHeight+10)*0.5;
}

- (void)configWithThread:(DTVirtualThread *)virtualThread {
    _virtualThread = virtualThread;
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateMeetingDuration)
                                                 name:DTStickMeetingManager.kMeetingDurationUpdateNotification
                                               object:nil];
    
    [self configUIStyle];
    
    NSString *meetingName = [self getMeetingName];
    if (DTParamsUtils.validateString(meetingName)) {
        self.nameLabel.text = meetingName;
    } else {
        self.nameLabel.text = [DTCallManager defaultMeetingName];
    }
    
}

#pragma mark - action

- (void)tapAction {
    
    if (self.meetingBarDelegate && [self.meetingBarDelegate respondsToSelector:@selector(didTapMeetingBarWithThread:)]) {
        [self.meetingBarDelegate didTapMeetingBarWithThread:self.virtualThread];
    }
}

#pragma mark - const

- (NSUInteger)avatarSize {
    return 48.f;
}

- (NSUInteger)avatarHSpacing
{
    return 12.f;
}

- (UIFont *)nameFont {
    return [UIFont ows_dynamicTypeBodyFont];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

@end
