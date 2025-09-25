//
//  DTThumbUpApi.h
//  Wea
//
//  Created by hornet on 2022/7/28.
//  Copyright © 2022 Difft. All rights reserved.
//

//#import <TTServiceKit/TTServiceKit.h>
#import <TTServiceKit/DTBaseAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTThumbUpApi : DTBaseAPI
- (void)thumbUpWith:(NSString *)number
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure;
@end

NS_ASSUME_NONNULL_END
