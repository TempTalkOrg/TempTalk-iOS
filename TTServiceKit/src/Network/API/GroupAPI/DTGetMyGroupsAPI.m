//
//  DTGetMyGroupsAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/28.
//

#import "DTGetMyGroupsAPI.h"

@implementation DTGetMyGroupsAPI

- (NSString *)requestMethod{
    return @"GET";
}

- (NSString *)requestUrl{
    return @"/v1/groups";
}

- (void)sendRequestWithSuccess:(void (^)(NSArray<DTGroupBaseInfoEntity *> * _Nonnull))success
                       failure:(DTAPIFailureBlock)failure{
    
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                            method:[self requestMethod]
                                        parameters:nil];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        
        NSArray *groupsData = entity.data[@"groups"];
        if(!DTParamsUtils.validateArray(groupsData)){
            success(@[]);
            return;;
        }
        NSError *error;
        NSArray *groups = [MTLJSONAdapter modelsOfClass:[DTGroupBaseInfoEntity class] fromJSONArray:groupsData error:&error];
        if(error){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            success(groups);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

@end
