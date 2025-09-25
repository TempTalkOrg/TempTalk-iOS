//
//  DTTranslateProcessor.h
//  TTServiceKit
//
//  Created by hornet on 2022/1/14.
//

#import <Foundation/Foundation.h>
#import "DTTranslateProcessor.h"

@class TSThread;
@class TSMessage;
@class SDSAnyWriteTransaction;
@class TSAttachmentStream;
@class OWSAttachmentsProcessor;
@class DTTranslateApi;

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, DTTranslateMessageType) {
    DTTranslateMessageTypeOriginal = 0,
    DTTranslateMessageTypeChinese = 1,//中文
    DTTranslateMessageTypeEnglish = 2,//英语
    DTTranslateMessageTypeSysterm = 3,//系统语言类型
    DTTranslateMessageTypeUnknow = 4 //未知的语言类型
};

@interface DTTranslateProcessor : NSObject

@property(nonatomic,readonly) DTTranslateApi *translateApi;

+ (instancetype)sharedInstance;

/// 翻译前前置处理消息 该方法用于在ConversationVC中进行调用使用
/// @param thread 会话
/// @param message 消息
/// @param transaction 事务
- (void)handleMessageForPreTranslateAfterScrollWithThread:(TSThread *)thread message:(TSMessage *)message  transaction:(SDSAnyWriteTransaction *)transaction;
/// 翻译前前置处理消息
/// @param thread 会话
/// @param message 消息
/// @param transaction 事务
//- (void)handleMessageForPreTranslateWithThread:(TSThread *)thread message:(TSMessage *)message  transaction:(SDSAnyWriteTransaction *)transaction;

/// 用于在接收消息的时候对翻译结果进行处理
/// @param thread 用户或者群组管理
/// @param message 接收到的消息
- (void)handleMessageForTranslateWithThread:(TSThread *)thread message:(TSMessage *)message;

///处理包含附件类型的消息
//- (void)handleAttachmentMessage:(TSMessage *)incomingMessage thread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *) transaction   attachmentStream:(TSAttachmentStream *)attachmentStream;

@end

NS_ASSUME_NONNULL_END
