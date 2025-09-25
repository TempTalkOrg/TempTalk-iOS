//
//  DTQuickCommandAdapter.h
//  Signal
//
//  Created by hornet on 2022/8/22.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DTQuickCommand;
@class TSOutgoingMessage;
@class TSMessage;
@class DTReplyModel;

NS_ASSUME_NONNULL_BEGIN

/// 处理指令消息类
@interface DTQuickCommandAdapter : NSObject

/// 处理消息发送
/// @param outgoingMessage 待发送的消息
+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage ;

/// 处理消息发送
/// @param outgoingMessage 待发送的消息
/// @param orignalMessage 关联的原始消息
+ (void)handleOutgoingMessage:(TSOutgoingMessage *)outgoingMessage associatedOrignalMessage:(TSMessage * __nullable)orignalMessage;


/// 处理消息发送
/// @param outgoingMessage 待发送的消息
/// @param quickCommand 对应的快捷指令
+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage quickCommand:(DTQuickCommand *)quickCommand;

/// 已经注册的快捷指令集是否包含指定的快捷指令
/// @param quickCommand 快捷指令
+ (BOOL)isContainQuickCommand:(DTQuickCommand *)quickCommand;

/// 通过字符串匹配对应的快捷指令 ⚠️ 快捷指令都是在字符串的开头 例如 @“/Topic hello world” @“/topic hello world” 等 ，非开头该方法不予匹配
+ (DTQuickCommand * __nullable)matchKeyboardCommandWithString:(NSString *)orignalMessage;

/// 字符串中是否包含快捷指令
+ (BOOL)isContainQuickCommandWithMessage:(NSString *)orignalMessage;

/// 处理消息发送
/// @param outgoingMessage  待发送的消息
/// @param replyModel 当前消息的 关联消息的数据模型 （例如：回复topic消息，需要知道原始消息的一下信息 replyModel会携带这些信息 ）
+ (void)handlerOutgoingMessage:(TSOutgoingMessage* )outgoingMessage replyModel:(DTReplyModel * __nullable )replyModel;

@end

NS_ASSUME_NONNULL_END
