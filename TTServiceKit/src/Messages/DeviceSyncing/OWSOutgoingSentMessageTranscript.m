//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOutgoingSentMessageTranscript.h"
#import "TSOutgoingMessage.h"
#import "TSThread.h"
#import "DTRapidFile.h"
#import "OWSDevice.h"
#import "TSAccountManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSOutgoingMessage (OWSOutgoingSentMessageTranscript)

/**
 * Normally this is private, but we need to embed this
 * data structure within our own.
 *
 * recipientId is nil when building "sent" sync messages for messages
 * sent to groups.
 */
- (DSKProtoDataMessage *)buildDataMessage:(NSString *_Nullable)recipientId;

@end

@interface OWSOutgoingSentMessageTranscript ()

@property (nonatomic, readwrite) TSOutgoingMessage *message;
// sentRecipientId is the recipient of message, for contact thread messages.
// It is used to identify the thread/conversation to desktop.
@property (nonatomic, readonly, nullable) NSString *sentRecipientId;

@end

@implementation OWSOutgoingSentMessageTranscript

- (instancetype)initWithOutgoingMessage:(TSOutgoingMessage *)message
{
    self = [super initSyncMessageWithTimestamp:message.timestamp];

    if (!self) {
        return self;
    }

    _message = message;
    // This will be nil for groups.
    _sentRecipientId = message.threadWithSneakyTransaction.contactIdentifier;
    
    _source = [[DTRealSourceEntity alloc] initSourceWithTimestamp:message.timestamp
                                                     sourceDevice:[OWSDevice currentDeviceId]
                                                           source:[TSAccountManager localNumber]
                                                       sequenceId:message.sequenceId
                                                 notifySequenceId:message.notifySequenceId];
    
    self.associatedUniqueThreadId = message.uniqueThreadId;

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];

    DSKProtoSyncMessageSentBuilder *sentBuilder = [DSKProtoSyncMessageSent builder];
    [sentBuilder setTimestamp:self.message.timestamp];

    [sentBuilder setDestination:self.sentRecipientId];
    [sentBuilder setMessage:[self.message buildDataMessage:self.sentRecipientId]];
    [sentBuilder setExpirationStartTimestamp:self.message.timestamp];
    [sentBuilder setServerTimestamp:self.message.serverTimestamp];
    [sentBuilder setSequenceID:self.message.sequenceId];
    [sentBuilder setNotifySequenceID:self.message.notifySequenceId];
    
    NSMutableArray *rapidFiles = @[].mutableCopy;
    [self.message.rapidFiles enumerateObjectsUsingBlock:^(DTRapidFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DSKProtoRapidFileBuilder *rapidFileBuilder = [DSKProtoRapidFile builder];
        rapidFileBuilder.rapidHash = obj.rapidHash;
        [rapidFileBuilder setAuthorizedID:obj.authorizedId];
        DSKProtoRapidFile *rapidFileProto = [rapidFileBuilder buildAndReturnError:nil];
        if (rapidFileProto) {
            [rapidFiles addObject:rapidFileProto];
        }
    }];
    if(rapidFiles.count){
        [sentBuilder setRapidFiles:rapidFiles];
    }

    [syncMessageBuilder setSent:[sentBuilder buildAndReturnError:nil]];

    return syncMessageBuilder;
}

- (BOOL)isReactionMessage {
    
    return self.message.reactionMessage != nil;
}

@end

NS_ASSUME_NONNULL_END
