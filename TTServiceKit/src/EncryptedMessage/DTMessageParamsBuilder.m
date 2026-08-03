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
#import <TTServiceKit/TTServiceKit-Swift.h>

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
    }else if ([message isKindOfClass:[TSOutgoingForwardNoticeMessage class]]) {
        msgType = DSKProtoEnvelopeMsgTypeMsgForwardNotice;
    }else if ([message isKindOfClass:[TSOutgoingActivityNoticeMessage class]]) {
        msgType = DSKProtoEnvelopeMsgTypeMsgActivityNotice;
    }else if ([message isKindOfClass:[TSOutgoingGroupKeyMessage class]]) {
        msgType = DSKProtoEnvelopeMsgTypeMsgGroupKey;
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
                                       syncContent:(NSData * __nullable)syncContent
                                             error:(NSError **)error {
    
    OWSAssertDebug(serializedData);
    
    BOOL readReceipt = [message isKindOfClass:[OWSReadReceiptsForSenderMessage class]];
    
    if([self checkShouldUseGroupRequestWithThread:thread recipient:recipient]){
        recipient = [SignalRecipient new];
    }
    
    // 一次读事务内完成 APNs builder 的群名解析和 associated thread 查询,避免 builder 内部重入事务
    __block NSDictionary *apnsInfo = nil;
    __block NSDictionary *associatedConversation = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        if (![message isKindOfClass:[TSOutgoingForwardNoticeMessage class]]
            && ![message isKindOfClass:[TSOutgoingActivityNoticeMessage class]]
            && ![message isKindOfClass:[TSOutgoingGroupKeyMessage class]]) {
            apnsInfo = [[[DTApnsMessageBuilder alloc] initWithMessage:message
                                                               thread:thread
                                                         forRecipient:recipient
                                                          transaction:transaction] build];
        }
        if (DTParamsUtils.validateString(message.associatedUniqueThreadId)) {
            TSThread *associatedThread = [TSThread anyFetchWithUniqueId:message.associatedUniqueThreadId transaction:transaction];
            associatedConversation = [self getConversationInfoWithThread:associatedThread];
        }
    }];

    DTMessageParams *messageParams = [[DTMessageParams alloc] initWithType:messageType
                                                                   content:serializedData
                                                             legacyContent:legacySerializedData
                                                               readReceipt:readReceipt
                                                                  apnsInfo:apnsInfo];

    messageParams.msgType = [self msgTypeWithMessage:message];
    OWSDetailMessageType type = [message detailMessageType];
    if (type != OWSDetailMessageTypeUnknow){
        messageParams.detailMessageType = type;
    }

    messageParams.conversation = associatedConversation ?: [self getConversationInfoWithThread:thread];
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

    // Set syncContent if provided
    if (syncContent) {
        messageParams.syncContent = [syncContent base64EncodedString];
    }

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
