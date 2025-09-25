//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContactShareView.h"
#import "OWSContactAvatarBuilder.h"
#import "TempTalk-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTServiceKit/OWSContact.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSContactShareView ()

@property (nonatomic, readonly) ContactShareViewModel *contactShare;

@property (nonatomic, readonly) BOOL isIncoming;
@property (nonatomic, readonly) ConversationStyle *conversationStyle;
@property (nonatomic, readonly) OWSContactsManager *contactsManager;

@end

#pragma mark -

@implementation OWSContactShareView

- (instancetype)initWithContactShare:(ContactShareViewModel *)contactShare
                          isIncoming:(BOOL)isIncoming
                   conversationStyle:(ConversationStyle *)conversationStyle
{
    self = [super init];
    if (self) {
        _contactShare = contactShare;
        _isIncoming = isIncoming;
        _conversationStyle = conversationStyle;
        _contactsManager = Environment.shared.contactsManager;
    }

    return self;
}

#pragma mark -

- (CGFloat)hMargin
{
    return 12.f;
}

+ (CGFloat)vMargin
{
    return 0.f;
}

- (CGFloat)iconHSpacing
{
    return 8.f;
}

+ (CGFloat)bubbleHeight
{
    return self.contentHeight;
}

+ (CGFloat)contentHeight
{
    CGFloat labelsHeight = (self.nameFont.lineHeight + self.labelsVSpacing + self.subtitleFont.lineHeight);
    CGFloat contentHeight = MAX(self.iconSize, labelsHeight);
    contentHeight += OWSContactShareView.vMargin * 2;
    return contentHeight;
}

+ (CGFloat)iconSize
{
    return 40.f;
}

+ (CGFloat)headerSize
{
    return 40.f;
}

- (CGFloat)iconSize
{
    return [OWSContactShareView iconSize];
}

+ (UIFont *)nameFont
{
    return [UIFont ows_dynamicTypeBodyFont];
}

+ (UIFont *)subtitleFont
{
    return [UIFont ows_dynamicTypeCaption1Font];
}

+ (CGFloat)labelsVSpacing
{
    return 2;
}

- (void)createContents
{
    self.layoutMargins = UIEdgeInsetsZero;
    
    UIView *headerView = [UIView new];
    [self addSubview:headerView];
    headerView.backgroundColor = [UIColor clearColor];
    [headerView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [headerView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [headerView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [headerView autoSetDimension:ALDimensionHeight toSize:[[self class] headerSize]];
    
    UIImageView *imageIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"share_contact_icon"]];
    [headerView addSubview:imageIcon];
    [imageIcon autoSetDimensionsToSize:CGSizeMake(12, 12)];
    [imageIcon autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [imageIcon autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:self.hMargin];
        
    UILabel *contactShareLabel = [[UILabel alloc] init];
    [headerView addSubview:contactShareLabel];
    contactShareLabel.text = Localized(@"FORWARD_MESSAGE_CONTACT_TYPE", nil);
    contactShareLabel.font = [UIFont systemFontOfSize:12];
    contactShareLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x474D57];
    [contactShareLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:imageIcon withOffset:4];
    [contactShareLabel autoAlignAxisToSuperviewAxis:ALAxisHorizontal];

    UIColor *lineColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF];
    UIView *line = [[UIView alloc] init];
    [headerView addSubview:line];
    line.backgroundColor = lineColor;
    [line autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [line autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [line autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [line autoSetDimension:ALDimensionHeight toSize:(1.0 / [UIScreen mainScreen].scale)];
    
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 8.0;
    self.layer.borderColor = lineColor.CGColor;
    self.layer.borderWidth = (1.0 / [UIScreen mainScreen].scale);
    self.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF];

    UIColor *textColor = [self.conversationStyle bubbleTextColorWithIsIncoming:self.isIncoming];

    AvatarImageView *avatarView = [AvatarImageView new];
    NSString *contactIdentifier = self.contactShare.phoneNumbers.firstObject.phoneNumber;
    SignalAccount *account = [self.contactsManager signalAccountForRecipientId:contactIdentifier];
    NSString *diaplayName = account.contact.fullName;

    [avatarView setImageWithContactAvatar:account.contact.avatar recipientId:contactIdentifier displayName:diaplayName];

    [avatarView autoSetDimension:ALDimensionWidth toSize:self.iconSize];
    [avatarView autoSetDimension:ALDimensionHeight toSize:self.iconSize];
    [avatarView setCompressionResistanceHigh];
    [avatarView setContentHuggingHigh];
    
    NSString *contactsName = account != nil ? [self.contactsManager displayNameForSignalAccount:account] : (self.contactShare.name.displayName ?: contactIdentifier);

    UILabel *topLabel = [UILabel new];
    topLabel.text = contactsName;
    topLabel.textColor = textColor;
    topLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    topLabel.font = [UIFont systemFontOfSize:16.0];

    UIStackView *labelsView = [UIStackView new];
    labelsView.axis = UILayoutConstraintAxisVertical;
    labelsView.spacing = OWSContactShareView.labelsVSpacing;
    [labelsView addArrangedSubview:topLabel];

    UIStackView *hStackView = [UIStackView new];
    hStackView.axis = UILayoutConstraintAxisHorizontal;
    hStackView.spacing = self.iconHSpacing;
    hStackView.alignment = UIStackViewAlignmentCenter;
    hStackView.layoutMarginsRelativeArrangement = YES;
    hStackView.layoutMargins
        = UIEdgeInsetsMake(OWSContactShareView.vMargin, self.hMargin, OWSContactShareView.vMargin, self.hMargin);
    [hStackView addArrangedSubview:avatarView];
    [hStackView addArrangedSubview:labelsView];

    [self addSubview:hStackView];
    
    [hStackView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:headerView withOffset:0];
    [hStackView autoPinEdgeToSuperviewEdge:ALEdgeLeft];
    [hStackView autoPinEdgeToSuperviewEdge:ALEdgeRight];
    [hStackView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:16];
}

@end

NS_ASSUME_NONNULL_END
