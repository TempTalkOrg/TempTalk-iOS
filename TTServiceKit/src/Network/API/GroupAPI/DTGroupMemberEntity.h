//
//  DTGroupMemberEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/2.
//

/*
 {
         "uid": "+70000000001",
         "role": 0,
         "displayName": "Mic@Mars" // Empty if not set
       }
 */

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TSGroupNotificationType) {
    TSGroupNotificationTypeAll,//0: All Messages
    TSGroupNotificationTypeAtMe,//1: @Mentions only
    TSGroupNotificationTypeOff//2: Off
};

typedef NS_ENUM(NSInteger, DTGroupMemberRole) {
    DTGroupMemberRoleOwner,//0: Owner
    DTGroupMemberRoleAdmin,//1: Admin
    DTGroupMemberRoleMember,//2: Member
    DTGroupMemberRoleUnknown
};

typedef NS_ENUM(NSInteger, DTGroupRAPIDRole) {
    DTGroupRAPIDRoleNone = 0,
    DTGroupRAPIDRoleRecommend,
    DTGroupRAPIDRoleAgree,
    DTGroupRAPIDRolePerform,
    DTGroupRAPIDRoleInput,
    DTGroupRAPIDRoleDecider,
    DTGroupRAPIDRoleObserver
};

@interface DTGroupMemberEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, assign) DTGroupMemberRole role;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *remark;
@property (nonatomic, assign) TSGroupNotificationType notification;
@property (nonatomic, strong) NSNumber *useGlobal;
@property (nonatomic, strong) NSNumber *extId;
@property (nonatomic, assign) DTGroupRAPIDRole rapidRole;
@property (nonatomic, readonly) NSString *rapidDescription;

@end

NS_ASSUME_NONNULL_END
