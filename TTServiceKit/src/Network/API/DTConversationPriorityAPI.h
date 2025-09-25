//
//  DTConversationPriorityAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/8/11.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTConversationPriorityAPI : DTBaseAPI


- (void)sendRequestWithParams:(nullable NSDictionary *)params
                      success:(DTAPISuccessBlock)success
                      failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
