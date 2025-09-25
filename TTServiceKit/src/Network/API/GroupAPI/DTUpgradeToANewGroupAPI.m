//
//  DTCreateANewGroupAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import "DTUpgradeToANewGroupAPI.h"

@implementation DTUpgradeToANewGroupDataEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@implementation DTUpgradeToANewGroupAPI

- (NSString *)requestMethod{
    return @"PUT";
}

- (NSString *)requestUrl{
    return @"/v1/groups/%@";
}

- (void)sendRequestWithGroupId:(NSString *)groupId
                          name:(NSString *)name
                        avatar:(NSString *)avatar
                       numbers:(NSArray *)numbers
                       success:(void(^)(DTUpgradeToANewGroupDataEntity *entity))success
                       failure:(DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(groupId) ||
       !DTParamsUtils.validateString(name) ||
       ![numbers isKindOfClass:[NSArray class]] ||
       ![avatar isKindOfClass:[NSString class]]){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    //TODO: messageExpiry
    __block NSTimeInterval messageExpiry = -1;
//    [DTDisappearanceTimeIntervalConfig fetchConfigWithCompletion:^(DTDisappearanceTimeIntervalEntity * _Nonnull entity, NSError * _Nonnull error) {
//        messageExpiry = entity.messageDefault.unsignedIntValue;
//    }];
    
    NSDictionary *parameters = @{
        @"name":name,
        @"numbers":numbers,
        @"messageExpiry":@(messageExpiry),
        @"avatar":avatar
    };
    
    NSString *path = [NSString stringWithFormat:[self requestUrl], groupId];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTUpgradeToANewGroupDataEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTUpgradeToANewGroupDataEntity class]
                                                        fromJSONDictionary:entity.data
                                                                     error:&error];
        if(error || !dataEntity.gid.length){
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }else{
            success(dataEntity);
        }
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
    
}

@end
