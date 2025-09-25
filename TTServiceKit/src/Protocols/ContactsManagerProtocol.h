//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class CNContact;
@class Contact;
@class PhoneNumber;
@class SignalAccount;
@class UIImage;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class TSThread;

@protocol ContactsManagerProtocol <NSObject>

// read from memory cache
- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId;
// read from database
- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;

// mark 准备废弃⚠️
- (NSString *)displayNameForPhoneIdentifier:(NSString *_Nullable)phoneNumber;
// try read from memory cache firstly, if no, read from database
- (NSString *_Nonnull)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
                                        transaction:(SDSAnyReadTransaction *)transaction;
//跳过 remark name，仅返回原始name或number
- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId;
- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId
                                   transaction:(SDSAnyReadTransaction *)transaction;

- (nullable NSString *)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
                                      signalAccount:(SignalAccount *)signalAccount;
- (nullable NSString *)signatureForPhoneIdentifier:(NSString *_Nullable)phoneNumber
                                       transaction:(SDSAnyReadTransaction *)transaction;

- (NSString *)displayNameForThread:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction;

- (nullable NSString *)emailForPhoneIdentifier:(NSString *_Nullable)phoneNumber
                                   transaction:(SDSAnyReadTransaction *)transaction;

- (NSArray<SignalAccount *> *)signalAccounts;
- (NSDictionary<NSString *, SignalAccount *> *)signalAccountMap;

- (BOOL)isSystemContact:(NSString *)recipientId;
- (BOOL)isSystemContactWithSignalAccount:(NSString *)recipientId;
//- (BOOL)containInLoacalContact:(NSString *)recipientId;

- (void)updateWithSignalAccounts:(NSArray<SignalAccount *> *)signalAccounts;

- (void)updateSignalAccountWithRecipientId:(NSString *)recipientId  withNewSignalAccount:(SignalAccount *)signalAccount withTransaction:(SDSAnyWriteTransaction *)transaction;

- (NSComparisonResult)compareSignalAccount:(SignalAccount *)left
                         withSignalAccount:(SignalAccount *)right NS_SWIFT_NAME(compare(signalAccount:with:));

// the avatar image for current logged in user.
- (nullable UIImage *)localProfileAvatarImage;
- (nullable NSString *)localProfileNameWithTransaction:(SDSAnyReadTransaction *)transaction;

- (NSString *)contactOrProfileNameForPhoneIdentifier:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
