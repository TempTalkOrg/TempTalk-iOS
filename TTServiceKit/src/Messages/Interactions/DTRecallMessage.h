//
//  DTRecallMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import <Foundation/Foundation.h>
#import "DTRealSourceEntity.h"
#import <Mantle/Mantle.h>
#import "MTLModel.h"
@class DTMention;
@class SDSAnyWriteTransaction;

NS_ASSUME_NONNULL_BEGIN


@class DSKProtoDataMessage;

@interface DTRecallMessage : MTLModel

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, strong) DTRealSourceEntity *source;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                           source:(DTRealSourceEntity *)source;

+ (DTRecallMessage *)recallWithDataMessage:(DSKProtoDataMessage *)dataMessage;

- (BOOL)checkIntegrity;

- (BOOL)isValidRecallMessageWithSource:(NSString *)source;

- (void)insertRecordWithSource:(NSString *)source
                  sourceDevice:(uint32_t)sourceDevice
                     timestamp:(uint64_t)timestamp
                   transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
