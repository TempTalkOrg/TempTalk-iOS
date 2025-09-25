//
//  DTUpdateGroupInfoAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN


@interface DTUpdateGroupInfoAPI : DTBaseAPI

- (void)sendUpdateGroupWithGroupId:(NSString *)groupId
                        updateInfo:(NSDictionary *)updateInfo
                           success:(DTAPISuccessBlock)success
                           failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
