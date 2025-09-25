//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSIncomingSentMessageTranscript.h"
#import "OWSContact.h"
#import "OWSMessageManager.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import "TSThread.h"
#import "DTCombinedForwardingMessage.h"
#import "DTRecallMessage.h"
#import "DTMention.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSIncomingSentMessageTranscript

- (instancetype)initWithProto:(DSKProtoEnvelope *)envelop
                  dataMessage:(DSKProtoDataMessage *)dataMessage
           hotDataDestination:(NSString *_Nullable)hotDataDestination
                  transaction:(SDSAnyWriteTransaction *)transaction
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _envelopSource = nil;
    _relay = envelop.relay;
    _dataMessage = dataMessage;
//    _rapidFiles = sentProto.rapidFiles;
    _timestamp = envelop.timestamp;
    _expirationStartedAt = envelop.timestamp;
    _expirationDuration = _dataMessage.expireTimer;
    _serverTimestamp = envelop.systemShowTimestamp;
    _sequenceId = envelop.sequenceID;
    _notifySequenceId = envelop.notifySequenceID;
    _body = _dataMessage.body;
    _atPersons = _dataMessage.atPersons;
    
    /// MsgExtra 新增conversationId，仅用于private会话同步的Schedule消息处理
    /// message MsgExtra {
    ///   //only for scheduled private message from me
    ///  optional ConversationId   conversationId  = 3;
    /// }
    
    _recipientId = hotDataDestination;
    _groupId = _dataMessage.group.id;
//    OWSAssertDebug(_recipientId.length > 0 || _groupId.length > 0 );
    _isGroupUpdate = _groupId && (_dataMessage.group.unwrappedType == DSKProtoGroupContextTypeUpdate);
    _isExpirationTimerUpdate = (_dataMessage.flags & DSKProtoDataMessageFlagsExpirationTimerUpdate) != 0;
    _isEndSessionMessage = (_dataMessage.flags & DSKProtoDataMessageFlagsEndSession) != 0;
    _sourceDeviceId = envelop.sourceDevice;
    
    if (_groupId) {
        _thread = [TSGroupThread getOrCreateThreadWithGroupId:_groupId transaction:transaction];
    } else {
        _thread = [TSContactThread getOrCreateThreadWithContactId:_recipientId transaction:transaction];
    }
    
    if (_dataMessage.quote) {
        NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:envelop.source
                                                                 deviceId:envelop.sourceDevice
                                                                timestamp:envelop.timestamp];
        _quotedMessage = [TSQuotedMessage quotedMessageForQuoteProto:_dataMessage.quote
                                                              thread:_thread
                                                           messageId:messageId
                                                               relay:_relay
                                                         transaction:transaction];
    }
    
    NSString *source = envelop.source;
    
    if(_dataMessage.forwardContext && _dataMessage.forwardContext.forwards.count){
        
        NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                 deviceId:_sourceDeviceId
                                                                timestamp:envelop.timestamp];
        DSKProtoDataMessageForward *forword = [DTCombinedForwardingMessage
                                               buildRootForwardProtoWithForwardContextProto:_dataMessage.forwardContext
                                               timestamp:_timestamp
                                               serverTimestamp:envelop.systemShowTimestamp
                                               author:source
                                               body:_body];
        _forwardingMessage = [DTCombinedForwardingMessage
                              forwardingMessageForDataMessage:forword
                              threadId:_thread.uniqueId
                              messageId:messageId
                              relay:_relay
                              transaction:transaction];
    }
    
    _contact = [self createContactIfHave:_dataMessage
                               timestamp:envelop.timestamp
                                  source:source
                            sourceDevice:_sourceDeviceId
                                threadId:_thread.uniqueId
                                   relay:_relay
                             transaction:transaction];

    _recall = [DTRecallMessage recallWithDataMessage:_dataMessage];
    
    return self;
}

- (instancetype)initWithProto:(DSKProtoSyncMessageSent *)sentProto
                       source:(NSString *)source
               sourceDeviceId:(UInt32)sourceDeviceId
                        relay:(nullable NSString *)relay
              serverTimestamp:(uint64_t)serverTimestamp
                  transaction:(SDSAnyWriteTransaction *)transaction
{
    self = [super init];
    if (!self) {
        return self;
    }

    _relay = relay;
    _dataMessage = sentProto.message;
    _rapidFiles = sentProto.rapidFiles;
    _recipientId = sentProto.destination;
    _timestamp = sentProto.timestamp;
    _expirationStartedAt = sentProto.expirationStartTimestamp;
    _expirationDuration = sentProto.message.expireTimer;
    _serverTimestamp = serverTimestamp;
    _sequenceId = sentProto.sequenceID;
    _notifySequenceId = sentProto.notifySequenceID;
    _body = _dataMessage.body;
    _atPersons = _dataMessage.atPersons;
    _groupId = _dataMessage.group.id;
    _isGroupUpdate = _groupId && (_dataMessage.group.unwrappedType == DSKProtoGroupContextTypeUpdate);
    _isExpirationTimerUpdate = (_dataMessage.flags & DSKProtoDataMessageFlagsExpirationTimerUpdate) != 0;
    _isEndSessionMessage = (_dataMessage.flags & DSKProtoDataMessageFlagsEndSession) != 0;
    
    _sourceDeviceId = sourceDeviceId;
    
    if (_dataMessage.mentions != nil && _dataMessage.mentions.count > 0) {
        _mentions = [DTMention mentionsWithProto:_dataMessage];
    }

    if (_groupId) {
        _thread = [TSGroupThread getOrCreateThreadWithGroupId:_groupId transaction:transaction];
    } else {
        _thread = [TSContactThread getOrCreateThreadWithContactId:_recipientId transaction:transaction];
    }

    if (_dataMessage.quote) {
        NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                 deviceId:_sourceDeviceId
                                                                timestamp:sentProto.timestamp];
        
        _quotedMessage =
        [TSQuotedMessage quotedMessageForQuoteProto:_dataMessage.quote
                                             thread:_thread
                                          messageId:messageId
                                              relay:_relay
                                        transaction:transaction];
    }
    
    if(_dataMessage.forwardContext && _dataMessage.forwardContext.forwards.count){
        DSKProtoDataMessageForward *forward = [DTCombinedForwardingMessage buildRootForwardProtoWithForwardContextProto:_dataMessage.forwardContext 
                                                                                                              timestamp:_timestamp
                                                                                                        serverTimestamp:serverTimestamp
                                                                                                                 author:source
                                                                                                                   body:_body];
        NSString *messageId = [TSInteraction generateUniqueIdWithAuthorId:source
                                                                 deviceId:_sourceDeviceId
                                                                timestamp:sentProto.timestamp];
        _forwardingMessage = [DTCombinedForwardingMessage
                              forwardingMessageForDataMessage:forward
                              threadId:_thread.uniqueId
                              messageId:messageId
                              relay:_relay
                              transaction:transaction];
    }
    
    _contact = [self createContactIfHave:_dataMessage
                               timestamp:sentProto.timestamp
                                  source:source
                            sourceDevice:_sourceDeviceId
                                threadId:_thread.uniqueId
                                   relay:relay
                             transaction:transaction];
    
    _recall = [DTRecallMessage recallWithDataMessage:_dataMessage];
    
    return self;
}

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

- (NSArray<DSKProtoAttachmentPointer *> *)attachmentPointerProtos
{
    if (self.isGroupUpdate && self.dataMessage.group.avatar) {
        return @[ self.dataMessage.group.avatar ];
    } else {
        return self.dataMessage.attachments;
    }
}

@end

NS_ASSUME_NONNULL_END
