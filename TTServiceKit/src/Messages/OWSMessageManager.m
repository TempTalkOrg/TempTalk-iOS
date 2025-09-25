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
                    
                    // TODO: 预览消息入库
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
            NSError *error;
            NSArray<TSOutgoingMessage *> *outgoingmessages = (NSArray<TSOutgoingMessage *> *)[InteractionFinder interactionsWithTimestamp:maxTimestamp.unsignedLongValue filter:^BOOL(TSInteraction * interaction) {
                return ([interaction isKindOfClass:[TSOutgoingMessage class]]);
            } transaction:transaction error:&error];
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
            
            if (outgoingmessage.isConfidentialMessage && receiptMessage.messageMode == 1) {
                NSString *threadId = outgoingmessage.uniqueThreadId;
                TSThread *thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
                if (thread.isGroupThread) {
                    AnyMessageReadPositonFinder *readPositionFinder = [AnyMessageReadPositonFinder new];
                    NSError *error;
                    __block NSInteger readCount = 0;
                    [readPositionFinder enumerateRecipientReadPositionsWithUniqueThreadId:thread.uniqueId
                                                                              transaction:transaction
                                                                                    error:&error
                                                                                    block:^(TSMessageReadPosition * readPosition) {
                        TSOutgoingMessageRecipientState *oldRecipientState = outgoingmessage.recipientStateMap[readPosition.recipientId];
                        if(oldRecipientState &&
                           oldRecipientState.state == OWSOutgoingMessageRecipientStateSent &&
                           readPosition.maxServerTime >= outgoingmessage.timestampForSorting &&
                           oldRecipientState.readTimestamp == nil){
                            readCount ++;
                        }
                    }];
                    if (outgoingmessage.recipientIds.count == readCount) {
                        [outgoingmessage anyRemoveWithTransaction:transaction];
                    }
                } else {
                    [outgoingmessage anyRemoveWithTransaction:transaction];
                }
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
        TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:dataMessage.group.id transaction:transaction];
        if (dataMessage.group && (!groupThread || (groupThread.groupModel && groupThread.groupModel.version == 0))) {
            //获取群组信息
            [self.notifyMessageHandler.groupUpdateMessageProcessor requestGroupInfoWithGroupId:dataMessage.group.id
                                                                                 targetVersion:0
                                                                             needSystemMessage:NO
                                                                                      generate:false
                                                                                      envelope:envelope
                                                                                   transaction:transaction
                                                                                    completion:^(SDSAnyWriteTransaction * transaction) {
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
        
        // 3.1.3
        // 如果同步消息是发送到 note 的，serverTimestamp 取 envelope 上的 systemShowTimestamp，
        // 同步 note 的 syncMessage.sent 中的 serverTimestamp 是端上随便设置的
        BOOL isSendToNote = [localNumber isEqualToString:syncMessage.sent.destination];
        uint64_t syncMessageServerTimestamp = isSendToNote ? envelope.systemShowTimestamp : syncMessage.sent.serverTimestamp;
        
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
            // We respond asynchronously because populating the sync message will
            // create transactions and it's not practical (due to locking in the OWSIdentityManager)
            // to plumb our transaction through.
            //
            // In rare cases this means we won't respond to the sync request, but that's
            // acceptable.
            /*
            __block id <DataSource> dataSource = nil;
            OWSSyncContactsMessage *syncContactsMessage =
            [[OWSSyncContactsMessage alloc] initWithSignalAccounts:self.contactsManager.signalAccounts
                                                   identityManager:self.identityManager
                                                    profileManager:self.profileManager];
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                NSError *dError;
                dataSource = [DataSourcePath dataSourceWritingSyncMessageData:[syncContactsMessage buildPlainTextAttachmentDataWithTransaction:transaction] error:&dError];
                if (dError) {
                    OWSLogDebug(@"contacts sync message data source error: %@", dError);
                }
            } completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) completion:^{
                if (dataSource.dataLength < 1) {
                    // Don't bother sending empty sync messages if we have no contacts to sync.
                    OWSLogInfo(@"skipping empty contact sync message.");
                    return;
                }
                
                [self.messageSender enqueueTemporaryAttachment:dataSource
                                                   contentType:OWSMimeTypeApplicationOctetStream
                                                     inMessage:syncContactsMessage
                                                       success:^{
                    OWSLogInfo(@"Successfully sent Contacts response syncMessage.");
                }
                                                       failure:^(NSError *error) {
                    OWSLogError(@"Failed to send Contacts response syncMessage with error: %@", error);
                }];
            }];
            */
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeGroups) {
            
            OWSLogInfo(@"ignore sync request groups message.");
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeBlocked) {
            OWSLogInfo(@"%@ Received request for block list", self.logTag);
//            [self.blockingManager syncBlockedPhoneNumbers];
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeConfiguration) {
            /*
            BOOL areReadReceiptsEnabled =
                [[OWSReadReceiptManager sharedManager] areReadReceiptsEnabledWithTransaction:transaction];
            OWSSyncConfigurationMessage *syncConfigurationMessage =
                [[OWSSyncConfigurationMessage alloc] initWithReadReceiptsEnabled:areReadReceiptsEnabled];
            [self.messageSender enqueueMessage:syncConfigurationMessage
                success:^{
                    OWSLogInfo(@"%@ Successfully sent Configuration response syncMessage.", self.logTag);
                }
                failure:^(NSError *error) {
                    OWSLogError(
                        @"%@ Failed to send Configuration response syncMessage with error: %@", self.logTag, error);
                }];
             */
        } else {
            OWSLogWarn(@"%@ ignoring unsupported sync request message", self.logTag);
        }
    } else if (syncMessage.blocked) {
        /*
        NSArray<NSString *> *blockedPhoneNumbers = [syncMessage.blocked.numbers copy];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.blockingManager setBlockedPhoneNumbers:blockedPhoneNumbers sendSyncMessage:NO];
        });
         */
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
    }
    else if (syncMessage.conversationArchive) { // 热数据不会记
        [DTMessageArchiveProcessor processIncomingSyncMessageWithArchiveMessage:syncMessage.conversationArchive serverTimestamp:envelope.systemShowTimestamp transaction:transaction];
    } else {
        OWSLogWarn(@"%@ Ignoring unsupported sync message.", self.logTag);
    }
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

    uint32_t expiresInSeconds = [gThread messageExpiresInSeconds];
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
    NSString *nameString = [self.contactsManager displayNameForPhoneIdentifier:envelope.source];
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
    
    BOOL duplicateRecallMessage = [RecallFinder duplicateRecallMessageWithTimestamp:recall.source.timestamp
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
        
        OWSLogInfo(@"===== originalMessage timestamp: %llu, serverTimestamp: %llu =====", originMessage.timestamp, originMessage.serverTimestamp);
        
        OWSLogInfo(@"===== recall source timestamp:%llu, servertimestamp: %llu =====", recall.source.timestamp, recall.source.serverTimestamp);
        
        NSString *nameString = [self.contactsManager displayNameForPhoneIdentifier:source transaction:transaction];
        nameString = [NSString stringWithFormat:@"\"%@\"", nameString];
        NSAttributedString *customString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE",nil), nameString]];
        
        TSInfoMessage *recallInfoMessage = [[TSInfoMessage alloc] initWithTimestamp:recall.source.timestamp
                                                                    serverTimestamp:envelope.systemShowTimestamp
                                                                           inThread:thread
                                                                           authorId:source
                                                                           deviceId:sourceDevice
                                                                   expiresInSeconds:dataMessage.expireTimer
                                                                      customMessage:customString];
        recallInfoMessage.serverTimestamp = originMessage.serverTimestamp?originMessage.serverTimestamp:recall.source.serverTimestamp;
        recallInfoMessage.recallPreview = customString.string;
        recallInfoMessage.recall = recall;
        if(originMessage){
            recallInfoMessage.uniqueId = originMessage.uniqueId;
            if(!recallInfoMessage.grdbId && originMessage.grdbId){
                [recallInfoMessage updateRowId:originMessage.grdbId.longLongValue];
            }
        }
        
        // TODO: check whisperMessageType
        recallInfoMessage.whisperMessageType = envelope.unwrappedType;
        
        if(job.envelopeProto.lastestMsgFlag){ // 拉取离线会话需要更新会话 lastestMsg
            if(!recallInfoMessage.grdbId){
                [recallInfoMessage updateRowId:100];
            }
            OWSLogInfo(@"%@ handling lastestMsgFlag  envelope: %@", self.logTag, [self descriptionForEnvelope:envelope]);
            [thread updateWithLastMessage:recallInfoMessage isInserted:YES transaction:transaction];
        }else{

            // 覆盖原始消息
            [recallInfoMessage anyUpsertWithTransaction:transaction];
            // 收到撤回消息时，删除原始消息索引
            if (originMessage) {
                [[FullTextSearchFinder new] modelWasRemovedObjcWithModel:originMessage transaction:transaction];
            }
        }
        OWSLogInfo(@"===== recall messaage timestamp:%llu, servertimestamp: %llu =====", recallInfoMessage.timestamp, recallInfoMessage.serverTimestamp);
        
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
        // If the message arrives later than the archived notification, archive it directly
        // Messages are no longer stored in "model_TSInteraction" table
        // TODO: 目前message 没有合适的方式直接入归档消息的table，后面数据库优化后调整
        [[OWSArchivedMessageJob sharedJob] checkAndArchiveWithMessage:recallInfoMessage withThread:thread transaction:transaction];
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
    
    // If the message arrives later than the archived notification, archive it directly
    // Messages are no longer stored in "model_TSInteraction" table, but this situation needs to be completed in the subsequent database optimization process
    // TODO: 目前message 没有合适的方式直接入归档消息的table，后面数据库优化后调整
    [[OWSArchivedMessageJob sharedJob] checkAndArchiveWithMessage:incomingMessage withThread:thread transaction:transaction];
    
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

//- (BOOL)checkAndArchiveMessage:(TSMessage *)message withThread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction {
//
//    OWSArchivedMessageJob *archivedMessageJob = [OWSArchivedMessageJob sharedJob];
//
//    if ([archivedMessageJob needArchiveMessageWithMessage:message withThread:thread transaction:transaction]) {
//        [[OWSArchivedMessageJob sharedJob] directInsertToArchivedMessageTableWithMessage:message transaction:transaction];
//        return true;
//    }
//
//    return false;
//}

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
