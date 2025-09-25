//
//  DTInviteToGroupAPI.m
//  TTServiceKit
//
//  Created by Ethan on 2022/2/28.
//

#import "DTInviteToGroupAPI.h"

@implementation DTInviteToGroupEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTInviteToGroupAPI

- (NSString *)requestUrl {
    
    return @"/v1/groups/invitation/%@";
}

- (void)getInviteCodeWithGId:(NSString *)gId success:(nonnull void (^)(NSString * _Nonnull inviteCode))success failure:(nonnull DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateString(gId)) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], gId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:nil];
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        if (entity.data) success(entity.data[@"inviteCode"]);
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

- (void)getGroupInfoByInviteCode:(NSString *)inviteCode success:(void (^)(DTInviteToGroupEntity * _Nonnull))success failure:(DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateString(inviteCode)) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], [@"groupInfo/" stringByAppendingString:inviteCode]];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:@"GET"
                                        parameters:nil];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTInviteToGroupEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTInviteToGroupEntity class]
                                                        fromJSONDictionary:entity.data
                                                                     error:&error];
        if (error) {
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        } else {
            success(dataEntity);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

- (void)joinGroupByInviteCode:(NSString *)inviteCode success:(void(^)(DTInviteToGroupEntity *entity, NSInteger status))success failure:(DTAPIFailureBlock)failure {
    
    if (!DTParamsUtils.validateString(inviteCode)) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], [@"join/" stringByAppendingString:inviteCode]];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:@"PUT"
                                        parameters:nil];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTInviteToGroupEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTInviteToGroupEntity class]
                                                        fromJSONDictionary:entity.data
                                                                     error:&error];
        if (error) {
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        } else {
            success(dataEntity, entity.status);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

@end
