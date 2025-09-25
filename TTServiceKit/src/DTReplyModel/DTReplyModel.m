//
//  DTReplyModel.m
//  TTMessaging
//
//  Created by hornet on 2022/8/23.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTReplyModel.h"
#import "MIMETypeUtil.h"
#import "OWSMessageSender.h"
#import "TSAccountManager.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSIncomingMessage.h"
#import "TSMessage.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import "TSThread.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTReplyModel

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         authorId:(NSString *)authorId
                             body:(NSString *_Nullable)body
                 attachmentStream:(nullable TSAttachmentStream *)attachmentStream
             conversationViewItem:(id<ConversationViewItem>)conversationItem{
    return [self initWithTimestamp:timestamp
                          authorId:authorId
                              body:body
                    thumbnailImage:attachmentStream.thumbnailImage
                       contentType:attachmentStream.contentType
                    sourceFilename:attachmentStream.sourceFilename
                  attachmentStream:attachmentStream
        thumbnailAttachmentPointer:nil
           thumbnailDownloadFailed:NO
              conversationViewItem:conversationItem];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         authorId:(NSString *)authorId
                             body:(NSString *_Nullable)body
                   thumbnailImage:(nullable UIImage *)thumbnailImage
             conversationViewItem:(nullable id<ConversationViewItem>)conversationItem {
    return [self initWithTimestamp:timestamp
                          authorId:authorId
                              body:body
                    thumbnailImage:thumbnailImage
                       contentType:nil
                    sourceFilename:nil
                  attachmentStream:nil
        thumbnailAttachmentPointer:nil
           thumbnailDownloadFailed:NO
              conversationViewItem:conversationItem];
}

- (instancetype)initWithQuotedMessage:(TSQuotedMessage *)quotedMessage
                          transaction:(SDSAnyReadTransaction *)transaction {
    OWSAssertDebug(quotedMessage.quotedAttachments.count <= 1);
    OWSAttachmentInfo *attachmentInfo = quotedMessage.quotedAttachments.firstObject;

    BOOL thumbnailDownloadFailed = NO;
    UIImage *_Nullable thumbnailImage;
    TSAttachmentPointer *attachmentPointer;
    if (attachmentInfo.thumbnailAttachmentStreamId) {
        TSAttachment *attachment =
            [TSAttachment anyFetchWithUniqueId:attachmentInfo.thumbnailAttachmentStreamId transaction:transaction];

        TSAttachmentStream *attachmentStream;
        if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
            attachmentStream = (TSAttachmentStream *)attachment;
            thumbnailImage = attachmentStream.image;
        }
    } else if (attachmentInfo.thumbnailAttachmentPointerId) {
        // download failed, or hasn't completed yet.
        TSAttachment *attachment =
            [TSAttachment anyFetchWithUniqueId:attachmentInfo.thumbnailAttachmentPointerId transaction:transaction];

        if ([attachment isKindOfClass:[TSAttachmentPointer class]]) {
            attachmentPointer = (TSAttachmentPointer *)attachment;
            if (attachmentPointer.state == TSAttachmentPointerStateFailed) {
                thumbnailDownloadFailed = YES;
            }
        }
    }
    TSAttachment *attachment = [TSAttachmentStream anyFetchWithUniqueId:attachmentInfo.attachmentId transaction:transaction];
    TSAttachmentStream *attachmentStream = nil;
    if (attachment && [attachment isKindOfClass:[TSAttachmentStream class]]) {
        attachmentStream = (TSAttachmentStream *)attachment;
    }

    return [self initWithTimestamp:quotedMessage.timestamp
                          authorId:quotedMessage.authorId
                              body:quotedMessage.body
                    thumbnailImage:thumbnailImage
                       contentType:attachmentInfo.contentType
                    sourceFilename:attachmentInfo.sourceFilename
                  attachmentStream:attachmentStream
        thumbnailAttachmentPointer:attachmentPointer
           thumbnailDownloadFailed:thumbnailDownloadFailed
              conversationViewItem:nil];
}

//需要子类自己实现
+ (nullable instancetype)replyModelForConversationViewItem:(id<ConversationViewItem>)conversationItem
                                               transaction:(SDSAnyReadTransaction *)transaction {
    return nil;
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         authorId:(NSString *)authorId
                             body:(nullable NSString *)body
                   thumbnailImage:(nullable UIImage *)thumbnailImage
                      contentType:(nullable NSString *)contentType
                   sourceFilename:(nullable NSString *)sourceFilename
                 attachmentStream:(nullable TSAttachmentStream *)attachmentStream
       thumbnailAttachmentPointer:(nullable TSAttachmentPointer *)thumbnailAttachmentPointer
          thumbnailDownloadFailed:(BOOL)thumbnailDownloadFailed
             conversationViewItem:(nullable id<ConversationViewItem>)conversationItem {
    self = [super init];
    if (!self) {
        return self;
    }

    _timestamp = timestamp;
    _authorId = authorId;
    _body = body;
    _thumbnailImage = thumbnailImage;
    _contentType = contentType;
    _sourceFilename = sourceFilename;
    _attachmentStream = attachmentStream;
    _thumbnailAttachmentPointer = thumbnailAttachmentPointer;
    _thumbnailDownloadFailed = thumbnailDownloadFailed;
    _replyItem = conversationItem;
    
    return self;
}

- (void)resetBodyContentWithBody:(nullable NSString *)body {
    _body = body;
}

- (NSObject *)buildMessage {
    return nil;
}
@end
