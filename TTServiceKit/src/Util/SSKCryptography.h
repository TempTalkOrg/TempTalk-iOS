//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

//extern const NSUInteger kAES256_KeyByteLength;

/// Key appropriate for use in AES128 crypto
@interface SSKAES256Key : NSObject <NSSecureCoding>

/// Generates new secure random key
- (instancetype)init;
+ (instancetype)generateRandomKey;

/**
 * @param data  representing the raw key bytes
 *
 * @returns a new instance if key is of appropriate length for AES128 crypto
 *          else returns nil.
 */
+ (nullable instancetype)keyWithData:(NSData *)data;

/// The raw key material
@property (nonatomic, readonly) NSData *keyData;

@end

@interface SSKCryptography : NSObject

typedef NS_ENUM(NSInteger, SSKMACType) {
    SSKHMACSHA1Truncated10Bytes   = 1,
    SSKHMACSHA256Truncated10Bytes = 2,
    SSKHMACSHA256AttachementType  = 3
};

+ (NSData *)generateRandomBytes:(NSUInteger)numberBytes;

+ (uint32_t)randomUInt32;
+ (uint64_t)randomUInt64;
+ (void)seedRandom;

#pragma mark - SHA and HMAC methods

// Full length SHA256 digest for `data`
+ (nullable NSData *)computeSHA256Digest:(NSData *)data;

+ (nullable NSData *)computeSHA512Digest:(NSData *)data;

// Truncated SHA256 digest for `data`
+ (nullable NSData *)computeSHA256Digest:(NSData *)data truncatedToBytes:(NSUInteger)truncatedBytes;

+ (nullable NSString *)truncatedSHA1Base64EncodedWithoutPadding:(NSString *)string;

+ (nullable NSData *)decryptAppleMessagePayload:(NSData *)payload withSignalingKey:(NSString *)signalingKeyString;

#pragma mark encrypt and decrypt attachment data

// Though digest can and will be nil for legacy clients, we now reject attachments lacking a digest.
// ⚠️Deprecated: useMd5Hash 字段废弃，内部通过 digest 的长度判断本地生成 digest 使用 md5 还是 sha256
+ (nullable NSData *)decryptAttachment:(NSData *)dataToDecrypt
                               withKey:(NSData *)key
                                digest:(nullable NSData *)digest
                            useMd5Hash:(BOOL)useMd5Hash
                          unpaddedSize:(UInt32)unpaddedSize
                                 error:(NSError **)error;

+ (nullable NSData *)encryptAttachmentData:(NSData *)attachmentData
                                      eKey:(NSData * _Nullable)encryptionKey
                                   hmacKey:(NSData * _Nullable)hmacKey
                                    outKey:(NSData *_Nonnull *_Nullable)outKey
                                 outDigest:(NSData *_Nonnull *_Nullable)outDigest
                                useMd5Hash:(BOOL)useMd5Hash;

+ (nullable NSData *)encryptAESGCMWithData:(NSData *)plaintextData key:(SSKAES256Key *)key;
+ (nullable NSData *)decryptAESGCMWithData:(NSData *)encryptedData key:(SSKAES256Key *)key;
+ (NSString *)getMd5WithString:(NSString *)string;

+ (NSData *)computeMD5Digest:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
