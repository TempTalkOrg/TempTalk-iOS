//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DTInputMessagePreView.h"

NS_ASSUME_NONNULL_BEGIN

@class DisplayableText;
@class OWSBubbleShapeView;
@class OWSQuotedReplyModel;
@class TSAttachmentPointer;
@class TSQuotedMessage;

@protocol OWSQuotedMessageViewDelegate <NSObject>

- (void)didTapQuotedReply:(OWSQuotedReplyModel *)quotedReply
    failedThumbnailDownloadAttachmentPointer:(TSAttachmentPointer *)attachmentPointer;

@end


///TODO: 这个类需要整理 需要将，目前先写了一个基类 带时间充足时调整 2022-0830
@interface OWSQuotedMessageView : DTInputMessagePreView

@property (nonatomic, nullable, weak) id<OWSQuotedMessageViewDelegate> delegate;
- (instancetype)init NS_UNAVAILABLE;

// Factory method for "message bubble" views.
+ (OWSQuotedMessageView *)quotedMessageViewForConversation:(OWSQuotedReplyModel *)quotedMessage
                                     displayableQuotedText:(nullable DisplayableText *)displayableQuotedText
                                         conversationStyle:(ConversationStyle *)conversationStyle
                                                isOutgoing:(BOOL)isOutgoing
                                              sharpCorners:(OWSDirectionalRectCorner)sharpCorners;



//目前在Thread中使用
//- (nullable NSString *)configureReplyAuthorLabelWithAuthorId:(NSString *) authorId;
@end

NS_ASSUME_NONNULL_END
