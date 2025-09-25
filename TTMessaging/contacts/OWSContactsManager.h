//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTServiceKit/Contact.h>
#import <TTServiceKit/ContactsManagerProtocol.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const OWSContactsManagerSignalAccountsDidChangeNotification;
extern NSString *const kLoadedContactsKey;

@class ImageCache;
@class SDImageCache;
@class SDWebImageManager;
@class SignalAccount;
@class UIFont;
@class SDSAnyWriteTransaction;

/**
 * Get latest Signal contacts, and be notified when they change.
 */
@interface OWSContactsManager : NSObject <ContactsManagerProtocol>

#pragma mark - Setup

- (void)startObserving;

#pragma mark - Accessors

@property (nonnull, readonly) ImageCache *avatarCache;
@property (nonnull, readonly) SDImageCache *sdAvatarCache;
@property (nonnull, readonly) SDWebImageManager *imageManager;

@property (atomic, readonly) NSArray<Contact *> *allContacts;

@property (atomic, readonly) NSArray<Contact *> *nofityContacts;

@property (atomic, readonly) NSDictionary<NSString *, Contact *> *allContactsMap;

// order of the signalAccounts array respects the systems contact sorting preference
@property (atomic, readonly) NSArray<SignalAccount *> *signalAccounts;
@property (atomic, readonly) NSDictionary<NSString *, SignalAccount *> *signalAccountMap;
@property (atomic, readonly) NSArray <SignalAccount *> *bots;

// read from memory cache
- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId;
// read from database
- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;
- (BOOL)hasSignalAccountForRecipientId:(NSString *)recipientId;

- (void)loadSignalAccountsFromCache;

#pragma mark - System Contact Fetching

// Must call `requestSystemContactsOnce` before accessing this method
@property (nonatomic, readonly) BOOL isSystemContactsAuthorized;
@property (nonatomic, readonly) BOOL isSystemContactsDenied;
@property (nonatomic, readonly) BOOL systemContactsHaveBeenRequestedAtLeastOnce;

@property (nonatomic, readonly) BOOL supportsContactEditing;

/// 请求全量服务端 contacts 数据
/// @param completionHandler 完成回调
- (void)userRequestedSystemContactsRefreshWithIsUserRequested:(BOOL)isUserRequested completion:(void (^)(NSError *_Nullable error))completionHandler;

#pragma mark - Util

- (BOOL)isSystemContact:(NSString *)recipientId;
- (BOOL)isSystemContactWithSignalAccount:(NSString *)recipientId;
- (BOOL)hasNameInSystemContactsForRecipientId:(NSString *)recipientId;
//获取名字
- (NSString *)displayNameForPhoneIdentifier:(nullable NSString *)identifier;
- (NSString *)displayNameForSignalAccount:(SignalAccount *)signalAccount;

//跳过 remark name，仅返回原始name或number
- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId;
- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId
                                   transaction:(SDSAnyReadTransaction *)transaction;

- (void)loadInternalContactsSuccess:(void(^)(NSArray * _Nonnull contacts))successHandler
                            failure:(void (^)(NSError *_Nullable error))failureHandler;

// added: add unkown contact into contact list.
- (void)addUnknownContact:(Contact *)contact addSuccess:(void (^)(NSString *))successHandler;

// contacts notify
- (void)handleNotifyMessageWithContacts:(NSArray<Contact *> *)contacts success:(void (^)(NSString *))success;

- (void)updateSignalAccountWithRecipientId:(NSString *)recipientId  withNewSignalAccount:(SignalAccount *)signalAccount withTransaction:(SDSAnyWriteTransaction *)transaction;

- (void)removeAccountWithRecipientId:(NSString *)recipientId
                         transaction:(SDSAnyWriteTransaction *)transaction;
//批量更新联系人
- (void)updateWithSignalAccounts:(NSArray<SignalAccount *> *)signalAccounts;
/**
 * Used for sorting, respects system contacts name sort order preference.
 */
- (NSString *)comparableNameForSignalAccount:(SignalAccount *)signalAccount;

// Generally we prefer the formattedProfileName over the raw profileName so as to
// distinguish a profile name apart from a name pulled from the system's contacts.
// This helps clarify when the remote person chooses a potentially confusing profile name.
- (nullable NSString *)formattedProfileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSString *)profileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSString *)nameFromSystemContactsForRecipientId:(NSString *)recipientId;

//- (nullable UIImage *)profileImageForPhoneIdentifier:(nullable NSString *)identifier;
- (nullable NSData *)profileImageDataForPhoneIdentifier:(nullable NSString *)identifier;

- (NSAttributedString *)formattedDisplayNameForSignalAccount:(SignalAccount *)signalAccount font:(UIFont *)font;
- (NSAttributedString *)formattedFullNameForRecipientId:(NSString *)recipientId font:(UIFont *)font;
- (NSString *_Nullable)formattedFullNameForRecipientId:(NSString *)recipientId;

- (NSString *)contactOrProfileNameForPhoneIdentifier:(NSString *)recipientId;
- (NSString *)contactOrProfileNameForPhoneIdentifier:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;
- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId;
- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
                                                             primaryFont:(UIFont *)primaryFont
                                                           secondaryFont:(UIFont *)secondaryFont
                                                             transaction:(SDSAnyReadTransaction *)transaction;

- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
                                                             primaryFont:(UIFont *)primaryFont
                                                           secondaryFont:(UIFont *)secondaryFont
                                                        primaryTextColor:(nullable UIColor *)primaryTextColor
                                                      secondaryTextColor:(nullable UIColor *)secondaryTextColor
                                                             transaction:(SDSAnyReadTransaction *)transaction;

#pragma mark - ShouldBeInitialized tag

- (BOOL)contactsShouldBeInitialized;
- (void)clearShouldBeInitializedTag;
@end

NS_ASSUME_NONNULL_END
