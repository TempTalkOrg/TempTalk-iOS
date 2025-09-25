//
//  DTReactionOutgoingMessage.m
//  TTServiceKit
//
//  Created by Ethan on 2022/5/20.
//

#import "DTReactionOutgoingMessage.h"
#import "DTReactionMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTReactionOutgoingMessage

+ (instancetype)reactionOutgoingMessageWithTimestamp:(uint64_t)timestamp
                        reactionMessage:(DTReactionMessage *)reactionMessage
                                 thread:(TSThread *)thread {
    
    DTReactionOutgoingMessage *outgoingMessage =
    [[DTReactionOutgoingMessage alloc] initOutgoingMessageWithTimestamp:timestamp
                                                               inThread:thread
                                                            messageBody:nil
                                                              atPersons:nil
                                                               mentions:nil
                                                          attachmentIds:@[].mutableCopy
                                                       expiresInSeconds:0
                                                        expireStartedAt:0
                                                         isVoiceMessage:NO
                                                       groupMetaMessage:TSGroupMessageUnspecified
                                                          quotedMessage:nil
                                                      forwardingMessage:nil
                                                           contactShare:nil];
    outgoingMessage.reactionMessage = reactionMessage;
    
    return outgoingMessage;
}

- (DSKProtoDataMessageBuilder *)dataMessageBuilder {
    
    DSKProtoDataMessageBuilder *builder = [super dataMessageBuilder];
    DSKProtoDataMessageReaction *reactionProto = [DTReactionMessage reactionProtoWithReaction:self.reactionMessage];
    if (reactionProto) {
        [builder setReaction:reactionProto];
        builder.requiredProtocolVersion = DSKProtoDataMessageProtocolVersionReaction;
    }
    
    return builder;
}

- (BOOL)isSilent {
    
    return YES;
}

- (BOOL)shouldBeSaved {
    
    return NO;
}

@end
