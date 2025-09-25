//
//  DTUploadSecretAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTUploadSecretAPI.h"

@implementation DTUploadSecretAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/secrets/upload";
}

- (void)sendRequestWithSecretText:(NSString *)secretText
                        signature:(NSString *)signature
                            nonce:(NSString *)nonce
                       deviceInfo:(NSString *)deviceInfo
                          success:(void(^)(void))success
                          failure:(DTAPIFailureBlock)failure {
    
    if(!DTParamsUtils.validateString(secretText) ||
       !DTParamsUtils.validateString(signature) ||
       !DTParamsUtils.validateString(nonce) ||
       ![deviceInfo isKindOfClass:[NSString class]]){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:@{
        @"secretText":secretText,
        @"signature":signature,
        @"nonce":nonce,
        @"deviceInfo":deviceInfo
    }];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        success();
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
    
    
}

@end
