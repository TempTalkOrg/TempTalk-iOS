//
//  DTBulletChatModel.h
//  Wea
//
//  Created by Ethan on 2022/8/3.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

// RTM channel
extern NSString *const DTBulletTypeMicOn;
extern NSString *const DTBulletTypeMicOff;
extern NSString *const DTBulletTypeVideoOn;
extern NSString *const DTBulletTypeVideoOff;
extern NSString *const DTBulletTypeJoin;
extern NSString *const DTBulletTypeLeft;
extern NSString *const DTBulletTypeText;
extern NSString *const DTBulletTypeScreenShare;
//extern NSString *const DTBulletTypeCaptionOn;
extern NSString *const DTBulletTypeLocalTips; //local system tips

// RTM message
extern NSString *const DTRTMMsgTypeMuteOther;
extern NSString *const DTRTMMsgTypeHostContinue;
extern NSString *const DTRTMMsgTypeLiveStart;

extern NSString *const DTRTMMsgTypeSetAsGuest;
extern NSString *const DTRTMMsgTypeSetAsAttendee;
extern NSString *const DTRTMMsgTypeHostDeny;
extern NSString *const DTRTMMsgTypeGuestHandUp;
extern NSString *const DTRTMMsgTypeGuestCancelHandUp;

@interface DTBulletChatModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *name;
/// recipientId
@property (nonatomic, copy) NSString *id;
/// iosxxxxxxx
@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *type;

@property (nonatomic, assign, readonly) uint64_t timestamp;

+ (DTBulletChatModel *)generateBulletChatModelWithMessage:(nullable NSString *)message
                                                     type:(NSString *)type
                                                receiptId:(NSString *)receiptId;

+ (DTBulletChatModel *)generateBulletChatModelWithMessage:(nullable NSString *)message
                                                     type:(NSString *)type
                                                receiptId:(NSString *)receiptId
                                               senderName:(NSString *)senderName;

@end

NS_ASSUME_NONNULL_END
