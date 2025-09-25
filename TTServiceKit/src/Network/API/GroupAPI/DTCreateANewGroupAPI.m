//
//  DTCreateANewGroupAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import "DTCreateANewGroupAPI.h"

@implementation DTCreateANewGroupDataEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end

@implementation DTCreateANewGroupAPI

- (NSString *)requestMethod{
    return @"PUT";
}

- (NSString *)requestUrl{
    return @"/v1/groups";
}


- (void)sendRequestWithName:(NSString *)name
                     avatar:(nonnull NSString *)avatar
                    numbers:(nonnull NSArray *)numbers
                    success:(nonnull void (^)(DTCreateANewGroupDataEntity * _Nonnull))success
                    failure:(nonnull DTAPIFailureBlock)failure{
    
    if(!DTParamsUtils.validateString(name) ||
       ![numbers isKindOfClass:[NSArray class]] ||
       ![avatar isKindOfClass:[NSString class]]){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
//    __block NSTimeInterval messageExpiry = -1;
//    [DTDisappearanceTimeIntervalConfig fetchConfigWithCompletion:^(DTDisappearanceTimeIntervalEntity * _Nonnull entity, NSError * _Nonnull error) {
//        messageExpiry = entity.messageDefault.unsignedIntValue;
//    }];
    
    NSDictionary *parameters = @{
        @"name":name,
        @"numbers":numbers,
//        @"messageExpiry":@(messageExpiry),
        @"avatar":avatar
    };
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters];
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTCreateANewGroupDataEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTCreateANewGroupDataEntity class]
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
