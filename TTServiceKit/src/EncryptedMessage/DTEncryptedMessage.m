//
//  DTEncryptedMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/17.
//

#import "DTEncryptedMessage.h"
#import <SignalCoreKit/SCKExceptionWrapper.h>
#import "TSConstants.h"
#import "AxolotlExceptions.h"
#import "SerializationUtilities.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString * const DTProtoDecryptMessageException = @"DTProtoDecryptMessageException";
NSString * const DTProtoEncryptMessageException = @"DTProtoEncryptMessageException";

@implementation DTEncryptedMessage

#pragma mark - send

- (instancetype)init_throws_withVersion:(int)version
                             cipherText:(NSData *)cipherText
                             signedEKey:(NSData *)signedEKey
                                   eKey:(NSData *)eKey
                            identityKey:(NSData *)identityKey
                                 eRMKeys:(NSArray<DTMsgPeerContextParams *> *)eRMKeys
{
    OWSAssert(cipherText);
    OWSAssert(signedEKey);
    OWSAssert(eKey);
    OWSAssert(identityKey);

    if (self = [super init]) {
        Byte versionByte = [SerializationUtilities intsToByteHigh:version low:MESSAGE_MINIMUM_SUPPORTED_VERSION];
        NSMutableData *serialized = [NSMutableData dataWithBytes:&versionByte length:1];

        E2EEMessageProtoContentBuilder *contentBuilder = [E2EEMessageProtoContent builder];
        contentBuilder.version = MESSAGE_CURRENT_VERSION;
        contentBuilder.cipherText = cipherText;
        contentBuilder.signedEkey = signedEKey;
        contentBuilder.eKey = eKey;
        contentBuilder.identityKey = identityKey;
        NSError *error;
        NSData *messageData = [contentBuilder buildSerializedDataAndReturnError:&error];
        if (!messageData || error) {
            OWSFailDebug(@"Encryption:Could not serialize proto");
            OWSRaiseException(DTProtoEncryptMessageException, @"Encryption:Could not serialize proto.");
        }
        [serialized appendData:messageData];
        
        //TODO: mac
//        NSData *mac = [SerializationUtilities throws_macWithVersion:version
//                                                        identityKey:[senderIdentityKey prependKeyType]
//                                                receiverIdentityKey:[receiverIdentityKey prependKeyType]
//                                                             macKey:macKey
//                                                         serialized:serialized];
//
//        [serialized appendData:mac];

        _version = version;
        _cipherText = cipherText;
        _signedEKey = signedEKey;
        _eKey = eKey;
        _identityKey = identityKey;
        _eRMKeys = eRMKeys;
        _serialized = [serialized copy];
    }

    return self;
}


#pragma mark - receive

- (nullable instancetype)initWithData:(nullable NSData *)serialized
                               eRMKey:(nullable NSData *)eRMKey
                                error:(NSError **)outError
{
    @try {
        self = [self init_throws_withData:serialized eRMKey:eRMKey];
        return self;
    } @catch (NSException *exception) {
        *outError = SCKExceptionWrapperErrorMake(exception);
        return nil;
    }
}

- (instancetype)init_throws_withData:(NSData *)serialized eRMKey:(NSData *)eRMKey
{
    if (self = [super init]) {
        if (serialized.length < 1) {
            OWSFailDebug(@"Empty data");
            OWSRaiseException(DTProtoDecryptMessageException, @"Decryption:Empty data");
        }

        Byte version;
        [serialized getBytes:&version length:1];
        _version = [SerializationUtilities highBitsToIntFromByte:version];

        if (_version > MESSAGE_CURRENT_VERSION || _version < MESSAGE_MINIMUM_SUPPORTED_VERSION) {
            OWSLogError(@"Decryption:Unknown version.");
            @throw [NSException exceptionWithName:DTProtoDecryptMessageException
                                           reason:[NSString stringWithFormat:@"Decryption:Unknown version, %d", _version]
                                         userInfo:@{ @"version" : [NSNumber numberWithInt:_version] }];
        }

        NSUInteger messageDataLength;
        ows_sub_overflow(serialized.length, 1, &messageDataLength);
        NSData *messageData = [serialized subdataWithRange:NSMakeRange(1, messageDataLength)];
        NSError *error;
        E2EEMessageProtoContent *encryptedMessageContent = [[E2EEMessageProtoContent alloc] initWithSerializedData:messageData error:&error];
        if (!encryptedMessageContent ||
            !encryptedMessageContent.cipherText ||
            !encryptedMessageContent.eKey ||
            !encryptedMessageContent.signedEkey ||
            !encryptedMessageContent.identityKey) {
            OWSFailDebug(@"Decryption:Could not parse proto.");
            OWSRaiseException(DTProtoDecryptMessageException, @"Decryption:Could not parse proto.");
        }
        
        if (!encryptedMessageContent.version || encryptedMessageContent.version != _version) {
            OWSLogError(@"Decryption:Version is empty or Version numbers are different.");
            OWSProdError(@"Decryption:Version is empty or Version numbers are different.");
        }
        
        _cipherText = encryptedMessageContent.cipherText;
        _eKey = encryptedMessageContent.eKey;
        _signedEKey = encryptedMessageContent.signedEkey;
        _identityKey = encryptedMessageContent.identityKey;
        _eRMKey = eRMKey;
        _serialized = serialized;
        
    }

    return self;
}

@end
