//
//  DTCombinedForwardingMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/23.
//

#import <Mantle/Mantle.h>
#import "DTRapidFile.h"
#import "DTCardMessageEntity.h"

NS_ASSUME_NONNULL_BEGIN

@class DSKProtoDataMessage;
@class DSKProtoDataMessageForward;
@class DSKProtoDataMessageForwardContext;
@class TSAttachment;
@class TSAttachmentStream;
@class SDSAnyWriteTransaction;
@class SDSAnyReadTransaction;
@class TSMessage;
@class DTMention;

@interface DTCombinedForwardingMessage : MTLModel

@property (nonatomic, strong) NSArray<DTCombinedForwardingMessage *> *subForwardingMessages;


@property (nonatomic, readonly) uint64_t timestamp;
@property (nonatomic, readonly) NSString *authorId;

// This property should be set IFF we are quoting a text message
// or attachment with caption.
@property (nullable, nonatomic) NSString *body;

@property (atomic) NSArray<NSString *> *forwardingAttachmentIds;
@property (atomic, nullable) NSArray<DTMention *> *forwardingMentions;

@property (nullable, nonatomic) NSString *attachmentsDescription;
@property (nonatomic, copy) NSString *authorName;

@property (nullable, nonatomic) DTCardMessageEntity *card;

@property (nonatomic, assign) BOOL isFromGroup;
@property (nonatomic, assign) int32_t messageType;

@property (nonatomic, strong) NSArray<DTRapidFile *> *rapidFiles;

@property (nonatomic, readonly) uint64_t serverTimestamp; // 3.1.4 新增

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                  serverTimestamp:(uint64_t)serverTimestamp
                         authorId:(NSString *)authorId
                      isFromGroup:(BOOL)isFromGroup
                      messageType:(int32_t)messageType
                             body:(NSString *_Nullable)body
          forwardingAttachmentIds:(NSArray<NSString *> * _Nullable)attachmentIds;

+ (DTCombinedForwardingMessage *_Nullable)buildSingleForwardingMessageWithMessage:(DTCombinedForwardingMessage *)message
                                                                      transaction:(nonnull SDSAnyWriteTransaction *)transaction;

+ (DTCombinedForwardingMessage *_Nullable)buildCombinedForwardingMessageForSendingWithMessages:(NSArray<TSMessage *> *)messages
                                                                                   isFromGroup:(BOOL)isFromGroup
                                                                                   transaction:(SDSAnyWriteTransaction *)transaction;

//used to adapt data processing logic
+ (DSKProtoDataMessageForward *)buildRootForwardProtoWithForwardContextProto:(DSKProtoDataMessageForwardContext *)forwardContextProto
                                                                   timestamp:(uint64_t)timestamp
                                                             serverTimestamp:(uint64_t)serverTimestamp
                                                                      author:(NSString *)author
                                                                        body:(NSString *)body;

+ (DTCombinedForwardingMessage *_Nullable)forwardingMessageForDataMessage:(DSKProtoDataMessageForward *)forwardProto
                                                                 threadId:(NSString *)threadId
                                                                messageId:(NSString *)messageId
                                                                    relay:(nullable NSString *)relay
                                                              transaction:(SDSAnyWriteTransaction *)transaction;

- (void)handleForwardingAttachmentsWithOrigionMessage:(nullable TSMessage *)origionMessage transaction:(nonnull SDSAnyWriteTransaction *)transaction completion:(nullable void(^)(TSAttachmentStream * attachmentStream))completion;
- (void)handleAllForwardingAttachmentsWithTransaction:(nonnull SDSAnyWriteTransaction *)transaction
                                           completion:(void(^)(NSError *error))completion;

- (NSArray<TSAttachmentStream *> *)forwardingAttachmentStreamsWithTransaction:(SDSAnyReadTransaction *)transaction;

- (NSArray<TSAttachment *> *)forwardingAttachmentsWithTransaction:(SDSAnyReadTransaction *)transaction;

- (NSArray<NSString *> *)allForwardingAttachmentIds;

@end

NS_ASSUME_NONNULL_END
