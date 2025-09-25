//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSVerificationStateSyncMessage.h"
#import "SSKCryptography.h"
#import "OWSIdentityManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark -

@interface OWSVerificationStateSyncMessage ()

@property (nonatomic, readonly) OWSVerificationState verificationState;
@property (nonatomic, readonly) NSData *identityKey;

@end

#pragma mark -

@implementation OWSVerificationStateSyncMessage

- (instancetype)initWithVerificationState:(OWSVerificationState)verificationState
                              identityKey:(NSData *)identityKey
               verificationForRecipientId:(NSString *)verificationForRecipientId
{
    OWSAssertDebug(identityKey.length == kIdentityKeyLength);
    OWSAssertDebug(verificationForRecipientId.length > 0);

    // we only sync user's marking as un/verified. Never sync the conflicted state, the sibling device
    // will figure that out on it's own.
    OWSAssertDebug(verificationState != OWSVerificationStateNoLongerVerified);

    self = [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]];
    if (!self) {
        return self;
    }

    _verificationState = verificationState;
    _identityKey = identityKey;
    _verificationForRecipientId = verificationForRecipientId;
    
    // This sync message should be 1-512 bytes longer than the corresponding NullMessage
    // we store this values so the corresponding NullMessage can subtract it from the total length.
    _paddingBytesLength = arc4random_uniform(512) + 1;

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder
{
    OWSAssertDebug(self.identityKey.length == kIdentityKeyLength);
    OWSAssertDebug(self.verificationForRecipientId.length > 0);

    // we only sync user's marking as un/verified. Never sync the conflicted state, the sibling device
    // will figure that out on it's own.
    OWSAssertDebug(self.verificationState != OWSVerificationStateNoLongerVerified);

    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];

    DSKProtoVerifiedBuilder *verifiedBuilder = [DSKProtoVerified builder];
    verifiedBuilder.destination = self.verificationForRecipientId;
    verifiedBuilder.identityKey = self.identityKey;
    verifiedBuilder.state = self.verificationState;

    OWSAssertDebug(self.paddingBytesLength != 0);

    // We add the same amount of padding in the VerificationStateSync message and it's coresponding NullMessage so that
    // the sync message is indistinguishable from an outgoing Sent transcript corresponding to the NullMessage. We pad
    // the NullMessage so as to obscure it's content. The sync message (like all sync messages) will be *additionally*
    // padded by the superclass while being sent. The end result is we send a NullMessage of a non-distinct size, and a
    // verification sync which is ~1-512 bytes larger then that.
    verifiedBuilder.nullMessage = [SSKCryptography generateRandomBytes:self.paddingBytesLength];
    
    syncMessageBuilder.verified = [verifiedBuilder buildAndReturnError:nil];
    
    return syncMessageBuilder;
}

- (size_t)unpaddedVerifiedLength
{
    OWSAssertDebug(self.identityKey.length == kIdentityKeyLength);
    OWSAssertDebug(self.verificationForRecipientId.length > 0);

    // we only sync user's marking as un/verified. Never sync the conflicted state, the sibling device
    // will figure that out on it's own.
    OWSAssertDebug(self.verificationState != OWSVerificationStateNoLongerVerified);

    DSKProtoVerifiedBuilder *verifiedBuilder = [DSKProtoVerified builder];
    verifiedBuilder.destination = self.verificationForRecipientId;
    verifiedBuilder.identityKey = self.identityKey;
    verifiedBuilder.state = self.verificationState;

    NSError *error;
    NSData *verifiedData = [verifiedBuilder buildSerializedDataAndReturnError:&error];
    if (verifiedData) {
        
        return verifiedData.length;
    } else {
     
        OWSLogError(@"%@ error:%@.", self.logTag, error);
        return 0;
    }
}

@end

NS_ASSUME_NONNULL_END
