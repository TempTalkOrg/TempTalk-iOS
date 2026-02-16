//
//  NSString+Encode.h
//  TTServiceKit
//
//  Created by hornet on 2023/4/13.
//

#import <Foundation/Foundation.h>
@class ECKeyPair;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Encode)

+ (NSString *)base64EncodedStringFromData:(NSData *)stringData;

+ (NSString *)base64UrlEncode:(NSData *)input;

+ (NSData *)base64UrlDecode:(NSString *)input;

+ (NSString *)generateChallengeCode;

///加密ChallengeCode
+ (NSString *)encryptChallengeCode:(NSString *)challengeCode withKey:(NSData *) publicKey;

///解密challengeCode
+ (NSString *)decryptChallengeCode:(NSString *)encryptedChallengeCode withKey:(NSData *) publicKey;

//+ (NSString *)base58EncodedString:(NSString *)encodedString;

+ (NSString *)base58EncodedNumber:(NSString *)encodedString;

/// 获取用户ID显示文本，优先使用customUid，次选使用base58编码的uid
/// @param customUid 自定义用户ID
/// @param recipientId 用户ID（电话号码）
+ (NSString *)displayUserIdWithCustomUid:(nullable NSString *)customUid recipientId:(NSString *)recipientId;

@end

NS_ASSUME_NONNULL_END
