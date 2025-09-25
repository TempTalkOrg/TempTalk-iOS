//
//  DTCombinedForwardingMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/23.
//

#import "DTCombinedForwardingMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "OWSDisappearingMessagesConfiguration.h"
#import "TSThread.h"
#import "SignalRecipient.h"
#import "TSIncomingMessage.h"
#import "TSAttachmentPointer.h"
#import "OWSAttachmentsProcessor.h"
#import "TSAccountManager.h"
#import "TSAttachment.h"
#import "TSAttachmentStream.h"
#import "TSIncomingMessage.h"
#import "TSInteraction.h"
#import "TSOutgoingMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTParamsBaseUtils.h"
#import "DTMention.h"

@interface DTCombinedForwardingMessage ()

@end

@implementation DTCombinedForwardingMessage

- (void)downloadAttachment:(NSString *)attachmentId
            origionMessage:(TSMessage *)origionMessage
                   message:(DTCombinedForwardingMessage *)message
               transaction:(nonnull SDSAnyWriteTransaction *)transaction
                   success:(void(^)(TSAttachmentStream *attachmentStream))success
                   failure:(void(^)(NSError *error))failure{
    TSAttachmentPointer *attachmentPointer =
        [TSAttachmentPointer anyFetchAttachmentPointerWithUniqueId:attachmentId
                                                       transaction:transaction];

    if ([attachmentPointer isKindOfClass:[TSAttachmentPointer class]]) {
        OWSAttachmentsProcessor *attachmentProcessor =
            [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer];

        DDLogDebug(
            @"%@ downloading forwarding attachment for message: %lu", self.logTag, (unsigned long)message.timestamp);
        [attachmentProcessor fetchAttachmentsForMessage:origionMessage forceDownload:NO
            transaction:transaction
            success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                DDLogInfo(@"%@ success to download forwarding attachment!" ,self.logTag);
                success(attachmentStream);
            }
            failure:^(NSError *_Nonnull error) {
                DDLogWarn(@"%@ failed to fetch forwarding attachment for message: %lu with error: %@",
                    self.logTag,
                    (unsigned long)message.timestamp,
                    error);
                failure(error);
            }];
    }else{
        if(success){
            success(nil);
        }
    }
}

- (void)handleForwardingAttachmentsWithOrigionMessage:(nullable TSMessage *)origionMessage
                                          transaction:(nonnull SDSAnyWriteTransaction *)transaction
                                           completion:(nullable void(^)(TSAttachmentStream * attachmentStream))completion {
    
    [self.subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
        [message.forwardingAttachmentIds enumerateObjectsUsingBlock:^(NSString * _Nonnull attachmentId, NSUInteger idx, BOOL * _Nonnull stop) {
            if(DTParamsUtils.validateString(attachmentId)){
                [self downloadAttachment:attachmentId origionMessage:origionMessage message:self transaction:transaction success:^(TSAttachmentStream *attachmentStream) {
                    
                    if (completion) completion(attachmentStream);
                } failure:^(NSError *error) {
                    
                }];
            }
        }];
    }];
    
}

- (void)handleAllForwardingAttachmentsWithTransaction:(nonnull SDSAnyWriteTransaction *)transaction
                                           completion:(void(^)(NSError *error))completion {
    
    dispatch_group_t group = dispatch_group_create();
    __block NSError *competionError;
    [[self allForwardingAttachmentIds] enumerateObjectsUsingBlock:^(NSString * attachmentId, NSUInteger idx, BOOL * _Nonnull stop) {
        if(DTParamsUtils.validateString(attachmentId)){
            dispatch_group_enter(group);
            [self downloadAttachment:attachmentId origionMessage:nil message:self transaction:transaction success:^(TSAttachmentStream *attachmentStream) {
                dispatch_group_leave(group);
            } failure:^(NSError *error) {
                competionError = error;
                dispatch_group_leave(group);
            }];
        }
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if(completion){
            completion(competionError);
        }
    });
}


- (instancetype)initWithTimestamp:(uint64_t)timestamp
                  serverTimestamp:(uint64_t)serverTimestamp
                         authorId:(NSString *)authorId
                      isFromGroup:(BOOL)isFromGroup
                      messageType:(int32_t)messageType
                             body:(NSString *_Nullable)body
          forwardingAttachmentIds:(NSArray<NSString *> * _Nullable)attachmentIds
    
{
    OWSAssertDebug(timestamp > 0);
    OWSAssertDebug(authorId.length > 0);

    self = [super init];
    if (!self) {
        return nil;
    }

    _timestamp = timestamp;
    _serverTimestamp = serverTimestamp;
    _authorId = authorId;
    _isFromGroup = isFromGroup;
    _messageType = messageType;
    _body = body;
    _forwardingAttachmentIds = attachmentIds;

    return self;
}

+ (void)handleMessageLevel:(DTCombinedForwardingMessage *)forwardingMessage level:(NSInteger)level{
    
    if(level >= 2){
        if(forwardingMessage.subForwardingMessages.count){
            forwardingMessage.subForwardingMessages = @[];
            forwardingMessage.messageType = DSKProtoDataMessageForwardTypeEof;
            forwardingMessage.body = [NSString stringWithFormat:@"[%@]",Localized(@"CANNOT_DISPLAYED_MESSAGE_TIP",nil)];
        }
    }else{
        [forwardingMessage.subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self handleMessageLevel:obj level:(level + 1)];
        }];
    }
}

+ (DTCombinedForwardingMessage *_Nullable)buildCombinedForwardingMessageForSendingWithMessages:(NSArray<TSMessage *> *)messages
                                                                                   isFromGroup:(BOOL)isFromGroup
                                                                                   transaction:(nonnull SDSAnyWriteTransaction *)transaction {
    NSString *authorId = [[TSAccountManager shared] localNumberWithTransaction:transaction];
    // 3.1.4
    // 发送合并转发消息前需要组装 forwordContext，iOS 存放 fordContext 也是使用的 DTCombinedForwardingMessage 模型，
    // 但实际 fordContext 并没有 serverTimestamp，接收方也并不会用到，接收方只会取 fordContext 对应上一层的 TSMessage 的 serverTimestamp，
    // 所以这里给 serverTimestamp 设置一个默认值，确保编译通过
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    DTCombinedForwardingMessage * forwardingMessage = [[DTCombinedForwardingMessage alloc] initWithTimestamp:timestamp
                                                                                             serverTimestamp:timestamp
                                                                                                    authorId:authorId
                                                                                                 isFromGroup:isFromGroup
                                                                                                 messageType:DSKProtoDataMessageForwardTypeNormal
                                                                                                        body:[NSString stringWithFormat:@"[%@]",Localized(@"FORWARD_MESSAGE_CHAT_HISTORY",nil)]
                                                                                     forwardingAttachmentIds:nil];

    
    NSMutableArray *subForwardingMessages = @[].mutableCopy;
    [messages enumerateObjectsUsingBlock:^(TSMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        DTCombinedForwardingMessage * subForwardingMessage = nil;
        if(obj.combinedForwardingMessage){
            DTCombinedForwardingMessage *newForwardingMessage = [self buildSingleForwardingMessageWithMessage:obj.combinedForwardingMessage transaction:transaction];
            [self handleMessageLevel:newForwardingMessage level:0];
            subForwardingMessage = newForwardingMessage;
        }else{
            uint64_t timestamp = obj.timestamp;
            
            NSString *authorId = nil;
            __block NSString *body = nil;
            
            if([obj isKindOfClass:[TSMessage class]]){
                if ([obj isKindOfClass:[TSIncomingMessage class]]) {
                    authorId = ((TSIncomingMessage *)obj).authorId;
                } else if ([obj isKindOfClass:[TSOutgoingMessage class]]) {
                    authorId = [TSAccountManager localNumber];
                }
                if (obj.contactShare) {
                    body = @"[Contact Card]";
                } else {
                    body = obj.body;
                }
            }else{
                OWSFailDebug(@"%@ unknown forwarding message", self.logTag);
                return;
            }
            
            DTCardMessageEntity *targetCard = obj.card;
            if (obj.cardUniqueId.length) {
                DTCardMessageEntity *latestCard = [DTCardMessageEntity anyFetchWithUniqueId:obj.cardUniqueId
                                                                                transaction:transaction];
                if(latestCard && latestCard.version > obj.card.version){
                    targetCard = latestCard;
                    body = latestCard.content;
                }
            }
            
            // 3.1.4 组装 Combined Forword Message 时，submessage 的 serverTimestamp = 原始消息的 serverTimestamp
            subForwardingMessage = [[DTCombinedForwardingMessage alloc] initWithTimestamp:timestamp
                                                                          serverTimestamp:obj.serverTimestamp
                                                                                 authorId:authorId
                                                                              isFromGroup:isFromGroup
                                                                              messageType:DSKProtoDataMessageForwardTypeNormal
                                                                                     body:body
                                                                  forwardingAttachmentIds:nil];
            subForwardingMessage.card = targetCard;
            
            subForwardingMessage.forwardingMentions = obj.mentions;
            NSMutableArray<NSString *> *attachmentIds = [NSMutableArray new];
            [obj.attachmentIds enumerateObjectsUsingBlock:^(NSString * attachmentId, NSUInteger idx, BOOL * _Nonnull stop) {
                
                TSAttachment *originAttachment = [TSAttachment anyFetchWithUniqueId:attachmentId transaction:transaction];
                TSAttachment *copiedAttachment = nil;
                if([originAttachment isKindOfClass:[TSAttachmentPointer class]]){
                    //支持转发本地未下载的附件，这里 copy 一下是防止原始消息被撤回或删除，导致关联的 attachment 信息被删除
                    TSAttachmentPointer *originAttachmentPointer = (TSAttachmentPointer *)originAttachment;
                    copiedAttachment = [[TSAttachmentPointer alloc] initWithServerId:originAttachmentPointer.serverId
                                                                                 key:originAttachmentPointer.encryptionKey
                                                                              digest:originAttachmentPointer.digest
                                                                           byteCount:originAttachmentPointer.byteCount
                                                                         contentType:originAttachmentPointer.contentType
                                                                               relay:originAttachmentPointer.relay
                                                                      sourceFilename:originAttachmentPointer.sourceFilename
                                                                      attachmentType:originAttachmentPointer.attachmentType
                                                                      albumMessageId:nil
                                                                             albumId:nil];
                    if(copiedAttachment) {
                        [copiedAttachment anyInsertWithTransaction:transaction];
                        if(copiedAttachment.uniqueId) {
                            [attachmentIds addObject:copiedAttachment.uniqueId];
                        }
                    }
                }else if ([originAttachment isKindOfClass:[TSAttachmentStream class]]){
                    TSAttachmentStream *originAttachmentStream = (TSAttachmentStream *)originAttachment;
                    copiedAttachment = [[TSAttachmentStream alloc] initWithContentType:originAttachmentStream.contentType byteCount:originAttachmentStream.byteCount sourceFilename:originAttachmentStream.sourceFilename albumMessageId:nil albumId:nil];
                    // 复制文件后记录下文件之前上传时的 hash 值：encryptionKey，在转发前需要校验 hash 判断本地文件是否被篡改
                    copiedAttachment.encryptionKey = originAttachment.encryptionKey;
                    NSError *error;
                    BOOL copyResult = [[NSFileManager defaultManager] copyItemAtPath:originAttachmentStream.filePath
                                                                              toPath:((TSAttachmentStream *)copiedAttachment).filePath
                                                                               error:&error];
                    if(error || !copyResult){
                        NSString *errorLog = [NSString stringWithFormat:@"%@ copy error: %@", self.logTag, error.description];
                        OWSProdError(errorLog);
                    }
                    
                    if(copiedAttachment){
                        [copiedAttachment anyInsertWithTransaction:transaction];
                        if(copiedAttachment.uniqueId){
                            [attachmentIds addObject:copiedAttachment.uniqueId];
                        }
                    }
                    
                }else{
                    
                }
                
            }];
            
            subForwardingMessage.forwardingAttachmentIds = attachmentIds.copy;
            
            
            if(timestamp <= 0 || !authorId.length || !(body.length || attachmentIds.count)){
                NSString *errorLog = [NSString stringWithFormat:@"%@ forwarding message missing id", self.logTag];
                OWSProdError(errorLog);
                return;
            }
            
            
        }
        
        if(subForwardingMessage){
            [subForwardingMessages addObject:subForwardingMessage];
        }
        
    }];
    
    forwardingMessage.subForwardingMessages = subForwardingMessages.copy;
    
    return forwardingMessage;
}

+ (DTCombinedForwardingMessage *_Nullable)buildSingleForwardingMessageWithMessage:(DTCombinedForwardingMessage *)message
                                                                      transaction:(nonnull SDSAnyWriteTransaction *)transaction{
    DTCombinedForwardingMessage * forwardingMessage = [message copy];
    
    NSMutableArray *subItems = @[].mutableCopy;
    
    [forwardingMessage.subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull subForwardingMessage, NSUInteger idx, BOOL * _Nonnull stop) {
        
        DTCombinedForwardingMessage *newMessage = [self buildSingleForwardingMessageWithMessage:subForwardingMessage transaction:transaction];
        NSMutableArray *attachmentIds = @[].mutableCopy;
        __block NSString *body = nil;
        [subForwardingMessage.forwardingAttachmentIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            TSAttachment *attachment = [TSAttachment anyFetchWithUniqueId:obj transaction:transaction];
            TSAttachment *copiedAttachment = nil;
            if([attachment isKindOfClass:[TSAttachmentPointer class]]){
                //支持转发本地未下载的附件，这里 copy 一下是防止原始消息被撤回或删除，导致关联的 attachment 信息被删除
                TSAttachmentPointer *originAttachmentPointer = (TSAttachmentPointer *)attachment;
                copiedAttachment = [[TSAttachmentPointer alloc] initWithServerId:originAttachmentPointer.serverId
                                                                             key:originAttachmentPointer.encryptionKey
                                                                          digest:originAttachmentPointer.digest
                                                                       byteCount:originAttachmentPointer.byteCount
                                                                     contentType:originAttachmentPointer.contentType
                                                                           relay:originAttachmentPointer.relay
                                                                  sourceFilename:originAttachmentPointer.sourceFilename
                                                                  attachmentType:originAttachmentPointer.attachmentType
                                                                  albumMessageId:nil
                                                                         albumId:nil];
                if(copiedAttachment) {
                    [copiedAttachment anyInsertWithTransaction:transaction];
                    if(copiedAttachment.uniqueId) {
                        [attachmentIds addObject:copiedAttachment.uniqueId];
                    }
                }
                
            }else if ([attachment isKindOfClass:[TSAttachmentStream class]]){
                TSAttachmentStream *originAttachmentStream = (TSAttachmentStream *)attachment;
                copiedAttachment = [[TSAttachmentStream alloc] initWithContentType:originAttachmentStream.contentType byteCount:originAttachmentStream.byteCount sourceFilename:originAttachmentStream.sourceFilename albumMessageId:nil albumId:nil];
                // 复制文件后记录下文件之前上传时的 hash 值：encryptionKey，在转发前需要校验 hash 判断本地文件是否被篡改
                copiedAttachment.encryptionKey = originAttachmentStream.encryptionKey;
                NSError *error;
                BOOL copyResult = [[NSFileManager defaultManager] copyItemAtPath:originAttachmentStream.filePath
                                                                          toPath:((TSAttachmentStream *)copiedAttachment).filePath
                                                                           error:&error];
                if(error || !copyResult){
                    NSString *errorLog = [NSString stringWithFormat:@"%@ copy error: %@", self.logTag, error.description];
                    OWSProdError(errorLog);
                }
                
                if(copiedAttachment){
                    [copiedAttachment anyInsertWithTransaction:transaction];
                    if(copiedAttachment.uniqueId){
                        [attachmentIds addObject:copiedAttachment.uniqueId];
                    }
                }
                
            }else{
                
            }
            
        }];
        
        newMessage.forwardingAttachmentIds = attachmentIds.copy;
        
        if(body.length){
            newMessage.body = body;
        }
        
        if(newMessage){
            [subItems addObject:newMessage];
        }
    }];
    
    forwardingMessage.subForwardingMessages = subItems.copy;
    
    
    
    return forwardingMessage;
}

// 组装 forwordContext 这层的数据，iOS 也是用的 DSKProtoDataMessageForward 模型，和 forwordContext 中的 forwords 相同
+ (DSKProtoDataMessageForward *)buildRootForwardProtoWithForwardContextProto:(DSKProtoDataMessageForwardContext *)forwardContextProto
                                                                   timestamp:(uint64_t)timestamp
                                                             serverTimestamp:(uint64_t)serverTimestamp
                                                                      author:(nonnull NSString *)author
                                                                        body:(nonnull NSString *)body {
    DSKProtoDataMessageForwardBuilder *forwardBuilder = [DSKProtoDataMessageForward builder];
    forwardBuilder.id = timestamp;
    [forwardBuilder setServerTimestamp:serverTimestamp];
    forwardBuilder.text = [NSString stringWithFormat:@"[%@]",Localized(@"FORWARD_MESSAGE_CHAT_HISTORY",nil)];
    forwardBuilder.author = author;
    if(forwardContextProto.forwards.count){
        forwardBuilder.isFromGroup = forwardContextProto.forwards.firstObject.isFromGroup;
        [forwardBuilder setForwards:forwardContextProto.forwards];
    }
    DSKProtoDataMessageForward *forward = [forwardBuilder buildAndReturnError:nil];
    return forward;
}

+ (DTCombinedForwardingMessage *_Nullable)forwardingMessageForDataMessage:(DSKProtoDataMessageForward *)forwardProto
                                                                 threadId:(NSString *)threadId
                                                                messageId:(NSString *)messageId
                                                                    relay:(nullable NSString *)relay
                                                              transaction:(SDSAnyWriteTransaction *)transaction{
    OWSAssertDebug(forwardProto);

    if (!forwardProto) {
        return nil;
    }
    
    if (![forwardProto hasID] || [forwardProto id] == 0) {
        OWSFailDebug(@"%@ forwarding message missing id", self.logTag);
        return nil;
    }
    uint64_t timestamp = [forwardProto id];

    if (![forwardProto hasAuthor] || [forwardProto author].length == 0) {
        OWSFailDebug(@"%@ forwarding message missing author", self.logTag);
        return nil;
    }
    
    NSString *authorId = [forwardProto author];

    NSString *_Nullable body = nil;
    BOOL hasText = NO;
    BOOL hasAttachment = NO;
    if ([forwardProto hasText] && [forwardProto text].length > 0) {
        body = [forwardProto text];
        hasText = YES;
    }

    NSMutableArray<NSString *> *attachmentIds = [NSMutableArray new];
    for (DSKProtoAttachmentPointer *forwardedAttachment in forwardProto.attachments) {
        hasAttachment = YES;
        if(forwardedAttachment.flags & DSKProtoAttachmentPointerFlagsVoiceMessage){
            body = [NSString stringWithFormat:@"[%@]",Localized(@"ATTACHMENT_TYPE_VOICE_MESSAGE",nil)];
        }else{
            TSAttachmentPointer *attachmentPointer =
            [TSAttachmentPointer attachmentPointerFromProto:forwardedAttachment
                                                      relay:relay
                                             albumMessageId:messageId
                                                    albumId:threadId];
            [attachmentPointer anyInsertWithTransaction:transaction];
            if(attachmentPointer.uniqueId){
                [attachmentIds addObject:attachmentPointer.uniqueId];
            }
        }
    
    }
    
    if(forwardProto.forwards.count){
        body = [NSString stringWithFormat:@"[%@]",Localized(@"FORWARD_MESSAGE_CHAT_HISTORY",nil)];
        hasText = YES;
    }else{
        
        switch (forwardProto.type) {
            case DSKProtoDataMessageForwardTypeNormal:
            {
                
            }
                
                break;
            case DSKProtoDataMessageForwardTypeEof:
            {
                body = [NSString stringWithFormat:@"[%@]",Localized(@"CANNOT_DISPLAYED_MESSAGE_TIP",nil)];
                hasText = YES;
            }
                
                break;
                
            default:
            {
                body = [NSString stringWithFormat:@"[%@]",Localized(@"UNSUPPORTED_MESSAGE_TIP",nil)];
                hasText = YES;
            }
                break;
        }
        
    }
    
    BOOL isFromGroup = forwardProto.isFromGroup;

    if (!hasText && !hasAttachment && !forwardProto.forwards.count && !forwardProto.card) {
        OWSFailDebug(@"%@ forwarding message has neither text nor attachment or forwards", self.logTag);
        return nil;
    }
    
    DTCombinedForwardingMessage * forwardingMessage = [[DTCombinedForwardingMessage alloc] initWithTimestamp:timestamp
                                                                                             serverTimestamp:forwardProto.serverTimestamp
                                                                                                    authorId:authorId
                                                                                                 isFromGroup:isFromGroup
                                                                                                 messageType:forwardProto.type
                                                                                                        body:body
                                                                                     forwardingAttachmentIds:attachmentIds.copy];
    
    if(forwardProto.card){
        forwardingMessage.card = [DTCardMessageEntity cardEntityWithProto:forwardProto.card];
    }
    
    if (DTParamsUtils.validateArray(forwardProto.mentions)) {
        forwardingMessage.forwardingMentions = [DTMention mentionsWithMentionsProto:forwardProto.mentions];
    }
    
    NSMutableArray *subForwardingMessages = @[].mutableCopy;
    [forwardProto.forwards enumerateObjectsUsingBlock:^(DSKProtoDataMessageForward * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DTCombinedForwardingMessage *subForwardingMessage = [self
                                                             forwardingMessageForDataMessage:obj
                                                             threadId:threadId
                                                             messageId:messageId
                                                             relay:relay
                                                             transaction:transaction];
        if(subForwardingMessage){
            [subForwardingMessages addObject:subForwardingMessage];
        }
    }];
    forwardingMessage.subForwardingMessages = subForwardingMessages.copy;
    if(forwardProto.forwards.count){
        forwardingMessage.isFromGroup = forwardProto.forwards.firstObject.isFromGroup;
    }

    return forwardingMessage;
}

- (NSArray<TSAttachmentStream *> *)forwardingAttachmentStreamsWithTransaction:(SDSAnyReadTransaction *)transaction{
    NSMutableArray<TSAttachment *> *items = @[].mutableCopy;
    [[self allForwardingAttachmentIds] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TSAttachment *attachment = [TSAttachment anyFetchWithUniqueId:obj transaction:transaction];
        if([attachment isKindOfClass:[TSAttachmentStream class]]){
            [items addObject:attachment];
        }
    }];
    return items.copy;
}

- (NSArray<TSAttachment *> *)forwardingAttachmentsWithTransaction:(SDSAnyReadTransaction *)transaction {
    NSMutableArray<TSAttachment *> *items = @[].mutableCopy;
    [[self allForwardingAttachmentIds] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        TSAttachment *attachment = [TSAttachment anyFetchWithUniqueId:obj transaction:transaction];
        [items addObject:attachment];
    }];
    return items.copy;
}

- (NSArray<NSString *> *)allForwardingAttachmentIds{
    NSMutableArray<NSString *> *items = @[].mutableCopy;
    [self.forwardingAttachmentIds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [items addObject:obj];
    }];
    
    [self.subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<NSString *> *subItems = [obj allForwardingAttachmentIds];
        if(subItems.count){
            [items addObjectsFromArray:subItems];
        }
    }];
    return items.copy;
}

@end
