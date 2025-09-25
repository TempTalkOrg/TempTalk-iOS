//
//  DTChangeYourSettingsInAGroupAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/13.
//

#import "DTChangeYourSettingsInAGroupAPI.h"
#import "TSAccountManager.h"

@implementation DTChangeYourSettingsInAGroupAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@/members/%@";
}

- (void)sendRequestWithGroupId:(NSString *)groupId
              notificationType:(NSNumber *)notificationType
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure{
    
    
    NSDictionary *parameters = @{
        @"notification":notificationType
    };
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId, [TSAccountManager localNumber]];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    [self sendRequest:request
              success:success
              failure:failure];
}

- (void)sendRequestWithGroupId:(NSString *)groupId
              notificationType:(NSNumber *)notificationType
                     useGlobal:(NSNumber *)useGlobal
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure {
    NSDictionary *parameters;
    if ([useGlobal intValue] == 1) {//打开了全局配置
        parameters = @{
            @"useGlobal":useGlobal
        };
    }else {//关闭了全局配置
        OWSAssertDebug(notificationType);//notificationType对象在关闭全局配置的情况下不能为空
        parameters = @{
            @"notification":notificationType,
            @"useGlobal":useGlobal
        };
    }
    
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId, [TSAccountManager localNumber]];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    [self sendRequest:request
              success:success
              failure:failure];
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                          role:(NSNumber *)role
                           uid:(NSString *)uid
                       success:(DTAPISuccessBlock)success
                       failure:(DTAPIFailureBlock)failure {
    OWSAssertDebug(role);
    NSDictionary *parameters = @{
        @"role":role
    };
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId, uid];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    [self sendRequest:request
              success:success
              failure:failure];
    
}

@end
