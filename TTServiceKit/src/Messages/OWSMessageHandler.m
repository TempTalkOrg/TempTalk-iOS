//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageHandler.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

// used in log formatting
NSString *envelopeAddress(DSKProtoEnvelope *envelope)
{
    return [NSString stringWithFormat:@"%@.%d", envelope.source, (unsigned int)envelope.sourceDevice];
}

@implementation OWSMessageHandler

- (NSString *)descriptionForEnvelopeType:(DSKProtoEnvelope *)envelope
{
    OWSAssertDebug(envelope != nil);
    
    // added: just return "Unkown" if has no type.
    if (!envelope.hasType) {
        return @"Unknown";
    }

    switch (envelope.unwrappedType) {
        case DSKProtoEnvelopeTypeReceipt:
            return @"DeliveryReceipt";
        case DSKProtoEnvelopeTypeUnknown:
            // Shouldn't happen

            // modified: when an exist user with unread messge try to reregister ,
            // the user who sended message maybe meet this situation.
            // e.g. maybe return this type when contact security code changed
            //OWSProdFail([OWSAnalyticsEvents messageManagerErrorEnvelopeTypeUnknown]);
            return @"Unknown";
        case DSKProtoEnvelopeTypeCiphertext:
            return @"SignalEncryptedMessage";
        case DSKProtoEnvelopeTypeKeyExchange:
            // Unsupported
            OWSProdFail([OWSAnalyticsEvents messageManagerErrorEnvelopeTypeKeyExchange]);
            return @"KeyExchange";
        case DSKProtoEnvelopeTypePrekeyBundle:
            return @"PreKeyEncryptedMessage";
        case DSKProtoEnvelopeTypeNotify:
            return @"NotifyMessage";
        case DSKProtoEnvelopeTypePlaintext:
            return @"PlaintextMessage";
        case DSKProtoEnvelopeTypeEtoee:
            return @"E2EEMessage";
        default:
            // Shouldn't happen
            OWSProdFail([OWSAnalyticsEvents messageManagerErrorEnvelopeTypeOther]);
            return @"Other";
    }
}

- (NSString *)descriptionForEnvelope:(DSKProtoEnvelope *)envelope
{
    OWSAssertDebug(envelope != nil);

    return [NSString stringWithFormat:@"<Envelope type: %@, source: %@, timestamp: %llu, servertimestamp: %llu, msgType: %d, content.length: %lu />",
                     [self descriptionForEnvelopeType:envelope],
                     envelopeAddress(envelope),
                     envelope.timestamp,
                     envelope.systemShowTimestamp,
                     envelope.unwrappedMsgType,
                     (unsigned long)envelope.content.length];
}

/**
 * We don't want to just log `content.description` because we'd potentially log message bodies for dataMesssages and
 * sync transcripts
 */
- (NSString *)descriptionForContent:(DSKProtoContent *)content
{
    if (content.syncMessage) {
        return [NSString stringWithFormat:@"<SyncMessage: %@ />", [self descriptionForSyncMessage:content.syncMessage]];
    } else if (content.dataMessage) {
        return [NSString stringWithFormat:@"<DataMessage: %@ />", [self descriptionForDataMessage:content.dataMessage]];
    } else if (content.callMessage) {
        NSString *callMessageDescription = [self descriptionForCallMessage:content.callMessage];
        return [NSString stringWithFormat:@"<CallMessage %@ />", callMessageDescription];
    } else if (content.nullMessage) {
        return [NSString stringWithFormat:@"<NullMessage: %@ />", content.nullMessage];
    } else if (content.receiptMessage) {
        return [NSString stringWithFormat:@"<ReceiptMessage: %@ />", content.receiptMessage];
    } else if (content.notifyMessage) {
        return [NSString stringWithFormat:@"<notifyMessage: %@ />", content.notifyMessage];
    }
    else {
        // Don't fire an analytics event; if we ever add a new content type, we'd generate a ton of
        // analytics traffic.
        OWSFailDebug(@"Unknown content type.");//
        return @"UnknownContent";
    }
}

- (NSString *)descriptionForCallMessage:(DSKProtoCallMessage *)callMessage
{
    NSString *messageType;
    NSString *roomId;
    
    if (callMessage.calling != nil) {
        messageType = @"Calling";
        roomId = callMessage.calling.roomID;
    } else if (callMessage.joined != nil) {
        messageType = @"Joined";
        roomId = callMessage.joined.roomID;
    } else if (callMessage.cancel != nil) {
        messageType = @"Cancel";
        roomId = callMessage.cancel.roomID;
    } else if (callMessage.reject != nil) {
        messageType = @"Reject";
        roomId = callMessage.reject.roomID;
    } else {
        OWSFailDebug(@"%@ failure: unexpected call message type: %@", self.logTag, callMessage);
        messageType = @"Unknown";
        roomId = 0;
    }

    return [NSString stringWithFormat:@"type: %@, roomId: %@", messageType, roomId];
}

/**
 * We don't want to just log `dataMessage.description` because we'd potentially log message contents
 */
- (NSString *)descriptionForDataMessage:(DSKProtoDataMessage *)dataMessage
{
    NSMutableString *description = [NSMutableString new];

    if (dataMessage.group) {
        [description appendString:@"(Group:YES) "];
    }

    if ((dataMessage.flags & DSKProtoDataMessageFlagsEndSession) != 0) {
        [description appendString:@"EndSession"];
    } else if ((dataMessage.flags & DSKProtoDataMessageFlagsExpirationTimerUpdate) != 0) {
        [description appendString:@"ExpirationTimerUpdate"];
    } else if ((dataMessage.flags & DSKProtoDataMessageFlagsProfileKeyUpdate) != 0) {
        [description appendString:@"ProfileKey"];
    } else if (dataMessage.attachments.count > 0) {
        [description appendString:@"MessageWithAttachment"];
    } else {
        [description appendString:@"Plain"];
    }

    return [NSString stringWithFormat:@"<%@ />", description];
}

/**
 * We don't want to just log `syncMessage.description` because we'd potentially log message contents in sent transcripts
 */
- (NSString *)descriptionForSyncMessage:(DSKProtoSyncMessage *)syncMessage
{
    NSMutableString *description = [NSMutableString new];
    if (syncMessage.sent) {
        [description appendString:@"SentTranscript"];
    } else if (syncMessage.request) {
        if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeContacts) {
            [description appendString:@"ContactRequest"];
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeGroups) {
            [description appendString:@"GroupRequest"];
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeBlocked) {
            [description appendString:@"BlockedRequest"];
        } else if (syncMessage.request.unwrappedType == DSKProtoSyncMessageRequestTypeConfiguration) {
            [description appendString:@"ConfigurationRequest"];
        } else {
            // Shouldn't happen
            OWSFailDebug(@"Unknown sync message request type");
            [description appendString:@"UnknownRequest"];
        }
    } else if (syncMessage.blocked) {
        [description appendString:@"Blocked"];
    } else if (syncMessage.read.count > 0) {
        [description appendString:@"ReadReceipt"];
    } else if (syncMessage.verified) {
        NSString *verifiedString =
            [NSString stringWithFormat:@"Verification for: %@", syncMessage.verified.destination];
        [description appendString:verifiedString];
    } else if (syncMessage.tasks.count) { // task notify
        [description appendString:@"Task Notify"];
    } else if (syncMessage.markAsUnread) {
        [description appendString:@"Mark As Read"];
    } else if (syncMessage.hasPadding) {
        [description appendString:@"Padding Null"];
    } else if (syncMessage.conversationArchive) {
        [description appendString:@"Conversation Archive"];
    } else if (syncMessage.criticalRead.count > 0) {
        [description appendString:@"Critical ReadReceipt"];
    } else {
        // Shouldn't happen
        OWSFailDebug(@"Unknown sync message type");
        [description appendString:@"Unknown"];
    }

    return description;
}

@end

NS_ASSUME_NONNULL_END
