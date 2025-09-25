//
//  DTPatternHelper.h
//  TTMessaging
//
//  Created by hornet on 2021/12/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kFormatSchemaPattern;

@interface DTPatternHelper : NSObject

+ (BOOL)isAppUid:(NSString *)uid;

+ (BOOL)validateEmail:(NSString *)email;
+ (BOOL)validateInvitedCode:(NSString *)invitedCode;
+ (BOOL)validateBChatInvitedCode:(NSString *)invitedCode;
+ (BOOL)validateVCode:(NSString *)vCode;
+ (NSString *)verification:(NSString *)invitedCode;
+ (NSString *)getForwardUidString:(NSString *)forwardMessage;
+ (NSString *)getNumberString:(NSString *)forwardMessage;
+ (void)getForwardMessageSourceTextWith:(NSString *)forwardMessage withCallBack:(void(^)(NSRange)) callBack;
+ (void)getForwardMessageURLtWith:(NSString *)forwardMessage withCallBack:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack;

//获取所有的 NSTextCheckingResult
+ (void)getForwardMessageSourceTextWith:(NSString *)forwardMessage withCallBackCheckingResult:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack;


/// 获取string内所有的url(prefix是mailto:表示email,其他为url)
/// - Parameters:
///   - string: string
///   - block: block
+ (void)getUrlsFromString:(NSString *)string usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop))block;

+ (void)matchResultFormString:(NSString *)string
                      pattern:(NSString *)pattern
                   usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL *stop))block;

+ (NSArray<NSTextCheckingResult *> *)matchResultFormString:(NSString *)string
                                                   pattern:(NSString *)pattern;


#pragma mark - temptalk
+ (NSString *)verificationTextInputNumerWithPlus:(NSString *)phoneNumer;

+ (NSString *)verificationTextInputNumer:(NSString *)phoneNumer;

+ (BOOL)validateSecurityChativeInvitedURL:(NSString *)url;

+ (BOOL)validateChativeInvitedCode:(NSString *)invitedCode;

+ (BOOL)validatePeroidChativeInvitedURL:(NSString *)url;
///是否是有效的temptalk链接
+ (BOOL)validateTempTalkInvitedURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
