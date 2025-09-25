//
//  DTBaseAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import "DTBaseAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const DTServerErrorDomain = @"DTServerErrorDomain";
NSString *const kDTAPIRequestHttpErrorDescription = @"network error";
NSString *const kDTAPIDataErrorDescription = @"data error！";
NSString *const kDTAPITokenErrorDescription = @"token error！";
NSString *const kDTAPIParamsErrorDescription = @"params error！";
NSString *const kDTAPIFrequencyLimitDescription = @"frequency limit!";

NSString *const DTLocalRequestErrorDomain = @"DTLocalRequestErrorDomain";
NSString *const kDTAPIRequestURLErrorDescription = @"request error!";

@implementation DTAPIMetaEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@interface DTBaseAPI ()

@property (atomic, copy) NSString *currentReqUrl;

@end


@implementation DTBaseAPI

- (instancetype)init{
    if(self = [super init]){
        self.serverType = DTServerTypeChat;
    }
    return self;
}


NSError *DTErrorWithCodeDescription(DTAPIRequestResponseStatus code, NSString *description){
    
    if(!DTParamsUtils.validateString(description)){
        description = @"";
    }
    
    return [NSError errorWithDomain:DTServerErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

NSError *DTRequestErrorWithCodeDescription(DTAPIRequestStatus code, NSString *description){
    
    if(!DTParamsUtils.validateString(description)){
        description = @"";
    }
    
    return [NSError errorWithDomain:DTServerErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

- (void)sendRequest:(TSRequest *)request
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure{
    
    void (^requestBlock)(void) = ^{
        self.currentReqUrl = request.URL.absoluteString;
        
        if(self.isSyncRequest){
            [self sendSyncRequest:request success:success failure:failure];
        }else{
            [self sendRequest:request completionQueue:dispatch_get_main_queue() success:success failure:failure];
        }
    };
    
    if(self.frequencyLimitEnable &&
       ([request.URL.absoluteString isEqualToString:self.currentReqUrl] &&
       (self.sameRequestFilter && self.sameRequestFilter()))){

        OWSLogWarn(@"URL frequency limit:%@", self.currentReqUrl);
        
        if(failure){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusFrequencyLimit, kDTAPIFrequencyLimitDescription));
        }
    }else{
    
        requestBlock();
    }
    
}

- (void)sendSyncRequest:(TSRequest *)request
                success:(DTAPISuccessBlock)success
                failure:(DTAPIFailureBlock)failure{
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self sendRequest:request completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        success(entity);
        dispatch_semaphore_signal(semaphore);
    } failure:^(NSError * _Nonnull error) {
        failure(error);
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)sendRequest:(TSRequest *)request
    completionQueue:(dispatch_queue_t)completionQueue
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure {
    
    @weakify(self);
    void(^successBlock)(id<HTTPResponse>  _Nonnull response) = ^(id<HTTPResponse>  _Nonnull response) {
        @strongify(self);
        
        NSDictionary *responseObject = response.responseBodyJson;
        
        if([responseObject isKindOfClass:[NSDictionary class]]){
            if (request.useResponseBodyJson) {
                success((DTAPIMetaEntity *)responseObject);
            } else {
                NSError *error;
                DTAPIMetaEntity *entity = [MTLJSONAdapter modelOfClass:[DTAPIMetaEntity class]
                                                    fromJSONDictionary:responseObject
                                                                 error:&error];
                if(error){
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
                }else{
                    if(entity.status == DTAPIRequestResponseStatusOK){
                        success(entity);
                    }else{
                        failure(DTErrorWithCodeDescription(entity.status, entity.reason));
                    }
                }
            }
        }else{
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }
        
        self.currentReqUrl = nil;
        
    };
    
    void(^failureBlock)(OWSHTTPErrorWrapper * _Nonnull error) = ^(OWSHTTPErrorWrapper * _Nonnull error) {
        @strongify(self);
        NSError *errorWapper = error.asNSError;
          // 切换域名在底层处理过了
        OWSLogError(@"request errorcode: %@, data: %@.", errorWapper.httpStatusCode, errorWapper.httpResponseJson);
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusHttpError, Localized(@"ERROR_DESCRIPTION_REQUEST_FAILED", @"")));
        self.currentReqUrl = nil;
    };
    
    NetworkManager *networkManager = nil;
    if(![SSKEnvironment hasShared] || !self.networkManager){
        networkManager = [NetworkManager sharedInstance];
    } else {
        networkManager = self.networkManager;
    }
    request.serverType = _serverType;
    [networkManager makeRequest:request
                completionQueue:completionQueue
                        success:successBlock
                        failure:failureBlock];
}

@end
