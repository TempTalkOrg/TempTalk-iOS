//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTServiceKit/ProfileManagerProtocol.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kNSNotificationName_ProfileWhitelistDidChange;

extern const NSUInteger kOWSProfileManager_NameDataLength;
extern const NSUInteger kOWSProfileManager_MaxAvatarDiameter;
extern const int kOWSProfileManager_MaxNameLengthBytes;

@class SSKAES256Key;
@class OWSMessageSender;
@class TSThread;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class SDSKeyValueStore;

// This class can be safely accessed and used from any thread.
@interface OWSProfileManager : NSObject <ProfileManagerProtocol>

@property (nonatomic, readonly) SDSKeyValueStore *whitelistedPhoneNumbersStore;
@property (nonatomic, readonly) SDSKeyValueStore *whitelistedGroupsStore;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)resetProfileStorage;

+ (nullable NSError *)migrateToSharedData;

#pragma mark - Local Profile

// These two methods should only be called from the main thread.
- (SSKAES256Key *)localProfileKey;
// localUserProfileExists is true if there is _ANY_ local profile.
- (BOOL)localProfileExists;
// hasLocalProfile is true if there is a local profile with a name or avatar.
- (BOOL)hasLocalProfileWithTransaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSString *)localProfileNameWithTransaction:(SDSAnyReadTransaction *)transaction;
- (nullable UIImage *)localProfileAvatarImage;
- (void)ensureLocalProfileCached;
- (NSDictionary *)localAvatar;
// This method is used to update the "local profile" state on the client
// and the service.  Client state is only updated if service state is
// successfully updated.
//
// This method should only be called from the main thread.
- (void)updateLocalProfileName:(nullable NSString *)profileName
                   avatarImage:(nullable UIImage *)avatarImage
                       success:(void (^)(void))successBlock
                       failure:(void (^)(void))failureBlock;

- (BOOL)isProfileNameTooLong:(nullable NSString *)profileName;

// The local profile state can fall out of sync with the service
// (e.g. due to a botched profile update, for example).
- (void)fetchLocalUsersProfile;

#pragma mark - Profile Whitelist

// These methods are for debugging.
- (void)clearProfileWhitelist;
- (void)logProfileWhitelist;
- (void)regenerateLocalProfile;

- (void)addThreadToProfileWhitelist:(TSThread *)thread;
- (void)addThreadToProfileWhitelist:(TSThread *)thread
                        transaction:(SDSAnyWriteTransaction *)transaction;

- (void)setContactRecipientIds:(NSArray<NSString *> *)contactRecipientIds;

#pragma mark - Other User's Profiles

// This method is for debugging.
- (void)logUserProfiles;

- (nullable SSKAES256Key *)profileKeyForRecipientId:(NSString *)recipientId;

- (nullable NSString *)profileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;

- (nullable NSData *)profileAvatarDataForRecipientId:(NSString *)recipientId;

- (void)updateProfileForRecipientId:(NSString *)recipientId
               profileNameEncrypted:(nullable NSData *)profileNameEncrypted
                      avatarUrlPath:(nullable NSString *)avatarUrlPath;

#pragma mark - User Interface

- (void)presentAddThreadToProfileWhitelist:(TSThread *)thread
                        fromViewController:(UIViewController *)fromViewController
                                   success:(void (^)(void))successHandler;
- (void)userAddedThreadToProfileWhitelist:(TSThread *)thread success:(void (^)(void))successHandler;

@end

NS_ASSUME_NONNULL_END
