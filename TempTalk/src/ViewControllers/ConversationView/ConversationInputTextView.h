//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class SignalAttachment;

@protocol ConversationInputTextViewDelegate <NSObject>

- (void)didPasteAttachment:(SignalAttachment *_Nullable)attachment;

- (void)inputTextViewSendMessagePressed;

- (void)pasteMentionWithJson:(NSString *)jsonMention range:(NSRange)range;

@end

#pragma mark -

@protocol ConversationTextViewToolbarDelegate <NSObject>

- (void)textViewDidBeginEditing:(UITextView *)textView;
- (void)textViewDidChange:(UITextView *)textView;
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)textViewDidBecomeFirstResponder:(UITextView *)textView;

/// 返回 YES 允许成为 first responder，返回 NO 阻止（用于先收起 attachment 键盘再弹出 system 键盘）
- (BOOL)textViewShouldBecomeFirstResponder:(UITextView *)textView;

@end

#pragma mark -

@interface ConversationInputTextView : UITextView

@property (weak, nonatomic) id<ConversationInputTextViewDelegate> inputTextViewDelegate;

@property (weak, nonatomic) id<ConversationTextViewToolbarDelegate> textViewToolbarDelegate;

@property (nonatomic, copy) NSString *placeholder;

- (NSString *)trimmedText;

- (nullable NSString *)untrimmedText;

- (void)applyTheme;

@end

NS_ASSUME_NONNULL_END
