//
//  DTChangeYourSettingsInAGroupAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/13.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTChangeYourSettingsInAGroupAPI : DTBaseAPI

- (void)sendRequestWithGroupId:(NSString *)groupId
              notificationType:(NSNumber *)notificationType
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure;

- (void)sendRequestWithGroupId:(NSString *)groupId
              notificationType:(NSNumber * _Nullable )notificationType
                     useGlobal:(NSNumber *)useGlobal
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure;

/// 发送改变群组的配置信息
/// @param groupId 群组id
/// @param role 用户角色
/// @param uid 用户id
/// @param success 成功回调
/// @param failure 失败回调
- (void)sendRequestWithGroupId:(NSString *)groupId
                          role:(NSNumber *)role
                           uid:(NSString *)uid
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure;
@end

NS_ASSUME_NONNULL_END
