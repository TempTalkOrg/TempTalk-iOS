//
//  DTScreenShotOutgoingMessage.m
//  TTServiceKit
//
//  Created by User on 2023/2/13.
//

#import "DTScreenShotOutgoingMessage.h"
#import "DTRealSourceEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTScreenShotOutgoingMessage

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                       realSource:(DTRealSourceEntity *)realSource
                         inThread:(nullable TSThread *)thread {
    self = [super initOutgoingMessageWithTimestamp:timestamp
                                          inThread:thread
                                       messageBody:nil
                                         atPersons:nil
                                          mentions:nil
                                     attachmentIds:@[].mutableCopy
                                  expiresInSeconds:thread.messageExpiresInSeconds
                                   expireStartedAt:0
                                    isVoiceMessage:NO
                                  groupMetaMessage:TSGroupMessageUnspecified
                                     quotedMessage:nil
                                 forwardingMessage:nil
                                      contactShare:nil];
    self.realSource = realSource;
    return self;
}

- (OWSDetailMessageType)detailMessageType {
    return OWSDetailMessageTypeScreenshot;
}

- (DSKProtoDataMessageScreenShotBuilder *)screenShotBuilder{

    if(!self.realSource){ return nil; }
    
    DSKProtoDataMessageScreenShotBuilder *builder = [DSKProtoDataMessageScreenShot builder];
    builder.source = [DTRealSourceEntity protoWithRealSourceEntity:self.realSource];
    return builder;
}

- (DSKProtoDataMessageBuilder *)dataMessageBuilder{
    DSKProtoDataMessageBuilder *builder = [super dataMessageBuilder];

    DSKProtoDataMessageScreenShotBuilder *screenShotBuilder = [self screenShotBuilder];
    if(screenShotBuilder) {
        [builder setScreenShot:[screenShotBuilder buildAndReturnError:nil]];
        [builder setRequiredProtocolVersion:DSKProtoDataMessageProtocolVersionScreenShot];
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

@end
