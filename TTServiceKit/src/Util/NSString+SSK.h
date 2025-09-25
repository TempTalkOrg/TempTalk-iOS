//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MeetingAccoutPrefix_iOS;
extern NSString *const MeetingAccoutPrefix_Mac;
extern NSString *const MeetingAccoutPrefix_Web;
extern NSString *const MeetingAccoutPrefix_Android;


@interface NSString (SSK)

- (NSString *)filterAsE164;

- (NSString *)rtlSafeAppend:(NSString *)string;

- (NSString *)substringBeforeRange:(NSRange)range;

- (NSString *)substringAfterRange:(NSRange)range;

/// URL query params encode
- (NSString *)stringByURLQueryEncode;

+ (NSString *)stringRemoveNumberPrefix_Plus:(NSString *)originString;
- (NSString *)stringRemoveNumberPrefix_Plus;

+ (NSString *)stringByAppendNumberPrefix_Plus:(NSString *)originString;

// 移除 name 中的 BU 信息
- (NSString *)removeBUMessage;

// MARK: meeting

+ (NSString *)transforUserAccountToCallNumber:(NSString *)userAccount;
- (NSString *)transforUserAccountToCallNumber;
- (NSArray <NSString *> *)transforCallNumberToUserAccounts;
- (NSString *)transforToIOSAccount;
- (NSString *)getWebUserName;

/// 找到自己 call account 的另一端--目前支持 ios/mac/android
/// @param account 查询的一端
+ (NSArray <NSString *> *)findOthersideAccountByAccount:(NSString *)account;
- (NSArray <NSString *> *)findOthersideAccountByAccount;

- (NSComparisonResult)compareWithVersion:(NSString *)aVersionString;

- (BOOL)isNewerThanVersion:(NSString *)aVersionString;

- (BOOL)isOlderThanVersion:(NSString *)aVersionString;

- (BOOL)isSameToVersion:(NSString *)aVersionString;

//truncate a string containing complete emoji
- (NSString *)composedCharacterStringWithRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
