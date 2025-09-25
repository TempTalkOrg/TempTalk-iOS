//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSEndSessionMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSEndSessionMessage

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp inThread:(nullable TSThread *)thread
{
    return [super initOutgoingMessageWithTimestamp:timestamp
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
}

- (BOOL)shouldBeSaved
{
    return NO;
}

- (DSKProtoDataMessageBuilder *)dataMessageBuilder
{
    DSKProtoDataMessageBuilder *builder = [super dataMessageBuilder];
    [builder setTimestamp:self.timestamp];
    [builder setFlags:DSKProtoDataMessageFlagsEndSession];

    return builder;
}

@end

NS_ASSUME_NONNULL_END
