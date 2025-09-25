//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSBlockedPhoneNumbersMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSBlockedPhoneNumbersMessage ()

@property (nonatomic, readonly) NSArray<NSString *> *phoneNumbers;

@end

@implementation OWSBlockedPhoneNumbersMessage

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (instancetype)initWithPhoneNumbers:(NSArray<NSString *> *)phoneNumbers
{
    self = [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]];
    if (!self) {
        return self;
    }

    _phoneNumbers = [phoneNumbers copy];

    return self;
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    DSKProtoSyncMessageBlockedBuilder *blockedPhoneNumbersBuilder = [DSKProtoSyncMessageBlocked builder];
    [blockedPhoneNumbersBuilder setNumbers:_phoneNumbers];
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    [syncMessageBuilder setBlocked:[blockedPhoneNumbersBuilder buildAndReturnError:nil]];

    return syncMessageBuilder;
}

@end

NS_ASSUME_NONNULL_END
