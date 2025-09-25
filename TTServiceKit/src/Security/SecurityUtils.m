//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SecurityUtils.h"
#import <SignalCoreKit/Randomness.h>
#import <CommonCrypto/CommonDigest.h>

@implementation SecurityUtils

+ (NSData *)generateRandomBytes:(NSUInteger)length
{
    return [Randomness generateRandomBytes:(int)length];
}

//获取一个字符串的MD5值  默认32位 小写
//@return 字符串的 md5值
// 16位MD5加密方式
//提取32位MD5散列的中间16位
+ (NSString *)getMd5WithString:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}


@end
