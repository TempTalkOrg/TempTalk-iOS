//
//  DTGroupMessageAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/18.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

/*
 {
   "needsSync": false,
   "sequenceId": 1,
   "systemShowTimestamp": 1647485744622
 }
 */

@interface DTGroupMessageDataEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) BOOL needsSync;
@property (nonatomic, assign) NSInteger sequenceId;
@property (nonatomic, assign) NSTimeInterval systemShowTimestamp;

@end

@interface DTGroupMessageAPI : DTBaseAPI

- (void)sendRequestWithGid:(NSString *)gid
                parameters:(NSDictionary *)parameters
                   success:(void(^)(DTGroupMessageDataEntity *entity))success
                   failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
