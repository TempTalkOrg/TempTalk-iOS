//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ThreadUtil.h"
//#import "OWSContactOffersInteraction.h"
#import "OWSContactsManager.h"
#import "OWSQuotedReplyModel.h"
#import "OWSUnreadIndicator.h"
#import "TSUnreadIndicatorInteraction.h"
#import <TTMessaging/OWSProfileManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <SignalCoreKit/NSDate+OWS.h>
//#import <TTServiceKit/OWSAddToProfileWhitelistOfferMessage.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/OWSMessageSender.h>
//#import <TTServiceKit/OWSUnknownContactBlockOfferMessage.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSContactThread.h>
//
//#import <TTServiceKit/TSInvalidIdentityKeyErrorMessage.h>
#import <TTServiceKit/TSThread.h>
#import "DTRecallMessagesJob.h"
#import <TTServiceKit/DTCardOutgoingMessage.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/DTScreenShotOutgoingMessage.h>


NS_ASSUME_NONNULL_BEGIN

@interface ThreadDynamicInteractions ()

@property (nonatomic, nullable) NSNumber *focusMessagePosition;

@property (nonatomic, nullable) OWSUnreadIndicator *unreadIndicator;

@end

#pragma mark -

@implementation ThreadDynamicInteractions

- (void)clearUnreadIndicatorState
{
    self.unreadIndicator = nil;
}

@end

#pragma mark -

@implementation ThreadUtil

+ (TSOutgoingMessage *)sendMessageWithText:(NSString *)text
                                 atPersons:(nullable NSString *)atPersons
                                  mentions:(nullable NSArray <DTMention *> *)mentions
                                  inThread:(TSThread *)thread
                          quotedReplyModel:(nullable DTReplyModel *)replyModel
                             messageSender:(OWSMessageSender *)messageSender
{
    return [self sendMessageWithText:text
                           atPersons:atPersons
                            mentions:mentions
                            inThread:thread
                    quotedReplyModel:replyModel
                       messageSender:messageSender
                             success:^{
        OWSLogInfo(@"%@ Successfully sent message.", self.logTag);
    }
                             failure:^(NSError *error) {
        DDLogWarn(@"%@ Failed to deliver message with error: %@", self.logTag, error);
    }];
}


+ (TSOutgoingMessage *)sendMessageWithText:(NSString *)text
                                 atPersons:(nullable NSString *)atPersons
                                  mentions:(nullable NSArray <DTMention *> *)mentions
                                  inThread:(TSThread *)thread
                          quotedReplyModel:(nullable DTReplyModel *)replyModel
                             messageSender:(OWSMessageSender *)messageSender
                                   success:(void (^)(void))successHandler
                                   failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(thread);
    OWSAssertDebug(messageSender);
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    TSOutgoingMessage *message = [TSOutgoingMessage outgoingMessageInThread:thread
                                                                messageBody:text
                                                                  atPersons:atPersons
                                                                   mentions:mentions
                                                               attachmentId:nil
                                                           expiresInSeconds:expiresInSeconds
                                                              quotedMessage:(TSQuotedMessage *)[replyModel buildMessage]
                                                          forwardingMessage:nil];
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    message.messageModeType = thread.conversationEntity.confidentialMode;
    //⚠️ 时机待确认 需要更新历史消息
    [messageSender enqueueMessage:message success:^{
        if (successHandler) {
            successHandler();
        }
    } failure:failureHandler];
    return message;
}

+ (TSOutgoingMessage *)sendMessageWithAttachment:(SignalAttachment *)attachment
                                        inThread:(TSThread *)thread
                                quotedReplyModel:(nullable DTReplyModel *)quotedReplyModel
                          preSendMessageCallBack:(nullable void (^)(TSOutgoingMessage *))preSendMessageCallBack
                                   messageSender:(OWSMessageSender *)messageSender
                                      completion:(void (^_Nullable)(NSError *_Nullable error))completion
{
    return [self sendMessageWithAttachment:attachment
                                  inThread:thread
                          quotedReplyModel:quotedReplyModel
                    preSendMessageCallBack:preSendMessageCallBack
                             messageSender:messageSender
                              ignoreErrors:NO
                                completion:completion];
}

+ (TSOutgoingMessage *)sendMessageWithAttachment:(SignalAttachment *)attachment
                                        inThread:(TSThread *)thread
                                quotedReplyModel:(nullable DTReplyModel *)replyModel
                          preSendMessageCallBack:(nullable void (^)(TSOutgoingMessage *))preSendMessageCallBack
                                   messageSender:(OWSMessageSender *)messageSender
                                    ignoreErrors:(BOOL)ignoreErrors
                                      completion:(void (^_Nullable)(NSError *_Nullable error))completion
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(attachment);
    OWSAssertDebug(ignoreErrors || ![attachment hasError]);
    OWSAssertDebug([attachment mimeType].length > 0);
    OWSAssertDebug(thread);
    OWSAssertDebug(messageSender);
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    TSOutgoingMessage *message =
    [[TSOutgoingMessage alloc] initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                       inThread:thread
                                                    messageBody:attachment.captionText
                                                      atPersons:nil
                                                       mentions:nil
                                                  attachmentIds:[NSMutableArray new]
                                               expiresInSeconds:expiresInSeconds
                                                expireStartedAt:0
                                                 isVoiceMessage:[attachment isVoiceMessage]
                                               groupMetaMessage:TSGroupMessageUnspecified
                                                  quotedMessage:(TSQuotedMessage *)[replyModel buildMessage]
                                              forwardingMessage:nil
                                                   contactShare:nil];
    
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    message.messageModeType = thread.conversationEntity.confidentialMode;
    [messageSender enqueueAttachment:attachment.dataSource
                         contentType:attachment.mimeType
                      sourceFilename:attachment.filenameOrDefault
                           inMessage:message
              preSendMessageCallBack:^(TSOutgoingMessage * _Nonnull preSendMessage) {
        if (preSendMessageCallBack) {
            preSendMessageCallBack(preSendMessage);
        }
    }
                             success:^{
        DDLogDebug(@"%@ Successfully sent message attachment.", self.logTag);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                completion(nil);
            });
        }
    }
                             failure:^(NSError *error) {
        DDLogError(@"%@ Failed to send message attachment with error: %@", self.logTag, error);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                completion(error);
            });
        }
    }];
    
    return message;
}

+ (TSOutgoingMessage *)sendMessageWithContactShare:(OWSContact *)contactShare
                                          inThread:(TSThread *)thread
                                     messageSender:(OWSMessageSender *)messageSender
                                        completion:(void (^_Nullable)(NSError *_Nullable error))completion
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);
    OWSAssertDebug(contactShare.ows_isValid);
    OWSAssertDebug(thread);
    OWSAssertDebug(messageSender);
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    TSOutgoingMessage *message =
    [[TSOutgoingMessage alloc] initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                       inThread:thread
                                                    messageBody:nil
                                                      atPersons:nil
                                                       mentions:nil
                                                  attachmentIds:[NSMutableArray new]
                                               expiresInSeconds:expiresInSeconds
                                                expireStartedAt:0
                                                 isVoiceMessage:NO
                                               groupMetaMessage:TSGroupMessageUnspecified
                                                  quotedMessage:nil
                                              forwardingMessage:nil
                                                   contactShare:contactShare];
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    message.messageModeType = thread.conversationEntity.confidentialMode;
    [messageSender enqueueMessage:message
                          success:^{
        DDLogDebug(@"%@ Successfully sent contact share.", self.logTag);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                completion(nil);
            });
        }
    }
                          failure:^(NSError *error) {
        DDLogError(@"%@ Failed to send contact share with error: %@", self.logTag, error);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                completion(error);
            });
        }
    }];
    
    return message;
}


#pragma mark - Dynamic Interactions

+ (BOOL)shouldShowGroupProfileBannerInThread:(TSThread *)thread blockingManager:(OWSBlockingManager *)blockingManager transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(thread);
    OWSAssertDebug(blockingManager);
    
    if (!thread.isGroupThread) {
        return NO;
    }
    if ([OWSProfileManager.sharedManager isThreadInProfileWhitelist:thread]) {
        return NO;
    }
    if (![OWSProfileManager.sharedManager hasLocalProfileWithTransaction:transaction]) {
        return NO;
    }
    BOOL hasUnwhitelistedMember = NO;
    NSArray<NSString *> *blockedPhoneNumbers = [blockingManager blockedPhoneNumbers];
    for (NSString *recipientId in thread.recipientIdentifiers) {
        if (![blockedPhoneNumbers containsObject:recipientId]
            && ![OWSProfileManager.sharedManager isUserInProfileWhitelist:recipientId]) {
            hasUnwhitelistedMember = YES;
            break;
        }
    }
    if (!hasUnwhitelistedMember) {
        return NO;
    }
    return YES;
}

+ (BOOL)addThreadToProfileWhitelistIfEmptyContactThread:(TSThread *)thread
{
    OWSAssertDebug(thread);
    
    if (thread.isGroupThread) {
        return NO;
    }
    if ([OWSProfileManager.sharedManager isThreadInProfileWhitelist:thread]) {
        return NO;
    }
    if (!thread.shouldBeVisible) {
        [OWSProfileManager.sharedManager addThreadToProfileWhitelist:thread];
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Delete Content

+ (void)deleteAllContent
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [TSThread anyRemoveAllWithInstantationWithTransaction:transaction];
        [TSInteraction anyRemoveAllWithInstantationWithTransaction:transaction];
        [TSAttachment anyRemoveAllWithInstantationWithTransaction:transaction];
        [SignalRecipient anyRemoveAllWithInstantationWithTransaction:transaction];
        
        // Deleting attachments above should be enough to remove any gallery items, but
        // we redunantly clean up *all* gallery items to be safe.
    });
    [TSAttachmentStream deleteAttachments];
}

+ (void)removeAllObjectsInCollection:(NSString *)collection
                              aClass:(Class)aClass
                         transaction:(SDSAnyReadTransaction *)transaction {
    OWSAssertDebug(collection.length > 0);
    OWSAssertDebug(aClass);
    OWSAssertDebug(transaction);
    
    //MARK GRDB need to focus on
}

+ (BOOL)shouldArchiveThreads{
    return (CurrentAppContext().isMainApp && CurrentAppContext().isAppForegroundAndActive);
}

+ (void)archiveThreadsWithItems:(NSMutableArray<TSThread *> *)items
                  oversizeItems:(NSMutableArray<TSThread *> *)oversizeItems
                      batchSize:(NSUInteger)batchSize{
    
    return;

    
    if(![self shouldArchiveThreads] ||
       (items.count == 0 && oversizeItems.count == 0)){
        return;
    }
    
    [BenchManager benchAsyncWithTitle:@"archiveInactiveConversations or archiveOversizeThreads" block:^(void (^ _Nonnull completeBenchmark)(void)) {
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            
            __block NSUInteger loopBatchIndex = 0;
            [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                TSThread *lastThread = items.lastObject;
                if (loopBatchIndex == batchSize || lastThread == nil || ![self shouldArchiveThreads]) {*stop = YES;return;}
                [lastThread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                    [t archiveThreadWithTransaction:writeTransaction];
                }];
                OWSLogInfo(@"archive inactive thread name: %@", [lastThread nameWithTransaction:writeTransaction]);
                [items removeLastObject];
                loopBatchIndex += 1;
            }];
            
            loopBatchIndex = 0;
            [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                TSThread *lastThread = oversizeItems.lastObject;
                if (loopBatchIndex == batchSize || lastThread == nil || ![self shouldArchiveThreads]) {*stop = YES;return;}
                [lastThread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull t) {
                    [t archiveOversizeThreadWithTransaction:writeTransaction];
                }];
                OWSLogInfo(@"archive oversize thread name: %@", [lastThread nameWithTransaction:writeTransaction]);
                [oversizeItems removeLastObject];
                loopBatchIndex += 1;
            }];
            
            [writeTransaction addAsyncCompletionOffMain:^{
                completeBenchmark();
                [self archiveThreadsWithItems:items oversizeItems:oversizeItems batchSize:100];
            }];
        });
    }];
    
}

+ (void)archiveInactiveConversations{
    
    return;
    
    if(![self shouldArchiveThreads]){
        return;
    }
    
    NSMutableArray<TSThread *> *items = @[].mutableCopy;
    NSMutableArray<TSThread *> *oversizeItems = @[].mutableCopy;
    [BenchManager benchWithTitle:@"read archiveInactiveConversations" block:^{
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            
            AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
            NSError *error;
            [finder enumerateInactiveThreadsWithTransaction:readTransaction
                                                      error:&error
                                                      block:^(TSThread * thread) {
                if (thread.isNoteToSelf) { return; }
                [items addObject:thread];
                
            }];
        }];
    }];
    
    if(![self shouldArchiveThreads]){
        return;
    }
    
    OWSLogInfo(@"will archive inactive thread count: %ld", items.count);
    OWSLogInfo(@"will archive oversize thread count: %ld", oversizeItems.count);
    
    [self archiveThreadsWithItems:items oversizeItems:oversizeItems batchSize:100];
}

#pragma mark - Find Content

+ (nullable TSInteraction *)findInteractionInThreadByTimestamp:(uint64_t)timestamp
                                                      authorId:(NSString *)authorId
                                                threadUniqueId:(NSString *)threadUniqueId
                                                   transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(timestamp > 0);
    OWSAssertDebug(authorId.length > 0);

    NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:transaction];
    if (localNumber.length < 1) {
        OWSFailDebug(@"%@ missing long number.", self.logTag);
        return nil;
    }
    
    NSError *error;
    NSArray<TSInteraction *> *interactions = (NSArray<TSInteraction *> *)[InteractionFinder interactionsWithTimestamp:timestamp
                                                                                                           filter:^(TSInteraction *interaction) {
        NSString *_Nullable messageAuthorId = nil;
        if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)interaction;
            messageAuthorId = incomingMessage.authorId;
        } else if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
            messageAuthorId = localNumber;
        }
        if (messageAuthorId.length < 1) {
            return NO;
        }

        if (![authorId isEqualToString:messageAuthorId]) {
            return NO;
        }
        if (![interaction.uniqueThreadId isEqualToString:threadUniqueId]) {
            return NO;
        }
        return YES;
    } transaction:transaction error:&error];

    if (error || interactions.count < 1) {
        return nil;
    }
    if (interactions.count > 1) {
        // In case of collision, take the first.
        DDLogError(@"%@ more than one matching interaction in thread.", self.logTag);
    }
    return interactions.firstObject;
}

#pragma mark - combined forwarding message

+ (TSOutgoingMessage *)sendMessageWithCombinedForwardingMessage:(DTCombinedForwardingMessage *)forwardingMessage
                                                      atPersons:(nullable NSString *)atPersons
                                                       mentions:(nullable NSArray<DTMention *> *)mentions
                                                       inThread:(TSThread *)thread
                                               quotedReplyModel:(nullable OWSQuotedReplyModel *)quotedReplyModel
                                                  messageSender:(OWSMessageSender *)messageSender
{
    return [self sendMessageWithCombinedForwardingMessage:forwardingMessage
                                                atPersons:atPersons
                                                 mentions:mentions
                                                 inThread:thread
                                         quotedReplyModel:quotedReplyModel
                                            messageSender:messageSender
                                                  success:^{
                    DDLogInfo(@"%@ Successfully sent combined forwarding message.", self.logTag);
        }
                                                  failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to deliver combined forwarding message with error: %@", self.logTag, error);
        }];
}


+ (TSOutgoingMessage *)sendMessageWithCombinedForwardingMessage:(DTCombinedForwardingMessage *)forwardingMessage
                                                      atPersons:(nullable NSString *)atPersons
                                                       mentions:(nullable NSArray<DTMention *> *)mentions
                                                       inThread:(TSThread *)thread
                                               quotedReplyModel:(nullable OWSQuotedReplyModel *)quotedReplyModel
                                                  messageSender:(OWSMessageSender *)messageSender
                                                        success:(void (^)(void))successHandler
                                                        failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(forwardingMessage.subForwardingMessages.count > 0);
    OWSAssertDebug(thread);
    OWSAssertDebug(messageSender);
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    TSOutgoingMessage *message = [TSOutgoingMessage outgoingMessageInThread:thread
                                                                messageBody:@"[Unsupported message type]"
                                                                  atPersons:atPersons
                                                                   mentions:mentions
                                                               attachmentId:nil
                                                           expiresInSeconds:expiresInSeconds
                                                              quotedMessage:(TSQuotedMessage *)[quotedReplyModel buildMessage]
                                                          forwardingMessage:forwardingMessage];
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    message.messageModeType = thread.conversationEntity.confidentialMode;
    [messageSender enqueueMessage:message success:successHandler failure:failureHandler];

    return message;
}

+ (TSOutgoingMessage *)sendScreenShotMessageInThread:(TSThread *)thread
                                             success:(void (^)(void))successHandler
                                             failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(thread);
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    DTRealSourceEntity *realSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:timestamp
                                                                            sourceDevice:[OWSDevice currentDeviceId]
                                                                                  source:[TSAccountManager localNumber]];
    DTScreenShotOutgoingMessage *message = [[DTScreenShotOutgoingMessage alloc] initWithTimestamp:timestamp realSource:realSource inThread:thread];
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    
    [self.messageSender enqueueMessage:message success:^{
        DDLogInfo(@"%@ Successfully sent screenshot message.", self.logTag);
        
        DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                         inThread:thread
                                                                      messageType:TSInfoMessageScreenshotMessage
                                                                 expiresInSeconds:expiresInSeconds
                                                                    customMessage:[NSString stringWithFormat:Localized(@"%@ took a screenshot!",nil), Localized(@"YOU",nil)]];
            [infoMessage anyInsertWithTransaction:writeTransaction];
            
            [writeTransaction addAsyncCompletionOnMain:^{
                if(successHandler){
                    successHandler();
                }
            }];
            
        }));
        
    } failure:^(NSError * _Nonnull error) {
        DDLogWarn(@"%@ Failed to deliver screenshot message with error: %@", self.logTag, error);
        if(failureHandler){
            failureHandler(error);
        }
    }];
    
    return message;
}

+ (TSOutgoingMessage *)sendRecallMessageWithOriginMessage:(TSOutgoingMessage *)originMessage
                                                 inThread:(TSThread *)thread
                                                  success:(void (^)(void))successHandler
                                                  failure:(void (^)(NSError *error))failureHandler{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(thread);
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    DTRealSourceEntity *originSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:originMessage.timestamp
                                                                              sourceDevice:originMessage.sourceDeviceId?:[OWSDevice currentDeviceId]
                                                                                    source:[TSAccountManager localNumber]
                                                                                sequenceId:originMessage.sequenceId
                                                                          notifySequenceId:originMessage.notifySequenceId];
    originSource.serverTimestamp = originMessage.serverTimestamp;
    
    DTRecallMessage *recallMessage = [[DTRecallMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                         source:originSource
                                                                           body:originMessage.body
                                                                      atPersons:originMessage.atPersons
                                                                       mentions:originMessage.mentions];
    
    DTRecallOutgoingMessage *message = [DTRecallOutgoingMessage recallOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                            recall:recallMessage
                                                                                          inThread:thread
                                                                                  expiresInSeconds:expiresInSeconds];
    message.originMessage = originMessage;
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    [self.messageSender enqueueMessage:message
                          success:^{
        DDLogInfo(@"%@ Successfully sent recall message.", self.logTag);
        
        DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
            
            //            [originMessage removeWithTransaction:transaction];
            
            NSMutableAttributedString *customString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE_WITH_EDIT",nil), Localized(@"YOU",nil)]];
            NSAttributedString *editString = [[NSAttributedString alloc] initWithString:Localized(@"RE-EDIT_MESSAGE",nil)
                                                                             attributes:@{
                NSForegroundColorAttributeName:[UIColor colorWithRGBHex:0x4c618c]
            }];
            [customString appendAttributedString:editString];
            
            
            NSString *previewSting = [NSString stringWithFormat:Localized(@"RECALL_INFO_MESSAGE",nil), Localized(@"YOU",nil)];
            
            if(!originMessage.isTextMessage){
                customString = [[NSMutableAttributedString alloc] initWithString:previewSting];
            }
            
            TSInfoMessage *recallInfoMessage = [[TSInfoMessage alloc] initWithTimestamp:originSource.timestamp
                                                                        serverTimestamp:originSource.serverTimestamp
                                                                               inThread:thread
                                                                       expiresInSeconds:originMessage.expiresInSeconds
                                                                          customMessage:customString];
            
            NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:writeTransaction];
            recallInfoMessage.sourceDeviceId = [OWSDevice currentDeviceId];
            recallInfoMessage.authorId = localNumber;
            recallInfoMessage.recall = recallMessage;
            recallInfoMessage.recallPreview = previewSting;
            if(originMessage.isTextMessage){
                recallInfoMessage.editable = YES;
            }
            // NOTE: 这里设置了和原始消息一样的 uniqueId，相当于覆盖了原始消息
            recallInfoMessage.uniqueId = originMessage.uniqueId;
            // 删除 model_TSMessageSecondary 中已经被被撤回的消息，避免在搜索时还能搜索到（实际展示的是空白）
            [[FullTextSearchFinder new] modelWasRemovedObjcWithModel:originMessage transaction:writeTransaction];
            
            if(!recallInfoMessage.grdbId && originMessage.grdbId){
                [recallInfoMessage updateRowId:originMessage.grdbId.longLongValue];
            }
           
            [recallInfoMessage anyUpsertWithTransaction:writeTransaction];
           
            [writeTransaction addAsyncCompletionOnMain:^{
                if(successHandler){
                    successHandler();
                }
                [[DTRecallMessagesJob sharedJob] startIfNecessary];
            }];
        }));
        
        [DTFileRequestHandler removeAuthorizeWithFileInfos:originMessage.rapidFiles
                                                completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
            
        }];
        
        
    } failure:^(NSError * _Nonnull error) {
        DDLogWarn(@"%@ Failed to deliver recall message with error: %@", self.logTag, error);
        if(failureHandler){
            failureHandler(error);
        }
    }];
    
    return message;
}


+ (TSOutgoingMessage *)sendReactionMessageWithEmoji:(NSString *)emoji
                                     remove:(BOOL)remove
                              targetMessage:(TSMessage *)targetMessage
                                   inThread:(TSThread *)thread
                                    success:(void (^)(void))successHandler
                                    failure:(void (^)(NSError * _Nonnull))failureHandler {
    
    OWSAssertIsOnMainThread();
    OWSAssertDebug(thread);
    
    //TODO: 防止非TSIncomingMessage/TSOutgoingMessage乱入造成reaction crash
    if (![targetMessage isKindOfClass:[TSIncomingMessage class]] && ![targetMessage isKindOfClass:[TSOutgoingMessage class]]) {
        OWSLogError(@"interaction is %@ class", targetMessage.class);
        return nil;
    }
    
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    uint32_t sourceDeviceId;
    NSString *authorId = nil;
    if ([targetMessage isKindOfClass:TSOutgoingMessage.class]) {
        sourceDeviceId = ((TSOutgoingMessage *)targetMessage).sourceDeviceId ?: [OWSDevice currentDeviceId];
        authorId = [TSAccountManager localNumber];
    } else {
        sourceDeviceId = ((TSIncomingMessage *)targetMessage).sourceDeviceId;
        authorId = ((TSIncomingMessage *)targetMessage).authorId;
    }
    
    DTReactionSource *oldReactionSource = nil;
    if (remove && DTParamsUtils.validateDictionary(targetMessage.reactionMap)) {
        NSArray <DTReactionSource *> *reactionSources = targetMessage.reactionMap[emoji];
        for (DTReactionSource *reactionSource in reactionSources) {
            if ([reactionSource.source isEqualToString:[TSAccountManager localNumber]]) {
                oldReactionSource = reactionSource;
                break;
            }
        }
        BOOL isBreakTimestamp = timestamp < oldReactionSource.timestamp;
        if (isBreakTimestamp) {
            timestamp = oldReactionSource.timestamp + 1;
        }
    }
    
    DTRealSourceEntity *realSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:targetMessage.timestamp sourceDevice:sourceDeviceId source:authorId];
    DTReactionMessage *reactionMessage = [[DTReactionMessage alloc] initWithEmoji:emoji source:realSource remove:remove];
    DTReactionOutgoingMessage *message = [DTReactionOutgoingMessage reactionOutgoingMessageWithTimestamp:timestamp reactionMessage:reactionMessage thread:thread];
    message.reactionInfo = [DTMergedReactionHandler buildParamsWithReactionMessage:reactionMessage removedReactionSource:oldReactionSource];
        
    [self.messageSender enqueueMessage:message
                               success:^{
                                
        if (successHandler) {
            successHandler();
        }
        
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:writeTransaction];
            DTRealSourceEntity *ownSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:message.timestamp sourceDevice:[OWSDevice currentDeviceId] source:localNumber];
            reactionMessage.ownSource = ownSource;
            reactionMessage.conversationId = thread.uniqueId;
            [reactionMessage saveWithTransaction:writeTransaction];
        });
    }
                               failure:failureHandler];
    
    return message;
}

@end

NS_ASSUME_NONNULL_END
