//
//  DTGroupPinAPI.m
//  TTServiceKit
//
//  Created by Ethan on 2022/3/17.
//

#import "DTGroupPinAPI.h"
#import "DTPinnedMessageEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTGroupPinAPI

- (NSString *)requestUrl {
    
    return @"/v1/groups/%@/pin";
}

- (void)pinMessage:(NSString *)messageInfo
               gid:(NSString *)gid
    conversationId:(NSString *)source
        businessId:(nullable NSString *)businessId
           success:(RESTNetworkManagerSuccess)success
           failure:(RESTNetworkManagerFailure)failure {
    
    if (!DTParamsUtils.validateString(messageInfo) || !DTParamsUtils.validateString(gid)) {
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], gid];
    NSDictionary *parameters = @{
        @"conversationId" : source,
        @"content"        : messageInfo
    };
    if(DTParamsUtils.validateString(businessId)){
        NSMutableDictionary *newParams = parameters.mutableCopy;
        newParams[@"businessId"] = businessId;//cardUniqueId
        parameters = newParams.copy;
    }
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
    
    [self.networkManager makeRequest:request success:success failure:failure];    
}

- (void)unpinMessages:(NSArray <NSString *>*)pinnedMessageIds gid:(NSString *)gid success:(DTAPISuccessBlock)success failure:(DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateArray(pinnedMessageIds) || !DTParamsUtils.validateString(gid)) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], gid];
    NSDictionary *parameters = @{
        @"pins" : pinnedMessageIds
    };
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:parameters];
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        success(entity);
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

- (void)getPinnedMessagesWithGid:(NSString *)gid page:(NSInteger)page size:(NSInteger)size success:(void (^)(NSArray<DTPinnedMessageEntity *> *pinnedMessageEntities))success failure:(DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateString(gid) || page <=0 || size <= 0) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], gid];
    NSDictionary *parameters = @{
        @"page" : @(page),
        @"size" : @(size)
    };
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:parameters];
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        NSArray <DTPinnedMessageEntity *> *pinnedMessages = [MTLJSONAdapter modelsOfClass:[DTPinnedMessageEntity class] fromJSONArray:entity.data[@"groupPins"] error:&error];
        if (error) {
            failure(error);
        } else {
            [pinnedMessages enumerateObjectsUsingBlock:^(DTPinnedMessageEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.groupId = entity.data[@"gid"];
            }];
            success(pinnedMessages);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

@end
