//
//  DTFileAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/11.
//

#import "DTFileAPI.h"
#import "TSAccountManager.h"
#import "DTFileServiceContext.h"

@implementation DTFileDataEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (UInt64)authorizeIdToInt{
    return [self.authorizeId longLongValue];
}

@end

@interface DTFileAPI ()

@property (nonatomic, assign) NSUInteger retryCount;

@end

@implementation DTFileAPI

-(instancetype)init{
    if(self = [super init]){
        self.retryCount = 3;
        self.serverType = DTServerTypeFileSharing;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (void)sendRequestWithParams:(NSDictionary *)params
                      success:(void (^)(DTFileDataEntity *))success
                       failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateDictionary(params)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSMutableDictionary *newParams = @{}.mutableCopy;
    [newParams addEntriesFromDictionary:params];
    
    [[DTFileServiceContext sharedInstance] fetchAuthTokenWithSuccess:^(NSString * _Nonnull token) {
        if(DTParamsUtils.validateString(token)){
            newParams[@"token"] = token;
            
            TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                                    method:[self requestMethod]
                                                parameters:newParams.copy];
            request.shouldHaveAuthorizationHeaders = NO;
            [self sendRequest:request
                      success:^(DTAPIMetaEntity * _Nonnull entity) {
                
                if(!DTParamsUtils.validateDictionary(entity.data)){
                    success(nil);
                    return;
                }
                
                NSError *error;
                DTFileDataEntity *fileDataEntity = [MTLJSONAdapter modelOfClass:[DTFileDataEntity class] fromJSONDictionary:entity.data error:&error];
                if(error){
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
                }else{
                    success(fileDataEntity);
                }
            } failure:^(NSError * _Nonnull error) {
                if(error.code == DTAPIRequestResponseStatusInvalidToken){
                    DDLogInfo(@"%@ DTAPIRequestResponseStatusInvalidToken error ：%@", self.logTag, error);
                    [DTFileServiceContext sharedInstance].authToken = @"";
                    if(self.retryCount > 0){
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self sendRequestWithParams:params
                                                success:success
                                                failure:failure];
                        });
                        self.retryCount --;
                    }else{
                        failure(error);
                    }
                    return;
                }
                
                failure(error);
            }];
            
        }else{
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }
    } failure:^(NSError * _Nullable error) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
    }];
    
}

@end
