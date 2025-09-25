//
//  DTRealSourceEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import "DTRealSourceEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSIncomingMessage.h"
#import "TSOutgoingMessage.h"

@implementation DTRealSourceEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (instancetype)initSourceWithTimestamp:(uint64_t)timestamp
                           sourceDevice:(uint32_t)sourceDevice
                                 source:(NSString *)source{
    if(self = [super init]){
        self.timestamp = timestamp;
        self.sourceDevice = sourceDevice;
        self.source = source;
    }
    return self;
}

- (instancetype)initSourceWithTimestamp:(uint64_t)timestamp
                           sourceDevice:(uint32_t)sourceDevice
                                 source:(NSString *)source
                             sequenceId:(uint64_t)sequenceId
                       notifySequenceId:(uint64_t)notifySequenceId{
    if(self = [super init]){
        self.timestamp = timestamp;
        self.sourceDevice = sourceDevice;
        self.source = source;
        self.sequenceId = sequenceId;
        self.notifySequenceId = notifySequenceId;
    }
    return self;
}

+ (nullable DTRealSourceEntity *)realSourceEntityWithProto:(nullable DSKProtoRealSource *)realSourceProto{
    if(!realSourceProto ||
       !(realSourceProto.hasSource &&  realSourceProto.hasTimestamp && realSourceProto.hasSourceDevice)){
        return nil;
    }
    DTRealSourceEntity *realSourceEntity = [[DTRealSourceEntity alloc] initSourceWithTimestamp:realSourceProto.timestamp
                                                                                  sourceDevice:realSourceProto.sourceDevice
                                                                                        source:realSourceProto.source];
    if(realSourceProto.hasServerTimestamp){
        realSourceEntity.serverTimestamp = realSourceProto.serverTimestamp;
    }
    return realSourceEntity;;
}

+ (nullable DSKProtoRealSource *)protoWithRealSourceEntity:(nullable DTRealSourceEntity *)realSourceEntity{
    if(!realSourceEntity){
        return nil;
    }
    
    DSKProtoRealSourceBuilder *builder = [DSKProtoRealSource builder];
    [builder setSource:realSourceEntity.source];
    [builder setSourceDevice:realSourceEntity.sourceDevice];
    [builder setTimestamp:realSourceEntity.timestamp];
    if(realSourceEntity.serverTimestamp){
        [builder setServerTimestamp:realSourceEntity.serverTimestamp];
    }
    return [builder buildAndReturnError:nil];
}
- (BOOL)isEqualToTargetSource:(DTRealSourceEntity *)sourceEntity {
    return [self.source isEqualToString:sourceEntity.source];
}

- (nullable TSMessage *)findMessageWithTransaction:(SDSAnyReadTransaction *)transaction {
    NSString *uniqueId = [TSMessage generateUniqueIdWithAuthorId:self.source deviceId:self.sourceDevice timestamp:self.timestamp];
    return [TSMessage anyFetchMessageWithUniqueId:uniqueId transaction:transaction];
}

- (NSString *)messageUniqid {
    return [TSMessage generateUniqueIdWithAuthorId:_source deviceId:_sourceDevice timestamp:_timestamp];
}

@end
