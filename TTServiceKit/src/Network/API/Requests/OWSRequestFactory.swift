//
//  OWSRequestFactory.swift
//  TTServiceKit
//
//  Created by Felix on 2022/7/20.
//

import Foundation

@objc
public extension OWSRequestFactory {
    static let textSecureAccountsAPI = "/v1/accounts"
    
    static let textSecureAttributesAPI = "/attributes/"
    
    static let textSecureAuthAPI = "/v1/auth"
    static let textSecureAuthV2API = "/v2/auth"
    
    static let textSecureMessagesAPI = "/v1/messages/"
    static let textSecureGroupMessageAPI = "/v1/messages/group/%@"
    static let textSecureSendMsgToUserAPI = "/v1/messages/destination/%@"
    static let textSecureKeysAPI = "/v2/keys"
    static let textSecureSignedKeysAPI = "/v2/keys/signed"
    static let textSecureDirectoryAPI = "/v1/directory"
    static let textSecureAttachmentsAPI = "/v1/attachments"
    static let textSecureDeviceProvisioningCodeAPI = "/v1/devices/provisioning/code"
    static let textSecureDeviceProvisioningAPIFormat = "/v1/provisioning/%@"
    static let textSecureDevicesAPIFormat = "/v1/devices/%@"
    static let textSecureProfileAPIFormat = "/v1/profile/%@"
    static let textSecureSetProfileNameAPIFormat = "/v1/profile/name/%@"
    static let textSecureProfileAvatarFormAPI = "/v1/profile/form/avatar"
    static let textSecure2FAAPI = "/v1/accounts/pin"
    static let textSecureProfileAvatarUrl = "/v1/profile/avatar/attachment"
    static let textSecureDebugLogAttachmentUrl = "/v1/profile/logger/attachment"
    static let v1ProfilePath = "/v1/profile"
    static let v1ClientBackstage = "/v1/client/backstage"
        
    static let TokenAuthForUserStateWSUrlPath = "/v1/authorize/token"
    
    static let changeUserStatusPath_V1 = "/v1/status/changeStatus"
    static let clearStatusSignaturePath_V1 = "/v1/status/clearStatusSignature"

    static let MeetingRTMTokenPath_V1 = "/v1/get-rtm-token"
    static let MeetingCenRTMTokenPath_V1 = "/v1/centrifugo/token"
    static let MeetingPriviteRTCChannelTokenPath_V1 = "/v1/get-private-rtc-token"
    static let MeetingInstantRTCChannelTokenPath_V1 = "/v1/get-instant-rtc-token"
    static let MeetingExternalRTCChannelTokenPath_V1 = "/v1/get-external-rtc-token"
    static let MeetingGroupRTCChannelTokenPath_V1 = "/v1/get-group-rtc-token"
    static let MeetingRenewRTCChannelTokenPath_V1 = "/v1/renew-rtc-token"
    static let MeetingAddInviteesRTCChannelTokenPath_V1 = "/v1/add-channel-users"
    static let MeetingGetUserRoomsPath_V1 = "/v1/get-user-rooms"
    static let MeetingCreateExternalPath_V1 = "/v1/create-external-meeting"
    static let MeetingExternalGroupRTCChannelTokenPath_V1 = "/v1/get-external-group-rtc-token"
    static let MeetingGetGroupMeetingDetailPath_V1 = "/v1/get-group-meeting-detail"
    static let MeetingGetMeetingDetailPath_V1 = "/v1/meeting/details"
    static let MeetingCreateGroupPath_V1 = "/v1/group"
    static let MeetingPrivateEnd_V1 = "/v1/meeting/private/end"
    static let MeetingGetOnlineUsersPath_V1 = "/v1/get-meeting-online-users"
    static let MeetingGetShareInfoPath_V1 = "/v1/get-share-info"
    static let MeetingGetChannelDetail_V1 = "/v1/get-channel-detail"
    static let MeetingGroupLeave_V1 = "/v1/group/leave"
    static let MeetingGroupInvite_V1 = "/v1/group/invite"
    static let MeetingGroupKick_V1 = "/v1/group/kick"
    static let MeetingHostGetInfo_V1 = "/v1/host/info"
    static let MeetingHostTransfer_V1 = "/v1/host/transfer"
    static let MeetingHostEnd_V1 = "/v1/host/end"
    static let MeetingGetUserName_V1 = "/v1/internal/get-user-name"
    static let MeetingLocalCameraState_V1 = "/v1/video/camera"

    static let LiveRTCChannelTokenPath_V1 = "/v1/live/token"
    static let LiveStartPath_V1 = "/v1/live/start"
    static let LiveSetRolePath_V1 = "/v1/live/role"
    static let LiveAudiencesQueryPath_V1 = "/v1/live/audience"

}
