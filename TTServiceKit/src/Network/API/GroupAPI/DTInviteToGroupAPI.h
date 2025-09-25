//
//  DTInviteToGroupAPI.h
//  TTServiceKit
//
//  Created by Ethan on 2022/2/28.
//

#import "DTBaseAPI.h"
#import "DTGetGroupInfoAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTInviteToGroupEntity : DTGetGroupInfoDataEntity

@property (nonatomic, assign) NSInteger membersCount;
@property (nonatomic, copy) NSString *gid;

@end

@interface DTInviteToGroupAPI : DTBaseAPI

- (void)getInviteCodeWithGId:(NSString *)gId success:(void(^)(NSString *inviteCode))success failure:(DTAPIFailureBlock)failure;;

- (void)getGroupInfoByInviteCode:(NSString *)inviteCode success:(void(^)(DTInviteToGroupEntity *entity))success failure:(DTAPIFailureBlock)failure;

- (void)joinGroupByInviteCode:(NSString *)inviteCode success:(void(^)(DTInviteToGroupEntity *entity, NSInteger status))success failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
