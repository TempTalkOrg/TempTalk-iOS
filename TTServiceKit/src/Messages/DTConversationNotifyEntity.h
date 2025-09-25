//
//  DTConversationNotifyEntity.h
//  TTServiceKit
//
//  Created by hornet on 2022/6/23.
//

#import <Mantle/Mantle.h>
#import "TSMessageMacro.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTConversationEntity : MTLModel <MTLJSONSerializing>
@property (nonatomic, strong) NSNumber *number;
@property (nonatomic, copy  ) NSString *conversation;
@property (nonatomic, assign) int muteStatus;
@property (nonatomic, assign) int blockStatus;
@property (nonatomic, copy) NSString *sourceDescribe;//相遇的方式/添加好友的方式
@property (nonatomic, copy) NSString *findyouDescribe;//找到的方式

@property (nonatomic, assign) int version;
@property (nonatomic, assign) TSMessageModeType confidentialMode;
@property (nonatomic, copy) NSString *remark;

@property (nonatomic, strong) NSNumber *messageExpiry;
@property (nonatomic, assign) uint64_t messageClearAnchor;

@end


@interface DTConversationNotifyEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) uint32_t sourceDeviceId;
@property (nonatomic, assign) int ver;
@property (nonatomic, assign) int changeType;
@property (nonatomic, strong) DTConversationEntity *conversation;

@end


NS_ASSUME_NONNULL_END
