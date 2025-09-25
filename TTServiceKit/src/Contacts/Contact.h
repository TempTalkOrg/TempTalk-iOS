//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An adapter for the system contacts
 */
/*
 {
     department = "<null>";
     email = "";
     name = c;
     number = "+75297242237";
     superior = "<null>";
     timeZone = "<null>";
 }
 */
@class CNContact;
@class PhoneNumber;
@class SignalRecipient;
@class UIImage;
@class SDSAnyReadTransaction;

@interface ContactPublicConfigs : MTLModel<MTLJSONSerializing>
@property (nonatomic, copy) NSString *publicName; //裁剪版本的名字
@property (nonatomic, assign) int meetingVersion; //会议的版本号

- (BOOL)isEqualToPublicConfigs:(ContactPublicConfigs *)publicConfigs;

@end

@interface ContactPrivateConfig : MTLModel<MTLJSONSerializing>

@property (nullable,nonatomic, strong) NSNumber *globalNotification;
@property (nonatomic, assign) BOOL voipNotification;
@property (nonatomic, strong, nullable) NSNumber *calendarNotification;
@property (nonatomic, copy) NSString *notificationSound;
@property (nonatomic, strong) NSDictionary *chatFolder;

@end


@interface DTLastSourceEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, copy) NSString *number;//对应用户id
@property (nonatomic, copy) NSString *publicName; //裁剪版本的名字
@end

//NSArray 中字典转模型不成功 待检查，暂时先使用字典
@interface DTThumbsUpEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, strong) NSArray *lastSource;
@property (nonatomic, assign) int thumbsUpCount;
@end


@interface Contact : MTLModel<MTLJSONSerializing>

@property (copy, nonatomic) NSString *name;
@property (nullable, readonly, nonatomic) NSString *firstName;
@property (nullable, readonly, nonatomic) NSString *lastName;
@property (nullable, copy, nonatomic) NSString *remark;//备注名
@property (nonatomic, copy) NSString *fullName;
@property (nullable, copy, nonatomic) NSString *email;
@property (nullable, copy, nonatomic) NSString *number;
@property (nullable, copy, nonatomic) NSString *joinedAt;
@property (nullable, copy, nonatomic) NSString *superior;
@property (nullable, copy, nonatomic) NSString *timeZone;
@property (nullable, copy, nonatomic) NSDictionary *avatar;
@property (nullable, copy, nonatomic) NSString *signature;
@property (nullable, strong, nonatomic) NSNumber* gender;
@property (nullable, copy, nonatomic) NSString *address;
@property (nullable, strong, nonatomic) NSNumber *flag;
@property (nullable,nonatomic, strong) ContactPrivateConfig *privateConfigs;
@property (nonatomic, strong) DTThumbsUpEntity *thumbsUp;
@property (nonatomic, strong) ContactPublicConfigs *publicConfigs;
@property (nullable, nonatomic, strong) NSString *sourceDescribe;

//MARK: vip客户专用
/// displayName
@property (nonatomic, copy) NSString *groupDisplayName;
/// 是否是通讯录API获取的用户, YES:群内不同subteam用户/NO:通讯录接口获取的用户
@property (nonatomic, assign, getter=isExternal) BOOL external;
/// 邮箱后缀区分
@property (nonatomic, strong) NSNumber *extId;
/// 是否可以发送紧急警报
@property (nonatomic, assign) BOOL spookyBotFlag;

@property (readonly, nonatomic) NSString *comparableNameFirstLast;
@property (readonly, nonatomic) NSString *comparableNameLastFirst;
@property (strong,   nonatomic) NSArray<NSString *> *userTextPhoneNumbers;
@property (readonly, nonatomic) NSArray<NSString *> *emails;
@property (readonly, nonatomic) NSString *uniqueId;
@property (nonatomic, readonly) BOOL isSignalContact;
@property (nonatomic, readonly) NSString *cnContactId;

- (NSArray<SignalRecipient *> *)signalRecipientsWithTransaction:(SDSAnyReadTransaction *)transaction;
// TODO: Remove this method.
- (NSArray<NSString *> *)textSecureIdentifiers;

#if TARGET_OS_IOS

- (instancetype)initWithFullName:(NSString *)fullName phoneNumber:(NSString *)number;
- (instancetype)initWithSystemContact:(CNContact *)cnContact NS_AVAILABLE_IOS(9_0);
+ (nullable Contact *)contactWithVCardData:(NSData *)data;
+ (nullable CNContact *)cnContactWithVCardData:(NSData *)data;

- (NSString *)nameForPhoneNumber:(NSString *)recipientId;

- (void)configWithFullName:(NSString *)fullName phoneNumber:(NSString *)number;

- (instancetype)initWithRecipientId:(NSString *)recipientId;

#endif // TARGET_OS_IOS

+ (NSComparator)comparatorSortingNamesByFirstThenLast:(BOOL)firstNameOrdering;
+ (NSString *)formattedFullNameWithCNContact:(CNContact *)cnContact NS_SWIFT_NAME(formattedFullName(cnContact:));

+ (nullable NSData *)avatarDataForCNContact:(nullable CNContact *)cnContact;

- (BOOL)isEqualToContact:(Contact *)contact;


@end

NS_ASSUME_NONNULL_END
