//
//  DTServerNotifyEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import <UIKit/UIKit.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DTServerNotifyType) {
    DTServerNotifyTypeGroupUpdate                       = 0, // 计入群消息的 sequenceid, 跟正常消息合并计算 sequenceid
    DTServerNotifyTypeContactsUpdate                    = 1,
    DTServerNotifyTypeLightTaskUpdate                   = 2,
    DTServerNotifyTypeVoteUpdate                        = 3,
    DTServerNotifyTypeConversationUpdate                = 4,//会话更新
    DTServerNotifyTypeConversationSharedConfiguration   = 5,//会话共享配置更新1v1
    DTServerNotifyTypeAddContacts                       = 6, //ask friend
    DTServerNotifyTypeReminder                          = 8,//会话的reminder提醒
    DTServerNotifyTypeCardUpdate                        = 9,//卡片刷新
    DTServerNotifyTypeCalendarVersion                   = 10, // calendar version
    DTServerNotifyTypeTopicTrack                        = 12, // topic track相关操作
    DTServerNotifyTypeMessageArchive                    = 14,
    DTServerNotifyTypeScreenLock                        = 15,
    DTServerNotifyTypeCoWorkerApproved                  = 16, // co-worker 同意了邀请
    DTServerNotifyTypeCallEnd                           = 17, // call
    DTServerNotifyTypeUnknown                           = 18,
    DTServerNotifyTypeResetIdentityKey                  = 19  // 重新生成密钥
};

@interface DTServerNotifyEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) DTServerNotifyType notifyType;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) BOOL display;
@property (nonatomic, assign) uint64_t notifyTime;
@property (nonatomic, strong) NSDictionary *data;

@end

NS_ASSUME_NONNULL_END
