//
//  DTRecallOutgoingMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import "DTRecallOutgoingMessage.h"
#import "SSKCryptography.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTRecallOutgoingMessage

- (DTRealSourceEntity *)realSource{
    return self.recall.source;
}

+ (instancetype)recallOutgoingMessageWithTimestamp:(uint64_t)timestamp
                                            recall:(DTRecallMessage *)recall
                                          inThread:(nullable TSThread *)thread
                                  expiresInSeconds:(uint32_t)expiresInSeconds{
    DTRecallOutgoingMessage *message = [[DTRecallOutgoingMessage alloc] initOutgoingMessageWithTimestamp:timestamp
                                                                                                inThread:thread
                                                                                             messageBody:nil
                                                                                               atPersons:nil
                                                                                                mentions:nil
                                                                                           attachmentIds:[NSMutableArray new]
                                                                                        expiresInSeconds:expiresInSeconds
                                                                                         expireStartedAt:0
                                                                                          isVoiceMessage:NO
                                                                                        groupMetaMessage:TSGroupMessageUnspecified
                                                                                           quotedMessage:nil
                                                                                       forwardingMessage:nil
                                                                                            contactShare:nil];
    message.recall = recall;
    return message;
}

- (nullable DSKProtoDataMessageRecall *)dataMessageRecall{
    
    if(!self.realSource){
        return nil;
    }
    
    DSKProtoDataMessageRecallBuilder *recallBuilder = [DSKProtoDataMessageRecall builder];
    recallBuilder.source = [DTRealSourceEntity protoWithRealSourceEntity:self.realSource];
    return [recallBuilder buildAndReturnError:nil];
}

- (DSKProtoDataMessageBuilder *)dataMessageBuilder{
    DSKProtoDataMessageBuilder *builder = [super dataMessageBuilder];
    
    DSKProtoDataMessageRecall *recall = [self dataMessageRecall];
    if(recall){
        [builder setRecall:recall];
        builder.requiredProtocolVersion = DSKProtoDataMessageProtocolVersionRecall;
    }
    return builder;
}

- (BOOL)isSilent
{
    return NO;
}

- (BOOL)shouldBeSaved
{
    return NO;
}

- (NSString *)collapseId{
    if(![self.recall checkIntegrity]){
        return @"";
    }
    NSString *inputString = [NSString stringWithFormat:@"%lld%@%u",self.recall.source.timestamp, self.recall.source.source, self.recall.source.sourceDevice];
    return [SSKCryptography getMd5WithString:inputString];
}

@end
