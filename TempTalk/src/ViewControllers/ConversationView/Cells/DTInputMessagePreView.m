//
//  DTInputReplyPreView.m
//  Signal
//
//  Created by hornet on 2022/8/30.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTInputMessagePreView.h"
#import "DTReplyModel.h"

@implementation DTInputMessagePreView

+ (DTInputMessagePreView *)replyMessageViewForPreview:(DTReplyModel *)quotedMessage
                                  conversationStyle:(ConversationStyle *)conversationStyle {
    return [DTInputMessagePreView new];
}

- (void)createContents {
    
}

// Measurement
- (CGSize)sizeForMaxWidth:(CGFloat)maxWidth {
    return CGSizeZero;
}

- (void)applyTheme {
    OWSAbstractMethod();
}

@end
