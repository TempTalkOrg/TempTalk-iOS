//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSReadReceiptManager.h"
#import "AppReadiness.h"
#import "NSDate+OWS.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSLinkedDeviceReadReceipt.h"
#import "OWSMessageSender.h"
#import "OWSReadReceiptsForLinkedDevicesMessage.h"
#import "OWSReadReceiptsForSenderMessage.h"
#import "OWSSyncConfigurationMessage.h"
#import "TSAccountManager.h"
#import "TSContactThread.h"
#import "TSIncomingMessage.h"
#import "TextSecureKitEnv.h"
#import "DTReadReceiptEntity.h"
#import <TTServiceKit/TSOutgoingMessage.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSGroupThread.h"
#import "DTReadPositionEntity.h"
#import <SignalCoreKit/Threading.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kIncomingMessageMarkedAsReadNotification = @"kIncomingMessageMarkedAsReadNotification";


@implementation TSRecipientReadReceipt

+ (NSString *)collection
{
    return @"TSRecipientReadReceipt2";
}

- (instancetype)initWithSentTimestamp:(uint64_t)sentTimestamp
{
    OWSAssertDebug(sentTimestamp > 0);

    self = [super initWithUniqueId:[TSRecipientReadReceipt uniqueIdForSentTimestamp:sentTimestamp]];

    if (self) {
        _sentTimestamp = sentTimestamp;
        _recipientMap = [NSDictionary new];
    }

    return self;
}

+ (NSString *)uniqueIdForSentTimestamp:(uint64_t)timestamp
{
    return [NSString stringWithFormat:@"%llu", timestamp];
}

- (void)addRecipientId:(NSString *)recipientId timestamp:(uint64_t)timestamp
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(timestamp > 0);

    NSMutableDictionary<NSString *, NSNumber *> *recipientMapCopy = [self.recipientMap mutableCopy];
    recipientMapCopy[recipientId] = @(timestamp);
    _recipientMap = [recipientMapCopy copy];
}

+ (void)addRecipientId:(NSString *)recipientId
         sentTimestamp:(uint64_t)sentTimestamp
         readTimestamp:(uint64_t)readTimestamp
           transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    /*

    TSRecipientReadReceipt *_Nullable recipientReadReceipt =
        [transaction objectForKey:[self uniqueIdForSentTimestamp:sentTimestamp] inCollection:[self collection]];
    if (!recipientReadReceipt) {
        recipientReadReceipt = [[TSRecipientReadReceipt alloc] initWithSentTimestamp:sentTimestamp];
    }
    [recipientReadReceipt addRecipientId:recipientId timestamp:readTimestamp];
    [recipientReadReceipt saveWithTransaction:transaction];
     */
}

+ (nullable NSDictionary<NSString *, NSNumber *> *)recipientMapForSentTimestamp:(uint64_t)sentTimestamp
                                                                    transaction:
                                                                        (SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    /*

    TSRecipientReadReceipt *_Nullable recipientReadReceipt =
        [transaction objectForKey:[self uniqueIdForSentTimestamp:sentTimestamp] inCollection:[self collection]];
    return recipientReadReceipt.recipientMap;
     */
    return nil;
}

+ (void)removeRecipientIdsForTimestamp:(uint64_t)sentTimestamp
                           transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    /*
    [transaction removeObjectForKey:[self uniqueIdForSentTimestamp:sentTimestamp] inCollection:[self collection]];
     */
}

@end

#pragma mark -

NSString *const OWSReadReceiptManagerCollection = @"OWSReadReceiptManagerCollection";
NSString *const OWSReadReceiptManagerAreReadReceiptsEnabled = @"areReadReceiptsEnabled";

@interface OWSReadReceiptManager ()

// A map of "thread unique id"-to-"read receipt" for read receipts that
// we will send to our linked devices.
//
// Should only be accessed while synchronized on the OWSReadReceiptManager.
@property (nonatomic, readonly) NSMutableDictionary<NSString *, OWSLinkedDeviceReadReceipt *> *toLinkedDevicesReadReceiptMap;

// A map of "recipient id"-to-"timestamp list" for read receipts that
// we will send to senders.
//
// Should only be accessed while synchronized on the OWSReadReceiptManager.
@property (nonatomic, readonly) NSMutableDictionary<NSString *, DTReadReceiptEntity *> *toSenderReadReceiptMap;

@property (nonatomic, strong) NSMutableDictionary<NSString *, TSMessageReadPosition *> *needToUpdateReadPositionMessageMap;

// Should only be accessed while synchronized on the OWSReadReceiptManager.
@property (nonatomic) BOOL isProcessing;

@property (atomic) NSNumber *areReadReceiptsEnabledCached;

@property (nonatomic, strong) dispatch_queue_t serialQueue;

@end

#pragma mark -

@implementation OWSReadReceiptManager

+ (instancetype)sharedManager
{
    static OWSReadReceiptManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    self = [super init];
    
    if (!self) {
        return self;
    }
    
    _toLinkedDevicesReadReceiptMap = [NSMutableDictionary new];
    _toSenderReadReceiptMap = [NSMutableDictionary new];
    _serialQueue = dispatch_queue_create("org.wea.readReceipt", DISPATCH_QUEUE_SERIAL);
    
    OWSSingletonAssert();
    
    // Start processing.
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        [self scheduleProcessing];
    });
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

// Schedules a processing pass, unless one is already scheduled.
- (void)scheduleProcessing
{
    OWSAssertDebug(AppReadiness.isAppReady);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self)
        {
            if (self.isProcessing) {
                return;
            }

            self.isProcessing = YES;

            
            [self process];
        }
    });
}

- (void)process
{

    @synchronized(self)
    {
        OWSLogVerbose(@"%@ Processing read receipts.", self.logTag);

        NSArray<OWSLinkedDeviceReadReceipt *> *readReceiptsForLinkedDevices = [self.toLinkedDevicesReadReceiptMap allValues];
        [self.toLinkedDevicesReadReceiptMap removeAllObjects];
        if (readReceiptsForLinkedDevices.count > 0) {
            
            for (OWSLinkedDeviceReadReceipt *readReceiptsForLinkedDevice in readReceiptsForLinkedDevices) {
                OWSReadReceiptsForLinkedDevicesMessage *message =
                    [[OWSReadReceiptsForLinkedDevicesMessage alloc] initWithReadReceipts:@[readReceiptsForLinkedDevice]];
                message.associatedUniqueThreadId = readReceiptsForLinkedDevice.associatedUniqueThreadId;

                OWSLogInfo(@"will send linked read receipt:%@", readReceiptsForLinkedDevice.readPosition);
                
                [self.messageSender enqueueMessage:message
                    success:^{
                        OWSLogInfo(@"Successfully sent linked read receipt:%@", readReceiptsForLinkedDevice.readPosition);
                        OWSLogInfo(@"%@ Successfully sent %zd read receipt to linked devices.",
                            self.logTag,
                            readReceiptsForLinkedDevices.count);
                    }
                    failure:^(NSError *error) {
                        OWSLogInfo(@"Failed to send linked read receipt:%@", readReceiptsForLinkedDevice.readPosition);
                        OWSLogError(@"%@ Failed to send read receipt to linked devices with error: %@", self.logTag, error);
                    }];
            }
        }

        NSDictionary<NSString *, DTReadReceiptEntity *> *toSenderReadReceiptMap = [self.toSenderReadReceiptMap copy];
        [self.toSenderReadReceiptMap removeAllObjects];
        if (toSenderReadReceiptMap.count > 0) {
            for (NSString *recipientId in toSenderReadReceiptMap) {
                DTReadReceiptEntity *readReceiptEntity = toSenderReadReceiptMap[recipientId];
                NSSet<NSNumber *> *timestamps = readReceiptEntity.timestamps;
                OWSAssertDebug(timestamps.count > 0);

                TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:recipientId];
//                TSThread *thread = [TSThread fetchObjectWithUniqueID:readReceiptEntity.associatedUniqueThreadId];
                OWSReadReceiptsForSenderMessage *message =
                    [[OWSReadReceiptsForSenderMessage alloc] initWithThread:thread
                                                          messageTimestamps:timestamps.allObjects
                                                               readPosition:readReceiptEntity.readPosition
                                                            messageModeType:readReceiptEntity.messageModeType];
                
                OWSLogInfo(@"will send read receipt:%@, contactThread: %@", readReceiptEntity.readPosition, thread.contactIdentifier);
                
                message.associatedUniqueThreadId = readReceiptEntity.associatedUniqueThreadId;
                message.whisperMessageType = readReceiptEntity.whisperMessageType;

                [self.messageSender enqueueMessage:message
                    success:^{
                        OWSLogInfo(@"Successfully sent read receipt:%@, contactThread: %@", readReceiptEntity.readPosition, thread.contactIdentifier);
                        OWSLogInfo(@"%@ Successfully sent %zd read receipts to sender.", self.logTag, timestamps.count);
                    }
                    failure:^(NSError *error) {
                        OWSLogInfo(@"Failed to send read receipt:%@, contactThread: %@", readReceiptEntity.readPosition, thread.contactIdentifier);
                        OWSLogError(@"%@ Failed to send read receipts to sender with error: %@", self.logTag, error);
                    }];
            }
            [self.toSenderReadReceiptMap removeAllObjects];
        }

        BOOL didWork = (readReceiptsForLinkedDevices.count > 0 || toSenderReadReceiptMap.count > 0);

        if (didWork) {
            // Wait N seconds before processing read receipts again.
            // This allows time for a batch to accumulate.
            //
            // We want a value high enough to allow us to effectively de-duplicate,
            // read receipts without being so high that we risk not sending read
            // receipts due to app exit.
            const CGFloat kProcessingFrequencySeconds = 3.f;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kProcessingFrequencySeconds * NSEC_PER_SEC)),
                dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                ^{
                    [self process];
                });
        } else {
            self.isProcessing = NO;
        }
    }
     
}

#pragma mark - Mark as Read Locally

- (void)confidentialMessageWasReadLocally:(TSIncomingMessage *)message {
    dispatch_async(self.serialQueue, ^{
        @synchronized(self)
        {
            NSString *threadUniqueId = message.uniqueThreadId;
            OWSAssertDebug(threadUniqueId.length > 0);

            NSString *messageAuthorId = message.messageAuthorId;
            OWSAssertDebug(messageAuthorId.length > 0);
            
            if (!message.isConfidentialMessage) return;
            
            TSThread *thread = message.threadWithSneakyTransaction;

            OWSLinkedDeviceReadReceipt *newReadReceipt =
                [[OWSLinkedDeviceReadReceipt alloc] initWithSenderId:messageAuthorId
                                                  messageIdTimestamp:message.timestamp
                                                       readTimestamp:[NSDate ows_millisecondTimeStamp]];
            newReadReceipt.whisperMessageType = message.whisperMessageType;
            newReadReceipt.isLargeGroupThread = thread.isLargeGroupThread;
            newReadReceipt.associatedUniqueThreadId = message.uniqueThreadId;
            NSData *groupId = nil;
            if(thread.isGroupThread){
                groupId = ((TSGroupThread *)thread).groupModel.groupId;
            }
            uint64_t notifySequenceId = message.notifySequenceId;
            DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId readAt:[NSDate ows_millisecondTimeStamp] maxServerTime:message.serverTimestamp notifySequenceId:notifySequenceId maxSequenceId:message.sequenceId];
            newReadReceipt.readPosition = readPosition;
            
            newReadReceipt.messageModeType = message.messageModeType;

            if ([message.messageAuthorId isEqualToString:[TSAccountManager localNumber]]) {
                OWSLogInfo(@"Ignoring read receipt for self-sender. confidential message timestamp: %llu.", message.timestamp);
                return;
            }
            
            OWSReadReceiptsForLinkedDevicesMessage *syncMessage =
                [[OWSReadReceiptsForLinkedDevicesMessage alloc] initWithReadReceipts:@[newReadReceipt]];
            syncMessage.associatedUniqueThreadId = newReadReceipt.associatedUniqueThreadId;
            syncMessage.messageModeType = TSMessageModeTypeConfidential;

            OWSLogInfo(@"will send linked confidential read receipt:%@", newReadReceipt.readPosition);
            
            [self.messageSender enqueueMessage:syncMessage
                                       success:^{
                OWSLogInfo(@"Successfully sent linked read receipt:%@", newReadReceipt.readPosition);
            } failure:^(NSError *error) {
                    OWSLogError(@"%@ Failed to send read receipt to linked devices with error: %@", self.logTag, error);
            }];

                        
            DTReadReceiptEntity *readReceiptEntity = [DTReadReceiptEntity new];
            readReceiptEntity.associatedUniqueThreadId = message.uniqueThreadId;
            readReceiptEntity.messageModeType = message.messageModeType;
            readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId readAt:[NSDate ows_millisecondTimeStamp] maxServerTime:message.serverTimestamp notifySequenceId:notifySequenceId maxSequenceId:message.sequenceId];
            readReceiptEntity.readPosition = readPosition;
            OWSReadReceiptsForSenderMessage *receiptMessage = [[OWSReadReceiptsForSenderMessage alloc] initWithThread:thread
                                                                                                    messageTimestamps:@[@(message.timestamp)]
                                                                                                         readPosition:readReceiptEntity.readPosition
                                                                                                      messageModeType:TSMessageModeTypeConfidential];
            
            OWSLogInfo(@"will send read receipt:%@, contactThread: %@", readReceiptEntity.readPosition, thread.contactIdentifier);
            
            receiptMessage.associatedUniqueThreadId = readReceiptEntity.associatedUniqueThreadId;

            [self.messageSender enqueueMessage:receiptMessage
                                       success:^{
                OWSLogInfo(@"Successfully sent read receipt:%@, contactThread: %@", readReceiptEntity.readPosition, thread.contactIdentifier);
                
            } failure:^(NSError *error) {
                OWSLogError(@"%@ Failed to send read receipts to sender with error: %@", self.logTag, error);
            }];
            
        }
    });
}

- (void)markAsReadLocallyBeforePosition:(DTReadPositionEntity *)readPosition
                        oldReadPosition:(DTReadPositionEntity *)oldReadPosition
                                 thread:(TSThread *)thread
                             completion:(void (^)(uint64_t latestTimestamp))completion
{
    OWSAssertDebug(thread);
    
    [self markAsReadBeforePosition:readPosition
                   oldReadPosition:oldReadPosition
                             thread:thread
                           wasLocal:YES
                         completion:completion];
}

- (void)messageWasReadLocally:(TSIncomingMessage *)message shouldSendReadReceipt:(BOOL)shouldSendReadReceipt
{
    
    dispatch_async(self.serialQueue, ^{
        @synchronized(self)
        {
            NSString *threadUniqueId = message.uniqueThreadId;
            OWSAssertDebug(threadUniqueId.length > 0);

            NSString *messageAuthorId = message.messageAuthorId;
            OWSAssertDebug(messageAuthorId.length > 0);
            
            if (message.isConfidentialMessage) return;
            
            TSThread *thread = message.threadWithSneakyTransaction;

            OWSLinkedDeviceReadReceipt *newReadReceipt =
                [[OWSLinkedDeviceReadReceipt alloc] initWithSenderId:messageAuthorId
                                                  messageIdTimestamp:message.timestamp
                                                       readTimestamp:[NSDate ows_millisecondTimeStamp]];
            newReadReceipt.whisperMessageType = message.whisperMessageType;
            // TODO: check felix 2022-11-29
            newReadReceipt.isLargeGroupThread = thread.isLargeGroupThread;
            newReadReceipt.associatedUniqueThreadId = message.uniqueThreadId;
            NSData *groupId = nil;
            if(thread.isGroupThread){
                groupId = ((TSGroupThread *)thread).groupModel.groupId;
            }
            uint64_t notifySequenceId = message.notifySequenceId;
            DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId readAt:[NSDate ows_millisecondTimeStamp] maxServerTime:message.serverTimestamp notifySequenceId:notifySequenceId maxSequenceId:message.sequenceId];
            newReadReceipt.readPosition = readPosition;
            
            newReadReceipt.messageModeType = message.messageModeType;

            OWSLinkedDeviceReadReceipt *_Nullable oldReadReceipt = self.toLinkedDevicesReadReceiptMap[threadUniqueId];
            if (oldReadReceipt && oldReadReceipt.messageIdTimestamp > newReadReceipt.messageIdTimestamp) {
                // If there's an existing "linked device" read receipt for the same thread with
                // a newer timestamp, discard this "linked device" read receipt.
                OWSLogVerbose(@"%@ Ignoring redundant read receipt for linked devices.", self.logTag);
            } else {
                OWSLogInfo(@"Enqueuing read receipt for linked devices. message timestamp: %llu.", message.timestamp);
                self.toLinkedDevicesReadReceiptMap[threadUniqueId] = newReadReceipt;
            }

            if ([message.messageAuthorId isEqualToString:[TSAccountManager localNumber]]) {
                OWSLogInfo(@"Ignoring read receipt for self-sender. message timestamp: %llu.", message.timestamp);
                return;
            }

            if ([self areReadReceiptsEnabled] && shouldSendReadReceipt) {
                OWSLogInfo(@"Enqueuing read receipt for sender. message timestamp: %llu.", message.timestamp);
                DTReadReceiptEntity *readReceiptEntity = self.toSenderReadReceiptMap[messageAuthorId];
                
                NSMutableSet<NSNumber *> *_Nullable timestamps = readReceiptEntity.timestamps;
                if (!readReceiptEntity) {
                    readReceiptEntity = [DTReadReceiptEntity new];
                    self.toSenderReadReceiptMap[messageAuthorId] = readReceiptEntity;
                    timestamps = readReceiptEntity.timestamps;
                    readReceiptEntity.associatedUniqueThreadId = message.uniqueThreadId;
                }
                
                readReceiptEntity.messageModeType = message.messageModeType;
                
                [timestamps addObject:@(message.timestamp)];
                NSNumber *maxTimestamp = [timestamps valueForKeyPath:@"@max.self"];
                if([maxTimestamp isEqualToNumber:@(message.timestamp)]){
                    DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId readAt:[NSDate ows_millisecondTimeStamp] maxServerTime:message.serverTimestamp notifySequenceId:notifySequenceId maxSequenceId:message.sequenceId];
                    readReceiptEntity.readPosition = readPosition;
                }
                readReceiptEntity.whisperMessageType = TSEncryptedWhisperMessageType;
            }

            
            [self scheduleProcessing];
        }
    });
     
}

#pragma mark - Read Receipts From Recipient

- (void)processReadReceiptsFromRecipientId:(NSString *)recipientId
                            sentTimestamps:(NSArray<NSNumber *> *)sentTimestamps
                             readTimestamp:(uint64_t)readTimestamp
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(sentTimestamps);
    
    
    if (![self areReadReceiptsEnabled]) {
        OWSLogInfo(@"%@ Ignoring incoming receipt message as read receipts are disabled.", self.logTag);
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            
            for (NSNumber *nsSentTimestamp in sentTimestamps) {
                UInt64 sentTimestamp = [nsSentTimestamp unsignedLongLongValue];
                
                NSError *error;
                NSArray<TSOutgoingMessage *> *messages = (NSArray<TSOutgoingMessage *> *)[InteractionFinder interactionsWithTimestamp:sentTimestamp
                                                                                                      filter:^BOOL(TSInteraction * interaction) {
                    return ([interaction isKindOfClass:[TSOutgoingMessage class]]);
                } transaction:writeTransaction error:&error];
                
                if (messages.count > 1) {
                    OWSLogError(@"%@ More than one matching message with timestamp: %llu.", self.logTag, sentTimestamp);
                }
                if (messages.count > 0) {
                    // TODO: We might also need to "mark as read by recipient" any older messages
                    // from us in that thread.  Or maybe this state should hang on the thread?
                    for (TSOutgoingMessage *message in messages) {
                        
                        if(message.grdbId){
                            [self.databaseStorage touchInteraction:message
                                                     shouldReindex:NO
                                                       transaction:writeTransaction];
                        }
                        
                    }
                } else {
                    // Persist the read receipts so that we can apply them to outgoing messages
                    // that we learn about later through sync messages.
//                    [TSRecipientReadReceipt addRecipientId:recipientId
//                                             sentTimestamp:sentTimestamp
//                                             readTimestamp:readTimestamp
//                                               transaction:writeTransaction];
                }
            }
        });
    });
     
     
}
 
//收到同步消息，标记之前为已读
- (void)applyEarlyReadReceiptsForOutgoingMessageFromLinkedDevice:(TSOutgoingMessage *)message
                                                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(message);
    OWSAssertDebug(transaction);
    
    AnyMessageReadPositonFinder *finder = [AnyMessageReadPositonFinder new];
    NSError *error;
    __block NSString *recipientId = nil;
    __block TSMessageReadPosition *oldReadPosition = nil;
    [finder enumerateReadPositionsWithMaxServerTime:message.timestamp
                                        transaction:transaction
                                              error:&error
                                              block:^(TSMessageReadPosition * messageReadPosition) {
        NSArray<NSString *> *components = [messageReadPosition.uniqueId componentsSeparatedByString:@"_"];
        if(components.count == 2 && [components.firstObject isEqualToString:@"0"]){
            recipientId = components.lastObject;
            oldReadPosition = messageReadPosition;
        }
    }];
    
    if(oldReadPosition){
        TSThread *thread = [TSThread anyFetchWithUniqueId:message.uniqueThreadId
                                              transaction:transaction];
        NSData *groupId = nil;
        if(thread.isGroupThread){
            groupId = ((TSGroupThread *)thread).groupModel.groupId;
        }
        DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                    readAt:[NSDate ows_millisecondTimeStamp]
                                                                             maxServerTime:message.timestampForSorting
                                                                          notifySequenceId:message.notifySequenceId
                                                                             maxSequenceId:message.sequenceId];
        OWSLogInfo(@"applyEarlyReadReceiptsForOutgoingMessage will save readPosition:%@", readPosition);
        TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                               recipientId:recipientId
                                                                                              readPosition:readPosition];
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [messageReadPosition updateOrInsertWithTransaction:transaction];
            [oldReadPosition anyRemoveWithTransaction:transaction];
        });
    }
    
    /*
    TSThread *thread = [message threadWithTransaction:transaction];
    
    // 收到同步 ougoing message 后，将当前消息以前的所有 incomming message 全部标记为已读
    if (thread) {
        OWSLogInfo(@"[mark read]收到同步 ougoing message 后，将当前消息以前的所有 incomming message 全部标记为已读");
        
        [self markAsReadBeforeTimestamp:message.timestampForSorting
                                 thread:thread
                          readTimestamp:[NSDate ows_millisecondTimeStamp]
                               wasLocal:NO
                             completion:nil];
    }

    uint64_t sentTimestamp = message.timestamp;
    NSDictionary<NSString *, NSNumber *> *recipientMap =
        [TSRecipientReadReceipt recipientMapForSentTimestamp:sentTimestamp transaction:transaction];
    
    if (!recipientMap) {
        return;
    }
    
    OWSAssertDebug(recipientMap.count > 0);
    for (NSString *recipientId in recipientMap) {
        NSNumber *nsReadTimestamp = recipientMap[recipientId];
        OWSAssertDebug(nsReadTimestamp);
        uint64_t readTimestamp = [nsReadTimestamp unsignedLongLongValue];

        [message updateWithReadRecipientId:recipientId readTimestamp:readTimestamp transaction:transaction];
    }
    [TSRecipientReadReceipt removeRecipientIdsForTimestamp:message.timestamp transaction:transaction];
     */
}

#pragma mark - Linked Device Read Receipts

//收到更早的他人消息，标记为已读, 废弃
- (void)applyEarlyReadReceiptsForIncomingMessage:(TSIncomingMessage *)incomingmessage
                                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(incomingmessage);
    OWSAssertDebug(transaction);
    
/*
    NSString *senderId = message.messageAuthorId;
    uint64_t timestamp = message.timestamp;
    if (senderId.length < 1 || timestamp < 1) {
        OWSFailDebug(@"%@ Invalid incoming message: %@ %llu", self.logTag, senderId, timestamp);
        return;
    }

    OWSLinkedDeviceReadReceipt *_Nullable readReceipt =
        [OWSLinkedDeviceReadReceipt findLinkedDeviceReadReceiptWithSenderId:senderId
                                                         messageIdTimestamp:timestamp
                                                                transaction:transaction];
    if (readReceipt) {
        [message markAsReadAtTimestamp:readReceipt.readTimestamp sendReadReceipt:NO transaction:transaction];
        [readReceipt removeWithTransaction:transaction];
    }else{
        //add
        TSThread *thread = [message threadWithTransaction:transaction];
        DTReadPositionEntity *readPosition = thread.readPositionEntity;
        if(readPosition && message.timestampForSorting && message.timestampForSorting <= readPosition.maxServerTime){
            uint64_t readAt = readPosition.readAt;
            if(!readAt){
                readAt = [NSDate ows_millisecondTimeStamp];
            }
            [message markAsReadAtTimestamp:readAt sendReadReceipt:NO transaction:transaction];
        }
        //
    }
 */
     
    /*
    TSThread *thread = [message threadWithTransaction:transaction];
    if(thread.readAtServerTime > message.timestampForSorting){
        [message markAsReadAtTimestamp:readReceipt.readTimestamp sendReadReceipt:NO transaction:transaction];
    }
     */
}

- (void)processReadReceiptsFromLinkedDevice:(NSArray<DSKProtoSyncMessageRead *> *)readReceiptProtos
                              readTimestamp:(uint64_t)readTimestamp
                                transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(readReceiptProtos);
    OWSAssertDebug(transaction);

    for (DSKProtoSyncMessageRead *readReceiptProto in readReceiptProtos) {
        NSString *_Nullable senderId = readReceiptProto.sender;
        uint64_t messageIdTimestamp = readReceiptProto.timestamp;
        uint64_t serverTimestamp = 0;
        NSData *groupId = nil;
        
        if(readReceiptProto.readPosition){
            DTReadPositionEntity *readPositionEntity = [DTReadPositionEntity readPostionEntityWithProto:readReceiptProto.readPosition];
            if(readPositionEntity.readAt > 0){
                readTimestamp = readPositionEntity.readAt;
            }
            if(readPositionEntity.maxServerTime > 0){
                serverTimestamp = readPositionEntity.maxServerTime;
            }
            if(readPositionEntity.groupId.length > 0){
                groupId = readPositionEntity.groupId;
            }
            
            //add-
            if(!readPositionEntity.maxServerTime){
                OWSProdError(@"from linked device readPosition.maxServerTime = 0");
            }else{
                TSThread *thread = nil;
                if (groupId.length > 0) {
                    thread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
                }else if(senderId.length) {
                    thread = [TSContactThread getThreadWithContactId:senderId transaction:transaction];
                }
                
                OWSLogInfo(@"processReadReceiptsFromLinkedDevice will sendReadRecipet:%@", readPositionEntity);
                if(thread){
                    OWSLogInfo(@"processReadReceiptsFromLinkedDevice did sendReadRecipet:%@", readPositionEntity);
                    [self updateSelfReadPositionEntity:readPositionEntity
                                                thread:thread
                                           transaction:transaction];
                }
            }
        } else {
            
            
        }
        // sync read confidentialMessage
        if (readReceiptProto.messageMode == DSKProtoDataMessageMessageModeConfidential) {
            NSError *error;
            NSArray<TSIncomingMessage *> *incomingMessages = (NSArray<TSIncomingMessage *> *)[InteractionFinder interactionsWithTimestamp:messageIdTimestamp filter:^BOOL(TSInteraction * interaction) {
                return ([interaction isKindOfClass:[TSIncomingMessage class]]);
            } transaction:transaction error:&error];
            TSIncomingMessage *incomingMessage = incomingMessages.firstObject;
            if (incomingMessage.isConfidentialMessage) {
                [incomingMessage anyRemoveWithTransaction:transaction];
            }
        }
        
        OWSLogInfo(@"received a read receipt from linked device, messageIdTimestamp:%llu serverTimestamp: %llu", messageIdTimestamp, serverTimestamp);
        
        if (senderId.length == 0) {
            OWSFailDebug(@"%@ in %s senderId was unexpectedly nil", self.logTag, __PRETTY_FUNCTION__);
            continue;
        }
        
        if (messageIdTimestamp == 0) {
            OWSFailDebug(@"%@ in %s messageIdTimestamp was unexpectedly 0", self.logTag, __PRETTY_FUNCTION__);
            continue;
        }
        
    }
}


- (void)markAsReadOnLinkedDevice:(TSIncomingMessage *)message
                   readTimestamp:(uint64_t)readTimestamp
                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(message);
    OWSAssertDebug(transaction);
/*
    // Always re-mark the message as read to ensure any earlier read time is applied to disappearing messages.
    [message markAsReadAtTimestamp:readTimestamp sendReadReceipt:NO transaction:transaction];

    // Also mark any messages appearing earlier in the thread as read.
    //
    // Use `timestampForSorting` which reflects local received order, rather than `timestamp`
    // which reflect sender time.
    [self markAsReadBeforeTimestamp:message.timestampForSorting
                             thread:[message threadWithTransaction:transaction]
                      readTimestamp:readTimestamp
                           wasLocal:NO
                         completion:nil];
 */
}

 
#pragma mark - Mark As Read
// IncommingMessage
- (void)markAsReadBeforePosition:(DTReadPositionEntity *)readPosition
                 oldReadPosition:(DTReadPositionEntity *)oldReadPosition
                        thread:(TSThread *)thread
                         wasLocal:(BOOL)wasLocal
                       completion:(nullable void (^)(uint64_t latestTimestamp))completion
{
    OWSAssertDebug(readPosition.maxServerTime > 0);
    if(oldReadPosition){
        OWSAssertDebug(oldReadPosition.maxServerTime > 0);
    }
    OWSAssertDebug(oldReadPosition.maxServerTime < readPosition.maxServerTime);
    OWSAssertDebug(thread);
    
    dispatch_async(self.serialQueue, ^{
        
        __block NSArray<id<OWSReadTracking>> *newlyReadList;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            newlyReadList = [self unreadMessagesBeforePosition:readPosition oldReadPosition:oldReadPosition thread:thread transaction:readTransaction];
        }];
        
        if (newlyReadList.count < 1) {
            
            if (completion) {
                DispatchMainThreadSafe(^{
                    completion(0);
                });
            }
            return;
        }
        
        if (wasLocal) {
            OWSLogInfo(@"Marking %lu messages as read locally.", (unsigned long)newlyReadList.count);
        } else {
            OWSLogInfo(@"Marking %lu messages as read by linked device.", (unsigned long)newlyReadList.count);
        }
        
        TSIncomingMessage *msg = (TSIncomingMessage *)newlyReadList.lastObject;
        uint64_t latestTimestamp = [msg isKindOfClass:[TSIncomingMessage class]] ? msg.timestampForSorting : 0;
        
        NSInteger batchSize = 32;
        if (newlyReadList.count > batchSize) {
            
            NSMutableArray <id<OWSReadTracking>> *unmarkedNewlyReadList = newlyReadList.mutableCopy;
            
            while (unmarkedNewlyReadList.count > 0) {
                
                __block NSInteger loopBatchIndex = 0;
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    
                    [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                        id<OWSReadTracking> unmarkedReadItem = unmarkedNewlyReadList.lastObject;
                        if (loopBatchIndex == batchSize ||
                            unmarkedReadItem == nil) {
                            *stop = YES;
                            return;
                        }
                        
                        [unmarkedNewlyReadList removeLastObject];
                        [unmarkedReadItem markAsReadAtPosition:readPosition sendReadReceipt:wasLocal transaction:writeTransaction];
                        
                        loopBatchIndex += 1;
                    }];
                });
                
                OWSLogInfo(@"Marking %lu messages as read locally loop:%ld.", (unsigned long)newlyReadList.count, (long)loopBatchIndex);
            }
            
            if (completion) {
                DispatchMainThreadSafe(^{
                    completion(latestTimestamp);
                });
            }
        } else {
            
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                NSMutableArray <id<OWSReadTracking>> *unmarkedNewlyReadList = newlyReadList.mutableCopy;
                [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                    id<OWSReadTracking> unmarkedReadItem = unmarkedNewlyReadList.lastObject;
                    if (unmarkedReadItem == nil) {
                        *stop = YES;
                        return;
                    }
                    
                    [unmarkedNewlyReadList removeLastObject];
                    [unmarkedReadItem markAsReadAtPosition:readPosition sendReadReceipt:wasLocal transaction:writeTransaction];
                }];
            });
            
            if (completion) {
                DispatchMainThreadSafe(^{
                    completion(latestTimestamp);
                });
            }
        }
    });
     
}

- (NSArray<id<OWSReadTracking>> *)unreadMessagesBeforePosition:(DTReadPositionEntity *)readPosition
                                                  oldReadPosition:(DTReadPositionEntity *)oldReadPosition
                                                      thread:(TSThread *)thread
                                                 transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(readPosition.maxServerTime > 0);
    if(oldReadPosition){
        OWSAssertDebug(oldReadPosition.maxServerTime > 0);
    }
    OWSAssertDebug(oldReadPosition.maxServerTime < readPosition.maxServerTime);
    OWSAssertDebug(thread);
    OWSAssertDebug(transaction);
    
    // POST GRDB TODO: We could pass readTimestamp and sortId through to the GRDB query.
    NSMutableArray<id<OWSReadTracking>> *newlyReadList = [NSMutableArray new];
    InteractionFinder *interactionFinder = [[InteractionFinder alloc] initWithThreadUniqueId:thread.uniqueId];
    NSError *error;
    [interactionFinder
     enumerateUnseenInteractionsWithOldReadPosition:oldReadPosition newReadPosition:readPosition transaction:transaction
     error:&error
     block:^(TSInteraction *interaction, BOOL *stop) {
        if (![interaction conformsToProtocol:@protocol(OWSReadTracking)]) {
            OWSFailDebug(@"Expected to conform to OWSReadTracking: object "
                         @"with class: %@ collection: %@ "
                         @"key: %@",
                         [interaction class],
                         TSInteraction.collection,
                         interaction.uniqueId);
            return;
        }
        
        
        id<OWSReadTracking> possiblyRead = (id<OWSReadTracking>)interaction;
        [newlyReadList addObject:possiblyRead];
        /*
        id<OWSReadTracking> possiblyRead = (id<OWSReadTracking>)interaction;
        if (possiblyRead.timestampForSorting > sortId) {
            *stop = YES;
            return;
        }
        
        OWSAssertDebug(!possiblyRead.read);
        OWSAssertDebug(possiblyRead.expireStartedAt == 0);
        if (!possiblyRead.read) {
            [newlyReadList addObject:possiblyRead];
        }
         */
    }];
    if (error != nil) {
        OWSFailDebug(@"Error during enumeration: %@", error);
    }
    return [newlyReadList copy];
     
}

#pragma mark - Settings

- (void)prepareCachedValues
{
    [self areReadReceiptsEnabled];
}

- (BOOL)areReadReceiptsEnabled
{
    /*
    // We don't need to worry about races around this cached value.
    if (!self.areReadReceiptsEnabledCached) {
        // Default to NO.
        __block NSNumber *areReadReceiptsEnabledCached = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            areReadReceiptsEnabledCached = [readTransaction.transitional_yapReadTransaction
                                            objectForKey:OWSReadReceiptManagerAreReadReceiptsEnabled
                                            inCollection:OWSReadReceiptManagerCollection];
        }];
        self.areReadReceiptsEnabledCached = areReadReceiptsEnabledCached;
    }

    return [self.areReadReceiptsEnabledCached boolValue];
     */
    return YES;
}

- (BOOL)areReadReceiptsEnabledWithTransaction:(SDSAnyReadTransaction *)transaction
{
    /*
    if (!self.areReadReceiptsEnabledCached) {
        
        self.areReadReceiptsEnabledCached = [transaction objectForKey:OWSReadReceiptManagerAreReadReceiptsEnabled
                                                         inCollection:OWSReadReceiptManagerCollection];
    }

    return [self.areReadReceiptsEnabledCached boolValue];
     */
    return NO;
}

- (void)setAreReadReceiptsEnabled:(BOOL)value
{
    /*
    OWSLogInfo(@"%@ setAreReadReceiptsEnabled: %d.", self.logTag, value);

    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
        [writeTransaction.transitional_yapWriteTransaction setObject:@(value)
                                                              forKey:OWSReadReceiptManagerAreReadReceiptsEnabled
                                                        inCollection:OWSReadReceiptManagerCollection];
    }];

    OWSSyncConfigurationMessage *syncConfigurationMessage =
        [[OWSSyncConfigurationMessage alloc] initWithReadReceiptsEnabled:value];
    [self.messageSender enqueueMessage:syncConfigurationMessage
        success:^{
            OWSLogInfo(@"%@ Successfully sent Configuration syncMessage.", self.logTag);
        }
        failure:^(NSError *error) {
            OWSLogError(@"%@ Failed to send Configuration syncMessage with error: %@", self.logTag, error);
        }];

    self.areReadReceiptsEnabledCached = @(value);
    */
}

#pragma mark - Others

- (void)updateSelfReadPositionEntity:(DTReadPositionEntity *)readPosition
                              thread:(TSThread *)thread
                         transaction:(SDSAnyWriteTransaction *)transaction {
    if(readPosition.maxServerTime <=0 || readPosition.readAt <= 0) {
        OWSLogError(@"sendReadRecipet, invalid readPosition: maxServerTime or readAt <= 0!");
        return;
    }
    
    if(readPosition.groupId.length && !thread.isGroupThread){
        OWSLogError(@"sendReadRecipet, invalid readPosition: groupId != null, thread is not group!");
        return;
    }
    
    if(readPosition.maxServerTime <= thread.readPositionEntity.maxServerTime) {
        OWSLogError(@"sendReadRecipet, invalid readPosition: new <= old");
        return;
    }
    
    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                           recipientId:localNumber
                                                                                          readPosition:readPosition];
    [messageReadPosition updateOrInsertWithTransaction:transaction];
    __block NSUInteger count = 0;
    [thread anyUpdateWithTransaction:transaction
                               block:^(TSThread * instance) {
        [instance updateReadPositionEntity:readPosition];
        if (count == 1){
            NSUInteger unreadCount = [instance getUnreadMessageCountWithTransaction:transaction];
            [instance updateUnreadMessageCount:unreadCount];
            [thread updateUnreadMessageCount:unreadCount];
        }
        count++;
    }];
}


- (void)sendReadRecipetWithReadPosition:(DTReadPositionEntity *)readPosition
                                 thread:(TSThread *)thread
                               wasLocal:(BOOL)wasLocal
                             completion:(nullable dispatch_block_t)completion {
    
    if(readPosition.maxServerTime <=0 || readPosition.readAt <= 0) {
        OWSLogError(@"sendReadRecipet, invalid readPosition: maxServerTime or readAt <= 0!");
        if(completion){
            completion();
        }
        return;
    }
    
    if(readPosition.groupId.length && !thread.isGroupThread){
        OWSLogError(@"sendReadRecipet, invalid readPosition: groupId != null, thread is not group!");
        if(completion){
            completion();
        }
        return;
    }
    
    if(readPosition.maxServerTime <= thread.readPositionEntity.maxServerTime) {
        OWSLogError(@"sendReadRecipet, invalid readPosition: new <= old");
        if(completion){
            completion();
        }
        return;
    }
    
    void (^saveBlock)(void) = ^ {
        TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                               recipientId:[TSAccountManager localNumber]
                                                                                              readPosition:readPosition];
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [messageReadPosition updateOrInsertWithTransaction:transaction];
            __block NSUInteger count = 0;
            [thread anyUpdateWithTransaction:transaction
                                            block:^(TSThread * instance) {
                [instance updateReadPositionEntity:readPosition];
                if (count == 1){
                    NSUInteger unreadCount = [instance getUnreadMessageCountWithTransaction:transaction];
                    [instance updateUnreadMessageCount:unreadCount];
                    [thread updateUnreadMessageCount:unreadCount];
                }
                count++;
            }];
            [transaction addAsyncCompletionOnMain:^{
                if(completion){
                    completion();
                }
            }];
        });
    };
    
    
    if(wasLocal){
        [self markAsReadLocallyBeforePosition:readPosition
                              oldReadPosition:thread.readPositionEntity
                                       thread:thread
                                   completion:^(uint64_t latestTimestamp) {
            
            OWSAssertIsOnMainThread();
            
            saveBlock();
            
        }];
    } else {
        saveBlock();
    }
    
    
   
}

- (void)temporarySaveNeedToUpdateReadPositionMessage:(TSMessageReadPosition *)messageReadPosition message:(TSOutgoingMessage *)message {
    
    if(!DTParamsUtils.validateString(message.uniqueId) || !messageReadPosition) return;
    
    if(message.timestamp != message.serverTimestamp) return;
    
    dispatch_async(self.serialQueue, ^{
        
        if(!self.needToUpdateReadPositionMessageMap){
            self.needToUpdateReadPositionMessageMap = @{}.mutableCopy;
        }
        
        if(self.needToUpdateReadPositionMessageMap.count > 1000){
            
            OWSLogWarn(@"temporary saved readPosition > 1000, drop!");
            
            return;
        }
        
        self.needToUpdateReadPositionMessageMap[message.uniqueId] = messageReadPosition;
        OWSLogInfo(@"temporary saved readPosition.");
        
    });
    
}
- (void)handleNeedToUpdateReadPositionMessage:(TSOutgoingMessage *)message thread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction{
    
    if(!DTParamsUtils.validateString(message.uniqueId)) return;
    
    //    dispatch_async(self.serialQueue, ^{
    
    if(!self.needToUpdateReadPositionMessageMap.count) return;
    
    TSMessageReadPosition *oldPosition = self.needToUpdateReadPositionMessageMap[message.uniqueId];
    if(!oldPosition) return;
    
    NSData *groupId = nil;
    if(thread.isGroupThread){
        groupId = ((TSGroupThread *)thread).groupModel.groupId;
    }
    DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                readAt:oldPosition.readAt
                                                                         maxServerTime:message.timestampForSorting
                                                                      notifySequenceId:message.notifySequenceId
                                                                         maxSequenceId:message.sequenceId];
    TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:oldPosition.uniqueThreadId
                                                                                           recipientId:oldPosition.recipientId
                                                                                          readPosition:readPosition];
    [messageReadPosition updateOrInsertWithTransaction:transaction];
    
    [self.needToUpdateReadPositionMessageMap removeObjectForKey:message.uniqueId];
    
    OWSLogInfo(@"remove temporary saved readPosition.");
    
    //    });
    
}


@end

NS_ASSUME_NONNULL_END
