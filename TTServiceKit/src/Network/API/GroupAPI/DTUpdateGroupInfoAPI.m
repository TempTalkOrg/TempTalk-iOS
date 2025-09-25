//
//  DTUpdateGroupInfoAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import "DTUpdateGroupInfoAPI.h"

@implementation DTUpdateGroupInfoAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@";
}

- (void)sendUpdateGroupWithGroupId:(NSString *)groupId
                        updateInfo:(NSDictionary *)updateInfo
                           success:(DTAPISuccessBlock)success
                           failure:(DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateString(groupId) || !DTParamsUtils.validateDictionary(updateInfo) || (DTParamsUtils.validateDictionary(updateInfo) && updateInfo.allKeys.count == 0)) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:updateInfo];
    [self sendRequest:request
              success:success
              failure:failure];
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                          name:(NSString *)name
                         owner:(NSString *)owner
                        avatar:(NSString *)avatar
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(groupId) ||
       (!DTParamsUtils.validateString(name) && !DTParamsUtils.validateString(owner) && ![avatar isKindOfClass:[NSString class]])){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSMutableDictionary *parameters = @{}.mutableCopy;
    if(DTParamsUtils.validateString(name)){
        parameters[@"name"] = name;
    }
    if(DTParamsUtils.validateString(owner)){
        parameters[@"owner"] = owner;
    }
    if(DTParamsUtils.validateString(avatar)){
        parameters[@"avatar"] = avatar;
    }
    
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
    [self sendRequest:request
              success:success
              failure:failure];
}

- (void)sendRequestForChangeGroupOwerWithGroupId:(NSString *)groupId
                                           owner:(NSString *)owner
                                         success:(DTAPISuccessBlock)success
                                         failure:(DTAPIFailureBlock)failure {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if(DTParamsUtils.validateString(owner)){
        parameters[@"owner"] = owner;
    }else {
        return;
    }
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
    [self sendRequest:request
              success:success
              failure:failure];
}


- (void)sendRequestForChangeInvitationRuleWithGroupId:(NSString *)groupId
                                       invitationRule:(NSNumber *)invitationRule
                                              success:(DTAPISuccessBlock)success
                                              failure:(DTAPIFailureBlock)failure {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if (DTParamsUtils.validateNumber(invitationRule)) {
        parameters[@"invitationRule"] = invitationRule;
    } else {
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
    [self sendRequest:request
              success:success
              failure:failure];
}

- (void)requestForUpdateArchiveMessageWithGroupId:(NSString *)groupId
                                         timeInterval:(NSInteger) messageExpiry
                                              success:(DTAPISuccessBlock)success
                                              failure:(DTAPIFailureBlock)failure {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (messageExpiry > 0) {
        parameters[@"messageExpiry"] = @(messageExpiry);
    }
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
    [self sendRequest:request
              success:success
              failure:failure];
}

@end
