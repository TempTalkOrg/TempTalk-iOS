//
//  DTQuickCommandAdapter.m
//  Signal
//
//  Created by hornet on 2022/8/22.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTQuickCommandAdapter.h"
#import "DTQuickCommand.h"
#import "TSOutgoingMessage.h"

extern NSMutableDictionary *DTGetQuickcommondDictionary(void);

@implementation DTQuickCommandAdapter

+ (void)handleOutgoingMessage:(TSOutgoingMessage *)outgoingMessage associatedOrignalMessage:(TSMessage * )orignalMessage {
    //匹配命令类型，并执行相应操作
    DTQuickCommand *quickCommand = [self matchKeyboardCommandWithString:outgoingMessage.body];
    [self handlerOutgoingMessage:outgoingMessage associatedOrignalMessage:orignalMessage quickCommand:quickCommand];
    
}

+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage {
    //匹配命令类型，并执行相应操作
    DTQuickCommand *quickCommand = [self matchKeyboardCommandWithString:outgoingMessage.body];
    [self handlerOutgoingMessage:outgoingMessage quickCommand:quickCommand];
}

+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage quickCommand:(DTQuickCommand *)quickCommand {
    if (!quickCommand) {return;}
    [quickCommand handleOutgoingMessage:outgoingMessage];
}

+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage associatedOrignalMessage:(TSMessage * ) associatedOrignalMessage  quickCommand:(DTQuickCommand * __nullable)quickCommand {
    if (!quickCommand) {return;}
    if (!associatedOrignalMessage) {
        [quickCommand handleOutgoingMessage:outgoingMessage];
    } else {
        [quickCommand handleOutgoingMessage:outgoingMessage associatedOrignalMessage:associatedOrignalMessage];
    }
}

+ (DTQuickCommand * __nullable)matchKeyboardCommandWithString:(NSString *)orignalMessage {
    for (NSString *classString in DTGetQuickcommondDictionary().allKeys) {
        Class class = NSClassFromString(classString);
        DTQuickCommand *quickCommand = (DTQuickCommand *)[class new];
        if ([quickCommand hasPrefixKeyboardCommandWith:orignalMessage]) {
            return quickCommand;
        }
    }
    return nil;
}

+ (BOOL)isContainQuickCommandWithMessage:(NSString *)orignalMessage {
    return [self matchKeyboardCommandWithString:orignalMessage];
}


+ (BOOL)isContainQuickCommand:(DTQuickCommand *)quickCommand {
    return [DTGetQuickcommondDictionary().allKeys containsObject:NSStringFromClass(quickCommand.class)];
}

+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage replyModel:(DTReplyModel *)replyModel {
    /// 没有原始信息的模型数据  表示的是用户发送的消息是不基于任何消息生成的新消息 按照新的指令消息处理
    if (!replyModel) { [self handlerOutgoingMessage:outgoingMessage]; return;}
}

@end
