//
//  DTInputReplyPreView.h
//  Signal
//
//  Created by hornet on 2022/8/30.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OWSBubbleView.h"

@class ConversationStyle;
@class DTReplyModel;

NS_ASSUME_NONNULL_BEGIN

@interface DTInputMessagePreView : UIView


// Only needs to be called if we're going to render this instance.
- (void)createContents;

- (void)applyTheme;

// Measurement
- (CGSize)sizeForMaxWidth:(CGFloat)maxWidth;

//子类自己实现
+ (DTInputMessagePreView *)replyMessageViewForPreview:(DTReplyModel *)quotedMessage
                                    conversationStyle:(ConversationStyle *)conversationStyle;

@end

NS_ASSUME_NONNULL_END
