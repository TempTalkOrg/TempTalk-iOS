//
//  DTGetMyGroupsAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/28.
//

#import "DTBaseAPI.h"
#import "DTGroupBaseInfoEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTGetMyGroupsAPI : DTBaseAPI

- (void)sendRequestWithSuccess:(void (^)(NSArray<DTGroupBaseInfoEntity *> *groups))success
                       failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
