//
//  DTPlatformAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/25.
//

#import "DTPlatformAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTPlatformAPI

- (instancetype)init{
    if(self = [super init]){
        self.serverType = DTServerTypePlatform;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (void)sendRequestWithAppId:(NSString *)appId
                     success:(DTAPISuccessBlock)success
                     failure:(DTAPIFailureBlock)failure{
    
    [[DTTokenHelper sharedInstance] asyncFetchAuthTokenWithAppId:appId completion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if(error){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusInvalidToken, kDTAPITokenErrorDescription));
        }else{
            if(DTParamsUtils.validateString(token)){
                
                TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                                        method:[self requestMethod]
                                                    parameters:@{}];
                request.authToken = token;
                request.shouldHaveAuthorizationHeaders = NO;
                [self sendRequest:request
                          success:^(DTAPIMetaEntity * _Nonnull entity) {
                    
                    success(entity);
                } failure:^(NSError * _Nonnull error) {
                    if(error.code == DTAPIRequestResponseStatusInvalidToken){
                        DDLogInfo(@"%@ DTAPIRequestResponseStatusInvalidToken error ：%@", self.logTag, error);
                        [[DTTokenHelper sharedInstance] removeAuthTokenFromLocalCacheWithAppId:appId];
                    }
                    
                    failure(error);
                }];
                
            }else{
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusInvalidToken, kDTAPITokenErrorDescription));
            }
        }
    }];
    
    
}

@end
