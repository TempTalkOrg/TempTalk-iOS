//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSQuotedMessageView.h"
#import "ConversationViewItem.h"
#import "Environment.h"
#import "OWSBubbleView.h"
#import "TempTalk-Swift.h"
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/UIView+SignalUI.h>
#import <TTServiceKit/TSAttachmentStream.h>
#import <TTServiceKit/TSMessage.h>
#import <TTServiceKit/TSQuotedMessage.h>
#import <TTServiceKit/NSString+DTMarkdown.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSQuotedMessageView ()

@property (nonatomic, readonly) DTReplyModel *replyModel;
@property (nonatomic, nullable, readonly) DisplayableText *displayableQuotedText;
@property (nonatomic, readonly) ConversationStyle *conversationStyle;

@property (nonatomic, readonly) BOOL isForPreview;
@property (nonatomic, readonly) BOOL isOutgoing;
@property (nonatomic, readonly) OWSDirectionalRectCorner sharpCorners;

@property (nonatomic, readonly) UIView *stripeView;
@property (nonatomic, readonly) UIStackView *vStackView;
@property (nonatomic, readonly) UILabel *quotedAuthorLabel;
@property (nonatomic, readonly) UILabel *quotedTextLabel;

@end

#pragma mark -

@implementation OWSQuotedMessageView

+ (OWSQuotedMessageView *)quotedMessageViewForConversation:(OWSQuotedReplyModel *)quotedMessage
                                     displayableQuotedText:(nullable DisplayableText *)displayableQuotedText
                                         conversationStyle:(ConversationStyle *)conversationStyle
                                                isOutgoing:(BOOL)isOutgoing
                                              sharpCorners:(OWSDirectionalRectCorner)sharpCorners
{
    OWSAssertDebug(quotedMessage);

    return [[OWSQuotedMessageView alloc] initWithQuotedMessage:quotedMessage
                                         displayableQuotedText:displayableQuotedText
                                             conversationStyle:conversationStyle
                                                  isForPreview:NO
                                                    isOutgoing:isOutgoing
                                                  sharpCorners:sharpCorners];
}

+ (OWSQuotedMessageView *)replyMessageViewForPreview:(DTReplyModel *)quotedMessage
                                    conversationStyle:(ConversationStyle *)conversationStyle
{
    OWSAssertDebug(quotedMessage);

    DisplayableText *_Nullable displayableQuotedText = nil;
    if (quotedMessage.body.length > 0) {
        displayableQuotedText = [DisplayableText displayableText:quotedMessage.body];
    }

    OWSQuotedMessageView *instance =
        [[OWSQuotedMessageView alloc] initWithQuotedMessage:quotedMessage
                                      displayableQuotedText:displayableQuotedText
                                          conversationStyle:conversationStyle
                                               isForPreview:YES
                                                 isOutgoing:YES
                                               sharpCorners:OWSDirectionalRectCornerAllCorners];
    [instance createContents];
    return instance;
}

- (instancetype)initWithQuotedMessage:(DTReplyModel *)quotedMessage
                displayableQuotedText:(nullable DisplayableText *)displayableQuotedText
                    conversationStyle:(ConversationStyle *)conversationStyle
                         isForPreview:(BOOL)isForPreview
                           isOutgoing:(BOOL)isOutgoing
                         sharpCorners:(OWSDirectionalRectCorner)sharpCorners
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSAssertDebug(quotedMessage);

    _replyModel = quotedMessage;
    _displayableQuotedText = displayableQuotedText;
    _isForPreview = isForPreview;
    _conversationStyle = conversationStyle;
    _isOutgoing = isOutgoing;
    _sharpCorners = sharpCorners;

    _quotedAuthorLabel = [UILabel new];
    _quotedTextLabel = [UILabel new];

    return self;
}

- (BOOL)hasQuotedAttachment
{
    return (self.replyModel.contentType.length > 0
        && ![OWSMimeTypeOversizeTextMessage isEqualToString:self.replyModel.contentType]);
}

- (BOOL)hasQuotedAttachmentThumbnailImage
{
    return (self.replyModel.contentType.length > 0
        && ![OWSMimeTypeOversizeTextMessage isEqualToString:self.replyModel.contentType] &&
        [TSAttachmentStream hasThumbnailForMimeType:self.replyModel.contentType]);
}

- (UIColor *)highlightColor
{
    BOOL isQuotingSelf = [NSObject isNullableObject:self.replyModel.authorId equalTo:TSAccountManager.localNumber];
    return (isQuotingSelf ? self.conversationStyle.bubbleColorOutgoingSent
                          : [self.conversationStyle quotingSelfHighlightColor]);
}

#pragma mark -

- (CGFloat)bubbleHMargin
{
    return 6.f;
}

- (CGFloat)hSpacing
{
    return 6.f;
}

- (CGFloat)vSpacing
{
    return 2.f;
}

- (CGFloat)stripeThickness
{
    return 4.f;
}

- (void)applyTheme {
    
    self.stripeView.backgroundColor = [UIColor ows_themeBlueColor];
    self.vStackView.backgroundColor = [[UIColor ows_themeBlueColor] colorWithAlphaComponent:0.2];
    self.quotedAuthorLabel.textColor = [self quotedAuthorColor];
    
    UIColor *quotedTextColor = nil;
    NSString *_Nullable fileTypeForSnippet = [self fileTypeForSnippet];
    NSString *_Nullable sourceFilename = [self.replyModel.sourceFilename filterStringForDisplay];
    if (self.replyModel.inputPreviewType == DTInputPreviewType_TopicFromMainViewReply) {
        quotedTextColor = self.quotedTextColor;
    } else {
        if (self.displayableQuotedText.displayText.length > 0 ) {
            quotedTextColor = self.quotedTextColor;
        } else if (fileTypeForSnippet) {
            quotedTextColor = self.fileTypeTextColor;
        } else if (sourceFilename) {
            quotedTextColor = self.filenameTextColor;
        } else {
            quotedTextColor = self.fileTypeTextColor;
        }
    }
    self.quotedTextLabel.textColor = quotedTextColor;
}

- (void)createContents
{
    // Ensure only called once.
    OWSAssertDebug(self.subviews.count < 1);

    self.userInteractionEnabled = YES;
    self.layoutMargins = UIEdgeInsetsZero;
    self.clipsToBounds = YES;

    OWSLayerView *innerBubbleView = [[OWSLayerView alloc]
         initWithFrame:CGRectZero
        layoutCallback:^(UIView *layerView) {
//            CGRect layerFrame = layerView.bounds;
//
//            const CGFloat bubbleLeft = 0.f;
//            const CGFloat bubbleRight = layerFrame.size.width;
//            const CGFloat bubbleTop = 0.f;
//            const CGFloat bubbleBottom = layerFrame.size.height;
//
//            const CGFloat sharpCornerRadius = 4;
//            const CGFloat wideCornerRadius = 6;
//
//            UIBezierPath *bezierPath = [OWSBubbleView roundedBezierRectWithBubbleTop:bubbleTop
//                                                                          bubbleLeft:bubbleLeft
//                                                                        bubbleBottom:bubbleBottom
//                                                                         bubbleRight:bubbleRight
//                                                                   sharpCornerRadius:sharpCornerRadius
//                                                                    wideCornerRadius:wideCornerRadius
//                                                                        sharpCorners:sharpCorners];
//
//            maskLayer.path = bezierPath.CGPath;
        }];
//    innerBubbleView.layer.mask = maskLayer;
//    innerBubbleView.backgroundColor = [[UIColor ows_themeBlueColor] colorWithAlphaComponent:0.2];
    //Theme.isDarkThemeEnabled ? [self.conversationStyle quotedReplyBubbleColorWithIsIncoming:!self.isOutgoing] : [[UIColor ows_themeBlueColor] colorWithAlphaComponent:0.2];
    [self addSubview:innerBubbleView];
    [innerBubbleView autoPinLeadingToSuperviewMarginWithInset:self.bubbleHMargin];
    [innerBubbleView autoPinTrailingToSuperviewMarginWithInset:self.bubbleHMargin];
    [innerBubbleView autoPinTopToSuperviewMargin];
    [innerBubbleView autoPinBottomToSuperviewMargin];

    UIStackView *hStackView = [UIStackView new];
    hStackView.axis = UILayoutConstraintAxisHorizontal;
    hStackView.spacing = self.hSpacing;
    hStackView.layoutMargins = UIEdgeInsetsMake(0, 4, 0, 4);
    hStackView.layoutMarginsRelativeArrangement = YES;
    [innerBubbleView addSubview:hStackView];
    [hStackView autoPinEdgesToSuperviewEdges];

    UIView *stripeView = [UIView new];
    stripeView.layer.cornerRadius = 2;
    stripeView.layer.masksToBounds = YES;
    stripeView.backgroundColor = [UIColor ows_themeBlueColor];
    //[self.conversationStyle quotedReplyStripeColorWithIsIncoming:!self.isOutgoing];
    [stripeView autoSetDimension:ALDimensionWidth toSize:self.stripeThickness];
    [stripeView setContentHuggingHigh];
    [stripeView setCompressionResistanceHigh];
    [hStackView addArrangedSubview:stripeView];

    UIStackView *vStackView = [UIStackView new];
    vStackView.backgroundColor = [[UIColor ows_themeBlueColor] colorWithAlphaComponent:0.2];
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.layoutMargins = UIEdgeInsetsMake(self.textVMargin, 0, self.textVMargin, 0);
    vStackView.layoutMarginsRelativeArrangement = YES;
    vStackView.spacing = self.vSpacing;
    [hStackView addArrangedSubview:vStackView];
    UILabel *quotedAuthorLabel = nil;
    
    quotedAuthorLabel = [self configureQuotedAuthorLabel];
    
    [vStackView addArrangedSubview:quotedAuthorLabel];
    [quotedAuthorLabel autoSetDimension:ALDimensionHeight toSize:self.quotedAuthorHeight];
    [quotedAuthorLabel setContentHuggingVerticalHigh];
    [quotedAuthorLabel setContentHuggingHorizontalLow];
    [quotedAuthorLabel setCompressionResistanceHorizontalLow];

    UILabel *quotedTextLabel = [self configureQuotedTextLabel];
    [vStackView addArrangedSubview:quotedTextLabel];
    [quotedTextLabel setContentHuggingLow];
    [quotedTextLabel setCompressionResistanceLow];

    if (self.hasQuotedAttachment) {
        UIView *_Nullable quotedAttachmentView = nil;
        UIImage *_Nullable thumbnailImage = [self tryToLoadThumbnailImage];
        if (thumbnailImage) {
            quotedAttachmentView = [self imageViewForImage:thumbnailImage];
            quotedAttachmentView.clipsToBounds = YES;
            quotedAttachmentView.backgroundColor = [UIColor whiteColor];

            if (self.isVideoAttachment) {
                UIImage *contentIcon = [UIImage imageNamed:@"attachment_play_button"];
                contentIcon = [contentIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *contentImageView = [self imageViewForImage:contentIcon];
                contentImageView.tintColor = [UIColor whiteColor];
                [quotedAttachmentView addSubview:contentImageView];
                [contentImageView autoCenterInSuperview];
            }
        } else if (self.replyModel.thumbnailDownloadFailed) {
            // TODO design review icon and color
            UIImage *contentIcon =
                [[UIImage imageNamed:@"btnRefresh--white"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            UIImageView *contentImageView = [self imageViewForImage:contentIcon];
            contentImageView.contentMode = UIViewContentModeScaleAspectFit;
            contentImageView.tintColor = UIColor.whiteColor;

            quotedAttachmentView = [UIView containerView];
            [quotedAttachmentView addSubview:contentImageView];
            quotedAttachmentView.backgroundColor = self.highlightColor;
            [contentImageView autoCenterInSuperview];
            [contentImageView
                autoSetDimensionsToSize:CGSizeMake(self.quotedAttachmentSize * 0.5f, self.quotedAttachmentSize * 0.5f)];

            UITapGestureRecognizer *tapGesture =
                [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapFailedThumbnailDownload:)];
            [quotedAttachmentView addGestureRecognizer:tapGesture];
            quotedAttachmentView.userInteractionEnabled = YES;
        } else {
            UIImage *contentIcon = [UIImage imageNamed:@"generic-attachment"];
            UIImageView *contentImageView = [self imageViewForImage:contentIcon];
            contentImageView.contentMode = UIViewContentModeScaleAspectFit;

            UIView *wrapper = [UIView containerView];
            [wrapper addSubview:contentImageView];
            [contentImageView autoCenterInSuperview];
            [contentImageView autoSetDimension:ALDimensionWidth toSize:self.quotedAttachmentSize * 0.5f];
            quotedAttachmentView = wrapper;
        }

        [quotedAttachmentView autoSetDimension:ALDimensionWidth toSize:self.quotedAttachmentSize];
        [quotedAttachmentView setContentHuggingHigh];
        [quotedAttachmentView setCompressionResistanceHigh];
        [hStackView addArrangedSubview:quotedAttachmentView];
    } else {
        // If there's no attachment, add an empty view so that
        // the stack view's spacing serves as a margin between
        // the text views and the trailing edge.
//        UIView *emptyView = [UIView containerView];
//        [hStackView addArrangedSubview:emptyView];
//        [emptyView setContentHuggingHigh];
//        [emptyView autoSetDimension:ALDimensionWidth toSize:0.f];
    }
}

- (void)didTapFailedThumbnailDownload:(UITapGestureRecognizer *)gestureRecognizer
{
    DDLogDebug(@"%@ in didTapFailedThumbnailDownload", self.logTag);

    if (!self.replyModel.thumbnailDownloadFailed) {
        OWSFailDebug(@"%@ in %s thumbnailDownloadFailed was unexpectedly false", self.logTag, __PRETTY_FUNCTION__);
        return;
    }

    if (!self.replyModel.thumbnailAttachmentPointer) {
        OWSFailDebug(@"%@ in %s thumbnailAttachmentPointer was unexpectedly nil", self.logTag, __PRETTY_FUNCTION__);
        return;
    }
    if ([self.replyModel isKindOfClass:OWSQuotedReplyModel.class] && [self.delegate respondsToSelector:@selector(didTapQuotedReply:failedThumbnailDownloadAttachmentPointer:)]) {
        [self.delegate didTapQuotedReply:(OWSQuotedReplyModel *)self.replyModel
            failedThumbnailDownloadAttachmentPointer:self.replyModel.thumbnailAttachmentPointer];
    }
}

- (nullable UIImage *)tryToLoadThumbnailImage
{
    if (!self.hasQuotedAttachmentThumbnailImage) {
        return nil;
    }

    // TODO: Possibly ignore data that is too large.
    UIImage *_Nullable image = self.replyModel.thumbnailImage;
    // TODO: Possibly ignore images that are too large.
    return image;
}

- (UIImageView *)imageViewForImage:(UIImage *)image
{
    OWSAssertDebug(image);

    UIImageView *imageView = [UIImageView new];
    imageView.image = image;
    // We need to specify a contentMode since the size of the image
    // might not match the aspect ratio of the view.
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    // Use trilinear filters for better scaling quality at
    // some performance cost.
    imageView.layer.minificationFilter = kCAFilterTrilinear;
    imageView.layer.magnificationFilter = kCAFilterTrilinear;
    return imageView;
}

- (UILabel *)configureQuotedTextLabel
{
    OWSAssertDebug(self.quotedTextLabel);

    UIColor *textColor = self.quotedTextColor;
    UIFont *font = self.quotedTextFont;
    NSString *text = @"";

    NSString *_Nullable fileTypeForSnippet = [self fileTypeForSnippet];
    NSString *_Nullable sourceFilename = [self.replyModel.sourceFilename filterStringForDisplay];
    
    if (self.replyModel.inputPreviewType == DTInputPreviewType_TopicFromMainViewReply) {
        text = @"";
        textColor = self.quotedTextColor;
        font = self.quotedTextFont;
    }else {
        if (self.displayableQuotedText.displayText.length > 0 ) {
            text = self.displayableQuotedText.displayText;
            // 卡片类型消息，预览时需要移除 markdown 格式
            if (DTParamsUtils.validateString(self.replyModel.replyItem.card.content)) {
                text = [text removeMarkdownStyle];
            }
            textColor = self.quotedTextColor;
            font = self.quotedTextFont;
        } else if (fileTypeForSnippet) {
            text = fileTypeForSnippet;
            textColor = self.fileTypeTextColor;
            font = self.fileTypeFont;
        } else if (sourceFilename) {
            text = sourceFilename;
            textColor = self.filenameTextColor;
            font = self.filenameFont;
        } else {
            text = Localized(
                                     @"QUOTED_REPLY_TYPE_ATTACHMENT", @"Indicates this message is a quoted reply to an attachment of unknown type.");
            textColor = self.fileTypeTextColor;
            font = self.fileTypeFont;
        }
    }
    self.quotedTextLabel.numberOfLines = self.isForPreview ? 1 : 2;
    self.quotedTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.quotedTextLabel.text = text;
    self.quotedTextLabel.textColor = textColor;
    self.quotedTextLabel.font = font;

    return self.quotedTextLabel;
}


- (nullable NSString *)fileTypeForSnippet
{
    // TODO: Are we going to use the filename?  For all mimetypes?
    NSString *_Nullable contentType = self.replyModel.contentType;
    if (contentType.length < 1) {
        return nil;
    }

    if ([MIMETypeUtil isAudio:contentType]) {
        return Localized(
            @"QUOTED_REPLY_TYPE_AUDIO", @"Indicates this message is a quoted reply to an audio file.");
    } else if ([MIMETypeUtil isVideo:contentType]) {
        return Localized(
            @"QUOTED_REPLY_TYPE_VIDEO", @"Indicates this message is a quoted reply to a video file.");
    } else if ([MIMETypeUtil isImage:contentType]) {
        return Localized(
            @"QUOTED_REPLY_TYPE_IMAGE", @"Indicates this message is a quoted reply to an image file.");
    } else if ([MIMETypeUtil isAnimated:contentType]) {
        return Localized(
            @"QUOTED_REPLY_TYPE_GIF", @"Indicates this message is a quoted reply to animated GIF file.");
    }
    return nil;
}

- (BOOL)isAudioAttachment
{
    // TODO: Are we going to use the filename?  For all mimetypes?
    NSString *_Nullable contentType = self.replyModel.contentType;
    if (contentType.length < 1) {
        return NO;
    }

    return [MIMETypeUtil isAudio:contentType];
}

- (BOOL)isVideoAttachment
{
    // TODO: Are we going to use the filename?  For all mimetypes?
    NSString *_Nullable contentType = self.replyModel.contentType;
    if (contentType.length < 1) {
        return NO;
    }

    return [MIMETypeUtil isVideo:contentType];
}

- (UILabel *)configureQuotedAuthorLabel {
    OWSAssertDebug(self.quotedAuthorLabel);
    self.quotedAuthorLabel.text = [self quoteText];
    self.quotedAuthorLabel.font = self.quotedAuthorFont;
    // TODO:
    self.quotedAuthorLabel.textColor = [self quotedAuthorColor];
    self.quotedAuthorLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.quotedAuthorLabel.numberOfLines = 1;
    
    return self.quotedAuthorLabel;
}


- (NSString *)quoteText {
    NSString *_Nullable localNumber = [TSAccountManager localNumber];
    NSString *quotedAuthorText;
    if ([localNumber isEqualToString:self.replyModel.authorId]) {

        if (self.isOutgoing) {
            quotedAuthorText = Localized(
                @"QUOTED_AUTHOR_INDICATOR_YOURSELF", @"message header label when quoting yourself");
        } else {
                quotedAuthorText = Localized(
                    @"QUOTED_AUTHOR_INDICATOR_YOU", @"message header label when someone else is quoting you");
            
        }
    } else {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *quotedAuthor = self.replyModel.authorName;
            quotedAuthorText = [NSString
                stringWithFormat:
                    Localized(@"QUOTED_AUTHOR_INDICATOR_YOU_FORMAT",
                        @"Indicates the author of a quoted message. Embeds {{the author's name or phone number}}."),
                quotedAuthor];
    }
    return quotedAuthorText;
}


- (void)getAuthorNameWithMessage:(NSString *)authorString withPatternString:(NSString *)patternString withCallBackCheckingResult:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@",patternString]
options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSArray<NSTextCheckingResult *> *checkingResultArr = [regex matchesInString:authorString options:0 range:NSMakeRange(0, [authorString length])];
           if(checkingResultArr && checkingResultArr.count){
               if (callBack) {
                   callBack(checkingResultArr);
               }
           }
       }
}

- (nullable NSString *)configureReplyAuthorLabelWithAuthorId:(NSString *) authorId {
    NSString *_Nullable localNumber = [TSAccountManager localNumber];
    NSString *quotedAuthorText = nil;
    if ([localNumber isEqualToString:authorId]) {
        if (self.isOutgoing) {
            quotedAuthorText = Localized(
                @"QUOTED_REPLY_AUTHOR_INDICATOR_YOURSELF", @"message header label when quoting yourself");
        } else {
            quotedAuthorText = Localized(
                @"QUOTED_REPLY_AUTHOR_INDICATOR_YOU", @"message header label when someone else is quoting you");
        }
    } else {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *quotedAuthor = [contactsManager contactOrProfileNameForPhoneIdentifier:authorId];
        quotedAuthorText = [NSString
            stringWithFormat:
                Localized(@"TOPIC_REPLY_AUTHOR_INDICATOR_FORMAT",
                    @"Indicates the author of a quoted message. Embeds {{the author's name or phone number}}."),
            quotedAuthor];
    }
    return quotedAuthorText;
}

- (nullable NSString *)configureQuotedAuthorLabelTextWithAuthorId:(NSString *) authorId {
    NSString *_Nullable localNumber = [TSAccountManager localNumber];
    NSString *quotedAuthorText = nil;
    if ([localNumber isEqualToString:authorId]) {
        if (self.isOutgoing) {
            quotedAuthorText = Localized(
                @"QUOTED_AUTHOR_INDICATOR_YOURSELF", @"message header label when quoting yourself");
        } else {
            quotedAuthorText = Localized(
                @"QUOTED_AUTHOR_INDICATOR_YOU", @"message header label when someone else is quoting you");
        }
    } else {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        NSString *quotedAuthor = [contactsManager contactOrProfileNameForPhoneIdentifier:authorId];
        quotedAuthorText = [NSString
            stringWithFormat:
                Localized(@"QUOTED_AUTHOR_INDICATOR_YOU_FORMAT",
                    @"Indicates the author of a quoted message. Embeds {{the author's name or phone number}}."),
            quotedAuthor];
    }
    return quotedAuthorText;
}

- (NSString *)getContactInfoWithAuthorId:(NSString *) authorId {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    NSString *quotedAuthor = [contactsManager contactOrProfileNameForPhoneIdentifier:authorId];
    return quotedAuthor;
}

#pragma mark - Measurement
- (CGFloat)textVMargin
{
    return 7.f;
}

- (CGSize)sizeForMaxWidth:(CGFloat)maxWidth
{
    CGSize result = CGSizeZero;

    result.width += self.bubbleHMargin * 2 + self.stripeThickness + self.hSpacing * 2;

    CGFloat thumbnailHeight = 0.f;
    if (self.hasQuotedAttachment) {
        result.width += self.quotedAttachmentSize;

        thumbnailHeight += self.quotedAttachmentSize;
    }

    // Quoted Author
    CGFloat textWidth = 0.f;
    CGFloat maxTextWidth = maxWidth - result.width;
    CGFloat textHeight = self.textVMargin * 2 + self.quotedAuthorHeight + self.vSpacing;
    {
        UILabel *quotedAuthorLabel = nil;
        quotedAuthorLabel = [self configureQuotedAuthorLabel];
        CGSize quotedAuthorSize = CGSizeCeil([quotedAuthorLabel sizeThatFits:CGSizeMake(maxTextWidth, CGFLOAT_MAX)]);
        textWidth = quotedAuthorSize.width;
    }

    {
        UILabel *quotedTextLabel = [self configureQuotedTextLabel];

        CGSize textSize = CGSizeCeil([quotedTextLabel sizeThatFits:CGSizeMake(maxTextWidth, CGFLOAT_MAX)]);
        textWidth = MAX(textWidth, textSize.width);
        textHeight += textSize.height;
    }

    textWidth = MIN(textWidth, maxTextWidth);
    result.width += textWidth;
    result.height += MAX(textHeight, thumbnailHeight);

    return CGSizeCeil(result);
}

- (UIFont *)quotedAuthorFont
{
    return UIFont.ows_dynamicTypeSubheadlineFont.ows_italic;
}
- (UIFont *)quotedAuthorFont01
{
    return UIFont.ows_dynamicTypeFootnoteFont.ows_semibold;
}


- (UIColor *)quotedAuthorColor
{
    return [self.conversationStyle quotedReplyAuthorColor];
}


- (UIColor *)quotedTextColor
{
    return [self.conversationStyle replyTextColor];
}

- (UIFont *)quotedTextFont
{
    return [UIFont ows_dynamicTypeBodyFont];
}

- (UIColor *)fileTypeTextColor
{
    return [self.conversationStyle quotedReplyAttachmentColor];
}

- (UIFont *)fileTypeFont
{
    return self.quotedTextFont.ows_italic;
}

- (UIColor *)filenameTextColor
{
    return [self.conversationStyle quotedReplyAttachmentColor];
}

- (UIFont *)filenameFont
{
    return self.quotedTextFont;
}

- (CGFloat)quotedAuthorHeight
{
    return (CGFloat)ceil([self quotedAuthorFont].lineHeight * 1.f);
}

- (CGFloat)quotedAttachmentSize
{
    return 54.f;
}

#pragma mark -

- (CGSize)sizeThatFits:(CGSize)size
{
    return [self sizeForMaxWidth:CGFLOAT_MAX];
}

@end

NS_ASSUME_NONNULL_END
