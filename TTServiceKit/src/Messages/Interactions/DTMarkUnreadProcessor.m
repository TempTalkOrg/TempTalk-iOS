//
//  DTMarkUnreadProcessor.m
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

#import "DTMarkUnreadProcessor.h"
#import "DTUnreadEntity.h"
#import "TSGroupThread.h"
#import "TSContactThread.h"
#import "NSNotificationCenter+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const DTMarkAsUnreadNotification = @"DTMarkAsUnreadNotification";

@implementation DTMarkUnreadProcessor

- (void)processIncomingSyncMessage:(DSKProtoSyncMessageMarkAsUnread *) markAsUnreadMessage
                   serverTimestamp:(UInt64)serverTimestamp
                       transaction:(SDSAnyWriteTransaction *) transaction {
    DSKProtoConversationId *messageConversation = markAsUnreadMessage.conversation;
    TSThread *thread = nil;
    if (messageConversation.hasGroupID && messageConversation.groupID.length) {
        thread = [TSGroupThread threadWithGroupId:messageConversation.groupID transaction:transaction];
        if(thread){
            [(TSGroupThread *)thread anyUpdateGroupThreadWithTransaction:transaction
                                                                   block:^(TSGroupThread * instance) {
                instance.unreadTimeStimeStamp = serverTimestamp;
                instance.unreadFlag = markAsUnreadMessage.unwrappedFlag;
            }];
        }
    } else {
        thread = [TSContactThread getOrCreateThreadWithContactId:messageConversation.number
                                                     transaction:transaction];
        [thread anyUpdateWithTransaction:transaction
                                   block:^(TSThread * instance) {
            instance.unreadTimeStimeStamp = serverTimestamp;
            instance.unreadFlag = markAsUnreadMessage.unwrappedFlag;
        }];
    }
    
    if (markAsUnreadMessage.unwrappedFlag == DSKProtoSyncMessageMarkAsUnreadFlagUnread) {
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTMarkAsUnreadNotification
                                                                 object:thread];
    }
}

@end
