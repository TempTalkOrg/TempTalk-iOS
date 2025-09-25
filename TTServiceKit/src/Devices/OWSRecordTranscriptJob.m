//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSRecordTranscriptJob.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSIncomingSentMessageTranscript.h"
//#import "OWSPrimaryStorage+SessionStore.h"
//
#import "OWSReadReceiptManager.h"
#import "TSAttachmentPointer.h"
#import "TSInfoMessage.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import "TextSecureKitEnv.h"
#import "DTCombinedForwardingMessage.h"
#import "TSGroupThread.h"
#import "TSContactThread.h"
#import "TSAccountManager.h"
#import "DTRecallMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "DTRecallConfig.h"
#import "DTRecallMessagesJob.h"
#import "OWSMessageManager.h"
#import "DTReactionMessage.h"
#import "AppVersion.h"

#import <TTServiceKit/TTServiceKit-Swift.h>

#import "SSKCryptography.h"

#import "DTConversationPreviewManager.h"
#import "DTFetchThreadConfigAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSRecordTranscriptJob ()

@property (nonatomic, readonly) OWSReadReceiptManager *readReceiptManager;
@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, readonly) OWSIncomingSentMessageTranscript *incomingSentMessageTranscript;
@property (nonatomic, strong, nullable) InteractionFinder *interactionFinder;
@end

@implementation OWSRecordTranscriptJob

- (instancetype)initWithIncomingSentMessageTranscript:(OWSIncomingSentMessageTranscript *)incomingSentMessageTranscript
{
    return [self initWithIncomingSentMessageTranscript:incomingSentMessageTranscript
                                    readReceiptManager:OWSReadReceiptManager.sharedManager
                                       contactsManager:[TextSecureKitEnv sharedEnv].contactsManager];
}

- (instancetype)initWithIncomingSentMessageTranscript:(OWSIncomingSentMessageTranscript *)incomingSentMessageTranscript
                                   readReceiptManager:(OWSReadReceiptManager *)readReceiptManager
                                      contactsManager:(id<ContactsManagerProtocol>)contactsManager
{
    self = [super init];
    if (!self) {
        return self;
    }

    _incomingSentMessageTranscript = incomingSentMessageTranscript;
    _incomingSentMessageTranscript.thread.removedFromConversation = false;
    _readReceiptManager = readReceiptManager;
    _contactsManager = contactsManager;

    return self;
}

- (void)runWithAttachmentHandler:(void (^)(TSAttachmentStream *attachmentStream))attachmentHandler
                     envelopeJob:(OWSMessageContentJob *)job
                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    OWSIncomingSentMessageTranscript *transcript = self.incomingSentMessageTranscript;
    OWSLogDebug(@"%@ Recording transcript: %@", self.logTag, transcript);

    if (transcript.isEndSessionMessage) {
        OWSLogInfo(@"%@ EndSession was sent to recipient: %@.", self.logTag, transcript.recipientId);

        // Don't continue processing lest we print a bubble for the session reset.
        return;
    }
    
    if (transcript.attachmentPointerProtos.count > 0) {
        [transcript.attachmentPointerProtos enumerateObjectsUsingBlock:^(DSKProtoAttachmentPointer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self handleIncomingSentMessageWith:transcript envelopeJob:job index:idx attachmentHandler:attachmentHandler transaction:transaction];
        }];
    } else {
        [self handleIncomingSentMessageWith:transcript envelopeJob:job index:0 attachmentHandler:attachmentHandler transaction:transaction];
    }
}

- (void)handleIncomingSentMessageWith:(OWSIncomingSentMessageTranscript *)transcript
                          envelopeJob:(OWSMessageContentJob *)job
                                index:(NSUInteger)index
                    attachmentHandler:(void (^)(TSAttachmentStream *attachmentStream))attachmentHandler
                          transaction:(SDSAnyWriteTransaction *)transaction {
    
    
    /*
    BOOL duplicateEnvelope = [InteractionFinder existsIncomingMessageWithTimestamp:transcript.timestamp + index
                                                                           address:TSAccountManager.localNumber
                                                                    sourceDeviceId:transcript.sourceDeviceId
                                                                       transaction:transaction];
    if (duplicateEnvelope) {
        OWSLogInfo(@"%@ Ignoring previously received envelope from sync with timestamp: %llu",
            self.logTag,
                  transcript.timestamp + index);
        return;
    }
     */
    
    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    BOOL hasRecallMessage = [RecallFinder existsRecallMessageWithTimestamp:transcript.timestamp + index
                                                                  sourceId:localNumber
                                                            sourceDeviceId:transcript.sourceDeviceId
                                                               transaction:transaction];
    
    if(hasRecallMessage){
//        OWSProdFail(@"sync message hasRecallMessage");
        OWSLogInfo(@"%@ sync message hasRecallMessage from %@ with timestamp: %llu",
            self.logTag,
            [TSAccountManager localNumber],
            transcript.timestamp + index);
        return;
    }
    
    if(transcript.recall){
        OWSLogInfo(@"start handle recall sync message");
        OWSLogInfo(@"recall description:%@", transcript.recall.description);
        
        BOOL duplicateRecallMessage = [RecallFinder duplicateRecallMessageWithTimestamp:transcript.recall.source.timestamp
                                                                               sourceId:[TSAccountManager localNumber]
                                                                         sourceDeviceId:transcript.sourceDeviceId
                                                                            transaction:transaction];
        if(duplicateRecallMessage){
            OWSLogWarn(@"%@sync message has duplicate recallMessage from %@ with timestamp: %llu",
                      self.logTag,
                      [TSAccountManager localNumber],
                      transcript.timestamp + index);
            return;
        }
        
        TSOutgoingMessage *originMessage = [TSOutgoingMessage findSyncMessageWithTimestamp:transcript.recall.source.timestamp + index
                                                                               transaction:transaction];
        TSThread *thread = nil;
        if (transcript.groupId.length > 0) {
            thread = [TSGroupThread threadWithGroupId:transcript.groupId transaction:transaction];
        }else{
            thread = [TSContactThread getOrCreateThreadWithContactId:transcript.recipientId
                                                         transaction:transaction
                                                               relay:transcript.relay];
        }
        
        NSMutableAttributedString *customString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE_WITH_EDIT",nil), Localized(@"YOU",nil)]];
        NSAttributedString *editString = [[NSAttributedString alloc] initWithString:Localized(@"RE-EDIT_MESSAGE",nil)
                                                                         attributes:@{
                                             NSForegroundColorAttributeName:[UIColor colorWithRed:76.0/255 green:97.0/255 blue:140.0/255 alpha:1.0]
                                         }];
        [customString appendAttributedString:editString];
        
        
        NSString *previewSting = [NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE",nil), Localized(@"YOU",nil)];
        
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        BOOL timeoutForEdit = ((now - (transcript.timestamp + index)) > [DTRecallConfig fetchRecallConfig].editableInterval*1000);
        if(!originMessage.isTextMessage || timeoutForEdit){
            customString = [[NSMutableAttributedString alloc] initWithString:previewSting];
        }
        
        DTRecallMessage *recall = transcript.recall;
        
        TSInfoMessage *recallInfoMessage = [[TSInfoMessage alloc] initWithTimestamp:recall.source.timestamp + index
                                                                    serverTimestamp:transcript.serverTimestamp
                                                                           inThread:thread
                                                                   expiresInSeconds:transcript.expirationDuration
                                                                      customMessage:customString];
        recall.timestamp = transcript.timestamp + index;
        recallInfoMessage.serverTimestamp = originMessage.serverTimestamp?(originMessage.serverTimestamp + index):(recall.source.serverTimestamp + index);
        recallInfoMessage.recall = recall;
        recallInfoMessage.authorId = [TSAccountManager localNumber];
        recallInfoMessage.sourceDeviceId = transcript.sourceDeviceId;
        recallInfoMessage.recallPreview = previewSting;
        if(originMessage.isTextMessage && !timeoutForEdit){
            recallInfoMessage.editable = YES;
            recall.body = originMessage.body;
        }
        if(originMessage){
            recallInfoMessage.uniqueId = originMessage.uniqueId;
            if(!recallInfoMessage.grdbId && originMessage.grdbId){
                [recallInfoMessage updateRowId:originMessage.grdbId.longLongValue];
            }
        }
        
        if(job.envelopeProto.lastestMsgFlag){
            if(!recallInfoMessage.grdbId){
                [recallInfoMessage updateRowId:100];
            }
            OWSLogInfo(@"%@ handling lastestMsgFlag  timestamp: %llu", self.logTag, recallInfoMessage.timestamp);
            [thread updateWithLastMessage:recallInfoMessage isInserted:YES transaction:transaction];
        } else {
//            if(originMessage){
//                [originMessage anyRemoveWithTransaction:transaction];
//                OWSLogInfo(@"recalled message timestamp for sorting: %llu", originMessage.timestampForSorting);
//            }
            OWSLogInfo(@"%@ will insert recall message  timestamp: %llu", self.logTag, recallInfoMessage.timestamp);
            [recallInfoMessage anyUpsertWithTransaction:transaction];
            OWSLogInfo(@"%@ did insert recall message  timestamp: %llu", self.logTag, recallInfoMessage.timestamp);
        }
        
//        [[OWSDisappearingMessagesJob shared] startAnyExpirationForMessage:recallInfoMessage
//                                                      expirationStartedAt:transcript.expirationStartedAt
//                                                              transaction:transaction];
        
        [[DTRecallMessagesJob sharedJob] startIfNecessary];
        
        if(self.handleUnsupportedMessage){
            TSOutgoingMessage *oldMessage = [TSOutgoingMessage findSyncMessageWithTimestamp:transcript.timestamp + index
                                                                                   transaction:transaction];
            if(oldMessage){
                [oldMessage anyRemoveWithTransaction:transaction];
                OWSLogInfo(@"handleUnsupportedMessage delete message timestamp for sorting: %llu", oldMessage.timestampForSorting);
            }
        }
        
        // If the message arrives later than the archived notification, archive it directly
        // Messages are no longer stored in "model_TSInteraction" table
        // TODO: 目前message 没有合适的方式直接入归档消息的table，后面数据库优化后调整
        [[OWSArchivedMessageJob sharedJob] checkAndArchiveWithMessage:recallInfoMessage withThread:thread transaction:transaction];
       
        return;
    }
    
    OWSLogInfo(@"start handle other sync message");
    
    NSArray <DSKProtoAttachmentPointer *> *singleAttachmentProtos = nil;
    NSString *messageBody = nil;
    if (transcript.attachmentPointerProtos.count > 0) {
        singleAttachmentProtos = @[transcript.attachmentPointerProtos[index]];
        messageBody = (index == transcript.attachmentPointerProtos.count - 1) ? transcript.body : nil;
    } else {
        messageBody = transcript.body;
        singleAttachmentProtos = transcript.attachmentPointerProtos;
    }
    
    NSString *msgUniqueId = [TSInteraction generateUniqueIdWithAuthorId:[self.tsAccountManager localNumberWithTransaction:transaction] deviceId:transcript.sourceDeviceId timestamp:(transcript.timestamp+index)];
    NSArray<TSAttachmentPointer *> *pointers = [TSAttachmentPointer attachmentPointersFromProtos:singleAttachmentProtos relay:transcript.relay albumMessageId:msgUniqueId albumId:transcript.thread.uniqueId];
    OWSAttachmentsProcessor *attachmentsProcessor =
        [[OWSAttachmentsProcessor alloc] initWithAttachmentPointers:pointers transaction:transaction];
    
    
    if(transcript.dataMessage.card){
        return;
    }
        
    if(transcript.dataMessage.hasRequiredProtocolVersion){
        
        if(transcript.dataMessage.requiredProtocolVersion > kCurrentProtocolVersion){
            //unsupport
            messageBody = [NSString stringWithFormat:@"[%@]",Localized(@"UNSUPPORTED_MESSAGE_TIP",nil)];
            job.unsupportedFlag = YES;
            job.lastestHandleVersion = [AppVersion shared].currentAppReleaseVersion;
            [job anyInsertWithTransaction:transaction];
        }else{
            job.unsupportedFlag = NO;
        }
    }else{
        job.unsupportedFlag = NO;
    }

    // TODO group updates. Currently desktop doesn't support group updates, so not a problem yet.
    TSOutgoingMessage *outgoingMessage =
        [[TSOutgoingMessage alloc] initOutgoingMessageWithTimestamp:transcript.timestamp + index
                                                           inThread:transcript.thread
                                                        messageBody:messageBody
                                                          atPersons:transcript.atPersons
                                                           mentions:transcript.mentions
                                                      attachmentIds:[attachmentsProcessor.attachmentIds mutableCopy]
                                                   expiresInSeconds:transcript.expirationDuration
                                                    expireStartedAt:transcript.expirationStartedAt
                                                     isVoiceMessage:NO
                                                   groupMetaMessage:TSGroupMessageUnspecified
                                                      quotedMessage:transcript.quotedMessage
                                                  forwardingMessage:transcript.forwardingMessage
                                                       contactShare:transcript.contact];
    
    outgoingMessage.sourceDeviceId = transcript.sourceDeviceId;
    [outgoingMessage resetUniqueIdWithTransaction:transaction];
    outgoingMessage.serverTimestamp = transcript.serverTimestamp;
    outgoingMessage.sequenceId = transcript.sequenceId;
    outgoingMessage.notifySequenceId = transcript.notifySequenceId;
    // hotdata
    outgoingMessage.envelopSource = transcript.envelopSource;
    
    
    [pointers enumerateObjectsUsingBlock:^(TSAttachmentPointer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.albumMessageId = outgoingMessage.uniqueId;
    }];
    
    // 文件
    [self _handleOutingMessage:outgoingMessage withRapidFiles:transcript.rapidFiles];
    
    TSQuotedMessage *_Nullable quotedMessage = transcript.quotedMessage;
    
    TSThread *thread_t = transcript.thread;
    if (quotedMessage && quotedMessage.thumbnailAttachmentPointerId ) {
        if (![[OWSArchivedMessageJob sharedJob] needArchiveWithMessage:outgoingMessage withThread:thread_t]){
                    // We weren't able to derive a local thumbnail, so we'll fetch the referenced attachment.
                    TSAttachmentPointer *attachmentPointer =
                        [TSAttachmentPointer anyFetchAttachmentPointerWithUniqueId:quotedMessage.thumbnailAttachmentPointerId
                                                                       transaction:transaction];

                    if ([attachmentPointer isKindOfClass:[TSAttachmentPointer class]]) {
                        OWSAttachmentsProcessor *attachmentProcessor =
                            [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer];

                        OWSLogDebug(
                            @"%@ downloading thumbnail for transcript: %lu", self.logTag, (unsigned long)transcript.timestamp);
                        [attachmentProcessor fetchAttachmentsForMessage:outgoingMessage
                                                          forceDownload:NO
                                                            transaction:transaction
                                                                success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                                DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                        
                                        [outgoingMessage anyUpdateWithTransaction:transaction
                                                                            block:^(TSInteraction * instance) {
                                            if([instance isKindOfClass:[TSOutgoingMessage class]]){
                                                [((TSOutgoingMessage *)instance) setQuotedMessageThumbnailAttachmentStream:attachmentStream];
                                            }
                                        }];
                                });
                                
                            }
                                                                failure:^(NSError *_Nonnull error) {
                                OWSLogWarn(@"%@ failed to fetch thumbnail for transcript: %lu with error: %@",
                                    self.logTag,
                                    (unsigned long)transcript.timestamp,
                                    error);
                            }];
                    }
            } else {
                OWSLogInfo(@"Message need archive, so don't download attachment.");
            }

    }
    
    DTCombinedForwardingMessage *forwardMessage = transcript.forwardingMessage;
    [forwardMessage handleForwardingAttachmentsWithOrigionMessage:outgoingMessage transaction:transaction completion:nil];
    
    // TODO: check 2.5.9
    if (transcript.isExpirationTimerUpdate) {

        // early return to avoid saving an empty incoming message.
        OWSAssertDebug(transcript.body.length == 0);
        OWSAssertDebug(outgoingMessage.attachmentIds.count == 0);
        
        return;
    }

    DTReactionMessage *reaction = nil;
    if (transcript.dataMessage.reaction) {
        reaction = [DTReactionMessage reactionWithProto:transcript.dataMessage];
        DTRealSourceEntity *ownSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:outgoingMessage.timestamp sourceDevice:transcript.sourceDeviceId source:[TSAccountManager localNumber]];
        reaction.ownSource = ownSource;
        reaction.conversationId = transcript.thread.uniqueId;
        [reaction saveWithTransaction:transaction];
        
        if (self.handleUnsupportedMessage) {
            TSOutgoingMessage *oldMessage = [TSOutgoingMessage findSyncMessageWithTimestamp:transcript.timestamp + index
                                                                                transaction:transaction];
            if (oldMessage) {
                [oldMessage anyRemoveWithTransaction:transaction];
                OWSLogInfo(@"handleUnsupportedMessage delete message timestamp for sorting: %llu", oldMessage.timestampForSorting);
            }
        }
        return;
    }

    if (outgoingMessage.body.length < 1 &&
        outgoingMessage.attachmentIds.count < 1 &&
        !outgoingMessage.contactShare &&
        !forwardMessage &&
        !reaction) {
        OWSLogWarn(@"%@ Ignoring message transcript for empty message, timestamp:%llu.", self.logTag, outgoingMessage.timestamp);
        return;
    }
    
    if(self.handleUnsupportedMessage){
        TSOutgoingMessage *oldMessage = [TSOutgoingMessage findSyncMessageWithTimestamp:transcript.timestamp + index
                                                                               transaction:transaction];
        if(oldMessage){
            outgoingMessage.uniqueId = oldMessage.uniqueId;
        }
    }
    
    if(transcript.dataMessage.hasMessageMode && transcript.dataMessage.messageMode){
        DSKProtoDataMessageMessageMode messageModeType = transcript.dataMessage.messageMode;
        if (messageModeType == DSKProtoDataMessageMessageModeConfidential) {
            outgoingMessage.messageModeType = TSMessageModeTypeConfidential;
        } else {
            outgoingMessage.messageModeType = TSMessageModeTypeNormal;
        }
    }
    
    if(job.envelopeProto.lastestMsgFlag){
        if(!outgoingMessage.grdbId){
            [outgoingMessage updateRowId:100];
        }
        
        OWSLogInfo(@"%@ handling lastestMsgFlag  timestamp: %llu", self.logTag, outgoingMessage.timestamp);
        [transcript.thread updateWithLastMessage:outgoingMessage isInserted:YES transaction:transaction];
        
    }else{
        
        // outgoingMessage have not insert, change from updateWithTransaction to simple setting value
        [outgoingMessage updateWithWasSentFromLinkedDevice];
        OWSLogInfo(@"%@ will insert outgoingMessage message  timestamp: %llu", self.logTag, outgoingMessage.timestamp);
        [outgoingMessage anyInsertWithTransaction:transaction];
        OWSLogInfo(@"%@ did insert outgoingMessage message  timestamp: %llu", self.logTag, outgoingMessage.timestamp);
        
        //    [[OWSDisappearingMessagesJob shared] startAnyExpirationForMessage:outgoingMessage
        //                                                  expirationStartedAt:transcript.expirationStartedAt
        //                                                          transaction:transaction];
        
        [self.readReceiptManager applyEarlyReadReceiptsForOutgoingMessageFromLinkedDevice:outgoingMessage
                                                                              transaction:transaction];

        [attachmentsProcessor fetchAttachmentsForMessage:outgoingMessage
                                           forceDownload:NO
                                             transaction:transaction
                                                 success:attachmentHandler
                                                 failure:^(NSError *_Nonnull error) {
                                   OWSLogError(@"%@ failed to fetch transcripts attachments for message: %@",
                                       self.logTag,
                                       outgoingMessage);
                               }];
        

    }
    // If the message arrives later than the archived notification, archive it directly
    // Messages are no longer stored in "model_TSInteraction" table, but this situation needs to be completed in the subsequent database optimization process
    // TODO: 目前message 没有合适的方式直接入归档消息的table，后面数据库优化后调整
    [[OWSArchivedMessageJob sharedJob] checkAndArchiveWithMessage:outgoingMessage withThread:thread_t transaction:transaction];
    
}

- (void)_handleOutingMessage:(TSOutgoingMessage *)outgoingMessage withRapidFiles:(nullable NSArray *)rapidFiles {
    if (rapidFiles && rapidFiles.count) {
        
        NSMutableArray *files = @[].mutableCopy;
        [rapidFiles enumerateObjectsUsingBlock:^(DSKProtoRapidFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            DTRapidFile *rapidFileEntity = [[DTRapidFile alloc] init];
            rapidFileEntity.rapidHash = obj.rapidHash;
            rapidFileEntity.authorizedId = obj.authorizedID;
            [files addObject:rapidFileEntity];
        }];
        outgoingMessage.rapidFiles = files;
    }
}

@end

NS_ASSUME_NONNULL_END
