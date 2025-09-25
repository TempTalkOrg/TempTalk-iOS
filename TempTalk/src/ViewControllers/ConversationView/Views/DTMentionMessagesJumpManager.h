//
//  DTMentionMessagesJumpManager.h
//  Signal
//
//  Created by Kris.s on 2022/7/21.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TSGroupThread;
@class TSMessage;

@interface DTMentionMessagesJumpManager : NSObject

- (instancetype)initWithConversationViewThread:(TSGroupThread *)thread
                           iconViewLayoutBlock:(void (^)(UIView *indicatorView))iconViewLayoutBlock
                                     jumpBlock:(void (^)(TSMessage *focusMessage))jumpBlock;

- (void)handleMentionedMessagesOnce;

@end

NS_ASSUME_NONNULL_END
