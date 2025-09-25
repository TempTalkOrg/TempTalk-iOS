//
//  DTEncryptedMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const DTProtoDecryptMessageException;

extern NSString * const DTProtoEncryptMessageException;

@class DTMsgPeerContextParams;

@interface DTEncryptedMessage : NSObject

@property (nonatomic, assign) int version;

@property (nonatomic, strong) NSData *cipherText;

@property (nonatomic, strong) NSData *signedEKey;

@property (nonatomic, strong) NSData *eKey;

@property (nonatomic, strong) NSData *identityKey;

//send
@property (nonatomic, strong, nullable) NSArray<DTMsgPeerContextParams *> *eRMKeys;

//receive
@property (nonatomic, strong, nullable) NSData *eRMKey;

@property (nonatomic, strong) NSData *serialized;



- (instancetype)init_throws_withVersion:(int)version
                             cipherText:(NSData *)cipherText
                             signedEKey:(NSData *)signedEKey
                                   eKey:(NSData *)eKey
                            identityKey:(NSData *)identityKey
                                eRMKeys:(NSArray<DTMsgPeerContextParams *> *)eRMKeys;

- (nullable instancetype)initWithData:(nullable NSData *)serialized
                               eRMKey:(nullable NSData *)eRMKey
                                error:(NSError **)outError;

@end

NS_ASSUME_NONNULL_END
