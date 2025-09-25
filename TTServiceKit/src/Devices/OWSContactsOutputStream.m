//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContactsOutputStream.h"
#import "Contact.h"
#import "ContactsManagerProtocol.h"
#import "SSKCryptography.h"
#import "MIMETypeUtil.h"
#import "NSData+keyVersionByte.h"
#import "OWSBlockingManager.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSRecipientIdentity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "SignalAccount.h"
#import "TSContactThread.h"
#import "TSAccountManager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OWSContactsOutputStream

- (void)writeSignalAccount:(SignalAccount *)signalAccount
         recipientIdentity:(nullable OWSRecipientIdentity *)recipientIdentity
            profileKeyData:(nullable NSData *)profileKeyData
           contactsManager:(id<ContactsManagerProtocol>)contactsManager
     conversationColorName:(NSString *)conversationColorName
disappearingMessagesConfiguration:(nullable OWSDisappearingMessagesConfiguration *)disappearingMessagesConfiguration
               transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(signalAccount);
    OWSAssertDebug(signalAccount.contact);
    OWSAssertDebug(contactsManager);

    DSKProtoContactDetailsBuilder *contactBuilder = [DSKProtoContactDetails builder];
    [contactBuilder setNumber:signalAccount.recipientId];
#ifdef CONVERSATION_COLORS_ENABLED
    [contactBuilder setColor:conversationColorName];
#endif

    if (recipientIdentity != nil) {
        DSKProtoVerifiedBuilder *verifiedBuilder = [DSKProtoVerified builder];
        verifiedBuilder.destination = recipientIdentity.recipientId;
        verifiedBuilder.identityKey = [recipientIdentity.identityKey prependKeyType];
        [verifiedBuilder setState:recipientIdentity.verificationState];
        
        [contactBuilder setVerified:[verifiedBuilder buildAndReturnError:nil]];
    }

    // added: sync current contact avatar and remark name to desktop client.
    UIImage *_Nullable rawAvatar = nil;
    NSString *_Nullable localNumber = [[TSAccountManager shared] localNumberWithTransaction:transaction];
    if (localNumber && [localNumber isEqualToString:signalAccount.recipientId]) {
        [contactBuilder setName:[contactsManager localProfileNameWithTransaction:transaction]];
        rawAvatar = [contactsManager localProfileAvatarImage];
    }
    
    NSData *_Nullable avatarPng;
    if (rawAvatar) {
        avatarPng = UIImagePNGRepresentation(rawAvatar);
        if (avatarPng) {
            DSKProtoContactDetailsAvatarBuilder *avatarBuilder =
                [DSKProtoContactDetailsAvatar builder];

            [avatarBuilder setContentType:OWSMimeTypeImagePng];
            [avatarBuilder setLength:(uint32_t)avatarPng.length];
            [contactBuilder setAvatar:[avatarBuilder buildAndReturnError:nil]];
        }
    }

    if (profileKeyData) {
        OWSAssertDebug(profileKeyData.length == kAES256_KeyByteLength);
        [contactBuilder setProfileKey:profileKeyData];
    }

    // Always ensure the "expire timer" property is set so that desktop
    // can easily distinguish between a modern client declaring "off" vs a
    // legacy client "not specifying".
    [contactBuilder setExpireTimer:0];

    if (disappearingMessagesConfiguration && disappearingMessagesConfiguration.isEnabled) {
        [contactBuilder setExpireTimer:disappearingMessagesConfiguration.durationSeconds];
    }

    if ([OWSBlockingManager.sharedManager isRecipientIdBlocked:signalAccount.recipientId]) {
        [contactBuilder setBlocked:YES];
    }

    NSData *contactData = [contactBuilder buildSerializedDataAndReturnError:nil];

    if (contactData) {
        uint32_t contactDataLength = (uint32_t)contactData.length;
        [self writeVariableLengthUInt32:contactDataLength];
        [self writeData:contactData];
    }

    if (avatarPng) {
        [self writeData:avatarPng];
    }
}

@end

NS_ASSUME_NONNULL_END
