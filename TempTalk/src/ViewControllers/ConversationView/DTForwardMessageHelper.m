//
//  DTForwardMessageHelper.m
//  Wea
//
//  Created by Ethan on 2021/11/23.
//

#import "DTForwardMessageHelper.h"
#import <CoreServices/CoreServices.h>
#import "ConversationViewItem.h"
#import "TempTalk-Swift.h"

@implementation DTForwardMessageHelper

+ (TSMessage *)messageFromViewItem:(id<ConversationViewItem>)viewItem {
   
    if ([viewItem.interaction isKindOfClass:[TSMessage class]]) {
        TSMessage *message = (TSMessage *)viewItem.interaction;
        return message;
    }
    
    return nil;
}

+ (NSArray <TSMessage *> *)messagesFromViewItems:(NSArray <id<ConversationViewItem>> *)viewItems {
    
    NSMutableArray *forwardMessages = @[].mutableCopy;
    for (id<ConversationViewItem>viewItem in viewItems) {
        TSMessage *message = [self messageFromViewItem:viewItem];
        if (message != nil) {
            [forwardMessages addObject:message];
        }
    }
    
    return forwardMessages.copy;
}

+ (id)forwardContentFromViewItem:(id<ConversationViewItem>)viewItem {
    
    if (viewItem.isCombindedForwardMessage || viewItem.contactShare != nil || viewItem.card != nil) {
        return (TSMessage *)viewItem.interaction;
    }
    __block NSString *messageBodyText = nil;
    __block SignalAttachment *signalAttachment = nil;
    DispatchMainThreadSafe(^{
        if (viewItem.hasBodyText && viewItem.displayableBodyText.fullText) {
            messageBodyText = viewItem.displayableBodyText.fullText;
            if ([viewItem.interaction isKindOfClass:[TSMessage class]]) {
                TSMessage *message = (TSMessage *)viewItem.interaction;
                if (message.isCardMessage) {
                    messageBodyText = [messageBodyText removeMarkdownStyle];
                }
            }
        }
        if (viewItem.attachmentStream) {
            NSString *utiType = [MIMETypeUtil utiTypeForMIMEType:viewItem.attachmentStream.contentType];
            if (!utiType) {
                OWSFailDebug(@"%@ Unknown MIME type: %@", self, viewItem.attachmentStream.contentType);
                utiType = (NSString *)kUTTypeGIF;
            }
            NSData *data = [NSData dataWithContentsOfURL:[viewItem.attachmentStream mediaURL]];
            if (!data) {
                OWSFailDebug(@"%@ Could not load attachment data: %@", self, [viewItem.attachmentStream mediaURL]);
            } else {
                id<DataSource> dataSource = [DataSourceValue dataSourceWithData:data utiType:utiType];
                [dataSource setSourceFilename:viewItem.attachmentStream.sourceFilename];
                signalAttachment = [SignalAttachment attachmentWithDataSource:dataSource dataUTI:utiType imageQuality:TSImageQualityOriginal];
            }
        } else if (viewItem.attachmentPointer) { // 支持转发本地未下载的附件
            messageBodyText = viewItem.attachmentPointer.description;
        }

    });
    if (signalAttachment) {
        signalAttachment.captionText = messageBodyText;
        return signalAttachment;
    } else {
        return messageBodyText;
    }
}

+ (NSArray *)forwardContentsFromViewItems:(NSArray <id<ConversationViewItem>> *)viewItems {
    
    OWSAssertDebug(viewItems.count > 0);
    __block NSMutableArray *forwardContents = [NSMutableArray new];
    [viewItems enumerateObjectsUsingBlock:^(id<ConversationViewItem> _Nonnull viewItem, NSUInteger idx, BOOL * _Nonnull stop) {
        id forwardContent = [self forwardContentFromViewItem:viewItem];
        if (forwardContent) {
            [forwardContents addObject:forwardContent];
        }
    }];
    
    return forwardContents.copy;
}


+ (NSString *)previewOfMessageTextWithForwardType:(DTForwardMessageType)type thread:(TSThread *)thread viewItems:(NSArray <id<ConversationViewItem>> *)viewItems {
    
    OWSAssertDebug(viewItems.count > 0);
    NSArray *forwardContnets = [self forwardContentsFromViewItems:viewItems];
    switch (type) {
        case DTForwardMessageTypeOneByOne:{
            if (forwardContnets.count == 1) {
                id forwardMessageContent = forwardContnets.firstObject;
                if ([forwardMessageContent isKindOfClass:NSString.class]) {
                    NSString *overviewText = (NSString *)forwardMessageContent;
                    return overviewText;
                } else if ([forwardMessageContent isKindOfClass:[TSMessage class]]) {
                    TSMessage *message = (TSMessage *)forwardMessageContent;
                    if (message.contactShare != nil) {
                        NSString *contactIdentifier = message.contactShare.phoneNumbers[0].phoneNumber;
                        NSString *contactName = [Environment.shared.contactsManager contactOrProfileNameForPhoneIdentifier:contactIdentifier];
                        //[个人名片]+name
                        return [[NSString stringWithFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_CONTACT_TYPE", @"")] stringByAppendingString:contactName];
                    } else if (message.card != nil){
                        NSString *bodyText = viewItems.firstObject.displayableBodyText.fullText;
                        if(message.isCardMessage) {
                            bodyText = [bodyText removeMarkdownStyle];
                        }
                        return bodyText;
                    } else {
                        //[聊天记录]
                        return [NSString stringWithFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_CHAT_HISTORY", @"")];
                    }
                } else {
                    SignalAttachment *signalAttachment = (SignalAttachment *)forwardMessageContent;
                    TSAttachmentStream *attachmentStream = viewItems.firstObject.attachmentStream;
                    NSString *overviewText = attachmentStream.description;
                    if (signalAttachment.captionText.length > 0) {
                        overviewText = [overviewText stringByAppendingString:signalAttachment.captionText];
                    }
                    return overviewText;
                }
            } else {
                NSString *overviewPrefix = [NSString stringWithFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_ONE_BY_ONE_TYPE", @"")];
                return [overviewPrefix stringByAppendingFormat:Localized(@"FORWARD_MESSAGE_ONE_BY_ONE_OVERVIEW", @""), forwardContnets.count];
            }
        }
            break;
        case DTForwardMessageTypeCombined:{
            NSString *overviewPrefix = [NSString stringWithFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_COMBINE_TYPE", @"")];
            BOOL isGroupThread = [thread isKindOfClass:[TSGroupThread class]];
            if (isGroupThread) {
                return [overviewPrefix stringByAppendingFormat:@"%@", Localized(@"FORWARD_MESSAGE_COMBINE_GROUP_OVERVIEW", @"")];
            } else {
                NSString *overviewFormat = Localized(@"FORWARD_MESSAGE_COMBINE_CONTACT_OVERVIEW", @"");
                NSArray <TSMessage *> *messages = [self messagesFromViewItems:viewItems];
                NSInteger incomingFlag = 0, outgoingFlag = 0, totalFlag = 0;
                for (TSMessage *message in messages) {
                    if ([message isKindOfClass:[TSOutgoingMessage class]]) {
                        outgoingFlag = 1;
                    }
                    if ([message isKindOfClass:[TSIncomingMessage class]]) {
                        incomingFlag = 2;
                    }
                }
                totalFlag = incomingFlag + outgoingFlag;
                
                NSString *profileName = [self userSelfName];
                __block NSString * threadName = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
                    threadName = [thread nameWithTransaction:readTransaction];
                }];
                BOOL isNote = [profileName isEqualToString:threadName];
                if (isNote || totalFlag == 1) {
                    return [overviewPrefix stringByAppendingString:[NSString stringWithFormat:overviewFormat, profileName]];
                }
                if (totalFlag == 2) {
                    return [overviewPrefix stringByAppendingString:[NSString stringWithFormat:overviewFormat, threadName]];
                }
                NSString *bothName = [NSString stringWithFormat:@"%@%@%@", threadName,  Localized(@"FORWARD_MESSAGE_OVERVIEW_AND", @""), profileName];
                return [overviewPrefix stringByAppendingFormat:overviewFormat, bothName];
            }
        }
            break;
        case DTForwardMessageTypeNote: {
            return nil;
            break;
        }
    }
    return nil;
}

+ (NSAttributedString *)combinedForwardingMessageBodyTextWithIsGroupThread:(BOOL)isGroupThread combinedMessage:(TSMessage *)combinedMessage {
    
    NSArray <DTCombinedForwardingMessage *> *subForwardingMessages = combinedMessage.combinedForwardingMessage.subForwardingMessages;
    OWSAssertDebug(subForwardingMessages);
    
    NSString *combinedForwardingTitle = [self combinedForwardingMessageTitleWithIsGroupThread:isGroupThread combinedMessage:combinedMessage];
    ConversationStyle *style = [[ConversationStyle alloc] initWithThread:nil];
    NSMutableAttributedString *attributeBodyText = [[NSMutableAttributedString alloc] initWithString:combinedForwardingTitle attributes:@{NSForegroundColorAttributeName : [style bubbleTextColorWithMessage:combinedMessage], NSFontAttributeName : UIFont.ows_dynamicTypeBodyFont}];
    __block NSString *overviewBodyText = @"\n";
    [subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull subMessage, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *authorName = subMessage.authorName;
        NSString *subMessageBodyText = [NSString stringWithFormat:@"%@：", authorName];
        
        if (subMessage.subForwardingMessages && subMessage.subForwardingMessages.count > 0) {
            subMessageBodyText = [subMessageBodyText stringByAppendingFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_CHAT_HISTORY", @"")];
        } else {
            if (subMessage.forwardingAttachmentIds.count > 0) {
                NSString *attachmentsDescription = subMessage.attachmentsDescription ?: [NSString stringWithFormat:@"[%@]", Localized(@"ATTACHMENT_LABEL", @"")];
                subMessageBodyText = [subMessageBodyText stringByAppendingString:attachmentsDescription];
            }
            if (subMessage.body && subMessage.body.length > 0) {
                subMessageBodyText = [subMessageBodyText stringByAppendingString:subMessage.body.ows_stripped];
            }
        }
        
        if ((subForwardingMessages.count >= 5 && idx < 4) || (subForwardingMessages.count < 5 && idx != subForwardingMessages.count - 1)) {
            subMessageBodyText = [subMessageBodyText stringByAppendingString:@"\n"];
        }
        if(subMessageBodyText.length){
            overviewBodyText = [overviewBodyText stringByAppendingString:subMessageBodyText];
        }
        if (idx == 4) {
            *stop = YES;
        }
    }];
    BOOL isIncoming = [combinedMessage isKindOfClass:[TSIncomingMessage class]];
    NSAttributedString *subAttributeText = [[NSAttributedString alloc] initWithString:overviewBodyText attributes:@{NSForegroundColorAttributeName : [style bubbleSecondaryTextColorWithIsIncoming:isIncoming], NSFontAttributeName : UIFont.ows_dynamicTypeFootnoteFont}];
    [attributeBodyText appendAttributedString:subAttributeText];

    return attributeBodyText;
}

+ (NSString *)combinedForwardingMessageTitleWithIsGroupThread:(BOOL)isGroupThread combinedMessage:(TSMessage *)combinedMessage {
    
    NSArray <DTCombinedForwardingMessage *> *subForwardingMessages = combinedMessage.combinedForwardingMessage.subForwardingMessages;
    OWSAssertDebug(subForwardingMessages);
    
    if (isGroupThread) {
        return Localized(@"FORWARD_MESSAGE_COMBINE_GROUP_OVERVIEW", @"");
    } else {
        __block NSString *firstUserName = nil;
//        __block NSString *secondUserName = nil;
        NSMutableSet <NSString *> *authorNames = [NSMutableSet new];
        [subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [authorNames addObject:obj.authorName];
            if(idx == 0){
                firstUserName = obj.authorName;
            }
        }];
        NSString *overviewFormat = Localized(@"FORWARD_MESSAGE_COMBINE_CONTACT_OVERVIEW", @"");
        if (authorNames.count == 1) {
            return [NSString stringWithFormat:overviewFormat, authorNames.anyObject];
        } else {
            [authorNames removeObject:firstUserName];
            NSString *bothName = [NSString stringWithFormat:@"%@%@%@", firstUserName,  Localized(@"FORWARD_MESSAGE_OVERVIEW_AND", @""), authorNames.anyObject];
            return [NSString stringWithFormat:overviewFormat, bothName];
        }
    }
    return Localized(@"FORWARD_MESSAGE_CHAT_HISTORY", @"");
}

+ (NSString *)userSelfName {
    
    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
    SignalAccount *selfAccount = [Environment.shared.contactsManager signalAccountForRecipientId:localNumber];
    NSString *selfName = selfAccount.contact.fullName;
    if (!selfAccount || selfName.length == 0) {
        return localNumber;
    }
    return selfName;
}

+ (void)forwardMessageIsFromGroup:(BOOL)isGroupThread
                     targetThread:(TSThread *)targetThread
                         messages:(NSArray <TSMessage *>*)messages
                          success:(void(^ _Nullable)(void))success
                          failure:(void(^ _Nullable)(NSError *error))failure {
    
    OWSAssertDebug(targetThread);
    OWSAssertDebug(messages.count > 0);
    
    if (messages.count == 1 && messages.firstObject.contactShare != nil) {
        //MARK: 如果合并转发内容是一个名片，直接发送不合并
        [ThreadUtil sendMessageWithContactShare:messages.firstObject.contactShare inThread:targetThread messageSender:Environment.shared.messageSender completion:^(NSError * _Nullable error) {
            if (error) {
                OWSLogError(@"%@", error.debugDescription);
                if (failure) failure(error);
            } else {
                if (success) success();
            }
        }];
    } else {
        __block DTCombinedForwardingMessage *forwardingMessage = nil;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            BOOL isFromGroup = isGroupThread;
            if (messages.count == 1 && messages.firstObject.combinedForwardingMessage) {
                //MARK: 合并消息直接转发消息本身
                TSMessage *message = messages.firstObject;
                isFromGroup = message.combinedForwardingMessage.isFromGroup;
                forwardingMessage = [DTCombinedForwardingMessage buildSingleForwardingMessageWithMessage:message.combinedForwardingMessage transaction:transaction];
            } else {
                //MARK: 非合并消息先合并再转发
                forwardingMessage = [DTCombinedForwardingMessage buildCombinedForwardingMessageForSendingWithMessages:messages isFromGroup:isFromGroup transaction:transaction];
            }
        });
        [ThreadUtil sendMessageWithCombinedForwardingMessage:forwardingMessage
                                                   atPersons:nil
                                                    mentions:nil
                                                    inThread:targetThread
                                            quotedReplyModel:nil
                                               messageSender:Environment.shared.messageSender];
        if (success) success();
    }
}

@end
