//
//  DTFetchThreadConfigAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/3/31.
//

#import "DTFetchThreadConfigAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTThreadConfigEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"source"] = @"operator";
    map[@"sourceDeviceId"] = @"operatorDeviceId";
    return map.copy;
}

@end

@implementation DTFetchThreadConfigAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/conversationconfig/share";
}

- (void)fetchThreadConfigRequestWithNumber:(NSString *)number
                                   success:(void(^)(DTThreadConfigEntity * __nullable entity))success
                                   failure:(DTAPIFailureBlock)failure {
    
    if(!DTParamsUtils.validateString(number)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSDictionary *parameters = @{
        @"conversations":@[number]
    };
    
    [[DTTokenHelper sharedInstance] asyncFetchGlobalAuthTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
            NSString *path = [self requestUrl];
            TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                                    method:[self requestMethod]
                                                parameters:parameters];
            request.authToken = token;
            [self sendRequest:request
                      success:^(DTAPIMetaEntity * _Nonnull entity) {
                
                NSArray *conversations = entity.data[@"conversations"];
                if(!DTParamsUtils.validateArray(conversations)){
                    success(nil);
                    return;
                }
                
                NSError *error;
                DTThreadConfigEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTThreadConfigEntity class]
                                                             fromJSONDictionary:conversations.firstObject
                                                                          error:&error];
                if(error || !dataEntity){
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
                }else{
                    success(dataEntity);
                }
            } failure:^(NSError * _Nonnull error) {
                failure(error);
            }];
        }];
    
}


- (void)fetchThreadConfigRequestWithConversationIds:(NSArray<NSString *> *)conversationIds
                                            success:(void(^)(NSArray<DTThreadConfigEntity *> * __nullable entities))success
                                            failure:(DTAPIFailureBlock)failure {
    
    if(!DTParamsUtils.validateArray(conversationIds)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSDictionary *parameters = @{
        @"conversations":conversationIds
    };
    
    [[DTTokenHelper sharedInstance] asyncFetchGlobalAuthTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
            NSString *path = [self requestUrl];
            TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                                    method:[self requestMethod]
                                                parameters:parameters];
            request.authToken = token;
            [self sendRequest:request
                      success:^(DTAPIMetaEntity * _Nonnull entity) {
                
                NSArray *conversations = entity.data[@"conversations"];
                if(!DTParamsUtils.validateArray(conversations)){
                    success(nil);
                    return;
                }
                
                NSError *error;
                NSArray<DTThreadConfigEntity *> * entities = [MTLJSONAdapter modelsOfClass:[DTThreadConfigEntity class] fromJSONArray:conversations error:&error];
                if(error || !DTParamsUtils.validateArray(entities)){
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
                }else{
                    success(entities);
                }
            } failure:^(NSError * _Nonnull error) {
                failure(error);
            }];
        }];
    
}

@end
