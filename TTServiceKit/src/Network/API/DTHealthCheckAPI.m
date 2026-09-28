//
//  DTHealthCheckAPI.m
//  TTServiceKit
//

#import "DTHealthCheckAPI.h"

@implementation DTHealthCheckAPI

- (NSString *)requestMethod {
    return @"GET";
}

- (NSString *)requestUrl {
    return @"/v1/health";
}

- (void)sendRequestWithSuccess:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure {

    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                            method:[self requestMethod]
                                        parameters:nil];
    request.shouldHaveAuthorizationHeaders = NO;

    [self sendRequest:request success:success failure:failure];
}

@end
