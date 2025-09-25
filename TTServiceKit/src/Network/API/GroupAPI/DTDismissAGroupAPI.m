//
//  DTDismissAGroupAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/28.
//

#import "DTDismissAGroupAPI.h"

@implementation DTDismissAGroupAPI

- (NSString *)requestMethod{
    return @"DELETE";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@";
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(groupId)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:nil];
    [self sendRequest:request success:success failure:failure];
}

@end
