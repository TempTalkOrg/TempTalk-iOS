//
//  DTAddToGroupItem.m
//  Wea
//
//  Created by hornet on 2022/1/1.
//

#import "DTAddToGroupItem.h"
#import <PureLayout/PureLayout.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import "OWSAvatarBuilder.h"
#import "Yelling-Swift.h"

static CGFloat const kDTSelectedAvatarSize = 48;
static CGFloat const kDTSelectedRemoveBadgeSize = 20;
// Below this content height the cell is a legacy short host (e.g. DTGroupMemberController): avatar only.
static CGFloat const kDTSelectedTallMinHeight = 60;

@interface DTAddToGroupItem()
@property(nonatomic,strong) DTAvatarImageView *iconImage;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UIImageView *removeBadge;
@property(nonatomic,assign) BOOL removable;
// Avatar size + top constraints, updated in layoutSubviews for tall vs short hosts.
@property(nonatomic,strong) NSLayoutConstraint *avatarWidthConstraint;
@property(nonatomic,strong) NSLayoutConstraint *avatarHeightConstraint;
@property(nonatomic,strong) NSLayoutConstraint *avatarTopConstraint;
@end

@implementation DTAddToGroupItem

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self creatSubViews];
    }
    return self;
}

// Auto Layout is required: a bare frame leaves DTAvatarImageView's inner image oversized.
- (void)creatSubViews {
    [self.contentView addSubview:self.iconImage];
    [self.contentView addSubview:self.nameLabel];
    [self.contentView addSubview:self.removeBadge];

    [self.iconImage autoAlignAxisToSuperviewAxis:ALAxisVertical];
    self.avatarTopConstraint = [self.iconImage autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:0];
    self.avatarWidthConstraint = [self.iconImage autoSetDimension:ALDimensionWidth toSize:kDTSelectedAvatarSize];
    self.avatarHeightConstraint = [self.iconImage autoSetDimension:ALDimensionHeight toSize:kDTSelectedAvatarSize];

    [self.nameLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.iconImage withOffset:2];
    [self.nameLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft];
    [self.nameLabel autoPinEdgeToSuperviewEdge:ALEdgeRight];

    // ✕ badge sits just outside the avatar's top-right corner.
    [self.removeBadge autoSetDimensionsToSize:CGSizeMake(kDTSelectedRemoveBadgeSize, kDTSelectedRemoveBadgeSize)];
    [self.removeBadge autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.iconImage withOffset:-5];
    [self.removeBadge autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.iconImage withOffset:5];
}

// Tall host (invite/add screen, height >= 60): 48 circular avatar + name + ✕ badge.
// Legacy short host (height < 60): square avatar only, no name/badge.
- (void)layoutSubviews {
    CGFloat height = CGRectGetHeight(self.contentView.bounds);
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    BOOL tall = height >= kDTSelectedTallMinHeight;

    CGFloat avatarSize = tall ? kDTSelectedAvatarSize : MIN(width, height);
    if (avatarSize > 0 && self.avatarWidthConstraint.constant != avatarSize) {
        self.avatarWidthConstraint.constant = avatarSize;
        self.avatarHeightConstraint.constant = avatarSize;
    }

    // Vertically center the avatar + name block in the tall host (short hosts pin to top).
    CGFloat topInset = 0;
    if (tall) {
        CGFloat blockHeight = avatarSize + 2 + 16; // avatar + gap + name line
        topInset = MAX(0, (height - blockHeight) / 2.0);
    }
    if (self.avatarTopConstraint.constant != topInset) {
        self.avatarTopConstraint.constant = topInset;
    }

    self.nameLabel.hidden = !tall;
    self.removeBadge.hidden = !(tall && self.removable);

    [super layoutSubviews];
}

- (void)configWithReceptId:(NSString *)receptId {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:receptId];
    [self.iconImage setImageWithAvatar:account.contact.avatar recipientId:receptId displayName:account.contactFullName completion:nil];
    self.nameLabel.text = account.contactFullName;
    self.removable = YES;
    [self setNeedsLayout];
}

- (void)configWithImage:(nullable NSString *)imageName {
    if (!imageName) {
        self.iconImage.image = nil;
    } else {
        self.iconImage.image = [UIImage imageNamed:imageName];
    }
    self.nameLabel.text = nil;
    self.removable = NO;
    [self setNeedsLayout];
}

- (DTAvatarImageView *)iconImage {
    if (!_iconImage ) {
        _iconImage = [DTAvatarImageView new];
        _iconImage.imageForSelfType = DTAvatarImageForSelfTypeOriginal;
    }
    return _iconImage;
}

- (UILabel *)nameLabel {
    if (!_nameLabel) {
        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:12];
        _nameLabel.textColor = Theme.tthirdColor;
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.numberOfLines = 1;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _nameLabel;
}

- (UIImageView *)removeBadge {
    if (!_removeBadge) {
        _removeBadge = [[UIImageView alloc] init];
        _removeBadge.contentMode = UIViewContentModeScaleAspectFit;
        UIImage *image = [[UIImage systemImageNamed:@"xmark.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _removeBadge.image = image;
        _removeBadge.tintColor = Theme.tthirdColor;
        _removeBadge.backgroundColor = [UIColor clearColor];
    }
    return _removeBadge;
}

@end
