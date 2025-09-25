//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSProfileManager.h"
#import "Environment.h"
#import "NSString+OWS.h"
#import "OWSUserProfile.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/SSKCryptography.h>
#import <TTServiceKit/MIMETypeUtil.h>
#import <TTServiceKit/NSData+Image.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/NSNotificationCenter+OWS.h>
#import <TTServiceKit/OWSFileSystem.h>
#import <TTServiceKit/OWSMessageSender.h>
//
#import <TTServiceKit/OWSProfileKeyMessage.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/BaseModel.h>
#import <TTServiceKit/TextSecureKitEnv.h>
#import <TTServiceKit/UIImage+OWS.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <SignalCoreKit/Threading.h>
#import <AFNetworking/AFURLSessionManager.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kNSNotificationName_ProfileWhitelistDidChange = @"kNSNotificationName_ProfileWhitelistDidChange";

NSString *const kOWSProfileManager_UserWhitelistCollection = @"kOWSProfileManager_UserWhitelistCollection";
NSString *const kOWSProfileManager_GroupWhitelistCollection = @"kOWSProfileManager_GroupWhitelistCollection";

// The max bytes for a user's profile name, encoded in UTF8.
// Before encrypting and submitting we NULL pad the name data to this length.
const NSUInteger kOWSProfileManager_NameDataLength = 26;
const int kOWSProfileManager_MaxNameLengthBytes = 128;
const NSUInteger kOWSProfileManager_MaxAvatarDiameter = 640;

@interface OWSProfileManager ()

// This property can be accessed on any thread, while synchronized on self.
@property (atomic, readonly) OWSUserProfile *localUserProfile;

// This property can be accessed on any thread, while synchronized on self.
@property (atomic, readonly) NSCache<NSString *, UIImage *> *profileAvatarImageCache;

// This property can be accessed on any thread, while synchronized on self.
@property (atomic, readonly) NSMutableSet<NSString *> *currentAvatarDownloads;
@property(nonatomic,copy,readwrite) NSString * _Nullable avatarString;
@end

#pragma mark -

// Access to most state should happen while synchronized on the profile manager.
// Writes should happen off the main thread, wherever possible.
@implementation OWSProfileManager

@synthesize localUserProfile = _localUserProfile;

+ (instancetype)sharedManager
{
    static OWSProfileManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- ( NSDictionary *  )localAvatar {
    if (self.avatarString && self.avatarString.length >0) {
        NSDictionary *avatar = [NSDictionary signal_dictionaryWithJSON:self.avatarString];
        return avatar;
    }
    return nil;
}

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSAssertIsOnMainThread();

    _profileAvatarImageCache = [NSCache new];
    _currentAvatarDownloads = [NSMutableSet new];
    
    _whitelistedPhoneNumbersStore =
        [[SDSKeyValueStore alloc] initWithCollection:kOWSProfileManager_UserWhitelistCollection];
    _whitelistedGroupsStore =
        [[SDSKeyValueStore alloc] initWithCollection:kOWSProfileManager_GroupWhitelistCollection];

    OWSSingletonAssert();

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (OWSIdentityManager *)identityManager
{
    return [OWSIdentityManager sharedManager];
}

#pragma mark - User Profile Accessor

- (void)ensureLocalProfileCached
{
    // Since localUserProfile can create a transaction, we want to make sure it's not called for the first
    // time unexpectedly (e.g. in a nested transaction.)
    __unused OWSUserProfile *profile = [self localUserProfile];
}

#pragma mark - Local Profile

- (OWSUserProfile *)localUserProfile
{
    @synchronized(self)
    {
        if (!_localUserProfile) {
            __block OWSUserProfile *localUserProfile = nil;
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                localUserProfile = [OWSUserProfile getOrBuildUserProfileForRecipientId:kLocalProfileUniqueId transaction:transaction];
            });
            
            _localUserProfile = localUserProfile;
        }
    }

    OWSAssertDebug(_localUserProfile.profileKey);

    return _localUserProfile;
}

- (BOOL)localProfileExists
{
    __block BOOL result = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        result = [self getUserProfileWithRecipientId:kLocalProfileUniqueId transaction:transaction];
    }];
    
    return result;
}

- (SSKAES256Key *)localProfileKey
{
    OWSAssertDebug(self.localUserProfile.profileKey.keyData.length == kAES256_KeyByteLength);

    return self.localUserProfile.profileKey;
}

- (BOOL)hasLocalProfileWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return ([self localProfileNameWithTransaction:transaction].length > 0 || self.localProfileAvatarImage != nil);
}

- (nullable NSString *)localProfileNameWithTransaction:(SDSAnyReadTransaction *)transaction
{
    NSString *profileName = self.localUserProfile.profileName;
    if (profileName && profileName.length > 0) {
        return profileName;
    }else {
        OWSContactsManager *contactManager = Environment.shared.contactsManager;
        NSString *recipientId = [TSAccountManager sharedInstance].localNumber;
        SignalAccount *account = [contactManager signalAccountForRecipientId:recipientId transaction:transaction];
        return account.contact.fullName;
    }
}

- (nullable UIImage *)localProfileAvatarImage
{
    return [self loadProfileAvatarWithFilename:self.localUserProfile.avatarFileName];
}

//用户名称， 头像
- (void)updateLocalProfileName:(nullable NSString *)profileName
                   avatarImage:(nullable UIImage *)avatarImage
                       success:(void (^)(void))successBlockParameter
                       failure:(void (^)(void))failureBlockParameter
{
    OWSAssertDebug(successBlockParameter);
    OWSAssertDebug(failureBlockParameter);

    // Ensure that the success and failure blocks are called on the main thread.
    void (^failureBlock)(void) = ^{
        DDLogError(@"%@ Updating service with profile failed.", self.logTag);

        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlockParameter();
        });
    };
    void (^successBlock)(void) = ^{
        OWSLogInfo(@"%@ Successfully updated service with profile.", self.logTag);
        dispatch_async(dispatch_get_main_queue(), ^{
            successBlockParameter();
        });
    };

    // The final steps are to:
    //
    // * Try to update the service.
    // * Update client state on success.
    void (^tryToUpdateService)(NSString *_Nullable, NSString *_Nullable) = ^(
        NSString *_Nullable avatarUrlPath, NSString *_Nullable avatarFileName) {
            OWSUserProfile *userProfile = self.localUserProfile;
            OWSAssertDebug(userProfile);
            NSURL *url = [NSURL URLWithString:avatarUrlPath];
            NSString* avatarId = url.path.lastPathComponent;
            OWSLogDebug(@"tryToUpdateService profileName:%@ avatarId:%@ avatarFileName:%@",
                      profileName, avatarId, avatarFileName);
            
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [userProfile updateWithProfileName:profileName
                                     avatarUrlPath:avatarId
                                    avatarFileName:avatarFileName
                                       transaction:transaction
                                        completion:^{
                    if (avatarFileName) {
                        [self updateProfileAvatarCache:avatarImage filename:avatarFileName];
                    }
                    successBlock();
                }];
            });
    };

    OWSUserProfile *userProfile = self.localUserProfile;
    OWSAssertDebug(userProfile);

    if (avatarImage) {
        if (profileName.length == 0) {
            profileName = nil;
        }
        // modified: new avatar image
        // write it to disk, encrypt it, upload it to oss server
        // send the avatar info including oss storage url to server.
        if (self.localProfileAvatarImage != avatarImage) {
            DDLogVerbose(@"%@ Updating local profile on service with new avatar.", self.logTag);
            [self writeAvatarToDisk:avatarImage
                success:^(NSData *data, NSString *fileName) {
                [self uploadAvatarToService:fileName avatarData:data profileName:profileName?:userProfile.profileName
                                    success:^(NSString *_Nullable avatarUrlPath) {
                    tryToUpdateService(avatarUrlPath, fileName);
                }
                                    failure:^{
                    failureBlock();
                    
                }];
                
            }failure:^{
                    failureBlock();
                }];
        } else {
            // If the avatar hasn't changed, reuse the existing metadata.
            
            OWSAssertDebug(userProfile.avatarUrlPath.length > 0);
            OWSAssertDebug(userProfile.avatarFileName.length > 0);
            
            DDLogVerbose(@"%@ Updating local profile on service with unchanged avatar.", self.logTag);
            tryToUpdateService(userProfile.avatarUrlPath, userProfile.avatarFileName);
        }
    }
// modified: misunderstanding this one ?????
//        else if (userProfile.avatarUrlPath) {
//        DDLogVerbose(@"%@ Updating local profile on service with cleared avatar.", self.logTag);
//        [self uploadAvatarToService:nil
//            avatarData:nil
//            success:^(NSString *_Nullable avatarUrlPath) {
//                tryToUpdateService(nil, nil);
//            }
//            failure:^{
//                failureBlock();
//            }];
//    }
    else {
        DDLogVerbose(@"%@ Updating local profile on service with no avatar.", self.logTag);
        self.avatarString = nil;
        NSMutableDictionary *parms = [NSMutableDictionary dictionary];
        if (profileName.length >0) {
            parms[@"name"] = profileName;
        }
        TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
        
        [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (DTParamsUtils.validateDictionary(responseObject)) {
                NSNumber *status = (NSNumber *)responseObject[@"status"];
                if (DTParamsUtils.validateNumber(status) && [status intValue] == 0 ) {
                    tryToUpdateService(nil, nil);
                }else {
                    failureBlock();
                }
            } else {
                failureBlock();
            }
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            failureBlock();
        }];
    }
}

- (void)writeAvatarToDisk:(UIImage *)avatar
                  success:(void (^)(NSData *data, NSString *fileName))successBlock
                  failure:(void (^)(void))failureBlock
{
    OWSAssertDebug(avatar);
    OWSAssertDebug(successBlock);
    OWSAssertDebug(failureBlock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (avatar) {
            NSData *data = [self processedImageDataForRawAvatar:avatar];
            OWSAssertDebug(data);
            if (data) {
                NSString *fileName = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"jpg"];
                NSString *filePath = [self.profileAvatarsDirPath stringByAppendingPathComponent:fileName];
                BOOL success = [data writeToFile:filePath atomically:YES];
                OWSAssertDebug(success);
                if (success) {
                    successBlock(data, fileName);
                    return;
                }
            }
        }
        failureBlock();
    });
}

- (NSData *)processedImageDataForRawAvatar:(UIImage *)image
{
    NSUInteger kMaxAvatarBytes = 5 * 1000 * 1000;

    if (image.size.width != kOWSProfileManager_MaxAvatarDiameter
        || image.size.height != kOWSProfileManager_MaxAvatarDiameter) {
        // To help ensure the user is being shown the same cropping of their avatar as
        // everyone else will see, we want to be sure that the image was resized before this point.
        OWSFailDebug(@"Avatar image should have been resized before trying to upload");
        image = [image resizedImageToFillPixelSize:CGSizeMake(kOWSProfileManager_MaxAvatarDiameter,
                                                       kOWSProfileManager_MaxAvatarDiameter)];
    }

    NSData *_Nullable data = UIImageJPEGRepresentation(image, 0.95f);
    if (data.length > kMaxAvatarBytes) {
        // Our avatar dimensions are so small that it's incredibly unlikely we wouldn't be able to fit our profile
        // photo. e.g. generating pure noise at our resolution compresses to ~200k.
        OWSFailDebug(@"Suprised to find profile avatar was too large. Was it scaled properly? image: %@", image);
    }

    return data;
}

// modified: upload the avatar image to oss server as a attachment
//      what is different is avatar in oss using differet bucket name.
- (void)uploadAvatarToService:(NSString *_Nullable)avatarFileName//文件名字
                             avatarData:(NSData *_Nullable)avatarData
                  profileName:(NSString *)profileName//名字
                      success:(void (^)(NSString *_Nullable avatarUrlPath))successBlock
                      failure:(void (^)(void))failureBlock
{
    OWSAssertDebug(successBlock);
    OWSAssertDebug(failureBlock);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // 1 encrypt avatar data
        NSData *encryptedAvatarData = [self encryptProfileData:avatarData];
        
        // 2 request upload url from server, and then upload it.
        TSAttachmentStream *attachmentStream =
        [[TSAttachmentStream alloc] initWithContentType:OWSMimeTypeImageJpeg
                                              byteCount:(UInt32)encryptedAvatarData.length
                                         sourceFilename:avatarFileName
                                         albumMessageId:nil
                                                albumId:nil];
        
        id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:encryptedAvatarData fileExtension:@"jpg"];

        if (![attachmentStream writeDataSource:dataSource]) {
            OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
            failureBlock();
        }
        
        //[attachmentStream save];
        
        OWSUploadOperation *uploadAttachmentOperation =
            [[OWSUploadOperation alloc] initWithAttachment:attachmentStream];
        [uploadAttachmentOperation syncrunWithProfileName:profileName profileKey:[OWSProfileManager sharedManager].localProfileKey];
        if (uploadAttachmentOperation.isPutProfileSucess) {
            self.avatarString = uploadAttachmentOperation.avatarString;
            successBlock(uploadAttachmentOperation.location);
        }else {
            self.avatarString = @"";
            failureBlock();
        }
    });

    return;
}

- (void)fetchLocalUsersProfile
{
    OWSAssertIsOnMainThread();

    NSString *_Nullable localNumber = [TSAccountManager sharedInstance].localNumber;
    if (!localNumber) {
        return;
    }
    [ProfileFetcherJob runWithRecipientId:localNumber ignoreThrottling:YES];
}

#pragma mark - Profile Whitelist

- (void)clearProfileWhitelist
{
    OWSLogWarn(@"Clearing the profile whitelist.");

    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.whitelistedPhoneNumbersStore removeAllWithTransaction:transaction];
        [self.whitelistedGroupsStore removeAllWithTransaction:transaction];

        OWSAssertDebug(0 == [self.whitelistedPhoneNumbersStore numberOfKeysWithTransaction:transaction]);
        OWSAssertDebug(0 == [self.whitelistedGroupsStore numberOfKeysWithTransaction:transaction]);
    });
}

- (void)logProfileWhitelist
{
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        OWSLogError(@"%@: %lu",
            self.whitelistedPhoneNumbersStore.collection,
            (unsigned long)[self.whitelistedPhoneNumbersStore numberOfKeysWithTransaction:transaction]);
        for (NSString *key in [self.whitelistedPhoneNumbersStore allKeysWithTransaction:transaction]) {
            OWSLogError(@"\t profile whitelist user phone number: %@", key);
        }
        OWSLogError(@"%@: %lu",
            self.whitelistedGroupsStore.collection,
            (unsigned long)[self.whitelistedGroupsStore numberOfKeysWithTransaction:transaction]);
        for (NSString *key in [self.whitelistedGroupsStore allKeysWithTransaction:transaction]) {
            OWSLogError(@"\t profile whitelist group: %@", key);
        }
    }];
}

- (void)regenerateLocalProfile
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        OWSUserProfile *userProfile = self.localUserProfile;
        [userProfile clearWithProfileKey:[SSKAES256Key generateRandomKey]
                            transaction:transaction
                              completion:nil];
    });
}

- (void)addUserToProfileWhitelist:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);
    if (recipientId && recipientId.length) {
        [self addUsersToProfileWhitelist:@[ recipientId ] transaction:transaction];
    } else {
        OWSFailDebug(@"no recipientId");
    }
}

- (void)addUsersToProfileWhitelist:(NSArray<NSString *> *)recipientIds
{
    OWSAssertDebug(recipientIds);

    NSMutableSet<NSString *> *newRecipientIds = [NSMutableSet new];
    DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *transaction) {
        for (NSString *recipientId in recipientIds) {
            NSNumber *_Nullable oldValue = [self.whitelistedPhoneNumbersStore getObjectForKey:recipientId transaction:transaction];
            if (oldValue && oldValue.boolValue) {
                continue;
            }
            [self.whitelistedPhoneNumbersStore setObject:@(YES) key:recipientId transaction:transaction];
            [newRecipientIds addObject:recipientId];
        }
        [transaction addAsyncCompletionOnMain:^{
            for (NSString *recipientId in newRecipientIds) {
                [[NSNotificationCenter defaultCenter]
                 postNotificationNameAsync:kNSNotificationName_ProfileWhitelistDidChange
                 object:nil
                 userInfo:@{
                    kNSNotificationKey_ProfileRecipientId : recipientId,
                }];
            }
        }];
    }));
}

- (void)addUsersToProfileWhitelist:(NSArray<NSString *> *)recipientIds transaction:(SDSAnyWriteTransaction *)transaction {
    OWSAssertDebug(recipientIds);
    OWSAssertDebug(transaction);

    NSMutableSet<NSString *> *newRecipientIds = [NSMutableSet new];
    for (NSString *recipientId in recipientIds) {
        NSNumber *_Nullable oldValue = [self.whitelistedPhoneNumbersStore getObjectForKey:recipientId transaction:transaction];
        if (oldValue && oldValue.boolValue) {
            continue;
        }
        [self.whitelistedPhoneNumbersStore setObject:@(YES) key:recipientId transaction:transaction];
        [newRecipientIds addObject:recipientId];
    }
    
    for (NSString *recipientId in newRecipientIds) {
        [[NSNotificationCenter defaultCenter]
            postNotificationNameAsync:kNSNotificationName_ProfileWhitelistDidChange
                               object:nil
                             userInfo:@{
                                 kNSNotificationKey_ProfileRecipientId : recipientId,
                             }];
    }
}

// TODO: ydb replace with transaction
- (BOOL)isUserInProfileWhitelist:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    __block BOOL result = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
        result = [self isUserInProfileWhitelist:recipientId transaction:transaction];
    }];
    return result;
}

- (BOOL)isUserInProfileWhitelist:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)readTransaction {
    OWSAssertDebug(recipientId.length > 0);
    
    BOOL result = NO;
    NSNumber *_Nullable oldValue = [self.whitelistedPhoneNumbersStore getObjectForKey:recipientId transaction:readTransaction];
    result = (oldValue && oldValue.boolValue);

    return result;
}


- (void)addGroupIdToProfileWhitelist:(NSData *)groupId
{
    OWSAssertDebug(groupId.length > 0);

    NSString *groupIdKey = [groupId hexadecimalString];

    __block BOOL didChange = NO;
    DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *transaction) {
        NSNumber *_Nullable oldValue = [self.whitelistedGroupsStore getObjectForKey:groupIdKey transaction:transaction];
        if (oldValue && oldValue.boolValue) {
            // Do nothing.
        } else {
            [self.whitelistedGroupsStore setObject:@(YES) key:groupIdKey transaction:transaction];
            didChange = YES;
        }
        [transaction addAsyncCompletionOnMain:^{
            if (didChange) {
                [[NSNotificationCenter defaultCenter]
                 postNotificationNameAsync:kNSNotificationName_ProfileWhitelistDidChange
                 object:nil
                 userInfo:@{
                    kNSNotificationKey_ProfileGroupId : groupId,
                }];
            }
        }];
    }));
}

- (void)addGroupIdToProfileWhitelist:(NSData *)groupId transaction:(SDSAnyWriteTransaction *)transaction {
    OWSAssertDebug(groupId.length > 0);
    OWSAssertDebug(transaction);

    NSString *groupIdKey = [groupId hexadecimalString];

    BOOL didChange = NO;
    
    NSNumber *_Nullable oldValue = [self.whitelistedGroupsStore getObjectForKey:groupIdKey transaction:transaction];
    if (oldValue && oldValue.boolValue) {
        // Do nothing.
    } else {
        [self.whitelistedGroupsStore setObject:@(YES) key:groupIdKey transaction:transaction];
        didChange = YES;
    }
    
    if (didChange) {
        [[NSNotificationCenter defaultCenter]
            postNotificationNameAsync:kNSNotificationName_ProfileWhitelistDidChange
                               object:nil
                             userInfo:@{
                                 kNSNotificationKey_ProfileGroupId : groupId,
                             }];
    }
}

- (void)addThreadToProfileWhitelist:(TSThread *)thread {
    OWSAssertDebug(thread);

    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        NSData *groupId = groupThread.groupModel.groupId;
        [self addGroupIdToProfileWhitelist:groupId];

        // When we add a group to the profile whitelist, we might as well
        // also add all current members to the profile whitelist
        // individually as well just in case delivery of the profile key
        // fails.
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self addUsersToProfileWhitelist:groupThread.recipientIdentifiers transaction:transaction];
        });
    } else {
        NSString *recipientId = thread.contactIdentifier;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self addUserToProfileWhitelist:recipientId  transaction:transaction];
        });
    }
}

- (void)addThreadToProfileWhitelist:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction {
    OWSAssertDebug(thread);

    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        NSData *groupId = groupThread.groupModel.groupId;
        [self addGroupIdToProfileWhitelist:groupId transaction:transaction];

        // When we add a group to the profile whitelist, we might as well
        // also add all current members to the profile whitelist
        // individually as well just in case delivery of the profile key
        // fails.
        [self addUsersToProfileWhitelist:groupThread.recipientIdentifiers transaction:transaction];
    } else {
        NSString *recipientId = thread.contactIdentifier;
        [self addUserToProfileWhitelist:recipientId transaction:transaction];
    }
}

// TODO: ydb replace with transaction
- (BOOL)isGroupIdInProfileWhitelist:(NSData *)groupId
{
    OWSAssertDebug(groupId.length > 0);

    NSString *groupIdKey = [groupId hexadecimalString];

    __block BOOL result = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        NSNumber *_Nullable oldValue = [self.whitelistedGroupsStore getObjectForKey:groupIdKey transaction:transaction];;
        result = (oldValue && oldValue.boolValue);
    }];
    return result;
}

- (BOOL)isGroupIdInProfileWhitelist:(NSData *)groupId transaction:(SDSAnyReadTransaction *)readTransaction
{
    OWSAssertDebug(groupId.length > 0);
    
    NSString *groupIdKey = [groupId hexadecimalString];
    
    BOOL result = NO;
    NSNumber *_Nullable oldValue = [self.whitelistedGroupsStore getObjectForKey:groupIdKey transaction:readTransaction];
    result = (oldValue && oldValue.boolValue);
    
    return result;
}

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread
{
    OWSAssertDebug(thread);

    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        NSData *groupId = groupThread.groupModel.groupId;
        return [self isGroupIdInProfileWhitelist:groupId];
    } else {
        NSString *recipientId = thread.contactIdentifier;
        return [self isUserInProfileWhitelist:recipientId];
    }
}

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread transaction:(SDSAnyReadTransaction *)readTransaction {
    OWSAssertDebug(thread);
    
    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        NSData *groupId = groupThread.groupModel.groupId;
        return [self isGroupIdInProfileWhitelist:groupId transaction:readTransaction];
    } else {
        NSString *recipientId = thread.contactIdentifier;
        return [self isUserInProfileWhitelist:recipientId transaction:readTransaction];
    }
}

- (void)setContactRecipientIds:(NSArray<NSString *> *)contactRecipientIds
{
    OWSAssertDebug(contactRecipientIds);

    [self addUsersToProfileWhitelist:contactRecipientIds];
}

#pragma mark - Other User's Profiles

- (void)logUserProfiles
{
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction *transaction) {
        OWSLogError(@"logUserProfiles: %zd", [OWSUserProfile anyCountWithTransaction:transaction]);
        [OWSUserProfile anyEnumerateWithTransaction:transaction
                                            batched:YES
                                              block:^(OWSUserProfile * object, BOOL * stop) {
            OWSAssertDebug([object isKindOfClass:[OWSUserProfile class]]);
            OWSUserProfile *userProfile = object;
            OWSLogError(@"\t [%@]: has profile key: %d, has avatar URL: %d, has "
                       @"avatar file: %d, name: %@",
                userProfile.recipientId,
                userProfile.profileKey != nil,
                userProfile.avatarUrlPath != nil,
                userProfile.avatarFileName != nil,
                userProfile.profileName);
        }];
    }];
}

- (void)setProfileKeyData:(NSData *)profileKeyData
           forRecipientId:(NSString *)recipientId
              transaction:(SDSAnyWriteTransaction *)transaction
{
        SSKAES256Key *_Nullable profileKey = [SSKAES256Key keyWithData:profileKeyData];
        if (profileKey == nil) {
            OWSFailDebug(@"Failed to make profile key for key data");
            return;
        }

//        [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
            OWSUserProfile *userProfile = [OWSUserProfile getOrBuildUserProfileForRecipientId:recipientId transaction:transaction];
            
            OWSAssertDebug(userProfile);
            if (userProfile.profileKey && [userProfile.profileKey.keyData isEqual:profileKey.keyData]) {
                // Ignore redundant update.
                return;
            }
            
            [userProfile clearWithProfileKey:profileKey
                                 transaction:transaction
                                  completion:^{
                DispatchMainThreadSafe(^{
                    [ProfileFetcherJob runWithRecipientId:recipientId
                                         ignoreThrottling:YES];
                });
            }];
}

- (nullable NSData *)profileKeyDataForRecipientId:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction {
    if ([transaction isKindOfClass:SDSAnyWriteTransaction.class]) {
        
        return [self profileKeyForRecipientId:recipientId transaction:transaction].keyData;
    } else {
        
        return [self profileKeyForRecipientId:recipientId].keyData;
    }
}

- (nullable SSKAES256Key *)profileKeyForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    OWSUserProfile *userProfile = [self getUserProfileWithRecipientId:recipientId];
    
    OWSAssertDebug(userProfile);
    return userProfile.profileKey;
}

- (nullable SSKAES256Key *)profileKeyForRecipientId:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction {
    OWSAssertDebug(recipientId.length > 0);

    OWSUserProfile *userProfile =
        [OWSUserProfile getOrBuildUserProfileForRecipientId:recipientId transaction:transaction];
    OWSAssertDebug(userProfile);

    return userProfile.profileKey;
}

- (nullable NSString *)profileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(recipientId.length > 0);

    OWSUserProfile *userProfile = [self getUserProfileWithRecipientId:recipientId transaction:transaction];
    
    return userProfile.profileName;
}

- (nullable NSData *)profileAvatarDataForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    OWSUserProfile *userProfile = [self getUserProfileWithRecipientId:recipientId];
    
    if (userProfile.avatarFileName.length > 0) {
        return [self loadProfileDataWithFilename:userProfile.avatarFileName];
    }

    return nil;
}

- (void)downloadAvatarForUserProfile:(OWSUserProfile *)userProfile
{
    OWSAssertDebug(userProfile);

    __block OWSBackgroundTask *backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (userProfile.avatarUrlPath.length < 1) {
            OWSFailDebug(@"%@ Malformed avatar URL: %@", self.logTag, userProfile.avatarUrlPath);
            return;
        }
        NSString *_Nullable avatarUrlPathAtStart = userProfile.avatarUrlPath;

        if (userProfile.profileKey.keyData.length < 1 || userProfile.avatarUrlPath.length < 1) {
            return;
        }

        SSKAES256Key *profileKeyAtStart = userProfile.profileKey;

        NSString *fileName = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"jpg"];
        NSString *filePath = [self.profileAvatarsDirPath stringByAppendingPathComponent:fileName];

        @synchronized(self.currentAvatarDownloads)
        {
            if ([self.currentAvatarDownloads containsObject:userProfile.recipientId]) {
                // Download already in flight; ignore.
                return;
            }
            [self.currentAvatarDownloads addObject:userProfile.recipientId];
        }

        OWSLogVerbose(@"%@ downloading profile avatar: %@", self.logTag, userProfile.uniqueId);

        NSString *tempDirectory = NSTemporaryDirectory();
        NSString *tempFilePath = [tempDirectory stringByAppendingPathComponent:fileName];

        void (^completionHandler)(NSURLResponse *_Nonnull, NSURL *_Nullable, NSError *_Nullable) = ^(
            NSURLResponse *_Nonnull response, NSURL *_Nullable filePathParam, NSError *_Nullable error) {
            // Ensure disk IO and decryption occurs off the main thread.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 3 decrypt avatar data
                NSData *_Nullable encryptedData = (error ? nil : [NSData dataWithContentsOfFile:tempFilePath]);
                NSData *_Nullable decryptedData = [self decryptProfileData:encryptedData profileKey:profileKeyAtStart];
                UIImage *_Nullable image = nil;
                if (decryptedData) {
                    BOOL success = [decryptedData writeToFile:filePath atomically:YES];
                    if (success) {
                        image = [UIImage imageWithContentsOfFile:filePath];
                    }
                }
                @synchronized(self.currentAvatarDownloads)
                {
                    [self.currentAvatarDownloads removeObject:userProfile.recipientId];
                }
                
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    OWSUserProfile *latestUserProfile = [OWSUserProfile getOrBuildUserProfileForRecipientId:userProfile.recipientId
                                                            transaction:writeTransaction];
                    
                    if (latestUserProfile.profileKey.keyData.length < 1
                        || ![latestUserProfile.profileKey isEqual:userProfile.profileKey]) {
                        DDLogWarn(@"%@ Ignoring avatar download for obsolete user profile.", self.logTag);
                    } else if (![avatarUrlPathAtStart isEqualToString:latestUserProfile.avatarUrlPath]) {
                        OWSLogInfo(@"%@ avatar url has changed during download", self.logTag);
                        if (latestUserProfile.avatarUrlPath.length > 0) {
                            [self downloadAvatarForUserProfile:latestUserProfile];
                        }
                    } else if (error) {
                        DDLogError(@"%@ avatar download failed: %@", self.logTag, error);
                    } else if (!encryptedData) {
                        DDLogError(@"%@ avatar encrypted data could not be read.", self.logTag);
                    } else if (!decryptedData) {
                        DDLogError(@"%@ avatar data could not be decrypted.", self.logTag);
                    } else if (!image) {
                        DDLogError(@"%@ avatar image could not be loaded: %@", self.logTag, error);
                    } else {
                        [self updateProfileAvatarCache:image filename:fileName];
                        
                        [latestUserProfile updateWithAvatarFileName:fileName
                                                        transaction:writeTransaction
                                                         completion:nil];
                    }
                    
                    // If we're updating the profile that corresponds to our local number,
                    // update the local profile as well.
                    NSString *_Nullable localNumber = [TSAccountManager sharedInstance].localNumber;
                    if (localNumber && [localNumber isEqualToString:userProfile.recipientId]) {
                        OWSUserProfile *localUserProfile = self.localUserProfile;
                        OWSAssertDebug(localUserProfile);
                        [localUserProfile updateWithAvatarFileName:fileName
                                                       transaction:writeTransaction
                                                        completion:nil];
                        [self updateProfileAvatarCache:image filename:fileName];
                    }
                });
                


                OWSAssertDebug(backgroundTask);
                backgroundTask = nil;
            });
        };

        // todo，从服务器上下载Avatar。
        // modified: download avatar
        //    1 retrive download url from signal server by avatarUrlPath which was generated when uploading.
        __block NSString* url = nil;
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        TSRequest *req = [OWSRequestFactory profileAvatarUploadUrlRequest:userProfile.avatarUrlPath];
        [self.networkManager makeRequest:req success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (![responseObject isKindOfClass:[NSDictionary class]]) {
                dispatch_group_leave(group);
                OWSLogError(@"%@ unexpected response from server: %@", self.logTag, responseObject);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                error.isRetryable = YES;
                return;
            }
            
            NSDictionary *responseDict = (NSDictionary *)responseObject;
            NSString* location = [responseDict objectForKey:@"location"];
            url = [[NSString alloc]initWithString:location];
            
            dispatch_group_leave(group);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
            dispatch_group_leave(group);
            
            NSError *error = errorWrapper.asNSError;
            OWSLogError(@"%@ Failed to allocate attachment with error: %@", self.logTag, error);
            error.isRetryable = YES;
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        if (!url) {
            return;
        }
        
        // 2 download the avatar image
        NSURL *avatarUrlPath = [NSURL URLWithString:url];
        NSURLRequest *request = [NSURLRequest requestWithURL:avatarUrlPath];
        AFURLSessionManager *manager = [[AFURLSessionManager alloc]
            initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request
            progress:^(NSProgress *_Nonnull downloadProgress) {
                DDLogVerbose(
                    @"Downloading avatar for %@ %f", userProfile.recipientId, downloadProgress.fractionCompleted);
            }
            destination:^NSURL *_Nonnull(NSURL *_Nonnull targetPath, NSURLResponse *_Nonnull response) {
                return [NSURL fileURLWithPath:tempFilePath];
            }
            completionHandler:completionHandler];

        [downloadTask resume];
    });
}

- (void)updateProfileForRecipientId:(NSString *)recipientId
               profileNameEncrypted:(nullable NSData *)profileNameEncrypted
                      avatarUrlPath:(nullable NSString *)avatarUrlPath
{
    OWSAssertDebug(recipientId.length > 0);
    
    // Ensure decryption, etc. off main thread.
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        OWSUserProfile *userProfile = [OWSUserProfile getOrBuildUserProfileForRecipientId:recipientId transaction:transaction];
        
        if (!userProfile.profileKey) {
            return;
        }
        
        NSString *_Nullable profileName =
            [self decryptProfileNameData:profileNameEncrypted profileKey:userProfile.profileKey];
        
        [userProfile updateWithProfileName:profileName
                             avatarUrlPath:avatarUrlPath
                               transaction:transaction
                                completion:nil];
        
        // If we're updating the profile that corresponds to our local number,
        // update the local profile as well.
        NSString *_Nullable localNumber = [TSAccountManager sharedInstance].localNumber;
        if (localNumber && [localNumber isEqualToString:recipientId]) {
            OWSUserProfile *localUserProfile = self.localUserProfile;
            OWSAssertDebug(localUserProfile);

            [localUserProfile updateWithProfileName:profileName
                                      avatarUrlPath:avatarUrlPath
                                        transaction:transaction
                                         completion:nil];
        }

        // Whenever we change avatarUrlPath, OWSUserProfile clears avatarFileName.
        // So if avatarUrlPath is set and avatarFileName is not set, we should to
        // download this avatar. downloadAvatarForUserProfile will de-bounce
        // downloads.
        if (userProfile.avatarUrlPath.length > 0 && userProfile.avatarFileName.length < 1) {
            [self downloadAvatarForUserProfile:userProfile];
        }
    });
}

- (BOOL)isNullableDataEqual:(NSData *_Nullable)left toData:(NSData *_Nullable)right
{
    if (left == nil && right == nil) {
        return YES;
    } else if (left == nil || right == nil) {
        return YES;
    } else {
        return [left isEqual:right];
    }
}

- (BOOL)isNullableStringEqual:(NSString *_Nullable)left toString:(NSString *_Nullable)right
{
    if (left == nil && right == nil) {
        return YES;
    } else if (left == nil || right == nil) {
        return YES;
    } else {
        return [left isEqualToString:right];
    }
}

- (OWSUserProfile *)getUserProfileWithRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction{
    OWSUserProfile *userProfile = [OWSUserProfile getUserProfileForRecipientId:recipientId transaction:transaction];
    return userProfile;
}

- (OWSUserProfile *)getUserProfileWithRecipientId:(NSString *)recipientId {
    __block OWSUserProfile *userProfile = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        userProfile = [OWSUserProfile getUserProfileForRecipientId:recipientId transaction:readTransaction];
    }];
    
    return userProfile;
}

#pragma mark - Profile Encryption

- (nullable NSData *)encryptProfileData:(nullable NSData *)encryptedData profileKey:(SSKAES256Key *)profileKey
{
    OWSAssertDebug(profileKey.keyData.length == kAES256_KeyByteLength);

    if (!encryptedData) {
        return nil;
    }

    return [SSKCryptography encryptAESGCMWithData:encryptedData key:profileKey];
}

- (nullable NSData *)decryptProfileData:(nullable NSData *)encryptedData profileKey:(SSKAES256Key *)profileKey
{
    OWSAssertDebug(profileKey.keyData.length == kAES256_KeyByteLength);

    if (!encryptedData) {
        return nil;
    }

    return [SSKCryptography decryptAESGCMWithData:encryptedData key:profileKey];
}

- (nullable NSString *)decryptProfileNameData:(nullable NSData *)encryptedData profileKey:(SSKAES256Key *)profileKey
{
    OWSAssertDebug(profileKey.keyData.length == kAES256_KeyByteLength);

    NSData *_Nullable decryptedData = [self decryptProfileData:encryptedData profileKey:profileKey];
    if (decryptedData.length < 1) {
        return nil;
    }


    // Unpad profile name.
    NSUInteger unpaddedLength = 0;
    const char *bytes = decryptedData.bytes;

    // Work through the bytes until we encounter our first
    // padding byte (our padding scheme is NULL bytes)
    for (NSUInteger i = 0; i < decryptedData.length; i++) {
        if (bytes[i] == 0x00) {
            break;
        }
        unpaddedLength = i + 1;
    }

    NSData *unpaddedData = [decryptedData subdataWithRange:NSMakeRange(0, unpaddedLength)];

    return [[NSString alloc] initWithData:unpaddedData encoding:NSUTF8StringEncoding];
}

- (nullable NSData *)encryptProfileData:(nullable NSData *)data
{
    return [self encryptProfileData:data profileKey:self.localProfileKey];
}

- (BOOL)isProfileNameTooLong:(nullable NSString *)profileName
{
    OWSAssertIsOnMainThread();

    NSData *nameData = [profileName dataUsingEncoding:NSUTF8StringEncoding];
    return nameData.length > (NSUInteger)kOWSProfileManager_MaxNameLengthBytes;
}

- (nullable NSData *)encryptProfileNameWithUnpaddedName:(NSString *)name
{
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    if (nameData.length > (NSUInteger)kOWSProfileManager_MaxNameLengthBytes) {
        OWSFailDebug(@"%@ name data is too long with length:%lu", self.logTag, (unsigned long)nameData.length);
        return nil;
    }

    NSUInteger paddingByteCount = (NSUInteger)kOWSProfileManager_MaxNameLengthBytes - nameData.length;

    NSMutableData *paddedNameData = [nameData mutableCopy];
    // Since we want all encrypted profile names to be the same length on the server, we use `increaseLengthBy`
    // to pad out any remaining length with 0 bytes.
    [paddedNameData increaseLengthBy:paddingByteCount];
    OWSAssertDebug(paddedNameData.length == (NSUInteger)kOWSProfileManager_MaxNameLengthBytes);

    return [self encryptProfileData:[paddedNameData copy] profileKey:self.localProfileKey];
}

#pragma mark - Avatar Disk Cache

- (nullable NSData *)loadProfileDataWithFilename:(NSString *)filename
{
    OWSAssertDebug(filename.length > 0);

    NSString *filePath = [self.profileAvatarsDirPath stringByAppendingPathComponent:filename];
    return [NSData dataWithContentsOfFile:filePath];
}

- (nullable UIImage *)loadProfileAvatarWithFilename:(NSString *)filename
{
    if (filename.length == 0) {
        return nil;
    }

    UIImage *_Nullable image = nil;
    @synchronized(self.profileAvatarImageCache)
    {
        image = [self.profileAvatarImageCache objectForKey:filename];
    }
    if (image) {
        return image;
    }

    NSData *data = [self loadProfileDataWithFilename:filename];
    if (![data ows_isValidImage]) {
        return nil;
    }
    image = [UIImage imageWithData:data];
    [self updateProfileAvatarCache:image filename:filename];
    return image;
}

- (void)updateProfileAvatarCache:(nullable UIImage *)image filename:(NSString *)filename
{
    OWSAssertDebug(filename.length > 0);
    OWSAssertDebug(image);

    @synchronized(self.profileAvatarImageCache)
    {
        if (image) {
            [self.profileAvatarImageCache setObject:image forKey:filename];
        } else {
            [self.profileAvatarImageCache removeObjectForKey:filename];
        }
    }
}

+ (NSString *)legacyProfileAvatarsDirPath
{
    return [[OWSFileSystem appDocumentDirectoryPath] stringByAppendingPathComponent:@"ProfileAvatars"];
}

+ (NSString *)sharedDataProfileAvatarsDirPath
{
    return [[OWSFileSystem appSharedDataDirectoryPath] stringByAppendingPathComponent:@"ProfileAvatars"];
}

+ (nullable NSError *)migrateToSharedData
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    return [OWSFileSystem moveAppFilePath:self.legacyProfileAvatarsDirPath
                       sharedDataFilePath:self.sharedDataProfileAvatarsDirPath];
}

- (NSString *)profileAvatarsDirPath
{
    static NSString *profileAvatarsDirPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        profileAvatarsDirPath = OWSProfileManager.sharedDataProfileAvatarsDirPath;
        
        [OWSFileSystem ensureDirectoryExists:profileAvatarsDirPath];
    });
    return profileAvatarsDirPath;
}

// TODO: We may want to clean up this directory in the "orphan cleanup" logic.

- (void)resetProfileStorage
{
    OWSAssertIsOnMainThread();

    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:[self profileAvatarsDirPath] error:&error];
    if (error) {
        DDLogError(@"Failed to delete database: %@", error.description);
    }
}

#pragma mark - User Interface

- (void)presentAddThreadToProfileWhitelist:(TSThread *)thread
                        fromViewController:(UIViewController *)fromViewController
                                   success:(void (^)(void))successHandler
{
    OWSAssertIsOnMainThread();

    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *shareTitle = Localized(@"CONVERSATION_SETTINGS_VIEW_SHARE_PROFILE",
        @"Button to confirm that user wants to share their profile with a user or group.");
    [alertController addAction:[UIAlertAction actionWithTitle:shareTitle
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *_Nonnull action) {
                                                          [self userAddedThreadToProfileWhitelist:thread
                                                                                          success:successHandler];
                                                      }]];
    [alertController addAction:[OWSAlerts cancelAction]];

    [fromViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)userAddedThreadToProfileWhitelist:(TSThread *)thread success:(void (^)(void))successHandler
{
    OWSAssertIsOnMainThread();

    OWSProfileKeyMessage *message =
        [[OWSProfileKeyMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp] inThread:thread];

    BOOL isFeatureEnabled = NO;
    if (!isFeatureEnabled) {
        DDLogWarn(
            @"%@ skipping sending profile-key message because the feature is not yet fully available.", self.logTag);
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread
                                                             transaction:writeTransaction];
            [writeTransaction addAsyncCompletionOnMain:^{
                successHandler();
            }];
        });
        
        return;
    }

    [self.messageSender enqueueMessage:message
        success:^{
            [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread];

            dispatch_async(dispatch_get_main_queue(), ^{
                successHandler();
            });
        }
        failure:^(NSError *_Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogError(@"%@ Failed to send profile key message", self.logTag);
            });
        }];
}

#pragma mark - Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    // TODO: Sync if necessary.
}

@end

NS_ASSUME_NONNULL_END

