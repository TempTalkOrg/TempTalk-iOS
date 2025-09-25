//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

@class TSThread;
@class SSKAES256Key;
@class SDSAnyWriteTransaction;
@class SDSAnyReadTransaction;

NS_ASSUME_NONNULL_BEGIN

@protocol ProfileManagerProtocol <NSObject>

- (SSKAES256Key *)localProfileKey;

- (nullable NSData *)profileKeyDataForRecipientId:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction;

- (void)setProfileKeyData:(NSData *)profileKeyData forRecipientId:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction;

// TODO: ydb replace with transaction
- (BOOL)isUserInProfileWhitelist:(NSString *)recipientId;

- (BOOL)isUserInProfileWhitelist:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)readTransaction;

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread;

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread transaction:(SDSAnyReadTransaction *)readTransaction;

- (void)addUserToProfileWhitelist:(NSString *)recipientId transaction:(SDSAnyWriteTransaction *)transaction;

- (void)addUsersToProfileWhitelist:(NSArray<NSString *> *)recipientIds transaction:(SDSAnyWriteTransaction *)transaction;

// TODO: ydb replace with transaction
- (void)addGroupIdToProfileWhitelist:(NSData *)groupId;
- (void)addGroupIdToProfileWhitelist:(NSData *)groupId transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
