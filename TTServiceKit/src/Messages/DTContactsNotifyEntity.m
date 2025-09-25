//
//  DTContactsNotifyEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/10/25.
//

#import "DTContactsNotifyEntity.h"

@implementation DTContactActionEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    NSMutableDictionary *map = [NSDictionary mtl_identityPropertyMapWithModel:[self class]].mutableCopy;
    map[@"fullName"] = @"name";
    return map.copy;
}

+ (NSValueTransformer *)avatarJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *avatarString, BOOL *success, NSError *__autoreleasing *error) {
        NSData *jsonData = [avatarString dataUsingEncoding:NSUTF8StringEncoding];
        if(jsonData){
            NSDictionary *passthroughInfo = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:nil];
            return passthroughInfo;
        }
        return nil;
    } reverseBlock:^id(NSDictionary *avatarInfo, BOOL *success, NSError *__autoreleasing *error) {
        if(avatarInfo.count){
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:avatarInfo.copy options:NSJSONWritingPrettyPrinted error:&jsonError];
            NSString *jsonString;
            if(jsonData.length && !jsonError){
                jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
            return jsonString;
        }else{
            return nil;
        }
    }];
}

@end

@implementation DTContactsNotifyEntity

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError *__autoreleasing *)error{
    if(self = [super initWithDictionary:dictionaryValue error:error]){
        [self.members enumerateObjectsUsingBlock:^(DTContactActionEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj configWithFullName:obj.fullName phoneNumber:obj.number];
        }];
    }
    return self;
}

+ (NSValueTransformer *)membersJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTContactActionEntity class]];
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

@end
