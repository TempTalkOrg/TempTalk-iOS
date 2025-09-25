//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSQuotedReplyModel.h"
#import "ConversationViewItem.h"
#import <TTMessaging/TTMessaging-Swift.h>

#import <TTServiceKit/TSOutgoingMessage.h>
#import <TTServiceKit/TSQuotedMessage.h>
#import <TTServiceKit/TSThread.h>

// View Model which has already fetched any thumbnail attachment.
@implementation OWSQuotedReplyModel

- (TSQuotedMessage *)buildMessage {
    NSArray *attachments = self.attachmentStream ? @[ self.attachmentStream ] : @[];
    NSString *bodyString = self.body;
    // 如果 quote 的是卡片消息，发送前需要将 body 移除 markdown
    if (DTParamsUtils.validateString(self.replyItem.card.content)) {
        bodyString = [bodyString removeMarkdownStyle];
    }
    return [[TSQuotedMessage alloc] initWithTimestamp:self.timestamp
                                             authorId:self.authorId
                                                 body:bodyString
                          quotedAttachmentsForSending:attachments];
}

+ (nullable instancetype)replyModelForConversationViewItem:(id<ConversationViewItem>)conversationItem
                                                transaction:(SDSAnyReadTransaction *)transaction {
    OWSAssertDebug(conversationItem);
    OWSAssertDebug(transaction);

    TSMessage *message = (TSMessage *)conversationItem.interaction;
    if (![message isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"%@ unexpected reply message: %@", self.logTag, message);
        return nil;
    }

    TSThread *thread = [message threadWithTransaction:transaction];
    OWSAssertDebug(thread);

    uint64_t timestamp = message.timestamp;

    NSString *_Nullable authorId = ^{
        if ([message isKindOfClass:[TSOutgoingMessage class]]) {
            return [[TSAccountManager shared] localNumberWithTransaction:transaction];
        } else if ([message isKindOfClass:[TSIncomingMessage class]]) {
            return [(TSIncomingMessage *)message authorId];
        } else {
            OWSFailDebug(@"%@ Unexpected message type: %@", self.logTag, message.class);
            return (NSString * _Nullable) nil;
        }
    }();
    OWSAssertDebug(authorId.length > 0);
    
    if (conversationItem.contactShare) {
//        ContactShareViewModel *contactShare = conversationItem.contactShare;
        // TODO We deliberately always pass `nil` for `thumbnailImage`, even though we might have a contactShare.avatarImage
        // because the QuotedReplyViewModel has some hardcoded assumptions that only quoted attachments have
        // thumbnails. Until we address that we want to be consistent about neither showing nor sending the
        // contactShare avatar in the quoted reply.
        return [[OWSQuotedReplyModel alloc] initWithTimestamp:timestamp
                                                     authorId:authorId
                                                         body: Localized(@"MESSAGE_PREVIEW_TYPE_CONTACT_CARD", @"")
                                               thumbnailImage:nil
                                         conversationViewItem:conversationItem];
        
    }
    
    NSString *_Nullable quotedText = nil;
    if (conversationItem.isCombindedForwardMessage && conversationItem.combinedForwardingMessage.subForwardingMessages.count > 0) {
        if (conversationItem.combinedForwardingMessage.subForwardingMessages.count == 1) {
            quotedText = conversationItem.combinedForwardingMessage.subForwardingMessages.firstObject.body;
        } else {
            quotedText = Localized(@"MESSAGE_PREVIEW_TYPE_HISTORY", @"");
        }
    } else {
        quotedText = message.body;
    }
    BOOL hasText = quotedText.length > 0;
    BOOL hasAttachment = NO;

    TSAttachment *_Nullable attachment = [message attachmentWithTransaction:transaction];
    TSAttachmentStream *quotedAttachment;
    if (attachment && [attachment isKindOfClass:[TSAttachmentStream class]]) {

        TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;

        // If the attachment is "oversize text", try the quote as a reply to text, not as
        // a reply to an attachment.
        if (!hasText && [OWSMimeTypeOversizeTextMessage isEqualToString:attachment.contentType]) {
            hasText = YES;
            quotedText = @"";

            NSData *_Nullable oversizeTextData = [NSData dataWithContentsOfFile:attachmentStream.filePath];
            if (oversizeTextData) {
                // We don't need to include the entire text body of the message, just
                // enough to render a snippet.  kOversizeTextMessageSizeThreshold is our
                // limit on how long text should be in protos since they'll be stored in
                // the database. We apply this constant here for the same reasons.
                NSString *_Nullable oversizeText =
                    [[NSString alloc] initWithData:oversizeTextData encoding:NSUTF8StringEncoding];
                // First, truncate to the rough max characters.
                NSString *_Nullable truncatedText =
                    [oversizeText substringToIndex:kOversizeTextMessageSizeThreshold - 1];
                // But kOversizeTextMessageSizeThreshold is in _bytes_, not characters,
                // so we need to continue to trim the string until it fits.
                while (truncatedText && truncatedText.length > 0 &&
                    [truncatedText dataUsingEncoding:NSUTF8StringEncoding].length
                        >= kOversizeTextMessageSizeThreshold) {
                    // A very coarse binary search by halving is acceptable, since
                    // kOversizeTextMessageSizeThreshold is much longer than our target
                    // length of "three short lines of text on any device we might
                    // display this on.
                    //
                    // The search will always converge since in the worst case (namely
                    // a single character which in utf-8 is >= 1024 bytes) the loop will
                    // exit when the string is empty.
                    truncatedText = [truncatedText substringToIndex:truncatedText.length / 2];
                }
                if ([truncatedText dataUsingEncoding:NSUTF8StringEncoding].length < kOversizeTextMessageSizeThreshold) {
                    quotedText = truncatedText;
                } else {
                    OWSFailDebug(@"%@ Missing valid text snippet.", self.logTag);
                }
            }
        } else {
            quotedAttachment = attachmentStream;
            hasAttachment = YES;
        }
    }

    if (!hasText && !hasAttachment) {
//        OWSFailDebug(@"%@ quoted message has neither text nor attachment", self.logTag);
        quotedText = @"";
        hasText = YES;
    }

    return [[OWSQuotedReplyModel alloc] initWithTimestamp:timestamp
                                                 authorId:authorId
                                                     body:quotedText
                                         attachmentStream:quotedAttachment
                                     conversationViewItem:conversationItem];
}

- (TSInteraction *)replyItemInteraction {
    return self.replyItem.interaction;
}
@end
