//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageFooterView.h"
//#import "OWSMessageTimerView.h"
#import "TempTalk-Swift.h"
#import <QuartzCore/QuartzCore.h>
#import <TTMessaging/DateUtil.h>
#import "DTImageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageFooterView ()

@property (nonatomic) UILabel *timestampLabel;
@property (nonatomic) DTImageView *statusIndicatorImageView;
//@property (nonatomic) OWSMessageTimerView *messageTimerView;

@end

@implementation OWSMessageFooterView

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commontInit];
    }

    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *_Nullable)event

{
    CGRect bounds = self.bounds;

    bounds = CGRectInset(bounds, -10, - 10);

    return CGRectContainsPoint(bounds, point);

}

- (void)commontInit
{
    // Ensure only called once.
    OWSAssertDebug(!self.timestampLabel);

    self.layoutMargins = UIEdgeInsetsZero;

    self.axis = UILayoutConstraintAxisHorizontal;
    self.alignment = UIStackViewAlignmentCenter;
    self.distribution = UIStackViewDistributionEqualSpacing;

    UIStackView *leftStackView = [UIStackView new];
    leftStackView.axis = UILayoutConstraintAxisHorizontal;
    leftStackView.spacing = self.hSpacing;
    leftStackView.alignment = UIStackViewAlignmentCenter;
    [self addArrangedSubview:leftStackView];
    [leftStackView setContentHuggingHigh];

    self.timestampLabel = [UILabel new];
    [leftStackView addArrangedSubview:self.timestampLabel];

//    self.messageTimerView = [OWSMessageTimerView new];
//    [self.messageTimerView setContentHuggingHigh];
//    [leftStackView addArrangedSubview:self.messageTimerView];

    self.statusIndicatorImageView = [DTImageView new];
    self.statusIndicatorImageView.titleLable.font = [UIFont boldSystemFontOfSize:7.0];
    @weakify(self);
    self.statusIndicatorImageView.tapBlock = ^(DTImageView * _Nonnull imageView) {
        @strongify(self);
        if([self.delegate respondsToSelector:@selector(tapReadStatusAction)]){
            [self.delegate tapReadStatusAction];
        }
    };
    [self addArrangedSubview:self.statusIndicatorImageView];

//    self.userInteractionEnabled = NO;
}

- (void)configureFonts
{
    self.timestampLabel.font = UIFont.ows_dynamicTypeCaption1Font;
}

- (CGFloat)hSpacing
{
    // TODO: Review constant.
    return 8.f;
}

- (CGFloat)maxImageWidth
{
    return 18.f;
}

- (CGFloat)imageHeight
{
    return 12.f;
}

#pragma mark - Load

- (void)configureWithConversationViewItem:(id <ConversationViewItem>)viewItem
                        isOverlayingMedia:(BOOL)isOverlayingMedia
                        conversationStyle:(ConversationStyle *)conversationStyle
                               isIncoming:(BOOL)isIncoming
{
    OWSAssertDebug(viewItem);
    OWSAssertDebug(conversationStyle);

    [self configureLabelsWithConversationViewItem:viewItem];

    UIColor *textColor;
    if (isOverlayingMedia) {
        textColor = [UIColor whiteColor];
    } else {
        textColor = [conversationStyle bubbleSecondaryTextColorWithIsIncoming:isIncoming];
    }
    self.timestampLabel.textColor = textColor;

    if (viewItem.hasPerConversationExpiration) {
        TSMessage *message = (TSMessage *)viewItem.interaction;
        uint64_t expirationTimestamp = message.expiresAt;
        uint32_t expiresInSeconds = message.expiresInSeconds;
//        [self.messageTimerView configureWithExpirationTimestamp:expirationTimestamp
//                                         initialDurationSeconds:expiresInSeconds
//                                                      tintColor:textColor];
//        self.messageTimerView.hidden = NO;
    } else {
//        self.messageTimerView.hidden = YES;
    }

    if (viewItem.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;

        UIImage *_Nullable statusIndicatorImage = nil;
        MessageReceiptStatus messageStatus =
            [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
        switch (messageStatus) {
            case MessageReceiptStatusUploading:
            case MessageReceiptStatusSending:
            {
                self.userInteractionEnabled = NO;
                statusIndicatorImage = [UIImage imageNamed:@"message_status_sending"];
                self.statusIndicatorImageView.titleLable.text = @"";
                [self animateSpinningIcon];
            }
                break;
            case MessageReceiptStatusSent:
            case MessageReceiptStatusSkipped:
            case MessageReceiptStatusDelivered:
            {
                if(viewItem.isGroupThread){
                    self.userInteractionEnabled = YES;
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_read_one"];
                }else if([outgoingMessage.recipientIds containsObject:[TSAccountManager localNumber]]){
                    self.userInteractionEnabled = NO;
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_sent"];
                    self.statusIndicatorImageView.titleLable.text = @"";
                }else{
                    self.userInteractionEnabled = NO;
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_read_one"];
                }
                self.statusIndicatorImageView.titleLable.text = @"";
            }
                break;
            case MessageReceiptStatusRead:
            {
                if(viewItem.isGroupThread){
                    self.userInteractionEnabled = YES;
                    NSArray *messageRecipientIds = outgoingMessage.readRecipientIds;
                    if(messageRecipientIds.count == outgoingMessage.recipientIds.count){
                        statusIndicatorImage = [UIImage imageNamed:@"message_status_sent"];
                        self.statusIndicatorImageView.titleLable.text = @"";
                    }else if(messageRecipientIds.count > 99){
                        statusIndicatorImage = [UIImage imageNamed:@"message_status_read_more"];
                        self.statusIndicatorImageView.titleLable.text = @"";
                    }else{
                        statusIndicatorImage = [UIImage imageNamed:@"message_status_read_one"];
                        self.statusIndicatorImageView.titleLable.text = [NSString stringWithFormat:@"%ld",(long)messageRecipientIds.count];
                    }
                }else{
                    self.userInteractionEnabled = NO;
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_sent"];
                    self.statusIndicatorImageView.titleLable.text = @"";
                }
            }
                break;
            case MessageReceiptStatusFailed:
                // No status indicator icon.
            {
                self.userInteractionEnabled = NO;
                self.statusIndicatorImageView.titleLable.text = @"";
            }
                break;
        }

        if (statusIndicatorImage) {
            [self showStatusIndicatorWithIcon:statusIndicatorImage textColor:textColor];
        } else {
            [self hideStatusIndicator];
        }
        
    } else {
        [self hideStatusIndicator];
        self.userInteractionEnabled = NO;
    }
}

- (void)showStatusIndicatorWithIcon:(UIImage *)icon textColor:(UIColor *)textColor
{
    OWSAssertDebug(icon.size.width <= self.maxImageWidth);
    self.statusIndicatorImageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.statusIndicatorImageView.tintColor = textColor;
    self.statusIndicatorImageView.titleLable.textColor = textColor;
    [self.statusIndicatorImageView setContentHuggingHigh];
    self.spacing = self.hSpacing;
}

- (void)hideStatusIndicator
{
    // If there's no status indicator, we want the other
    // footer contents to "cling to the leading edge".
    // Instead of hiding the status indicator view,
    // we clear its contents and let it stretch to fill
    // the available space.
    self.statusIndicatorImageView.image = nil;
    [self.statusIndicatorImageView setContentHuggingLow];
    self.spacing = 0;
}

- (void)animateSpinningIcon
{
    CABasicAnimation *animation;
    animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.toValue = @(M_PI * 2.0);
    const CGFloat kPeriodSeconds = 1.f;
    animation.duration = kPeriodSeconds;
    animation.cumulative = YES;
    animation.repeatCount = HUGE_VALF;

    [self.statusIndicatorImageView.layer addAnimation:animation forKey:@"animation"];
}

- (BOOL)isFailedOutgoingMessage:(id <ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    if (viewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage) {
        return NO;
    }

    TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
    MessageReceiptStatus messageStatus =
        [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
    return messageStatus == MessageReceiptStatusFailed;
}

- (void)configureLabelsWithConversationViewItem:(id <ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    [self configureFonts];

    NSString *timestampLabelText;
    if ([self isFailedOutgoingMessage:viewItem]) {
        timestampLabelText
            = Localized(@"MESSAGE_STATUS_SEND_FAILED", @"Label indicating that a message failed to send.");
    } else {
        timestampLabelText = [DateUtil formatMessageTimestamp:viewItem.interaction.timestamp];
    }

    self.timestampLabel.text = timestampLabelText.localizedUppercaseString;
}

- (CGSize)measureWithConversationViewItem:(id <ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);

    [self configureLabelsWithConversationViewItem:viewItem];

    CGSize result = CGSizeZero;
    result.height = MAX(self.timestampLabel.font.lineHeight, self.imageHeight);

    // Measure the actual current width, to be safe.
    CGFloat timestampLabelWidth = [self.timestampLabel sizeThatFits:CGSizeZero].width;

    result.width = timestampLabelWidth;
    if (viewItem.interaction.interactionType == OWSInteractionType_OutgoingMessage) {
        if (![self isFailedOutgoingMessage:viewItem]) {
            result.width += (self.maxImageWidth + self.hSpacing);
        }
    }

//    if (viewItem.hasPerConversationExpiration) {
//        result.width += ([OWSMessageTimerView measureSize].width + self.hSpacing);
//    }

    return CGSizeCeil(result);
}

- (nullable NSString *)messageStatusTextForConversationViewItem:(id <ConversationViewItem>)viewItem
{
    OWSAssertDebug(viewItem);
    if (viewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage) {
        return nil;
    }

    TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
    NSString *statusMessage = [MessageRecipientStatusUtils receiptMessageWithOutgoingMessage:outgoingMessage];
    return statusMessage;
}

- (void)prepareForReuse
{
    [self.statusIndicatorImageView.layer removeAllAnimations];

//    [self.messageTimerView prepareForReuse];
}

- (void)dealloc {
    OWSLogInfo(@"OWSMessageFooterView --> dealloc");
}
@end

NS_ASSUME_NONNULL_END
