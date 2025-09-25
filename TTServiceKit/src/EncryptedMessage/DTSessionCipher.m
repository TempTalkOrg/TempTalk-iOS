//
//  DTSessionCipher.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/15.
//

#import "DTSessionCipher.h"
#import <Curve25519Kit/Curve25519.h>
#import <Curve25519Kit/Ed25519.h>
#import <HKDFKit/HKDFKit.h>
#import "SSKCryptography.h"
#import "NSData+keyVersionByte.h"
#import "SCKExceptionWrapper.h"
#import "DTEncryptedMessage.h"
#import "AxolotlExceptions.h"
#import "DTMsgPeerContextParams.h"
#import "NSData+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <DTProto/DTProto-Swift.h>
#import "OWSIdentityManager.h"
#import "DTSessionRecord.h"

@interface DTSessionCipher ()

@property (nonatomic, readonly) NSString *recipientId;
@property (nonatomic, readonly) NSArray<NSString *> *recipientIds;
@property (nonatomic, readonly) DTEncryptedMessageType type;

@end

@implementation DTSessionCipher

- (instancetype)initWithRecipientId:(NSString *)recipientId
                                type:(DTEncryptedMessageType)type {
    if(self = [super init]){
        _recipientId = recipientId;
        _type = type;
    }
    
    return self;
    
}

- (instancetype)initWithRecipientIds:(NSArray<NSString *> *)recipientIds
                                type:(DTEncryptedMessageType)type {
    if(self = [super init]){
        _recipientIds = recipientIds;
        _type = type;
    }
    
    return self;
}

- (nullable DTEncryptedMessage *)encryptMessage:(NSData *)paddedMessage
                                    transaction:(SDSAnyReadTransaction *)transaction
                                          error:(NSError **)outError
{
    __block DTEncryptedMessage *_Nullable result;
    [SCKExceptionWrapper
        tryBlock:^{
            result = [self throws_encryptMessage:paddedMessage transaction:transaction];
        }
           error:outError];

    return result;
}

- (DTEncryptedMessage *)throws_encryptMessage:(NSData *)paddedMessage
                                  transaction:(SDSAnyReadTransaction *)transaction {
    
    ECKeyPair *localIdKeyPair = [OWSIdentityManager.sharedManager identityKeyPairWithTransaction:transaction];
    NSMutableDictionary *pubIdKeys = @{}.mutableCopy;
    NSData *pubIdKey = [NSData data];
    
    int version = MESSAGE_CURRENT_VERSION;
    NSArray<DTMsgPeerContextParams *> *eRMKeys = nil;
    
    NSString *encryptedMessageType = @"";
    
    if (self.type == DTEncryptedMessageTypeGroup) {
        
        encryptedMessageType = @"Group";
        
        if(!self.recipientIds.count){
            OWSLogError(@"Invalid recipientIds.");
            OWSRaiseException(DTProtoEncryptMessageException, @"Invalid recipientIds.");
        }
        
        [self.recipientIds enumerateObjectsUsingBlock:^(NSString * _Nonnull recipientId, NSUInteger idx, BOOL * _Nonnull stop) {
            
            DTSessionRecord *sessionRecord = [TTSessionStore loadSessionWithIdentifier:recipientId transaction:transaction];
            if(sessionRecord.remoteIdentityKey.length){
                pubIdKeys[recipientId] = sessionRecord.remoteIdentityKey;
            } else {
                OWSLogWarn(@"remoteIdentityKey is empty!");
            }
            
        }];
        
    } else if (self.type == DTEncryptedMessageTypePrivate) {
        
        encryptedMessageType = @"Private";
        
        DTSessionRecord *sessionRecord = [TTSessionStore loadSessionWithIdentifier:self.recipientId transaction:transaction];
        pubIdKey = sessionRecord.remoteIdentityKey;
        
        DTMsgPeerContextParams *peerContextParams = [[DTMsgPeerContextParams alloc] initWithDestination:self.recipientId
                                                                              destinationRegistrationId:sessionRecord.remoteRegistrationId
                                                                                            peerContext:nil];
        eRMKeys = @[peerContextParams];
        
    } else {
        OWSLogError(@"Invalid encryption type.");
        OWSRaiseException(DTProtoEncryptMessageException, @"Invalid encryption type.");
    }
    
    
    DTProtoAdapter *protoAdapter = [DTProtoAdapter new];
    NSError *error;
    DTEncryptedMsgResult *result = [protoAdapter encryptMessageWithVersion:version
                                                                  pubIdKey:pubIdKey
                                                                  pubIdKeys:pubIdKeys.copy
                                                                localPriKey:localIdKeyPair.privateKey
                                                                  plainText:paddedMessage
                                                                      error:&error];
    if(error){
        OWSLogError(@"encrypt error: %@", error);
        @throw [NSException exceptionWithName:DTProtoEncryptMessageException reason:[NSString stringWithFormat:@"%@ Encryption:%@", encryptedMessageType, [self errorMsgWithError:error]] userInfo:nil];
    }
    if (self.type == DTEncryptedMessageTypeGroup) {
        NSMutableArray *peerContexts = @[].mutableCopy;
        [result.ermKeys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSData * _Nonnull obj, BOOL * _Nonnull stop) {
            DTSessionRecord *sessionRecord = [TTSessionStore loadSessionWithIdentifier:key transaction:transaction];
            DTMsgPeerContextParams *peerContextParams = [[DTMsgPeerContextParams alloc] initWithDestination:key
                                                                                  destinationRegistrationId:sessionRecord.remoteRegistrationId
                                                                                                peerContext:[obj base64EncodedString]];
            [peerContexts addObject:peerContextParams];
        }];
        eRMKeys = peerContexts.copy;
    }
    
    DTEncryptedMessage * message = [[DTEncryptedMessage alloc] init_throws_withVersion:version
                                                                            cipherText:result.cipherText
                                                                            signedEKey:result.signedEKey
                                                                                  eKey:result.eKey
                                                                           identityKey:result.identityKey
                                                                               eRMKeys:eRMKeys];
    
    return message;
     
    
}

- (nullable NSData *)decrypt:(DTEncryptedMessage *)message
             localTheirIdKey:(NSString *)localTheirIdKey
                 transaction:(SDSAnyReadTransaction *)transaction
                       error:(NSError **)outError
{
    __block NSData *_Nullable result;
    [SCKExceptionWrapper
        tryBlock:^{
        result = [self throws_decrypt:message localTheirIdKey:localTheirIdKey transaction:transaction];
        }
           error:outError];

    return result;
}

- (DTDecryptedMsgResult *)decryptWithMessage:(DTEncryptedMessage *)message
                         localTheirIdKeyData:(NSData *)localTheirIdKeyData
                             localPriKeyData:(NSData *)localPriKeyData
                                       error:(NSError **)outError {
    DTProtoAdapter *protoAdapter = [DTProtoAdapter new];
    DTDecryptedMsgResult *result = [protoAdapter decryptMessageWithVersion:message.version
                                                                signedEKey:message.signedEKey
                                                                theirIdKey:message.identityKey
                                                           localTheirIdKey:localTheirIdKeyData
                                                                      eKey:message.eKey
                                                               localPriKey:localPriKeyData
                                                                    ermKey:message.eRMKey
                                                                cipherText:message.cipherText
                                                                     error:outError];
    return result;
}

BOOL isMoreThanOneDayAgo(NSTimeInterval timestamp) {
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeDifference = currentTimestamp - timestamp;
    return timeDifference > 24 * 60 * 60; // 24小时 * 60分钟 * 60秒
}

- (NSData *)throws_decrypt:(DTEncryptedMessage *)message
           localTheirIdKey:(NSString *)localTheirIdKey
               transaction:(SDSAnyReadTransaction *)transaction {
    
    
    ECKeyPair *localIdKeyPair = [OWSIdentityManager.sharedManager identityKeyPairWithTransaction:transaction];
    NSData *localTheirIdKeyData = [[NSData dataFromBase64StringNoPadding:localTheirIdKey] throws_removeKeyType];
    NSError *error;
    DTDecryptedMsgResult * result = [self decryptWithMessage:message
                                         localTheirIdKeyData:localTheirIdKeyData
                                             localPriKeyData:localIdKeyPair.privateKey
                                                       error:&error];
    if(error){
        BOOL useOldKey = NO;
        NSError *retryError;
        NSNumber *idKeyTime = [[OWSIdentityManager sharedManager] identityKeyTimeWithTransaction:transaction];
        if (DTParamsUtils.validateNumber(idKeyTime)){
            NSTimeInterval idKeyTimestamp = idKeyTime.longValue;
            if(idKeyTimestamp > 0 && !isMoreThanOneDayAgo(idKeyTimestamp)) {
                ECKeyPair *oldLocalIdKeyPair = [[OWSIdentityManager sharedManager] oldIdentityKeyPair:transaction];
                if(oldLocalIdKeyPair.privateKey){
                    useOldKey = YES;
                    OWSLogInfo(@"retry decrypt message use old key.");
                    result = [self decryptWithMessage:message
                                  localTheirIdKeyData:localTheirIdKeyData
                                      localPriKeyData:oldLocalIdKeyPair.privateKey
                                                error:&retryError];
                }
            }
        }
        if (!useOldKey || retryError) {
            NSString *encryptedMessageType = @"Private";
            if (self.type == DTEncryptedMessageTypeGroup) {
                encryptedMessageType = @"Group";
            }
            OWSLogInfo(@"decrypt useOldKey: %d, error: %@",useOldKey ,error);
            @throw [NSException exceptionWithName:DTProtoDecryptMessageException reason:[NSString stringWithFormat:@"%@ useOldKey: %d, Decryption:%@", encryptedMessageType, useOldKey, [self errorMsgWithError:error]] userInfo:nil];
        }
    }
    
    if(DTParamsUtils.validateString(localTheirIdKey)){
        if(!result.verifiedIDResult) {
            NSString *logInfo = [NSString stringWithFormat:@"Decryption:verifiedID failed! source = %@, sourceDevice = %u, messageIdKey = %@, remoteIdKey = %@.", self.recipientId, self.sourceDevice, [message.identityKey base64EncodedString], [localTheirIdKeyData base64EncodedString]];
            OWSLogWarn(@"%@", logInfo);
            OWSProdError(logInfo);
        }
    } else {
        OWSLogWarn(@"Decryption:remoteTheirIdKey is empty!");
        OWSProdError(@"Decryption:remoteTheirIdKey is empty!");
    }
    
    return result.plainText;
}

- (NSString *)errorMsgWithError:(NSError *)error {
    return [NSString stringWithFormat:@"[code:%ld, description:%@]", error.code, error.description];
}

@end
