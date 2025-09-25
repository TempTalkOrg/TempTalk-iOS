//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSSyncConfigurationMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSSyncConfigurationMessage ()

@property (nonatomic, readonly) BOOL areReadReceiptsEnabled;

@end

@implementation OWSSyncConfigurationMessage

- (instancetype)initWithReadReceiptsEnabled:(BOOL)areReadReceiptsEnabled
{
    self = [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]];
    if (!self) {
        return nil;
    }

    _areReadReceiptsEnabled = areReadReceiptsEnabled;

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    DSKProtoSyncMessageConfigurationBuilder *configurationBuilder =
        [DSKProtoSyncMessageConfiguration builder];
    configurationBuilder.readReceipts = self.areReadReceiptsEnabled;

    DSKProtoSyncMessageBuilder *builder = [DSKProtoSyncMessage builder];

    builder.configuration = [configurationBuilder buildAndReturnError:nil];

    return builder;
}

@end

NS_ASSUME_NONNULL_END
