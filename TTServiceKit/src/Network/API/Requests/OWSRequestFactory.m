//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSRequestFactory.h"
#import "OWS2FAManager.h"
#import "OWSDevice.h"
#import "TSAttributes.h"
#import "TSConstants.h"
#import "TSRequest.h"
//#import <AxolotlKit/NSData+keyVersionByte.h>
//#import <AxolotlKit/SignedPrekeyRecord.h>
#import "NSString+SSK.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "NSData+keyVersionByte.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OWSRequestFactory

+ (TSRequest *)enable2FARequestWithPin:(NSString *)pin
{
    OWSAssertDebug(pin.length > 0);

    return [TSRequest requestWithUrl:[NSURL URLWithString:self.textSecure2FAAPI]
                              method:@"PUT"
                          parameters:@{
                              @"pin" : pin,
                          }];
}

+ (TSRequest *)disable2FARequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:self.textSecure2FAAPI] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)acknowledgeMessageDeliveryRequestWithSource:(NSString *)source timestamp:(UInt64)timestamp
{
    OWSAssertDebug(source.length > 0);
    OWSAssertDebug(timestamp > 0);

    NSString *path = [NSString stringWithFormat:@"v1/messages/%@/%llu", source, timestamp];

    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)deleteDeviceRequestWithDevice:(OWSDevice *)device
{
    OWSAssertDebug(device);

    NSString *path = [NSString stringWithFormat:self.textSecureDevicesAPIFormat, @(device.deviceId)];

    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)deviceProvisioningCodeRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:self.textSecureDeviceProvisioningCodeAPI]
                              method:@"GET"
                          parameters:@{}];
}

+ (TSRequest *)deviceProvisioningRequestWithMessageBody:(NSData *)messageBody ephemeralDeviceId:(NSString *)deviceId
{
    OWSAssertDebug(messageBody.length > 0);
    OWSAssertDebug(deviceId.length > 0);

    NSString *path = [NSString stringWithFormat:self.textSecureDeviceProvisioningAPIFormat, deviceId];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"PUT"
                          parameters:@{
                              @"body" : [messageBody base64EncodedString],
                          }];
}

+ (TSRequest *)getDevicesRequest
{
    NSString *path = [NSString stringWithFormat:self.textSecureDevicesAPIFormat, @""];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)getMessagesRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/messages"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)getProfileRequestWithRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    NSString *path = [NSString stringWithFormat:self.textSecureProfileAPIFormat, recipientId];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)turnServerInfoRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/accounts/turn"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)allocAttachmentRequest
{
    NSString *path = [NSString stringWithFormat:@"%@", self.textSecureAttachmentsAPI];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)allocDebugLogAttachmentRequest
{
    NSString *path = [NSString stringWithFormat:@"%@", self.textSecureDebugLogAttachmentUrl];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)attachmentRequestWithAttachmentId:(UInt64)attachmentId relay:(nullable NSString *)relay
{
    OWSAssertDebug(attachmentId > 0);

    NSString *path = [NSString stringWithFormat:@"%@/%llu", self.textSecureAttachmentsAPI, attachmentId];

    // TODO: Should this be in the parameters?
    if (relay.length > 0) {
        path = [path stringByAppendingFormat:@"?relay=%@", relay];
    }

    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)availablePreKeysCountRequest
{
    NSString *path = [NSString stringWithFormat:@"%@", self.textSecureKeysAPI];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

// added: retrive invite code from server
+ (TSRequest *)getInviteCodeRequest:(nullable NSString *)friendName
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.textSecureDirectoryAPI, @"internal/account/invitation"];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"POST"
                          parameters:@{@"name":friendName}];
}

// added: exchange account number and vcode by inviteCode
+ (TSRequest *)exchangeAccountRequest:(NSString*)inviteCode
{
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@", self.textSecureAccountsAPI, @"invitation", inviteCode];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"GET"
                          parameters:@{}];
    request.shouldHaveAuthorizationHeaders = NO;
    
    return request;
}

// added: retrive inner contacts from server
+ (TSRequest *)getInternalContactsRequest
{
//    NSString *path = [NSString stringWithFormat:@"%@/%@", textSecureDirectoryAPI, @"internal/accounts"];
    NSString *path = [NSString stringWithFormat:@"%@/%@?%@", self.textSecureDirectoryAPI, @"contacts",@"properties=all"];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"POST" parameters:@{}];
}

// 获取用户联系人信息的V1版本
+ (TSRequest *)getV1ContactMessage:(nullable NSArray *)uids;
{
    NSString *path = [NSString stringWithFormat:@"%@/%@?%@", self.textSecureDirectoryAPI, @"contacts",@"properties=all"];
    TSRequest *request;
    if (!uids || (uids && uids.count ==0)) {
        request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"POST" parameters:@{}];
    }else {
        request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"POST" parameters:@{@"uids":uids}];
    }
    return request;
}

+ (TSRequest *)getV1ContactExtId:(nonnull NSString *)uid
{
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@", self.textSecureDirectoryAPI, @"extInfo", uid];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)putV1ProfileWithParams:(NSDictionary *)params {
    NSString *path = [NSString stringWithFormat:@"%@", self.v1ProfilePath];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:params];
    return request;
}

+ (TSRequest *)userStateWSTokenAuthRequestWithAppId:(nullable NSString *)appid {
    NSString *path = [NSString stringWithFormat:@"%@", self.TokenAuthForUserStateWSUrlPath];
    NSMutableDictionary *parms = [NSMutableDictionary dictionary];
    if (appid && appid.length > 0) {
        parms[@"appid"] = appid;
        parms[@"scope"] = @"NameRead,EmailRead";
    }
    OWSLogInfo(@"appid = %@, parms = %@",appid,parms);
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parms.copy];
    request.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"PUT", nil];
    return request;
}

#pragma mark - meeting 相关

+ (TSRequest *)meetingTokenAuthRequest {
    NSString *path = [NSString stringWithFormat:@"%@", self.TokenAuthForUserStateWSUrlPath];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:nil];
    return request;
}

+ (TSRequest *)getRTMTokenRequestV1:(NSString *)uid {
    NSString *u = uid.length ? uid : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingRTMTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString] method:@"GET"
                                        parameters:@{@"account" : u}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getPrivateChannelTokenRequestV1WithInvitee:(nullable NSString*)invitee 
                                            notInContacts:(BOOL) notInContacts
                                              meetingName:(NSString *)meetingName {
    NSString *encryptionTypes = [OWSRequestFactory generateEncryptionModes];
    NSString *i = invitee.length ? invitee : @"";
    NSString *name = DTParamsUtils.validateString(meetingName) ? meetingName : @"";
    NSArray *iA = @[i];
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingPriviteRTCChannelTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"encryptionParam": encryptionTypes,
                                                     @"invite": iA,
                                                     @"notInContacts": @(notInContacts),
                                                     @"meetingName" : name,
                                                     @"t" : @(self.requestTimestamp)
                                                   }];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getInstantChannelTokenRequestV1WithInvitee:(nullable NSArray *)invitees
                                              meetingName:(NSString *)meetingName {
    NSString *encryptionTypes = [OWSRequestFactory generateEncryptionModes];
    NSArray *is = invitees.count ? invitees : @[];
    NSString *m = meetingName ? meetingName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingInstantRTCChannelTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"encryptionParam": encryptionTypes,
                                                     @"invite": is,
                                                     @"meetingName": m,
                                                     @"t" : @(self.requestTimestamp)
                                                   }];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getExternalChannelTokenRequestV1WithChannelName:(NSString *)channelName {
    
    NSString *c = channelName.length ? channelName : @"";
    NSString *encryptionTypes = [OWSRequestFactory generateEncryptionModes];
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingExternalRTCChannelTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"encryptionParam": encryptionTypes,
                                                     @"channelName": c,
                                                     @"joinType": @"link",
                                                     @"t" : @(self.requestTimestamp)
                                                   }];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getGroupChannelTokenRequestV1:(NSString*)channelName
                                 meetingName:(NSString *)meetingName
                                    invitees:(NSArray *)invitees
                                     encInfo:(NSArray *)encInfo
                              meetingVersion:(int)meetingVersion {
    NSString *c = channelName.length ? channelName : @"";
    NSString *m = meetingName.length ? meetingName : @"";
    NSArray *i = invitees.count ? invitees : @[];
    NSArray *encInfos = DTParamsUtils.validateArray(encInfo) ? encInfo : @[];
    NSString *e = [OWSRequestFactory generateEncryptionModes];
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGroupRTCChannelTokenPath_V1];
    NSNumber *meetingVersion_num = @(meetingVersion);
    TSRequest *request = nil;
    if(meetingVersion == 3){
        ECKeyPair *identityKeyPair = [[OWSIdentityManager sharedManager] identityKeyPair];
        NSString *publickKey = [[identityKeyPair.publicKey prependKeyType] base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] ;
        request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                                method:@"PUT"
                                            parameters:@{@"channelName": c,
                                                         @"name": m,
                                                         @"invite": i,
                                                         @"encryptionParam": e,
                                                         @"encInfos":encInfos,
                                                         @"publicKey":publickKey,
                                                         @"meetingVersion":meetingVersion_num,
                                                         @"joinType": @"call",
                                                         @"t" : @(self.requestTimestamp)}];
    } else {
        request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                                method:@"PUT"
                                            parameters:@{@"channelName": c,
                                                         @"name": m,
                                                         @"invite": i,
                                                         @"encryptionParam": e,
                                                         @"meetingVersion":meetingVersion_num,
                                                         @"joinType": @"call",
                                                         @"t" : @(self.requestTimestamp)}];
    }
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)addInviteeToChannelWithInvitee:(nullable NSArray *)invitees
                                  channelName:(NSString *)channelName
                                          eid:(nullable NSString *)eid
                                     encInfos:(nullable NSArray *)encInfos
                                    publicKey:(nullable NSString *)publicKey
                               meetingVersion:(int) meetingVersion
                                    meetingId:(nullable NSString *)meetingId{
    
    NSString *encryptionTypes = [OWSRequestFactory generateEncryptionModes];
    NSArray *is = invitees.count ? invitees : @[];
    channelName = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingAddInviteesRTCChannelTokenPath_V1];
    
    TSRequest *request = nil;
    if(DTParamsUtils.validateArray(encInfos) && DTParamsUtils.validateString(publicKey) ){
        NSMutableDictionary *params = @{@"encryptionParam" : encryptionTypes,
            @"users": is,
            @"channelName": channelName,
            @"encInfos": encInfos,
            @"publicKey": publicKey,
            @"meetingVersion": @(meetingVersion),
           
        }.mutableCopy;
        if(DTParamsUtils.validateString(meetingId)){
            int meetingId_num = [meetingId intValue];
            params[@"meetingId"] = @(meetingId_num);
        }
        if (DTParamsUtils.validateString(eid)) {
            params[@"eid"] = eid;
        }
        request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                                method:@"PUT"
                                            parameters:params];
    } else {
        
        NSMutableDictionary *params = @{@"encryptionParam": encryptionTypes,
                                        @"users": is,
                                        @"channelName": channelName}.mutableCopy;
        
        if (DTParamsUtils.validateString(eid)) {
            params[@"eid"] = eid;
        }
        
        request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                                method:@"PUT"
                                            parameters:params];
    }
    
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getRenewRTCChannelTokenRequestV1:(NSString*)channelName
                                       joinType:(nullable NSString *)joinType
                                      meetingId:(nullable NSString *)meetingId
                                     expireTime:(nullable NSString *)expireTime {
    
    NSString *c = channelName.length ? channelName : @"";
    NSString *j = joinType.length ? joinType : @"";
    NSString *e = [OWSRequestFactory generateEncryptionModes];
    NSMutableDictionary *params = @{@"channelName" : c,
                                    @"encryptionParam" : e,
                                    @"joinType" : j,
                                    @"t" : @(self.requestTimestamp)
                                   }.mutableCopy;
    if (meetingId && meetingId.length > 0) {
        params[@"meetingId"] = @([meetingId integerValue]);
    }
    if (expireTime && expireTime.length > 0) {
        NSNumberFormatter *formatter = [NSNumberFormatter new];
        NSNumber *numberExpireTime = [formatter numberFromString:expireTime];
        params[@"expireTime"] = numberExpireTime;
    }
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingRenewRTCChannelTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:params];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getGroupMeetingDetailRequestV1:(NSString *)groupMeetingId {
    NSString *g = groupMeetingId.length ? groupMeetingId : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@?groupMeetingId=%@", self.MeetingGetGroupMeetingDetailPath_V1, g];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString] method:@"GET" parameters:nil];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingDetailRequestV1:(NSString *)meetingId {
    NSString *g = meetingId.length ? meetingId : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@?meetingId=%@", self.MeetingGetMeetingDetailPath_V1, g];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString] method:@"GET" parameters:nil];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)createMeetingGroupRequestV1WithGroupName:(nullable NSString *)groupName
                                              meetingId:(NSNumber *)meetingId
                                              memberIds:(NSArray <NSString *> *)memberIds {
   
//    NSString *mId = meetingId.length ? meetingId : @"";
    NSMutableDictionary *parameters = @{@"type" : @0,
                                        @"meetingId" : meetingId,
                                        @"members" : memberIds}.mutableCopy;
    if (DTParamsUtils.validateString(groupName)) {
        parameters[@"name"] = groupName;
    }

    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:self.MeetingCreateGroupPath_V1] method:@"POST" 
                                        parameters:parameters.copy];
    request.shouldHaveAuthorizationHeaders = NO;
    
    return request;
}


+ (TSRequest *)getUserRelatedChannelRequestV1 {
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGetUserRoomsPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString] method:@"GET" parameters:nil];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingChannelAndPasswordRequestV1 {
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingCreateExternalPath_V1];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString] method:@"POST" parameters:@{@"startTs" : @(ceil(now))}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getExternalGroupChannelTokenRequestV1:(NSString*)channelName
                                 meetingName:(NSString *)meetingName
                                    invitees:(NSArray *)invitees {
    NSString *c = channelName.length ? channelName : @"";
    NSString *m = meetingName.length ? meetingName : @"";
    NSArray *i = invitees.count ? invitees : @[];
    NSString *e = [OWSRequestFactory generateEncryptionModes];
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingExternalGroupRTCChannelTokenPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName": c,
                                                     @"name": m,
                                                     @"invite": i,
                                                     @"encryptionParam": e,}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingOnlineUsersRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGetOnlineUsersPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"GET"
                                        parameters:@{@"channelName": c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingShareInfoRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGetShareInfoPath_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"GET"
                                        parameters:@{@"channelName": c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingChannelDetailRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGetChannelDetail_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"GET"
                                        parameters:@{@"channelName": c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)putMeetingGroupMemberLeaveRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGroupLeave_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName" : c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)putMeetingGroupMemberInviteRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGroupInvite_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName" : c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)putMeetingGroupMemberKickRequestV1:(NSString *)channelName
                                            users:(NSArray <NSString *> *)users {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGroupKick_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName" : c,
                                                     @"users" : users
                                                   }];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingHostRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingHostGetInfo_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"GET"
                                        parameters:@{@"channelName": c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)putMeetingHostTransferRequestV1:(NSString *)channelName
                                          host:(NSString *)host {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingHostTransfer_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName" : c,
                                                     @"host" : host}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)putMeetingHostEndRequestV1:(NSString *)channelName {
    NSString *c = channelName.length ? channelName : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingHostEnd_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"PUT"
                                        parameters:@{@"channelName": c}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)getMeetingUserNameRequestV1:(NSString *)uid {
    NSString *u = uid.length ? uid : @"";
    NSString *urlString = [NSString stringWithFormat:@"%@", self.MeetingGetUserName_V1];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"GET"
                                        parameters:@{@"uid" : u}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (TSRequest *)postMeetingCameraState:(BOOL)isOpen
                          channelName:(NSString *)channelName
                              account:(NSString *)account {
    NSString *c = channelName.length ? channelName : @"";
    NSString *a = account.length ? account : @"";
    NSString *action = isOpen ? @"on" : @"off";
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:self.MeetingLocalCameraState_V1]
                                            method:@"POST"
                                        parameters:@{@"channelName" : c,
                                                     @"account" : a,
                                                     @"camera" : action}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (NSString *)generateEncryptionModes {
    NSString *modes = @"1,2,3,4,5,6,7,8";
    return modes;
}

+ (NSTimeInterval)requestTimestamp {
    
    return ceil([[NSDate date] timeIntervalSince1970]);
}

#pragma mark - userstatus

+ (TSRequest *)changeUserStatus:(NSNumber *)status
                         expire:(nullable NSNumber *)expire
                      signature:(nullable NSString *)signature
              pauseNotification:(nullable NSNumber *)pauseNotification {
    
    NSString *urlString = [NSString stringWithFormat:@"%@", self.changeUserStatusPath_V1];
    NSMutableDictionary *parameters = @{@"status": status}.mutableCopy;
    if (expire) {
        parameters[@"expire"] = expire;
    }
    if (signature) {
        parameters[@"signature"] = signature;
    }
    if (pauseNotification) {
        parameters[@"pauseNotification"] = pauseNotification;
    }
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:urlString]
                                            method:@"POST"
                                        parameters:parameters.copy];
    request.shouldHaveAuthorizationHeaders = NO;
    
    return request;
}

+ (TSRequest *)clearStatusSignature {
    
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:self.clearStatusSignaturePath_V1]
                                            method:@"POST"
                                        parameters:nil];
    request.shouldHaveAuthorizationHeaders = NO;
    
    return request;
}

#pragma mark -

+ (TSRequest *)currentSignedPreKeyRequest
{
    NSString *path = self.textSecureSignedKeysAPI;
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)profileAvatarUploadFormRequest
{
    NSString *path = self.textSecureProfileAvatarFormAPI;
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

// added: retrive url for user avatar from server: textSecureProfileAvatarUrl
//       upload url or download url
+ (TSRequest *)profileAvatarUploadUrlRequest:(nullable NSString *)recipientNumber
{
    NSString *path = nil;

    // if recipient number passed in, then the path is download one.
    // otherwise, the path is the one for uploading user avatar.
    if (recipientNumber) {
        path = [NSString stringWithFormat:@"%@/%@", self.textSecureProfileAvatarUrl, recipientNumber];
    }
    else {
        path = self.textSecureProfileAvatarUrl;
    }
    
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}


+ (TSRequest *)recipientPrekeyRequestWithRecipient:(NSString *)recipientNumber deviceId:(NSString *)deviceId
{
    OWSAssertDebug(recipientNumber.length > 0);
    OWSAssertDebug(deviceId.length > 0);

    NSString *path = [NSString stringWithFormat:@"%@/%@/%@", self.textSecureKeysAPI, recipientNumber, deviceId];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)registerForPushRequestWithPushIdentifier:(NSString *)identifier voipIdentifier:(NSString *)voipId
{
    OWSAssertDebug(identifier.length > 0);
//    OWSAssertDebug(voipId.length > 0);

    NSString *path = [NSString stringWithFormat:@"%@/%@", self.textSecureAccountsAPI, @"apn"];
    OWSAssertDebug(voipId);
    return [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"PUT"
                          parameters:@{
                              @"apnRegistrationId" : identifier,
                              @"voipRegistrationId" : voipId ?: @"",
                          }];
}

+ (TSRequest *)updateAttributesRequestWithManualMessageFetching:(BOOL)enableManualMessageFetching
{
    NSString *path = [self.textSecureAccountsAPI stringByAppendingString:self.textSecureAttributesAPI];
    NSString *_Nullable pin = [OWS2FAManager.sharedManager pinCode];
    return [TSRequest
        requestWithUrl:[NSURL URLWithString:path]
                method:@"PUT"
            parameters:[TSAttributes attributesFromStorageWithManualMessageFetching:enableManualMessageFetching
                                                                                pin:pin 
                                                                           passcode:nil]];
}

+ (TSRequest *)unregisterAccountRequest
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.textSecureAccountsAPI, @"apn"];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:@{}];
}

///
+ (TSRequest *)requestVerificationCodeRequestWithPhoneNumber:(NSString *)phoneNumber
                                                   transport:(TSVerificationTransport)transport
{
    OWSAssertDebug(phoneNumber.length > 0);
    NSString *path = [NSString stringWithFormat:@"%@/%@/code/%@?client=ios",
                               self.textSecureAccountsAPI,
                               [self stringForTransport:transport],
                               phoneNumber];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
    request.shouldHaveAuthorizationHeaders = NO;
    return request;
}

+ (NSString *)stringForTransport:(TSVerificationTransport)transport
{
    switch (transport) {
        case TSVerificationTransportSMS:
            return @"sms";
        case TSVerificationTransportVoice:
            return @"voice";
    }
}

+ (TSRequest *)submitMessageRequestWithRecipient:(NSString *)recipientId
                                        messages:(NSArray *)messages
                                           relay:(nullable NSString *)relay
                                       timeStamp:(uint64_t)timeStamp
                                          silent:(BOOL)silent
{
    // NOTE: messages may be empty; See comments in OWSDeviceManager.
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(timeStamp > 0);

    NSString *path = [self.textSecureMessagesAPI stringByAppendingString:recipientId];
    NSMutableDictionary *parameters = [@{
        @"messages" : messages,
        @"timestamp" : @(timeStamp),
        @"silent":@(silent)
    } mutableCopy];

    if (relay) {
        parameters[@"relay"] = relay;
    }
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
}

+ (TSRequest *)submitTunnelSecurityMessageRequestWithGId:(NSString *)gId
                                              parameters:(NSDictionary *)parameters
{
    OWSAssertDebug(parameters.count > 0);

    NSString *path = [NSString stringWithFormat:self.textSecureGroupMessageAPI, gId];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
}

+ (TSRequest *)submitTunnelSecurityMessageRequestWithRecipient:(NSString *)recipientId
                                                    parameters:(NSDictionary *)parameters
{
    OWSAssertDebug(parameters.count > 0);

    NSString *path = [NSString stringWithFormat:self.textSecureSendMsgToUserAPI, recipientId];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
}

+ (TSRequest *)postUserBackgroundStatus:(BOOL)inBackground {
   
    return [TSRequest requestWithUrl:[NSURL URLWithString:self.v1ClientBackstage]
                              method:@"POST"
                          parameters:@{@"status" : @(inBackground)}];
}

// temptalk

// added: retrive invite code from server
+ (TSRequest *)getLongPeroidInviteCodeRequestWithRegenerate:(NSNumber *)regenerate shortNumber:(NSNumber *)shortNumber;
{
    NSString *path = [NSString stringWithFormat:@"/%@?regenerate=%d&short=%d", @"v3/accounts/inviteCode",[regenerate intValue],[shortNumber intValue]];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"POST"
                          parameters:nil];
}

@end

NS_ASSUME_NONNULL_END
