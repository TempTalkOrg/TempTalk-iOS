//
//  DTQuickCommand.h
//  Signal
//
//  Created by hornet on 2022/8/22.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TSMessage;
@class TSOutgoingMessage;
@class TSIncomingMessage;

NS_ASSUME_NONNULL_BEGIN
//
@interface DTQuickCommand : NSObject
@property (nonatomic, strong) NSString *keyCommand;
///是否区分大小写
+ (BOOL)isVerifyCaseOfTheString;

///配置关键指令
+ (NSString * __nullable)configKeyCommand;
///是否需要将消息体中以当前快捷指令开头的 字符删除 default false
+ (BOOL)isNeedremovePrefixQuickCommand;

-(void)removePrefixQuickCommandFromMessage:(TSMessage *)message;

///是否以KeyboardCommand 开头 default: false
- (BOOL)hasPrefixKeyboardCommandWith:(NSString *)string;



/// 处理发送的消息
/// @param message 消息
- (void)handleOutgoingMessage:(TSOutgoingMessage *)message;


- (void)handleOutgoingMessage:(TSOutgoingMessage *)message associatedOrignalMessage:(TSMessage *)orignalMessage;

/// 处理接收的消息
/// @param message 消息
- (void)handleIncomingMessage:(TSIncomingMessage *)message;
@end

NS_ASSUME_NONNULL_END
