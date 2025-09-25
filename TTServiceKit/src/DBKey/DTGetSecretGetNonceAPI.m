//
//  DTGetSecretGetNonceAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTGetSecretGetNonceAPI.h"

static const NSUInteger kGetSecretGetNonceAPIRetryCount = 3;

@interface DTGetSecretGetNonceAPI ()

@property (nonatomic, assign) NSUInteger retryCount;

@end

@implementation DTGetSecretGetNonceAPI

-(instancetype)init{
    if(self = [super init]){
        self.retryCount = kGetSecretGetNonceAPIRetryCount;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/secrets/getSecretNonce";
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
    request.shouldHaveAuthorizationHeaders = NO;
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSString *nonce = entity.data[@"nonce"];
        if(!DTParamsUtils.validateString(nonce)){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            self.retryCount = kGetSecretGetNonceAPIRetryCount;
            success(nonce);
        }
    } failure:^(NSError * _Nonnull error) {
        if(self.retryCount > 0){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendRequestWithPK:pk
                                success:success
                                failure:failure];
            });
            self.retryCount --;
        }else{
            failure(error);
        }
    }];
    
    
}

@end
