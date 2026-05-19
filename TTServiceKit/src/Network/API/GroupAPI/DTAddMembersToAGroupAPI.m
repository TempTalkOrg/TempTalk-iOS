//
//  DTAddMembersToAGroupAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import "DTAddMembersToAGroupAPI.h"

@implementation DTAddMembersToAGroupAPI

- (NSString *)requestMethod{
    if(self.transformToRemove){
        return @"DELETE";
    }
    return @"PUT";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@/members";
}

- (void)sendRequestWithWithGroupId:(NSString *)groupId
                           numbers:(NSArray *)numbers
                           success:(DTAPISuccessBlock)success
                           failure:(DTAPIFailureBlock)failure{
    [self sendRequestWithWithGroupId:groupId
                             numbers:numbers
                      memberBindings:nil
                             success:success
                             failure:failure];
}

- (void)sendRequestWithWithGroupId:(NSString *)groupId
                           numbers:(NSArray *)numbers
                    memberBindings:(nullable NSArray *)memberBindings
                           success:(DTAPISuccessBlock)success
                           failure:(DTAPIFailureBlock)failure{

    if(!DTParamsUtils.validateString(groupId) ||
       !DTParamsUtils.validateArray(numbers)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }

    NSMutableDictionary *parameters = @{
        @"numbers":numbers
    }.mutableCopy;

    if(memberBindings){
        parameters[@"memberBindings"] = memberBindings;
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
