//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSAccountManager.h"
#import "AppContext.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSError.h"
//#import "OWSPrimaryStorage+SessionStore.h"
#import "OWSRequestFactory.h"
#import "SecurityUtils.h"
//#import "TSPreKeyManager.h"
#import "TSVerifyCodeRequest.h"
#import "Contact.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTContactsUpdateMessageProcessor.h"
#import "DTParamsBaseUtils.h"
#import "DTBaseAPI.h"
#import "DTChatFolderManager.h"
#import "DTDBKeyManager.h"
#import <TTServiceKit/Localize_Swift.h>
#import "DTTokenKeychainStore.h"

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const NSNotificationNameLocalNumberDidChange = @"NSNotificationNameLocalNumberDidChange";
NSNotificationName const NSNotificationNameDeregistrationStateDidChange = @"NSNotificationNameDeregistrationStateDidChange";
NSNotificationName const NSNotificationNameRegistrationStateDidChange = @"NSNotificationNameRegistrationStateDidChange";

NSNotificationName const NSNotificationNameLoginWithNewNumber = @"NSNotificationNameLoginWithNewNumber";

NSString *const TSRegistrationErrorDomain = @"TSRegistrationErrorDomain";
NSString *const TSRegistrationErrorUserInfoHTTPStatus = @"TSHTTPStatus";

NSString *const TSAccountManager_RegisteredNumberKey = @"TSStorageRegisteredNumberKey";
NSString *const TSAccountManager_IsDeregisteredKey = @"TSAccountManager_IsDeregisteredKey";
NSString *const TSAccountManager_ReregisteringPhoneNumberKey = @"TSAccountManager_ReregisteringPhoneNumberKey";
NSString *const TSAccountManager_LocalRegistrationIdKey = @"TSStorageLocalRegistrationId";

NSString *const TSAccountManager_UserAccountCollection = @"TSStorageUserAccountCollection";
NSString *const TSAccountManager_ServerAuthToken = @"TSStorageServerAuthToken";
NSString *const TSAccountManager_ServerSignalingKey = @"TSStorageServerSignalingKey";

NSString *const TSAccountManager_IsTransferedKey = @"TSAccountManager_IsTransferedKey";
NSString *const TSAccountManager_IsTransferInProgressKey = @"TSAccountManager_IsTransferInProgressKey";
NSString *const TSAccountManager_UserEmail = @"TSStorageUserEmail";
NSString *const TSAccountManager_UserPhone = @"TSStorageUserPhone";

NSString *const TSAccountManager_InviteCodeKey = @"TSAccountManager_InviteCodeKey";
NSString *const TSAccountManager_InviteLinkKey = @"TSAccountManager_InviteLinkKey";
NSString *const TSAccountManager_ChallengeCodeKey = @"TSAccountManager_ChallengeCodeKey";

NSString *NSStringForOWSRegistrationState(OWSRegistrationState value)
{
    switch (value) {
        case OWSRegistrationState_Unregistered:
            return @"Unregistered";
        case OWSRegistrationState_PendingBackupRestore:
            return @"PendingBackupRestore";
        case OWSRegistrationState_Registered:
            return @"Registered";
        case OWSRegistrationState_Deregistered:
            return @"Deregistered";
        case OWSRegistrationState_Reregistering:
            return @"Reregistering";
    }
}

@interface TSAccountManager ()<DatabaseChangeDelegate>

@property (nonatomic, readonly) BOOL isRegistered;

// This property is exposed publicly for testing purposes only.
//#ifndef DEBUG
//@property (nonatomic, nullable) NSString *phoneNumberAwaitingVerification;
//#endif

@property (nonatomic, nullable) NSString *cachedLocalNumber;

@property (nonatomic, nullable) NSNumber *cachedIsDeregistered;

@property (nonatomic, nullable) NSNumber *cachedIsTransfered;

@property (nonatomic, assign, readwrite) BOOL newRegister;

@property (nonatomic, strong) NSMutableArray *challengeCodeArr;

///缓存的群组会议的MeetingKey，在自己发起群组会议的时候进行缓存
@property (nonatomic, strong) NSDictionary *cachedMeetingKeys;

@end

#pragma mark -

@implementation TSAccountManager

@synthesize isRegistered = _isRegistered;
@synthesize isTransferInProgress = _isTransferInProgress;

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    OWSSingletonAssert();
    
    _keyValueStore = [[SDSKeyValueStore alloc] initWithCollection:TSAccountManager_UserAccountCollection];

    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if (!CurrentAppContext().isMainApp) {
            [self.databaseStorage appendDatabaseChangeDelegate:self];
        }
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetCache)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

- (void)resetCache {
    self.isChangeGlobalNotificationType = false;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

- (void)setPhoneNumberAwaitingVerification:(NSString *_Nullable)phoneNumberAwaitingVerification
{
    _phoneNumberAwaitingVerification = phoneNumberAwaitingVerification;

    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameLocalNumberDidChange
                                                             object:nil
                                                           userInfo:nil];
}

- (void)setNewRegisterWith:(NSNumber *)isNewRegister {
    if(DTParamsUtils.validateNumber(isNewRegister) && [isNewRegister intValue] == 1){
        _newRegister = true;
    } else {
        _newRegister = false;
    }
}

- (OWSRegistrationState)registrationState
{
    if (!self.isRegistered) {
        return OWSRegistrationState_Unregistered;
    } else if (self.isDeregistered) {
        if (self.isReregistering) {
            return OWSRegistrationState_Reregistering;
        } else {
            return OWSRegistrationState_Deregistered;
        }
    } else {
        return OWSRegistrationState_Registered;
    }
}

+ (BOOL)isRegistered
{
    return [[self sharedInstance] isRegistered];
}

- (BOOL)isRegisteredAndReady
{
    return self.registrationState == OWSRegistrationState_Registered;
}

- (BOOL)isRegistered
{
    if (_isRegistered) {
        return YES;
    } else {
        @synchronized (self) {
            // Cache this once it's true since it's called alot, involves a dbLookup, and once set - it doesn't change.
            _isRegistered = [self storedLocalNumber] != nil;
        }
    }
    return _isRegistered;
}

- (void)didRegister
{
    OWSLogInfo(@"%@ didRegister", self.logTag);
    NSString *phoneNumber = self.phoneNumberAwaitingVerification;

    if (!phoneNumber) {
        OWSRaiseException(@"RegistrationFail", @"Internal Corrupted State");
    }

    [self storeLocalNumber:phoneNumber];

    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameRegistrationStateDidChange
                                                             object:nil
                                                           userInfo:nil];

    // Warm these cached values.
    [self isRegistered];
    [self localNumber];
    [self isDeregistered];
}

+ (nullable NSString *)localNumber
{
    return [[self sharedInstance] localNumber];
}

- (nullable NSString *)localNumber
{
    NSString *awaitingVerif = self.phoneNumberAwaitingVerification;
    if (awaitingVerif) {
        return awaitingVerif;
    }

    // Cache this since we access this a lot, and once set it will not change.
    @synchronized(self)
    {
        if (self.cachedLocalNumber == nil) {
            self.cachedLocalNumber = self.storedLocalNumber;
        }
    }

    return self.cachedLocalNumber;
}

- (nullable NSString *)localNumberWithTransaction:(SDSAnyReadTransaction *)transaction
{
    NSString *awaitingVerif = self.phoneNumberAwaitingVerification;
    if (awaitingVerif) {
        return awaitingVerif;
    }

    // Cache this since we access this a lot, and once set it will not change.
    @synchronized(self)
    {
        if (self.cachedLocalNumber == nil) {
            self.cachedLocalNumber = [self storedLocalNumberWithTransaction:transaction];
        }
    }

    return self.cachedLocalNumber;
}


+ (nullable NSString *)localCallNumber {
   return [[self sharedInstance] localCallNumber];
}

- (nullable NSString *)localCallNumber {
    NSString *localNumber = [self localNumber];
    if ([localNumber hasPrefix:@"+"]) {
        localNumber = [localNumber substringFromIndex:1];
    }
    
    return [NSString stringWithFormat:@"ios%@", localNumber];
}


- (nullable NSString *)storedLocalNumber
{
    @synchronized (self) {
        __block NSString *storedLocalNumber = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            storedLocalNumber = [self.keyValueStore getString:TSAccountManager_RegisteredNumberKey transaction:readTransaction];
        }];
        
        return storedLocalNumber;
    }
}

- (nullable NSString *)storedLocalNumberWithTransaction:(SDSAnyReadTransaction *)transaction
{
    @synchronized (self) {
        NSString *storedLocalNumber = [self.keyValueStore getString:TSAccountManager_RegisteredNumberKey transaction:transaction];
        return storedLocalNumber;
    }
}

- (void)storeLocalNumber:(NSString *)localNumber
{
    @synchronized (self) {
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [self.keyValueStore setString:localNumber key:TSAccountManager_RegisteredNumberKey transaction:writeTransaction];
            
            [self.keyValueStore removeValueForKey:TSAccountManager_ReregisteringPhoneNumberKey transaction:writeTransaction];
        });

        self.phoneNumberAwaitingVerification = nil;

        self.cachedLocalNumber = localNumber;
    }
}

+ (uint32_t)getOrGenerateRegistrationId
{
    return [[self sharedInstance] getOrGenerateRegistrationId];
}

+ (uint32_t)getOrGenerateRegistrationId:(SDSAnyWriteTransaction *)transaction
{
    return [[self sharedInstance] getOrGenerateRegistrationId:transaction];
}

- (uint32_t)getOrGenerateRegistrationId
{
    __block uint32_t result;
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        result = [self getOrGenerateRegistrationId:writeTransaction];
    });
    return result;
}

- (uint32_t)getOrGenerateRegistrationId:(SDSAnyWriteTransaction *)transaction
{
    @synchronized(self)
    {
        uint32_t registrationID = [[self.keyValueStore getObjectForKey:TSAccountManager_LocalRegistrationIdKey transaction:transaction] unsignedIntValue];

        if (registrationID == 0) {
            registrationID = (uint32_t)arc4random_uniform(16380) + 1;
            OWSLogWarn(@"%@ Generated a new registrationID: %u", self.logTag, registrationID);

            [self.keyValueStore setObject:[NSNumber numberWithUnsignedInteger:registrationID]
                                      key:TSAccountManager_LocalRegistrationIdKey
                              transaction:transaction];
        }
        return registrationID;
    }
}

- (void)registerForPushNotificationsWithPushToken:(NSString *)pushToken
                                        voipToken:(NSString *)voipToken
                                          success:(void (^)(void))successHandler
                                          failure:(void (^)(NSError *))failureHandler
{
    [self registerForPushNotificationsWithPushToken:pushToken
                                          voipToken:voipToken
                                            success:successHandler
                                            failure:failureHandler
                                   remainingRetries:3];
}

- (void)registerForPushNotificationsWithPushToken:(NSString *)pushToken
                                        voipToken:(NSString *)voipToken
                                          success:(void (^)(void))successHandler
                                          failure:(void (^)(NSError *))failureHandler
                                 remainingRetries:(int)remainingRetries
{
    TSRequest *request =
        [OWSRequestFactory registerForPushRequestWithPushIdentifier:pushToken voipIdentifier:voipToken];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        successHandler();
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        if (remainingRetries > 0) {
            [self registerForPushNotificationsWithPushToken:pushToken
                                                  voipToken:voipToken
                                                    success:successHandler
                                                    failure:failureHandler
                                           remainingRetries:remainingRetries - 1];
        } else {
            NSError *error = errorWrapper.asNSError;
            
            if (!error.isNetworkConnectivityFailure) {
                OWSProdError([OWSAnalyticsEvents accountsErrorRegisterPushTokensFailed]);
            }
            failureHandler(error);
        }
    }];
}

+ (void)registerWithPhoneNumber:(NSString *)phoneNumber
                        success:(void (^)(id responseObject))successBlock
                        failure:(void (^)(NSError *error))failureBlock
                smsVerification:(BOOL)isSMS

{
    if ([self isRegistered]) {
        failureBlock([NSError errorWithDomain:@"tsaccountmanager.verify" code:4000 userInfo:nil]);
        return;
    }

    // The country code of TSAccountManager.phoneNumberAwaitingVerification is used to
    // determine whether or not to use domain fronting, so it needs to be set _before_
    // we make our verification code request.
    TSAccountManager *manager = [self sharedInstance];
    manager.phoneNumberAwaitingVerification = phoneNumber;

    TSRequest *request =
        [OWSRequestFactory requestVerificationCodeRequestWithPhoneNumber:phoneNumber
                                                               transport:(isSMS ? TSVerificationTransportSMS
                                                                                : TSVerificationTransportVoice)];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogInfo(@"Successfully requested verification code request method:%@", isSMS ? @"SMS" : @"Voice");
        
        NSDictionary *responseObject = response.responseBodyJson;
        
        if ([responseObject isKindOfClass:NSDictionary.class]) {
            
            successBlock(responseObject);
        } else {
            NSError *unexpectedError = OWSErrorWithCodeDescription(OWSErrorCodeUnableToProcessServerResponse,
                                                                   Localized(@"REGISTRATION_VERIFICATION_FAILED_TITLE",
                                                                                     @"Error message indicating that registration failed due to a okta error"));
            failureBlock(unexpectedError);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents accountsErrorVerificationCodeRequestFailed]);
        }
        OWSLogError(@"%@ Failed to request verification code request with error:%@", self.logTag, error);
        failureBlock(error);
    }];
}

+ (void)rerequestSMSWithSuccess:(void (^)(id responseObject))successBlock failure:(void (^)(NSError *error))failureBlock
{
    TSAccountManager *manager = [self sharedInstance];
    NSString *number          = manager.phoneNumberAwaitingVerification;

    OWSAssertDebug(number);

    [self registerWithPhoneNumber:number success:successBlock failure:failureBlock smsVerification:YES];
}

+ (void)rerequestVoiceWithSuccess:(void (^)(id responseObject))successBlock failure:(void (^)(NSError *error))failureBlock
{
    TSAccountManager *manager = [self sharedInstance];
    NSString *number          = manager.phoneNumberAwaitingVerification;

    OWSAssertDebug(number);

    [self registerWithPhoneNumber:number success:successBlock failure:failureBlock smsVerification:NO];
}

- (void)registerForManualMessageFetchingWithSuccess:(void (^)(void))successBlock
                                            failure:(void (^)(NSError *error))failureBlock
{
    TSRequest *request = [OWSRequestFactory updateAttributesRequestWithManualMessageFetching:YES];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogInfo(@"%@ updated server with account attributes to enableManualFetching", self.logTag);
        successBlock();
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        OWSLogError(@"%@ failed to updat server with account attributes with error: %@", self.logTag, error);
        failureBlock(error);
    }];
}

- (void)verifyAccountWithCode:(NSString *)verificationCode
                          pin:(nullable NSString *)pin
                     passcode:(nullable NSString *)passcode
                      success:(void (^)(void))successBlock
                      failure:(void (^)(NSError *error))failureBlock
{
    NSString *authToken = [[self class] generateNewAccountAuthenticationToken];
    NSString *signalingKey = [[self class] generateNewSignalingKeyToken];
    NSString *phoneNumber = self.phoneNumberAwaitingVerification;

    OWSAssertDebug(signalingKey);
    OWSAssertDebug(authToken);
    OWSAssertDebug(phoneNumber);

    TSVerifyCodeRequest *request = [[TSVerifyCodeRequest alloc] initWithVerificationCode:verificationCode
                                                                               forNumber:phoneNumber
                                                                                     pin:pin
                                                                            signalingKey:signalingKey
                                                                                 authKey:authToken
                                                                                passcode:passcode];

    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSInteger statusCode = response.responseStatusCode;
        switch (statusCode) {
            case 200:
            case 204: {
                OWSLogInfo(@"%@ Verification code accepted.", self.logTag);
                __block NSString *previousNumber = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                    previousNumber = [self reregisterationPhoneNumberWithTransaction:transaction];
                }];
                if(DTParamsUtils.validateString(previousNumber)) {
                    if(![previousNumber isEqualToString:phoneNumber]) {
                        OWSLogInfo(@"%@ login with new number.", self.logTag);
                        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameLoginWithNewNumber
                                                                                 object:nil
                                                                               userInfo:nil];
                        return;
                    } else {
                        OWSLogInfo(@"%@ relogin with a same number.", self.logTag);
                        self.isSameAccountRelogin = YES;
                    }
                }
                [self storeServerAuthToken:authToken signalingKey:signalingKey];
                [DTIdentityKeyHandler registerIDKeyWithSuccess:successBlock failure:failureBlock];
                break;
            }
            default: {
                OWSLogError(@"%@ Unexpected status while verifying code: %ld", self.logTag, statusCode);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                failureBlock(error);
                break;
            }
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull wrapperError) {
        NSError *error = wrapperError.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
//            OWSProdError([OWSAnalyticsEvents accountsErrorVerifyAccountRequestFailed]);
        }
        
        OWSLogWarn(@"%@ Error verifying code: %@", self.logTag, error.debugDescription);
        
        switch (error.httpStatusCode.integerValue) {
            case 403: {
                NSError *userError = OWSErrorWithCodeDescription(OWSErrorCodeUserError,
                                                                 Localized(@"CODE_EXPIRED_OR_DOES_NOT_EXIST_PLEASE_CHECK",
                                                                                   @"Error message indicating that registration failed due to a missing or incorrect "
                                                                                   "verification code."));
                failureBlock(userError);
                break;
            }
            case 413: {
                // In the case of the "rate limiting" error, we want to show the
                // "recovery suggestion", not the error's "description."
                NSError *userError = OWSErrorWithCodeDescription(OWSErrorCodeUserError,
                                                                 Localized(@"LOGIN_ATTEMPTS_TOO_FREQUENT_PLEASE_TRY_AGAIN",
                                                                                   @"Error message indicating that registration failed due to a missing or incorrect "
                                                                                   "verification code."));
                failureBlock(userError);
                break;
            }
            case 423: {
                NSString *localizedMessage = Localized(@"REGISTRATION_VERIFICATION_FAILED_WRONG_PIN",
                                                               @"Error message indicating that registration failed due to a missing or incorrect 2FA PIN.");
                OWSLogError(@"%@ 2FA PIN required: %ld", self.logTag, error.code);
                NSError *error
                = OWSErrorWithCodeDescription(OWSErrorCodeRegistrationMissing2FAPIN, localizedMessage);
                failureBlock(error);
                break;
            }
            default: {
                OWSLogError(@"%@ verifying code failed with unknown error: %@", self.logTag, error);
                failureBlock(error);
                break;
            }
        }
    }]; 
}

#pragma mark Server keying material

+ (NSString *)generateNewAccountAuthenticationToken {
    NSData *authToken        = [SecurityUtils generateRandomBytes:16];
    NSString *authTokenPrint = [[NSData dataWithData:authToken] hexadecimalString];
    return authTokenPrint;
}

+ (NSString *)generateNewSignalingKeyToken {
    /*The signalingKey is 32 bytes of AES material (256bit AES) and 20 bytes of
     * Hmac key material (HmacSHA1) concatenated into a 52 byte slug that is
     * base64 encoded. */
    NSData *signalingKeyToken        = [SecurityUtils generateRandomBytes:52];
    NSString *signalingKeyTokenPrint = [[NSData dataWithData:signalingKeyToken] base64EncodedString];
    return signalingKeyTokenPrint;
}

+ (nullable NSString *)signalingKey
{
    return [[self sharedInstance] signalingKey];
}

- (nullable NSString *)signalingKey
{
    __block NSString *signalingKey;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        signalingKey = [self.keyValueStore getString:TSAccountManager_ServerSignalingKey transaction:readTransaction];
    }];
    
    return signalingKey;
}

+ (nullable NSString *)serverAuthToken
{
    return [[self sharedInstance] serverAuthToken];
}

- (nullable NSString *)serverAuthToken
{
    __block NSString *serverAuthToken;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        serverAuthToken = [self.keyValueStore getString:TSAccountManager_ServerAuthToken transaction:readTransaction];
    }];
    
    return serverAuthToken;
}

- (void)storeServerAuthToken:(NSString *)authToken signalingKey:(NSString *)signalingKey
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:authToken key:TSAccountManager_ServerAuthToken transaction:writeTransaction];
        [self.keyValueStore setObject:signalingKey key:TSAccountManager_ServerSignalingKey transaction:writeTransaction];
    });
}

- (void)storeServerAuthToken:(NSString *)authToken
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:authToken key:TSAccountManager_ServerAuthToken transaction:writeTransaction];
    });
}

- (void)storeUserEmail:(NSString *)email
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:email key:TSAccountManager_UserEmail transaction:writeTransaction];
    });
}

- (void)storeUserPhone:(NSString *)phone
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:phone key:TSAccountManager_UserPhone transaction:writeTransaction];
    });
}

- (nullable NSString *)loadStoredUserEmail
{
    __block NSString *emailString;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        emailString = [self.keyValueStore getString:TSAccountManager_UserEmail transaction:readTransaction];
    }];
    
    return emailString;
}

- (nullable NSString *)loadStoredUserPhone
{
    
    __block NSString *phoneString;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        phoneString = [self.keyValueStore getString:TSAccountManager_UserPhone transaction:readTransaction];
    }];
    
    return phoneString;
}

+ (void)unregisterTextSecureWithSuccess:(void (^)(void))success failure:(void (^)(NSError *error))failureBlock
{
    TSRequest *request = [OWSRequestFactory unregisterAccountRequest];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogInfo(@"%@ Successfully unregistered", self.logTag);
        success();
        
        // This is called from `[AppSettingsViewController proceedToUnregistration]` whose
        // success handler calls `[Environment resetAppData]`.
        // This method, after calling that success handler, fires
        // `RegistrationStateDidChangeNotification` which is only safe to fire after
        // the data store is reset.
        
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameRegistrationStateDidChange
                                                                 object:nil
                                                               userInfo:nil];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents accountsErrorUnregisterAccountRequestFailed]);
        }
        OWSLogError(@"%@ Failed to unregister with error: %@", self.logTag, error);
        failureBlock(error);
    }];
}

#pragma mark - DatabaseChangeDelegate

- (void)databaseChangesDidUpdateWithDatabaseChanges:(id<DatabaseChanges>)databaseChanges
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    // Do nothing.
}

- (void)databaseChangesDidUpdateExternally
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    OWSLogVerbose(@"");

    // Any database write by the main app might reflect a deregistration,
    // so clear the cached "is registered" state.  This will significantly
    // erode the value of this cache in the SAE.
    @synchronized(self)
    {
        _isRegistered = NO;
    }
}

- (void)databaseChangesDidReset
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    // Do nothing.
}

#pragma mark - De-Registration

- (BOOL)isDeregistered
{
    // Cache this since we access this a lot, and once set it will not change.
    @synchronized(self) {
        if (self.cachedIsDeregistered == nil) {
            __block BOOL cachedIsDeregistered = NO;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
                cachedIsDeregistered = [self.keyValueStore getBool:TSAccountManager_IsDeregisteredKey
                                                      defaultValue:NO
                                                       transaction:readTransaction];
            }];
            
            self.cachedIsDeregistered = @(cachedIsDeregistered);
        }

        OWSAssertDebug(self.cachedIsDeregistered);
        return self.cachedIsDeregistered.boolValue;
    }
}

- (void)setIsDeregistered:(BOOL)isDeregistered
{
    @synchronized(self) {
        if (self.cachedIsDeregistered && self.cachedIsDeregistered.boolValue == isDeregistered) {
            return;
        }

        OWSLogWarn(@"%@ isDeregistered: %d", self.logTag, isDeregistered);

        self.cachedIsDeregistered = @(isDeregistered);
    }

    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:@(isDeregistered)
                                  key:TSAccountManager_IsDeregisteredKey
                          transaction:writeTransaction];
        [writeTransaction addAsyncCompletionOnMain:^{
            [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameDeregistrationStateDidChange
                                                                     object:nil
                                                                   userInfo:nil];
        }];
    });
}

#pragma mark - Transfer data

- (BOOL)isTransfered {
    // Cache this since we access this a lot, and once set it will not change.
    @synchronized(self) {
        if (self.cachedIsTransfered == nil) {
            __block BOOL cachedIsTransfered = NO;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
                cachedIsTransfered = [self.keyValueStore getBool:TSAccountManager_IsTransferedKey defaultValue:NO transaction:readTransaction];
            }];
            
            self.cachedIsTransfered = @(cachedIsTransfered);
        }

        OWSAssertDebug(self.cachedIsTransfered);
        return self.cachedIsTransfered.boolValue;
    }
}

- (void)setTransferedSucess:(BOOL)transfered {
    @synchronized(self) {

        DDLogWarn(@"%@ isTransfered: %d", self.logTag, transfered);
        self.cachedIsTransfered = @(transfered);
    }
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:@(transfered)
                                  key:TSAccountManager_IsTransferedKey
                          transaction:writeTransaction];
    });

    self.cachedIsTransfered = @(transfered);
}

- (BOOL)isTransferInProgress
{
    @synchronized (self) {
        __block NSNumber *isTransferInProgressNumber = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            isTransferInProgressNumber = [self.keyValueStore getNSNumber:TSAccountManager_IsTransferInProgressKey transaction:readTransaction];
        }];
        return [isTransferInProgressNumber intValue] == 1 ? true : false;
    }
}

- (void)setIsTransferInProgress:(BOOL)transferInProgress
{
    if (transferInProgress == self.isTransferInProgress) {
        return;
    }
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        @synchronized(self) {
            [self.keyValueStore setObject:@(transferInProgress)
                                      key:TSAccountManager_IsTransferInProgressKey
                              transaction:writeTransaction];
        }
        [writeTransaction addAsyncCompletionOnMain:^{
            @synchronized(self) {
                self->_isTransferInProgress = transferInProgress;
            }
        }];
    });


}

#pragma mark - Re-registration

- (BOOL)resetForReregistration
{
    @synchronized(self) {
        NSString *_Nullable localNumber = self.localNumber;
        if (!localNumber) {
            OWSFailDebug(@"%@ can't re-register without valid local number.", self.logTag);
            return NO;
        }

        _isRegistered = NO;
        _cachedLocalNumber = nil;
        _phoneNumberAwaitingVerification = nil;
        _cachedIsDeregistered = nil;
        
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self.keyValueStore removeAllWithTransaction:transaction];
            
            [self.keyValueStore setObject:localNumber
                                      key:TSAccountManager_ReregisteringPhoneNumberKey
                              transaction:transaction];
        });

        return YES;
    }
}

- (nullable NSString *)reregisterationPhoneNumberWithTransaction:(SDSAnyReadTransaction *)transaction {    
    NSString *_Nullable result = [self.keyValueStore getString:TSAccountManager_ReregisteringPhoneNumberKey transaction:transaction];
    
    return result;
}

- (BOOL)isReregistering
{
    __block NSString *_Nullable result = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        result = [self.keyValueStore getString:TSAccountManager_ReregisteringPhoneNumberKey
                                   transaction:transaction];
    }];
    
    return result != nil;
}

- (void)getInternalContactSuccess:(void (^)(NSArray* array))successHandler
                          failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);

    TSRequest *request = [OWSRequestFactory getInternalContactsRequest];
    
    DTBaseAPI *baseAPI = [DTBaseAPI new];
    [baseAPI sendRequest:request
         completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                 success:^(DTAPIMetaEntity * _Nonnull entity) {
        
        NSArray *accountDicts = [entity.data objectForKey:@"contacts"];
        if (!DTParamsUtils.validateArray(accountDicts)) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had no accounts.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }

        NSNumber *directoryVersion = [entity.data objectForKey:@"directoryVersion"];
        NSMutableArray *accountDictsM = accountDicts.mutableCopy;
        NSMutableArray *accountArray = [[NSMutableArray alloc] init];
        
        [Batching loopObjcWithBatchSize:500 loopBlock:^(BOOL * _Nonnull stop) {
            NSDictionary *dict = accountDictsM.lastObject;
            
            if (dict == nil) {
                *stop = YES;
            }
            
            if (!DTParamsUtils.validateDictionary(dict)) {
                OWSLogError(@"Failed retrieval of account. Account are not dict.");
            } else {

                NSMutableDictionary *contactDictM = [[NSMutableDictionary alloc] initWithDictionary:dict];
                contactDictM[@"avatar"] = @{};
                
                if(DTParamsUtils.validateString(dict[@"avatar"])){
                    NSData *avatarJsonData = [dict[@"avatar"] dataUsingEncoding:NSUTF8StringEncoding];
                    NSError *error;
                    if(avatarJsonData){
                        NSDictionary *avatarDict = [NSJSONSerialization JSONObjectWithData:avatarJsonData
                                                                                   options:NSJSONReadingMutableContainers
                                                                                     error:&error];
                        if (!error && DTParamsUtils.validateDictionary(avatarDict)) {
                            
                            contactDictM[@"avatar"] = avatarDict;
                        } else {
                            
                            OWSLogWarn(@"avatar JSONSerialization error:%@", error);
                        }
                    }
                }
                
                NSError *error;
                Contact *contact = [MTLJSONAdapter modelOfClass:[Contact class]
                                             fromJSONDictionary:contactDictM.copy
                                                          error:&error];
                NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:contact.remark receptid:contact.number];
                contact.remark = remark;
                [contact configWithFullName:contact.name phoneNumber:contact.number];
                
                if (!error && contact) {
                    
                    [accountArray addObject:contact];
                } else {
                    
                    OWSLogWarn(@"create contact error:%@", error);
                }
            }
            
            [accountDictsM removeLastObject];
        }];

        successHandler(accountArray.copy);
        if(DTParamsUtils.validateNumber(directoryVersion)){
            [DTContactsUpdateMessageProcessor saveContactsVersion:directoryVersion.integerValue];
        }
    } failure:^(NSError * _Nonnull error) {
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        
        return failureHandler(error);
    }];
    
}

- (void)getContactMessageByReceptid:(NSString *)receptid
                            success:(void (^)(Contact* contact))successHandler
                            failure:(void (^)(NSError *error))failureHandler {
    [self getContactMessageV1ByPhoneNumber:@[receptid] success:^(NSArray * _Nonnull array) {
        if(DTParamsUtils.validateArray(array) && successHandler){
            Contact *contact = array.firstObject;
            successHandler(contact);
        }
    } failure:^(NSError * _Nonnull error) {
        if(failureHandler){
            failureHandler(error);
        }
    }];
}

- (void)getContactMessageV1ByPhoneNumber:(nullable NSArray <NSString *> *)uids
                                 success:(void (^)(NSArray* array))successHandler
                                 failure:(void (^)(NSError *error))failureHandler {
    TSRequest *request = [OWSRequestFactory getV1ContactMessage:uids];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        id responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        
        NSDictionary *responseDic = (NSDictionary *)responseObject;
        if (!responseDic) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSString *status = [NSString stringWithFormat:@"%@",responseDic[@"status"]];
        if (![status isEqualToString:@"0"]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSDictionary *responseContactsData = responseDic[@"data"];
        if (!responseContactsData) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSArray <NSDictionary *>*contacts = responseContactsData[@"contacts"];
        if (![contacts isKindOfClass:[NSArray class]]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had no accounts.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        if (!contacts) {return;}
        NSMutableDictionary *dict = [contacts.firstObject mutableCopy];
        if (![dict isKindOfClass:NSDictionary.class]) {
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        
        NSString *fullName = dict[@"name"];
        if (!fullName) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had no name.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        
        NSString *number = [dict objectForKey:@"number"];
        if (!number) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had no number.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        //局限于Contact中有一些逻辑，所以为防止其他异常出现暂时不做替换，先转成临时模型进行承接
        if (dict[@"avatar"] && [dict[@"avatar"] isKindOfClass:NSString.class]) {
            NSString *avatarJson = dict[@"avatar"];
            NSDictionary *avatarDict = [NSObject signal_dictionaryWithJSON:avatarJson];
            dict[@"avatar"] = avatarDict;
        }
        NSError *error;
        Contact *contact = [MTLJSONAdapter modelOfClass:[Contact class] fromJSONDictionary:dict error:&error];
        NSNumber *friend = dict[@"friend"];
        if (DTParamsUtils.validateNumber(friend)) {
            contact.external = !friend.boolValue;
        }
        if (error) {
            OWSLogError(@"%@ parse contact %@ error: %@", self.logTag, dict[@"number"], error.localizedFailureReason);
            return;
        }
        [contact configWithFullName:fullName phoneNumber:number];
        NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:contact.remark receptid:contact.number];
        contact.remark = remark;
        successHandler(@[contact]);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        failureHandler(error);
    }];
}

- (void)getChatFolderSuccess:(void (^)(NSArray <DTChatFolderEntity *> * chatFolders))successHandler
                     failure:(void (^)(NSError *error))failureHandler
{
    OWSLogInfo(@"[DTChatFolderManager] sync with server");
    TSRequest *request = [OWSRequestFactory getV1ContactMessage:@[[TSAccountManager localNumber]]];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        
        NSDictionary *responseDic = (NSDictionary *)responseObject;
        if (!responseDic) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSString *status = [NSString stringWithFormat:@"%@",responseDic[@"status"]];
        if (![status isEqualToString:@"0"]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSDictionary *responseContactsData = responseDic[@"data"];
        if (!responseContactsData) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        NSArray *contacts = responseContactsData[@"contacts"];
        if (![contacts isKindOfClass:[NSArray class]]) {
            OWSLogError(@"%@ Failed retrieval of accounts. Response had no accounts.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        if (!contacts) {return;}
        NSDictionary *dict = contacts.firstObject;
        if (![dict isKindOfClass:NSDictionary.class]) {
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        //局限于Contact中有一些逻辑，所以为防止其他异常出现暂时不做替换，先转成临时模型进行承接
        Contact *tmpContact = [Contact signal_modelWithDictionary:dict];
        if (DTParamsUtils.validateDictionary(tmpContact.privateConfigs.chatFolder)) {
            NSDictionary *folderData = tmpContact.privateConfigs.chatFolder;
            NSArray <NSDictionary *> *value = folderData[@"value"];
            NSMutableArray <NSDictionary *> *tmpValue = @[].mutableCopy;
            [value enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *conditionsKey = @"conditions";
                NSMutableDictionary *tmpFolder = [obj mutableCopy];
                id conditions = obj[conditionsKey];
                if (conditions != nil && ![conditions isKindOfClass:[NSDictionary class]]) {
                    [tmpFolder removeObjectForKey:conditionsKey];
                }
                [tmpFolder removeObjectForKey:@"grdbId"];
                [tmpValue addObject:tmpFolder];
            }];
            NSError *error;
            NSArray <DTChatFolderEntity *> *chatFolders = [MTLJSONAdapter modelsOfClass:[DTChatFolderEntity class] fromJSONArray:tmpValue.copy error:&error];
            
            NSInteger newVersion = 0;
            NSNumber *newVersionNumber = folderData[@"version"];
            if (DTParamsUtils.validateNumber(newVersionNumber)) {
                newVersion = newVersionNumber.integerValue;
            }
            if (error) {
                OWSLogError(@"%@\n%@", error.localizedDescription, folderData);
                failureHandler(error);
            } else {
                [DTChatFolderManager updateChatFolders:chatFolders forceUpdate:YES newVersion:newVersion success:^{
                    successHandler(chatFolders);
                }];
            }
        } else {
            successHandler(@[]);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        
        failureHandler(error);
    }];
}

- (void)getInviteCodeSuccess:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);

    TSRequest *request = [OWSRequestFactory getInviteCodeRequest: [NSString string]];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ Failed retrieval of invite code. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        successHandler(responseObject);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        return failureHandler(error);
    }];
}

- (void)exchangeAccountWithInviteCode:(NSString *)inviteCode
                              success:(void (^)(DTAPIMetaEntity *metaEntity))successHandler
                              failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(inviteCode);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);

    TSRequest *request = [OWSRequestFactory exchangeAccountRequest:inviteCode];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ Failed exchange account. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        
        NSError *error;
        DTAPIMetaEntity *metaEntity = [MTLJSONAdapter modelOfClass:DTAPIMetaEntity.class fromJSONDictionary:responseObject error:&error];
        if(metaEntity.status != 0){
            NSError *failError = [NSError errorWithDomain:@"exchangeAccountRequestError" code:metaEntity.status userInfo:@{NSLocalizedDescriptionKey: metaEntity.reason}];
            if(failureHandler){
                failureHandler(failError);
            }
        } else {
            successHandler(metaEntity);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSLogError(@"%@",[OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        return failureHandler(error);
    }];
}

- (void)storeLocalNumber:(NSString *)localNumber transaction:(SDSAnyWriteTransaction *)transaction
{
    @synchronized (self) {
        [self.keyValueStore setString:localNumber key:TSAccountManager_RegisteredNumberKey transaction:transaction];
        
        [self.keyValueStore removeValueForKey:TSAccountManager_ReregisteringPhoneNumberKey transaction:transaction];

        self.phoneNumberAwaitingVerification = nil;

        self.cachedLocalNumber = localNumber;
    }
}

- (void)storeServerAuthToken:(NSString *)authToken signalingKey:(NSString *)signalingKey transaction:(SDSAnyWriteTransaction *)transaction
{
    [self.keyValueStore setObject:authToken key:TSAccountManager_ServerAuthToken transaction:transaction];
    [self.keyValueStore setObject:signalingKey key:TSAccountManager_ServerSignalingKey transaction:transaction];
}

- (void)setRegistrationId:(uint32_t)registrationID transaction:(SDSAnyWriteTransaction *)transaction{
    
    [self.keyValueStore setObject:[NSNumber numberWithUnsignedInteger:registrationID]
                              key:TSAccountManager_LocalRegistrationIdKey
                      transaction:transaction];
}

-(DTPasskeyManager *)passKeyManager {
    if(!_passKeyManager){
        _passKeyManager =  [DTPasskeyManager new];
    }
    return _passKeyManager;
}

- (uint32_t)randomANewRegistrationId:(SDSAnyReadTransaction *)transaction {
    uint32_t registrationID = [[self.keyValueStore getObjectForKey:TSAccountManager_LocalRegistrationIdKey transaction:transaction] unsignedIntValue];
    uint32_t newID = 0;
    do {
        newID = [self randomRegistrationId];
    } while (registrationID == newID);
    
    return newID;
}

- (uint32_t)randomRegistrationId {
    uint32_t registrationID = (uint32_t)arc4random_uniform(16380) + 1;
    DDLogWarn(@"%@ Generated a new registrationID: %u", self.logTag, registrationID);
    return registrationID;
}

- (void)storeRegistrationId:(uint32_t)registrationId transaction:(SDSAnyWriteTransaction *)transaction {
    
    [self.keyValueStore setObject:[NSNumber numberWithUnsignedInteger:registrationId]
                              key:TSAccountManager_LocalRegistrationIdKey
                      transaction:transaction];
    
}

- (void)storeInviteCode:(NSString *)inviteCode transaction:(SDSAnyWriteTransaction *)transaction
{
    @synchronized (self) {
        [self.keyValueStore setObject:inviteCode
                                  key:TSAccountManager_InviteCodeKey
                          transaction:transaction];
    }
}

- (nullable NSString *)storedInviteCodeWithTransaction:(SDSAnyReadTransaction *)transaction
{
    @synchronized (self) {
        NSString *storedLocalNumber = [self.keyValueStore getString:TSAccountManager_InviteCodeKey transaction:transaction];
        return storedLocalNumber;
    }
}

- (void)storeInviteLink:(NSString *)inviteLink transaction:(SDSAnyWriteTransaction *)transaction
{
    @synchronized (self) {
        [self.keyValueStore setObject:inviteLink
                                  key:TSAccountManager_InviteLinkKey
                          transaction:transaction];
    }
}

- (nullable NSString *)storedInviteLinkWithTransaction:(SDSAnyReadTransaction *)transaction
{
    @synchronized (self) {
        NSString *storedLocalNumber = [self.keyValueStore getString:TSAccountManager_InviteLinkKey transaction:transaction];
        return storedLocalNumber;
    }
}

- (void)storeChallengeCode:(NSString *)challengeCode transaction:(SDSAnyWriteTransaction *)transaction {
    if(!DTParamsUtils.validateString(challengeCode)){
        OWSLogInfo(@"challengeCode = nil");
        return;
    }
    NSMutableArray *challengeCodeCacheArr = [[self challengeCodeCache] mutableCopy];
    if(!DTParamsUtils.validateArray(challengeCodeCacheArr)){
        challengeCodeCacheArr = [NSMutableArray array];
    }
    [challengeCodeCacheArr addObject:challengeCode];
    if(challengeCodeCacheArr.count > 100){
        [challengeCodeCacheArr removeObjectAtIndex:0];
    }
    [self.keyValueStore setObject:challengeCodeCacheArr.copy
                              key:TSAccountManager_ChallengeCodeKey
                      transaction:transaction];
    self->_challengeCodeArr = challengeCodeCacheArr;
}

- (NSMutableArray *)challengeCodeCache {
    if(DTParamsUtils.validateArray(_challengeCodeArr)){
        return _challengeCodeArr;
    }
    
    if(!_challengeCodeArr){
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            self->_challengeCodeArr = [self.keyValueStore getObjectForKey:TSAccountManager_ChallengeCodeKey transaction:transaction];
        }];
    }
    return _challengeCodeArr;
}

- (void)requestLongPeroidInviteCode:(NSNumber *)regenerate
                        shortNumber:(NSNumber *)shortNumber
                            success:(void (^)(DTAPIMetaEntity *metaEntity))successHandler
                     failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    TSRequest *request = [OWSRequestFactory getLongPeroidInviteCodeRequestWithRegenerate:regenerate shortNumber:shortNumber];
    [[DTTokenHelper sharedInstance] asyncFetchGlobalAuthTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if(error){
            OWSLogInfo(@"requestLongPeroidInviteCodeSuccess asyncGetAuthTokenForApp fail");
            if(!failureHandler){return;}
            failureHandler(DTErrorWithCodeDescription(DTAPIRequestResponseStatusHttpError, kDTAPIRequestHttpErrorDescription));
        }
        request.authToken = token;
        [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            if (![responseObject isKindOfClass:[NSDictionary class]]) {
                DDLogError(@"%@ Failed retrieval of invite code. Response had unexpected format.", self.logTag);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            NSError *error;
            DTAPIMetaEntity *metaEntity = [MTLJSONAdapter modelOfClass:DTAPIMetaEntity.class fromJSONDictionary:responseObject error:&error];
            if(metaEntity.status != 0){
                NSError *failError = [NSError errorWithDomain:@"getLongPeroidInviteCodeRequestError" code:metaEntity.status userInfo:@{NSLocalizedDescriptionKey: metaEntity.reason}];
                if(failureHandler){
                    failureHandler(failError);
                }
            } else {
                successHandler(metaEntity);
            }
        } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
            NSError *error = errorWrapper.asNSError;
            if (!error.isNetworkConnectivityFailure) {
                OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
            }
            return failureHandler(error);
        }];
    }];
}

///发起会议的时候进行内存缓存
- (void)storeGroupMeetingMkstring:(NSString *) meetingKey thread:(TSThread *) gThread {
    if(![gThread isKindOfClass:TSGroupThread.class]){return;}
    
    NSMutableDictionary * cachedMeetingKeys = [self.cachedMeetingKeys mutableCopy];
    NSString *meetingChannlName = [DTCallManager generateGroupChannelNameBy:gThread];
    if(!DTParamsUtils.validateString(meetingChannlName)){return;}
    NSString *cachedMeetingKeyValue = [self.cachedMeetingKeys objectForKey:meetingChannlName];
    
    if([cachedMeetingKeyValue isEqualToString:meetingKey]){return;}
    [cachedMeetingKeys setObject:meetingKey forKey:meetingChannlName];
    
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.keyValueStore setObject:meetingKey key:meetingChannlName transaction:writeTransaction];
    });
    self.cachedMeetingKeys = [cachedMeetingKeys copy];
    // Cache this since we access this a lot, and once set it will not change.
}

///renew 群会议的时候获取缓存的meetingKey
- (NSString *)groupMeetingMkstringFromThread:(TSThread *) gThread {
    if(![gThread isKindOfClass:TSGroupThread.class]){return nil;}
    NSString *meetingChannelName = [DTCallManager generateGroupChannelNameBy:gThread];
    if (!DTParamsUtils.validateString(meetingChannelName) ) {return nil;}
    __block NSString *meetingKey = [self.cachedMeetingKeys objectForKey:meetingChannelName];
    if(DTParamsUtils.validateString(meetingKey)){return meetingKey;}
    // Cache this since we access this a lot, and once set it will not change.
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        meetingKey = [self.keyValueStore getObjectForKey:meetingChannelName transaction:readTransaction];
    }];
    
    NSMutableDictionary * cachedMeetingKeys = [self.cachedMeetingKeys mutableCopy];
    if(DTParamsUtils.validateString(meetingKey)){
        [cachedMeetingKeys setObject:meetingKey forKey:meetingChannelName];
    }
    self.cachedMeetingKeys = cachedMeetingKeys.copy;
    return meetingKey;
}

@end

NS_ASSUME_NONNULL_END
