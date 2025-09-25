//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSReadReceiptsForSenderMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "SignalRecipient.h"
#import "DTReadPositionEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSReadReceiptsForSenderMessage ()

@property (nonatomic, readonly) NSArray<NSNumber *> *messageTimestamps;
@property (nonatomic, readonly) DTReadPositionEntity *readPosition;


@end

#pragma mark -

@implementation OWSReadReceiptsForSenderMessage

- (instancetype)initWithThread:(nullable TSThread *)thread
             messageTimestamps:(NSArray<NSNumber *> *)messageTimestamps
                  readPosition:(DTReadPositionEntity *)readPosition
               messageModeType:(TSMessageModeType)messageModeType
{
    self = [super initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                          inThread:thread
                                       messageBody:nil
                                         atPersons:nil
                                          mentions:nil
                                     attachmentIds:[NSMutableArray new]
                                  expiresInSeconds:0
                                   expireStartedAt:0
                                    isVoiceMessage:NO
                                  groupMetaMessage:TSGroupMessageUnspecified
                                     quotedMessage:nil
                                 forwardingMessage:nil
                                      contactShare:nil];
    if (!self) {
        return self;
    }

    _messageTimestamps = [messageTimestamps copy];
    _readPosition = readPosition;
    self.messageModeType = messageModeType;

    return self;
}

#pragma mark - TSOutgoingMessage overrides

- (BOOL)shouldSyncTranscript
{
    return NO;
}

- (BOOL)isSilent
{
    // Avoid "phantom messages" for "recipient read receipts".

    return YES;
}

// TODO: messageSender 里取该值判断，但对于此不可见消息类没用, 此类消息的发送失败需要单独处理
- (TSOutgoingMessageState)messageState {
    return TSOutgoingMessageStateSent;
}

- (nullable NSData *)buildPlainTextData:(SignalRecipient *)recipient
{
    OWSAssertDebug(recipient);

    DSKProtoContentBuilder *contentBuilder = [DSKProtoContent builder];
    [contentBuilder setReceiptMessage:[self buildReceiptMessage:recipient.recipientId]];
    
    NSError *error;
    NSData *data = [contentBuilder buildSerializedDataAndReturnError:&error];
    if (error) {
        OWSLogError(@"%@ error: %@.", self.logTag, error);
    }
    return data;
}

- (nullable DSKProtoReceiptMessage *)buildReceiptMessage:(NSString *)recipientId
{
    DSKProtoReceiptMessageBuilder *builder = [DSKProtoReceiptMessage builder];

    [builder setType:DSKProtoReceiptMessageTypeRead];
    OWSAssertDebug(self.messageTimestamps.count > 0);
    for (NSNumber *messageTimestamp in self.messageTimestamps) {
        [builder addTimestamp:[messageTimestamp unsignedLongLongValue]];
    }
    
    DSKProtoDataMessageMessageMode messageMode = DSKProtoDataMessageMessageModeNormal;
    if (self.messageModeType == TSMessageModeTypeConfidential) {
        messageMode = DSKProtoDataMessageMessageModeConfidential;
    }
    [builder setMessageMode:messageMode];
    
    if (self.readPosition) {
        DSKProtoReadPositionBuilder *readPositionBuilder = [DSKProtoReadPosition builder];
        if (self.readPosition.groupId) {
            [readPositionBuilder setGroupID:self.readPosition.groupId];
        }
        
        if (self.readPosition.readAt) {
            [readPositionBuilder setReadAt:self.readPosition.readAt];
        }
        
        if (self.readPosition.maxServerTime) {
            [readPositionBuilder setMaxServerTime:self.readPosition.maxServerTime];
        }
        
        if (self.readPosition.maxNotifySequenceId) {
            [readPositionBuilder setMaxNotifySequenceID:self.readPosition.maxNotifySequenceId];
        }
        
        DSKProtoReadPosition *readPosition = [readPositionBuilder buildAndReturnError:nil];
        
        if (readPosition) {
            [builder setReadPosition:readPosition];
        }
    }

    return [builder buildAndReturnError:nil];
}

#pragma mark - TSYapDatabaseObject overrides

- (BOOL)shouldBeSaved
{
    return NO;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@ with message timestamps: %zd", self.logTag, self.messageTimestamps.count];
}

@end

NS_ASSUME_NONNULL_END
