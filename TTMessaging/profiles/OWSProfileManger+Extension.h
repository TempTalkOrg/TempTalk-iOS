//
//  OWSProfileManger+Extension.h
//  TTMessaging
//
//  Created by hornet on 2021/11/8.
//
NS_ASSUME_NONNULL_BEGIN
@interface OWSProfileManager ()

- (NSString *)profileAvatarsDirPath;
- (nullable NSData *)decryptProfileData:(nullable NSData *)encryptedData profileKey:(SSKAES256Key *)profileKey;
- (void)writeAvatarToDisk:(UIImage *)avatar
                  success:(void (^)(NSData *data, NSString *fileName))successBlock
                  failure:(void (^)(void))failureBlock;
@end

NS_ASSUME_NONNULL_END
