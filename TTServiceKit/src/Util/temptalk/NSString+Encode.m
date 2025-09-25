//
//  NSString+Encode.m
//  TTServiceKit
//
//  Created by hornet on 2023/4/13.
//

#import "NSString+Encode.h"
#import <Curve25519Kit/Curve25519.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "OWSIdentityManager.h"
#import "SSKCryptography.h"

@implementation NSString (Encode)

+ (NSString *)base64EncodedStringFromData:(NSData *)stringData {
    return [stringData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

+ (NSString *)base64UrlEncode:(NSData *)input {
    NSString *base64String = [input base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return base64String;
}

+ (NSData *)base64UrlDecode:(NSString *)input {
    NSString *base64String = [input stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (base64String.length % 4 != 0) {
    base64String = [base64String stringByAppendingString:@"="];
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return data;
    
}

///生成8位字符串
+ (NSString *)generateChallengeCode {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:8];

    for (int i = 0; i < 8; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }

    NSString *urlEncodedString = [randomString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return urlEncodedString;
}

//加密
+ (NSString *)encryptChallengeCode:(NSString *)challengeCode withKey:(NSData *) publicKey {
    ECKeyPair *idKeyPair = [OWSIdentityManager sharedManager].identityKeyPair;
    NSData *sharedSecret = [Curve25519 throws_generateSharedSecretFromPublicKey:publicKey andKeyPair:idKeyPair];
    SSKAES256Key *aes256Key = [SSKAES256Key keyWithData:sharedSecret];
    ///得到原始的challengeCode
//    NSData *challengeCodeData = [self base64UrlDecode:challengeCode];
    NSData *challengeCodeData = [[NSData alloc] initWithBase64EncodedString:challengeCode options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *secChallengeCodeData=  [SSKCryptography encryptAESGCMWithData:challengeCodeData key:aes256Key];
    NSString *encryptedChallengeCodeString = [secChallengeCodeData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    return encryptedChallengeCodeString;
}

//解密
+ (NSString *)decryptChallengeCode:(NSString *)encryptedChallengeCode withKey:(NSData *) publicKey {
    
    //将base64 后的字符串 转成NSData 类型
    NSData *secData = [[NSData alloc] initWithBase64EncodedString:encryptedChallengeCode options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    //使用获取到的公钥和自己的私钥进行协商
    ECKeyPair *identityKeyPair = [[OWSIdentityManager sharedManager] identityKeyPair];
    
    NSData *sharedSecret =
    [Curve25519 throws_generateSharedSecretFromPublicKey:publicKey andKeyPair:identityKeyPair];
    SSKAES256Key *aes256Key = [SSKAES256Key keyWithData:sharedSecret];
   
    //解密 secData ，且 resultMkData 是原始的challengeCode
    NSData *resultMkData = [SSKCryptography decryptAESGCMWithData:secData key:aes256Key];
    NSString *decryptedString = [resultMkData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    return decryptedString;
}

+ (NSString *)base58EncodedString:(NSString *)encodedString {
    if([[encodedString ows_stripped] hasPrefix:@"+"]){
        encodedString = [encodedString stringByReplacingOccurrencesOfString:@"+" withString:@""];
    }
    NSData *dataToEncode = [encodedString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base58String = [Base58Util encode:dataToEncode];
    return base58String;
}

+ (NSString *)decodeBase58String:(NSString *)base58String {
    NSData *base58Data = [Base58Util decode:base58String];
    NSString *decodeBase58String = [[NSString alloc] initWithData:base58Data encoding:NSUTF8StringEncoding];
    return decodeBase58String;
}


+ (NSString *)base58EncodedNumber:(NSString *)encodedString {
    if (encodedString.length == 0) {
        return nil;
    }
    
    if([[encodedString ows_stripped] hasPrefix:@"+"]){
        encodedString = [encodedString stringByReplacingOccurrencesOfString:@"+" withString:@""];
    }
    long long number = [encodedString longLongValue];
    NSString *base58String = [Base58Util encodeNumber:number];
    return base58String;
}

//+ (NSString *)decodeBase58Number:(NSString *)base58String {
//    UInt64 decoded = [Base58Util decodeToNumber:base58String];
//    return [NSString stringWithFormat:@"%@", @(decoded)];
//}

@end
