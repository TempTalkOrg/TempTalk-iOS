//
//  DTGetSecretAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTGetSecretAPI.h"

static const NSUInteger kDTGetSecretAPIRetryCount = 3;

@interface DTGetSecretAPI ()

@property (nonatomic, assign) NSUInteger retryCount;

@end

@implementation DTGetSecretAPI

-(instancetype)init{
    if(self = [super init]){
        self.retryCount = kDTGetSecretAPIRetryCount;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/secrets/getSecret";
}

- (void)sendRequestWithSignature:(NSString *)signature
                           nonce:(NSString *)nonce
                         success:(void(^)(NSString *secretText))success
                         failure:(DTAPIFailureBlock)failure {
    
    if(!DTParamsUtils.validateString(signature) ||
       !DTParamsUtils.validateString(nonce)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:@{
        @"signature":signature,
        @"nonce":nonce,
    }];
    request.shouldHaveAuthorizationHeaders = NO;
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSString *secretText = entity.data[@"secretText"];
        if(!DTParamsUtils.validateString(secretText)){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            self.retryCount = kDTGetSecretAPIRetryCount;
            success(secretText);
        }
    } failure:^(NSError * _Nonnull error) {
        if(self.retryCount > 0){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendRequestWithSignature:signature
                                         nonce:nonce
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
