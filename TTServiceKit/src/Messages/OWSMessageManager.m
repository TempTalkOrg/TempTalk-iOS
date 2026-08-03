//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageManager.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import "ContactsManagerProtocol.h"
#import "SSKCryptography.h"
#import "MIMETypeUtil.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSString+SSK.h"
#import "NotificationsProtocol.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSContact.h"
#import "OWSDevice.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSIdentityManager.h"
#import "OWSIncomingSentMessageTranscript.h"
#import "OWSMessageSender.h"
#import "OWSMessageUtils.h"
////#import "OWSPrimaryStorage+SessionStore.h"
#import "OWSReadReceiptManager.h"
#import "OWSRecordTranscriptJob.h"
#import "OWSSyncConfigurationMessage.h"
#import "OWSSyncContactsMessage.h"
#import "OWSSyncGroupsMessage.h"
//#import "OWSSyncGroupsRequestMessage.h"
#import "ProfileManagerProtocol.h"
#import "TSAccountManager.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
//
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import "DTCombinedForwardingMessage.h"
#import "TextSecureKitEnv.h"
#import "DTUpdateGroupInfoAPI.h"
#import "DTAddMembersToAGroupAPI.h"
#import "DTRemoveMembersOfAGroupAPI.h"
#import "DTServerNotifyMessageHandler.h"
#import "DTRecallMessage.h"
#import "DTReactionMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTCardMessageEntity.h"
#import "NSData+messagePadding.h"
#import "AppVersion.h"
#import "DTMarkUnreadProcessor.h"
#import "DTConversationPreviewManager.h"
#import "DTMention.h"
#import "DTFetchThreadConfigAPI.h"

extern NSString *const OWSMimeTypeOversizeTextMessage;
extern const NSUInteger kOversizeTextMessageSizeThreshold;
extern const NSUInteger kOversizeTextMessageSizelength;
extern const NSUInteger kReceivedOversizeBodyLength;

NS_ASSUME_NONNULL_BEGIN


@interface OWSMessageManager ()

@property (nonatomic, readonly) id<CallMessageHandlerProtocol> callMessageHandler;
@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) OWSIdentityManager *identityManager;

@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;
@property (nonatomic, strong) DTAddMembersToAGroupAPI *addMembersToAGroupAPI;
@property (nonatomic, strong) DTRemoveMembersOfAGroupAPI *removeMembersOfAGroupAPI;

@property (nonatomic, strong) DTServerNotifyMessageHandler *notifyMessageHandler;
@property (nonatomic, strong) DTMarkUnreadProcessor *unreadProcessor;
@property (nonatomic, strong, nullable) InteractionFinder *interactionFinder;

// Serial queue for confidential placeholder creation to prevent race conditions
@property (nonatomic, strong) dispatch_queue_t confidentialPlaceholderQueue;

@end

#pragma mark -

@implementation OWSMessageManager

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI{
    if(!_updateGroupInfoAPI){
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}

- (DTAddMembersToAGroupAPI *)addMembersToAGroupAPI{
    if(!_addMembersToAGroupAPI){
        _addMembersToAGroupAPI = [DTAddMembersToAGroupAPI new];
    }
    return _addMembersToAGroupAPI;
}

- (DTRemoveMembersOfAGroupAPI *)removeMembersOfAGroupAPI{
    if(!_removeMembersOfAGroupAPI){
        _removeMembersOfAGroupAPI = [DTRemoveMembersOfAGroupAPI new];
    }
    return _removeMembersOfAGroupAPI;
}

- (DTServerNotifyMessageHandler *)notifyMessageHandler{
    if(!_notifyMessageHandler){
        _notifyMessageHandler = [DTServerNotifyMessageHandler new];
    }
    return _notifyMessageHandler;
}

- (DTMarkUnreadProcessor *)unreadProcessor {
    if (!_unreadProcessor) {
        _unreadProcessor = [DTMarkUnreadProcessor new];
    }
    return _unreadProcessor;
}


+ (instancetype)sharedManager
{
    static OWSMessageManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    id<ContactsManagerProtocol> contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
    id<CallMessageHandlerProtocol> callMessageHandler = [TextSecureKitEnv sharedEnv].callMessageHandler;
    OWSIdentityManager *identityManager = [OWSIdentityManager sharedManager];
    OWSMessageSender *messageSender = [TextSecureKitEnv sharedEnv].messageSender;
    
    
    return [self initWithCallMessageHandler:callMessageHandler
                            contactsManager:contactsManager
                            identityManager:identityManager
                              messageSender:messageSender];
}

- (instancetype)initWithCallMessageHandler:(id<CallMessageHandlerProtocol>)callMessageHandler
                           contactsManager:(id<ContactsManagerProtocol>)contactsManager
                           identityManager:(OWSIdentityManager *)identityManager
                             messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];

    if (!self) {
        return self;
    }

    _callMessageHandler = callMessageHandler;
    _contactsManager = contactsManager;
    _identityManager = identityManager;
    _messageSender = messageSender;
    _confidentialPlaceholderQueue = dispatch_queue_create("com.temptalk.confidentialPlaceholder", DISPATCH_QUEUE_SERIAL);

    OWSSingletonAssert();


    //    if (CurrentAppContext().isMainApp) {
    //        [AppReadiness runNowOrWhenAppIsReady:^{
    //            [self startObserving];
    //        }];
    //    }

    return self;
}


#pragma mark -

/*
 - (void)startObserving
 {
 [self.databaseStorage appendDatabaseChangeDelegate:self];
 
 [[NSNotificationCenter defaultCenter]
 addObserver:self
 selector:@selector(databaseDidCommitInteractionChange)
 name:DatabaseChangeObserver.databaseDidCommitInteractionChangeNotification
 object:nil];
 }
 
 - (void)databaseDidCommitInteractionChange
 {
 OWSAssertIsOnMainThread();
 OWSLogInfo(@"");
 
 // Only the main app needs to update the badge count.
 // When app is active, this will occur in response to database changes
 // that affect interactions (see below).
 // When app is not active, we should update badge count whenever
 // changes to interactions are committed.
 if (CurrentAppContext().isMainApp && !CurrentAppContext().isMainAppAndActive) {
 [AppReadiness runNowOrWhenAppIsReady:^{
 [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
 }];
 }
 }
 
 #pragma mark - DatabaseChangeDelegate
 
 - (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(AppReadiness.isAppReady);
 
 if (!databaseChanges.didUpdateInteractions) {
 return;
 }
 
 [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
 }
 
 - (void)databaseChangesDidUpdateExternally
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(AppReadiness.isAppReady);
 
 [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
 }
 
 - (void)databaseChangesDidReset
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(AppReadiness.isAppReady);
 
 [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
 }
 
 */

#pragma mark - Blocking

- (BOOL)isEnvelopeBlocked:(DSKProtoEnvelope *)envelope
{
    OWSAssertDebug(envelope);
    
    return [self.blockingManager isRecipientIdBlocked:envelope.source];
}

#pragma mark - message handling

- (void)processEnvelopeJob:(OWSMessageContentJob *_Nullable)job
                  envelope:(DSKProtoEnvelope *)envelope
             plaintextData:(NSData *_Nullable)plaintextData
        hotDataDestination:(NSString *_Nullable)hotDataDestination
               transaction:(SDSAnyWriteTransaction *)writeTransaction
{
    OWSAssertDebug(writeTransaction);
    OWSAssertDebug([TSAccountManager isRegistered]);
    
    OWSLogInfo(@"===== %@ handling decrypted envelope: %@", self.logTag, [self descriptionForEnvelope:envelope]);
    
    if (!envelope.source.isStructurallyValidE164 &&
        envelope.unwrappedType != DSKProtoEnvelopeTypeNotify) {
        OWSProdFail([OWSAnalyticsEvents messageIncomingEnvelopeHasInvalidSource]);
        OWSLogVerbose(
                      @"%@ incoming envelope has invalid source: %@", self.logTag, [self descriptionForEnvelope:envelope]);
        OWSFailDebug(@"%@ incoming envelope has invalid source", self.logTag);
        return;
    }
    
    OWSAssertDebug(envelope.source.length > 0);
    //    OWSAssertDebug(![self isEnvelopeBlocked:envelope]);
    
    switch (envelope.unwrappedType) {
        case DSKProtoEnvelopeTypeCiphertext:
        case DSKProtoEnvelopeTypePrekeyBundle:
        case DSKProtoEnvelopeTypePlaintext:
        case DSKProtoEnvelopeTypeEtoee:
            if (plaintextData) {
                [self handleEnvelopeJob:job
                               envelope:envelope
                          plaintextData:plaintextData
                     hotDataDestination:hotDataDestination
                            transaction:writeTransaction];
            } else {
                OWSProdFail([OWSAnalyticsEvents messageMissingDecryptedDataForEnvelope]);
                OWSFailDebug(
                             @"%@ missing decrypted data for envelope: %@", self.logTag, [self descriptionForEnvelope:envelope]);
            }
            break;
        case DSKProtoEnvelopeTypeReceipt:
            OWSAssertDebug(!plaintextData);
            //            [self handleDeliveryReceipt:envelope transaction:transaction];
            break;
            // Other messages are just dismissed for now.
        case DSKProtoEnvelopeTypeKeyExchange:
            OWSLogWarn(@"Received Key Exchange Message, not supported");
            break;
        case DSKProtoEnvelopeTypeNotify:
        {
            NSData *plaintextData = envelope.content;
            if(plaintextData.length){
                @try {
                    [self.notifyMessageHandler handleNotifyDataWithEnvelope:envelope
                                                              plaintextData:plaintextData
                                                                transaction:writeTransaction];
                } @catch (NSException *exception) {
                    OWSLogError(@"handle_notify_data_with_envelope_error exception: %@", exception);
                }
            }else{
                OWSProdFail([OWSAnalyticsEvents messageMissingGroupUpdateDataForEnvelope]);
                OWSFailDebug(
                             @"%@ missing decrypted data for envelope: %@", self.logTag, [self descriptionForEnvelope:envelope]);
            }
        }
            break;
        case DSKProtoEnvelopeTypeUnknown:
            OWSLogWarn(@"Received an unknown message type");
            break;
        default:
            OWSLogWarn(@"Received unhandled envelope type: %d", (int)envelope.unwrappedType);
            break;
    }
}

/*
 
 - (void)handleDeliveryReceipt:(DSKProtoEnvelope *)envelope
 transaction:(SDSAnyWriteTransaction *)transaction
 {
 OWSAssertDebug(envelope);
 OWSAssertDebug(transaction);
 
 // Old-style delivery notices don't include a "delivery timestamp".
 [self processDeliveryReceiptsFromRecipientId:envelope.source
 sentTimestamps:@[
 @(envelope.timestamp),
 ]
 deliveryTimestamp:nil
 transaction:transaction];
 }
 
 // deliveryTimestamp is an optional parameter, since legacy
 // delivery receipts don't have a "delivery timestamp".  Those
 // messages repurpose the "timestamp" field to indicate when the
 // corresponding message was originally sent.
 - (void)processDeliveryReceiptsFromRecipientId:(NSString *)recipientId
 sentTimestamps:(NSArray<NSNumber *> *)sentTimestamps
 deliveryTimestamp:(NSNumber *_Nullable)deliveryTimestamp
 transaction:(SDSAnyWriteTransaction *)transaction
 {
 OWSAssertDebug(recipientId);
 OWSAssertDebug(sentTimestamps);
 OWSAssertDebug(transaction);
 
 for (NSNumber *nsTimestamp in sentTimestamps) {
 uint64_t timestamp = [nsTimestamp unsignedLongLongValue];
 
 NSArray<TSOutgoingMessage *> *messages
 = (NSArray<TSOutgoingMessage *> *)[TSInteraction ydb_interactionsWithTimestamp:timestamp
 ofClass:[TSOutgoingMessage class]
 withTransaction:transaction];
 if (messages.count < 1) {
 // The service sends delivery receipts for "unpersisted" messages
 // like group updates, so these errors are expected to a certain extent.
 //
 // TODO: persist "early" delivery receipts.
 OWSLogInfo(@"%@ Missing message for delivery receipt: %llu", self.logTag, timestamp);
 } else {
 if (messages.count > 1) {
 OWSLogInfo(@"%@ More than one message (%zd) for delivery receipt: %llu",
 self.logTag,
 messages.count,
 timestamp);
 }
 for (TSOutgoingMessage *outgoingMessage in messages) {
 [outgoingMessage updateWithDeliveredRecipient:recipientId
 deliveryTimestamp:deliveryTimestamp
 transaction:transaction];
 }
 }
 }
 }
 
 */

- (void)handleEnvelopeJob:(OWSMessageContentJob *)job
                 envelope:(DSKProtoEnvelope *)envelope
            plaintextData:(NSData *)plaintextData
       hotDataDestination:(NSString *_Nullable)hotDataDestination
              transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(plaintextData);
    OWSAssertDebug(transaction);
    OWSAssertDebug(envelope.hasTimestamp && envelope.timestamp > 0);
    OWSAssertDebug(envelope.hasSource && envelope.source.length > 0);
    OWSAssertDebug(envelope.hasSourceDevice && envelope.sourceDevice > 0);
    
    if (envelope.hasContent) {
        
        
        
        @try {
            NSError *error;
            DSKProtoContent *content = [[DSKProtoContent alloc] initWithSerializedData:plaintextData error:&error];
            OWSLogInfo(@"%@ handling content: <Content: %@>", self.logTag, [self descriptionForContent:content]);
            if (error) {
                OWSLogError(@"init serialized data error: %@.", error);
            }
            
            if (content.syncMessage) {
                [self handleIncomingEnvelopeJob:job
                                       envelope:envelope
                                withSyncMessage:content.syncMessage
                                    transaction:transaction];
                
                [[OWSDeviceManager sharedManager] setHasReceivedSyncMessageWithTransaction:transaction];
            } else if (content.dataMessage) {
                //if (body.length == 0 && attachmentIds.count < 1 && !forwardingMessage) {
                if (envelope.hasSource) {
                    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
                    
                    //DSKProtoEnvelopeMsgTypeMsgScheduleNormal 这个类型和hotData数据的同步消息的处理逻辑一致, 热数据的情况下不会填充number
                    NSString *extraNumber =  envelope.msgExtra.conversationID.number;
                    if (envelope.hasMsgType && envelope.unwrappedMsgType == DSKProtoEnvelopeMsgTypeMsgScheduleNormal && DTParamsUtils.validateString(extraNumber)) {
                        hotDataDestination = extraNumber;
                    }
                    
                    // sync group message
                    if ([localNumber isEqualToString:envelope.source] &&
                        (DTParamsUtils.validateString(hotDataDestination) || content.dataMessage.group)) {
                        
                        [self handleHotDataIncomingEnvelopeJob:job
                                                      envelope:envelope
                                               withDataMessage:content.dataMessage
                                            hotDataDestination:hotDataDestination
                                                   transaction:transaction];
                    } else {
                        
                        [self handleIncomingEnvelopeJob:job envelope:envelope withDataMessage:content.dataMessage transaction:transaction];
                    }
                    
                } else {
                    
                    [self handleIncomingEnvelopeJob:job envelope:envelope withDataMessage:content.dataMessage transaction:transaction];
                }
            } else if (content.callMessage) {
                [self handleIncomingEnvelope:envelope withCallMessage:content.callMessage transaction:transaction];
            } else if (content.nullMessage) {
                OWSLogInfo(@"%@ Received null message.", self.logTag);
            } else if (content.receiptMessage) {
                [self handleIncomingEnvelope:envelope withReceiptMessage:content.receiptMessage transaction:transaction];
            }  else if (content.notifyMessage) {
                [self handleIncomingEnvelopeJob:job envelope:envelope withNotifyMessage:content.notifyMessage transaction:transaction];
                OWSLogInfo(@"%@ received notifyMessage", self.logTag);
            } else if (content.groupKeyMessage) {
                [DTGroupKeyMessageHandler.shared handleGroupKeyMessage:content.groupKeyMessage transaction:transaction];
            } else if (content.activityNotice) {
                [self handleIncomingEnvelope:envelope
                        withActivityNotice:content.activityNotice
                                transaction:transaction];
            } else if (content.forwardNotice) {
                [self handleIncomingEnvelope:envelope
                           withForwardNotice:content.forwardNotice
                                 transaction:transaction];
            } else {
                OWSLogWarn(@"%@ Ignoring envelope. Content with no known payload", self.logTag);
            }
        } @catch (NSException *exception) {
            OWSLogError(@"%@ envelop:%@, parse content exception:%@.", self.logTag, [self descriptionForEnvelope:envelope], exception.name);
        }
        
    } else {
        OWSProdInfoWEnvelope([OWSAnalyticsEvents messageManagerErrorEnvelopeNoActionablePayload], envelope);
    }
}


- (void)handleIncomingEnvelopeJob:(OWSMessageContentJob *)job
                         envelope:(DSKProtoEnvelope *)envelope
                  withDataMessage:(DSKProtoDataMessage *)dataMessage
                      transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    
    if (dataMessage.hasTimestamp) {
        if (dataMessage.timestamp <= 0) {
            OWSLogError(@"%@ Ignoring message with invalid data message timestamp: %@", self.logTag, envelope.source);
            return;
        }
        // This prevents replay attacks by the service.
        if (dataMessage.timestamp != envelope.timestamp) {
            OWSLogError(
                        @"%@ Ignoring message with non-matching data message timestamp: %@", self.logTag, envelope.source);
            return;
        }
    }
    
    if(dataMessage.body.length > kReceivedOversizeBodyLength) {
        OWSLogError(@"%@ DataMessage body exceeds maximum length. Ignoring message with invalid data message timestamp: %@", self.logTag, envelope.source);
        return;
    }
    
    if (dataMessage.group) {
        [DTGroupKeyMessageHandler.shared handleFallbackGroupRootKeyWithGroupContext:dataMessage.group transaction:transaction];
    }

    if (dataMessage.hasProfileKey) {
        NSData *profileKey = [dataMessage profileKey];
        NSString *recipientId = envelope.source;
        if (profileKey.length == kAES256_KeyByteLength) {
            [self.profileManager setProfileKeyData:profileKey forRecipientId:recipientId transaction:transaction];
        } else {
            OWSFailDebug(
                         @"Unexpected profile key length:%lu on message from:%@", (unsigned long)profileKey.length, recipientId);
        }
    }
    
    if (dataMessage.group) {
        TSGroupThread *_Nullable groupThread =
        [TSGroupThread threadWithGroupId:dataMessage.group.id transaction:transaction];
        
        if (!groupThread || (groupThread.groupModel && groupThread.groupModel.version == 0)) {
            // Unknown group.
            if (dataMessage.group.unwrappedType == DSKProtoGroupContextTypeUpdate) {
                // Accept group updates for unknown groups.
            } else if (dataMessage.group.unwrappedType == DSKProtoGroupContextTypeDeliver) {
                //                [self sendGroupInfoRequest:dataMessage.group.id envelope:envelope transaction:transaction];
                @try {
                    [self.notifyMessageHandler.groupUpdateMessageProcessor requestGroupInfoWithGroupId:dataMessage.group.id
                                                                                         targetVersion:0
                                                                                     needSystemMessage:NO
                                                                                              generate:false
                                                                                              envelope:envelope
                                                                                           transaction:transaction
                                                                                            completion:^(SDSAnyWriteTransaction * transaction) {
                        //                        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
                        //                            [self handleIncomingEnvelopeJob:job envelope:envelope withDataMessage:dataMessage transaction:writeTransaction.transitional_yapWriteTransaction];
                        //                        }];
                    }];
                    groupThread = [TSGroupThread getOrCreateThreadWithGroupId:dataMessage.group.id transaction:transaction];
                    if(!groupThread){
                        OWSProdError(@"Create group thread exception!");
                    }
                } @catch (NSException *exception) {
                    NSString *errorInfo = exception.description;
                    if(![errorInfo isKindOfClass:[NSString class]]){
                        errorInfo = @"requestGroupInfoWithGroupId";
                    }
                    OWSProdError(errorInfo);
                }
                
            } else {
                OWSLogInfo(@"%@ Ignoring group message for unknown group from: %@", self.logTag, envelope.source);
                return;
            }
        }
    }
    
    if ((dataMessage.flags & DSKProtoDataMessageFlagsEndSession) != 0) {
        //        [self handleEndSessionMessageWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    } else if ((dataMessage.flags & DSKProtoDataMessageFlagsExpirationTimerUpdate) != 0) {
        [self handleExpirationTimerUpdateMessageWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    } else if ((dataMessage.flags & DSKProtoDataMessageFlagsProfileKeyUpdate) != 0) {
        [self handleProfileKeyMessageWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    } else if (dataMessage.attachments.count > 0) {
        [self handleReceivedMediaWithEnvelopeJob:job envelope:envelope dataMessage:dataMessage transaction:transaction];
    } else {
        [self handleReceivedTextMessageWithEnvelopeJob:job envelope:envelope timestamp:envelope.timestamp dataMessage:dataMessage idx:0 transaction:transaction];
        
        //        if ([self isDataMessageGroupAvatarUpdate:dataMessage]) {
        //            OWSLogVerbose(@"%@ Data message had group avatar attachment", self.logTag);
        //            [self handleReceivedGroupAvatarUpdateWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
        //        }
    }
}

/*
 - (void)sendGroupInfoRequest:(NSData *)groupId
 envelope:(DSKProtoEnvelope *)envelope
 transaction:(SDSAnyWriteTransaction *)transaction
 {
 OWSAssertDebug(groupId.length > 0);
 OWSAssertDebug(envelope);
 OWSAssertDebug(transaction);
 
 if (groupId.length < 1) {
 return;
 }
 
 // FIXME: https://github.com/signalapp/Signal-iOS/issues/1340
 OWSLogInfo(@"%@ Sending group info request: %@", self.logTag, envelopeAddress(envelope));
 
 NSString *recipientId = envelope.source;
 
 TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:recipientId transaction:transaction];
 
 OWSSyncGroupsRequestMessage *syncGroupsRequestMessage =
 [[OWSSyncGroupsRequestMessage alloc] initWithThread:thread groupId:groupId];
 [self.messageSender enqueueMessage:syncGroupsRequestMessage
 success:^{
 OWSLogWarn(@"%@ Successfully sent Request Group Info message.", self.logTag);
 }
 failure:^(NSError *error) {
 OWSLogError(@"%@ Failed to send Request Group Info message with error: %@", self.logTag, error);
 }];
 }
 */

- (id<ProfileManagerProtocol>)profileManager
{
    return [TextSecureKitEnv sharedEnv].profileManager;
}

//处理已读回执
- (void)handleIncomingEnvelope:(DSKProtoEnvelope *)envelope
            withReceiptMessage:(DSKProtoReceiptMessage *)receiptMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(receiptMessage);
    OWSAssertDebug(transaction);
    
    switch (receiptMessage.unwrappedType) {
        case DSKProtoReceiptMessageTypeDelivery: // 废弃
            OWSLogVerbose(@"%@ Processing receipt message with delivery receipts.", self.logTag);
            //            [self processDeliveryReceiptsFromRecipientId:envelope.source
            //                                          sentTimestamps:sentTimestamps
            //                                       deliveryTimestamp:@(envelope.timestamp)
            //                                             transaction:transaction];
            return;
        case DSKProtoReceiptMessageTypeRead:
        {
            OWSLogVerbose(@"%@ Processing receipt message with read receipts.", self.logTag);
            // 2.4.0 开始有 ReadPosition
            
            NSArray *messageTimestamps = receiptMessage.timestamp;
//            NSMutableArray<NSNumber *> *sentTimestamps = [NSMutableArray new];
//            for (int i = 0; i < messageTimestamps.count; i++) {
//                UInt64 timestamp = [messageTimestamps uint64AtIndex:i];
//                [sentTimestamps addObject:@(timestamp)];
//            }
            
            NSNumber *maxTimestamp = [messageTimestamps valueForKeyPath:@"@max.self"];
            NSError *error = nil;
            NSArray<TSOutgoingMessage *> *outgoingmessages = (NSArray<TSOutgoingMessage *> *)[InteractionFinder interactionsWithTimestamp:maxTimestamp.unsignedLongValue filter:^BOOL(TSInteraction * interaction) {
                return ([interaction isKindOfClass:[TSOutgoingMessage class]]);
            } transaction:transaction error:&error];

            if (error != nil) {
                OWSLogError(@"Failed to query outgoing messages: %@", error);
                return;
            }

            TSOutgoingMessage *outgoingmessage = outgoingmessages.firstObject;
            
            if (receiptMessage.readPosition) {
                DSKProtoReadPosition *readPositionProto = receiptMessage.readPosition;
                DTReadPositionEntity *readPosition = [DTReadPositionEntity readPostionEntityWithProto:readPositionProto];
                
                if(readPosition.maxServerTime <=0 || readPosition.readAt <= 0) {
                    OWSProdError(@"ReceiptMessage, invalid readPosition: maxServerTime or readAt <= 0!")
                    return;
                }
                
                TSThread *thread = [self threadForEnvelope:envelope receiptMessage:receiptMessage transaction:transaction];
                OWSLogInfo(@"001 handleIncoming  will save readPosition:%@", readPosition);
                TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                                       recipientId:envelope.source
                                                                                                      readPosition:readPosition];
                [messageReadPosition updateOrInsertWithTransaction:transaction];
                
                if(outgoingmessage.grdbId){
                    [self.databaseStorage touchInteraction:outgoingmessage
                                             shouldReindex:NO
                                               transaction:transaction];
                }
                
            } else {
                
                if(outgoingmessage) {
                    TSThread *thread = [TSThread anyFetchWithUniqueId:outgoingmessage.uniqueThreadId
                                                          transaction:transaction];
                    NSData *groupId = nil;
                    if(thread.isGroupThread){
                        groupId = ((TSGroupThread *)thread).groupModel.groupId;
                    }
                    // TODO: maxSequenceId
                    DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                                readAt:[NSDate ows_millisecondTimeStamp]
                                                                                         maxServerTime:outgoingmessage.timestampForSorting
                                                                                      notifySequenceId:outgoingmessage.notifySequenceId
                                                                                         maxSequenceId:outgoingmessage.sequenceId];
                    OWSLogInfo(@"002 handleIncoming  will save readPosition:%@", readPosition);
                    TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                                           recipientId:envelope.source
                                                                                                          readPosition:readPosition];
                    [messageReadPosition updateOrInsertWithTransaction:transaction];
                    
                    [[OWSReadReceiptManager sharedManager] temporarySaveNeedToUpdateReadPositionMessage:messageReadPosition message:outgoingmessage];
                    
                    if(outgoingmessage.grdbId){
                        [self.databaseStorage touchInteraction:outgoingmessage
                                                 shouldReindex:NO
                                                   transaction:transaction];
                    }
                    
                } else {
                    // TODO: maxSequenceId
                    DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:[NSData data]
                                                                                                readAt:[NSDate ows_millisecondTimeStamp]
                                                                                         maxServerTime:maxTimestamp.unsignedLongValue
                                                                                      notifySequenceId:0
                                                                                         maxSequenceId:0];
                    OWSLogInfo(@"003 handleIncoming  will save readPosition:%@", readPosition);
                    TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:@"0"
                                                                                                           recipientId:envelope.source
                                                                                                          readPosition:readPosition];
                    [messageReadPosition updateOrInsertWithTransaction:transaction];
                    
                }
                
            }

            // Handle confidential message deletion
            if (outgoingmessage && outgoingmessage.isConfidentialMessage && receiptMessage.messageMode == DSKProtoDataMessageMessageModeConfidential) {
                // Use serial queue to prevent race conditions
                NSString *messageId = outgoingmessage.uniqueId;
                uint64_t messageTimestamp = outgoingmessage.timestamp;
                NSString *threadId = outgoingmessage.uniqueThreadId;

                dispatch_async(self.confidentialPlaceholderQueue, ^{
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        // Re-fetch the outgoing message to ensure it still exists
                        TSOutgoingMessage *currentMessage = [TSOutgoingMessage anyFetchWithUniqueId:messageId
                                                                                         transaction:transaction];

                        if (!currentMessage || !currentMessage.isConfidentialMessage) {
                            return;
                        }

                        TSThread *thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
                        if (!thread) {
                            return;
                        }

                        // Use timestamp + 1 to avoid uniqueId conflict with outgoingMessage
                        TSInfoMessage *placeholder = [[TSInfoMessage alloc]
                            initWithTimestamp:messageTimestamp + 1
                            inThread:thread
                            messageType:TSInfoMessageConfidentialViewed
                            expiresInSeconds:0
                            customMessage:nil];

                        placeholder.shouldAffectThreadSorting = YES;

                        [placeholder anyInsertWithTransaction:transaction];
                        [currentMessage anyRemoveWithTransaction:transaction];
                    });
                });
            }
        }
            
            break;
        default:
            OWSLogInfo(@"%@ Ignoring receipt message of unknown type: %d.", self.logTag, (int)receiptMessage.unwrappedType);
            return;
    }
}

- (void)handleIncomingEnvelopeJob:(OWSMessageContentJob *)job
                         envelope:(DSKProtoEnvelope *)envelope
                  withNotifyMessage:(DSKProtoNotifyMessage *)notifyMessage
                      transaction:(SDSAnyWriteTransaction *)transaction {
    OWSLogInfo(@"%@ received notifyMessage", self.logTag);
    OWSAssertDebug(envelope);
    OWSAssertDebug(notifyMessage);
    [self handleClientNotifyWithEnvelopeJob:job envelope:envelope message:notifyMessage transaction:transaction];
}

- (void)handleIncomingEnvelope:(DSKProtoEnvelope *)envelope
               withCallMessage:(DSKProtoCallMessage *)callMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(callMessage);
    
    [[DTCallMessageManager shared] handleIncomingWithEnvelope:envelope
                                                  callMessage:callMessage
                                                  transaction:transaction];
}

- (void)handleReceivedGroupAvatarUpdateWithEnvelope:(DSKProtoEnvelope *)envelope
                                        dataMessage:(DSKProtoDataMessage *)dataMessage
                                        transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    
    TSGroupThread *_Nullable groupThread =
    [TSGroupThread threadWithGroupId:dataMessage.group.id transaction:transaction];
    if (!groupThread) {
        OWSFailDebug(@"%@ Missing group for group avatar update", self.logTag);
        return;
    }
    
    OWSAssertDebug(groupThread);
    
    // 群头像不需要关联消息和会话
    NSArray<TSAttachmentPointer *> *pointers = [TSAttachmentPointer attachmentPointersFromProtos:@[ dataMessage.group.avatar ] relay:envelope.relay albumMessageId:nil albumId:nil];
    
    OWSAttachmentsProcessor *attachmentsProcessor =
    [[OWSAttachmentsProcessor alloc] initWithAttachmentPointers:pointers transaction:transaction];
    
    if (!attachmentsProcessor.hasSupportedAttachments) {
        OWSLogWarn(@"%@ received unsupported group avatar envelope", self.logTag);
        return;
    }
    [attachmentsProcessor fetchAttachmentsForMessage:nil
                                       forceDownload:NO
                                         transaction:transaction
                                             success:^(TSAttachmentStream *attachmentStream) {
        [groupThread updateAvatarWithAttachmentStream:attachmentStream];
        
    }
                                             failure:^(NSError *error) {
        OWSLogError(@"%@ failed to fetch attachments for group avatar sent at: %llu. with error: %@",
                    self.logTag,
                    envelope.timestamp,
                    error);
    }];
}

- (void)handleReceivedMediaWithEnvelopeJob:(OWSMessageContentJob *)job
                                  envelope:(DSKProtoEnvelope *)envelope
                               dataMessage:(DSKProtoDataMessage *)dataMessage
                               transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    
    TSThread *_Nullable thread = [self threadForEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    if (!thread) {
        OWSFailDebug(@"%@ ignoring media message for unknown group.", self.logTag);
        return;
    }
    
    [dataMessage.attachments enumerateObjectsUsingBlock:^(DSKProtoAttachmentPointer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        UInt64 timestamp = envelope.timestamp + idx;
        
        TSAttachmentPointer *pointer = [TSAttachmentPointer attachmentPointerFromProto:obj relay:envelope.relay albumMessageId:nil albumId:thread.uniqueId];
        
        TSIncomingMessage *_Nullable createdMessage = [self handleReceivedEnvelopeJob:job
                                                                             envelope:envelope
                                                                            timestamp:timestamp
                                                                      withDataMessage:dataMessage
                                                                        attachmentIds:@[pointer.uniqueId]
                                                                                  idx:idx
                                                                          transaction:transaction];
        
        pointer.albumMessageId = createdMessage.uniqueId;
        
        OWSAttachmentsProcessor *attachmentsProcessor =
        [[OWSAttachmentsProcessor alloc] initWithAttachmentPointers:@[pointer] transaction:transaction];
        
        if (!createdMessage) {
            return;
        }
        
        OWSLogInfo(@"%@ incoming attachment message: %@", self.logTag, createdMessage.debugDescription);
        
        
        [attachmentsProcessor fetchAttachmentsForMessage:createdMessage
                                           forceDownload:NO
                                             transaction:transaction
                                                 success:^(TSAttachmentStream *attachmentStream) {
            OWSLogDebug(@"%@ successfully fetched attachment: %@ for message: %@",
                        self.logTag,
                        attachmentStream,
                        createdMessage);
            //            [self handleAttachmentsMessageBodyAfterDownLoad:obj thread:thread message:createdMessage attachmentStream:attachmentStream];
        }failure:^(NSError *error) {
            OWSLogError(
                        @"%@ failed to fetch attachments for message: %@ with error: %@", self.logTag, createdMessage, error);
        }];
        
    }];
}

- (void)handleHotDataIncomingEnvelopeJob:(OWSMessageContentJob *)job
                                envelope:(DSKProtoEnvelope *)envelope
                         withDataMessage:(DSKProtoDataMessage *)dataMessage
                      hotDataDestination:(NSString *_Nullable)hotDataDestination
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    OWSAssertDebug([TSAccountManager isRegistered]);
    
    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    if (![localNumber isEqualToString:envelope.source]) {
        // Sync messages should only come from linked devices.
        OWSProdErrorWEnvelope([OWSAnalyticsEvents messageManagerErrorSyncMessageFromUnknownSource], envelope);
        return;
    }
    
    if (dataMessage.group) {
        // 先快照群状态再调 fallback，防止 fallback 链路扩展后影响下面的判断
        TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:dataMessage.group.id transaction:transaction];
        BOOL groupUnknown = !groupThread || (groupThread.groupModel && groupThread.groupModel.version == 0);
        BOOL willFetchGroupInfo = groupUnknown && dataMessage.group.unwrappedType == DSKProtoGroupContextTypeDeliver;

        // 外层即将自行拉取群信息时，让 fallback 跳过内部的 refresh，避免重复请求。
        [DTGroupKeyMessageHandler.shared handleFallbackGroupRootKeyWithGroupContext:dataMessage.group
                                                                 skipGroupInfoFetch:willFetchGroupInfo
                                                                        transaction:transaction];

        if (willFetchGroupInfo) {
            [self.notifyMessageHandler.groupUpdateMessageProcessor requestGroupInfoWithGroupId:dataMessage.group.id
                                                                                 targetVersion:0
                                                                             needSystemMessage:NO
                                                                                      generate:NO
                                                                                      envelope:envelope
                                                                                   transaction:transaction
                                                                                    completion:^(SDSAnyWriteTransaction *t) {
            }];
        }
    }
    
    OWSIncomingSentMessageTranscript *transcript = [[OWSIncomingSentMessageTranscript alloc]
                                                    initWithProto:envelope
                                                    dataMessage:dataMessage
                                                    hotDataDestination:hotDataDestination
                                                    transaction:transaction];
    
    OWSRecordTranscriptJob *recordJob = [[OWSRecordTranscriptJob alloc] initWithIncomingSentMessageTranscript:transcript];
    recordJob.handleUnsupportedMessage = job.unsupportedFlag;
        
    // TODO: need remove
    if ([self isDataMessageGroupAvatarUpdate:dataMessage]) {
        [recordJob runWithAttachmentHandler:^(TSAttachmentStream *attachmentStream) {
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                TSGroupThread *_Nullable groupThread =
                [TSGroupThread threadWithGroupId:dataMessage.group.id
                                     transaction:transaction];
                if (!groupThread) {
                    OWSFailDebug(@"%@ ignoring sync group avatar update for unknown group.", self.logTag);
                    return;
                }
                
                [groupThread updateAvatarWithAttachmentStream:attachmentStream
                                                  transaction:transaction];
            });
        } envelopeJob:job transaction:transaction];
    } else {
        [recordJob runWithAttachmentHandler:^(TSAttachmentStream *attachmentStream) {
            OWSLogInfo(@"%@ successfully fetched transcript attachment: %@", self.logTag, attachmentStream);
        } envelopeJob:job transaction:transaction];
    }
}

- (void)handleIncomingEnvelopeJob:(OWSMessageContentJob *)job
                         envelope:(DSKProtoEnvelope *)envelope
                  withSyncMessage:(DSKProtoSyncMessage *)syncMessage
                      transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(syncMessage);
    OWSAssertDebug(transaction);
    OWSAssertDebug([TSAccountManager isRegistered]);

    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    if (![localNumber isEqualToString:envelope.source]) {
        // Sync messages should only come from linked devices.
        OWSProdErrorWEnvelope([OWSAnalyticsEvents messageManagerErrorSyncMessageFromUnknownSource], envelope);
        return;
    }
    

    if (syncMessage.sent) {
        
        if (syncMessage.sent.message.group) {
            TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:syncMessage.sent.message.group.id transaction:transaction];
            if (!groupThread || (groupThread.groupModel && groupThread.groupModel.version == 0)) {
                //获取群组信息
                [self.notifyMessageHandler.groupUpdateMessageProcessor requestGroupInfoWithGroupId:syncMessage.sent.message.group.id
                                                                                     targetVersion:0
                                                                                 needSystemMessage:NO
                                                                                          generate:false
                                                                                          envelope:envelope
                                                                                       transaction:transaction
                                                                                        completion:^(SDSAnyWriteTransaction * transaction) {
                }];
            }
        }
        
        uint64_t syncMessageServerTimestamp = envelope.systemShowTimestamp;
        
        OWSIncomingSentMessageTranscript *transcript =
            [[OWSIncomingSentMessageTranscript alloc] initWithProto:syncMessage.sent
                                                             source:envelope.source
                                                     sourceDeviceId:envelope.sourceDevice
                                                              relay:envelope.relay
                                                    serverTimestamp:syncMessageServerTimestamp
                                                        transaction:transaction];

        OWSRecordTranscriptJob *recordJob =
            [[OWSRecordTranscriptJob alloc] initWithIncomingSentMessageTranscript:transcript];
        recordJob.handleUnsupportedMessage = job.unsupportedFlag;

        DSKProtoDataMessage *dataMessage = syncMessage.sent.message;
        OWSAssertDebug(dataMessage);
        NSString *destination = syncMessage.sent.destination;
        if (dataMessage && destination.length > 0 && dataMessage.hasProfileKey) {
            // If we observe a linked device sending our profile key to another
            // user, we can infer that that user belongs in our profile whitelist.
            if (dataMessage.group) {
                [self.profileManager addGroupIdToProfileWhitelist:dataMessage.group.id transaction:transaction];
            } else {
                [self.profileManager addUserToProfileWhitelist:destination transaction:transaction];
            }
        }
        
        if (transcript.recall) {
            if (![transcript.recall isValidRecallMessageWithSource:envelope.source]) {
                //ignore recall.
                OWSLogWarn(@"%@ ignoring recall message.", self.logTag);
                return;
            }
        }

        if ([self isDataMessageGroupAvatarUpdate:syncMessage.sent.message]) {
            [recordJob runWithAttachmentHandler:^(TSAttachmentStream *attachmentStream) {
                DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    TSGroupThread *_Nullable groupThread =
                    [TSGroupThread threadWithGroupId:dataMessage.group.id
                                         transaction:transaction];
                    if (!groupThread) {
                        OWSFailDebug(@"%@ ignoring sync group avatar update for unknown group.", self.logTag);
                        return;
                    }
                    
                    [groupThread updateAvatarWithAttachmentStream:attachmentStream
                                                      transaction:transaction];
                });
            } envelopeJob:job transaction:transaction];
        } else {
            [recordJob runWithAttachmentHandler:^(TSAttachmentStream *attachmentStream) {
                OWSLogDebug(@"%@ successfully fetched transcript attachment: %@", self.logTag, attachmentStream);
            } envelopeJob:job transaction:transaction];
        }
    } else if (syncMessage.request) {
        
        if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeContacts) {

        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeGroups) {
            
            OWSLogInfo(@"ignore sync request groups message.");
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeBlocked) {
            OWSLogInfo(@"%@ Received request for block list", self.logTag);
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeConfiguration) {

        } else {
            OWSLogWarn(@"%@ ignoring unsupported sync request message", self.logTag);
        }
    } else if (syncMessage.blocked) {
        
    } else if (syncMessage.read.count > 0) { // 热数据不会记
        OWSLogInfo(@"%@ Received %ld read receipt(s)", self.logTag, (u_long)syncMessage.read.count);
        [OWSReadReceiptManager.sharedManager processReadReceiptsFromLinkedDevice:syncMessage.read
                                                                   readTimestamp:envelope.timestamp
                                                                     transaction:transaction];
    } else if (syncMessage.criticalRead.count > 0) {
        //
    } else if (syncMessage.verified) {
        OWSLogInfo(@"%@ Received verification state for %@", self.logTag, syncMessage.verified.destination);
        [self.identityManager processIncomingSyncMessage:syncMessage.verified transaction:transaction];
    }  else if (syncMessage.tasks.count) { // 内层已注释
        //
    } else if (syncMessage.markAsUnread) { // 热数据不会记
        [self.unreadProcessor processIncomingSyncMessage:syncMessage.markAsUnread serverTimestamp:envelope.systemShowTimestamp transaction:transaction];
    } else if (syncMessage.markTopicAsTrack) {
        //
    } else if (syncMessage.topicMark) {
        [self processIncomingSyncMessageWithTopicMark:syncMessage.topicMark serverTimestamp:envelope.systemShowTimestamp transaction:transaction];
    } else if (syncMessage.topicAction) {
        [self processIncomingSyncMessageWithTopicAction:syncMessage.topicAction serverTimestamp:envelope.systemShowTimestamp transaction:transaction];
    } else if (syncMessage.activityNoticeSync) {
        [self handleIncomingEnvelope:envelope
                  withActivityNotice:syncMessage.activityNoticeSync
                         transaction:transaction];
    } else if (syncMessage.forwardNoticeSync) {
        [self handleIncomingEnvelope:envelope
                   withForwardNotice:syncMessage.forwardNoticeSync
                         transaction:transaction];
    }
    else if (syncMessage.conversationArchive) { // 热数据不会记
        [DTMessageArchiveProcessor processIncomingSyncMessageWithArchiveMessage:syncMessage.conversationArchive serverTimestamp:envelope.systemShowTimestamp transaction:transaction];
    } else {
        OWSLogWarn(@"%@ Ignoring unsupported sync message.", self.logTag);
    }
}

- (void)handleIncomingEnvelope:(DSKProtoEnvelope *)envelope
             withForwardNotice:(DSKProtoForwardNoticeMessage *)forwardNotice
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(forwardNotice);
    OWSAssertDebug(transaction);

    NSString *localNumber = [TSAccountManager localNumber];
    BOOL isSelfSync = DTParamsUtils.validateString(localNumber)
        && DTParamsUtils.validateString(envelope.source)
        && [envelope.source isEqualToString:localNumber];
    OWSLogInfo(@"%@ ForwardNotice recv source=%@ scene=%d count=%u authors=%lu isSelfSync=%d",
               self.logTag,
               envelope.source,
               (int)forwardNotice.unwrappedScene,
               forwardNotice.hasMessageCount ? forwardNotice.messageCount : 0,
               (unsigned long)forwardNotice.sourceAuthorIds.count,
               isSelfSync);

    TSThread *thread = [self threadForForwardNoticeEnvelope:envelope
                                              forwardNotice:forwardNotice
                                                transaction:transaction];
    if (!thread) {
        OWSLogError(@"%@ ForwardNotice dropped: thread not found.", self.logTag);
        return;
    }

    if (envelope.timestamp > 0) {
        NSError *findError;
        NSArray<TSInteraction *> *existing = [InteractionFinder
            interactionsWithTimestamp:envelope.timestamp
                               filter:^BOOL(TSInteraction *interaction) {
                                   if (![interaction isKindOfClass:[TSInfoMessage class]]) {
                                       return NO;
                                   }
                                   TSInfoMessageType msgType = ((TSInfoMessage *)interaction).messageType;
                                   return msgType == TSInfoMessageForwardNotice;
                               }
                          transaction:transaction
                                error:&findError];
        if (findError) {
            OWSLogError(@"%@ ForwardNotice dedup query error: %@", self.logTag, findError);
        }
        NSString *envelopeSource = envelope.source ?: @"";
        for (TSInteraction *interaction in existing) {
            TSInfoMessage *info = (TSInfoMessage *)interaction;
            if ([info.uniqueThreadId isEqualToString:thread.uniqueId]
                && [(info.authorId ?: @"") isEqualToString:envelopeSource]) {
                OWSLogInfo(@"%@ ForwardNotice dedup: thread=%@ ts=%llu source=%@",
                           self.logTag, thread.uniqueId, envelope.timestamp, envelopeSource);
                return;
            }
        }
    }

    uint32_t messageCount = forwardNotice.hasMessageCount ? forwardNotice.messageCount : 0;
    if (messageCount == 0) {
        messageCount = 1;
    }

    DTForwardNoticeCombinedForwardMode combinedForwardMode = DTForwardNoticeCombinedForwardModeUnknown;
    if (forwardNotice.hasCombinedForwardMode) {
        combinedForwardMode = (DTForwardNoticeCombinedForwardMode)forwardNotice.unwrappedCombinedForwardMode;
    }

    NSString *noticeText = [DTForwardNoticeTextFormatter textWithOperatorId:envelope.source
                                                              messageCount:messageCount
                                                           sourceAuthorIds:forwardNotice.sourceAuthorIds
                                                       combinedForwardMode:combinedForwardMode
                                                               transaction:transaction];

    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:envelope.timestamp
                                                                 inThread:thread
                                                              messageType:TSInfoMessageForwardNotice
                                                            customMessage:noticeText];
    infoMessage.serverTimestamp = envelope.systemShowTimestamp;
    infoMessage.authorId = envelope.source;
    infoMessage.sourceDeviceId = envelope.sourceDevice;
    infoMessage.shouldAffectThreadSorting = YES;
    [infoMessage anyInsertWithTransaction:transaction];
    OWSLogInfo(@"%@ ForwardNotice inserted thread=%@ ts=%llu", self.logTag, thread.uniqueId, infoMessage.timestamp);
}

- (nullable TSThread *)threadForForwardNoticeEnvelope:(DSKProtoEnvelope *)envelope
                                         forwardNotice:(DSKProtoForwardNoticeMessage *)forwardNotice
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
    DSKProtoConversationId *payloadConv = forwardNotice.conversation;

    NSData *groupID = payloadConv.groupID;
    if (groupID.length > 0) {
        return [TSGroupThread threadWithGroupId:groupID transaction:transaction];
    }

    NSString *localNumber = [TSAccountManager localNumber];
    BOOL isSelfSync = DTParamsUtils.validateString(localNumber) && [envelope.source isEqualToString:localNumber];

    if (isSelfSync) {
        NSString *number = payloadConv.number;
        if (DTParamsUtils.validateString(number)) {
            return [TSContactThread getOrCreateThreadWithContactId:number transaction:transaction];
        }
        // Defensive NTS fallback: payload missing → my own NTS thread.
        OWSLogError(@"%@ ForwardNotice self-sync payload missing number, fallback to NTS.", self.logTag);
        return [TSContactThread getOrCreateThreadWithContactId:localNumber transaction:transaction];
    }

    // Primary 1v1: envelope.source is the peer.
    return [TSContactThread getOrCreateThreadWithContactId:envelope.source transaction:transaction];
}

#pragma mark - Activity Notice (Copy)

- (void)handleIncomingEnvelope:(DSKProtoEnvelope *)envelope
            withActivityNotice:(DSKProtoMessageActivityNotice *)activityNotice
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(activityNotice);
    OWSAssertDebug(transaction);

    // §3.1-1/2  typeData must be set to a recognized case; drop otherwise
    DSKProtoCopyData *copyData = activityNotice.copyData;
    if (!copyData) {
        OWSLogWarn(@"%@ ActivityNotice dropped: TYPEDATA_NOT_SET (no copyData), source=%@", self.logTag, envelope.source);
        return;
    }

    // Validate envelope.source
    if (!DTParamsUtils.validateString(envelope.source)) {
        OWSLogWarn(@"%@ ActivityNotice dropped: envelope.source is empty or nil", self.logTag);
        return;
    }

    // §3.2-5  timestamp must be valid (sendTs → envelope.timestamp)
    if (envelope.timestamp == 0) {
        OWSLogWarn(@"%@ ActivityNotice dropped: envelope.timestamp is 0, source=%@", self.logTag, envelope.source);
        return;
    }

    // Validate copyData has meaningful content
    if (copyData.sourceAuthorIds.count == 0) {
        OWSLogWarn(@"%@ ActivityNotice dropped: copyData.sourceAuthorIds is empty, source=%@", self.logTag, envelope.source);
        return;
    }

    NSString *localNumber = [TSAccountManager localNumber];
    BOOL isSelfSync = DTParamsUtils.validateString(localNumber)
        && [envelope.source isEqualToString:localNumber];
    OWSLogInfo(@"%@ ActivityNotice(COPY) recv source=%@ count=%u authors=%lu isSelfSync=%d",
               self.logTag,
               envelope.source,
               copyData.hasMessageCount ? copyData.messageCount : 0,
               (unsigned long)copyData.sourceAuthorIds.count,
               isSelfSync);

    // §3.1-5/6/7  Resolve target thread with member & well-formed checks
    TSThread *thread = [self threadForActivityNoticeEnvelope:envelope
                                             activityNotice:activityNotice
                                                transaction:transaction];
    if (!thread) {
        OWSLogWarn(@"%@ ActivityNotice dropped: thread not resolved, source=%@", self.logTag, envelope.source);
        return;
    }

    // Dedup: same timestamp + same thread + same source → already inserted
    NSError *findError;
    NSArray<TSInteraction *> *existing = [InteractionFinder
        interactionsWithTimestamp:envelope.timestamp
                           filter:^BOOL(TSInteraction *interaction) {
                               if (![interaction isKindOfClass:[TSInfoMessage class]]) {
                                   return NO;
                               }
                               return ((TSInfoMessage *)interaction).messageType == TSInfoMessageCopyNotice;
                           }
                      transaction:transaction
                            error:&findError];
    if (findError) {
        OWSLogError(@"%@ ActivityNotice dedup query error: %@", self.logTag, findError);
    }
    for (TSInteraction *interaction in existing) {
        TSInfoMessage *info = (TSInfoMessage *)interaction;
        if ([info.uniqueThreadId isEqualToString:thread.uniqueId]
            && [(info.authorId ?: @"") isEqualToString:envelope.source]) {
            OWSLogInfo(@"%@ ActivityNotice dedup: thread=%@ ts=%llu source=%@",
                       self.logTag, thread.uniqueId, envelope.timestamp, envelope.source);
            return;
        }
    }

    uint32_t messageCount = copyData.hasMessageCount ? copyData.messageCount : 0;
    if (messageCount == 0) {
        messageCount = 1;
    }

    DTForwardNoticeCombinedForwardMode combinedForwardMode = copyData.hasCombinedForwardMode
        ? (DTForwardNoticeCombinedForwardMode)copyData.unwrappedCombinedForwardMode
        : DTForwardNoticeCombinedForwardModeUnknown;

    NSString *noticeText = [DTCopyNoticeTextFormatter textWithOperatorId:envelope.source
                                                            messageCount:messageCount
                                                         sourceAuthorIds:copyData.sourceAuthorIds
                                                     combinedForwardMode:combinedForwardMode
                                                             transaction:transaction];

    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:envelope.timestamp
                                                                 inThread:thread
                                                              messageType:TSInfoMessageCopyNotice
                                                            customMessage:noticeText];
    infoMessage.serverTimestamp = envelope.systemShowTimestamp;
    infoMessage.authorId = envelope.source;
    infoMessage.sourceDeviceId = envelope.sourceDevice;
    infoMessage.shouldAffectThreadSorting = YES;
    [infoMessage anyInsertWithTransaction:transaction];
    OWSLogInfo(@"%@ CopyNotice inserted thread=%@ ts=%llu", self.logTag, thread.uniqueId, infoMessage.timestamp);
}

- (nullable TSThread *)threadForActivityNoticeEnvelope:(DSKProtoEnvelope *)envelope
                                        activityNotice:(DSKProtoMessageActivityNotice *)activityNotice
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
    DSKProtoConversationId *payloadConv = activityNotice.conversation;

    // §3.1-5  Group: verify envelope.source is a member
    NSData *groupID = payloadConv.groupID;
    if (groupID.length > 0) {
        TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:groupID transaction:transaction];
        if (!groupThread) {
            OWSLogWarn(@"%@ ActivityNotice dropped: group thread not found for groupID.", self.logTag);
            return nil;
        }
        if (![groupThread.groupModel.groupMemberIds containsObject:envelope.source]) {
            OWSLogWarn(@"%@ ActivityNotice dropped: source=%@ is not a member of group=%@",
                       self.logTag, envelope.source, groupThread.uniqueId);
            return nil;
        }
        return groupThread;
    }

    NSString *localNumber = [TSAccountManager localNumber];
    BOOL isSelfSync = DTParamsUtils.validateString(localNumber) && [envelope.source isEqualToString:localNumber];

    // §3.1-7  Self-sync: conversation must be well-formed, drop if not
    if (isSelfSync) {
        NSString *number = payloadConv.number;
        if (DTParamsUtils.validateString(number)) {
            return [TSContactThread getOrCreateThreadWithContactId:number transaction:transaction];
        }
        OWSLogWarn(@"%@ ActivityNotice dropped: self-sync conversation missing valid number, refusing NTS fallback.", self.logTag);
        return nil;
    }

    // §3.1-6  1v1: conversation field absent → fallback to envelope.source
    return [TSContactThread getOrCreateThreadWithContactId:envelope.source transaction:transaction];
}

- (void)handleExpirationTimerUpdateMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                           dataMessage:(DSKProtoDataMessage *)dataMessage
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
   //
}

- (void)handleProfileKeyMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                dataMessage:(DSKProtoDataMessage *)dataMessage
                                transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);

    NSString *recipientId = envelope.source;
    if (!dataMessage.hasProfileKey) {
        OWSFailDebug(
            @"%@ received profile key message without profile key from: %@", self.logTag, envelopeAddress(envelope));
        return;
    }
    NSData *profileKey = dataMessage.profileKey;
    if (profileKey.length != kAES256_KeyByteLength) {
        OWSFailDebug(@"%@ received profile key of unexpected length:%lu from:%@",
            self.logTag,
            (unsigned long)profileKey.length,
            envelopeAddress(envelope));
        return;
    }

    id<ProfileManagerProtocol> profileManager = [TextSecureKitEnv sharedEnv].profileManager;
    [profileManager setProfileKeyData:profileKey forRecipientId:recipientId transaction:transaction];
}

- (void)handleReceivedTextMessageWithEnvelopeJob:(OWSMessageContentJob *)job
                                        envelope:(DSKProtoEnvelope *)envelope
                                       timestamp:(UInt64)timestamp
                                     dataMessage:(DSKProtoDataMessage *)dataMessage
                                             idx:(NSUInteger)idx
                                     transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);

    [self handleReceivedEnvelopeJob:job
                           envelope:envelope
                       timestamp:timestamp
                 withDataMessage:dataMessage
                   attachmentIds:@[]
                             idx:idx
                     transaction:transaction];
}

- (void)sendGroupUpdateForThread:(TSGroupThread *)gThread message:(TSOutgoingMessage *)message
{
    OWSAssertDebug(gThread);
    OWSAssertDebug(gThread.groupModel);
    OWSAssertDebug(message);

    if (gThread.groupModel.groupImage) {
        NSData *data = UIImagePNGRepresentation(gThread.groupModel.groupImage);
        id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:data fileExtension:@"png"];
        [self.messageSender enqueueAttachment:dataSource
            contentType:OWSMimeTypeImagePng
            sourceFilename:nil
            inMessage:message
         preSendMessageCallBack:nil
            success:^{
                OWSLogDebug(@"%@ Successfully sent group update with avatar", self.logTag);
            }
            failure:^(NSError *error) {
                OWSLogError(@"%@ Failed to send group avatar update with error: %@", self.logTag, error);
            }];
    } else {
        [self.messageSender enqueueMessage:message
            success:^{
                OWSLogDebug(@"%@ Successfully sent group update", self.logTag);
            }
            failure:^(NSError *error) {
                OWSLogError(@"%@ Failed to send group update with error: %@", self.logTag, error);
            }];
    }
}

- (void)handleGroupInfoRequest:(DSKProtoEnvelope *)envelope
                   dataMessage:(DSKProtoDataMessage *)dataMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    OWSAssertDebug(dataMessage.group.unwrappedType == DSKProtoGroupContextTypeRequestInfo);

    NSData *groupId = dataMessage.group ? dataMessage.group.id : nil;
    if (!groupId) {
        OWSFailDebug(@"Group info request is missing group id.");
        return;
    }

    OWSLogWarn(
        @"%@ Received 'Request Group Info' message for group: %@ from: %@", self.logTag, groupId, envelope.source);

    TSGroupThread *_Nullable gThread = [TSGroupThread threadWithGroupId:dataMessage.group.id transaction:transaction];
    if (!gThread) {
        OWSLogWarn(@"%@ Unknown group: %@", self.logTag, groupId);
        return;
    }

    // Ensure sender is in the group.
    if (![gThread.groupModel.groupMemberIds containsObject:envelope.source]) {
        OWSLogWarn(@"%@ Ignoring 'Request Group Info' message for non-member of group. %@ not in %@",
            self.logTag,
            envelope.source,
            gThread.groupModel.groupMemberIds);
        return;
    }

    // Ensure we are in the group.
    OWSAssertDebug([TSAccountManager isRegistered]);
    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    if (![gThread.groupModel.groupMemberIds containsObject:localNumber]) {
        OWSLogWarn(@"%@ Ignoring 'Request Group Info' message for group we no longer belong to.", self.logTag);
        return;
    }

    NSString *updateGroupInfo = @"";
//        [gThread.groupModel getInfoStringAboutUpdateTo:gThread.groupModel contactsManager:self.contactsManager];

    uint32_t expiresInSeconds = [gThread messageExpiresInSecondsWithTransaction:transaction];
    TSOutgoingMessage *message = [TSOutgoingMessage outgoingMessageInThread:gThread
                                                           groupMetaMessage:TSGroupMessageUpdate
                                                                  atPersons:nil
                                                                   mentions:nil
                                                           expiresInSeconds:expiresInSeconds];

    [message updateWithCustomMessage:updateGroupInfo transaction:transaction];
    // Only send this group update to the requester.
    [message updateWithSendingToSingleGroupRecipient:envelope.source transaction:transaction];

    [self sendGroupUpdateForThread:gThread message:message];
}

- (BOOL)checkMessageIntegrityWithEnvelopeJob:(OWSMessageContentJob *)job
                                    envelope:(DSKProtoEnvelope *)envelope
                                   timestamp:(UInt64)timestamp
                                 DataMessage:(DSKProtoDataMessage *)dataMessage
                                        body:(NSString **)body
                           containsOtherData:(BOOL)containsOtherData
                           markAsUnsupported:(BOOL)markAsUnsupported
                                 transaction:(SDSAnyWriteTransaction *)transaction {
    
    if (dataMessage.requiredProtocolVersion > kCurrentProtocolVersion || markAsUnsupported) {
        //unsupport
        *body = [NSString stringWithFormat:@"[%@]",Localized(@"UNSUPPORTED_MESSAGE_TIP",nil)];
        job.unsupportedFlag = YES;
        job.lastestHandleVersion = [AppVersion shared].currentAppReleaseVersion;
        [job anyInsertWithTransaction:transaction];
        return YES;
    }
    
    if(!containsOtherData){
        //exception
        OWSLogWarn(@"%@ version hasType ignoring empty incoming message from: %@ with timestamp: %lu",
                   self.logTag,
                   envelopeAddress(envelope),
                   (unsigned long)timestamp);
        job.unsupportedFlag = NO;
        return NO;
    } else {
        
        job.unsupportedFlag = NO;
        return YES;
    }
}

- (void)screenshotWithEnvelope:(DSKProtoEnvelope *)envelope
                   dataMessage:(DSKProtoDataMessage *)dataMessage
                        thread:(TSThread *)thread
                   transaction:(SDSAnyWriteTransaction *)transaction {
    OWSLogInfo(@"Screen Shot message");
    DTRealSourceEntity *realSource = [DTRealSourceEntity realSourceEntityWithProto:dataMessage.screenShot.source];
    // Use transaction-based method to ensure database lookup for nickname
    NSString *nameString = [self.contactsManager displayNameForPhoneIdentifier:envelope.source transaction:transaction];
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                 inThread:thread
                                                              messageType:TSInfoMessageScreenshotMessage
                                                         expiresInSeconds:dataMessage.expireTimer
                                                            customMessage:[NSString stringWithFormat:Localized(@"%@ took a screenshot!",nil), nameString]];
    infoMessage.serverTimestamp = envelope.systemShowTimestamp;
    infoMessage.authorId = envelope.source;
    infoMessage.sourceDeviceId = realSource.sourceDevice;
    [infoMessage anyInsertWithTransaction:transaction];
}

- (TSIncomingMessage *_Nullable)handleReceivedEnvelopeJob:(OWSMessageContentJob *)job
                                              envelope:(DSKProtoEnvelope *)envelope
                                             timestamp:(UInt64)timestamp_
                                       withDataMessage:(DSKProtoDataMessage *)dataMessage
                                         attachmentIds:(NSArray<NSString *> *)attachmentIds
                                                   idx:(NSUInteger)idx
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
    
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);
    uint64_t timestamp = timestamp_;//envelope.timestamp;
    NSString *source = envelope.source;
    uint32_t sourceDevice = envelope.sourceDevice;
    NSString *relay = envelope.relay;
    
    BOOL hasRecallMessage = [RecallFinder existsRecallMessageWithTimestamp:timestamp
                                                                  sourceId:source
                                                            sourceDeviceId:sourceDevice
                                                               transaction:transaction];
    
    if(hasRecallMessage){
        OWSLogWarn(@"%@incoming message hasRecallMessage from %@ with timestamp: %llu",
            self.logTag,
            envelopeAddress(envelope),
            timestamp);
        
        // recall 消息和原始消息乱序时，接收到原始消息后，同步 recall 消息的 serverTimestamp
        NSString *recallMessageId = [TSInteraction generateUniqueIdWithAuthorId:source deviceId:sourceDevice timestamp:timestamp];
        TSInteraction *recallMessage = [InteractionFinder fetchWithUniqueId:recallMessageId transaction:transaction];
        if (recallMessage && recallMessage.serverTimestamp != envelope.systemShowTimestamp) {
            
            OWSLogInfo(@"sync recall message servertimestamp, from %llu, to: %llu, message timestamp: %llu", recallMessage.serverTimestamp, envelope.systemShowTimestamp, timestamp);
            
            [recallMessage anyUpdateWithTransaction:transaction block:^(TSInteraction * _Nonnull copyMessage) {
                copyMessage.serverTimestamp = envelope.systemShowTimestamp;
            }];
        }
        return nil;
    }
    
    NSString *body = nil;
    if (attachmentIds.count > 0) {
        body = idx == dataMessage.attachments.count - 1 ? dataMessage.body : @"";
    } else {
        body = dataMessage.body;
    }
    NSString *atPersons = dataMessage.atPersons;
    NSArray <DTMention *> *mentions = [DTMention mentionsWithProto:dataMessage];
    NSData *groupId = dataMessage.group ? dataMessage.group.id : nil;
    
    DTRecallMessage *recall = [DTRecallMessage recallWithDataMessage:dataMessage];
    
    BOOL duplicateRecallMessage = [RecallFinder duplicateRecallMessageWithTimestamp:timestamp
                                                                           sourceId:source
                                                                     sourceDeviceId:sourceDevice
                                                                        transaction:transaction];
    if(duplicateRecallMessage){
//        OWSProdFail(@"incoming message hasRecallMessage");
        OWSLogInfo(@"%@incoming message has duplicate recallMessage from %@ with timestamp: %llu",
            self.logTag,
            envelopeAddress(envelope),
            timestamp);
        
        if (job.unsupportedFlag) { // 处理数据库中异常数据，历史遗留库中可能存在重复的不支持的 recall 消息，没有机会删除掉（Felix 手机遇到）
            job.unsupportedFlag = NO;
        }
        return nil;
    }
    if(recall){
        
        if (![recall isValidRecallMessageWithSource:envelope.source]) {
            //ignore recall.
            OWSLogWarn(@"%@ ignoring recall message.", self.logTag);
            return nil;
        }
        
        TSIncomingMessage *originMessage = [TSIncomingMessage findMessageWithAuthorId:recall.source.source
                                                                             deviceId:recall.source.sourceDevice
                                                                            timestamp:recall.source.timestamp
                                                                          transaction:transaction];
        TSThread *thread = nil;
        if (groupId.length > 0) {
            thread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
        }else{
            thread = [TSContactThread getOrCreateThreadWithContactId:source
                                                         transaction:transaction
                                                               relay:relay];
        }
        
        OWSLogInfo(@"===== recall source timestamp:%llu, servertimestamp: %llu =====", recall.source.timestamp, recall.source.serverTimestamp);
        if (originMessage) {
            OWSLogInfo(@"===== originalMessage timestamp: %llu, serverTimestamp: %llu =====", originMessage.timestamp, originMessage.serverTimestamp);
            [originMessage anyRemoveWithTransaction:transaction];
        }
        [recall insertRecordWithSource:source
                          sourceDevice:sourceDevice
                             timestamp:timestamp
                           transaction:transaction];
        OWSLogInfo(@"===== recall messaage timestamp:%llu, servertimestamp: %llu =====", recall.source.timestamp, envelope.systemShowTimestamp);
        
        if(self.handleUnsupportedMessage){
            TSIncomingMessage *oldMessage = [TSIncomingMessage findMessageWithAuthorId:source
                                                                              deviceId:sourceDevice
                                                                             timestamp:timestamp
                                                                           transaction:transaction];
            if(oldMessage){
                [oldMessage anyRemoveWithTransaction:transaction];
                OWSLogInfo(@"handleUnsupportedMessage delete message timestamp for sorting: %llu", oldMessage.timestampForSorting);
            }
        }
        return nil;
    }

//    if (dataMessage.group.type == DSKProtoGroupContextTypeRequestInfo) {
//        [self handleGroupInfoRequest:envelope dataMessage:dataMessage transaction:transaction];
//        return nil;
//    }
    

    if (groupId.length > 0) {
        NSMutableSet *newMemberIds = [NSMutableSet setWithArray:dataMessage.group.members];
        for (NSString *recipientId in newMemberIds) {
            if (!recipientId.isStructurallyValidE164) {
                OWSLogVerbose(@"%@ incoming group update has invalid group member: %@",
                    self.logTag,
                    [self descriptionForEnvelope:envelope]);
                OWSFailDebug(@"%@ incoming group update has invalid group member", self.logTag);
                return nil;
            }
        }

        // Group messages create the group if it doesn't already exist.
        //
        // We distinguish between the old group state (if any) and the new group state.
        TSGroupThread *_Nullable oldGroupThread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
        
        if (dataMessage.screenShot) {
            [self screenshotWithEnvelope:envelope
                             dataMessage:dataMessage
                                  thread:oldGroupThread
                             transaction:transaction];
            return nil;
        }

        OWSContact *_Nullable contact = [self createContactIfHave:dataMessage
                                                        timestamp:timestamp
                                                           source:source
                                                     sourceDevice:sourceDevice
                                                         threadId:oldGroupThread.uniqueId
                                                            relay:relay
                                                      transaction:transaction];

        switch (dataMessage.group.unwrappedType) {
            case DSKProtoGroupContextTypeUpdate: { // deprecated
                
                return nil;
            }
            case DSKProtoGroupContextTypeQuit: { // deprecated
                
                return nil;
            }
            case DSKProtoGroupContextTypeDeliver: {
                if (!oldGroupThread) {
                    OWSFailDebug(@"%@ ignoring deliver group message from unknown group.", self.logTag);
                    return nil;
                }
                
                DTCombinedForwardingMessage *_Nullable forwardingMessage = nil;
                if(dataMessage.forwardContext && dataMessage.forwardContext.forwards.count){
                    
                    NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                             deviceId:sourceDevice
                                                                            timestamp:timestamp];
                    DSKProtoDataMessageForward *forword =
                    [DTCombinedForwardingMessage
                     buildRootForwardProtoWithForwardContextProto:dataMessage.forwardContext
                     timestamp:timestamp
                     serverTimestamp:envelope.systemShowTimestamp
                     author:source
                     body:body];
                    forwardingMessage = [DTCombinedForwardingMessage
                                         forwardingMessageForDataMessage:forword
                                         threadId:oldGroupThread.uniqueId
                                         messageId:messageId
                                         relay:relay
                                         transaction:transaction];
//                    if (forwardingMessage.subForwardingMessages.count > 1) {
//                        [forwardingMessage handleForwardingAttachmentsWithOrigionMessage:nil transaction:transaction completion:nil];
//                    }
                }
                
                TSQuotedMessage *_Nullable quotedMessage = nil;
                if (dataMessage.quote) {
                    NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                             deviceId:sourceDevice
                                                                            timestamp:timestamp];
                    quotedMessage = [TSQuotedMessage quotedMessageForQuoteProto:dataMessage.quote
                                                                         thread:oldGroupThread
                                                                      messageId:messageId
                                                                          relay:relay
                                                                    transaction:transaction];
                }
                
                if(dataMessage.card){
                    return nil;
                }
                
                DTReactionMessage *reaction = nil;
                if (dataMessage.reaction) {
                    reaction = [DTReactionMessage reactionWithProto:dataMessage];
                    DTRealSourceEntity *ownSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:timestamp sourceDevice:sourceDevice source:source];
                    reaction.ownSource = ownSource;
                    reaction.conversationId = oldGroupThread.uniqueId;
                    [reaction saveWithTransaction:transaction];
                    
                    if (self.handleUnsupportedMessage) {
                        TSIncomingMessage *oldMessage = [TSIncomingMessage findMessageWithAuthorId:source
                                                                                          deviceId:sourceDevice
                                                                                         timestamp:timestamp
                                                                                       transaction:transaction];
                        if (oldMessage) {
                            [oldMessage anyRemoveWithTransaction:transaction];
                            OWSLogInfo(@"handleUnsupportedMessage delete message timestamp for sorting: %llu", oldMessage.timestampForSorting);
                        }
                    }
                }
                
                BOOL containsOtherData = (body.length || forwardingMessage || reaction || attachmentIds.count > 0 || quotedMessage || contact);
                
                BOOL markAsUnsupported = NO;

                if(![self checkMessageIntegrityWithEnvelopeJob:job
                                                      envelope:envelope
                                                     timestamp:timestamp
                                                   DataMessage:dataMessage
                                                          body:&body
                                             containsOtherData:containsOtherData
                                             markAsUnsupported:markAsUnsupported
                                                   transaction:transaction]){
                    return nil;
                }

                OWSLogDebug(@"%@ incoming message from: %@ for group: %@ with timestamp: %lu",
                    self.logTag,
                    envelopeAddress(envelope),
                    groupId,
                    (unsigned long)timestamp);

                TSIncomingMessage *incomingMessage =
                    [[TSIncomingMessage alloc] initIncomingMessageWithTimestamp:timestamp
                                                                serverTimestamp:envelope.systemShowTimestamp
                                                                     sequenceId:envelope.sequenceID
                                                               notifySequenceId:envelope.notifySequenceID
                                                                       inThread:oldGroupThread
                                                                       authorId:source
                                                                 sourceDeviceId:sourceDevice
                                                                    messageBody:body
                                                                      atPersons:atPersons
                                                                       mentions:mentions
                                                                  attachmentIds:attachmentIds
                                                               expiresInSeconds:dataMessage.expireTimer
                                                                  quotedMessage:quotedMessage
                                                              forwardingMessage:forwardingMessage
                                                                   contactShare:contact];
                
                incomingMessage.reactionMessage = reaction;
                incomingMessage.whisperMessageType = envelope.unwrappedType;
                
                if (forwardingMessage && forwardingMessage.subForwardingMessages.firstObject.forwardingAttachmentIds.count > 0) {
                    [forwardingMessage handleForwardingAttachmentsWithOrigionMessage:incomingMessage transaction:transaction completion:^(TSAttachmentStream * _Nonnull attachmentStream) {
//                        [self handleAttachmentMessage:incomingMessage thread:oldGroupThread transaction:transaction attachmentStream:attachmentStream];
                    }];
                }
                
                if(self.handleUnsupportedMessage){
                    TSIncomingMessage *oldMessage = [TSIncomingMessage findMessageWithAuthorId:source
                                                                                      deviceId:sourceDevice
                                                                                     timestamp:timestamp
                                                                                   transaction:transaction];
                    if(oldMessage){
                        incomingMessage.uniqueId = oldMessage.uniqueId;
                    }
                }
                
                if(dataMessage.hasMessageMode && dataMessage.messageMode){
                    DSKProtoDataMessageMessageMode messageModeType = dataMessage.messageMode;
                    if (messageModeType == DSKProtoDataMessageMessageModeConfidential) {
                        incomingMessage.messageModeType = TSMessageModeTypeConfidential;
                    } else {
                        incomingMessage.messageModeType = TSMessageModeTypeNormal;
                    }
                }
                
                [self finalizeIncomingMessage:incomingMessage
                                  envelopeJob:job
                                       thread:oldGroupThread
                                     envelope:envelope
                                  transaction:transaction];
                return incomingMessage;
            }
            default: {
                OWSLogWarn(@"%@ Ignoring unknown group message type: %d", self.logTag, (int)dataMessage.group.unwrappedType);
                return nil;
            }
        }
    } else {
        
        TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactId:source
                                                                      transaction:transaction
                                                                            relay:relay];
        
        if (dataMessage.screenShot) {
            [self screenshotWithEnvelope:envelope
                             dataMessage:dataMessage
                                  thread:thread
                             transaction:transaction];
            return nil;
        }
        
        OWSContact *_Nullable contact = [self createContactIfHave:dataMessage
                                                        timestamp:timestamp
                                                           source:source
                                                     sourceDevice:sourceDevice
                                                         threadId:thread.uniqueId
                                                            relay:relay
                                                      transaction:transaction];
        
        DTCombinedForwardingMessage *_Nullable forwardingMessage = nil;
        if(dataMessage.forwardContext && dataMessage.forwardContext.forwards.count){
            DSKProtoDataMessageForward *forward =
            [DTCombinedForwardingMessage buildRootForwardProtoWithForwardContextProto:dataMessage.forwardContext
                                                                            timestamp:timestamp
                                                                      serverTimestamp:envelope.systemShowTimestamp
                                                                               author:thread.contactIdentifier
                                                                                 body:body];
            NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                     deviceId:sourceDevice
                                                                    timestamp:timestamp];
            
            forwardingMessage = [DTCombinedForwardingMessage forwardingMessageForDataMessage:forward
                                                                                    threadId:thread.uniqueId
                                                                                   messageId:messageId
                                                                                       relay:relay
                                                                                 transaction:transaction];
//            if (forwardingMessage.subForwardingMessages.count > 1) {
//                [forwardingMessage handleForwardingAttachmentsWithOrigionMessage:nil transaction:transaction completion:nil];
//            }
        }
        
        TSQuotedMessage *_Nullable quotedMessage = nil;
        if (dataMessage.quote) {
            NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                     deviceId:sourceDevice
                                                                    timestamp:timestamp];
            quotedMessage = [TSQuotedMessage quotedMessageForQuoteProto:dataMessage.quote
                                                                 thread:thread
                                                              messageId:messageId
                                                                  relay:relay
                                                            transaction:transaction];;
        }
        
        if(dataMessage.card){
            return nil;
        }
        
        DTReactionMessage *reaction = nil;
        if (dataMessage.reaction) {
            reaction = [DTReactionMessage reactionWithProto:dataMessage];
            DTRealSourceEntity *ownSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:timestamp sourceDevice:sourceDevice source:source];
            reaction.ownSource = ownSource;
            reaction.conversationId = source;
            [reaction saveWithTransaction:transaction];
            
            if (self.handleUnsupportedMessage) {
                TSIncomingMessage *oldMessage = [TSIncomingMessage findMessageWithAuthorId:source
                                                                                  deviceId:sourceDevice
                                                                                 timestamp:timestamp
                                                                               transaction:transaction];
                if (oldMessage) {
                    [oldMessage anyRemoveWithTransaction:transaction];
                    OWSLogInfo(@"handleUnsupportedMessage delete message timestamp for sorting: %llu", oldMessage.timestampForSorting);
                }
            }
        }
        
        BOOL containsOtherData = (body.length || forwardingMessage || reaction || attachmentIds.count || quotedMessage || contact);
        BOOL markAsUnsupported = NO;

        if(![self checkMessageIntegrityWithEnvelopeJob:job
                                              envelope:envelope
                                             timestamp:timestamp
                                           DataMessage:dataMessage
                                                  body:&body
                                     containsOtherData:containsOtherData
                                     markAsUnsupported:markAsUnsupported
                                           transaction:transaction]){
            return nil;
        }

        OWSLogDebug(@"%@ incoming message from: %@ with timestamp: %lu",
            self.logTag,
            envelopeAddress(envelope),
            (unsigned long)timestamp);
        
        TSIncomingMessage *incomingMessage =
            [[TSIncomingMessage alloc] initIncomingMessageWithTimestamp:timestamp
                                                        serverTimestamp:envelope.systemShowTimestamp
                                                             sequenceId:envelope.sequenceID
                                                       notifySequenceId:envelope.notifySequenceID
                                                               inThread:thread
                                                               authorId:thread.contactIdentifier
                                                         sourceDeviceId:sourceDevice
                                                            messageBody:body
                                                              atPersons:atPersons
                                                               mentions:mentions
                                                          attachmentIds:attachmentIds
                                                       expiresInSeconds:dataMessage.expireTimer
                                                          quotedMessage:quotedMessage
                                                      forwardingMessage:forwardingMessage
                                                           contactShare:contact];
        
        incomingMessage.reactionMessage = reaction;
        incomingMessage.whisperMessageType = envelope.unwrappedType;
        
        if (forwardingMessage && forwardingMessage.subForwardingMessages.firstObject.forwardingAttachmentIds.count == 1) {//有附件带文字
            [forwardingMessage handleForwardingAttachmentsWithOrigionMessage:incomingMessage transaction:transaction completion:^(TSAttachmentStream * _Nonnull attachmentStream) {
//                [self handleAttachmentMessage:incomingMessage thread:thread transaction:transaction attachmentStream:attachmentStream];
            }];
        }
        
        if(self.handleUnsupportedMessage){
            TSIncomingMessage *oldMessage = [TSIncomingMessage findMessageWithAuthorId:source
                                                                              deviceId:sourceDevice
                                                                             timestamp:timestamp
                                                                           transaction:transaction];
            if(oldMessage){
                incomingMessage.uniqueId = oldMessage.uniqueId;
            }
        }
        
        if(dataMessage.hasMessageMode && dataMessage.messageMode){
            DSKProtoDataMessageMessageMode messageModeType = dataMessage.messageMode;
            if (messageModeType == DSKProtoDataMessageMessageModeConfidential) {
                incomingMessage.messageModeType = TSMessageModeTypeConfidential;
            } else {
                incomingMessage.messageModeType = TSMessageModeTypeNormal;
            }
        }

        [self finalizeIncomingMessage:incomingMessage
                          envelopeJob:job
                               thread:thread
                             envelope:envelope
                          transaction:transaction];
        return incomingMessage;
    }
}

- (void)finalizeIncomingMessage:(TSIncomingMessage *)incomingMessage
                    envelopeJob:(OWSMessageContentJob *)job
                         thread:(TSThread *)thread
                       envelope:(DSKProtoEnvelope *)envelope
                    transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(thread);
    OWSAssertDebug(incomingMessage);
    OWSAssertDebug(envelope);
    OWSAssertDebug(transaction);

    OWSAssertDebug([TSAccountManager isRegistered]);
    if (!thread) {
        OWSFailDebug(@"%@ Can't finalize without thread", self.logTag);
        return;
    }
    if (!incomingMessage) {
        OWSFailDebug(@"%@ Can't finalize missing message", self.logTag);
        return;
    }
    
    OWSLogInfo(@"%@ incomingMessage saved.",self.logTag);
   
    //MARK: 1、reactionMessage不入库
    if (incomingMessage.isReactionMessage) {
        return;
    }
        
    //MARK: 如果有新消息且因为乱序且之前收到过reactionMessage，查找未关联原消息的reactionMessage并尝试关联
    NSArray <DTReactionMessage *> *relatedReactionMessages = [DTReactionMessage findReactionMessagesWithMessage:incomingMessage transaction:transaction];
    if (relatedReactionMessages.count > 0) {
        [relatedReactionMessages enumerateObjectsUsingBlock:^(DTReactionMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj relateReactionMessageWithOriginMessage:incomingMessage transaction:transaction];
        }];
    }
    
    if(job.envelopeProto.lastestMsgFlag){ // 拉取离线会话需要更新会话 lastestMsg
        if(!incomingMessage.grdbId){
            [incomingMessage updateRowId:100];
        }
        OWSLogInfo(@"%@ handling lastestMsgFlag  envelope: %@", self.logTag, [self descriptionForEnvelope:envelope]);
        [thread updateWithLastMessage:incomingMessage isInserted:YES transaction:transaction];
        
        return;
    }else{
        OWSLogInfo(@"%@ will insert incomingMessage: %@", self.logTag, [self descriptionForEnvelope:envelope]);
        [incomingMessage anyInsertWithTransaction:transaction];
        OWSLogInfo(@"%@ did insert incomingMessage: %@", self.logTag, [self descriptionForEnvelope:envelope]);
        
        NSData *groupId = nil;
        if(thread.isGroupThread){
            groupId = ((TSGroupThread *)thread).groupModel.groupId;
        }
        DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                    readAt:incomingMessage.serverTimestamp
                                                                             maxServerTime:incomingMessage.serverTimestamp
                                                                          notifySequenceId:incomingMessage.notifySequenceId
                                                                             maxSequenceId:incomingMessage.sequenceId];
        TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                               recipientId:incomingMessage.authorId
                                                                                              readPosition:readPosition];
        [messageReadPosition updateOrInsertWithTransaction:transaction];
        
    }
    
    // Any messages sent from the current user - from this device or another - should be automatically marked as read.
    NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
    if ([envelope.source isEqualToString:localNumber]) {
        // Don't send a read receipt for messages sent by ourselves.
        NSData *groupId = nil;
        if(thread.isGroupThread){
            groupId = ((TSGroupThread *)thread).groupModel.groupId;
        }
        DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                    readAt:[NSDate ows_millisecondTimeStamp]
                                                                             maxServerTime:incomingMessage.serverTimestamp
                                                                          notifySequenceId:incomingMessage.notifySequenceId
                                                                             maxSequenceId:incomingMessage.sequenceId];
        TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                               recipientId:localNumber
                                                                                              readPosition:readPosition];
        [messageReadPosition updateOrInsertWithTransaction:transaction];
        [incomingMessage markAsReadAtPosition:readPosition sendReadReceipt:NO transaction:transaction];
    }

    TSQuotedMessage *_Nullable quotedMessage = incomingMessage.quotedMessage;
    if (quotedMessage && quotedMessage.thumbnailAttachmentPointerId) {
        // We weren't able to derive a local thumbnail, so we'll fetch the referenced attachment.
        TSAttachmentPointer *attachmentPointer =
            [TSAttachmentPointer anyFetchAttachmentPointerWithUniqueId:quotedMessage.thumbnailAttachmentPointerId
                                             transaction:transaction];

        if ([attachmentPointer isKindOfClass:[TSAttachmentPointer class]]) {
            OWSAttachmentsProcessor *attachmentProcessor =
                [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer];

            OWSLogDebug(
                @"%@ downloading thumbnail for message: %lu", self.logTag, (unsigned long)incomingMessage.timestamp);
            [attachmentProcessor fetchAttachmentsForMessage:incomingMessage
                                              forceDownload:NO
                                                transaction:transaction
                                                    success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *wTransaction) {
                    [incomingMessage anyUpdateWithTransaction:wTransaction
                                                        block:^(TSInteraction * instance) {
                        if([instance isKindOfClass:[TSIncomingMessage class]]){
                            [((TSIncomingMessage *)instance) setQuotedMessageThumbnailAttachmentStream:attachmentStream];
                        }
                    }];
                });
            }
                                                    failure:^(NSError *_Nonnull error) {
                OWSLogWarn(@"%@ failed to fetch thumbnail for message: %lu with error: %@",
                          self.logTag,
                          (unsigned long)incomingMessage.timestamp,
                          error);
            }];
        }
    }
    
    //combined forwarding message attachment
//    [incomingMessage.combinedForwardingMessage handleWithIncomingMessage:incomingMessage transaction:transaction];

    OWSContact *_Nullable contact = incomingMessage.contactShare;
    if (contact && contact.avatarAttachmentId) {
        TSAttachmentPointer *attachmentPointer =
            [TSAttachmentPointer anyFetchAttachmentPointerWithUniqueId:contact.avatarAttachmentId transaction:transaction];

        if (![attachmentPointer isKindOfClass:[TSAttachmentPointer class]]) {
            OWSFailDebug(@"%@ in %s avatar attachmentPointer was unexpectedly nil", self.logTag, __PRETTY_FUNCTION__);
        } else {
            OWSAttachmentsProcessor *attachmentProcessor =
                [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer];

            OWSLogDebug(@"%@ downloading contact avatar for message: %lu",
                self.logTag,
                (unsigned long)incomingMessage.timestamp);
            [attachmentProcessor fetchAttachmentsForMessage:incomingMessage forceDownload:NO
                transaction:transaction
                success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                        if(incomingMessage.grdbId){
                            [self.databaseStorage touchInteraction:incomingMessage
                                                     shouldReindex:NO
                                                       transaction:writeTransaction];
                        }
                    });
                }
                failure:^(NSError *_Nonnull error) {
                    OWSLogWarn(@"%@ failed to fetch contact avatar for message: %lu with error: %@",
                        self.logTag,
                        (unsigned long)incomingMessage.timestamp,
                        error);
                }];
        }
    }
    // In case we already have a read receipt for this new message (this happens sometimes).
    [OWSReadReceiptManager.sharedManager applyEarlyReadReceiptsForIncomingMessage:incomingMessage
                                                                      transaction:transaction];

    // Update thread preview in inbox
//    [thread touchWithTransaction:transaction];

    [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForIncomingMessage:incomingMessage
                                                                           inThread:thread
                                                                    contactsManager:self.contactsManager
                                                                        transaction:transaction];
    
}

- (void)finalizeIncomingMessage:(TSIncomingMessage *)incomingMessage
                         thread:(TSThread *)thread
                    transaction:(SDSAnyWriteTransaction *)transaction
{
    [incomingMessage anyInsertWithTransaction:transaction];    
    NSData *groupId = nil;
    if(thread.isGroupThread){
        groupId = ((TSGroupThread *)thread).groupModel.groupId;
    }
    DTReadPositionEntity *readPosition = [[DTReadPositionEntity alloc] initWithGroupId:groupId
                                                                                readAt:incomingMessage.serverTimestamp
                                                                         maxServerTime:incomingMessage.serverTimestamp
                                                                      notifySequenceId:incomingMessage.notifySequenceId
                                                                         maxSequenceId:incomingMessage.sequenceId];
    TSMessageReadPosition *messageReadPosition = [[TSMessageReadPosition alloc] initWithUniqueThreadId:thread.uniqueId
                                                                                           recipientId:incomingMessage.authorId
                                                                                          readPosition:readPosition];
    [messageReadPosition updateOrInsertWithTransaction:transaction];
    
    [OWSReadReceiptManager.sharedManager applyEarlyReadReceiptsForIncomingMessage:incomingMessage
                                                                      transaction:transaction];
}

#pragma mark - constructor message data

- (nullable OWSContact *)createContactIfHave:(DSKProtoDataMessage *)dataMessage
                                   timestamp:(NSTimeInterval)timestamp
                                      source:(NSString *)source
                                sourceDevice:(uint32_t)sourceDevice
                                    threadId:(NSString *)threadId
                                       relay:(NSString *)relay
                                 transaction:(SDSAnyWriteTransaction *)transaction {
    
    if (DTParamsUtils.validateArray(dataMessage.contact)) {
        
        NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                 deviceId:sourceDevice
                                                                timestamp:timestamp];
        OWSContact *contact = [OWSContacts contactForDataMessageContact:dataMessage.contact.firstObject
                                                               threadId:threadId
                                                              messageId:messageId
                                                                  relay:relay
                                                            transaction:transaction];
        return contact;
    } else {
        return nil;
    }
}


#pragma mark - helpers

- (BOOL)isDataMessageGroupAvatarUpdate:(DSKProtoDataMessage *)dataMessage
{
    return dataMessage.group && dataMessage.group.unwrappedType == DSKProtoGroupContextTypeUpdate
        && dataMessage.group.avatar;
}

/**
 * @returns
 *   Group or Contact thread for message, creating a new contact thread if necessary,
 *   but never creating a new group thread.
 */
- (nullable TSThread *)threadForEnvelope:(DSKProtoEnvelope *)envelope
                             dataMessage:(DSKProtoDataMessage *)dataMessage
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(transaction);

    if (dataMessage.group) {
        NSData *groupId = dataMessage.group.id;
        OWSAssertDebug(groupId.length > 0);
        TSGroupThread *_Nullable groupThread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
        // This method should only be called from a code path that has already verified
        // that this is a "known" group.
        OWSAssertDebug(groupThread);
        return groupThread;
    } else {
        return [TSContactThread getOrCreateThreadWithContactId:envelope.source transaction:transaction];
    }
}
    
- (nullable TSThread *)threadForEnvelope:(DSKProtoEnvelope *)envelope
                          receiptMessage:(DSKProtoReceiptMessage *)receiptMessage
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(receiptMessage);
    OWSAssertDebug(transaction);
    
    DSKProtoReadPosition *readPosition = receiptMessage.readPosition;
    if (readPosition.hasGroupID) { // 群会话回执
        
        NSData *groupId = readPosition.groupID;
        
        TSGroupThread *_Nullable groupThread;
        // TODO: 服务端统一 proto 里的 groupId 格式
        if (groupId.length == 36) {
            NSString *serverIdString = [[NSString alloc] initWithData:groupId encoding:NSUTF8StringEncoding];
            NSData *localGroupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:serverIdString];
            groupThread = [TSGroupThread getOrCreateThreadWithGroupId:localGroupId transaction:transaction];
        } else {
            groupThread = [TSGroupThread getOrCreateThreadWithGroupId:groupId transaction:transaction];
        }

        OWSAssertDebug(groupThread);
        return groupThread;
    } else { // 1on1 会话回执
        
        return [TSContactThread getOrCreateThreadWithContactId:envelope.source transaction:transaction];
    }
}


@end

NS_ASSUME_NONNULL_END
