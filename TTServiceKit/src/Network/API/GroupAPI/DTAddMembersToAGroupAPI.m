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
    
    if(!DTParamsUtils.validateString(groupId) ||
       !DTParamsUtils.validateArray(numbers)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSDictionary *parameters = @{
        @"numbers":numbers
    };
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    [self sendRequest:request
              success:success
              failure:failure];
}

@end
