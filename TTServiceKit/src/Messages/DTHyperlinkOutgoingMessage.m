//
//  DTHyperlinkOutgoingMessage.m
//  TTServiceKit
//
//  Created by Ethan on 2022/7/26.
//

#import "DTHyperlinkOutgoingMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>
#import "OWSDisappearingMessagesConfiguration.h"
#import "TSThread.h"

@implementation DTHyperlinkOutgoingMessage

// --- CODE GENERATION MARKER
// --- CODE GENERATION MARKER

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                          thread:(TSThread *)thread {
    DTHyperlinkOutgoingMessage *message = [DTHyperlinkOutgoingMessage outgoingHyperlinkMessageWithText:text
                                                                                             atPersons:nil
                                                                                              mentions:nil
                                                                                                thread:thread
                                                                                              cardInfo:nil];

    return message;

}

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                       atPersons:(NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                        apnsType:(DTApnsMessageType)apnsType
                                          thread:(TSThread *)thread {
    
    DTHyperlinkOutgoingMessage *message = [DTHyperlinkOutgoingMessage outgoingHyperlinkMessageWithText:text
                                                                                             atPersons:atPersons
                                                                                              mentions:mentions
                                                                                                thread:thread];

    message.apnsType = apnsType;
    return message;
}

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                       atPersons:(NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                          thread:(TSThread *)thread {
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    NSString *finalText = [DTHyperlinkOutgoingMessage handleMarkdownKeysInText:text];
    
    DTCardMessageEntity *card = [DTCardMessageEntity new];
    card.appId = @"";
    card.content = finalText;
    
    DTHyperlinkOutgoingMessage *message = [[DTHyperlinkOutgoingMessage alloc] initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                                 inThread:thread
                                                                                              messageBody:text
                                                                                                atPersons:atPersons
                                                                                                      mentions:mentions
                                                                                            attachmentIds:[NSMutableArray new]
                                                                                         expiresInSeconds:expiresInSeconds
                                                                                          expireStartedAt:0
                                                                                           isVoiceMessage:NO
                                                                                         groupMetaMessage:TSGroupMessageUnspecified
                                                                                            quotedMessage:nil
                                                                                        forwardingMessage:nil
                                                                                             contactShare:nil];
    message.card = card;
    
    return message;
}

+ (instancetype)outgoingHyperlinkMessageWithText:(nullable NSString *)text
                                        apnsType:(DTApnsMessageType)apnsType
                                          thread:(TSThread *)thread
                                        cardInfo:(nullable NSDictionary *)cardInfo {
    
    DTHyperlinkOutgoingMessage *message = [DTHyperlinkOutgoingMessage outgoingHyperlinkMessageWithText:text
                                                                                             atPersons:nil
                                                                                              mentions:nil
                                                                                                thread:thread
                                                                                              cardInfo:cardInfo];

    message.apnsType = apnsType;
    return message;
}

//+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
//                                       atPersons:(NSString *)atPersons
//                                        mentions:(nullable NSArray <DTMention *> *)mentions
//                                        apnsType:(DTApnsMessageType)apnsType
//                                          thread:(TSThread *)thread {
//    
//    DTHyperlinkOutgoingMessage *message = [DTHyperlinkOutgoingMessage outgoingHyperlinkMessageWithText:text
//                                                                                             atPersons:atPersons
//                                                                                              mentions:mentions
//                                                                                                thread:thread];
//
//    message.apnsType = apnsType;
//    return message;
//}

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                       atPersons:(NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                          thread:(TSThread *)thread
                                        cardInfo:(nullable NSDictionary *)cardInfo {
            
    DTCardMessageEntity *card = [[DTCardMessageEntity alloc] init];
    NSString *body = text;

    if (DTParamsUtils.validateDictionary(cardInfo)) {
        NSString *appId = cardInfo[@"appId"];
        NSString *content = cardInfo[@"content"];
        NSString *cardId = cardInfo[@"id"];
        NSString *conversationId = cardInfo[@"conversationId"];
        NSNumber *version = cardInfo[@"version"];
        if (DTParamsUtils.validateString(appId)) {
            card.appId = appId;
        } else {
            OWSLogError(@"%@ appId unexpected is nil", self.logTag);
        }
        if (DTParamsUtils.validateString(content)) {
            NSString *finalContent = [DTHyperlinkOutgoingMessage handleMarkdownKeysInText:content];
            card.content = finalContent;
            body = finalContent;
        } else {
            OWSLogError(@"%@ content unexpected is nil", self.logTag);
        }
        
        if (DTParamsUtils.validateString(cardId)) {
            card.cardId = cardId;
        } else {
            OWSLogError(@"%@ cardId unexpected is nil", self.logTag);
        }

        if (DTParamsUtils.validateNumber(version)) {
            card.version = [version intValue];
        } else {
            OWSLogError(@"%@ version unexpected is nil", self.logTag);
        }
        
        if (DTParamsUtils.validateString(conversationId)) {
            card.conversationId = conversationId;
        } else {
            OWSLogError(@"%@ conversationId unexpected is nil", self.logTag);
        }
        
    } else {
        NSString *finalText = [DTHyperlinkOutgoingMessage handleMarkdownKeysInText:text];
        card.content = finalText;
        card.source = [TSAccountManager localNumber];
        card.appId = @"meeting-server";
    }
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];

    DTHyperlinkOutgoingMessage *message = [[DTHyperlinkOutgoingMessage alloc] initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                                      inThread:thread
                                                                                                   messageBody:body
                                                                                                     atPersons:atPersons
                                                                                                      mentions:mentions
                                                                                                 attachmentIds:[NSMutableArray new]
                                                                                              expiresInSeconds:expiresInSeconds
                                                                                               expireStartedAt:0
                                                                                                isVoiceMessage:NO
                                                                                              groupMetaMessage:TSGroupMessageUnspecified
                                                                                                 quotedMessage:nil
                                                                                             forwardingMessage:nil
                                                                                                  contactShare:nil];
    
    if (DTParamsUtils.validateDictionary(cardInfo)) {
        NSString *cardUniqueId = [card generateUniqueIdWithSource:[TSAccountManager localNumber] conversationId:card.conversationId];
        card.uniqueId = cardUniqueId;
        message.cardUniqueId = cardUniqueId;
        message.cardVersion = card.version;
    }
    message.card = card;
    
    return message;
}

//MARK: 处理群名/会议名中有markdown语法字符展示异常的问题
+ (NSString *)handleMarkdownKeysInText:(NSString *)text {
    
    NSString *handleText = text;

    NSArray <NSString *> *allTips = @[Localized(@"GROUP_CALL_WITH_LINK_JOIN", @""), Localized(@"SHARE_GROUP_LINK_CLICK_TO_JOIN", @""), @"click to join the meeting"];
    __block NSString *tips = nil;
    __block NSArray <NSString *> *textElements = nil;
    [allTips enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([handleText containsString:obj]) {
            tips = [NSString stringWithFormat:@"[%@]", obj];
            textElements = [text componentsSeparatedByString:tips];
            *stop = YES;
        }
    }];
    
    if (textElements.count == 2) {
        __block NSString *prefix = textElements[0];
        NSArray <NSString *> *markdownKeys = @[@"*", @"_", @"~", @"[", @"]", @"(", @")", @"#", @"!", @"-", @"<", @">", @"|", @"`"];
        NSMutableArray <NSString *> *prefixs = @[].mutableCopy;
        for (NSInteger i = 0; i < prefix.length; i ++) {
            NSString *temp = [prefix substringWithRange:NSMakeRange(i, 1)];
            [prefixs addObject:temp];
        }
        NSMutableArray <NSString *> *newPrefixs = prefixs.mutableCopy;
        [prefixs enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([markdownKeys containsObject:obj]) {
                [newPrefixs replaceObjectAtIndex:idx withObject:[@"\\" stringByAppendingString:obj]];
            }
        }];
        prefix = [newPrefixs componentsJoinedByString:@""];
        
        handleText = [NSString stringWithFormat:@"%@%@%@", prefix, tips, textElements[1]];
    }

    return handleText;
}

- (BOOL)isSilent {
    return NO;
}

- (BOOL)shouldBeSaved {

    return YES;
}

@end
