//
//  DTCardOutgoingMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/18.
//

#import "DTCardOutgoingMessage.h"
#import "TSThread.h"
#import "OWSDevice.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTCardOutgoingMessage

+ (instancetype)cardOutgoingMessageWithTimestamp:(uint64_t)timestamp
                                            card:(DTCardMessageEntity *)card
                                            body:(NSString *)body
                                       atPersons:(NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                        inThread:(nullable TSThread *)thread
                                expiresInSeconds:(uint32_t)expiresInSeconds{

    DTCardOutgoingMessage *message = [[DTCardOutgoingMessage alloc] initOutgoingMessageWithTimestamp:timestamp
                                                                                                inThread:thread
                                                                                             messageBody:body
                                                                                               atPersons:atPersons
                                                                                            mentions:mentions
                                                                                           attachmentIds:[NSMutableArray new]
                                                                                        expiresInSeconds:expiresInSeconds
                                                                                         expireStartedAt:0
                                                                                          isVoiceMessage:NO
                                                                                        groupMetaMessage:TSGroupMessageUnspecified
                                                                                           quotedMessage:nil
                                                                                       forwardingMessage:nil
                                                                                            contactShare:nil];
    message.card = card;
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    return message;
}

- (DSKProtoCard *)cardProto{
    return [DTCardMessageEntity cardProtoWithEntity:self.card];
}

- (DSKProtoDataMessageBuilder *)dataMessageBuilder{
    DSKProtoDataMessageBuilder *builder = [super dataMessageBuilder];
    
    DSKProtoCard *cardProto = [self cardProto];
    if(cardProto){
        [builder setCard:cardProto];
        builder.requiredProtocolVersion = DSKProtoDataMessageProtocolVersionCard;
    }
    return builder;
}

@end
