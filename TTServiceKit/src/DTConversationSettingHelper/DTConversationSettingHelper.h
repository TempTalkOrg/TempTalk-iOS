//
//  DTTokenHelper.h
//  TTServiceKit
//
//  Created by hornet on 2021/11/11.
//

#import <Foundation/Foundation.h>

extern NSString * _Nonnull const kConversationUpdateFromSocketMessageNotification;
@interface DTConversationSettingHelper : NSObject
@property (nonatomic, strong, readonly) NSMutableArray * _Nonnull loadedActiveSettingThreadIds;

/// 实例化
+ (instancetype _Nonnull )sharedInstance;

/// 请求所有的活跃会话的 会话信息
- (void)requestAllActiveThreadsConversationSettingAndSaveResult;

/// 请求单个会话的配置信息
/// @param conversationId 会话id （gid/receptid）
- (void)requestConversationSettingAndSaveResultWithConversationId:(NSString * _Nonnull)conversationId;

/// 批量请求
/// @param conversationIds 所有会话ID （gid/receptid）
- (void)requestConversationSettingAndSaveResultWithConversationIds:(NSArray * _Nonnull)conversationIds;

- (void)configMuteStatusWithConversationID:(NSString * _Nonnull)gid
                                muteStatus:(NSNumber * _Nonnull) muteStatus
                                   success:(void(^ _Nullable)(void)) successBlock
                                   failure:(void(^ _Nullable)(void)) failureBlock;

- (void)configBlockStatusWithConversationID:(NSString *_Nonnull)gid
                                blockStatus:(NSNumber *_Nonnull) blockStatus
                                    success:(void(^_Nullable)(void)) successBlock
                                   failure:(void(^_Nullable)(void)) failureBlock;

- (nullable NSString *)encryptRemarkString:(NSString * _Nonnull)remarkName receptid:(NSString * _Nonnull)receptid;

- (nullable NSString *)decryptRemarkString:(NSString * _Nonnull)remarkName receptid:(NSString * _Nonnull)receptid;

- (BOOL)isEncryptedRemarkString:(NSString * _Nonnull) remarkName;

@end


