//
//  DTCallInviteMemberVC.h
//  Signal
//
//  Created by Felix on 2021/9/13.
//

#import <TTMessaging/TTMessaging.h>

@class TSThread;

typedef enum : NSUInteger {
    CallInviteTypeDefault,
    CallInviteTypeInstantMeeting
} CallInviteType;

NS_ASSUME_NONNULL_BEGIN

@interface DTCallInviteMemberVC : OWSViewController

@property (nonatomic) TSThread * _Nullable thread;
@property (nonatomic, assign) CallInviteType inviteType;
/// 是否是新版会议
@property (nonatomic, assign) BOOL isLiveKitCall;

@end

NS_ASSUME_NONNULL_END
