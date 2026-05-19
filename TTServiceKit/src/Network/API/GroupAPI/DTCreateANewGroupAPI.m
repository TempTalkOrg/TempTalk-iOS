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
    [self sendRequestWithName:name
                       avatar:avatar
                      numbers:numbers
              groupCryptoMode:0
                encryptedName:nil
              encryptedAvatar:nil
   groupMemberVerifyPublicKey:nil
               memberBindings:nil
                      success:success
                      failure:failure];
}

- (void)sendRequestWithName:(NSString *)name
                     avatar:(NSString *)avatar
                    numbers:(NSArray *)numbers
            groupCryptoMode:(NSInteger)groupCryptoMode
              encryptedName:(nullable NSString *)encryptedName
            encryptedAvatar:(nullable NSString *)encryptedAvatar
 groupMemberVerifyPublicKey:(nullable NSString *)groupMemberVerifyPublicKey
             memberBindings:(nullable NSArray *)memberBindings
                    success:(void(^)(DTCreateANewGroupDataEntity *entity))success
                    failure:(DTAPIFailureBlock)failure{

    if(!DTParamsUtils.validateString(name) ||
       ![numbers isKindOfClass:[NSArray class]] ||
       ![avatar isKindOfClass:[NSString class]]){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }

    NSString *safeName = (groupCryptoMode > 0) ? @"Encrypted Group" : name;
    NSMutableDictionary *parameters = @{
        @"name":safeName,
        @"numbers":numbers,
        @"avatar":avatar
    }.mutableCopy;

    if(groupCryptoMode > 0){
        parameters[@"groupCryptoMode"] = @(groupCryptoMode);
        if(encryptedName){
            parameters[@"encryptedName"] = encryptedName;
        }
        if(encryptedAvatar){
            parameters[@"encryptedAvatar"] = encryptedAvatar;
        }
        if(groupMemberVerifyPublicKey){
            parameters[@"groupMemberVerifyPublicKey"] = groupMemberVerifyPublicKey;
        }
        if(memberBindings){
            parameters[@"memberBindings"] = memberBindings;
        }
    }

    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:parameters.copy];
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
