//
//  DTGetGroupInfoAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/2.
//

#import "DTGetGroupInfoAPI.h"

@implementation DTGetGroupInfoDataEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

+ (NSValueTransformer *)membersJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTGroupMemberEntity class]];
}

@end

@implementation DTGetGroupInfoAPI

- (NSString *)requestMethod{
    return @"GET";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@";
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                 targetVersion:(NSInteger)targetVersion
                       success:(void(^)(DTGetGroupInfoDataEntity *entity))success
                       failure:(DTAPIFailureBlock)failure{
    self.sameRequestFilter = ^BOOL{
        return targetVersion > 0 && self.version > 0 && targetVersion <= self.version;
    };
    
    [self sendRequestWithGroupId:groupId success:success failure:failure];
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                       success:(void (^)(DTGetGroupInfoDataEntity * _Nonnull))success
                       failure:(DTAPIFailureBlock)failure{
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:nil];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTGetGroupInfoDataEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTGetGroupInfoDataEntity class]
                                                        fromJSONDictionary:entity.data
                                                                     error:&error];
        if(error){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            self.version = dataEntity.version;
            success(dataEntity);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}


@end
