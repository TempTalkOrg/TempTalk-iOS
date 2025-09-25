//
//  DTGetGroupPersonalConfigAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/27.
//

#import "DTGetGroupPersonalConfigAPI.h"

@implementation DTGetGroupPersonalConfigAPI

- (NSString *)requestMethod{
    return @"GET";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@/members";
}

- (void)sendRequestWithWithGroupId:(NSString *)groupId
                           success:(void(^)(DTGroupMemberEntity *entity))success
                           failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(groupId)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:nil];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTGroupMemberEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTGroupMemberEntity class]
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
