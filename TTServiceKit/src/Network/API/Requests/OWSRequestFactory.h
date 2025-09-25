//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class OWSDevice;
@class PreKeyRecord;
@class SignedPreKeyRecord;
@class TSRequest;

typedef NS_ENUM(NSUInteger, TSVerificationTransport) { TSVerificationTransportVoice = 1, TSVerificationTransportSMS };

@interface OWSRequestFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (TSRequest *)enable2FARequestWithPin:(NSString *)pin;

+ (TSRequest *)disable2FARequest;

+ (TSRequest *)acknowledgeMessageDeliveryRequestWithSource:(NSString *)source timestamp:(UInt64)timestamp;

+ (TSRequest *)deleteDeviceRequestWithDevice:(OWSDevice *)device;

+ (TSRequest *)deviceProvisioningCodeRequest;

+ (TSRequest *)deviceProvisioningRequestWithMessageBody:(NSData *)messageBody ephemeralDeviceId:(NSString *)deviceId;

+ (TSRequest *)getDevicesRequest;

+ (TSRequest *)getMessagesRequest;

+ (TSRequest *)getProfileRequestWithRecipientId:(NSString *)recipientId;

+ (TSRequest *)turnServerInfoRequest;

+ (TSRequest *)allocAttachmentRequest;

+ (TSRequest *)allocDebugLogAttachmentRequest;

+ (TSRequest *)attachmentRequestWithAttachmentId:(UInt64)attachmentId relay:(nullable NSString *)relay;

+ (TSRequest *)availablePreKeysCountRequest;

+ (TSRequest *)getInternalContactsRequest;

/// 获取用户联系人的V1版本 uids  如果不传则会获取全部联系人
/// @param uids 用户联系人数组
+ (TSRequest *)getV1ContactMessage:(nullable NSArray *)uids;

+ (TSRequest *)getV1ContactExtId:(nonnull NSString *)uid;
/// V1版本的
/// @param params 参数
+ (TSRequest *)putV1ProfileWithParams:(NSDictionary *)params;

// request invite code
+ (TSRequest *)getInviteCodeRequest:(nullable NSString *)friendName;

#pragma mark - meeting 相关

/// 会议接口所需认证信息
+ (TSRequest *)meetingTokenAuthRequest;

/// 用于用户状态的鉴权
+ (TSRequest *)userStateWSTokenAuthRequestWithAppId:(nullable NSString *)appid;

/// 请求云信令token
/// @param uid uid
+ (TSRequest *)getRTMTokenRequestV1:(NSString*)uid;

/// 请求1v1语音频道token
/// @param invitee invitee
+ (TSRequest *)getPrivateChannelTokenRequestV1WithInvitee:(nullable NSString*)invitee 
                                            notInContacts:(BOOL) notInContacts
                                              meetingName:(NSString *)meetingName;

/// 构建 instant meeting token 请求
/// @param invitees invitees
+ (TSRequest *)getInstantChannelTokenRequestV1WithInvitee:(nullable NSArray *)invitees
                                              meetingName:(NSString *)meetingName;

/// 构建 external meeting token 请求
/// @param channelName channelName
+ (TSRequest *)getExternalChannelTokenRequestV1WithChannelName:(NSString *)channelName;

/// 请求群语音频道token
/// @param channelName 频道名
/// @param meetingName 会议名
/// @param invitees 会议的人员信息（包含自己）
+ (TSRequest *)getGroupChannelTokenRequestV1:(NSString*)channelName
                                 meetingName:(NSString *)meetingName
                                    invitees:(NSArray *)invitees
                                     encInfo:(NSArray *)encInfo
                              meetingVersion:(int)meetingVersion;

/// add invitees to channel
/// @param invitees invitees
+ (TSRequest *)addInviteeToChannelWithInvitee:(nullable NSArray *)invitees
                                  channelName:(NSString *)channelName
                                          eid:(nullable NSString *)eid
                                     encInfos:(nullable NSArray *)encInfos
                                    publicKey:(nullable NSString *)publicKey
                               meetingVersion:(int) meetingVersion
                                    meetingId:(nullable NSString *)meetingId;

/// renew RTC channel token
/// @param channelName 频道名
/// @param joinType window 通过弹窗，meetingBar 入会
+ (TSRequest *)getRenewRTCChannelTokenRequestV1:(NSString*)channelName
                                       joinType:(nullable NSString *)joinType
                                      meetingId:(nullable NSString *)meetingId
                                     expireTime:(nullable NSString *)expireTime;


/// 群会议进会/离会日志
/// @param groupMeetingId 群会议id
+ (TSRequest *)getGroupMeetingDetailRequestV1:(NSString *)groupMeetingId;

/// 会议进会/离会日志(新)
/// @param meetingId 群会议id
+ (TSRequest *)getMeetingDetailRequestV1:(NSString *)meetingId;


/// 会议详情列表建群
/// @param groupName 群名
/// @param meetingId meetingId
/// @param memberIds memberIds
+ (TSRequest *)createMeetingGroupRequestV1WithGroupName:(nullable NSString *)groupName
                                              meetingId:(NSNumber *)meetingId
                                              memberIds:(NSArray <NSString *> *)memberIds;

/// 查询所有与此用户有关的ROOM状态
+ (TSRequest *)getUserRelatedChannelRequestV1;

/// 查询会议 channelName 和 password
+ (TSRequest *)getMeetingChannelAndPasswordRequestV1;

/// 请求外部群会议password
/// @param channelName 频道名
/// @param meetingName 会议名
/// @param invitees 会议的人员信息（包含自己）
+ (TSRequest *)getExternalGroupChannelTokenRequestV1:(NSString*)channelName
                                         meetingName:(NSString *)meetingName
                                            invitees:(NSArray *)invitees;

/// 请求当前 channel 的在线用户
/// @param channelName 频道名
+ (TSRequest *)getMeetingOnlineUsersRequestV1:(NSString *)channelName;

/// 获取当前正在分享的用户
/// @param channelName 频道名
+ (TSRequest *)getMeetingShareInfoRequestV1:(NSString *)channelName;

/// 获取会议当前状态
/// @param channelName 频道名
+ (TSRequest *)getMeetingChannelDetailRequestV1:(NSString *)channelName;

/// 用户退群
/// @param channelName 频道名
+ (TSRequest *)putMeetingGroupMemberLeaveRequestV1:(NSString *)channelName;

/// 邀请用户入群
/// @param channelName 频道名
+ (TSRequest *)putMeetingGroupMemberInviteRequestV1:(NSString *)channelName;

/// 删除群成员
/// @param channelName 频道名
+ (TSRequest *)putMeetingGroupMemberKickRequestV1:(NSString *)channelName
                                            users:(nonnull NSArray <NSString *> *)users;

/// 获取会议当前主持人
/// @param channelName 频道名
+ (TSRequest *)getMeetingHostRequestV1:(NSString *)channelName;

/// 转让会议主持人
/// @param channelName 频道名
/// @param host 转让目标人id
+ (TSRequest *)putMeetingHostTransferRequestV1:(NSString *)channelName
                                          host:(NSString *)host;

/// 主持人结束会议
/// @param channelName 频道名
+ (TSRequest *)putMeetingHostEndRequestV1:(NSString *)channelName;

+ (TSRequest *)getMeetingUserNameRequestV1:(NSString *)uid;

/// 是否打开本地camera
+ (TSRequest *)postMeetingCameraState:(BOOL)isOpen
                          channelName:(NSString *)channelName
                              account:(NSString *)account;

#pragma mark -

// exchange account number and vcode  by inviteCode
+ (TSRequest *)exchangeAccountRequest:(NSString *)inviteCode;

+ (TSRequest *)currentSignedPreKeyRequest;

+ (TSRequest *)profileAvatarUploadFormRequest;

+ (TSRequest *)profileAvatarUploadUrlRequest:(nullable NSString *)recipientNumber;

+ (TSRequest *)recipientPrekeyRequestWithRecipient:(NSString *)recipientNumber deviceId:(NSString *)deviceId;

+ (TSRequest *)registerForPushRequestWithPushIdentifier:(NSString *)identifier voipIdentifier:(NSString *)voipId;

+ (TSRequest *)updateAttributesRequestWithManualMessageFetching:(BOOL)enableManualMessageFetching;

+ (TSRequest *)unregisterAccountRequest;

+ (TSRequest *)requestVerificationCodeRequestWithPhoneNumber:(NSString *)phoneNumber
                                                   transport:(TSVerificationTransport)transport;

+ (TSRequest *)submitMessageRequestWithRecipient:(NSString *)recipientId
                                        messages:(NSArray *)messages
                                           relay:(nullable NSString *)relay
                                       timeStamp:(uint64_t)timeStamp
                                          silent:(BOOL)silent;

+ (TSRequest *)submitTunnelSecurityMessageRequestWithGId:(NSString *)gId
                                              parameters:(NSDictionary *)parameters;

+ (TSRequest *)submitTunnelSecurityMessageRequestWithRecipient:(NSString *)recipientId
                                                    parameters:(NSDictionary *)parameters;

+ (TSRequest *)registerIdentitykeyRequest;

+ (TSRequest *)changeUserStatus:(NSNumber *)status
                         expire:(nullable NSNumber *)expire
                      signature:(nullable NSString *)signature
              pauseNotification:(nullable NSNumber *)pauseNotification;

+ (TSRequest *)clearStatusSignature;

+ (TSRequest *)postUserBackgroundStatus:(BOOL)inBackground;

+ (TSRequest *)getLongPeroidInviteCodeRequestWithRegenerate:(NSNumber *)regenerate
                                                shortNumber:(NSNumber *)shortNumber;

@end

NS_ASSUME_NONNULL_END
