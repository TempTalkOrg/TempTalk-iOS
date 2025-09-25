//
//  DTCardOutgoingMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/18.
//

#import "TSOutgoingMessage.h"
#import "DTCardMessageEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTCardOutgoingMessage : TSOutgoingMessage

+ (instancetype)cardOutgoingMessageWithTimestamp:(uint64_t)timestamp
                                            card:(DTCardMessageEntity *)card
                                            body:(NSString *)body
                                       atPersons:(nullable NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                        inThread:(nullable TSThread *)thread
                                expiresInSeconds:(uint32_t)expiresInSeconds;

@end

NS_ASSUME_NONNULL_END
