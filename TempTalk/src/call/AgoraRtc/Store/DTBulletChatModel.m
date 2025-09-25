//
//  DTBulletChatModel.m
//  Wea
//
//  Created by Ethan on 2022/8/3.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTBulletChatModel.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/NSString+SSK.h>

NSString *const DTBulletTypeMicOn = @"mic-on";
NSString *const DTBulletTypeMicOff = @"mic-off";
NSString *const DTBulletTypeVideoOn = @"video-on";
NSString *const DTBulletTypeVideoOff = @"video-off";
NSString *const DTBulletTypeJoin = @"join";
NSString *const DTBulletTypeLeft = @"left";
NSString *const DTBulletTypeText = @"text";
NSString *const DTBulletTypeScreenShare = @"start-screen";
//NSString *const DTBulletTypeCaptionOn = @"caption-on";
NSString *const DTBulletTypeLocalTips = @"local-tips"; //local tips, without user name
NSString *const DTRTMMsgTypeMuteOther = @"mute-other";
NSString *const DTRTMMsgTypeHostContinue = @"host-continue";
NSString *const DTRTMMsgTypeLiveStart = @"live-stream-start";

NSString *const DTRTMMsgTypeSetAsGuest = @"set-as-guest";
NSString *const DTRTMMsgTypeSetAsAttendee = @"set-as-attendee";
NSString *const DTRTMMsgTypeHostDeny = @"host-deny";
NSString *const DTRTMMsgTypeHostHostSyncGuest = @"host-sync-guest";
NSString *const DTRTMMsgTypeGuestHandUp = @"hand-up";
NSString *const DTRTMMsgTypeGuestCancelHandUp = @"cancel-hand-up";

@implementation DTBulletChatModel

- (instancetype)init {
    
    if (self = [super init]) {
        _timestamp = [NSDate ows_millisecondTimeStamp];
    }
    return self;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (DTBulletChatModel *)generateBulletChatModelWithMessage:(NSString *)message
                                                     type:(NSString *)type
                                                receiptId:(NSString *)receiptId {
    NSString *name = [[Environment shared].contactsManager displayNameForPhoneIdentifier:receiptId];
    name = name.length > 0 ? [name removeBUMessage] : receiptId;
    
    DTBulletChatModel *bulletChatModel = [DTBulletChatModel new];
    bulletChatModel.id = receiptId;
    bulletChatModel.account = [receiptId transforToIOSAccount];
    bulletChatModel.name = name;
    bulletChatModel.text = message;
    bulletChatModel.type = type;
    
    return bulletChatModel;
}

+ (DTBulletChatModel *)generateBulletChatModelWithMessage:(NSString *)message
                                                     type:(NSString *)type
                                                receiptId:(NSString *)receiptId
                                               senderName:(NSString *)senderName {
    DTBulletChatModel *bulletChatModel = [DTBulletChatModel new];
    bulletChatModel.id = receiptId;
    bulletChatModel.account = [receiptId transforToIOSAccount];
    bulletChatModel.name = senderName && senderName.length > 0 ? senderName : @"";
    bulletChatModel.text = message;
    bulletChatModel.type = type;
    
    return bulletChatModel;
}

@end
