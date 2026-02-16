//
//  DTCltlogAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/22.
//

#import "DTCltlogAPI.h"
#import "TSAccountManager.h"

@implementation DTCltlogAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/cltlog";
}

- (void)sendRequestWithEventName:(NSString *)eventName
                          params:(NSDictionary *)params
                         success:(DTAPISuccessBlock)success
                         failure:(DTAPIFailureBlock)failure{
    
    // TODO: 梳理出真正需要上报的时机再加回 && failure 回调
//    if (!TSAccountManager.sharedInstance.isRegisteredAndReady) {
//        return;
//    }
    
    if(!DTParamsUtils.validateDictionary(params)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSMutableDictionary *parameters = params.mutableCopy;
    parameters[@"eventName"] = eventName;
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
//    request.shouldHaveAuthorizationHeaders = NO;
                           
    [self sendRequest:request success:success failure:failure];
    
}

@end
