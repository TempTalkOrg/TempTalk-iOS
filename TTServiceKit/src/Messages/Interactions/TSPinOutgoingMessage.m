//
//  TSPinOutgoingMessage.m
//  TTServiceKit
//
//  Created by Ethan on 2022/3/31.
//

#import "TSPinOutgoingMessage.h"
#import "TSGroupThread.h"
#import "TSAccountManager.h"
#import "TSIncomingMessage.h"
#import "OWSDevice.h"

@implementation TSPinOutgoingMessage

- (TSGroupChatMode)groupChatMode {
    
    return TSGroupChatModePin;
}

- (TSOutgoingMessageState)messageState {
    
    return TSOutgoingMessageStateSent;
}

- (NSArray<NSString *> *)recipientIds {
    
    TSGroupThread *groupThread = (TSGroupThread *)self.threadWithSneakyTransaction;
    NSString *serverGroupId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    NSMutableArray *recipientIds = [super.recipientIds mutableCopy];
    [recipientIds addObject:serverGroupId];
    
    return recipientIds.copy;
}

- (NSString *)source {
    
    TSMessage *contentMessage = self.pinMessages.firstObject;
    NSString *authorId = @"";
    uint32_t sourceDeviceId = 0;
    if ([contentMessage isKindOfClass:TSIncomingMessage.class]) {
        TSIncomingMessage *incomingMessage = (TSIncomingMessage *)contentMessage;
        authorId = incomingMessage.authorId;
        sourceDeviceId = incomingMessage.sourceDeviceId;
    }
    if ([contentMessage isKindOfClass:TSOutgoingMessage.class]) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)contentMessage;
        authorId = [TSAccountManager localNumber];
        sourceDeviceId = outgoingMessage.sourceDeviceId ?: [OWSDevice currentDeviceId];
    }

    return [NSString stringWithFormat:@"%@:%u:%lld", authorId, sourceDeviceId, contentMessage.timestamp];
}

@end
