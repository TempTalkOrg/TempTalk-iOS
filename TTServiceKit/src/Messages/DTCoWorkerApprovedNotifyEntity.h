//
//  DTCoWorkerApprovedNotifyEntity.h
//  TTServiceKit
//
//  Created by Jaymin on 2024/9/8.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTCoWorkerApprovedNotifyEntity : MTLModel<MTLJSONSerializing>

/// 邀请人 id
@property (nonatomic, copy) NSString *invitorId;
/// 邀请人名称
@property (nonatomic, copy) NSString *invitorName;
/// 被邀请人 id
@property (nonatomic, copy) NSString *inviteeId;
/// 被邀请人名称
@property (nonatomic, copy) NSString *inviteeName;

@end

NS_ASSUME_NONNULL_END
