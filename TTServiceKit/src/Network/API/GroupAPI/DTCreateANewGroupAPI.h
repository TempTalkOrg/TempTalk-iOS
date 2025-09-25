//
//  DTCreateANewGroupAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTCreateANewGroupDataEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *gid;

@end

@interface DTCreateANewGroupAPI : DTBaseAPI

- (void)sendRequestWithName:(NSString *)name
                     avatar:(NSString *)avatar
                    numbers:(NSArray *)numbers
                    success:(void(^)(DTCreateANewGroupDataEntity *entity))success
                    failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
