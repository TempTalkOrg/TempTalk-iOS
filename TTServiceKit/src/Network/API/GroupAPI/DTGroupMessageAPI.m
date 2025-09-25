//
//  DTGroupMessageAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/18.
//

#import "DTGroupMessageAPI.h"

@implementation DTGroupMessageDataEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@implementation DTGroupMessageAPI

- (NSString *)requestMethod{
    return @"PUT";
}

- (NSString *)requestUrl{
    return @"/v1/messages/group/%@";
}


- (void)sendRequestWithGid:(NSString *)gid
                parameters:(NSDictionary *)parameters
                   success:(void (^)(DTGroupMessageDataEntity * _Nonnull))success
                   failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(gid)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], gid];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTGroupMessageDataEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTGroupMessageDataEntity class]
                                                         fromJSONDictionary:entity.data
                                                                      error:&error];
        if(error){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            success(dataEntity);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
    
}

@end
