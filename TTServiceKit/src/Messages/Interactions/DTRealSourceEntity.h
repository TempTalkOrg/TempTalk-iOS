//
//  DTRealSourceEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>
@class SDSAnyReadTransaction;
@class TSMessage;

NS_ASSUME_NONNULL_BEGIN

@class DSKProtoRealSource;

@interface DTRealSourceEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) uint32_t sourceDevice;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) uint64_t serverTimestamp;
@property (nonatomic, assign) uint64_t sequenceId;
@property (nonatomic, assign) uint64_t notifySequenceId;

- (instancetype)initSourceWithTimestamp:(uint64_t)timestamp
                           sourceDevice:(uint32_t)sourceDevice
                                 source:(NSString *)source;

- (instancetype)initSourceWithTimestamp:(uint64_t)timestamp
                           sourceDevice:(uint32_t)sourceDevice
                                 source:(NSString *)source
                             sequenceId:(uint64_t)sequenceId
                       notifySequenceId:(uint64_t)notifySequenceId;

+ (DTRealSourceEntity * _Nullable)realSourceEntityWithProto:(DSKProtoRealSource * _Nullable)realSourceProto;

+ (nullable DSKProtoRealSource *)protoWithRealSourceEntity:(nullable DTRealSourceEntity *)realSourceEntity;

- (BOOL)isEqualToTargetSource:(DTRealSourceEntity *)sourceEntity;

- (nullable TSMessage *)findMessageWithTransaction:(SDSAnyReadTransaction *)transaction;

- (NSString *)messageUniqid;
@end

NS_ASSUME_NONNULL_END
