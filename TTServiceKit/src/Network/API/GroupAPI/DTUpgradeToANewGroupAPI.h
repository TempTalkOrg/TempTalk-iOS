//
//  DTCreateANewGroupAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTUpgradeToANewGroupDataEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *gid;

@end

@interface DTUpgradeToANewGroupAPI : DTBaseAPI

- (void)sendRequestWithGroupId:(NSString *)groupId
                          name:(NSString *)name
                        avatar:(NSString *)avatar
                       numbers:(NSArray *)numbers
                       success:(void(^)(DTUpgradeToANewGroupDataEntity *entity))success
                       failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
