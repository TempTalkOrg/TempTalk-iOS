//
//  DTRecallOutgoingMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import "TSOutgoingMessage.h"
#import "DTRecallMessage.h"
#import "DTApnsMessageBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTRecallOutgoingMessage : TSOutgoingMessage

@property (nonatomic, strong) TSOutgoingMessage *originMessage;

+ (instancetype)recallOutgoingMessageWithTimestamp:(uint64_t)timestamp
                                            recall:(DTRecallMessage *)recall
                                          inThread:(nullable TSThread *)thread
                                  expiresInSeconds:(uint32_t)expiresInSeconds;



@end

NS_ASSUME_NONNULL_END
