//
//  DTRemoveMembersOfAGroupAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTRemoveMembersOfAGroupAPI : DTBaseAPI

- (void)sendRequestWithWithGroupId:(NSString *)groupId
                           numbers:(NSArray *)numbers
                           success:(DTAPISuccessBlock)success
                           failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
