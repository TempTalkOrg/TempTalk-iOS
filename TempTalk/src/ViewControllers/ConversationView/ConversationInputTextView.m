//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationInputTextView.h"
#import "TempTalk-Swift.h"
#import <SignalCoreKit/NSString+OWS.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConversationInputTextView () <UITextViewDelegate>

@property (nonatomic) UILabel *placeholderView;
@property (nonatomic) NSArray<NSLayoutConstraint *> *placeholderConstraints;

@end

#pragma mark -

@implementation ConversationInputTextView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setTranslatesAutoresizingMaskIntoConstraints:NO];
        self.delegate = self;

        self.backgroundColor = [UIColor clearColor];
        self.scrollIndicatorInsets = UIEdgeInsetsMake(4, 4, 4, 2);

        self.scrollsToTop = NO;

        self.font = [UIFont ows_dynamicTypeBodyFont];
//        self.textColor = Theme.primaryTextColor;
        self.textAlignment = NSTextAlignmentNatural;

        self.contentMode = UIViewContentModeRedraw;
        self.dataDetectorTypes = UIDataDetectorTypeNone;
//        self.keyboardAppearance = Theme.keyboardAppearance;

        self.text = nil;

        self.placeholderView = [UILabel new];
        self.placeholderView.text = Localized(@"new_message", @"");
//        self.placeholderView.textColor = Theme.placeholderColor;
        self.placeholderView.userInteractionEnabled = NO;
        [self addSubview:self.placeholderView];

        // We need to do these steps _after_ placeholderView is configured.
        self.font = [UIFont ows_dynamicTypeBodyFont];
        self.textContainerInset = UIEdgeInsetsMake(7.0f, 10.0f, 7.0f, 0.0f);

        [self ensurePlaceholderConstraints];
        [self updatePlaceholderVisibility];
        
        [self applyTheme];
        [self addMenuItem];
    }

    return self;
}

- (void)addMenuItem {
    UIMenuItem *menuItem = [[UIMenuItem alloc]initWithTitle:Localized(@"Line_NewLine", @"") action:@selector(lineFeedSelector:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:[NSArray arrayWithObject:menuItem]];
    [menuController setMenuVisible:NO];
}

- (void)lineFeedSelector:(UIButton *)sender {
    UITextPosition *selectionStart = self.selectedTextRange.start;
    NSUInteger location = self.selectedRange.location;
    NSString *content = self.text;
    NSString *appendString = [NSString stringWithFormat:@"%@\n",[content substringToIndex:location]];
    NSString *result = [NSString stringWithFormat:@"%@%@",appendString,[content substringFromIndex:location]];
    self.text = result;
    UITextPosition *start = [self positionFromPosition:selectionStart offset:1];
    UITextPosition *end = [self positionFromPosition:selectionStart offset:1];
    [self setSelectedTextRange:[self textRangeFromPosition:start toPosition:end]];
    
}

- (void)applyTheme {
    
    self.backgroundColor = Theme.isDarkThemeEnabled?[UIColor colorWithRgbHex:0x1E2329]:[UIColor colorWithRgbHex:0xFAFAFA];
    self.textColor = Theme.primaryTextColor;
    self.keyboardAppearance = Theme.keyboardAppearance;
    self.placeholderView.textColor = Theme.placeholderColor;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    self.placeholderView.text = placeholder;
}

- (void)setFont:(UIFont *_Nullable)font
{
    [super setFont:font];

    self.placeholderView.font = font;
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)isAnimated
{
    // When creating new lines, contentOffset is animated, but because because
    // we are simultaneously resizing the text view, this can cause the
    // text in the textview to be "too high" in the text view.
    // Solution is to disable animation for setting content offset.
    [super setContentOffset:contentOffset animated:NO];
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    [super setContentInset:contentInset];

    [self ensurePlaceholderConstraints];
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
    [super setTextContainerInset:textContainerInset];

    [self ensurePlaceholderConstraints];
}

- (void)ensurePlaceholderConstraints
{
    OWSAssertDebug(self.placeholderView);

    if (self.placeholderConstraints) {
        [NSLayoutConstraint deactivateConstraints:self.placeholderConstraints];
    }

    // We align the location of our placeholder with the text content of
    // this view.  The only safe way to do that is by measuring the
    // beginning position.
    UIEdgeInsets textContainerInset = self.textContainerInset;
    CGFloat lineFragmentPadding = self.textContainer.lineFragmentPadding;

    CGFloat leftInset = textContainerInset.left + lineFragmentPadding;
    CGFloat topInset = textContainerInset.top;

    // we use Left instead of Leading, since it's based on the prior CGRect offset
    self.placeholderConstraints = @[
        [self.placeholderView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:topInset],
        [self.placeholderView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:leftInset],
        [self.placeholderView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:textContainerInset.right]
    ];
}

- (void)updatePlaceholderVisibility
{
    self.placeholderView.hidden = self.text.length > 0;
}

- (void)setText:(NSString *_Nullable)text
{
    [super setText:text];

    OWSLogDebug(@"------ %@", text);
    
    [self updatePlaceholderVisibility];
}

- (BOOL)becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];
    
    if (result) {
        [self.textViewToolbarDelegate textViewDidBecomeFirstResponder:self];
    }
    
    return result;
}

- (BOOL)pasteboardHasPossibleAttachment
{
    // We don't want to load/convert images more than once so we
    // only do a cursory validation pass at this time.
    return ([SignalAttachment pasteboardHasPossibleAttachment] && ![SignalAttachment pasteboardHasText]);
}

- (BOOL)canPerformAction:(SEL)action withSender:(nullable id)sender
{
    if (action == @selector(paste:)) {
        if ([self pasteboardHasPossibleAttachment]) {
            return YES;
        }
    }
    if (action == @selector(lineFeedSelector:)) {
       return YES;
    }
    return [super canPerformAction:action withSender:sender];
}

- (void)paste:(nullable id)sender
{
    if ([self pasteboardHasPossibleAttachment]) {
        SignalAttachment *attachment = [SignalAttachment attachmentFromPasteboard];
        // Note: attachment might be nil or have an error at this point; that's fine.
        [self.inputTextViewDelegate didPasteAttachment:attachment];
        return;
    }

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (pasteboard.strings.count != 2) {
        [super paste:sender];
        return;
    }
    
    NSString *mentionText = pasteboard.strings[1];
    if (![mentionText containsString:@"uid"] || ![mentionText containsString:@"start"] || ![mentionText containsString:@"length"]) {
        //MARK: 不是wea/cc带@的内容copy
        [super paste:sender];
        return;
    }
    
    NSString *messageText = pasteboard.strings[0];
    NSRange selectedRange = self.selectedRange;
    OWSLogDebug(@"%@--%lu",self.logTag, selectedRange.location);
    if (DTParamsUtils.validateString(self.text)) {
        NSMutableString *text = self.text.mutableCopy;
        if (selectedRange.length == 0) {
            [text insertString:messageText
                       atIndex:selectedRange.location];
        } else {
            NSString *selectedText = [text substringWithRange:selectedRange];
            [text replaceOccurrencesOfString:selectedText
                                  withString:messageText
                                     options:NSCaseInsensitiveSearch
                                       range:selectedRange];
        }
        self.text = text;
        self.selectedRange = NSMakeRange(selectedRange.location + messageText.length, 0);
    } else {
        self.text = pasteboard.strings[0];
    }
    if (self.inputTextViewDelegate && [self.inputTextViewDelegate respondsToSelector:@selector(pasteMentionWithJson:range:)]) {
        [self.inputTextViewDelegate pasteMentionWithJson:pasteboard.strings[1] range:selectedRange];
    }
    pasteboard.strings = nil;
    [self textViewDidChange:self];
}

- (NSString *)trimmedText
{
    return [self.text ows_stripped];
}

- (nullable NSString *)untrimmedText
{
    return self.text;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
 
    if (self.textViewToolbarDelegate && [self.textViewToolbarDelegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
        [self.textViewToolbarDelegate textViewDidBeginEditing:self];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    OWSAssertDebug(self.textViewToolbarDelegate);

    [self updatePlaceholderVisibility];

    if (self.textViewToolbarDelegate && [self.textViewToolbarDelegate respondsToSelector:@selector(textViewDidChange:)]) {
        
        [self.textViewToolbarDelegate textViewDidChange:self];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    if (self.textViewToolbarDelegate && [self.textViewToolbarDelegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
        
        return [self.textViewToolbarDelegate textView:textView shouldChangeTextInRange:range replacementText:text];
    } else {
        
        return YES;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.textViewToolbarDelegate && [self.textViewToolbarDelegate respondsToSelector:@selector(textViewWillBeginDragging:)]) {
        [self.textViewToolbarDelegate textViewWillBeginDragging:scrollView];
    }
}

#pragma mark - Key Commands

- (nullable NSArray<UIKeyCommand *> *)keyCommands
{
    // We're permissive about what modifier key we accept for the "send message" hotkey.
    // We accept command-return, option-return.
    //
    // We don't support control-return because it doesn't work.
    //
    // We don't support shift-return because it is often used for "newline" in other
    // messaging apps.
    return @[
        [self keyCommandWithInput:@"\r"
                    modifierFlags:0
                           action:@selector(modifiedReturnPressed:)
             discoverabilityTitle:@"Send Message"],
        // "Alternate" is option.
        [self keyCommandWithInput:@"\r"
                    modifierFlags:UIKeyModifierAlternate
                           action:@selector(modifiedReturnPressed:)
             discoverabilityTitle:@"Send Message"],
    ];
}

- (UIKeyCommand *)keyCommandWithInput:(NSString *)input
                        modifierFlags:(UIKeyModifierFlags)modifierFlags
                               action:(SEL)action
                 discoverabilityTitle:(NSString *)discoverabilityTitle
{
    return [UIKeyCommand keyCommandWithInput:input
                               modifierFlags:modifierFlags
                                      action:action
                        discoverabilityTitle:discoverabilityTitle];
}

- (void)modifiedReturnPressed:(UIKeyCommand *)sender
{
    OWSLogInfo(@"%@ modifiedReturnPressed: %@", self.logTag, sender.input);
    [self.inputTextViewDelegate inputTextViewSendMessagePressed];
}

@end

NS_ASSUME_NONNULL_END
