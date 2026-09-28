//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageSender.h"
#import "AppContext.h"
#import "ContactsUpdater.h"
#import "NSData+messagePadding.h"
#import "NSData+Image.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSError+MessageSending.h"
#import "OWSBackgroundTask.h"
#import "OWSContact.h"
#import "OWSDevice.h"
#import "OWSError.h"
#import "OWSIdentityManager.h"
#import "OWSMessageServiceParams.h"
#import "OWSOperation.h"
#import "OWSOutgoingSentMessageTranscript.h"
#import "OWSOutgoingSyncMessage.h"
#import "OWSRequestFactory.h"
#import "OWSUploadOperation.h"
#import "SignalRecipient.h"
#import "TSAccountManager.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSQuotedMessage.h"
#import "TSThread.h"
#import "Threading.h"
#import <TwistedOakCollapsingFutures/CollapsingFutures.h>
#import "DTApnsMessageBuilder.h"
#import "DTCombinedForwardingMessage.h"
#import "DTParamsBaseUtils.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTGroupUtils.h"
#import "TSMessageReadPosition.h"
#import "DTReadPositionEntity.h"

NS_ASSUME_NONNULL_BEGIN
// TODO: fix bad extern define here
extern NSString *const OWSMimeTypeOversizeTextMessage;

const NSUInteger kOversizeTextMessageSizeThreshold = 4 * 1024;
const NSUInteger kOversizeTextMessageSizelength = 4 * 1024 ;
const NSUInteger kOversizeTextMessageBodyLength = 2 * 1024;
const NSUInteger kReceivedOversizeBodyLength = 8 * 1024;

void AssertIsOnSendingQueue(void)
{
#ifdef DEBUG
    if (@available(iOS 10.0, *)) {
        dispatch_assert_queue([OWSDispatch sendingQueue]);
    } // else, skip assert as it's a development convenience.
#endif
}

#pragma mark -

/**
 * OWSSendMessageOperation encapsulates all the work associated with sending a message, e.g. uploading attachments,
 * getting proper keys, and retrying upon failure.
 *
 * Used by `OWSMessageSender` to serialize message sending, ensuring that messages are emitted in the order they
 * were sent.
 */
@interface OWSSendMessageOperation : OWSOperation

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMessage:(TSOutgoingMessage *)message
                  messageSender:(OWSMessageSender *)messageSender
                        success:(void (^)(void))aSuccessHandler
                        failure:(void (^)(NSError *_Nonnull error))aFailureHandler NS_DESIGNATED_INITIALIZER;

@end

#pragma mark -

@interface OWSMessageSender (OWSSendMessageOperation)

- (void)sendMessageToService:(TSOutgoingMessage *)message
                     success:(void (^)(void))successHandler
                     failure:(RetryableFailureHandler)failureHandler;

@end

#pragma mark -

@interface OWSSendMessageOperation ()

@property (nonatomic, readonly) TSOutgoingMessage *message;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) void (^successHandler)(void);
@property (nonatomic, readonly) void (^failureHandler)(NSError *_Nonnull error);

@end

#pragma mark -

@implementation OWSSendMessageOperation

- (instancetype)initWithMessage:(TSOutgoingMessage *)message
                  messageSender:(OWSMessageSender *)messageSender
                        success:(void (^)(void))successHandler
                        failure:(void (^)(NSError *_Nonnull error))failureHandler
{
    self = [super init];
    if (!self) {
        return self;
    }

    _message = message;
    _messageSender = messageSender;
    _successHandler = successHandler;
    _failureHandler = failureHandler;

    return self;
}

#pragma mark - OWSOperation overrides

- (nullable NSError *)checkForPreconditionError
{
    for (NSOperation *dependency in self.dependencies) {
        if (![dependency isKindOfClass:[OWSOperation class]]) {
            NSString *errorDescription =
                [NSString stringWithFormat:@"%@ unknown dependency: %@", self.logTag, dependency.class];
            NSError *assertionError = OWSErrorMakeAssertionError(errorDescription);
            return assertionError;
        }

        OWSOperation *upload = (OWSOperation *)dependency;

        // Cannot proceed if dependency failed - surface the dependency's error.
        NSError *_Nullable dependencyError = upload.failingError;
        if (dependencyError) {
            return dependencyError;
        }
    }

    // Sanity check preconditions
    if (self.message.hasAttachments) {
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
            TSAttachmentStream *attachmentStream
                = (TSAttachmentStream *)[self.message attachmentWithTransaction:transaction];
            OWSAssertDebug(attachmentStream);
            OWSAssertDebug([attachmentStream isKindOfClass:[TSAttachmentStream class]]);
            OWSAssertDebug(attachmentStream.serverId);
            OWSAssertDebug(attachmentStream.isUploaded);
        }];
    }

    return nil;
}

- (void)run
{
    // If the message has been deleted, abort send.
    __block TSOutgoingMessage *OutgoingMessage = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        OutgoingMessage = [TSOutgoingMessage anyFetchOutgoingMessageWithUniqueId:self.message.uniqueId transaction:transaction];
    }];
    if (self.message.shouldBeSaved && !OutgoingMessage) {
        OWSLogInfo(@"%@ aborting message send; message deleted.", self.logTag);
        NSError *error = OWSErrorWithCodeDescription(
            OWSErrorCodeMessageDeletedBeforeSent, @"Message was deleted before it could be sent.");
        error.isFatal = YES;
        [self reportError:error];
        return;
    }

    [self.messageSender sendMessageToService:self.message success:^{
        [self reportSuccess];
    } failure:^(NSError *error) {
        [self reportError:error];
    }];
}

- (void)didSucceed
{
    if (self.message.messageState != TSOutgoingMessageStateSent) {
        OWSFailDebug(@"%@ unexpected message status: %@", self.logTag, self.message.statusDescription);
    }

    self.successHandler();
}

- (void)didFailWithError:(NSError *)error
{
    [self.message updateWithSendingError:error];
    
    OWSLogDebug(@"%@ failed with error: %@", self.logTag, error);
    self.failureHandler(error);
}

@end


int const OWSMessageSenderRetryAttempts = 3;
NSString *const OWSMessageSenderInvalidDeviceException = @"InvalidDeviceException";
NSString *const OWSMessageSenderRateLimitedException = @"RateLimitedException";

/// A quoted thumbnail prepared before the send transaction.
@interface OWSPreparedQuotedThumbnail : NSObject

@property (nonatomic) OWSAttachmentInfo *attachmentInfo;
@property (nonatomic) TSAttachmentStream *sourceStream;
@property (nonatomic) TSAttachmentStream *thumbnailStream;

@end

@implementation OWSPreparedQuotedThumbnail
@end

@interface OWSMessageSender ()

@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, readonly) ContactsUpdater *contactsUpdater;
@property (atomic, readonly) NSMutableDictionary<NSString *, NSOperationQueue *> *sendingQueueMap;

/// Per-conversation preparation queues for attachment preprocessing (currently
/// video compression). Two concurrent lanes, keyed by `uniqueThreadId` like
/// `sendingQueueMap`, so a backlog in conversation A never gates conversation B.
@property (atomic, readonly) NSMutableDictionary<NSString *, NSOperationQueue *> *preparationQueueMap;

- (OWSUploadOperation *)buildUploadOperationForAttachmentId:(NSString *)attachmentId
                                               recipientIds:(NSArray *)recipientIds
                                                    message:(TSOutgoingMessage *)message;

- (NSArray<OWSPreparedQuotedThumbnail *> *)prepareQuotedThumbnailsForMessage:(TSOutgoingMessage *)message;
- (NSArray<TSAttachmentStream *> *)persistPreparedQuotedThumbnails:
    (NSArray<OWSPreparedQuotedThumbnail *> *)preparedThumbnails
                                                       transaction:(SDSAnyWriteTransaction *)transaction;
- (void)removeUnpersistedPreparedQuotedThumbnails:(NSArray<OWSPreparedQuotedThumbnail *> *)preparedThumbnails
                                             persisted:(NSArray<TSAttachmentStream *> *)persistedThumbnails;

@end

@implementation OWSMessageSender

- (instancetype)initWithContactsManager:(id<ContactsManagerProtocol>)contactsManager
                       contactsUpdater:(ContactsUpdater *)contactsUpdater
{
    self = [super init];
    if (!self) {
        return self;
    }

    _contactsManager = contactsManager;
    _contactsUpdater = contactsUpdater;
    _sendingQueueMap = [NSMutableDictionary new];
    _preparationQueueMap = [NSMutableDictionary new];

    OWSSingletonAssert();

    return self;
}

- (NSOperationQueue *)sendingQueueForMessage:(TSOutgoingMessage *)message
{
    OWSAssertDebug(message);

    NSString *kDefaultQueueKey = @"kDefaultQueueKey";
    NSString *queueKey = message.uniqueThreadId ?: kDefaultQueueKey;
    OWSAssertDebug(queueKey.length > 0);

    if ([kDefaultQueueKey isEqualToString:queueKey]) {
        // when do we get here?
        OWSLogDebug(@"%@ using default message queue", self.logTag);
    }

    @synchronized(self)
    {
        NSOperationQueue *sendingQueue = self.sendingQueueMap[queueKey];

        if (!sendingQueue) {
            sendingQueue = [NSOperationQueue new];
            sendingQueue.qualityOfService = NSOperationQualityOfServiceUserInitiated;
            sendingQueue.maxConcurrentOperationCount = 1;

            self.sendingQueueMap[queueKey] = sendingQueue;
        }

        return sendingQueue;
    }
}

- (NSOperationQueue *)preparationQueueForMessage:(TSOutgoingMessage *)message
{
    OWSAssertDebug(message);

    NSString *queueKey = message.uniqueThreadId ?: @"kDefaultQueueKey";
    OWSAssertDebug(queueKey.length > 0);

    @synchronized(self)
    {
        NSOperationQueue *preparationQueue = self.preparationQueueMap[queueKey];

        if (!preparationQueue) {
            preparationQueue = [NSOperationQueue new];
            preparationQueue.name = [NSString stringWithFormat:@"OWSMessageSender.preparation.%@", queueKey];
            preparationQueue.qualityOfService = NSOperationQualityOfServiceUserInitiated;
            // Preparation is independent per message. Two lanes let the next video
            // make progress while another is transcoding without allowing a large
            // picker batch to saturate VideoToolbox, memory, and disk I/O. Completion
            // order intentionally wins: a later short clip may upload and arrive before
            // an earlier long clip, matching the product's independent-send behavior.
            preparationQueue.maxConcurrentOperationCount = 2;

            self.preparationQueueMap[queueKey] = preparationQueue;
        }

        return preparationQueue;
    }
}

/// Build the standard outgoing-attachment upload operation. Extracted so the
/// regular upload branch and the post-preprocessing branch share the same
/// recipient + rapid-file wiring. Caller owns `addDependency:` / queueing.
- (OWSUploadOperation *)buildUploadOperationForAttachmentId:(NSString *)attachmentId
                                               recipientIds:(NSArray *)recipientIds
                                                    message:(TSOutgoingMessage *)message
{
    OWSUploadOperation *uploadOperation =
        [[OWSUploadOperation alloc] initWithAttachmentId:attachmentId recipientIds:[recipientIds copy]];
    uploadOperation.rapidFileInfoBlock = ^(NSDictionary *_Nonnull info) {
        if (info.count < 2) {
            OWSLogError(@"%@ get rapidFile info failed!", self.logTag);
            OWSProdError(@"get rapidFile info failed!");
            return;
        }
        NSError *error;
        DTRapidFile *rapidFile = [MTLJSONAdapter modelOfClass:[DTRapidFile class]
                                           fromJSONDictionary:info
                                                        error:&error];
        if (!error) {
            NSMutableArray *items = @[].mutableCopy;
            if (message.rapidFiles.count) {
                [items addObjectsFromArray:message.rapidFiles];
            }
            [items addObject:rapidFile];
            message.rapidFiles = items.copy;
        } else {
            OWSLogError(@"%@ rapidFile info to model failed!", self.logTag);
            OWSProdError(@"rapidFile info to model failed!");
        }
    };
    return uploadOperation;
}

- (NSArray<OWSPreparedQuotedThumbnail *> *)prepareQuotedThumbnailsForMessage:(TSOutgoingMessage *)message
{
    TSQuotedMessage *_Nullable quotedMessage = message.quotedMessage;
    if (!quotedMessage) {
        return @[];
    }

    NSMutableArray<OWSPreparedQuotedThumbnail *> *preparedThumbnails = [NSMutableArray new];
    for (OWSAttachmentInfo *attachmentInfo in quotedMessage.quotedAttachments) {
        NSString *_Nullable sourceAttachmentId = attachmentInfo.attachmentId;
        if (sourceAttachmentId.length < 1
            || ![TSAttachmentStream hasThumbnailForMimeType:attachmentInfo.contentType]) {
            continue;
        }

        __block TSAttachmentStream *_Nullable sourceStream = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
            TSAttachment *_Nullable attachment =
                [TSAttachment anyFetchWithUniqueId:sourceAttachmentId transaction:transaction];
            if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                sourceStream = (TSAttachmentStream *)attachment;
            }
        }];
        if (!sourceStream) {
            continue;
        }

        // Decrypt and decode before acquiring the write transaction.
        TSAttachmentStream *_Nullable thumbnailStream = [sourceStream cloneAsThumbnail];
        if (!thumbnailStream) {
            continue;
        }

        OWSPreparedQuotedThumbnail *prepared = [OWSPreparedQuotedThumbnail new];
        prepared.attachmentInfo = attachmentInfo;
        prepared.sourceStream = sourceStream;
        prepared.thumbnailStream = thumbnailStream;
        [preparedThumbnails addObject:prepared];
    }
    return [preparedThumbnails copy];
}

- (NSArray<TSAttachmentStream *> *)persistPreparedQuotedThumbnails:
    (NSArray<OWSPreparedQuotedThumbnail *> *)preparedThumbnails
                                                       transaction:(SDSAnyWriteTransaction *)transaction
{
    NSMutableArray<TSAttachmentStream *> *persistedThumbnails = [NSMutableArray new];
    for (OWSPreparedQuotedThumbnail *prepared in preparedThumbnails) {
        TSAttachmentStream *preparedSource = prepared.sourceStream;
        TSAttachment *_Nullable attachment =
            [TSAttachment anyFetchWithUniqueId:preparedSource.uniqueId transaction:transaction];
        if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
            continue;
        }

        TSAttachmentStream *canonicalSource = (TSAttachmentStream *)attachment;
        BOOL sameRelativePath = canonicalSource.localRelativeFilePath == preparedSource.localRelativeFilePath
            || [canonicalSource.localRelativeFilePath isEqualToString:preparedSource.localRelativeFilePath];
        BOOL samePayload = sameRelativePath
            && canonicalSource.byteCount == preparedSource.byteCount
            && [canonicalSource.contentType isEqualToString:preparedSource.contentType];
        if (!samePayload) {
            OWSLogWarn(@"%@ quoted attachment changed while preparing its thumbnail: %@",
                       self.logTag,
                       preparedSource.uniqueId);
            continue;
        }

        TSAttachmentStream *thumbnailStream = prepared.thumbnailStream;
        // The payload is already a display-ready JPEG.
        [thumbnailStream anyInsertPreparedThumbnailWithTransaction:transaction];
        prepared.attachmentInfo.thumbnailAttachmentStreamId = thumbnailStream.uniqueId;
        [persistedThumbnails addObject:thumbnailStream];
    }
    return [persistedThumbnails copy];
}

- (void)removeUnpersistedPreparedQuotedThumbnails:(NSArray<OWSPreparedQuotedThumbnail *> *)preparedThumbnails
                                         persisted:(NSArray<TSAttachmentStream *> *)persistedThumbnails
{
    NSSet<NSString *> *persistedIds = [NSSet setWithArray:[persistedThumbnails valueForKey:@"uniqueId"]];
    for (OWSPreparedQuotedThumbnail *prepared in preparedThumbnails) {
        if ([persistedIds containsObject:prepared.thumbnailStream.uniqueId]) {
            continue;
        }
        // Remove files rejected by canonical revalidation.
        [prepared.thumbnailStream removePlaintextFile];
    }
}

- (void)enqueueMessage:(TSOutgoingMessage *)message
               success:(void (^)(void))successHandler
               failure:(void (^)(NSError *error))failureHandler
{
    OWSLogInfo(@"%@ message:%llu send step-1 ENQUEUE MESSAGE.", self.logTag, message.timestamp);
    OWSAssertDebug(message);
    if (![message isKindOfClass:[TSOutgoingMessage class]]) {
        OWSLogError(@"%@ message is not TSOutgoingMessage, type:%@.", self.logTag, [message class]);
        return;
    }
    if (message.body.length > 0) {
        OWSAssertDebug([message.body lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= kOversizeTextMessageSizeThreshold);
    }
    
    //发送 消息队列
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSArray<OWSPreparedQuotedThumbnail *> *preparedQuotedThumbnails =
            [self prepareQuotedThumbnailsForMessage:message];
        __block NSArray<TSAttachmentStream *> *quotedThumbnailAttachments = @[];
        __block NSArray<TSAttachment *> *forwardingAttachments = @[];
        __block TSAttachmentStream *_Nullable contactShareAvatarAttachment;
        __block TSThread *desThread = nil;
        // This method will use a read/write transaction. This transaction
        // will block until any open read/write transactions are complete.
        //
        // That's key - we don't want to send any messages in response
        // to an incoming message until processing of that batch of messages
        // is complete.  For example, we wouldn't want to auto-reply to a
        // group info request before that group info request's batch was
        // finished processing.  Otherwise, we might receive a delivery
        // notice for a group update we hadn't yet saved to the db.
        //
        // So we're using YDB behavior to ensure this invariant, which is a bit
        // unorthodox.
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            
            if (message.quotedMessage) {
                quotedThumbnailAttachments =
                    [self persistPreparedQuotedThumbnails:preparedQuotedThumbnails transaction:writeTransaction];
            }
            
            if (message.combinedForwardingMessage) {
                forwardingAttachments =
                    [message.combinedForwardingMessage forwardingAttachmentsWithTransaction:writeTransaction];
                [forwardingAttachments enumerateObjectsUsingBlock:^(TSAttachment * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (![obj isKindOfClass:TSAttachment.class]) {
                        return;
                    }
                    [obj anyUpdateWithTransaction:writeTransaction block:^(TSAttachment * _Nonnull attachment) {
                        attachment.albumId = message.uniqueThreadId;
                        attachment.albumMessageId = message.uniqueId;
                    }];
                }];
            }

            if (message.contactShare.avatarAttachmentId != nil) {
                TSAttachment *avatarAttachment = [message.contactShare avatarAttachmentWithTransaction:writeTransaction];
                if ([avatarAttachment isKindOfClass:[TSAttachmentStream class]]) {
                    contactShareAvatarAttachment = (TSAttachmentStream *)avatarAttachment;
                } else {
                    OWSFailDebug(@"%@ in %s unexpected avatarAttachment: %@",
                        self.logTag,
                        __PRETTY_FUNCTION__,
                        avatarAttachment);
                }
            }
            
            desThread = [message threadWithTransaction:writeTransaction];

            if (message.shouldBeSaved) {
                // All outgoing messages should be saved at the time they are enqueued.
                // When we start a message send, all "failed" recipients should be marked as "sending".
                [message updateWithMarkingAllUnsentRecipientsAsSendingWithTransaction:writeTransaction];
                [message anyInsertWithTransaction:writeTransaction];

                // 发送消息成功后, 将已归档的会话解除归档状态
                if (desThread.isArchived) {
                    [desThread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                        [t unarchiveThread];
                    }];
                }
            }
        });

        [self removeUnpersistedPreparedQuotedThumbnails:preparedQuotedThumbnails
                                               persisted:quotedThumbnailAttachments];
        
        NSOperationQueue *sendingQueue = [self sendingQueueForMessage:message];
        OWSSendMessageOperation *sendMessageOperation =
            [[OWSSendMessageOperation alloc] initWithMessage:message
                                               messageSender:self
                                                     success:successHandler
                                                     failure:failureHandler];

        OWSLogInfo(@"%@ message:%llu send step-2.1 创建发送消息 operation", self.logTag, message.timestamp);
        
        // TODO de-dupe attachment enque logic.
        if (message.hasAttachments) {

            NSString *attachmentId = message.attachmentIds.firstObject;
            NSArray *recipientIds = desThread.recipientIdentifiers;

            __block TSAttachmentStream *placeholderStream = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                TSAttachment *attachment = [TSAttachment anyFetchWithUniqueId:attachmentId
                                                                  transaction:transaction];
                if ([attachment isKindOfClass:[TSAttachmentStream class]]
                    && ((TSAttachmentStream *)attachment).preprocessingKind != TSAttachmentPreprocessingKindNone) {
                    placeholderStream = (TSAttachmentStream *)attachment;
                }
            }];

            OWSOperation *prepOp = nil;
            if (placeholderStream) {
                // Off the insert transaction (see -[TSAttachmentStream
                // anyDidInsertWithTransaction:]): a video still needs the hardware
                // decoder, which a concurrent compression can hold for seconds, and
                // under the write lock that stalls every later bubble. Touch the
                // message after — the cell keys off interactions, not attachments.
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    [placeholderStream ensureThumbnail];
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *thumbnailTransaction) {
                        if (message.grdbId) {
                            [self.databaseStorage touchInteraction:message
                                                     shouldReindex:NO
                                                       transaction:thumbnailTransaction];
                        }
                    });
                });

                prepOp = [self makePreprocessingOperationForMessage:message attachment:placeholderStream];
                if (!prepOp) {
                    // No factory entry for this kind (programmer error). Bail instead
                    // of falling through to the regular upload branch, which would
                    // ship the placeholder's uncompressed payload as the final one.
                    OWSFailDebug(@"%@ no preprocessing operation for kind %lu",
                                 self.logTag,
                                 (unsigned long)placeholderStream.preprocessingKind);
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        [message updateWithAllSendingRecipientsMarkedAsFailedWithTansaction:transaction];
                    });
                    NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
                    [error setIsRetryable:NO];
                    return failureHandler(error);
                }
            }

            OWSUploadOperation *uploadAttachmentOperation =
                [self buildUploadOperationForAttachmentId:attachmentId
                                             recipientIds:recipientIds
                                                  message:message];

            if (prepOp) {
                // prepOp → uploadOp → sendOp. The prep op swaps the payload in
                // place, so the attachment still needs uploading afterwards.
                //
                // Cancellation must cascade: if the user deletes the message
                // mid-compression the row is still a placeholder, and uploading
                // or sending it would ship the wrong payload.
                uploadAttachmentOperation.cascadesCancellationFromDependencies = YES;
                sendMessageOperation.cascadesCancellationFromDependencies = YES;

                [uploadAttachmentOperation addDependency:prepOp];
                [sendMessageOperation addDependency:uploadAttachmentOperation];
                [[self preparationQueueForMessage:message] addOperation:prepOp];
                [sendingQueue addOperation:uploadAttachmentOperation];

                OWSLogInfo(@"%@ message:%llu send step-2.2 预处理占位 (kind=%lu) prepOp → uploadOp → sendOp.",
                           self.logTag,
                           message.timestamp,
                           (unsigned long)placeholderStream.preprocessingKind);
            } else {
                [sendMessageOperation addDependency:uploadAttachmentOperation];
                [sendingQueue addOperation:uploadAttachmentOperation];

                OWSLogInfo(@"%@ message:%llu send step-2.2 创建并添加上传附件Operation为依赖.", self.logTag, message.timestamp);
            }
        }

        // Though we currently only ever expect at most one thumbnail, the proto data model
        // suggests this could change. The logic is intended to work with multiple, but
        // if we ever actually want to send multiple, we should do more testing.
        OWSAssertDebug(quotedThumbnailAttachments.count <= 1);
        for (TSAttachmentStream *thumbnailAttachment in quotedThumbnailAttachments) {
            OWSAssertDebug(message.quotedMessage);

            OWSUploadOperation *uploadQuoteThumbnailOperation =
                [[OWSUploadOperation alloc] initWithAttachmentId:thumbnailAttachment.uniqueId
                                                    recipientIds:desThread.recipientIdentifiers];
            // TODO put attachment uploads on a (lowly) concurrent queue
            [sendMessageOperation addDependency:uploadQuoteThumbnailOperation];
            [sendingQueue addOperation:uploadQuoteThumbnailOperation];
        }
        
        for (TSAttachment *forwardingAttachment in forwardingAttachments) {
            OWSAssertDebug(message.combinedForwardingMessage);

            // 转发本地已下载的附件
            if ([forwardingAttachment isKindOfClass:[TSAttachmentStream class]]) {
                OWSUploadOperation *uploadForwardingAttachmentOperation =
                    [[OWSUploadOperation alloc] initWithAttachmentId:forwardingAttachment.uniqueId
                                                        recipientIds:desThread.recipientIdentifiers];
                BOOL containsBot = desThread.recipientsContainsBot;
                
                uploadForwardingAttachmentOperation.rapidFileInfoBlock = ^(NSDictionary * _Nonnull info) {
                    if(info.count < 2){
                        OWSLogError(@"%@ get rapidFile info failed!", self.logTag);
                        OWSProdError(@"get rapidFile info failed!");
                        return;
                    }
                    NSError *error;
                    DTRapidFile *rapidFile = [MTLJSONAdapter modelOfClass:[DTRapidFile class]
                                                       fromJSONDictionary:info
                                                                    error:&error];
                    if(!error){
                        // TODO: check after update recipientsContainsBot
                        if(containsBot){
                            NSMutableArray *items = @[].mutableCopy;
                            if(message.combinedForwardingMessage.rapidFiles.count){
                                [items addObjectsFromArray:message.combinedForwardingMessage.rapidFiles];
                            }
                            [items addObject:rapidFile];
                            message.combinedForwardingMessage.rapidFiles = items.copy;
                        }
                        
                        NSMutableArray *items = @[].mutableCopy;
                        if(message.rapidFiles.count){
                            [items addObjectsFromArray:message.rapidFiles];
                        }
                        [items addObject:rapidFile];
                        message.rapidFiles = items.copy;
                        
                    }else{
                        OWSLogError(@"%@ rapidFile info to model failed!", self.logTag);
                        OWSProdError(@"rapidFile info to model failed!");
                    }
                };
                
                [sendMessageOperation addDependency:uploadForwardingAttachmentOperation];
                [sendingQueue addOperation:uploadForwardingAttachmentOperation];
                
            // 转发本地未下载的附件
            } else if ([forwardingAttachment isKindOfClass:[TSAttachmentPointer class]]) {
                DTUploadAttachmentPointerOperation *uploadOperation = [[DTUploadAttachmentPointerOperation alloc] initWithAttachmentId:forwardingAttachment.uniqueId recipientIds:desThread.recipientIdentifiers];
                
                BOOL containsBot = desThread.recipientsContainsBot;
                uploadOperation.rapidFileCallback = ^(DTRapidFile * _Nonnull rapidFile) {
                    // TODO: check after update recipientsContainsBot
                    if(containsBot){
                        NSMutableArray *items = @[].mutableCopy;
                        if(message.combinedForwardingMessage.rapidFiles.count){
                            [items addObjectsFromArray:message.combinedForwardingMessage.rapidFiles];
                        }
                        [items addObject:rapidFile];
                        message.combinedForwardingMessage.rapidFiles = items.copy;
                    }
                    
                    NSMutableArray *items = @[].mutableCopy;
                    if(message.rapidFiles.count){
                        [items addObjectsFromArray:message.rapidFiles];
                    }
                    [items addObject:rapidFile];
                    message.rapidFiles = items.copy;
                };
                
                [sendMessageOperation addDependency:uploadOperation];
                [sendingQueue addOperation:uploadOperation];
            }
            
            OWSLogInfo(@"%@ message:%llu send step-2.3 创建并添加转发消息附件上传Operation为依赖.", self.logTag, message.timestamp);
        }

        if (contactShareAvatarAttachment != nil) {
            OWSAssertDebug(message.contactShare);
            OWSUploadOperation *uploadAvatarOperation =
                [[OWSUploadOperation alloc] initWithAttachmentId:contactShareAvatarAttachment.uniqueId
                                                    recipientIds:desThread.recipientIdentifiers];

            // TODO put attachment uploads on a (lowly) concurrent queue
            [sendMessageOperation addDependency:uploadAvatarOperation];
            [sendingQueue addOperation:uploadAvatarOperation];
            
            OWSLogInfo(@"%@ message:%llu send step-2.3 创建并添加上传头像Operation为依赖.", self.logTag, message.timestamp);
        }

        [sendingQueue addOperation:sendMessageOperation];
    });
}

- (void)enqueueTemporaryAttachment:(id <DataSource> )dataSource
                       contentType:(NSString *)contentType
                         inMessage:(TSOutgoingMessage *)message
                           success:(void (^)(void))successHandler
                           failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(dataSource);

    void (^successWithDeleteHandler)(void) = ^() {
        successHandler();

        OWSLogDebug(@"%@ Removing successful temporary attachment message with attachment ids: %@",
            self.logTag,
            message.attachmentIds);
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [message anyRemoveWithTransaction:transaction];
            OWSLogInfo(@"%@ Removing successful temporary attachment message timestamp for sorting: %llu", self.logTag, message.timestampForSorting);
        });
    };

    void (^failureWithDeleteHandler)(NSError *error) = ^(NSError *error) {
        failureHandler(error);

        OWSLogDebug(@"%@ Removing failed temporary attachment message with attachment ids: %@",
            self.logTag,
            message.attachmentIds);
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [message anyRemoveWithTransaction:transaction];
            OWSLogInfo(@"%@ Removing failed temporary attachment message timestamp for sorting: %llu", self.logTag, message.timestampForSorting);
        });
    };

    [self enqueueAttachment:dataSource
                contentType:contentType
             sourceFilename:nil
                  inMessage:message
     preSendMessageCallBack:nil
                    success:successWithDeleteHandler
                    failure:failureWithDeleteHandler];
}

- (void)enqueueAttachment:(id <DataSource>)dataSource
              contentType:(NSString *)contentType
           sourceFilename:(nullable NSString *)sourceFilename
                inMessage:(TSOutgoingMessage *)message
                  preSendMessageCallBack:(nullable void (^)(TSOutgoingMessage *))preSendMessageCallBack
                  success:(void (^)(void))successHandler
                  failure:(void (^)(NSError *error))failureHandler
{
    [self enqueueAttachment:dataSource
                contentType:contentType
             sourceFilename:sourceFilename
          preprocessingKind:TSAttachmentPreprocessingKindNone
        preprocessingParams:nil
                  inMessage:message
     preSendMessageCallBack:preSendMessageCallBack
                    success:successHandler
                    failure:failureHandler];
}

- (void)enqueueAttachment:(id <DataSource>)dataSource
              contentType:(NSString *)contentType
           sourceFilename:(nullable NSString *)sourceFilename
        preprocessingKind:(TSAttachmentPreprocessingKind)preprocessingKind
      preprocessingParams:(nullable NSData *)preprocessingParams
                inMessage:(TSOutgoingMessage *)message
   preSendMessageCallBack:(nullable void (^)(TSOutgoingMessage *))preSendMessageCallBack
                  success:(void (^)(void))successHandler
                  failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(dataSource);

    void (^persistAttachment)(CGSize) = ^(CGSize sourceVideoPixelSize) {
        dispatch_async([OWSDispatch attachmentsQueue], ^{
        
            __block TSThread *thread = nil;
            if(message.uniqueThreadId){
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                    thread = [message threadWithTransaction:transaction];
                }];
            }
        
            TSAttachmentStream *attachmentStream =
                [[TSAttachmentStream alloc] initWithContentType:contentType
                                                      byteCount:(UInt64)dataSource.dataLength
                                                 sourceFilename:sourceFilename
                                                 albumMessageId:message.uniqueId
                                                        albumId:thread.uniqueId];
            if (message.isVoiceMessage) {
                attachmentStream.attachmentType = TSAttachmentTypeVoiceMessage;
            } else if (([MIMETypeUtil isImage:contentType] || [MIMETypeUtil isAnimated:contentType])
                       && [dataSource.data imageMetadataWithPath:nil mimeType:contentType].isAnimated) {
                // Mark animated images (GIF/animated-WebP/APNG) so receivers can preview without downloading.
                // Gate on image MIME first so a large video/file never loads its bytes just to check.
                attachmentStream.attachmentType = TSAttachmentTypeGif;
            }

            // Carry the placeholder intent onto the persisted row before the data is
            // written, so `enqueueMessage:` below dispatches the matching preparation
            // operation instead of taking the regular upload branch.
            if (preprocessingKind != TSAttachmentPreprocessingKindNone) {
                attachmentStream.preprocessingKind = preprocessingKind;
                attachmentStream.preprocessingParams = preprocessingParams;
            }

            if (![attachmentStream writeDataSource:dataSource]) {
                OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
                NSError *error = OWSErrorMakeWriteAttachmentDataError();
                return failureHandler(error);
            }

            // Stamp dimensions obtained before entering the serial attachment queue.
            // The cell-height pass can then size from the row without synchronously
            // loading AVAsset metadata or decoding a frame during snapshot rendering.
            if (sourceVideoPixelSize.width > 0 && sourceVideoPixelSize.height > 0) {
                attachmentStream.width = (UInt32)round(sourceVideoPixelSize.width);
                attachmentStream.height = (UInt32)round(sourceVideoPixelSize.height);
            }

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [attachmentStream anyInsertWithTransaction:transaction];
            });
            if(attachmentStream.uniqueId.length){
                NSMutableArray *newItems = @[].mutableCopy;
                if(message.attachmentIds.count){
                    [newItems addObjectsFromArray:message.attachmentIds];
                }
                [newItems addObject:attachmentStream.uniqueId];
                message.attachmentIds = newItems.copy;
            }
//        [message.attachmentIds addObject:attachmentStream.uniqueId];
//        if (sourceFilename) {
//            message.attachmentFilenameMap[attachmentStream.uniqueId] = sourceFilename;
//        }
            if (preSendMessageCallBack) {
                preSendMessageCallBack(message);
            }
            [self enqueueMessage:message success:successHandler failure:failureHandler];
        });
    };

    if (preprocessingKind == TSAttachmentPreprocessingKindVideoCompression) {
        // AVAsset track loading can block even though it does not decode a frame.
        // Do it independently per video so one slow metadata load cannot hold the
        // global serial attachment queue and delay every bubble behind it. Persistence
        // order may therefore follow metadata readiness rather than picker order; this
        // is intentional for the same independent-send behavior as preparation above.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSURL *_Nullable sourceURL = dataSource.dataUrl;
            CGSize pixelSize = sourceURL
                ? [OWSMessageSender videoPixelSizeForFileURL:sourceURL]
                : CGSizeZero;
            persistAttachment(pixelSize);
        });
    } else {
        persistAttachment(CGSizeZero);
    }
}

// 发送消息
- (void)sendMessageToService:(TSOutgoingMessage *)message
                     success:(void (^)(void))successHandler
                     failure:(RetryableFailureHandler)failureHandler
{
    dispatch_async([OWSDispatch sendingQueue], ^{
        
        if ([message isKindOfClass:[DTRecallOutgoingMessage class]]) {
            if (![message.recall isValidRecallMessageWithSource:[TSAccountManager localNumber]]) {
                //ignore recall.
                OWSLogWarn(@"%@ ignoring recall message.", self.logTag);
                NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
                [error setIsRetryable:NO];
                failureHandler(error);
                return;
            }
        }
        
        TSThread *_Nullable thread = message.threadWithSneakyTransaction;

        // TODO: It would be nice to combine the "contact" and "group" send logic here.
        if ([thread isKindOfClass:[TSContactThread class]] &&
            [((TSContactThread *)thread).contactIdentifier isEqualToString:[TSAccountManager localNumber]]) {
            // Send to self.
            OWSAssertDebug(message.recipientIds.count == 1);
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                // 3.1.3 逻辑调整
                // Mac 老版本在接收发送给 note 的同步消息时，会判断同步消息的 serverTimestamp 是否等于 0，
                // 若为 0 会去取 envelope 层的 systemShowTimestamp 作为 message 的 serverTimestamp，
                // iOS 在创建 outgoingMessage 时，默认 serverTimestamp = timestamp，
                // 为了保证 Mac 老本没有问题，发送的 outgoingMessage 的 servertimestamp 需要置为 0，
                // 但不能同步数据库❕❕❕，一旦同步数据库，消息会先展示在会话页最下面，在 servertimestamp 置为 0 后，会瞬间排到最上面，
                // 在接口返回正确的 serverTimestamp 并同步后，又瞬间展示在最下面。
                message.serverTimestamp = 0;
                message.sequenceId = 0;
                [self sendLocallyEncryptedMessageWithMessage:message
                                                      toNote:true
                                                    attempts:OWSMessageSenderRetryAttempts
                                                     success:successHandler
                                                     failure:failureHandler];
            });

            return;
        } else if ([thread isKindOfClass:[TSGroupThread class]]) {
            
            [self sendGroupMessageWithLabel:@"e2ee group message"
                                    message:message
                                     thread:(TSGroupThread *)thread
                                   attempts:OWSMessageSenderRetryAttempts
                                    success:successHandler
                                    failure:failureHandler];
            
            OWSLogInfo(@"%@ message:%llu send step-3 SEND e2ee Group MESSAGE.", self.logTag, message.timestamp);
        } else if ([thread isKindOfClass:[TSContactThread class]]
            || [message isKindOfClass:[OWSOutgoingSyncMessage class]]) {

            TSContactThread *contactThread = (TSContactThread *)thread;

            NSString *recipientContactId
                = ([message isKindOfClass:[OWSOutgoingSyncMessage class]] ? [TSAccountManager localNumber]
                                                                          : contactThread.contactIdentifier);

            // If we block a user, don't send 1:1 messages to them. The UI
            // should prevent this from occurring, but in some edge cases
            // you might, for example, have a pending outgoing message when
            // you block them.
            OWSAssertDebug(recipientContactId.length > 0);

            SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:recipientContactId];
            if (!recipient) {
                NSError *error;
                // possibly returns nil.
                recipient = [self.contactsUpdater synchronousLookup:recipientContactId error:&error];

                if (error) {
                    if (error.code == OWSErrorCodeNoSuchSignalRecipient) {
                        OWSLogWarn(@"%@ recipient contact not found", self.logTag);
                        if (recipient) {
                            [self unregisteredRecipient:recipient message:message thread:thread];
                        }
                    }

                    OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotFindContacts3]);
                    // No need to repeat trying to find a failure. Apart from repeatedly failing, it would also cause us
                    // to print redundant error messages.
                    [error setIsRetryable:NO];
                    failureHandler(error);
                    return;
                }
            }

            if (!recipient) {
                NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
                OWSLogWarn(@"%@ recipient contact still not found after attempting lookup.", self.logTag);
                // No need to repeat trying to find a failure. Apart from repeatedly failing, it would also cause us to
                // print redundant error messages.
                [error setIsRetryable:NO];
                failureHandler(error);
                return;
            }

            [self sendPrivateMessageWithLabel:@"e2ee private message"
                                      message:message
                                       thread:thread
                                    recipient:recipient
                                     attempts:OWSMessageSenderRetryAttempts
                                      success:successHandler
                                      failure:failureHandler];
            
            OWSLogInfo(@"%@ message:%llu send step-3 SEND e2ee 1on1 MESSAGE.", self.logTag, message.timestamp);
        } else {
            // Neither a group nor contact thread? This should never happen.
            OWSFailDebug(@"%@ Unknown message:%llu type: %@", self.logTag, message.timestamp, NSStringFromClass([message class]));

            NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
            [error setIsRetryable:NO];
            failureHandler(error);
        }
    });
}

- (void)unregisteredRecipient:(SignalRecipient *)recipient
                      message:(TSOutgoingMessage *)message
                       thread:(TSThread *)thread
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        
        if (thread.isGroupThread) {
            // Mark as "skipped" group members who no longer have signal accounts.
            [message updateWithSkippedRecipient:recipient.recipientId transaction:writeTransaction];
        }

        [recipient anyRemoveWithTransaction:writeTransaction];

        if (!thread.isGroupThread) {
            
            [[TSInfoMessage userNotRegisteredMessageInThread:thread recipientId:recipient.recipientId]
             anyInsertWithTransaction:writeTransaction];
        }
    });
}

- (void)permissionWasForbiddenRecipient:(SignalRecipient *)recipient
                         httpStatusCode:(NSInteger)statusCode
                                message:(TSOutgoingMessage *)message
                                 thread:(TSThread *)thread
{
    DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
        if (thread.isGroupThread) {
            // Mark as "skipped" group members who no longer have signal accounts.
            [message updateWithSkippedRecipient:recipient.recipientId transaction:writeTransaction];
        }
        
        [recipient anyRemoveWithTransaction:writeTransaction];
        
        //MARK: 同步消息发送失败后不再生成系统消息
        if ([message isKindOfClass:[OWSOutgoingSentMessageTranscript class]]) {
            OWSLogInfo(@"%@ OWSOutgoingSentMessageTranscript send failure, statusCode = %ld", self.logTag, statusCode);
            return;
        }
        
        if (statusCode == 430) {
            
            NSAttributedString *attributeText = [[NSAttributedString alloc] init];
            NSString *botName = TSConstants.officialBotName;
            NSString *msgText = [NSString stringWithFormat:Localized(@"CONTACT_DETAIL_COMM_TYPE_FORBIDDEN", @"Operation denied, please contact xxBot"), botName];
            NSMutableAttributedString *attributeTextM = [[NSMutableAttributedString alloc] initWithString:msgText];
            NSRange range = [msgText rangeOfString:botName];
            [attributeTextM addAttribute:NSForegroundColorAttributeName
                                  value:[UIColor colorWithRed:76.0/255 green:97.0/255 blue:140.0/255 alpha:1.0] range:range];
            attributeText = attributeTextM.copy;
            
            [self sendUserPermissionWasForbiddenedMessageWithThread:thread
                                                      customMessage:attributeText
                                                        transaction:writeTransaction];
        } else if (statusCode == 431) {
            
            NSString *msgText = Localized(@"CONTACT_DETAIL_COMM_TYPE_INACTIVE", @"Inactive（60天）用户会被进行“Inactive处理”");
            NSMutableAttributedString *attributeText = [[NSMutableAttributedString alloc] initWithString:msgText];
            [self sendUserPermissionWasForbiddenedMessageWithThread:thread
                                                      customMessage:attributeText
                                                        transaction:writeTransaction];
        }
        
    }));
}

- (void)sendUserPermissionWasForbiddenedMessageWithThread:(TSThread *)thread
                                            customMessage:(NSAttributedString *)customMessage
                                              transaction:(SDSAnyWriteTransaction *)transaction {
    
    
    uint64_t now = [DTTrustedClock clientStampMs];
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageUserPermissionForbidden
                                                                            timestamp:now
                                                                      serverTimestamp:0
                                                                             inThread:thread
                                                                        customMessage:customMessage];
    [infoMessage anyInsertWithTransaction:transaction];
}


@end

NS_ASSUME_NONNULL_END
