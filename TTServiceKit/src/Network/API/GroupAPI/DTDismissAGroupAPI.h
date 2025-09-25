//
//  DTDismissAGroupAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/28.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTDismissAGroupAPI : DTBaseAPI

- (void)sendRequestWithGroupId:(NSString *)groupId
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
