//
//  DTReadPositionEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/6/25.
//

#import <Mantle/Mantle.h>

@class DSKProtoReadPosition;

NS_ASSUME_NONNULL_BEGIN

@interface DTReadPositionEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong, nullable) NSData *groupId;

@property (nonatomic, assign) uint64_t readAt;

@property (nonatomic, assign) uint64_t maxServerTime;
// Max(max_read_notify_sequence_id, max_outgoing_notify_sequence_id)
@property (nonatomic, assign) uint64_t maxNotifySequenceId;
// 已读位置最新消息 sequence id
@property (nonatomic, assign) uint64_t maxSequenceId;

- (instancetype)initWithGroupId:(nullable NSData *)groupId
                         readAt:(uint64_t)readAt
                  maxServerTime:(uint64_t)maxServerTime
               notifySequenceId:(uint64_t)notifySequenceId
                  maxSequenceId:(uint64_t)maxSequenceId;

+ (DTReadPositionEntity *)readPostionEntityWithProto:(DSKProtoReadPosition *)readPositionProto;
+ (nullable DSKProtoReadPosition *)readPostionProtoWithEntity:(nullable DTReadPositionEntity *)readPositionEntity;

@end

NS_ASSUME_NONNULL_END
