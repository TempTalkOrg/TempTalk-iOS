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

NS_ASSUME_NONNULL_BEGIN


@class DSKProtoDataMessage;

@interface DTRecallMessage : MTLModel

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, strong) DTRealSourceEntity *source;

@property (nonatomic, copy) NSString *body;

@property (nonatomic, copy) NSString *atPersons;

@property (nonatomic, readonly, nullable) NSArray <DTMention *> *mentions;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                           source:(DTRealSourceEntity *)source
                             body:(NSString *)body
                        atPersons:(NSString *)atPersons
                         mentions:(nullable NSArray <DTMention *> *)mentions;

+ (DTRecallMessage *)recallWithDataMessage:(DSKProtoDataMessage *)dataMessage;

- (BOOL)checkIntegrity;

- (void)clearOriginContent;

- (BOOL)isValidRecallMessageWithSource:(NSString *)source;

@end

NS_ASSUME_NONNULL_END
