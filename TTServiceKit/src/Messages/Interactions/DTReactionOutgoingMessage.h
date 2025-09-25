//
//  DTReactionOutgoingMessage.h
//  TTServiceKit
//
//  Created by Ethan on 2022/5/20.
//

#import "TSOutgoingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTReactionOutgoingMessage : TSOutgoingMessage

@property (nonatomic, strong) NSDictionary *reactionInfo;

+ (instancetype)reactionOutgoingMessageWithTimestamp:(uint64_t)timestamp
                        reactionMessage:(DTReactionMessage *)reactionMessage
                                 thread:(TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
