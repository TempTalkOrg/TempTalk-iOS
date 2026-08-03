//
//  DTFriendWeakRelationNotifyEntity.h
//  TTServiceKit
//
//  notifyType=25 弱联系人(待移除)变更通知的 data 实体。
//  与通讯录通知 DTContactsNotifyEntity 完全分离：独立类型、独立处理器、独立缓存。
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFriendWeakRelationNotifyEntity : MTLModel<MTLJSONSerializing>

/// 0=进入弱态(加入待移除集) / 1=已移除(到期 或 立即移除，共用)
@property (nonatomic, assign) NSInteger changeType;
/// 0=对方删好友 / 1=账号注销。客户端不依赖，仅透传备扩展。
@property (nonatomic, assign) NSInteger reason;
@property (nonatomic, copy, nullable) NSString *uid;
/// 展示快照：最后已知 displayName
@property (nonatomic, copy, nullable) NSString *name;
/// 展示快照：头像 JSON 字符串
@property (nonatomic, copy, nullable) NSString *avatar;
/// 绝对到期时间(ms)
@property (nonatomic, assign) uint64_t expireTime;
/// 删除发生时间(ms)。客户端不依赖。
@property (nonatomic, assign) uint64_t deleteTime;
/// 服务端当前时间(ms)，倒计时锚点
@property (nonatomic, assign) uint64_t serverTimestamp;

@end

NS_ASSUME_NONNULL_END
