//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSRecipientIdentity.h"
//#import <AxolotlKit/IdentityKeyStore.h>
#import <Curve25519Kit/Curve25519.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const OWSPrimaryStorageTrustedKeysCollection;

// This notification will be fired whenever identities are created
// or their verification state changes.
extern NSString *const kNSNotificationName_IdentityStateDidChange;

// number of bytes in a signal identity key, excluding the key-type byte.
extern const NSUInteger kIdentityKeyLength;

typedef NS_CLOSED_ENUM(uint8_t, OWSIdentity) {
    OWSIdentityACI NS_SWIFT_NAME(aci),
    OWSIdentityPNI NS_SWIFT_NAME(pni)
};

@class OWSRecipientIdentity;
@class DSKProtoVerified;
@class SDSAnyWriteTransaction;
@class SDSAnyReadTransaction;
@protocol IdentityKeyStore;
@protocol SPKProtocolWriteContext;
@protocol SPKProtocolReadContext;

// This class can be safely accessed and used from any thread.
@interface OWSIdentityManager : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)generateNewIdentityKey;

- (void)storeNewIdentityKeyPair:(ECKeyPair *)keyPair transaction:(SDSAnyWriteTransaction *)transaction;

- (nullable ECKeyPair *)oldIdentityKeyPair:(SDSAnyReadTransaction *)transaction;

- (nullable NSNumber *)identityKeyTimeWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
         isSendSystemMessage:(BOOL)isSendSystemMessage
                 transaction:(SDSAnyWriteTransaction *)transaction;

- (OWSVerificationState)verificationStateForRecipientId:(NSString *)recipientId;
- (OWSVerificationState)verificationStateForRecipientId:(NSString *)recipientId
                                            transaction:(SDSAnyWriteTransaction *)transaction;

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
         isSendSystemMessage:(BOOL)isSendSystemMessage;

- (nullable OWSRecipientIdentity *)recipientIdentityForRecipientId:(NSString *)recipientId;

/**
 * @param   recipientId unique stable identifier for the recipient, e.g. e164 phone number
 * @returns nil if the recipient does not exist, or is trusted for sending
 *          else returns the untrusted recipient.
 */
- (nullable OWSRecipientIdentity *)untrustedIdentityForSendingToRecipientId:(NSString *)recipientId;

- (nullable OWSRecipientIdentity *)unverifiedIdentityForSendingToRecipientId:(NSString *)recipientId;

// This method can be called from any thread.
- (void)processIncomingSyncMessage:(DSKProtoVerified *)verified
                       transaction:(SDSAnyWriteTransaction *)transaction;

#pragma mark - IdentityKeyStore

- (BOOL)saveRemoteIdentity:(NSData *)identityKey
               recipientId:(NSString *)recipientId DEPRECATED_MSG_ATTRIBUTE("Please use [OWSIdentityManager getUUIDAtIndex:recipientId:protocolContext:]");

- (BOOL)saveRemoteIdentity:(NSData *)identityKey
               recipientId:(NSString *)recipientId
           protocolContext:(id<SPKProtocolWriteContext>)protocolContext;

- (nullable NSData *)identityKeyForRecipientId:(NSString *)recipientId;

- (nullable NSData *)identityKeyForRecipientId:(NSString *)recipientId
                                   transaction:(SDSAnyWriteTransaction *)transaction;

- (nullable NSData *)identityKeyForRecipientId:(nonnull NSString *)recipientId
                               protocolContext:(nullable id<SPKProtocolReadContext>)protocolContext;

- (nullable ECKeyPair *)identityKeyPair;
- (nullable ECKeyPair *)identityKeyPairWithTransaction:(SDSAnyReadTransaction *)transaction;

#pragma mark - Debug

#if DEBUG
// Clears everything except the local identity key.
- (void)clearIdentityState:(SDSAnyWriteTransaction *)transaction;

//- (void)snapshotIdentityState:(SDSAnyWriteTransaction *)transaction;
//- (void)restoreIdentityState:(SDSAnyWriteTransaction *)transaction;
#endif

#pragma mark - for data migrator

- (void)migratorIdentityKey:(ECKeyPair *)key transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
