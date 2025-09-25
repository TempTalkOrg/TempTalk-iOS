//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class OWSContact;
@class DSKProtoEnvelope;
@class DSKProtoAttachmentPointer;
@class DSKProtoDataMessage;
@class DSKProtoSyncMessageSent;
@class TSQuotedMessage;
@class DTCombinedForwardingMessage;
@class DTRecallMessage;
@class TSThread;
@class SDSAnyWriteTransaction;
@class DTMention;
@class DSKProtoRapidFile;

/**
 * Represents notification of a message sent on our behalf from another device.
 * E.g. When we send a message from Signal-Desktop we want to see it in our conversation on iPhone.
 */
@interface OWSIncomingSentMessageTranscript : NSObject

- (instancetype)initWithProto:(DSKProtoSyncMessageSent *)sentProto
                       source:(NSString *)source
               sourceDeviceId:(UInt32)sourceDeviceId
                        relay:(nullable NSString *)relay
              serverTimestamp:(uint64_t)serverTimestamp
                  transaction:(SDSAnyWriteTransaction *)transaction;

/// hot data, 有一部分 sync message 以 dataMessage 的形式拉下来
- (instancetype)initWithProto:(DSKProtoEnvelope *)envelop
                  dataMessage:(DSKProtoDataMessage *)dataMessage
           hotDataDestination:(NSString *_Nullable)hotDataDestination
                  transaction:(SDSAnyWriteTransaction *)transaction;

@property (nonatomic, readonly, nullable) NSString *envelopSource;
@property (nonatomic, readonly) NSString *relay;
@property (nonatomic, readonly) DSKProtoDataMessage *dataMessage;
@property (nonatomic, readonly) NSArray<DSKProtoRapidFile *> *rapidFiles;
@property (nonatomic, readonly) NSString *recipientId;
@property (nonatomic, readonly) uint64_t timestamp;
@property (nonatomic, readonly) uint64_t serverTimestamp;
@property (nonatomic, readonly) uint64_t sequenceId;
@property (nonatomic, readonly) uint64_t notifySequenceId;
@property (nonatomic, readonly) uint64_t expirationStartedAt;
@property (nonatomic, readonly) uint32_t expirationDuration;
@property (nonatomic, readonly) BOOL isGroupUpdate;
@property (nonatomic, readonly) BOOL isExpirationTimerUpdate;
@property (nonatomic, readonly) BOOL isEndSessionMessage;
@property (nonatomic, readonly, nullable) NSData *groupId;
@property (nonatomic, readonly) NSString *body;
@property (nonatomic, readonly) NSString *atPersons;
@property (nonatomic, readonly) NSArray <DTMention *> *mentions;
@property (nonatomic, readonly) NSArray<DSKProtoAttachmentPointer *> *attachmentPointerProtos;
@property (nonatomic, readonly) TSThread *thread;
@property (nonatomic, readonly, nullable) TSQuotedMessage *quotedMessage;
@property (nonatomic, readonly, nullable) DTCombinedForwardingMessage *forwardingMessage;
@property (nonatomic, readonly, nullable) OWSContact *contact;

@property (nonatomic, strong) DTRecallMessage *recall;

@property (nonatomic, readonly) UInt32 sourceDeviceId;

@end

NS_ASSUME_NONNULL_END
