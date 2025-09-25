//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSConversationSettingsViewDelegate.h"
#import <TTMessaging/OWSViewController.h>
@class TSThread;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DTCreateGroupType) {
    DTCreateGroupTypeDefault = 0,
    DTCreateGroupTypeConvenient, // 快速建群
    DTCreateGroupTypeContact,    // 单聊会话设置建群
    DTCreateGroupTypeByMeeting   // 会议结束view detail一键建群
};

@interface NewGroupViewController : OWSViewController

@property (nonatomic, weak) id<OWSConversationSettingsViewDelegate> delegate;
@property (nonatomic, assign) DTCreateGroupType createType;
@property (nonatomic, strong, nullable) TSThread *thread;


/// 会议一键建群
/// 类型为DTCreateGroupTypeByMeeting时传入参会人ids
@property (nonatomic, strong, nullable) NSSet <NSString *> *meetingMemberIds;
@property (nonatomic, copy, nullable) NSString *meetingGroupName;
@property (nonatomic, copy, nullable) NSNumber *meetingId;
@property (nonatomic, copy, nullable) void (^createGroupFinish)(NSString *, NSString *, BOOL isGroupExist);

@end

NS_ASSUME_NONNULL_END
