//
//  DTMessageParamsBuilder.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import "DTMessageParamsBuilder.h"
#import "TSOutgoingMessage.h"
#import "SignalRecipient.h"
#import "TSGroupThread.h"
#import "TSContactThread.h"
#import "OWSReadReceiptsForSenderMessage.h"
#import "OWSReadReceiptsForLinkedDevicesMessage.h"
#import "DTApnsMessageBuilder.h"
#import "TSAccountManager.h"
#import "DTParamsBaseUtils.h"
#import "OWSLinkedDeviceReadReceipt.h"
#import "DTRecallMessage.h"
#import "OWSOutgoingSentMessageTranscript.h"
#import "DTMessageParams.h"
#import "DTMsgPeerContextParams.h"

@implementation DTMessageParamsBuilder

- (BOOL)checkShouldUseGroupRequestWithThread:(TSThread *)thread
                                   recipient:(SignalRecipient *)recipient{
    return (thread.isGroupThread && ![recipient.recipientId isEqualToString:[TSAccountManager localNumber]]);
}

- (DSKProtoEnvelopeMsgType)msgTypeWithMessage:(TSOutgoingMessage *)message{
    DSKProtoEnvelopeMsgType msgType = DSKProtoEnvelopeMsgTypeMsgNormal;
    
    if([message isKindOfClass:[OWSReadReceiptsForLinkedDevicesMessage class]]){
        msgType = DSKProtoEnvelopeMsgTypeMsgReadReceipt;
    }else if([message isKindOfClass:[OWSOutgoingSentMessageTranscript class]] &&
             !message.isReactionMessage){
        msgType = DSKProtoEnvelopeMsgTypeMsgSyncPreviewable;
    }else if([message isKindOfClass:[OWSOutgoingSyncMessage class]]){
        msgType = DSKProtoEnvelopeMsgTypeMsgSync;
    }else if ([message isKindOfClass:[OWSReadReceiptsForSenderMessage class]]){
        msgType = DSKProtoEnvelopeMsgTypeMsgReadReceipt;
    }else if ([message isRecalMessage]){
        msgType = DSKProtoEnvelopeMsgTypeMsgRecall;
    }
    
    return msgType;
}

- (NSDictionary *)getConversationInfoWithThread:(TSThread *)thread{
    NSMutableDictionary *conversationInfo = @{}.mutableCopy;
    if(thread.isGroupThread && DTParamsUtils.validateString(thread.serverThreadId)){
        conversationInfo[@"gid"] = thread.serverThreadId;
    }else if(DTParamsUtils.validateString(thread.contactIdentifier)){
        conversationInfo[@"number"] = thread.contactIdentifier;
    }
    return conversationInfo.copy;
}

- (NSDictionary * _Nullable)buildParamsWithMessage:(TSOutgoingMessage *)message
                                          toThread:(TSThread *)thread
                                         recipient:(SignalRecipient *)recipient
                                       messageType:(TSWhisperMessageType)messageType
                                    serializedData:(NSData *)serializedData
                              legacySerializedData:(NSData * __nullable)legacySerializedData
                             recipientPeerContexts:(NSArray<DTMsgPeerContextParams *> *)recipientPeerContexts
                                             error:(NSError **)error {
    
    OWSAssertDebug(serializedData);
    
    BOOL readReceipt = [message isKindOfClass:[OWSReadReceiptsForSenderMessage class]];
    
    if([self checkShouldUseGroupRequestWithThread:thread recipient:recipient]){
        recipient = [SignalRecipient new];
    }
    
    NSDictionary *apnsInfo = [[[DTApnsMessageBuilder alloc] initWithMessage:message thread:thread forRecipient:recipient] build];
    
    DTMessageParams *messageParams = nil;
    
    messageParams = [[DTMessageParams alloc] initWithType:messageType
                                                  content:serializedData
                                            legacyContent:legacySerializedData
                                              readReceipt:readReceipt
                                                 apnsInfo:apnsInfo];
    
    messageParams.msgType = [self msgTypeWithMessage:message];
    OWSDetailMessageType type = [message detailMessageType];
    if (type != OWSDetailMessageTypeUnknow){
        messageParams.detailMessageType = type;
    }
   
    if(DTParamsUtils.validateString(message.associatedUniqueThreadId)){
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
            messageParams.conversation = [self getConversationInfoWithThread:[TSThread anyFetchWithUniqueId:message.associatedUniqueThreadId transaction:transaction]];
        }];
    }else{
        messageParams.conversation = [self getConversationInfoWithThread:thread];
    }
    if([message isKindOfClass:[OWSReadReceiptsForLinkedDevicesMessage class]]){
        OWSReadReceiptsForLinkedDevicesMessage *receiptMsg = (OWSReadReceiptsForLinkedDevicesMessage *)message;
        OWSLinkedDeviceReadReceipt *receipt = receiptMsg.readReceipts.firstObject;
        if([receipt.readPosition isKindOfClass:[DTReadPositionEntity class]]){
            messageParams.readPositions = @[receipt.readPosition];
        }
    }
    
    if(messageParams.msgType == DSKProtoEnvelopeMsgTypeMsgRecall){
        messageParams.realSource = message.recall.source;
    }
    
    if(messageParams.msgType == DSKProtoEnvelopeMsgTypeMsgSyncPreviewable &&
       [message isKindOfClass:[OWSOutgoingSentMessageTranscript class]]){
        OWSOutgoingSentMessageTranscript *sentMsg = (OWSOutgoingSentMessageTranscript *)message;
        messageParams.realSource = sentMsg.source;
    }
    
    messageParams.timestamp = message.timestamp;
    messageParams.silent = message.isSilent;
    messageParams.recipients = recipientPeerContexts;
    
    NSError *jsonError;
    NSDictionary *jsonDict = [MTLJSONAdapter JSONDictionaryFromModel:messageParams error:&jsonError];

    if (jsonError) {
        OWSLogError(@"messageParams to json error: %@", jsonError.description);
        OWSProdError([OWSAnalyticsEvents messageSendErrorCouldNotSerializeMessageJson]);
        *error = jsonError;
    }
    return jsonDict;
}

@end
