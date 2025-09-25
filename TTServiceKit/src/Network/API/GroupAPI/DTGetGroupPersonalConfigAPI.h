//
//  DTGetGroupPersonalConfigAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/27.
//

#import "DTBaseAPI.h"
#import "DTGroupMemberEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTGetGroupPersonalConfigAPI : DTBaseAPI

- (void)sendRequestWithWithGroupId:(NSString *)groupId
                           success:(void(^)(DTGroupMemberEntity *entity))success
                           failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
