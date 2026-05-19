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
                     forceNormalMode:NO
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
                           forceNormalMode:(BOOL)forceNormalMode
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

    // Determine message mode type
    TSMessageModeType messageModeType = TSMessageModeTypeNormal;

    if (!forceNormalMode) {
        // Check if recipient is a friend (only for 1-on-1 contact threads)
        if ([thread isKindOfClass:[TSContactThread class]]) {
            TSContactThread *contactThread = (TSContactThread *)thread;
            NSString *recipientId = contactThread.contactIdentifier;

            __block BOOL isFriend = NO;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                SignalAccount *account = [SignalAccount anyFetchWithUniqueId:recipientId transaction:transaction];
                isFriend = account.isFriend;
            }];

            // Only use confidential mode if recipient is a friend
            if (isFriend) {
                messageModeType = thread.conversationEntity.confidentialMode;
            }
        } else {
            // For group threads, use thread's confidential mode setting
            messageModeType = thread.conversationEntity.confidentialMode;
        }
    }

    message.messageModeType = messageModeType;
    //⚠️ 时机待确认 需要更新历史消息
    [messageSender enqueueMessage:message success:^{
        if (successHandler) {
            successHandler();
        }
    } failure:failureHandler];
    return message;
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
    return [self sendMessageWithText:text
                           atPersons:atPersons
                            mentions:mentions
                            inThread:thread
                    quotedReplyModel:replyModel
                       messageSender:messageSender
                     forceNormalMode:NO
                             success:successHandler
                             failure:failureHandler];
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

    NSString *combinedForwardFallbackBody = [NSString stringWithFormat:@"[%@]", Localized(@"FORWARD_MESSAGE_CHAT_HISTORY", @"")];
    TSOutgoingMessage *message = [TSOutgoingMessage outgoingMessageInThread:thread
                                                                messageBody:combinedForwardFallbackBody
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
    return [self sendRecallMessageWithOriginMessage:originMessage
                                           inThread:thread
                                  explicitTimestamp:[NSDate ows_millisecondTimeStamp]
                                            success:successHandler
                                            failure:failureHandler];
}

+ (TSOutgoingMessage *)sendRecallMessageWithOriginMessage:(TSOutgoingMessage *)originMessage
                                                 inThread:(TSThread *)thread
                                        explicitTimestamp:(uint64_t)explicitTimestamp
                                                  success:(void (^)(void))successHandler
                                                  failure:(void (^)(NSError *error))failureHandler{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(thread);

    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];

    NSString *localNumber = [TSAccountManager localNumber];
    DTRealSourceEntity *originSource = [[DTRealSourceEntity alloc] initSourceWithTimestamp:originMessage.timestamp
                                                                              sourceDevice:originMessage.sourceDeviceId?:[OWSDevice currentDeviceId]
                                                                                    source:localNumber
                                                                                sequenceId:originMessage.sequenceId
                                                                          notifySequenceId:originMessage.notifySequenceId];
    originSource.serverTimestamp = originMessage.serverTimestamp;

    DTRecallMessage *recallMessage = [[DTRecallMessage alloc] initWithTimestamp:explicitTimestamp
                                                                         source:originSource];

    DTRecallOutgoingMessage *message = [DTRecallOutgoingMessage recallOutgoingMessageWithTimestamp:explicitTimestamp
                                                                                            recall:recallMessage
                                                                                          inThread:thread
                                                                                  expiresInSeconds:expiresInSeconds];
    message.originMessage = originMessage;
    message.sourceDeviceId = [OWSDevice currentDeviceId];
    [self.messageSender enqueueMessage:message
                          success:^{
        DDLogInfo(@"%@ Successfully sent recall message.", self.logTag);
        
        DatabaseStorageAsyncWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
            [originMessage anyRemoveWithTransaction:writeTransaction];
            [recallMessage insertRecordWithSource:localNumber
                                     sourceDevice:[OWSDevice currentDeviceId]
                                        timestamp:message.timestamp
                                      transaction:writeTransaction];
            [writeTransaction addAsyncCompletionOnMain:^{
                if(successHandler){
                    successHandler();
                }
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
