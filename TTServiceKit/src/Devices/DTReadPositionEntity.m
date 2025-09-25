//
//  DTReadPositionEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/6/25.
//

#import "DTReadPositionEntity.h"
#import "TSGroupThread.h"
#import "DTParamsBaseUtils.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTReadPositionEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}


- (instancetype)initWithGroupId:(nullable NSData *)groupId
                         readAt:(uint64_t)readAt
                  maxServerTime:(uint64_t)maxServerTime
               notifySequenceId:(uint64_t)notifySequenceId
                  maxSequenceId:(uint64_t)maxSequenceId {
    if(self = [super init]){
        self.groupId = groupId;
        self.readAt = readAt;
        self.maxServerTime = maxServerTime;
        self.maxNotifySequenceId = notifySequenceId;
        self.maxSequenceId = maxSequenceId;
    }
    return self;
}

+ (NSValueTransformer *)groupIdJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *serverGId, BOOL *success, NSError *__autoreleasing *error) {
        if([serverGId isKindOfClass:[NSString class]]){
            return [TSGroupThread transformToLocalGroupIdWithServerGroupId:serverGId];
        }else{
            return nil;
        }
    } reverseBlock:^id(NSData *groupId, BOOL *success, NSError *__autoreleasing *error) {
        if([groupId isKindOfClass:[NSData class]]){
            return [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupId];
        }else{
            return nil;
        }
    }];
}

+ (DTReadPositionEntity *)readPostionEntityWithProto:(DSKProtoReadPosition *)readPositionProto{
    
    DTReadPositionEntity *readPositionEntity = [[DTReadPositionEntity alloc] initWithGroupId:readPositionProto.groupID
                                                                                      readAt:readPositionProto.readAt
                                                                               maxServerTime:readPositionProto.maxServerTime
                                                                            notifySequenceId:readPositionProto.maxNotifySequenceID
                                                                               maxSequenceId:readPositionProto.maxSequenceID];
    return readPositionEntity;
    
}

+ (nullable DSKProtoReadPosition *)readPostionProtoWithEntity:(nullable DTReadPositionEntity *)readPositionEntity{
    DSKProtoReadPositionBuilder *readPositionBuilder = [DSKProtoReadPosition builder];
    [readPositionBuilder setGroupID:readPositionEntity.groupId];
    [readPositionBuilder setMaxSequenceID:readPositionEntity.maxSequenceId];
    [readPositionBuilder setMaxNotifySequenceID:readPositionEntity.maxNotifySequenceId];
    readPositionBuilder.readAt = readPositionEntity.readAt;
    readPositionBuilder.maxServerTime = readPositionEntity.maxServerTime;

    return [readPositionBuilder buildAndReturnError:nil];
}

- (NSString *)description {
    NSString *groupIdString = @"nil";
    if (_groupId && _groupId.length) {
        groupIdString = [TSGroupThread transformToServerGroupIdWithLocalGroupId:_groupId];
    }
    
    return [NSString stringWithFormat:@"maxServerTime: %llu, readAt: %llu, maxNotifySequenceId: %llu, maxSequenceId: %llu, groupId: %@", self.maxServerTime, self.readAt, self.maxNotifySequenceId, self.maxSequenceId, groupIdString];
}

@end
