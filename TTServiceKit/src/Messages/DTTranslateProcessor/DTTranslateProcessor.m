//
//  DTTranslateProcessor.m
//  TTServiceKit
//
//  Created by hornet on 2022/1/14.
//

#import "DTTranslateProcessor.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSOutgoingMessage.h"
#import "DTCombinedForwardingMessage.h"
#import "DTTranslateApi.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSAttachmentStream.h"
#import "MIMETypeUtil.h"
#import "OWSAttachmentsProcessor.h"
#import "TSAttachmentPointer.h"
#import "DTTranslateOpreation.h"


@interface DTTranslateProcessor()

@property(nonatomic,strong) DTTranslateApi *translateApi;
@property(nonatomic,strong) NSOperationQueue *translateQueue;

@end

@implementation DTTranslateProcessor

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (void)handleMessageForTranslateWithThread:(TSThread *)thread message:(TSMessage *)message {
    DTTranslateOpreation *translateOpreation = [[DTTranslateOpreation alloc] initWithThread:thread message:message];
    [self.translateQueue addOperation:translateOpreation];
}

//群组
- (void)handleThreadWithMessage:(TSThread *)thread message:(TSMessage *)message {
    DTTranslateMessageType translateSettingType = (DTTranslateMessageType)[thread.translateSettingType intValue];
    __block DTTranslateMessage *translateMessage = [DTTranslateMessage new];
    NSString *contents = [self.translateApi getTargetTranferContents:message];
    @weakify(self);
    [self.translateApi sendRequestWithSourceLang:nil
                                      targetLang:translateSettingType
                                        contents:contents
                                          thread:thread
                                    attachmentId:message.attachmentIds.firstObject
                                         success:^(DTTranslateEntity * _Nonnull entity) {
        @strongify(self);
        __block TSMessage *tmpMessage = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
            tmpMessage = [TSMessage anyFetchMessageWithUniqueId:message.uniqueId transaction:transaction];
        }];
        if (tmpMessage.translateMessage) {
            translateMessage = tmpMessage.translateMessage;
        }
        if ([tmpMessage isKindOfClass:TSIncomingMessage.class] || [tmpMessage isKindOfClass:TSOutgoingMessage.class]) {
            DTTranslateSingleEntity *translateSingleEntity;
            if (entity && entity.data) {
                translateSingleEntity = entity.data;
            }
            if (translateSingleEntity) {
                //过滤掉同种语言 或则翻译结果是同一个的情况
                if ([contents isEqualToString:translateSingleEntity.translatedText]) {
                    translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                    translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
                    translateMessage.tranEngLishResult = translateSingleEntity.translatedText;
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                        [message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
                            messageCopy.translateMessage = translateMessage;
                        }];
                    });
                    return;
                }
                translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                switch (translateSettingType) {
                    case DTTranslateMessageTypeOriginal:translateMessage.translatedType = @(translateSettingType);break;
                        
                    case DTTranslateMessageTypeEnglish:{
                        translateMessage.translatedType = @(translateSettingType);
                        translateMessage.tranEngLishResult = translateSingleEntity.translatedText;
                    }
                        break;
                    case DTTranslateMessageTypeChinese:{
                        translateMessage.translatedType = @(translateSettingType);
                        translateMessage.tranChinseResult = translateSingleEntity.translatedText;
                    }
                        break;
                    default:
                        translateMessage.translatedType = @(translateSettingType);
                        break;
                }
                
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    [message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
                        messageCopy.translateMessage = translateMessage;
                    }];
                });
            }else {
                translateMessage.translatedState = @(DTTranslateMessageStateTypeFailed);
                translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE_FAILED", @"");
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    [message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
                        messageCopy.translateMessage = translateMessage;
                    }];
                });
            }
        }else{
            return;
        }
        
    } failure:^(NSError * _Nonnull error) {
        @strongify(self);
        translateMessage.translatedState = @(DTTranslateMessageStateTypeFailed);
        translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE_FAILED", @"");
        translateMessage.translatedType = @(translateSettingType);
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
                messageCopy.translateMessage = translateMessage;
            }];
        });
    }];
}

//验证是否包含emoji表情
- (int)validateContainsEmoji:(NSString *)string {
    __block BOOL returnValue = NO;
    __block int count = 0;
    [string enumerateSubstringsInRange:NSMakeRange(0, [string length])
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        const unichar hs = [substring characterAtIndex:0];
        if (0xd800 <= hs && hs <= 0xdbff) {
            if (substring.length > 1) {
                const unichar ls = [substring characterAtIndex:1];
                const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                if (0x1d000 <= uc && uc <= 0x1f77f) {
                    returnValue = YES;
                    count +=2;
                }
            }
        } else if (substring.length > 1) {
            const unichar ls = [substring characterAtIndex:1];
            if (ls == 0x20e3) {
                returnValue = YES;
                count +=2;
            }
        } else {
            if (0x2100 <= hs && hs <= 0x27ff) {
                returnValue = YES;
                count +=2;
            } else if (0x2B05 <= hs && hs <= 0x2b07) {
                returnValue = YES;
                count +=2;
            } else if (0x2934 <= hs && hs <= 0x2935) {
                returnValue = YES;
                count +=2;
            } else if (0x3297 <= hs && hs <= 0x3299) {
                returnValue = YES;
                count +=2;
            } else if (hs == 0xa9 || hs == 0xae || hs == 0x303d || hs == 0x3030 || hs == 0x2b55 || hs == 0x2b1c || hs == 0x2b1b || hs == 0x2b50) {
                returnValue = YES;
                count +=2;
            }
        }
    }];
    return count;
}


//- (void)handleAttachmentMessage:(TSMessage *)incomingMessage thread:(TSThread *)thread transaction:(SDSAnyWriteTransaction *) transaction attachmentStream:(TSAttachmentStream *)attachmentStream {
//    if (![attachmentStream.contentType isEqualToString:OWSMimeTypeOversizeTextMessage]) {
//        return;
//    }
//    DTTranslateMessageType translateSettingType = (DTTranslateMessageType)[thread.translateSettingType intValue];
//    if (translateSettingType != DTTranslateMessageTypeOriginal && translateSettingType != DTTranslateMessageTypeUnknow) {
//        NSData *textData = [NSData dataWithContentsOfURL:attachmentStream.mediaURL];
//        //        NSString *text =
//        //        [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
//        if (textData.length > kOversizeTextMessageSizelength) {
//            DTTranslateMessage *translateMessage = [DTTranslateMessage new];
//            translateMessage.translatedState = @(DTTranslateMessageStateTypeFailed);
//            translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE_LONG_TEXT", @"");
//            translateMessage.translatedType = @(translateSettingType);
//            incomingMessage.translateMessage = translateMessage;
//            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
//                [incomingMessage anyUpdateMessageWithTransaction:transaction block:^(TSMessage * _Nonnull messageCopy) {
//                    messageCopy.translateMessage = translateMessage;
//                }];
//            });
//        }else {
//            DTTranslateMessage *translateMessage = [DTTranslateMessage new];
//            translateMessage.translatedState = @(DTTranslateMessageStateTypeTranslating);
//            translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE", @"");
//            translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
//            incomingMessage.translateMessage = translateMessage;
//            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
//                [incomingMessage anyUpdateMessageWithTransaction:transaction block:^(TSMessage * _Nonnull messageCopy) {
//                    messageCopy.translateMessage = translateMessage;
//                }];
//            });
//            [self handleMessageForTranslateWithThread:thread message:incomingMessage];
//        }
//    }
//}
- (void)handleMessageForPreTranslateAfterScrollWithThread:(TSThread *)thread message:(TSMessage *)message  transaction:(SDSAnyWriteTransaction *)transaction {
    DTTranslateMessageType translateSettingType = (DTTranslateMessageType)[thread.translateSettingType intValue];
    if (message.isSingleForward) {//表示单条转发的消息
        DTCombinedForwardingMessage *forwardingMessage = message.combinedForwardingMessage.subForwardingMessages.firstObject;
        NSString *contents = forwardingMessage.body;
        NSString *subMessageAttachmentId = forwardingMessage.forwardingAttachmentIds.firstObject;
        
        TSAttachment *attachment = nil;
        if (DTParamsUtils.validateString(subMessageAttachmentId)) {
            attachment = [TSAttachment anyFetchWithUniqueId:subMessageAttachmentId transaction:transaction];
        }
        
        // 转发的消息中有附件且是长文本类型先不做处理，因为不知道文本大小
        if (attachment &&
            [attachment isKindOfClass:TSAttachmentStream.class] &&
            [attachment.contentType isEqualToString:OWSMimeTypeOversizeTextMessage]) {
            return;
        } else {
            if (contents.length > 0) {
                if ([self validateContainsEmoji:contents] == contents.length) {
                    return;
                }
                DTTranslateMessage *translateMessage = [DTTranslateMessage new];
                translateMessage.translatedState = @(DTTranslateMessageStateTypeTranslating);
                translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE", @"");
                translateMessage.translatedType = @(translateSettingType);
                [message anyUpdateMessageWithTransaction:transaction block:^(TSMessage * _Nonnull messageCopy) {
                    messageCopy.translateMessage = translateMessage;
                }];
            }
        }
    } else {//普通文本消息
        NSString *contents = message.body;
        if ([self validateContainsEmoji:contents] == contents.length) {
            return;
        }
        DTTranslateMessage *translateMessage = [DTTranslateMessage new];
        translateMessage.translatedState = @(DTTranslateMessageStateTypeTranslating);
        translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE", @"");
        translateMessage.translatedType = @(translateSettingType);
        [message anyUpdateMessageWithTransaction:transaction block:^(TSMessage * _Nonnull messageCopy) {
            messageCopy.translateMessage = translateMessage;
        }];
    }
}

//- (void)handleMessageForPreTranslateWithThread:(TSThread *)thread message:(TSMessage *)message  transaction:(SDSAnyWriteTransaction *)transaction {
//    DTTranslateMessageType translateSettingType = (DTTranslateMessageType)[thread.translateSettingType intValue];
//    if (translateSettingType != DTTranslateMessageTypeOriginal && translateSettingType != DTTranslateMessageTypeUnknow) {
//        //判断是否是长文本类型
//        if (!message.body.length && message.attachmentIds.count) {//表示是附件类型,附件类型需要先下载附件所以这里不做处理
//            [message anyInsertWithTransaction:transaction];
//        }else {//非附件类型
//            if (message.isSingleForward) {//表示单条转发的消息
//                DTCombinedForwardingMessage *forwardingMessage = message.combinedForwardingMessage.subForwardingMessages.firstObject;
//                NSString *contents = forwardingMessage.body;
//                NSString *subMessageAttachmentId = forwardingMessage.forwardingAttachmentIds.firstObject;
//                TSAttachmentPointer *attachmentPointer =
//                [TSAttachmentPointer anyFetchAttachmentPointerWithUniqueId:subMessageAttachmentId
//                                                               transaction:transaction];
//                //转发的消息中有附件切是长文本类型先不做处理，因为不知道文本大小
//                if ([attachmentPointer.contentType isEqualToString:OWSMimeTypeOversizeTextMessage]) {
//                    [message anyInsertWithTransaction:transaction];
//                }else {
//                    if (contents.length > 0) {
//                        if ([self validateContainsEmoji:contents] == contents.length) {
//                            [message anyInsertWithTransaction:transaction];
//                            return;
//                        }
//                        DTTranslateMessage *translateMessage = [DTTranslateMessage new];
//                        translateMessage.translatedState = @(DTTranslateMessageStateTypeTranslating);
//                        translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE", @"");
//                        translateMessage.translatedType = @(translateSettingType);
//                        message.translateMessage = translateMessage;
//                        [message anyInsertWithTransaction:transaction];
//                        [self handleMessageForTranslateWithThread:thread message:message];
//                    }else {
//                        [message anyInsertWithTransaction:transaction];
//                    }
//                }
//            }else if (message.isMultiForward){//表示多条合并转发
//                [message anyInsertWithTransaction:transaction];
//            }else if([message isTaskMessage]){
//                [message anyInsertWithTransaction:transaction];
//            } else if ([message isVoteMessgae]) {
//                [message anyInsertWithTransaction:transaction];
//            } else {//普通文本消息
//                NSString *contents = message.body;
//                if ([self validateContainsEmoji:contents] == contents.length) {
//                    [message anyInsertWithTransaction:transaction];
//                    return;
//                }
//                DTTranslateMessage *translateMessage = [DTTranslateMessage new];
//                translateMessage.translatedState = @(DTTranslateMessageStateTypeTranslating);
//                translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE", @"");
//                translateMessage.translatedType = @(translateSettingType);
//                message.translateMessage = translateMessage;
//                [message anyInsertWithTransaction:transaction];
//                [self handleMessageForTranslateWithThread:thread message:message];
//            }
//        }
//    }else{//用户未配置翻译，直接展示原文
//        [message anyInsertWithTransaction:transaction];
//    }
//}

- (DTTranslateApi *)translateApi {
    if (!_translateApi) {
        _translateApi = [[DTTranslateApi alloc] init];
    }
    return _translateApi;
}

-(NSOperationQueue *)translateQueue {
    if (!_translateQueue) {
        _translateQueue = [NSOperationQueue new];
        _translateQueue.maxConcurrentOperationCount = 1;
    }
    return _translateQueue;
}
@end
