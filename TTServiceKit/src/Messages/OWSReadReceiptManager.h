//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "BaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@class DSKProtoSyncMessageRead;
@class TSIncomingMessage;
@class TSOutgoingMessage;
@class TSThread;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class DTReadPositionEntity;
@class TSMessageReadPosition;

extern NSString *const kIncomingMessageMarkedAsReadNotification;

@interface TSRecipientReadReceipt : BaseModel

@property (nonatomic, readonly) uint64_t sentTimestamp;
// Map of "recipient id"-to-"read timestamp".
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *recipientMap;

@end

// There are four kinds of read receipts:
//
// * Read receipts that this client sends to linked
//   devices to inform them that a message has been read.
// * Read receipts that this client receives from linked
//   devices that inform this client that a message has been read.
//    * These read receipts are saved so that they can be applied
//      if they arrive before the corresponding message.
// * Read receipts that this client sends to other users
//   to inform them that a message has been read.
// * Read receipts that this client receives from other users
//   that inform this client that a message has been read.
//    * These read receipts are saved so that they can be applied
//      if they arrive before the corresponding message.
//
// This manager is responsible for handling and emitting all four kinds.
@interface OWSReadReceiptManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)sharedManager;

#pragma mark - Sender/Recipient Read Receipts

// This method should be called when we receive a read receipt
// from a user to whom we have sent a message.
//
// This method can be called from any thread.
- (void)processReadReceiptsFromRecipientId:(NSString *)recipientId
                            sentTimestamps:(NSArray<NSNumber *> *)sentTimestamps
                             readTimestamp:(uint64_t)readTimestamp;

- (void)applyEarlyReadReceiptsForOutgoingMessageFromLinkedDevice:(TSOutgoingMessage *)message
                                                     transaction:(SDSAnyWriteTransaction *)transaction;

#pragma mark - Linked Device Read Receipts

- (void)processReadReceiptsFromLinkedDevice:(NSArray<DSKProtoSyncMessageRead *> *)readReceiptProtos
                              readTimestamp:(uint64_t)readTimestamp
                                transaction:(SDSAnyWriteTransaction *)transaction;

- (void)applyEarlyReadReceiptsForIncomingMessage:(TSIncomingMessage *)message
                                     transaction:(SDSAnyWriteTransaction *)transaction;

#pragma mark - Locally Read

// This method cues this manager:
//
// * ...to inform the sender that this message was read (if read receipts
//      are enabled).
// * ...to inform the local user's other devices that this message was read.
//
// Both types of messages are deduplicated.
//
// This method can be called from any thread.
- (void)messageWasReadLocally:(TSIncomingMessage *)message shouldSendReadReceipt:(BOOL)shouldSendReadReceipt;

- (void)confidentialMessageWasReadLocally:(TSIncomingMessage *)message;

- (void)markAsReadLocallyBeforePosition:(DTReadPositionEntity *)readPosition oldReadPosition:(DTReadPositionEntity *)oldReadPosition thread:(TSThread *)thread completion:(void (^)(uint64_t latestTimestamp))completion;

#pragma mark - Settings

- (void)prepareCachedValues;

- (BOOL)areReadReceiptsEnabled;
- (BOOL)areReadReceiptsEnabledWithTransaction:(SDSAnyReadTransaction *)transaction;
- (void)setAreReadReceiptsEnabled:(BOOL)value;

#pragma mark - Self
- (void)updateSelfReadPositionEntity:(DTReadPositionEntity *)readPosition
                              thread:(TSThread *)thread
                         transaction:(SDSAnyWriteTransaction *)transaction;

#pragma mark - Others
- (void)sendReadRecipetWithReadPosition:(DTReadPositionEntity *)readPosition
                               thread:(TSThread *)thread
                             wasLocal:(BOOL)wasLocal
                           completion:(nullable dispatch_block_t)completion;


- (void)temporarySaveNeedToUpdateReadPositionMessage:(TSMessageReadPosition *)messageReadPosition message:(TSOutgoingMessage *)message;
- (void)handleNeedToUpdateReadPositionMessage:(TSOutgoingMessage *)message thread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
