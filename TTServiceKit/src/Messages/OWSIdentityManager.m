//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSIdentityManager.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "NSNotificationCenter+OWS.h"
#import "NotificationsProtocol.h"
#import "OWSError.h"
#import "OWSFileSystem.h"
#import "OWSMessageSender.h"
#import "OWSOutgoingNullMessage.h"
#import "OWSRecipientIdentity.h"
#import "OWSVerificationStateChangeMessage.h"
#import "OWSVerificationStateSyncMessage.h"
#import "TSAccountManager.h"
#import "TSContactThread.h"
#import "TSErrorMessage.h"
#import "TSGroupThread.h"
#import "TextSecureKitEnv.h"
#import <Curve25519Kit/Curve25519.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "AxolotlkitDefines.h"
#import "NSData+keyVersionByte.h"
#import "SPKProtocolContext.h"

NS_ASSUME_NONNULL_BEGIN

// Storing our own identity key
NSString *const OWSPrimaryStorageIdentityKeyStoreIdentityKey = @"TSStorageManagerIdentityKeyStoreIdentityKey";
NSString *const OWSPrimaryStorageIdentityKeyStoreCollection = @"TSStorageManagerIdentityKeyStoreCollection";
NSString *const OWSPrimaryStorageIdentityKeyStoreOldIDKey = @"TSStorageManagerIdentityKeyStoreOldIDKey";
NSString *const OWSPrimaryStorageIdentityKeyStoreIDKeyTime = @"TSStorageManagerIdentityKeyStoreIDKeyTime";

// Storing recipients identity keys
NSString *const OWSPrimaryStorageTrustedKeysCollection = @"TSStorageManagerTrustedKeysCollection";

NSString *const OWSIdentityManager_QueuedVerificationStateSyncMessages =
    @"OWSIdentityManager_QueuedVerificationStateSyncMessages";

// Don't trust an identity for sending to unless they've been around for at least this long
const NSTimeInterval kIdentityKeyStoreNonBlockingSecondsThreshold = 5.0;

// The canonical key includes 32 bytes of identity material plus one byte specifying the key type
const NSUInteger kIdentityKeyLength = 33;

// Cryptographic operations do not use the "type" byte of the identity key, so, for legacy reasons we store just
// the identity material.
// TODO: migrate to storing the full 33 byte representation.
const NSUInteger kStoredIdentityKeyLength = 32;

NSString *const kNSNotificationName_IdentityStateDidChange = @"kNSNotificationName_IdentityStateDidChange";

@interface OWSIdentityManager ()

@property (nonatomic, readonly) SDSKeyValueStore *ownIdentityKeyValueStore;
@property (nonatomic, readonly) SDSKeyValueStore *queuedVerificationStateSyncMessagesKeyValueStore;
@property (nonatomic, readonly) SDSKeyValueStore *ownTrustedIdentityKeyValueStore;

@end

#pragma mark -

@implementation OWSIdentityManager

+ (instancetype)sharedManager
{
    static OWSIdentityManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }
    
    _ownIdentityKeyValueStore =
        [[SDSKeyValueStore alloc] initWithCollection:OWSPrimaryStorageIdentityKeyStoreCollection];
    _queuedVerificationStateSyncMessagesKeyValueStore =
        [[SDSKeyValueStore alloc] initWithCollection:OWSIdentityManager_QueuedVerificationStateSyncMessages];
    
    _ownTrustedIdentityKeyValueStore = [[SDSKeyValueStore alloc] initWithCollection:OWSPrimaryStorageTrustedKeysCollection];

//    self.dbConnection.objectCacheEnabled = NO;
    OWSSingletonAssert();

    [self observeNotifications];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)storeNewIdentityKeyPair:(ECKeyPair *)keyPair transaction:(SDSAnyWriteTransaction *)transaction {
    ECKeyPair *oldKeyPair = [self identityKeyPairWithTransaction:transaction];
    if ([oldKeyPair isKindOfClass:[ECKeyPair class]]){
        [self.ownIdentityKeyValueStore setObject:oldKeyPair
                                             key:OWSPrimaryStorageIdentityKeyStoreOldIDKey
                                     transaction:transaction];
    }
    [self.ownIdentityKeyValueStore setObject:keyPair
                                         key:OWSPrimaryStorageIdentityKeyStoreIdentityKey
                                 transaction:transaction];
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    [self.ownIdentityKeyValueStore setObject:@(now)
                                         key:OWSPrimaryStorageIdentityKeyStoreIDKeyTime
                                 transaction:transaction];
}

- (nullable NSNumber *)identityKeyTimeWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    return [self.ownIdentityKeyValueStore getObjectForKey:OWSPrimaryStorageIdentityKeyStoreIDKeyTime transaction:transaction];
}

- (nullable ECKeyPair *)oldIdentityKeyPair:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    ECKeyPair *_Nullable identityKeyPair = [self.ownIdentityKeyValueStore getObjectForKey:OWSPrimaryStorageIdentityKeyStoreOldIDKey transaction:transaction];
    return identityKeyPair;
}

- (void)generateNewIdentityKey
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.ownIdentityKeyValueStore setObject:[Curve25519 generateKeyPair]
                                             key:OWSPrimaryStorageIdentityKeyStoreIdentityKey
                                     transaction:transaction];
    });
}

- (nullable NSData *)identityKeyForRecipientId:(NSString *)recipientId
                                   transaction:(SDSAnyWriteTransaction *)transaction {
    OWSAssertDebug(recipientId.length > 0);

    if (transaction) {
        return [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction].identityKey;
    } else {
        __block NSData * ientIdentityKey = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * readTransaction) {
            ientIdentityKey = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:readTransaction].identityKey;
        }];
        return ientIdentityKey;
    }
}

// 支持 SDSAnyReadTransaction transaction
- (nullable NSData *)identityKeyForRecipientId:(NSString *)recipientId
                               readTransaction:(SDSAnyReadTransaction *)readTransaction
{
    OWSAssertDebug(recipientId.length > 0);
    
    if (readTransaction) {
        return [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:readTransaction].identityKey;
    } else {
        __block NSData * ientIdentityKey = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * readTransaction) {
            ientIdentityKey = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:readTransaction].identityKey;
        }];
        return ientIdentityKey;
    }
}

- (nullable ECKeyPair *)identityKeyPair
{
    __block ECKeyPair *_Nullable identityKeyPair = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        identityKeyPair = [self identityKeyPairWithTransaction:transaction];
    }];

    return identityKeyPair;
}


#pragma mark - IdentityKeyStore

// This method should only be called from SignalProtocolKit, which doesn't know about YapDatabaseTransactions.
// Whenever possible, prefer to call the strongly typed variant: `identityKeyPairWithTransaction:`.
- (nullable ECKeyPair *)identityKeyPair:(nullable id<SPKProtocolWriteContext>)protocolContext
{
    OWSAssertDebug([protocolContext conformsToProtocol:@protocol(SPKProtocolWriteContext)]);
    
    SDSAnyWriteTransaction *transaction = protocolContext;

    return [self identityKeyPairWithTransaction:transaction];
}

- (nullable ECKeyPair *)identityKeyPairWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);
    ECKeyPair *_Nullable identityKeyPair = [self.ownIdentityKeyValueStore getObjectForKey:OWSPrimaryStorageIdentityKeyStoreIdentityKey transaction:transaction];
    
    return identityKeyPair;
}

- (int)localRegistrationId:(nullable id<SPKProtocolWriteContext>)protocolContext
{
    OWSAssertDebug([protocolContext conformsToProtocol:@protocol(SPKProtocolWriteContext)]);

    SDSAnyWriteTransaction *transaction = protocolContext;

    return (int)[TSAccountManager getOrGenerateRegistrationId:transaction];
}

- (BOOL)saveRemoteIdentity:(NSData *)identityKey recipientId:(NSString *)recipientId
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);

    __block BOOL result;
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        result = [self saveRemoteIdentity:identityKey recipientId:recipientId protocolContext:transaction];
    });

    return result;
}

- (BOOL)saveRemoteIdentity:(NSData *)identityKey
               recipientId:(NSString *)recipientId
           protocolContext:(id <SPKProtocolWriteContext>)protocolContext
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug([protocolContext conformsToProtocol:@protocol(SPKProtocolWriteContext)]);
    
    SDSAnyWriteTransaction *transaction = (SDSAnyWriteTransaction *)protocolContext;

    // Deprecated. We actually no longer use the OWSPrimaryStorageTrustedKeysCollection for trust
    // decisions, but it's desirable to try to keep it up to date with our trusted identitys
    // while we're switching between versions, e.g. so we don't get into a state where we have a
    // session for an identity not in our key store.
    [self.ownTrustedIdentityKeyValueStore setObject:identityKey key:recipientId transaction:transaction];

    OWSRecipientIdentity *existingIdentity =
        [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];

    if (existingIdentity == nil) {
        DDLogInfo(@"%@ saving first use identity for recipient: %@", self.logTag, recipientId);
        [[[OWSRecipientIdentity alloc] initWithRecipientId:recipientId
                                               identityKey:identityKey
                                           isFirstKnownKey:YES
                                                 createdAt:[NSDate new]
                                         verificationState:OWSVerificationStateDefault]
            anyInsertWithTransaction:transaction];

        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForRecipientId:recipientId transaction:transaction];

        [self fireIdentityStateChangeNotification];

        return NO;
    }

    if (![existingIdentity.identityKey isEqual:identityKey]) {
        OWSVerificationState verificationState;
        switch (existingIdentity.verificationState) {
            case OWSVerificationStateDefault:
                verificationState = OWSVerificationStateDefault;
                break;
            case OWSVerificationStateVerified:
            case OWSVerificationStateNoLongerVerified:
                verificationState = OWSVerificationStateNoLongerVerified;
                break;
        }

        DDLogInfo(@"%@ replacing identity for existing recipient: %@ (%@ -> %@)",
            self.logTag,
            recipientId,
            OWSVerificationStateToString(existingIdentity.verificationState),
            OWSVerificationStateToString(verificationState));
       //MARK: 
        //[self createIdentityChangeInfoMessageForRecipientId:recipientId transaction:transaction];

        [[[OWSRecipientIdentity alloc] initWithRecipientId:recipientId
                                               identityKey:identityKey
                                           isFirstKnownKey:NO
                                                 createdAt:[NSDate new]
                                         verificationState:verificationState] anyInsertWithTransaction:transaction];

        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForRecipientId:recipientId transaction:transaction];

        [self fireIdentityStateChangeNotification];

        return YES;
    }

    return NO;
}

- (BOOL)isTrustedIdentityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
                   direction:(TSMessageDirection)direction
             protocolContext:(nullable id<SPKProtocolReadContext>)protocolContext
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(direction != TSMessageDirectionUnknown);
    OWSAssertDebug([protocolContext conformsToProtocol:@protocol(SPKProtocolReadContext)]);
    
    SDSAnyReadTransaction *anyReadTransaction = (SDSAnyReadTransaction *)protocolContext;
    
    return [self isTrustedIdentityKey:identityKey recipientId:recipientId direction:direction transaction:anyReadTransaction];
}

- (nullable NSData *)identityKeyForRecipientId:(NSString *)recipientId
{
    __block NSData *_Nullable result = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        result = [self identityKeyForRecipientId:recipientId readTransaction:transaction];
    }];
    
    return result;
}

- (nullable NSData *)identityKeyForRecipientId:(nonnull NSString *)recipientId protocolContext:(nullable id<SPKProtocolReadContext>)protocolContext {
    OWSAssertDebug(recipientId.length > 0);
//    OWSAssertDebug([protocolContext conformsToProtocol:@protocol(SPKProtocolReadContext)]);
        
    NSData *_Nullable result = [self identityKeyForRecipientId:recipientId readTransaction:protocolContext];
    
    return result;
}

#pragma mark -

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
         isSendSystemMessage:(BOOL)isSendSystemMessage
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self setVerificationState:verificationState
                       identityKey:identityKey
                       recipientId:recipientId
             isUserInitiatedChange:isUserInitiatedChange
               isSendSystemMessage:isSendSystemMessage
                       transaction:transaction];
    });
}

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
         isSendSystemMessage:(BOOL)isSendSystemMessage
             protocolContext:(nullable id)protocolContext
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug([protocolContext isKindOfClass:[SDSAnyWriteTransaction class]]);

    SDSAnyWriteTransaction *transaction = protocolContext;

    [self setVerificationState:verificationState
                   identityKey:identityKey
                   recipientId:recipientId
         isUserInitiatedChange:isUserInitiatedChange
           isSendSystemMessage:isSendSystemMessage
                   transaction:transaction];
}

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
         isSendSystemMessage:(BOOL)isSendSystemMessage
                 transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);

    // Ensure a remote identity exists for this key. We may be learning about
    // it for the first time.
    [self saveRemoteIdentity:identityKey recipientId:recipientId protocolContext:transaction];

    OWSRecipientIdentity *recipientIdentity =
        [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];

    if (recipientIdentity == nil) {
        OWSFailDebug(@"Missing expected identity: %@", recipientId);
        return;
    }

    if (recipientIdentity.verificationState == verificationState) {
        return;
    }

    DDLogInfo(@"%@ setVerificationState: %@ (%@ -> %@)",
        self.logTag,
        recipientId,
        OWSVerificationStateToString(recipientIdentity.verificationState),
        OWSVerificationStateToString(verificationState));

    [recipientIdentity updateWithVerificationState:verificationState transaction:transaction];

    if (isUserInitiatedChange) {

        [self saveChangeMessagesForRecipientId:recipientId
                             verificationState:verificationState
                                 isLocalChange:YES
                           isSendSystemMessage:isSendSystemMessage
                                   transaction:transaction];
        [self enqueueSyncMessageForVerificationStateForRecipientId:recipientId transaction:transaction];
    } else {
        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForRecipientId:recipientId transaction:transaction];
    }

    [self fireIdentityStateChangeNotification];
}

- (OWSVerificationState)verificationStateForRecipientId:(NSString *)recipientId
{
//    __block OWSVerificationState result;
//    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
//        result = [self verificationStateForRecipientId:recipientId readTransaction:transaction];
//    }];
//
//    return result;
    return OWSVerificationStateVerified;
}

//
- (OWSVerificationState)verificationStateForRecipientId:(NSString *)recipientId
                                        readTransaction:(SDSAnyReadTransaction *)readTransaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(readTransaction);
    
    OWSRecipientIdentity *_Nullable currentIdentity =
    [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:readTransaction];
    
    if (!currentIdentity) {
        // We might not know the identity for this recipient yet.
        return OWSVerificationStateDefault;
    }
    
    return currentIdentity.verificationState;
}

- (OWSVerificationState)verificationStateForRecipientId:(NSString *)recipientId
                                            transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);

    OWSRecipientIdentity *_Nullable currentIdentity =
        [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];

    if (!currentIdentity) {
        // We might not know the identity for this recipient yet.
        return OWSVerificationStateDefault;
    }

    return currentIdentity.verificationState;
}

- (nullable OWSRecipientIdentity *)recipientIdentityForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    __block OWSRecipientIdentity *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        result = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];
    }];
    
    return result;
}

- (nullable OWSRecipientIdentity *)untrustedIdentityForSendingToRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    __block OWSRecipientIdentity *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        OWSRecipientIdentity *_Nullable recipientIdentity =
        [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];
        
        if (recipientIdentity == nil) {
            // trust on first use
            return;
        }
        
        BOOL isTrusted = [self isTrustedIdentityKey:recipientIdentity.identityKey
                                        recipientId:recipientId
                                          direction:TSMessageDirectionOutgoing
                                        transaction:transaction];
        if (isTrusted) {
            return;
        } else {
            result = recipientIdentity;
        }
    }];
    
    return result;
}

- (nullable OWSRecipientIdentity *)unverifiedIdentityForSendingToRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    __block OWSRecipientIdentity *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        OWSRecipientIdentity *_Nullable recipientIdentity =
        [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];
        
        if (recipientIdentity == nil) {
            // trust on first use
            return;
        }
        
        BOOL isVerified = recipientIdentity.verificationState == OWSVerificationStateVerified;
        if (isVerified) {
            return;
        } else {
            result = recipientIdentity;
        }
    }];
    
    return result;
}

- (void)fireIdentityStateChangeNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:kNSNotificationName_IdentityStateDidChange
                                                             object:nil
                                                           userInfo:nil];
}

- (BOOL)isTrustedIdentityKey:(NSData *)identityKey
                 recipientId:(NSString *)recipientId
                   direction:(TSMessageDirection)direction
                 transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(direction != TSMessageDirectionUnknown);
    OWSAssertDebug(transaction);

    NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:transaction];
    if ([localNumber isEqualToString:recipientId]) {
        ECKeyPair *_Nullable localIdentityKeyPair = [self identityKeyPairWithTransaction:transaction];

        if ([localIdentityKeyPair.publicKey isEqualToData:identityKey]) {
            return YES;
        } else {
            OWSFailDebug(@"%@ Wrong identity: %@ for local key: %@, recipientId: %@",
                self.logTag,
                identityKey,
                localIdentityKeyPair.publicKey,
                recipientId);
            return NO;
        }
    }

    switch (direction) {
        case TSMessageDirectionIncoming: {
            return YES;
        }
        case TSMessageDirectionOutgoing: {
            OWSRecipientIdentity *existingIdentity =
                [OWSRecipientIdentity anyFetchWithUniqueId:recipientId transaction:transaction];
            return [self isTrustedKey:identityKey forSendingToIdentity:existingIdentity];
        }
        default: {
            OWSFailDebug(@"%@ unexpected message direction: %ld", self.logTag, (long)direction);
            return NO;
        }
    }
}

- (BOOL)isTrustedKey:(NSData *)identityKey forSendingToIdentity:(nullable OWSRecipientIdentity *)recipientIdentity
{
    OWSAssertDebug(identityKey.length == kStoredIdentityKeyLength);

    if (recipientIdentity == nil) {
        return YES;
    }

    OWSAssertDebug(recipientIdentity.identityKey.length == kStoredIdentityKeyLength);
    if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
        DDLogWarn(@"%@ key mismatch for recipient: %@", self.logTag, recipientIdentity.recipientId);
        return NO;
    }

    if ([recipientIdentity isFirstKnownKey]) {
        return YES;
    }

    switch (recipientIdentity.verificationState) {
        case OWSVerificationStateDefault: {
            BOOL isNew = (fabs([recipientIdentity.createdAt timeIntervalSinceNow])
                < kIdentityKeyStoreNonBlockingSecondsThreshold);
            if (isNew) {
                DDLogWarn(
                    @"%@ not trusting new identity for recipient: %@", self.logTag, recipientIdentity.recipientId);
                return NO;
            } else {
                return YES;
            }
        }
        case OWSVerificationStateVerified:
            return YES;
        case OWSVerificationStateNoLongerVerified:
            DDLogWarn(@"%@ not trusting no longer verified identity for recipient: %@",
                self.logTag,
                recipientIdentity.recipientId);
            return NO;
    }
}

- (void)createIdentityChangeInfoMessageForRecipientId:(NSString *)recipientId
                                          transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);

    NSMutableArray<TSMessage *> *messages = [NSMutableArray new];

    TSContactThread *contactThread =
        [TSContactThread getOrCreateThreadWithContactId:recipientId transaction:transaction];
    OWSAssertDebug(contactThread != nil);

    TSErrorMessage *errorMessage =
        [TSErrorMessage nonblockingIdentityChangeInThread:contactThread recipientId:recipientId];
    [messages addObject:errorMessage];

    for (TSGroupThread *groupThread in [TSGroupThread groupThreadsWithRecipientId:recipientId transaction:transaction]) {
        [messages addObject:[TSErrorMessage nonblockingIdentityChangeInThread:groupThread recipientId:recipientId]];
    }

    for (TSMessage *message in messages) {
        [message anyInsertWithTransaction:transaction];
    }

    [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForErrorMessage:errorMessage
                                                                          thread:contactThread
                                                                     transaction:transaction];
}

- (void)enqueueSyncMessageForVerificationStateForRecipientId:(NSString *)recipientId
                                                 transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);
    
    [self.queuedVerificationStateSyncMessagesKeyValueStore setObject:recipientId key:recipientId transaction:transaction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryToSyncQueuedVerificationStates];
    });
}

- (void)tryToSyncQueuedVerificationStates
{
    OWSAssertIsOnMainThread();

    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
        [self syncQueuedVerificationStates];
    });
}

- (void)syncQueuedVerificationStates
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<OWSVerificationStateSyncMessage *> *messages = [NSMutableArray new];
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            
            [self.queuedVerificationStateSyncMessagesKeyValueStore enumerateKeysAndObjectsWithTransaction:transaction
                                                                                                    block:^(NSString * recipientId, OWSRecipientIdentity * recipientIdentity, BOOL * stop) {
                if([recipientIdentity isKindOfClass:[OWSRecipientIdentity class]]){
                    return;
                }
                
                if (recipientIdentity.recipientId.length < 1) {
                    OWSFailDebug(@"Invalid recipient identity for recipientId: %@", recipientId);
                    return;;
                }

                // Prepend key type for transit.
                // TODO we should just be storing the key type so we don't have to juggle re-adding it.
                NSData *identityKey = [recipientIdentity.identityKey prependKeyType];
                if (identityKey.length != kIdentityKeyLength) {
                    OWSFailDebug(@"Invalid recipient identitykey for recipientId: %@ key: %@", recipientId, identityKey);
                    return;;
                }
                if (recipientIdentity.verificationState == OWSVerificationStateNoLongerVerified) {
                    // We don't want to sync "no longer verified" state.  Other clients can
                    // figure this out from the /profile/ endpoint, and this can cause data
                    // loss as a user's devices overwrite each other's verification.
                    OWSFailDebug(@"Queue verification state had unexpected value: %@ recipientId: %@",
                        OWSVerificationStateToString(recipientIdentity.verificationState),
                        recipientId);
                    return;
                }
                OWSVerificationStateSyncMessage *message =
                    [[OWSVerificationStateSyncMessage alloc] initWithVerificationState:recipientIdentity.verificationState
                                                                           identityKey:identityKey
                                                            verificationForRecipientId:recipientIdentity.recipientId];
                [messages addObject:message];
                
            }];
        }];

        if (messages.count > 0) {
            for (OWSVerificationStateSyncMessage *message in messages) {
                [self sendSyncVerificationStateMessage:message];
            }
        }
    });
}

- (void)sendSyncVerificationStateMessage:(OWSVerificationStateSyncMessage *)message
{
    OWSAssertDebug(message);
    OWSAssertDebug(message.verificationForRecipientId.length > 0);

    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactId:message.verificationForRecipientId];
    
    // Send null message to appear as though we're sending a normal message to cover the sync messsage sent
    // subsequently
    OWSOutgoingNullMessage *nullMessage = [[OWSOutgoingNullMessage alloc] initWithContactThread:contactThread
                                                                   verificationStateSyncMessage:message];
    [self.messageSender enqueueMessage:nullMessage
        success:^{
            DDLogInfo(@"%@ Successfully sent verification state NullMessage", self.logTag);
            [self.messageSender enqueueMessage:message
                                       success:^{
                DDLogInfo(@"%@ Successfully sent verification state sync message", self.logTag);
                
                // Record that this verification state was successfully synced.
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    [self clearSyncMessageForRecipientId:message.verificationForRecipientId transaction:transaction];
                    
                });
                
            }
                failure:^(NSError *error) {
                    DDLogError(@"%@ Failed to send verification state sync message with error: %@", self.logTag, error);
                }];
        }
        failure:^(NSError *_Nonnull error) {
            DDLogError(@"%@ Failed to send verification state NullMessage with error: %@", self.logTag, error);
            if (error.code == OWSErrorCodeNoSuchSignalRecipient) {
                DDLogInfo(@"%@ Removing retries for syncing verification state, since user is no longer registered: %@",
                    self.logTag,
                    message.verificationForRecipientId);
                // Otherwise this will fail forever.
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    [self clearSyncMessageForRecipientId:message.verificationForRecipientId transaction:transaction];;
                });
            }
        }];
}

- (void)clearSyncMessageForRecipientId:(NSString *)recipientId
                           transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);
    
    [self.queuedVerificationStateSyncMessagesKeyValueStore removeValueForKey:recipientId transaction:transaction];
}

- (void)processIncomingSyncMessage:(DSKProtoVerified *)verified
                       transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(verified);
    OWSAssertDebug(transaction);

    NSString *recipientId = verified.destination;
    if (recipientId.length < 1) {
        OWSFailDebug(@"Verification state sync message missing recipientId.");
        return;
    }
    NSData *rawIdentityKey = verified.identityKey;
    if (rawIdentityKey.length != kIdentityKeyLength) {
        OWSFailDebug(@"Verification state sync message for recipient: %@ with malformed identityKey: %@",
            recipientId,
            rawIdentityKey);
        return;
    }
    NSData *identityKey = [rawIdentityKey throws_removeKeyType];

    switch (verified.unwrappedState) {
        case DSKProtoVerifiedStateDefault:
            [self tryToApplyVerificationStateFromSyncMessage:OWSVerificationStateDefault
                                                 recipientId:recipientId
                                                 identityKey:identityKey
                                         overwriteOnConflict:NO
                                                 transaction:transaction];
            break;
        case DSKProtoVerifiedStateVerified:
            [self tryToApplyVerificationStateFromSyncMessage:OWSVerificationStateVerified
                                                 recipientId:recipientId
                                                 identityKey:identityKey
                                         overwriteOnConflict:YES
                                                 transaction:transaction];
            break;
        case DSKProtoVerifiedStateUnverified:
            OWSFailDebug(@"Verification state sync message for recipientId: %@ has unexpected value: %@.",
                recipientId,
                OWSVerificationStateToString(OWSVerificationStateNoLongerVerified));
            return;
    }

    [self fireIdentityStateChangeNotification];
}

- (void)tryToApplyVerificationStateFromSyncMessage:(OWSVerificationState)verificationState
                                       recipientId:(NSString *)recipientId
                                       identityKey:(NSData *)identityKey
                               overwriteOnConflict:(BOOL)overwriteOnConflict
                                       transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);

    if (recipientId.length < 1) {
        OWSFailDebug(@"Verification state sync message missing recipientId.");
        return;
    }

    if (identityKey.length != kStoredIdentityKeyLength) {
        OWSFailDebug(@"Verification state sync message missing identityKey: %@", recipientId);
        return;
    }
    
    OWSRecipientIdentity *_Nullable recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId
                                                                                          transaction:transaction];
    if (!recipientIdentity) {
        // There's no existing recipient identity for this recipient.
        // We should probably create one.
        
        if (verificationState == OWSVerificationStateDefault) {
            // There's no point in creating a new recipient identity just to
            // set its verification state to default.
            return;
        }
        
        // Ensure a remote identity exists for this key. We may be learning about
        // it for the first time.
        [self saveRemoteIdentity:identityKey recipientId:recipientId protocolContext:transaction];
        
        recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId
                                                              transaction:transaction];
        
        if (recipientIdentity == nil) {
            OWSFailDebug(@"Missing expected identity: %@", recipientId);
            return;
        }
        
        if (![recipientIdentity.recipientId isEqualToString:recipientId]) {
            OWSFailDebug(@"recipientIdentity has unexpected recipientId: %@", recipientId);
            return;
        }
        
        if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
            OWSFailDebug(@"recipientIdentity has unexpected identityKey: %@", recipientId);
            return;
        }
        
        if (recipientIdentity.verificationState == verificationState) {
            return;
        }
        
        DDLogInfo(@"%@ setVerificationState: %@ (%@ -> %@)",
                  self.logTag,
                  recipientId,
                  OWSVerificationStateToString(recipientIdentity.verificationState),
                  OWSVerificationStateToString(verificationState));
        
        [recipientIdentity updateWithVerificationState:verificationState
         transaction:transaction];
        
        // No need to call [saveChangeMessagesForRecipientId:..] since this is
        // a new recipient.
    } else {
        // There's an existing recipient identity for this recipient.
        // We should update it.
        if (![recipientIdentity.recipientId isEqualToString:recipientId]) {
            OWSFailDebug(@"recipientIdentity has unexpected recipientId: %@", recipientId);
            return;
        }
        
        if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
            // The conflict case where we receive a verification sync message
            // whose identity key disagrees with the local identity key for
            // this recipient.
            if (!overwriteOnConflict) {
                DDLogWarn(@"recipientIdentity has non-matching identityKey: %@", recipientId);
                return;
            }
            
            DDLogWarn(@"recipientIdentity has non-matching identityKey; overwriting: %@", recipientId);
            [self saveRemoteIdentity:identityKey recipientId:recipientId protocolContext:transaction];
            
            recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:recipientId
                                                                  transaction:transaction];
            
            if (recipientIdentity == nil) {
                OWSFailDebug(@"Missing expected identity: %@", recipientId);
                return;
            }
            
            if (![recipientIdentity.recipientId isEqualToString:recipientId]) {
                OWSFailDebug(@"recipientIdentity has unexpected recipientId: %@", recipientId);
                return;
            }
            
            if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
                OWSFailDebug(@"recipientIdentity has unexpected identityKey: %@", recipientId);
                return;
            }
        }
        
        if (recipientIdentity.verificationState == verificationState) {
            return;
        }
        
        [recipientIdentity updateWithVerificationState:verificationState
                                           transaction:transaction];
        
        [self saveChangeMessagesForRecipientId:recipientId
                             verificationState:verificationState
                                 isLocalChange:NO
                           isSendSystemMessage:YES
                                   transaction:transaction];
    }
}

// We only want to create change messages in response to user activity,
// on any of their devices.
- (void)saveChangeMessagesForRecipientId:(NSString *)recipientId
                       verificationState:(OWSVerificationState)verificationState
                           isLocalChange:(BOOL)isLocalChange
                     isSendSystemMessage:(BOOL)isSendSystemMessage
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(transaction);

    NSMutableArray<TSMessage *> *messages = [NSMutableArray new];

    TSContactThread *contactThread =
        [TSContactThread getOrCreateThreadWithContactId:recipientId transaction:transaction];
    OWSAssertDebug(contactThread);
    if (isSendSystemMessage) {
        [messages addObject:[[OWSVerificationStateChangeMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                  thread:contactThread
                                                                             recipientId:recipientId
                                                                       verificationState:verificationState
                                                                           isLocalChange:isLocalChange]];
    }

    /*
    for (TSGroupThread *groupThread in
        [TSGroupThread groupThreadsWithRecipientId:recipientId transaction:transaction]) {
        [messages
            addObject:[[OWSVerificationStateChangeMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                            thread:groupThread
                                                                       recipientId:recipientId
                                                                 verificationState:verificationState
                                                                     isLocalChange:isLocalChange]];
    }
    */
    
    for (TSMessage *message in messages) {
        [message anyInsertWithTransaction:transaction];
    }
}

#pragma mark - Debug

#if DEBUG
- (void)clearIdentityState:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);
    
    [self.ownIdentityKeyValueStore removeAllWithTransaction:transaction];
    
    [self.ownTrustedIdentityKeyValueStore removeAllWithTransaction:transaction];
}

- (NSString *)identityKeySnapshotFilePath
{
    // Prefix name with period "." so that backups will ignore these snapshots.
    NSString *dirPath = [OWSFileSystem appDocumentDirectoryPath];
    return [dirPath stringByAppendingPathComponent:@".identity-key-snapshot"];
}

- (NSString *)trustedKeySnapshotFilePath
{
    // Prefix name with period "." so that backups will ignore these snapshots.
    NSString *dirPath = [OWSFileSystem appDocumentDirectoryPath];
    return [dirPath stringByAppendingPathComponent:@".trusted-key-snapshot"];
}

#endif

#pragma mark - Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    // We want to defer this so that we never call this method until
    // [UIApplicationDelegate applicationDidBecomeActive:] is complete.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)1.f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self tryToSyncQueuedVerificationStates];
    });
}

#pragma mark - for data migrator

- (void)migratorIdentityKey:(ECKeyPair *)key transaction:(SDSAnyWriteTransaction *)transaction{
    [self.ownIdentityKeyValueStore setObject:key
                                         key:OWSPrimaryStorageIdentityKeyStoreIdentityKey
                                 transaction:transaction];
}

@end

NS_ASSUME_NONNULL_END
