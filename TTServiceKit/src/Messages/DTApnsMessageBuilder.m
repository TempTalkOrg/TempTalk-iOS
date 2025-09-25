//
//  DTApnsMessageBuilder.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/26.
//

#import "DTApnsMessageBuilder.h"
#import "TSOutgoingMessage.h"
#import "TSThread.h"
#import "TSGroupThread.h"
#import "TSQuotedMessage.h"
#import "DTOutgoingCallMessage.h"
#import "DTHyperlinkOutgoingMessage.h"
#import "TSAccountManager.h"
#import "SignalRecipient.h"
#import "TSContactThread.h"
#import "DTRecallMessage.h"
#import "DTRecallOutgoingMessage.h"
#import <TTServiceKit/Localize_Swift.h>

@implementation DTApnsMessageInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
        @"messageType":@"type",
        @"groupID":@"args.gid",
        @"groupName":@"args.gname",
        @"passthrough":@"args.passthrough",
        @"mentionedPersons":@"args.mentionedPersons",
        @"collapseId":@"args.collapseId"
    };
}

//- (NSDictionary *)dictionaryValueWithoutNil{
//    NSMutableDictionary *modifiedDictionaryValue = [[super dictionaryValue] mutableCopy];
//
//    for (NSString *originalKey in [super dictionaryValue]) {
//        if ([self valueForKey:originalKey] == nil) {
//            [modifiedDictionaryValue removeObjectForKey:originalKey];
//        }
//    }
//
//    return [modifiedDictionaryValue copy];
//}

@end

@interface DTApnsMessageBuilder ()

@property (nonatomic, strong)TSOutgoingMessage *message;
@property (nonatomic, strong)TSThread *thread;
@property (nonatomic, strong)SignalRecipient *recipient;

@end

@implementation DTApnsMessageBuilder

- (instancetype)initWithMessage:(TSOutgoingMessage *)message
                         thread:(TSThread *)thread
                   forRecipient:(SignalRecipient *)recipient{
    
    if(self = [super init]){
        
        self.apnsMessageInfo = [[DTApnsMessageInfo alloc] init];
        self.message = message;
        self.thread = thread;
        self.recipient = recipient;
        
        [self handleMessage];
        
    }
    
    return self;
}

- (void)handleMessage{
    if(self.thread.isGroupThread){
        [self handleGroupMessage];
    }else{
        [self handleContactMessage];
    }
    [self handlePassthroughInfo];
}

- (void)handleGroupMessage{
    TSOutgoingMessage *message = self.message;
    NSString *recipientId = self.recipient.recipientId;
    
    self.apnsMessageInfo.collapseId = self.message.collapseId;
    
    if(message.hasAttachments){
        self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_FILE;
    }else if (message.quotedMessage.authorId){
        self.apnsMessageInfo.mentionedPersons = @[message.quotedMessage.authorId];
        if([message.quotedMessage.authorId isEqualToString:recipientId]){
            self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_REPLY_DESTINATION;
        }else{
            self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_REPLY_OTHER;
        }
    }else if([message isKindOfClass:[DTOutgoingCallMessage class]] &&
             ((DTOutgoingCallMessage *)self.message).apnsType){
        self.apnsMessageInfo.messageType = ((DTOutgoingCallMessage *)self.message).apnsType;
    }else if([message isKindOfClass:[DTHyperlinkOutgoingMessage class]] &&
             ((DTHyperlinkOutgoingMessage *)self.message).apnsType){
        self.apnsMessageInfo.messageType = ((DTHyperlinkOutgoingMessage *)self.message).apnsType;
    }else if (message.atPersons.length){
        NSArray *atPersons = [message.atPersons componentsSeparatedByString:@";"];
        NSMutableArray *editPersons = atPersons.mutableCopy;
        [editPersons enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if(!obj.length){
                [editPersons removeObject:obj];
            }
        }];
        atPersons = editPersons.copy;
        self.apnsMessageInfo.mentionedPersons = atPersons;
        if([atPersons containsObject:recipientId]){
            self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_MENTIONS_DESTINATION;
        }else if([atPersons containsObject:MENTIONS_ALL]){
            self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_MENTIONS_ALL;
        }else{
            self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_MENTIONS_OTHER;
        }
    }else if(self.message.recall){
        self.apnsMessageInfo.messageType = DTApnsMessageType_RECALL_MSG;
        if([self.message isKindOfClass:[DTRecallOutgoingMessage class]]){
            DTRecallOutgoingMessage *recallMessage = (DTRecallOutgoingMessage *)self.message;
            if(recallMessage.originMessage.atPersons.length || recallMessage.originMessage.quotedMessage.authorId){
                if([recallMessage.originMessage.atPersons containsString:recipientId] ||
                   [recallMessage.originMessage.atPersons containsString:MENTIONS_ALL] ||
                   [recallMessage.originMessage.quotedMessage.authorId isEqualToString:recipientId]){
                    self.apnsMessageInfo.messageType = DTApnsMessageType_RECALL_MENTIONS_MSG;
                }
                if(recallMessage.originMessage.quotedMessage.authorId){
                    self.apnsMessageInfo.mentionedPersons = @[recallMessage.originMessage.quotedMessage.authorId];
                }else{
                    NSArray *atPersons = [recallMessage.originMessage.atPersons componentsSeparatedByString:@";"];
                    NSMutableArray *editPersons = atPersons.mutableCopy;
                    [editPersons enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if(!obj.length){
                            [editPersons removeObject:obj];
                        }
                    }];
                    self.apnsMessageInfo.mentionedPersons = atPersons;
                }
            }
        }
    }else{
        self.apnsMessageInfo.messageType = DTApnsMessageType_GROUP_NORMAL;
    }
    
    if ([self.thread nameWithTransaction:nil].length == 0) {
        self.apnsMessageInfo.groupName = Localized(@"NEW_GROUP_DEFAULT_TITLE", @"");
    } else {
        self.apnsMessageInfo.groupName = [self.thread nameWithTransaction:nil];
    }
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    self.apnsMessageInfo.groupID = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    
}

- (void)handleContactMessage{
    
    self.apnsMessageInfo.collapseId = self.message.collapseId;
    
    if(self.message.hasAttachments){
        self.apnsMessageInfo.messageType = DTApnsMessageType_PERSONAL_FILE;
    }else if(self.message.quotedMessage.authorId){
        self.apnsMessageInfo.messageType = DTApnsMessageType_PERSONAL_REPLY;
    }else if([self.message isKindOfClass:[DTOutgoingCallMessage class]]){
        self.apnsMessageInfo.messageType = ((DTOutgoingCallMessage *)self.message).apnsType;
        //tmp meeting
        if(self.apnsMessageInfo.messageType == DTApnsMessageType_GROUP_CALL){
            self.apnsMessageInfo.groupName = ((DTOutgoingCallMessage *)self.message).groupName;
        }
    }else if([self.message isKindOfClass:[DTHyperlinkOutgoingMessage class]]){
        self.apnsMessageInfo.messageType = ((DTHyperlinkOutgoingMessage *)self.message).apnsType;

        if(self.apnsMessageInfo.messageType == DTApnsMessageType_GROUP_CALL){
            self.apnsMessageInfo.groupName = ((DTHyperlinkOutgoingMessage *)self.message).groupName;
        }
    }else if(self.message.recall){
        self.self.apnsMessageInfo.messageType = DTApnsMessageType_RECALL_MSG;
    }else{
        self.apnsMessageInfo.messageType = DTApnsMessageType_PERSONAL_NORMAL;
    }
}

- (void)handlePassthroughInfo{
    
    NSMutableDictionary *passthroughInfo = @{}.mutableCopy;
    if([self.message isKindOfClass:[DTOutgoingCallMessage class]]){
        if(((DTOutgoingCallMessage *)self.message).apnsPassthroughInfo){
            [passthroughInfo addEntriesFromDictionary:((DTOutgoingCallMessage *)self.message).apnsPassthroughInfo];
        }
        self.apnsMessageInfo.collapseId = ((DTOutgoingCallMessage *)self.message).collapseId;
    } else if ([self.message isKindOfClass:[DTHyperlinkOutgoingMessage class]]){
        if(((DTHyperlinkOutgoingMessage *)self.message).apnsPassthroughInfo){
            [passthroughInfo addEntriesFromDictionary:((DTHyperlinkOutgoingMessage *)self.message).apnsPassthroughInfo];
        }
        self.apnsMessageInfo.collapseId = ((DTHyperlinkOutgoingMessage *)self.message).collapseId;
    }
    
    NSString *conversationId = nil;
    if(self.thread.isGroupThread){
        conversationId = [((TSGroupThread *)self.thread).groupModel.groupId base64EncodedString];
    }else{
        conversationId = [TSAccountManager localNumber];
    }
    
    if(conversationId){
        [passthroughInfo setObject:conversationId forKey:@"conversationId"];
    }
        
    if(passthroughInfo.count){
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:passthroughInfo.copy options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString;
        if(jsonData.length && !error){
            jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
        self.apnsMessageInfo.passthrough = jsonString;
    }
}

- (NSDictionary *)build{
    NSError *error;
    NSDictionary *dict = [MTLJSONAdapter JSONDictionaryFromModel:self.apnsMessageInfo error:&error];
    if(error){
        return nil;
    }
    return dict;
}

@end
