//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationInputToolbar.h"
#import "ConversationInputTextView.h"
#import "Environment.h"
#import "OWSContactsManager.h"
#import "OWSMath.h"
#import "TempTalk-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import "ViewControllerUtils.h"
#import "ChooseAtMembersViewController.h"
#import <SignalServiceKit/NSTimer+OWS.h>
#import <SignalServiceKit/TSQuotedMessage.h>
#import "DTInputToolbarFlowLayout.h"
#import "DTInputBarMoreCell.h"
#import <SignalServiceKit/DTReplyModel.h>
#import <SignalMessaging/DTTopicReplyModel.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_CLOSED_ENUM(NSUInteger, KeyboardType) { KeyboardType_System, KeyboardType_Sticker, KeyboardType_Attachment };

static void *kConversationInputTextViewObservingContext = &kConversationInputTextViewObservingContext;

const CGFloat kMinTextViewHeight = 38;
const CGFloat kMaxTextViewHeight = 98;
const CGFloat kMaxIPadTextViewHeight = 142;
const CGFloat kSendButtonHeight = 30;

static NSString *DTInputBarMoreCellID = @"DTInputBarMoreCellID";
#pragma mark -

@interface ConversationInputToolbar () <ConversationTextViewToolbarDelegate, DTInputReplyPreviewDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, readonly) ConversationStyle *conversationStyle;
@property (nonatomic, strong) UIVisualEffectView *blurEffectView;

@property (nonatomic, readonly) ConversationInputTextView *inputTextView;
@property (nonatomic, readonly) UIView *inputTextContentRowView;
@property (nonatomic, readonly) UIStackView *contentRows;
@property (nonatomic, readonly) UIStackView *composeRow;
@property (nonatomic, readonly) UIStackView *functionRow;
//@property (nonatomic, readonly) UIButton *attachmentButton;
@property (nonatomic, readonly) UIButton *voiceMemoButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *botMenuButton;
@property (nonatomic, weak) UILongPressGestureRecognizer *longPressGesture;
//@property(nonatomic, strong)UIButton *callButton;
@property (nonatomic, strong) NSArray <UIButton *> *btnFunctions;
@property (nonatomic, strong) UICollectionView *functionView;
@property (nonatomic, weak) UIView *functionSeparator;

@property (nonatomic) CGFloat textViewHeight;
@property (nonatomic, readonly) NSLayoutConstraint *inputTextContentHeightConstraint;
@property (nonatomic, readonly) NSLayoutConstraint *textViewHeightConstraint;

#pragma mark -

@property (nonatomic, nullable) UIView *replyMessagePreview;

#pragma mark - Voice Memo Recording UI

@property (nonatomic, nullable) UIView *voiceMemoUI;
@property (nonatomic, nullable) UIView *voiceMemoContentView;
@property (nonatomic) NSDate *voiceMemoStartTime;
@property (nonatomic, nullable) NSTimer *voiceMemoUpdateTimer;
@property (nonatomic, nullable) UILabel *recordingLabel;
@property (nonatomic) BOOL isRecordingVoiceMemo;
@property (nonatomic) CGPoint voiceMemoGestureStartLocation;
@property (nonatomic, assign) DTInputToolbarType type;
@property (nonatomic, assign) DTInputToobarState state;
@property (nonatomic, strong) NSArray <DTInputToolBarMoreItem *> *moreItems;
@property(nonatomic, assign) BOOL isDragged;//用户是否进行了拖拽
@property(nonatomic, assign, readwrite) BOOL replyToUser;
@property (nonatomic, strong) TSThread *thread;

#pragma mark - Keyboards

@property (nonatomic) KeyboardType desiredKeyboardType;
@property (nonatomic) BOOL isMeasuringKeyboardHeight;
//@property (nonatomic, strong, nullable) OWSQuotedReplyModel *quotedReply;
@property (nonatomic, weak) DTInputReplyPreview *quotedMessagePreview;

@property (nonatomic, strong) UIView *topLine;

@end

@implementation ConversationInputToolbar

- (instancetype)initWithConversationStyle:(ConversationStyle *)conversationStyle withType:(DTInputToolbarType)type thread:(TSThread *)thread
{
    self = [super initWithFrame:CGRectZero];
    _type = type;
    _thread = thread;
    _conversationStyle = conversationStyle;
    
    if (self) {
        _atCache = [DTInputAtCache new];
        [self createContents];
        [self applyTheme];
        _isDragged = false;
        self.inputTextView.layoutManager.allowsNonContiguousLayout = NO;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(isStickerSendEnabledDidChange:)
//                                                 name:StickerManager.isStickerSendEnabledDidChange
//                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardFrameDidChange:)
                                                 name:UIKeyboardDidChangeFrameNotification
                                               object:nil];
    
    return self;
}

- (CGSize)intrinsicContentSize
{
    // Since we have `self.autoresizingMask = UIViewAutoresizingFlexibleHeight`, we must specify
    // an intrinsicContentSize. Specifying CGSize.zero causes the height to be determined by autolayout.
    return CGSizeZero;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    self.inputTextView.placeholder = placeholder;
}

- (UIColor *)backgroundColor_ {
//    return Theme.isDarkThemeEnabled ? [UIColor colorWithRgbHex:0x1C1C1C] : [UIColor colorWithRgbHex:0xF5F5F5];
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF];
}

- (void)applyTheme {
    
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        self.backgroundColor = self.backgroundColor_;
    } else {
        self.backgroundColor = [self.backgroundColor_ colorWithAlphaComponent:0.8];
        _blurEffectView.effect = Theme.barBlurEffect;
    }
    
    self.inputTextContentRowView.backgroundColor = Theme.toolbarBackgroundColor;
//    self.attachmentButton.tintColor = Theme.primaryIconColor;
    self.voiceMemoButton.tintColor = Theme.secondaryTextAndIconColor;
//    self.callButton.tintColor = Theme.primaryIconColor;
    for (UIButton *btn in self.btnFunctions) {
        btn.tintColor = Theme.secondaryTextAndIconColor;
    }
    self.functionSeparator.backgroundColor = Theme.outlineColor;
    [self.functionView reloadData];
    [self.inputTextView applyTheme];
    
    [self.quotedMessagePreview applyTheme];
    _topLine.backgroundColor = Theme.isDarkThemeEnabled ?  [UIColor colorWithRGBHex:0x474D57] :  [UIColor colorWithRGBHex:0xEAECEF];
}

- (void)createContents
{
    self.layoutMargins = UIEdgeInsetsZero;

    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        self.backgroundColor = self.backgroundColor_;
    } else {
        self.backgroundColor = [self.backgroundColor_ colorWithAlphaComponent:0.8];

        _blurEffectView = [[UIVisualEffectView alloc] initWithEffect:Theme.barBlurEffect];
        [self addSubview:_blurEffectView];
        [_blurEffectView autoPinEdgesToSuperviewEdges];
    }
    
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight;

    _topLine = [[UIView alloc] init];
    _topLine.backgroundColor = Theme.isDarkThemeEnabled ?  [UIColor colorWithRGBHex:0x474D57] :  [UIColor colorWithRGBHex:0xEAECEF];
    [self addSubview:_topLine];
    [_topLine autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self];
    [_topLine autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self];
    [_topLine autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self];
    [_topLine autoSetDimension:ALDimensionHeight toSize:.5];
    
    UIView *inputTextContentRowView = [[UIView alloc] init];
    _inputTextContentRowView = inputTextContentRowView;
    inputTextContentRowView.layer.borderColor = [UIColor.ows_blackColor colorWithAlphaComponent:0.12f].CGColor;
    inputTextContentRowView.layer.borderWidth = 0.5f;
    inputTextContentRowView.backgroundColor = Theme.toolbarBackgroundColor;
    inputTextContentRowView.layer.cornerRadius = 5.0;
    inputTextContentRowView.layer.masksToBounds = true;

    ConversationInputTextView *inputTextView = [ConversationInputTextView new];
    _inputTextView = inputTextView;
    [inputTextContentRowView addSubview:inputTextView];
    inputTextView.textViewToolbarDelegate = self;
    inputTextView.font = [UIFont ows_dynamicTypeBodyFont];
    inputTextView.returnKeyType = UIReturnKeyDefault;
    
    inputTextView.textContainerInset = UIEdgeInsetsMake(8, 2, 8, 2);
    [inputTextView autoPinEdgesToSuperviewEdges];
    _textViewHeightConstraint = [_inputTextView autoSetDimension:ALDimensionHeight toSize:kMinTextViewHeight];
    
    [inputTextContentRowView setContentHuggingHorizontalLow];
    _inputTextContentHeightConstraint = [inputTextContentRowView autoSetDimension:ALDimensionHeight toSize:kMinTextViewHeight];
    
    UIImage *voiceMemoIcon = [UIImage imageNamed:@"ic_inputbar_mic"];
    OWSAssertDebug(voiceMemoIcon);
    _voiceMemoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.voiceMemoButton setImage:[voiceMemoIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                          forState:UIControlStateNormal];
    [self.voiceMemoButton autoSetDimensionsToSize:CGSizeMake(40, kMinTextViewHeight)];

    // We want to be permissive about the voice message gesture, so we hang
    // the long press GR on the button's wrapper, not the button itself.
    UILongPressGestureRecognizer *longPressGestureRecognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGesture = longPressGestureRecognizer;
    longPressGestureRecognizer.minimumPressDuration = 0;
    [self.voiceMemoButton addGestureRecognizer:longPressGestureRecognizer];
    
    _sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.hidden = YES;
    [self.sendButton setImage:[UIImage imageNamed:@"ic_inputbar_send"] forState:UIControlStateNormal];
    [self.sendButton setImage:[UIImage imageNamed:@"ic_inputbar_send"] forState:UIControlStateHighlighted];
    [self.sendButton autoSetDimensionsToSize:CGSizeMake(40, kMinTextViewHeight)];
    [self.sendButton addTarget:self action:@selector(sendButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    _botMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botMenuButton.hidden = YES;
    [self.botMenuButton setImage:[UIImage imageNamed:@"ic_inputbar_bot_menu"] forState: UIControlStateNormal];
    [self.botMenuButton setImage:[UIImage imageNamed:@"ic_inputbar_bot_menu"] forState: UIControlStateHighlighted];
    [self.botMenuButton autoSetDimensionsToSize:CGSizeMake(40, kMinTextViewHeight)];
    [self.botMenuButton addTarget:self action:@selector(botMenuButtonClick:) forControlEvents:UIControlEventTouchUpInside];

    self.userInteractionEnabled = YES;

    _composeRow = [[UIStackView alloc]
                   initWithArrangedSubviews:@[self.inputTextContentRowView, self.voiceMemoButton, self.sendButton, self.botMenuButton]];
    self.composeRow.axis = UILayoutConstraintAxisHorizontal;
    self.composeRow.layoutMarginsRelativeArrangement = YES;
    self.composeRow.layoutMargins = UIEdgeInsetsMake(6, 6, 6, 4);
    self.composeRow.alignment = UIStackViewAlignmentBottom;
    self.composeRow.spacing = 8;
    
    UIView *spacer = [UIView containerView];
    [spacer setContentHuggingHorizontalLow];
    _functionRow = [[UIStackView alloc] initWithArrangedSubviews:@[spacer]];
    self.functionRow.axis = UILayoutConstraintAxisHorizontal;
    self.functionRow.layoutMarginsRelativeArrangement = YES;
    self.functionRow.layoutMargins = UIEdgeInsetsMake(0, 12, 6, 5.5);
    self.functionRow.alignment = UIStackViewAlignmentCenter;
    self.functionRow.spacing = 12;

    NSMutableArray *tempBtns = @[].mutableCopy;
    
    UIButton *gifButton = [self btnFuctionWithTag:DTInputToobarItemTag_Gif iconName:@"ic_inputbar_gif"];
    [self.functionRow addArrangedSubview:gifButton];
    [tempBtns addObject:gifButton];
    
    if (![self.thread isBotThread]) {
        UIButton *btnTopicList = [self btnFuctionWithTag:DTInputToobarItemTag_TopicList iconName:@"ic_inputbar_topic_list"];
        [self.functionRow addArrangedSubview:btnTopicList];
        [tempBtns addObject:btnTopicList];
    }
    
    if (self.type == DTInputToolbarTypeSupportGroupThread) {
        UIButton *btnThreadReply = [self btnFuctionWithTag:DTInputToobarItemTag_Reply iconName:@"ic_inputbar_reply_to_user_normal"];
        [self.functionRow addArrangedSubview:btnThreadReply];
        [tempBtns addObject:btnThreadReply];
    }
    
    UIButton *btnGallery = [self btnFuctionWithTag:DTInputToobarItemTag_Gallery iconName:@"ic_inputbar_image"];
    [self.functionRow addArrangedSubview:btnGallery];
    [tempBtns addObject:btnGallery];
    
    UIButton *btnCamera = [self btnFuctionWithTag:DTInputToobarItemTag_Camera iconName:@"ic_inputbar_camera"];
    [self.functionRow addArrangedSubview:btnCamera];
    [tempBtns addObject:btnCamera];

    if (self.type != DTInputToolbarTypeNote) {
        UIButton *btnTranslate = [self btnFuctionWithTag:DTInputToobarItemTag_Translate iconName:@"ic_inputbar_translate"];
        [self.functionRow addArrangedSubview:btnTranslate];
        [tempBtns addObject:btnTranslate];
    }
    
//    if (self.type == DTInputToolbarTypeGroup) {
        UIButton *btnAt = [self btnFuctionWithTag:DTInputToobarItemTag_At iconName:@"ic_inputbar_at"];
        [self.functionRow addArrangedSubview:btnAt];
        [tempBtns addObject:btnAt];
//    }
    
    UIButton *btnMore = [self btnFuctionWithTag:DTInputToobarItemTag_More iconName:@"ic_inputbar_more"];
    [self.functionRow addArrangedSubview:btnMore];
    [tempBtns addObject:btnMore];
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat buttonsWidth = 40 * tempBtns.count;
    CGFloat buttonWidthWithLeftMargin = buttonsWidth + 5.5;
    CGFloat buttonsWidthWithSpacing = buttonWidthWithLeftMargin + (tempBtns.count - 1) * 12;
    CGFloat buttonsWidthWithSpacer = buttonsWidthWithSpacing + 24;
    
    if (buttonsWidth > screenWidth) {
        CGFloat buttonWidth = floor(screenWidth / tempBtns.count);
        for (UIButton *button in tempBtns) {
            [button autoSetDimensionsToSize:CGSizeMake(buttonWidth, 36)];
        }
        [spacer removeFromSuperview];
        self.functionRow.spacing = 0;
        self.functionRow.layoutMargins = UIEdgeInsetsMake(0, 0, 6, 0);
        self.functionRow.distribution = UIStackViewDistributionEqualSpacing;
        
    } else if (buttonWidthWithLeftMargin > screenWidth) {
        [spacer removeFromSuperview];
        self.functionRow.spacing = 0;
        self.functionRow.layoutMargins = UIEdgeInsetsMake(0, 0, 6, screenWidth - buttonsWidth);
        self.functionRow.distribution = UIStackViewDistributionEqualSpacing;
        
    } else if (buttonsWidthWithSpacing > screenWidth) {
        [spacer removeFromSuperview];
        self.functionRow.spacing = 0;
        self.functionRow.layoutMargins = UIEdgeInsetsMake(0, 0, 6, 5.5);
        self.functionRow.distribution = UIStackViewDistributionEqualSpacing;
        
    } else if (buttonsWidthWithSpacer > screenWidth) {
        [spacer removeFromSuperview];
        self.functionRow.spacing = 12;
        self.functionRow.layoutMargins = UIEdgeInsetsMake(0, screenWidth - buttonsWidthWithSpacing, 6, 5.5);
        
    } else {
        // spacing is enough, do nothing
    }
    
    self.btnFunctions = tempBtns.copy;

    _contentRows = [[UIStackView alloc] initWithArrangedSubviews:@[self.composeRow, self.functionRow, self.functionView]];
    self.contentRows.axis = UILayoutConstraintAxisVertical;

    [self addSubview:self.contentRows];
    [self.contentRows autoPinEdgesToSuperviewSafeArea];

    [self ensureShouldShowSendButton];
}

- (UIButton *)btnFuctionWithTag:(NSInteger)tag iconName:(NSString *)iconName {
    
    UIButton *btnFunction = [UIButton buttonWithType:UIButtonTypeCustom];
    btnFunction.tag = tag;
    UIImage *functionIcon = [[UIImage imageNamed:iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    btnFunction.imageView.tintColor = Theme.secondaryTextAndIconColor;
    [btnFunction setImage:functionIcon forState:UIControlStateNormal];
    [btnFunction setImage:functionIcon forState:UIControlStateHighlighted];
    [btnFunction addTarget:self action:@selector(btnFunctionAction:) forControlEvents:UIControlEventTouchUpInside];
    [btnFunction autoSetDimensionsToSize:CGSizeMake(40, 36)];

    return btnFunction;
}

- (void)sendButtonClick:(UIButton *)sender {
//    NSString *inputText = self.inputTextView.text;
//    DTInputAtItem *item = [self getFirstAtInfoWithTextMessage:inputText];
//    if ([inputText hasPrefix:kMentionStartChar]  && item && [inputText hasPrefix:item.name]) {
//        if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(senderButtonPressed:view:atItem:)]) {
//            [self.inputToolbarDelegate senderButtonPressed:self view:self.inputTextView atItem:item];
//        }
//        return;
//    }
    
    if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(senderButtonPressed:view:)]) {
        [self.inputToolbarDelegate senderButtonPressed:self view:self.inputTextView];
    }
}

- (void)botMenuButtonClick:(UIButton *)sender {
    if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(botMenuButtonPressed:)]) {
        [self.inputToolbarDelegate botMenuButtonPressed:self];
    }
}

- (DTInputAtItem *)getFirstAtInfoWithTextMessage:(NSString *)string {
    NSArray *allAtShowNameArr = [self.atCache allAtShowName:string];
    if (allAtShowNameArr && allAtShowNameArr.count) {
        return allAtShowNameArr.firstObject;
    }else {
        return nil;
    }
}

- (void)btnFunctionAction:(UIButton *)sender {
    
    if (sender.tag == DTInputToobarItemTag_More) {
        DTInputToobarState state = DTInputToobarStateNone;
        if (self.state == DTInputToobarStateMoreView) {
            [self.inputTextView becomeFirstResponder];
            state = DTInputToobarStateKeyboard;
        } else {
            state = DTInputToobarStateMoreView;
            if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(inputToolbarMoreViewItems)]) {
                self.moreItems = [self.inputToolbarDelegate inputToolbarMoreViewItems];
                [UIView performWithoutAnimation:^{
                    [self.functionView reloadData];
                }];
            }
        }
        [self switchFunctionViewState:state animated:YES];
    } else {
        if (self.state == DTInputToobarStateMoreView && sender.tag != DTInputToobarItemTag_Translate) {
            [self switchFunctionViewState:DTInputToobarStateNone animated:YES];
        }
    }
    
    if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(functionButtonPressed:tag:)]) {
        [self.inputToolbarDelegate functionButtonPressed:self tag:sender.tag];
    }
}

- (void)inputTextContentRowViewClick:(UITapGestureRecognizer *)tap {
    [self.inputTextView becomeFirstResponder];
}

/*
- (UIButton *)customCallButton {
    UIButton *callButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [[UIImage imageNamed:@"icon_voice_call_btn"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [callButton setImage:image forState:UIControlStateNormal];
    
    if (OWSWindowManager.sharedManager.hasCall) {
        callButton.enabled = NO;
        callButton.userInteractionEnabled = NO;
        callButton.tintColor = Theme.primaryIconColor;
    } else {
        callButton.enabled = YES;
        callButton.userInteractionEnabled = YES;
        callButton.tintColor = Theme.primaryIconColor;
    }
    callButton.accessibilityLabel = Localized(@"CALL_LABEL", "Accessibility label for placing call button");
    [callButton addTarget:self action:@selector(startAudioCall:) forControlEvents:UIControlEventTouchUpInside];
    callButton.tintColor = Theme.primaryIconColor;
    return callButton;
}
 
- (void)startAudioCall:(UIButton *)sender {
    if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(callButtonPressed:sender:)]) {
        [self.inputToolbarDelegate callButtonPressed:self sender:sender];
    }
}
 */

- (void)updateFontSizes {
    self.inputTextView.font = [UIFont ows_dynamicTypeBodyFont];
}

//- (void)layoutSubviews {
//    [super layoutSubviews];
//    [self ensureTextViewHeight];
//    [self performcheckOptionContentWithDelayTime:0.003];
//}
//
//- (void)performcheckOptionContentWithDelayTime:(double) time {
//    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTextViewSize) object:nil];
//    [self performSelector:@selector(updateTextViewSize) withObject:nil afterDelay:time inModes:@[NSDefaultRunLoopMode]];
//}
//
//- (void)updateTextViewSize {
//    if (!_isDragged) {
//        [self.inputTextView scrollRangeToVisible:NSMakeRange(self.inputTextView.text.length - 1, 1)];
//    }
//}

- (void)setInputTextViewDelegate:(id<ConversationInputTextViewDelegate>)value
{
    OWSAssertDebug(self.inputTextView);
    OWSAssertDebug(value);

    self.inputTextView.inputTextViewDelegate = value;
}

- (NSString *)messageText
{
    OWSAssertDebug(self.inputTextView);

    return self.inputTextView.trimmedText;
}

- (NSString *)originMessageText {
    OWSAssertDebug(self.inputTextView);

    return self.inputTextView.untrimmedText;
}

- (void)setMessageText:(NSString *_Nullable)value animated:(BOOL)isAnimated {
    
    [self setMessageText:value selectRange:NSMakeRange(0, 0) animated:isAnimated];
}

- (void)setMessageText:(NSString *_Nullable)value selectRange:(NSRange)selectRange animated:(BOOL)isAnimated {
    
    OWSAssertDebug(self.inputTextView);

    self.inputTextView.text = value;

    // It's important that we set the textViewHeight before
    // doing any animation in `ensureButtonVisibilityWithIsAnimated`
    // Otherwise, the resultant keyboard frame posted in `keyboardWillChangeFrame`
    // could reflect the inputTextView height *before* the new text was set.
    //
    // This bug was surfaced to the user as:
    //  - have a quoted reply draft in the input toolbar
    //  - type a multiline message
    //  - hit send
    //  - quoted reply preview and message text is cleared
    //  - input toolbar is shrunk to it's expected empty-text height
    //  - *but* the conversation's bottom content inset was too large. Specifically, it was
    //    still sized as if the input textview was multiple lines.
    // Presumably this bug only surfaced when an animation coincides with more complicated layout
    // changes (in this case while simultaneous with removing quoted reply subviews, hiding the
    // wrapper view *and* changing the height of the input textView
    [self ensureTextViewHeight];
    [self ensureShouldShowSendButton];
//    [self.inputTextView sizeToFit];
    if (selectRange.location > 0) {
        self.inputTextView.selectedRange = selectRange;
    }
}

- (void)clearTextMessageAnimated:(BOOL)isAnimated
{
    [self setMessageText:nil animated:isAnimated];
    [self.inputTextView.undoManager removeAllActions];
}

- (void)toggleDefaultKeyboard
{
    // Primary language is nil for the emoji keyboard.
    if (!self.inputTextView.textInputMode.primaryLanguage) {
        // Stay on emoji keyboard after sending
        return;
    }

    // Otherwise, we want to toggle back to default keyboard if the user had the numeric keyboard present.

    // Momentarily switch to a non-default keyboard, else reloadInputViews
    // will not affect the displayed keyboard. In practice this isn't perceptable to the user.
    // The alternative would be to dismiss-and-pop the keyboard, but that can cause a more pronounced animation.
    self.inputTextView.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    [self.inputTextView reloadInputViews];

    self.inputTextView.keyboardType = UIKeyboardTypeDefault;
    [self.inputTextView reloadInputViews];
}

- (void)setReplyModel:(nullable DTReplyModel *)replyModel {
    if (replyModel == nil && [_replyModel isKindOfClass:OWSQuotedReplyModel.class]) {
        [self setQuotedReply:nil];return;
    } else if (replyModel == nil && [_replyModel isKindOfClass:DTTopicReplyModel.class]) {
        [self setTopicReplyModel:nil];return;
    }
    
    if ([replyModel isKindOfClass:[DTTopicReplyModel class]]) {
        [self setTopicReplyModel:(DTTopicReplyModel *)replyModel];
    } else if ([replyModel isKindOfClass: [OWSQuotedReplyModel class]]) {
        [self setQuotedReply:(OWSQuotedReplyModel *)replyModel];
    }
}

- (void)setTopicReplyModel:(nullable DTTopicReplyModel *)topicReplyMode {
    /// ⚠️待处理
    if (self.replyMessagePreview) {
        [self clearReplyMessagePreview];

    }
    OWSAssertDebug(self.replyMessagePreview == nil);

    _replyModel = topicReplyMode;
    if (!topicReplyMode) {
        [self clearReplyMessagePreview];
        return;
    }
    
    /// 暂时先去掉Topic中的 reply提示窗
    //    DTInputReplyPreviewDelegate
    if ([topicReplyMode.replyItemInteraction isKindOfClass:TSMessage.class]) {
//        TSMessage *message = (TSMessage *)topicReplyMode.replyItemInteraction;
        DTInputReplyPreview *quotedMessagePreview =
        [[DTInputReplyPreview alloc] initWithQuotedReply:topicReplyMode conversationStyle:self.conversationStyle];
        _quotedMessagePreview = quotedMessagePreview;
        quotedMessagePreview.delegate = self;
        
        UIView *wrapper = [UIView containerView];
        wrapper.layoutMargins = UIEdgeInsetsMake(self.quotedMessageTopMargin, 0, 0, 0);
        [wrapper addSubview:quotedMessagePreview];
        [quotedMessagePreview autoPinEdgesToSuperviewEdges];
        
        [self.contentRows insertArrangedSubview:wrapper atIndex:0];
        self.replyMessagePreview = wrapper;
    }
       
};

- (void)setQuotedReply:(nullable OWSQuotedReplyModel *)quotedReply showQuotedMessagePreview:(BOOL)isShowPreview {
    if (isShowPreview) {
        [self setQuotedReply:quotedReply];
    }else {
        if (self.replyMessagePreview || !quotedReply) {
            [self clearReplyMessagePreview];
        }
        _replyModel = quotedReply;
    }
}

- (void)setQuotedReply:(nullable OWSQuotedReplyModel *)quotedReply
{
    if (self.replyMessagePreview) {
        [self clearReplyMessagePreview];
    }
    OWSAssertDebug(self.replyMessagePreview == nil);

    _replyModel = quotedReply;
    
    if (!quotedReply) {
        [self clearReplyMessagePreview];
        return;
    }
//    DTInputReplyPreviewDelegate
    DTInputReplyPreview *quotedMessagePreview =
        [[DTInputReplyPreview alloc] initWithQuotedReply:quotedReply conversationStyle:self.conversationStyle];
    _quotedMessagePreview = quotedMessagePreview;
    quotedMessagePreview.delegate = self;

    UIView *wrapper = [UIView containerView];
    wrapper.layoutMargins = UIEdgeInsetsMake(self.quotedMessageTopMargin, 0, 0, 0);
    [wrapper addSubview:quotedMessagePreview];
    [quotedMessagePreview autoPinEdgesToSuperviewEdges];

    [self.contentRows insertArrangedSubview:wrapper atIndex:0];

    self.replyMessagePreview = wrapper;
}

- (void)setIsCouldShowBotMenu:(BOOL)isCouldShowBotMenu {
    if (_isCouldShowBotMenu != isCouldShowBotMenu) {
        _isCouldShowBotMenu = isCouldShowBotMenu;
        [self ensureShouldShowSendButton];
    }
}

- (CGFloat)quotedMessageTopMargin
{
    return 5.f;
}

- (void)clearReplyMessagePreview
{
    if (self.replyMessagePreview) {
        [self.contentRows removeArrangedSubview:self.replyMessagePreview];
        [self.replyMessagePreview removeFromSuperview];
        self.replyMessagePreview = nil;
    }
}

- (BOOL)isInputTextViewFirstResponder
{
    return self.inputTextView.isFirstResponder;
}

- (BOOL)needShowSendBtn {
    // 1.如果输入框有值，展示发送按钮
    return self.inputTextView.trimmedText.length > 0 || self.textInputOnly;
}

- (void)ensureShouldShowSendButton {
    if (self.needShowSendBtn) {
        self.sendButton.hidden = NO;
        self.botMenuButton.hidden = YES;
        self.voiceMemoButton.hidden = YES;
        
    } else if (self.isCouldShowBotMenu) { // 2.如果输入框没有值，并且 bot menu 有配置
        self.sendButton.hidden = YES;
        self.botMenuButton.hidden = NO;
        self.voiceMemoButton.hidden = YES;
        
    } else { // 3.如果输入框没有值，并且没有配置 bot menu，展示语音按钮
        self.sendButton.hidden = YES;
        self.botMenuButton.hidden = YES;
        self.voiceMemoButton.hidden = NO;
    }
}
    
- (void)handleLongPress:(UIGestureRecognizer *)sender
{
    switch (sender.state) {
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            if (self.isRecordingVoiceMemo) {
                // Cancel voice message if necessary.
                self.isRecordingVoiceMemo = NO;
                [self.inputToolbarDelegate voiceMemoGestureDidCancel];
            }
            break;
        case UIGestureRecognizerStateBegan:
            if (self.isRecordingVoiceMemo) {
                // Cancel voice message if necessary.
                self.isRecordingVoiceMemo = NO;
                [self.inputToolbarDelegate voiceMemoGestureDidCancel];
            }
            // Start voice message.
            self.isRecordingVoiceMemo = YES;
            self.voiceMemoGestureStartLocation = [sender locationInView:self];
            [self.inputToolbarDelegate voiceMemoGestureDidStart];
            break;
        case UIGestureRecognizerStateChanged:
            if (self.isRecordingVoiceMemo) {
                // Check for "slide to cancel" gesture.
                CGPoint location = [sender locationInView:self];
                // For LTR/RTL, swiping in either direction will cancel.
                // This is okay because there's only space on screen to perform the
                // gesture in one direction.
                CGFloat offset = fabs(self.voiceMemoGestureStartLocation.x - location.x);
                // The lower this value, the easier it is to cancel by accident.
                // The higher this value, the harder it is to cancel.
                const CGFloat kCancelOffsetPoints = 100.f;
                CGFloat cancelAlpha = offset / kCancelOffsetPoints;
                BOOL isCancelled = cancelAlpha >= 1.f;
                if (isCancelled) {
                    self.isRecordingVoiceMemo = NO;
                    [self.inputToolbarDelegate voiceMemoGestureDidCancel];
                } else {
                    [self.inputToolbarDelegate voiceMemoGestureDidChange:cancelAlpha];
                }
            }
            break;
        case UIGestureRecognizerStateEnded:
            if (self.isRecordingVoiceMemo) {
                // End voice message.
                self.isRecordingVoiceMemo = NO;
                [self.inputToolbarDelegate voiceMemoGestureDidEnd];
            }
            break;
    }
}

- (void)beginEditingMessage
{
    if (!self.desiredFirstResponder.isFirstResponder) {
        [self.desiredFirstResponder becomeFirstResponder];
    }
}

- (void)endEditingMessage
{
    [self.inputTextView resignFirstResponder];
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wunused-result"
//    [self.stickerKeyboard resignFirstResponder];
//    [self.attachmentKeyboard resignFirstResponder];
//#pragma clang diagnostic pop
}

- (BOOL)isInputViewFirstResponder
{
    return (self.inputTextView.isFirstResponder);// || self.stickerKeyboard.isFirstResponder
//            || self.attachmentKeyboard.isFirstResponder);
}

- (void)ensureButtonVisibilityWithIsAnimated:(BOOL)isAnimated doLayout:(BOOL)doLayout
{
//    __block BOOL didChangeLayout = NO;
//    void (^ensureViewHiddenState)(UIView *, BOOL) = ^(UIView *subview, BOOL hidden) {
//        if (subview.isHidden != hidden) {
//            subview.hidden = hidden;
//            didChangeLayout = YES;
//        }
//    };
//
//    // NOTE: We use untrimmedText, so that the sticker button disappears
//    //       even if the user just enters whitespace.
//    BOOL hasTextInput = self.inputTextView.untrimmedText.length > 0;
//    ensureViewHiddenState(self.attachmentButton, NO);
//    if (hasTextInput) {
//        ensureViewHiddenState(self.cameraButton, YES);
//        ensureViewHiddenState(self.voiceMemoButton, YES);
//        ensureViewHiddenState(self.sendButton, NO);
//    } else {
//        ensureViewHiddenState(self.cameraButton, NO);
//        ensureViewHiddenState(self.voiceMemoButton, NO);
//        ensureViewHiddenState(self.sendButton, YES);
//    }
//
//    // If the layout has changed, update the layout
//    // of the "media and send" stack immediately,
//    // to avoid a janky animation where these buttons
//    // move around far from their final positions.
//    if (doLayout && didChangeLayout) {
//        [self.mediaAndSendStack setNeedsLayout];
//        [self.mediaAndSendStack layoutIfNeeded];
//    }
//
//    void (^updateBlock)(void) = ^{
//        BOOL hideStickerButton = hasTextInput || self.quotedReply != nil || !StickerManager.shared.isStickerSendEnabled;
//        ensureViewHiddenState(self.stickerButton, hideStickerButton);
//        if (!hideStickerButton) {
//            self.stickerButton.imageView.tintColor
//            = (self.desiredKeyboardType == KeyboardType_Sticker ? UIColor.ows_signalBlueColor
//               : Theme.primaryIconColor);
//        }
//
//        self.attachmentButton.selected = self.desiredKeyboardType == KeyboardType_Attachment;
//
//        [self updateSuggestedStickers];
//
//        if (self.stickerButton.hidden || self.stickerKeyboard.isFirstResponder) {
//            [self removeStickerTooltip];
//        }
//
//        if (doLayout) {
//            [self layoutIfNeeded];
//        }
//    };
//
//    if (isAnimated) {
//        [UIView animateWithDuration:0.1 animations:updateBlock];
//    } else {
//        updateBlock();
//    }
//
//    [self showStickerTooltipIfNecessary];
}

#pragma mark - Voice Memo

- (void)showVoiceMemoUI
{
    OWSAssertIsOnMainThread();

    self.voiceMemoStartTime = [NSDate date];

    [self.voiceMemoUI removeFromSuperview];

    self.voiceMemoUI = [UIView new];
    self.voiceMemoUI.userInteractionEnabled = NO;
    self.voiceMemoUI.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRgbHex:0x1C1C1C] : [UIColor colorWithRGBHex:0xF9F9F9];
    [self addSubview:self.voiceMemoUI];
    self.voiceMemoUI.frame = CGRectMake(0, 0, self.bounds.size.width, self.inputTextContentRowView.height + self.functionRow.height);

    self.voiceMemoContentView = [UIView new];
    [self.voiceMemoUI addSubview:self.voiceMemoContentView];
    [self.voiceMemoContentView autoPinEdgesToSuperviewSafeArea];

    self.recordingLabel = [UILabel new];
    self.recordingLabel.textColor = [UIColor ows_destructiveRedColor];
    self.recordingLabel.font = [UIFont ows_semiboldFontWithSize:14.f];
    [self.voiceMemoContentView addSubview:self.recordingLabel];
    [self updateVoiceMemo];

    UIImage *icon = [UIImage imageNamed:@"voice-memo-button"];
    OWSAssertDebug(icon);
    UIImageView *imageView =
        [[UIImageView alloc] initWithImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    imageView.tintColor = [UIColor ows_destructiveRedColor];
    [self.voiceMemoContentView addSubview:imageView];

    NSMutableAttributedString *cancelString = [NSMutableAttributedString new];
    const CGFloat cancelArrowFontSize = ScaleFromIPhone5To7Plus(18.4, 20.f);
    const CGFloat cancelFontSize = ScaleFromIPhone5To7Plus(14.f, 16.f);
    NSString *arrowHead = (CurrentAppContext().isRTL ? @"\uf105" : @"\uf104");
//    NSString *arrowHead = @"\uf105" ;
    [cancelString
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:arrowHead
                                       attributes:@{
                                           NSFontAttributeName : [UIFont ows_fontAwesomeFont:cancelArrowFontSize],
                                           NSForegroundColorAttributeName : [UIColor ows_destructiveRedColor],
                                           NSBaselineOffsetAttributeName : @(-1.f),
                                       }]];
    [cancelString
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:@"  "
                                       attributes:@{
                                           NSFontAttributeName : [UIFont ows_fontAwesomeFont:cancelArrowFontSize],
                                           NSForegroundColorAttributeName : [UIColor ows_destructiveRedColor],
                                           NSBaselineOffsetAttributeName : @(-1.f),
                                       }]];
    [cancelString
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:Localized(@"VOICE_MESSAGE_CANCEL_INSTRUCTIONS",
                                                      @"Indicates how to cancel a voice message.")
                                       attributes:@{
                                           NSFontAttributeName : [UIFont ows_semiboldFontWithSize:cancelFontSize],
                                           NSForegroundColorAttributeName : [UIColor ows_destructiveRedColor],
                                       }]];
    [cancelString
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:@"  "
                                       attributes:@{
                                           NSFontAttributeName : [UIFont ows_fontAwesomeFont:cancelArrowFontSize],
                                           NSForegroundColorAttributeName : [UIColor ows_destructiveRedColor],
                                           NSBaselineOffsetAttributeName : @(-1.f),
                                       }]];
    [cancelString
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:arrowHead
                                       attributes:@{
                                           NSFontAttributeName : [UIFont ows_fontAwesomeFont:cancelArrowFontSize],
                                           NSForegroundColorAttributeName : [UIColor ows_destructiveRedColor],
                                           NSBaselineOffsetAttributeName : @(-1.f),
                                       }]];
    UILabel *cancelLabel = [UILabel new];
    cancelLabel.attributedText = cancelString;
    [self.voiceMemoContentView addSubview:cancelLabel];

    const CGFloat kRedCircleSize = 100.f;
    UIView *redCircleView = [UIView new];
    redCircleView.backgroundColor = [UIColor ows_destructiveRedColor];
    redCircleView.layer.cornerRadius = kRedCircleSize * 0.5f;
    [redCircleView autoSetDimension:ALDimensionWidth toSize:kRedCircleSize];
    [redCircleView autoSetDimension:ALDimensionHeight toSize:kRedCircleSize];
    [self.voiceMemoContentView addSubview:redCircleView];
    [redCircleView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.voiceMemoButton];
    [redCircleView autoAlignAxis:ALAxisVertical toSameAxisOfView:self.voiceMemoButton];

    UIImage *whiteIcon = [UIImage imageNamed:@"voice-message-large-white"];
    OWSAssertDebug(whiteIcon);
    UIImageView *whiteIconView = [[UIImageView alloc] initWithImage:whiteIcon];
    [redCircleView addSubview:whiteIconView];
    [whiteIconView autoCenterInSuperview];

    [imageView autoVCenterInSuperview];
    [imageView autoPinLeadingToSuperviewMarginWithInset:10.f];
    [self.recordingLabel autoVCenterInSuperview];
    [self.recordingLabel autoPinLeadingToTrailingEdgeOfView:imageView offset:5.f];
    [cancelLabel autoVCenterInSuperview];
    [cancelLabel autoHCenterInSuperview];
    [self.voiceMemoUI setNeedsLayout];
    [self.voiceMemoUI layoutSubviews];

    // Slide in the "slide to cancel" label.
    CGRect cancelLabelStartFrame = cancelLabel.frame;
    CGRect cancelLabelEndFrame = cancelLabel.frame;
    cancelLabelStartFrame.origin.x
        = (CurrentAppContext().isRTL ? -self.voiceMemoUI.bounds.size.width : self.voiceMemoUI.bounds.size.width);
    cancelLabel.frame = cancelLabelStartFrame;
    [UIView animateWithDuration:0.35f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         cancelLabel.frame = cancelLabelEndFrame;
                     }
                     completion:nil];

    // Pulse the icon.
    imageView.layer.opacity = 1.f;
    [UIView animateWithDuration:0.5f
                          delay:0.2f
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                        | UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         imageView.layer.opacity = 0.f;
                     }
                     completion:nil];

    // Fade in the view.
    self.voiceMemoUI.layer.opacity = 0.f;
    [UIView animateWithDuration:0.2f
        animations:^{
            self.voiceMemoUI.layer.opacity = 1.f;
        }
        completion:^(BOOL finished) {
            if (finished) {
                self.voiceMemoUI.layer.opacity = 1.f;
            }
        }];

    [self.voiceMemoUpdateTimer invalidate];
    self.voiceMemoUpdateTimer = [NSTimer weakScheduledTimerWithTimeInterval:0.1f
                                                                     target:self
                                                                   selector:@selector(updateVoiceMemo)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)hideVoiceMemoUI:(BOOL)animated
{
    OWSAssertIsOnMainThread();

    UIView *oldVoiceMemoUI = self.voiceMemoUI;
    self.voiceMemoUI = nil;
    self.voiceMemoContentView = nil;
    self.recordingLabel = nil;
    NSTimer *voiceMemoUpdateTimer = self.voiceMemoUpdateTimer;
    self.voiceMemoUpdateTimer = nil;

    [oldVoiceMemoUI.layer removeAllAnimations];

    if (animated) {
        [UIView animateWithDuration:0.35f
            animations:^{
                oldVoiceMemoUI.layer.opacity = 0.f;
            }
            completion:^(BOOL finished) {
                [oldVoiceMemoUI removeFromSuperview];
                [voiceMemoUpdateTimer invalidate];
            }];
    } else {
        [oldVoiceMemoUI removeFromSuperview];
        [voiceMemoUpdateTimer invalidate];
    }
}

- (void)setVoiceMemoUICancelAlpha:(CGFloat)cancelAlpha
{
    OWSAssertIsOnMainThread();

    // Fade out the voice message views as the cancel gesture
    // proceeds as feedback.
    self.voiceMemoContentView.layer.opacity = MAX(0.f, MIN(1.f, 1.f - (float)cancelAlpha));
}

- (void)updateVoiceMemo
{
    OWSAssertIsOnMainThread();

    NSTimeInterval durationSeconds = fabs([self.voiceMemoStartTime timeIntervalSinceNow]);
    self.recordingLabel.text = [OWSFormat formatDurationSeconds:(long)round(durationSeconds)];
    [self.recordingLabel sizeToFit];
}

- (void)cancelVoiceMemoIfNecessary
{
    if (self.isRecordingVoiceMemo) {
        self.isRecordingVoiceMemo = NO;
    }
}

#pragma mark - Event Handlers


//- (void)attachmentButtonPressed
//{
//    OWSAssertDebug(self.inputToolbarDelegate);
//
//    [self.inputToolbarDelegate attachmentButtonPressed];
//}

#pragma mark - Keyboards

- (void)toggleKeyboardType:(KeyboardType)keyboardType
{
    OWSAssertDebug(self.inputToolbarDelegate);
    
    if (self.desiredKeyboardType == keyboardType) {
        self.desiredKeyboardType = KeyboardType_System;
    } else {
        self.desiredKeyboardType = keyboardType;
    }
    
    [self beginEditingMessage];
}

- (void)setDesiredKeyboardType:(KeyboardType)desiredKeyboardType
{
    if (_desiredKeyboardType == desiredKeyboardType) {
        return;
    }
    
    _desiredKeyboardType = desiredKeyboardType;
    
    [self ensureButtonVisibilityWithIsAnimated:NO doLayout:YES];
    
    if (self.isInputViewFirstResponder) {
        // If any keyboard is presented, make sure the correct
        // keyboard is presented.
        [self beginEditingMessage];
    } else {
        // Make sure neither keyboard is presented.
        [self endEditingMessage];
    }
}

- (void)clearDesiredKeyboard
{
    OWSAssertIsOnMainThread();
    
    self.desiredKeyboardType = KeyboardType_System;
}

- (UIResponder *)desiredFirstResponder
{
    switch (self.desiredKeyboardType) {
        case KeyboardType_System:
            return self.inputTextView;
        case KeyboardType_Sticker:
            return nil;//self.stickerKeyboard;
        case KeyboardType_Attachment:
            return nil;//self.attachmentKeyboard;
    }
}

- (void)showStickerKeyboard
{
    OWSAssertIsOnMainThread();
    
    if (self.desiredKeyboardType != KeyboardType_Sticker) {
        [self toggleKeyboardType:KeyboardType_Sticker];
    }
}

- (void)showAttachmentKeyboard
{
    OWSAssertIsOnMainThread();
    
    if (self.desiredKeyboardType != KeyboardType_Attachment) {
        [self toggleKeyboardType:KeyboardType_Attachment];
    }
}

#pragma mark -

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    [self restoreDesiredKeyboardIfNecessary];
}

- (void)ensureFirstResponderState
{
    [self restoreDesiredKeyboardIfNecessary];
}

- (void)restoreDesiredKeyboardIfNecessary
{
    OWSAssertIsOnMainThread();
    
    if (self.desiredKeyboardType != KeyboardType_System && !self.desiredFirstResponder.isFirstResponder) {
        [self.desiredFirstResponder becomeFirstResponder];
    }
}

- (void)keyboardFrameDidChange:(NSNotification *)notification
{
    NSValue *_Nullable keyboardEndFrameValue = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
    if (!keyboardEndFrameValue) {
        OWSFailDebug(@"Missing keyboard end frame");
        return;
    }
    CGRect keyboardEndFrame = [keyboardEndFrameValue CGRectValue];
    
    if (self.inputTextView.isFirstResponder || self.isMeasuringKeyboardHeight) {
        // The returned keyboard height includes the input view, so subtract our height.
        CGFloat newHeight = keyboardEndFrame.size.height - self.frame.size.height;
        if (newHeight > 0) {
//            [self.stickerKeyboard updateSystemKeyboardHeight:newHeight];
//            [self.attachmentKeyboard updateSystemKeyboardHeight:newHeight];
            self.isMeasuringKeyboardHeight = NO;
        }
    }
}

#pragma mark - view appear

- (void)viewDidAppear
{
    [self ensureButtonVisibilityWithIsAnimated:NO doLayout:NO];
    // MARK: 等后续加入表情键盘等自定键盘时，使用此方法提前探测自定义键盘高度
//    [self cacheKeyboardIfNecessary];
}

- (void)cacheKeyboardIfNecessary
{
    // Preload the keyboard if we're not showing it already, this
    // allows us to calculate the appropriate initial height for
    // our custom inputViews and in general to present it faster
    // We disable animations so this preload is invisible to the
    // user.
    //
    // We only measure the keyboard if the toolbar isn't hidden.
    // If it's hidden, we're likely here from a peek interaction
    // and don't want to show the keyboard. We'll measure it later.
    if (!self.inputTextView.isFirstResponder && !self.isHidden) {
        
        // Flag that we're measuring the system keyboard's height, so
        // even if though it won't be the first responder by the time
        // the notifications fire, we'll still read its measurement
        self.isMeasuringKeyboardHeight = YES;
        
        [UIView setAnimationsEnabled:NO];
        [self.inputTextView becomeFirstResponder];
        [self.inputTextView resignFirstResponder];
        [UIView setAnimationsEnabled:YES];
    }
}

- (void)ensureTextViewHeight
{
    [self updateHeightWithTextView:self.inputTextView];
}

#pragma mark - ConversationTextViewToolbarDelegate

- (void)setBounds:(CGRect)bounds
{
    CGFloat oldHeight = self.bounds.size.height;
    
    [super setBounds:bounds];
    
    if (oldHeight != bounds.size.height) {
        [self.inputToolbarDelegate updateToolbarHeight];
    }
}

- (void)textViewWillBeginDragging:(UIScrollView *)scrollView {
    _isDragged = true;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    
    DTInputToobarState state = DTInputToobarStateKeyboard;
    if (self.state == DTInputToobarStateMoreView) {
        [self switchFunctionViewState:state animated:YES];
    } else {
        self.state = state;
    }
    if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(beginInput)]) {
        [self.inputToolbarDelegate beginInput];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    OWSAssertDebug(self.inputToolbarDelegate);
    [self updateHeightWithTextView:textView];
    [self ensureShouldShowSendButton];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    
    /*
    if ([text isEqualToString:@""] && range.length == 1 ) {
        //非选择删除
        return [self onTextDelete];
    }
     */
    //是新增at就触发弹框
    if ([text isEqualToString:@"@"]) {
        NSRange atRange = self.inputTextView.selectedRange;
        [self.inputToolbarDelegate atIsActiveLocation:atRange.location + 1];
    }
//    if ([text isEqualToString:@"\n"]) {
//        if (self.inputToolbarDelegate && [self.inputToolbarDelegate respondsToSelector:@selector(senderButtonPressed:view:)]) {
//            [self.inputToolbarDelegate senderButtonPressed:self view:textView];
//        }
//        return NO;
//    }
    return YES;
}

- (BOOL)onTextDelete {
    //    NSRange range = [self delRangeForEmoticon];
    //    if (range.length == 1)
    //    {
    NSRange range = NSMakeRange(NSNotFound, 1);
    // 删的不是表情，可能是@
    DTInputAtItem *item = [self delRangeForAt];
    if (item) {
        range = item.range;
    }
//        }
    if (range.length == 1) {
        //自动删除
        return YES;
    }
    [self deleteText:range];
    return NO;
}

- (DTInputAtItem *)delRangeForAt {
    NSString *text = self.originMessageText;
    NSRange range = [self rangeForPrefix:kMentionStartChar suffix:kMentionEndChar];
    NSRange selectedRange = [self.inputTextView selectedRange];
    DTInputAtItem *item = nil;
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        //暂时@name逐字删除
        NSString *set = [kMentionStartChar stringByAppendingString:kMentionEndChar];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:set]];
        
        item = [self.atCache item:name];
        range = item? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    item.range = range;
    return item;
}

- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix {
    NSString *text = self.originMessageText;
    NSRange range = [self.inputTextView selectedRange];
    NSUInteger endLocation = range.location;
    NSString *selectedText = range.length ? [text substringWithRange:range] : [text substringToIndex:endLocation];
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        // 往前搜最多40个字符
        NSInteger p = 40;
        for (NSInteger i = endLocation-1; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
//            if ([subString compare:suffix] == NSOrderedSame) {
//                break;
//            }
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

- (void)deleteText:(NSRange)range {
    NSString *text = self.originMessageText;
    if (range.location + range.length <= [text length]
        && range.location != NSNotFound && range.length != 0)
    {
        NSString *newText = [text stringByReplacingCharactersInRange:range withString:@""];
        NSRange newSelectRange = NSMakeRange(range.location, 0);
        [self.inputTextView setText:newText];
        self.inputTextView.selectedRange = newSelectRange;
    }
}

- (void)updateHeightWithTextView:(UITextView *)textView
{
    // compute new height assuming width is unchanged
    CGSize currentSize = textView.frame.size;
    
    CGFloat fixedWidth = currentSize.width;
    CGSize contentSize = [textView sizeThatFits:CGSizeMake(fixedWidth, CGFLOAT_MAX)];
    
    // `textView.contentSize` isn't accurate when restoring a multiline draft, so we compute it here.
    textView.contentSize = contentSize;
    
    CGFloat newHeight = CGFloatClamp(contentSize.height,
                                     kMinTextViewHeight,
                                     UIDevice.currentDevice.isIPad ? kMaxIPadTextViewHeight : kMaxTextViewHeight);
    
    if (newHeight != self.textViewHeight) {
        self.textViewHeight = newHeight;
        OWSAssertDebug(self.textViewHeightConstraint);
        self.textViewHeightConstraint.constant = newHeight;
        self.inputTextContentHeightConstraint.constant = newHeight;
        [self invalidateIntrinsicContentSize];
    }
}

- (void)textViewDidBecomeFirstResponder:(UITextView *)textView
{
    self.desiredKeyboardType = KeyboardType_System;
}

#pragma mark QuotedReplyPreviewViewDelegate

- (void)inputReplyPreviewDidPressCancel:(DTInputReplyPreview *)preview {
        if (self.replyModel.viewMode == ConversationViewMode_Thread) {
                [self clearReplyMessagePreview];
            if([self.replyModel isKindOfClass: [DTTopicReplyModel class]]){
                UIButton *btnReplyToUser = nil;
                for (UIButton *button in self.btnFunctions) {
                    if (button.tag == DTInputToobarItemTag_Reply) {
                        btnReplyToUser = button;
                        break;
                    }
                }
                
                if(btnReplyToUser){
                    [self btnFunctionAction:btnReplyToUser];
                }
            }
           
        } else {
            self.replyModel = nil;
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
//MARK: anyUpdateWithTransaction不需要
                [self.thread anyUpdateWithTransaction:transaction block:^(TSThread * _Nonnull thread) {
                    [thread clearDraftWithTransaction:transaction];
                }];
            });
           
        }
}

// MARK: - +展开功能view

- (void)startGroupAt {
    
    NSString *inputText = self.inputTextView.text;
    if (!DTParamsUtils.validateString(inputText)) {
        self.inputTextView.text = @"@";
        [self.inputToolbarDelegate atIsActiveLocation:1];
    } else {
        if ([self.inputTextView isFirstResponder]) {
            NSMutableString *tmpInpuText = [NSMutableString stringWithString:inputText];
            NSUInteger location = self.inputTextView.selectedRange.location;
            [tmpInpuText insertString:@"@" atIndex:location];
            self.inputTextView.text = [tmpInpuText copy];
            self.inputTextView.selectedRange = NSMakeRange(location + 1, 0);
            [self.inputToolbarDelegate atIsActiveLocation:location + 1];
        } else {
            self.inputTextView.text = [inputText stringByAppendingString:@"@"];
            [self.inputToolbarDelegate atIsActiveLocation:self.inputTextView.text.length];
        }
    }

    [self ensureShouldShowSendButton];
}

- (NSRange)selectRange {
    
    return self.inputTextView.selectedRange;
}

- (void)setTranslateOpen:(BOOL)isOpen {
    UIImage *btnImage = nil;
    if (isOpen) {
        btnImage = [[UIImage imageNamed:@"input_attachment_confide_select"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        btnImage = [[UIImage imageNamed:@"input_attachment_confide"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    UIButton *btnTranslate = nil;
    for (UIButton *button in self.btnFunctions) {
        if (button.tag == DTInputToobarItemTag_Translate) {
            btnTranslate = button;
            break;
        }
    }
    if (!btnTranslate) return;
    OWSAssertDebug(btnTranslate);
    [btnTranslate setImage:btnImage forState:UIControlStateNormal];
    [btnTranslate setImage:btnImage forState:UIControlStateHighlighted];
}

- (void)setReplyToUserState:(BOOL)replyToUser {
    _replyToUser = replyToUser;
    UIButton *btnReplyToUser = nil;
    for (UIButton *button in self.btnFunctions) {
        if (button.tag == DTInputToobarItemTag_Reply) {
            btnReplyToUser = button;
            break;
        }
    }
    if (!btnReplyToUser) {return;}
    UIImage *btnImage = nil;
    if (replyToUser) {
        btnImage = [[UIImage imageNamed:@"ic_inputbar_reply_to_user_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        btnImage = [[UIImage imageNamed:@"ic_inputbar_reply_to_user_normal"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    OWSAssertDebug(btnReplyToUser);
    [btnReplyToUser setImage:btnImage forState:UIControlStateNormal];
    [btnReplyToUser setImage:btnImage forState:UIControlStateHighlighted];
}

- (void)setTextInputOnly:(BOOL)textInputOnly {
    _textInputOnly = textInputOnly;
    self.functionRow.hidden = textInputOnly;
}

- (void)switchFunctionViewState:(DTInputToobarState)state animated:(BOOL)animted {
    
    _state = state;
    switch (state) {
        case DTInputToobarStateNone:
            [self.inputTextView resignFirstResponder];
            self.functionSeparator.hidden = YES;
//            self.functionView.hidden = YES;
            break;
        case DTInputToobarStateKeyboard:
//            self.functionView.hidden = YES;
            break;
        case DTInputToobarStateMoreView: {
            [UIView performWithoutAnimation:^{
                [self.inputTextView resignFirstResponder];
            }];
        }
//            self.functionView.hidden = NO;
            break;
        default:
            break;
    }
    
    if (animted) {
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:1.0 initialSpringVelocity:15.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            switch (state) {
                case DTInputToobarStateNone:
                    self.functionView.hidden = YES;
                    break;
                case DTInputToobarStateKeyboard:
                    self.functionView.hidden = YES;
                    break;
                case DTInputToobarStateMoreView:
                    self.functionView.hidden = NO;
                    self.functionSeparator.hidden = NO;
                    break;
                default:
                    break;
            }
            [self layoutIfNeeded];
        } completion:^(BOOL finished) {
          
        }];
    } else {
        switch (state) {
            case DTInputToobarStateNone:
                self.functionView.hidden = YES;
                break;
            case DTInputToobarStateKeyboard:
                self.functionView.hidden = YES;
                break;
            case DTInputToobarStateMoreView:
                self.functionView.hidden = NO;
                self.functionSeparator.hidden = NO;
                break;
            default:
                break;
        }
        [self layoutIfNeeded];
    }
}

- (BOOL)isFunctionViewDisplay {
    
    return self.state == DTInputToobarStateMoreView;
}

- (UICollectionView *)functionView {
    
    if (!_functionView) {
        DTInputToolbarFlowLayout *layout = [DTInputToolbarFlowLayout new];
        CGFloat itemWidth = (kScreenWidth - 20.f) / 4;
        CGFloat itemHeight = 90.f;
        layout.itemSize = CGSizeMake(itemWidth, itemHeight);
        layout.sectionInset = UIEdgeInsetsMake(20, 10, 10, 10);
//        layout.minimumInteritemSpacing = 10;
        _functionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, itemHeight * 2 + 50.f) collectionViewLayout:layout];
        _functionView.tag = 1;
        _functionView.dataSource = self;
        _functionView.delegate = self;
        _functionView.hidden = YES;
        _functionView.pagingEnabled = YES;
        _functionView.showsHorizontalScrollIndicator = NO;
        _functionView.showsVerticalScrollIndicator = NO;
        _functionView.backgroundColor = [UIColor clearColor];
        
        [_functionView autoSetDimensionsToSize:CGSizeMake(kScreenWidth, itemHeight * 2 + 50.f)];
        
        [_functionView registerNib:[UINib nibWithNibName:NSStringFromClass(DTInputBarMoreCell.class) bundle:nil] forCellWithReuseIdentifier:DTInputBarMoreCellID];
        
        UIView *topSeparator = [UIView new];
        _functionSeparator = topSeparator;
        topSeparator.backgroundColor = Theme.outlineColor;
        [_functionView addSubview:topSeparator];
        [topSeparator autoPinEdgeToSuperviewEdge:ALEdgeTop];
        [topSeparator autoPinEdgeToSuperviewEdge:ALEdgeLeading];
        [topSeparator autoSetDimensionsToSize:CGSizeMake(kScreenWidth, 1 / [UIScreen mainScreen].scale)];
    }
    
    return _functionView;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return (NSInteger)[self.moreItems count];
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    DTInputBarMoreCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:DTInputBarMoreCellID forIndexPath:indexPath];
    if ((NSUInteger)indexPath.item < self.moreItems.count) {
        cell.item = self.moreItems[(NSUInteger)indexPath.item];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    [self switchFunctionViewState:DTInputToobarStateNone animated:YES];
    
    DTInputToolBarMoreItem *moreItem = self.moreItems[(NSUInteger)indexPath.item];
  
    if (moreItem.action) moreItem.action();
}

@end

@implementation DTInputToolBarMoreItem

- (instancetype)initWithTitle:(NSString *)title imageName:(NSString *)imageName action:(DTInputBarMoreItemAction)action {
    
    if (self = [super init]) {
        _title = title;
        _imageName = imageName;
        _action = action;
    }
    
    return self;
}

@end

NS_ASSUME_NONNULL_END
