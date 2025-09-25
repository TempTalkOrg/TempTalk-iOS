//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSReadReceiptsForLinkedDevicesMessage.h"
#import "OWSLinkedDeviceReadReceipt.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSReadReceiptsForLinkedDevicesMessage ()

@property (nonatomic, readwrite) NSArray<OWSLinkedDeviceReadReceipt *> *readReceipts;

@end

@implementation OWSReadReceiptsForLinkedDevicesMessage

- (instancetype)initWithReadReceipts:(NSArray<OWSLinkedDeviceReadReceipt *> *)readReceipts
{
    self = [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]];
    if (!self) {
        return self;
    }

    _readReceipts = [readReceipts copy];
    
    self.whisperMessageType = TSEncryptedWhisperMessageType;
    
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    for (OWSLinkedDeviceReadReceipt *readReceipt in self.readReceipts) {
        DSKProtoSyncMessageReadBuilder *readProtoBuilder =
            [DSKProtoSyncMessageRead builder];
        DSKProtoDataMessageMessageMode messageMode = DSKProtoDataMessageMessageModeNormal;
        if (self.messageModeType == TSMessageModeTypeConfidential) {
            messageMode = DSKProtoDataMessageMessageModeConfidential;
        }
        [readProtoBuilder setMessageMode:messageMode];
        [readProtoBuilder setSender:readReceipt.senderId];
        [readProtoBuilder setTimestamp:readReceipt.messageIdTimestamp];
        DTReadPositionEntity *readPositionEntity = readReceipt.readPosition;
        if(readPositionEntity){
            DSKProtoReadPositionBuilder *readPositionBuilder = [DSKProtoReadPosition builder];
            [readPositionBuilder setGroupID:readPositionEntity.groupId];
            [readPositionBuilder setReadAt:readPositionEntity.readAt];
            [readPositionBuilder setMaxServerTime:readPositionEntity.maxServerTime];
            [readPositionBuilder setMaxNotifySequenceID:readPositionEntity.maxNotifySequenceId];
            [readProtoBuilder setReadPosition:[readPositionBuilder buildAndReturnError:nil]];
        }
        [syncMessageBuilder addRead:[readProtoBuilder buildAndReturnError:nil]];
    }

    return syncMessageBuilder;
}

#pragma mark - TSOutgoingMessage overrides

// TODO: messageSender 里取该值判断，但对于此不可见消息类没用, 此类消息的发送失败需要单独处理
- (TSOutgoingMessageState)messageState {
    return TSOutgoingMessageStateSent;
}

@end

NS_ASSUME_NONNULL_END
