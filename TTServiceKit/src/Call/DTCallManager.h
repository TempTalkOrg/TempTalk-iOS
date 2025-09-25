//
//  DTCallManager.h
//  TTServiceKit
//
//  Created by Felix on 2021/7/30.
//

#import <Foundation/Foundation.h>
@class SDSAnyWriteTransaction;
@class SDSAnyReadTransaction;
@class OWSURLSession;

NS_ASSUME_NONNULL_BEGIN

@class TSThread;

extern NSString *const DTMeetingVirtualBackgroundKey;
extern NSString *const DTMeetingVirtualEffectBlur;
extern NSString *const DTMeetingLocalVideoMirrorKey;
extern NSString *const DTMeetingCCLanguageKey;
extern const int TSMeetingVersion;

typedef NS_ENUM(NSInteger, DTGroupMemberChangeType) {
    DTGroupMemberChangeTypeSelfLeave,
    DTGroupMemberChangeTypeKickOther,
    DTGroupMemberChangeTypeAddOther
};

typedef NS_ENUM(NSInteger, LiveStreamRole) {
    LiveStreamRoleBroadcaster = 0, //"broadcaster"
    LiveStreamRoleAudience         //"audience"
};

@interface DTCallManager : NSObject

+ (instancetype)sharedInstance;

+ (NSString *)generateRandomChannelName;

+ (NSString *)generateGroupChannelNameBy:(TSThread *)thread;

- (NSString *)restoreGroupIdStringFromChannelName:(NSString *)groupChannelName;

- (NSData *)restoreGroupIdFromChannelName:(NSString *)groupChannelName;

+ (NSString *)defaultMeetingName;

+ (NSString *)defaultInstanceMeetingName;

- (OWSURLSession *)meetingUrlSession;

+ (nullable TSThread *)getThreadFromChannelName:(NSString *)channelName transaction:(SDSAnyReadTransaction *)transaction;

- (void)getMeetingAuthSuccess:(void (^)(NSString * authToken))successHandler
                      failure:(void (^)(NSError *error))failureHandler;

- (void)getRTMTokenV1ByUid:(NSString *)uid
                   success:(void (^)(NSDictionary *responseObject))successHandler
                   failure:(void (^)(NSError *error))failureHandler;


/// 获取 1on1 meeting rtc token
/// @param invitee 邀请人
/// @param successHandler 成功回调
/// @param failureHandler 失败回调
- (void)getPrivateChannelTokenV1WithInvitee:(NSString *)invitee
                              notInContacts:(BOOL)notInContacts
                                meetingName:(NSString *)meetingName 
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler;

- (void)getPrivateChannelIdentityKeyByUid:(NSString *)uid
                   success:(void (^)(id responseObject))successHandler
                                  failure:(void (^)(NSError *error))failureHandler;

- (void)getChannelIdentityKeyByUidArr:(NSArray<NSString *> *)uids
                              success:(void (^)(id responseObject))successHandler
                              failure:(void (^)(NSError *error))failureHandler;

- (void)getPrekeyBundleByUid:(NSString *)uid
                   success:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

- (void)requestForConfigMeetingversion;

/// 获取 instant meeting rtc token
/// @param invitees 邀请人
/// @param successHandler 成功回调
/// @param failureHandler 失败回调
- (void)getInstantChannelTokenV1WithInvitees:(NSArray *)invitees
                                 meetingName:(NSString *)meetingName
                                     success:(void (^)(id responseObject))successHandler
                                     failure:(void (^)(NSError *error))failureHandler;

/*
/// 获取 external meeting rtc token
/// @param channelName channelName
/// @param successHandler 成功回调
/// @param failureHandler 失败回调
- (void)getExternalChannelTokenV1WithChannelName:(NSString *)channelName
                                         success:(void (^)(id responseObject))successHandler
                                         failure:(void (^)(NSError *error))failureHandler;
*/

- (void)getGroupChannelTokenV1ByChannelName:(NSString *)channelName
                                meetingName:(NSString *)meetingName
                                   invitees:(NSArray *)invitees
                                    encInfo:(NSArray *)encInfo
                             meetingVersion:(int)meetingVersion
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler;

/// 将会议中途拉入的人同步到 meeting 服务端
/// @param invitees invitees
/// @param successHandler successHandler
/// @param failureHandler failureHandler
- (void)addInviteesToChannel:(NSArray *)invitees
                 channelName:(NSString *)channelName
                         eid:(nullable NSString *)eid
                    encInfos:(nullable NSArray *)encInfos
                   publicKey:(nullable NSString *)publicKey
              meetingVersion:(int) meetingVersion
                   meetingId:(nullable NSString *)meetingId
                     success:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

- (void)getRenewRTCChannelTokenV1ByChannelName:(NSString *)channelName
                                      joinType:(nullable NSString *)joinType
                                     meetingId:(nullable NSString *)meetingId
                                    expireTime:(nullable NSString *)expireTime
                                       success:(void (^)(id responseObject))successHandler
                                       failure:(void (^)(NSError *error))failureHandler;

- (void)getUserRelatedChannelV1Success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingChannelAndPasswordV1Success:(void (^)(id responseObject))successHandler
                                      failure:(void (^)(NSError *error))failureHandler;

- (void)getExternalGroupChannelPasswordV1ByChannelName:(NSString *)channelName
                                           meetingName:(NSString *)meetingName
                                              invitees:(NSArray *)invitees
                                               success:(void (^)(id responseObject))successHandler
                                               failure:(void (^)(NSError *error))failureHandler;

- (void)getGroupMeetingDetailsV1ByMeetingId:(NSString *)groupMeetingId
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingDetailsV1ByMeetingId:(NSString *)meetingId
                               success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler;

- (void)createGroupV1WithGroupName:(nullable NSString *)groupName
                         meetingId:(NSNumber *)meetingId
                         memberIds:(NSArray <NSString *> *)memberIds
                           success:(void (^)(id responseObject))successHandler
                           failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingOnlineStatusByChannelName:(NSString *)channelName
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingShareInfoByChannelName:(NSString *)channelName
                                 success:(void (^)(id responseObject))successHandler
                                 failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingChannelDetailByChannelName:(NSString *)channelName
                                     success:(void (^)(id responseObject))successHandler
                                     failure:(void (^)(NSError *error))failureHandler;

- (void)putMeetingGroupMemberLeaveBychannelName:(NSString *)channelName
                                        success:(void (^)(id responseObject))successHandler
                                        failure:(void (^)(NSError *error))failureHandler;

- (void)putMeetingGroupMemberInviteBychannelName:(NSString *)channelName
                                         success:(void (^)(id responseObject))successHandler
                                         failure:(void (^)(NSError *error))failureHandler;

- (void)putMeetingGroupMemberKickBychannelName:(NSString *)channelName
                                         users:(NSArray <NSString *> *)users
                                       success:(void (^)(id responseObject))successHandler
                                       failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingHostByChannelName:(NSString *)channelName
                         completion:(void (^)(NSString *host))completion;

- (void)putMeetingHostTransferByChannelName:(NSString *)channelName
                                       host:(NSString *)host
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler;

- (void)putMeetingHostEndByChannelName:(NSString *)channelName
                               success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler;

- (void)postLocalCameraState:(BOOL)isOpen
                 channelName:(NSString *)channelName
                     account:(NSString *)account
                     success:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

- (void)getMeetingUserNameByUid:(NSString *)uid
                        success:(void (^)(NSString *name))successHandler
                        failure:(void (^)(NSError *error))failureHandler;

/// 群成员变更相关预约会议系统消息
/// - Parameters:
///   - thread: 对应会话
///   - meetingDetailUrl: 点击跳转url
///   - transaction: transaction
+ (void)sendGroupMemberChangeMeetingSystemMessageWithThread:(TSThread *)thread
                                           meetingDetailUrl:(NSString *)meetingDetailUrl
                                                transaction:(SDSAnyWriteTransaction *)transaction;

- (void)storeCClanguage:(NSString *)lang;
- (NSString *)storedCClanguage;

- (void)storeVirtualBgEffect:(nullable NSString *)effect
                 transaction:(nullable SDSAnyWriteTransaction *)writeTransaction;
- (nullable NSString *)storedVirtualBgEffectWithTransaction:(nullable SDSAnyReadTransaction *)readTransaction;

- (void)storeLocalVideoMirror:(BOOL)mirrorEnable
                  transaction:(nullable SDSAnyWriteTransaction *)writeTransaction;
- (BOOL)storedLocalVideoMirrorWithTransaction:(nullable SDSAnyReadTransaction *)readTransaction;

- (NSString *)cc_English;
- (NSString *)cc_Chinese;

@end

NS_ASSUME_NONNULL_END
