//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOutgoingSyncMessage.h"
#import "SSKCryptography.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "TSThread.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSOutgoingSyncMessage

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (instancetype)initSyncMessageWithTimestamp:(uint64_t)timestamp {
    self = [super initOutgoingMessageWithTimestamp:timestamp
                                         inThread:nil
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

    return self;
}

- (BOOL)shouldBeSaved
{
    return NO;
}

- (BOOL)shouldSyncTranscript
{
    return NO;
}

- (BOOL)isSilent{
    return YES;
}

// This method should not be overridden, since we want to add random padding to *every* sync message
- (nullable DSKProtoSyncMessage *)buildSyncMessage
{
    DSKProtoSyncMessageBuilder *builder = [self syncMessageBuilder];
    
    // Add a random 1-512 bytes to obscure sync message type
    size_t paddingBytesLength = arc4random_uniform(512) + 1;
    builder.padding = [SSKCryptography generateRandomBytes:paddingBytesLength];

    return [builder buildAndReturnError:nil];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    OWSFailDebug(@"Abstract method should be overridden in subclass.");
    return [DSKProtoSyncMessage builder];
}

- (nullable NSData *)buildPlainTextData:(SignalRecipient *)recipient
{
    DSKProtoContentBuilder *contentBuilder = [DSKProtoContent builder];
    [contentBuilder setSyncMessage:[self buildSyncMessage]];
    
    NSError *error;
    if (error) {
        OWSLogError(@"%@ error:%@.", self.logTag, error);
    }
    
    return [contentBuilder buildSerializedDataAndReturnError:&error];
}

@end

NS_ASSUME_NONNULL_END
