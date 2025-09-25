//
//  DTSessionCipher.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/15.
//

#import <Foundation/Foundation.h>
#import "DTPrekeyBundle.h"
#import "DTEncryptedMessage.h"

NS_ASSUME_NONNULL_BEGIN

@class DTEncryptedMessage;
@class SDSAnyReadTransaction;

typedef NS_ENUM(NSInteger, DTEncryptedMessageType) {
    DTEncryptedMessageTypePrivate,
    DTEncryptedMessageTypeGroup
};

@interface DTSessionCipher : NSObject

@property (nonatomic, assign) uint32_t sourceDevice;

- (instancetype)initWithRecipientId:(NSString *)recipientId
                                type:(DTEncryptedMessageType)type;

- (instancetype)initWithRecipientIds:(NSArray<NSString *> *)recipientIds
                                type:(DTEncryptedMessageType)type;

- (DTEncryptedMessage *)throws_encryptMessage:(NSData *)paddedMessage
                                  transaction:(SDSAnyReadTransaction *)transaction;
- (nullable DTEncryptedMessage *)encryptMessage:(NSData *)paddedMessage
                                    transaction:(SDSAnyReadTransaction *)transaction
                                          error:(NSError **)outError;

- (NSData *)throws_decrypt:(DTEncryptedMessage *)message
           localTheirIdKey:(NSString *)localTheirIdKey
               transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSData *)decrypt:(DTEncryptedMessage *)message
             localTheirIdKey:(NSString *)localTheirIdKey
                 transaction:(SDSAnyReadTransaction *)transaction
                       error:(NSError **)outError;

@end

NS_ASSUME_NONNULL_END
