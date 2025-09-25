//
//  DTUploadSecretGetNonceAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTUploadSecretGetNonceAPI.h"

@implementation DTUploadSecretGetNonceAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/secrets/uploadSecretNonce";
}

- (void)sendRequestWithPK:(NSString *)pk
                  success:(void(^)(NSString *nonce))success
                  failure:(DTAPIFailureBlock)failure {
    
    if(!DTParamsUtils.validateString(pk)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:@{@"userPk":pk}];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSString *nonce = entity.data[@"nonce"];
        if(!DTParamsUtils.validateString(nonce)){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            success(nonce);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
    
    
}

@end
