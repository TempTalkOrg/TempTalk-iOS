//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSConstants.h"
@class Contact;
NS_ASSUME_NONNULL_BEGIN

extern NSString *const TSRegistrationErrorDomain;
extern NSString *const TSRegistrationErrorUserInfoHTTPStatus;
extern NSNotificationName const NSNotificationNameDeregistrationStateDidChange;
extern NSNotificationName const NSNotificationNameRegistrationStateDidChange;
extern NSNotificationName const NSNotificationNameLocalNumberDidChange;
extern NSNotificationName const NSNotificationNameLoginWithNewNumber;

//@class OWSPrimaryStorage;
@class DTChatFolderEntity;
@class SDSKeyValueStore;
@class SDSAnyWriteTransaction;
@class SDSAnyReadTransaction;
@class DTPasskeyManager;
@class DTAPIMetaEntity;
@class TSThread;

// 通话类型
typedef NS_ENUM(NSInteger, DTGlobalNotificationType) {
    DTGlobalNotificationTypeALL = 0,// 全部消息
    DTGlobalNotificationTypeMENTION,// 仅@
    DTGlobalNotificationTypeOFF,// 关闭
};

typedef NS_ENUM(NSUInteger, OWSRegistrationState) {
    OWSRegistrationState_Unregistered,
    OWSRegistrationState_PendingBackupRestore,
    OWSRegistrationState_Registered,
    OWSRegistrationState_Deregistered,
    OWSRegistrationState_Reregistering,
};

NSString *NSStringForOWSRegistrationState(OWSRegistrationState value);

@interface TSAccountManager : NSObject

@property (nonatomic, readonly) SDSKeyValueStore *keyValueStore;

@property (nonatomic, assign, readonly, getter=isNewRegister) BOOL newRegister;
// This property is exposed for testing purposes only.
//#ifdef DEBUG
@property (nonatomic, nullable) NSString *phoneNumberAwaitingVerification;
//#endif


@property(atomic, copy) NSString *authtoken;
#pragma mark - Initializers

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

//全局通知类型是否发生了变化
@property (nonatomic, assign) BOOL isChangeGlobalNotificationType;

- (OWSRegistrationState)registrationState;
@property (readonly) BOOL isRegisteredAndReady;

@property (nonatomic, assign) BOOL isSameAccountRelogin;
/**
 *  Returns if a user is registered or not
 *
 *  @return registered or not
 */
+ (BOOL)isRegistered;
- (BOOL)isRegistered;

/**
 *  Returns current phone number for this device, which may not yet have been registered.
 *
 *  @return E164 formatted phone number
 */
+ (nullable NSString *)localNumber;
- (nullable NSString *)localNumber;
- (nullable NSString *)localNumberWithTransaction:(SDSAnyReadTransaction *)transaction;

/**
 *  Returns current agora uid.
 *
 *  @return ios + phone number
 */
+ (nullable NSString *)localCallNumber;
- (nullable NSString *)localCallNumber;

/**
 *  Symmetric key that's used to encrypt message payloads from the server,
 *
 *  @return signaling key
 */
+ (nullable NSString *)signalingKey;
- (nullable NSString *)signalingKey;

/**
 *  The server auth token allows the Signal client to connect to the Signal server
 *
 *  @return server authentication token
 */
+ (nullable NSString *)serverAuthToken;
- (nullable NSString *)serverAuthToken;

/**
 *  The registration ID is unique to an installation of TextSecure, it allows to know if the app was reinstalled
 *
 *  @return registrationID;
 */

+ (uint32_t)getOrGenerateRegistrationId;
+ (uint32_t)getOrGenerateRegistrationId:(SDSAnyWriteTransaction *)transaction;

#pragma mark - Register with phone number

+ (void)registerWithPhoneNumber:(NSString *)phoneNumber
                        success:(void (^)(id responseObject))successBlock
                        failure:(void (^)(NSError *error))failureBlock
                smsVerification:(BOOL)isSMS;

+ (void)rerequestSMSWithSuccess:(void (^)(id responseObject))successBlock failure:(void (^)(NSError *error))failureBlock;

+ (void)rerequestVoiceWithSuccess:(void (^)(id responseObject))successBlock failure:(void (^)(NSError *error))failureBlock;

- (void)verifyAccountWithCode:(NSString *)verificationCode
                          pin:(nullable NSString *)pin
                     passcode:(nullable NSString *)passcode
                      success:(void (^)(void))successBlock
                      failure:(void (^)(NSError *error))failureBlock;

- (void)registerForManualMessageFetchingWithSuccess:(void (^)(void))successBlock
                                            failure:(void (^)(NSError *error))failureBlock;

// Called once registration is complete - meaning the following have succeeded:
// - obtained signal server credentials
// - uploaded pre-keys
// - uploaded push tokens
- (void)didRegister;

#if TARGET_OS_IPHONE

/**
 *  Register's the device's push notification token with the server
 *
 *  @param pushToken Apple's Push Token
 */
- (void)registerForPushNotificationsWithPushToken:(NSString *)pushToken
                                        voipToken:(NSString *)voipToken
                                          success:(void (^)(void))successHandler
                                          failure:(void (^)(NSError *error))failureHandler
    NS_SWIFT_NAME(registerForPushNotifications(pushToken:voipToken:success:failure:));

#endif

+ (void)unregisterTextSecureWithSuccess:(void (^)(void))success failure:(void (^)(NSError *error))failureBlock;

#pragma mark - De-Registration

// De-registration reflects whether or not the "last known contact"
// with the service was:
//
// * A 403 from the service, indicating de-registration.
// * A successful auth'd request _or_ websocket connection indicating
//   valid registration.
- (BOOL)isDeregistered;
- (void)setIsDeregistered:(BOOL)isDeregistered;

#pragma mark - Re-registration

// Re-registration is the process of re-registering _with the same phone number_.

// Returns YES on success.
- (BOOL)resetForReregistration;
- (nullable NSString *)reregisterationPhoneNumberWithTransaction:(SDSAnyReadTransaction *)transaction;
- (BOOL)isReregistering;

- (void)getInternalContactSuccess:(void (^)(NSArray* array))successHandler
                          failure:(void (^)(NSError *error))failureHandler;

- (void)getContactMessageByReceptid:(NSString *)receptid
                               success:(void (^)(Contact* contact))successHandler
                            failure:(void (^)(NSError *error))failureHandler;

/// ⚠️注意本api不建议再使用   建议使用 getContactMessageV2ByPhoneNumber 即v2版本
/// 通过id获取用户联系人信息
/// @param phoneNumber uid
/// @param successHandler 成功回调
/// @param failureHandler 失败回调
//- (void)getContactMessageByPhoneNumber:(NSString *)phoneNumber
//                               success:(void (^)(NSArray* array))successHandler
//                               failure:(void (^)(NSError *error))failureHandler;

/// ⚠️注意本api用于逐步替代 getContactMessageByPhoneNumber即V0版本的api
/// 通过id获取用户联系人信息
/// @param uids uid 数组
/// @param successHandler 成功回调
/// @param failureHandler 失败回调
- (void)getContactMessageV1ByPhoneNumber:(nullable NSArray *)uids
                               success:(void (^)(NSArray* array))successHandler
                                 failure:(void (^)(NSError *error))failureHandler;

- (void)getInviteCodeSuccess:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

- (void)exchangeAccountWithInviteCode:(NSString *)inviteCode
                              success:(void (^)(DTAPIMetaEntity *metaEntity))successHandler
                              failure:(void (^)(NSError *error))failureHandler;

/// 获取chat folder
/// @param successHandler success
/// @param failureHandler failure
- (void)getChatFolderSuccess:(void (^)(NSArray <DTChatFolderEntity *> * chatFolders))successHandler
                     failure:(void (^)(NSError *error))failureHandler;


#pragma mark - for data migrator

- (void)storeLocalNumber:(NSString *)localNumber transaction:(SDSAnyWriteTransaction *)transaction;
- (void)storeServerAuthToken:(NSString *)authToken signalingKey:(NSString *)signalingKey transaction:(SDSAnyWriteTransaction *)transaction;
- (void)setRegistrationId:(uint32_t)registrationID transaction:(SDSAnyWriteTransaction *)transaction;
- (void)setPhoneNumberAwaitingVerification:(NSString *_Nullable)phoneNumberAwaitingVerification;
- (void)setNewRegisterWith:(NSNumber *)isNewRegister;

#pragma mark - temptalk registration

@property(atomic, assign) BOOL hasWebauthn;
@property (nonatomic, strong) DTPasskeyManager *passKeyManager;

@property (nonatomic, copy) NSString *passkeysUserId;

+ (NSString *)generateNewAccountAuthenticationToken;
- (void)storeServerAuthToken:(NSString *)authToken;

- (void)storeUserEmail:(NSString *)email;
- (nullable NSString *)loadStoredUserEmail;

- (void)storeUserPhone:(NSString *)phone;
- (nullable NSString *)loadStoredUserPhone;

#pragma mark - temptalk Transfer

- (BOOL)isTransfered;
- (void)setTransferedSucess:(BOOL)transfered;

@property (nonatomic) BOOL isTransferInProgress;
@property (nonatomic) BOOL wasTransferred;

#pragma mark - new

- (uint32_t)randomANewRegistrationId:(SDSAnyReadTransaction *)transaction;

- (void)storeRegistrationId:(uint32_t)registrationId transaction:(SDSAnyWriteTransaction *)transaction;

- (void)storeInviteCode:(NSString *)inviteCode transaction:(SDSAnyWriteTransaction *)transaction;

- (nullable NSString *)storedInviteCodeWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)storeInviteLink:(NSString *)inviteLink transaction:(SDSAnyWriteTransaction *)transaction;

- (nullable NSString *)storedInviteLinkWithTransaction:(SDSAnyReadTransaction *)transaction;

- (void)storeChallengeCode:(NSString *)challengeCode transaction:(SDSAnyWriteTransaction *)transaction;

- (NSMutableArray *)challengeCodeCache;

- (void)requestLongPeroidInviteCode:(NSNumber *)regenerate
                        shortNumber:(NSNumber *)shortNumber
                            success:(void (^)(DTAPIMetaEntity *metaEntity))successHandler
                            failure:(void (^)(NSError *error))failureHandler;

- (NSString *)groupMeetingMkstringFromThread:(TSThread *)gThread;
- (void)storeGroupMeetingMkstring:(NSString *) meetingKey thread:(TSThread *)gThread;

@end

NS_ASSUME_NONNULL_END
