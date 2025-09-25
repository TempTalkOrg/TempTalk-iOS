//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSSyncGroupsMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "OWSGroupsOutputStream.h"
#import "TSAttachment.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSSyncGroupsMessage

- (instancetype)init
{
    return [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{

    if (self.attachmentIds.count != 1) {
        DDLogError(@"expected sync groups message to have exactly one attachment, but found %lu",
            (unsigned long)self.attachmentIds.count);
    }
    DSKProtoAttachmentPointer *attachmentProto = [TSAttachmentStream buildProtoForAttachmentId:self.attachmentIds.firstObject];

    DSKProtoSyncMessageGroupsBuilder *groupsBuilder =
        [DSKProtoSyncMessageGroups builder];

    [groupsBuilder setBlob:attachmentProto];

    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    [syncMessageBuilder setGroups:[groupsBuilder buildAndReturnError:nil]];

    return syncMessageBuilder;
}

- (NSData *)buildPlainTextAttachmentDataWithTransaction:(SDSAnyReadTransaction *)transaction
{
    // TODO use temp file stream to avoid loading everything into memory at once
    // First though, we need to re-engineer our attachment process to accept streams (encrypting with stream,
    // and uploading with streams).
    NSOutputStream *dataOutputStream = [NSOutputStream outputStreamToMemory];
    [dataOutputStream open];
    
    OWSGroupsOutputStream *groupsOutputStream = [[OWSGroupsOutputStream alloc] initWithOutputStream:dataOutputStream];

    [TSGroupThread anyEnumerateWithTransaction:transaction
                                       batched:YES
                                         block:^(TSThread * obj, BOOL * stop) {
        if (![obj isKindOfClass:[TSGroupThread class]]) {
            if (![obj isKindOfClass:[TSContactThread class]]) {
                DDLogWarn(
                    @"Ignoring non group thread in thread collection: %@", obj);
            }
            return;
        }
        TSGroupThread *groupThread = (TSGroupThread *)obj;
        [groupsOutputStream writeGroup:groupThread transaction:transaction];
    }];

    [dataOutputStream close];

    return [dataOutputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

@end

NS_ASSUME_NONNULL_END
