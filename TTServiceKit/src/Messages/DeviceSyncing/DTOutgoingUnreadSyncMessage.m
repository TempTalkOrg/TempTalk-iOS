//
//  DTOutgoingUnreadSyncMessage.m
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

#import "DTOutgoingUnreadSyncMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>


@interface DTOutgoingUnreadSyncMessage()
@property (nonatomic, strong) DTUnreadEntity *unreadEntity;
@end

@implementation DTOutgoingUnreadSyncMessage

- (instancetype)initOutgoingMessageWithUnReadEntity:( DTUnreadEntity * _Nonnull )unreadEntity{
    uint64_t now = [NSDate ows_millisecondTimeStamp];
//    OWSLogDebug(@"------>>> UnreadSyncMessage NOW %llu", now);
    self = [super initSyncMessageWithTimestamp:now];
    if (self) {
        self.unreadEntity = unreadEntity;
    }
    return self;
}

//构建同步的消息体
- (DSKProtoSyncMessageBuilder *)syncMessageBuilder {
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    
    DSKProtoSyncMessageMarkAsUnreadBuilder *markAsUnreadBuilder = [DSKProtoSyncMessageMarkAsUnread builder];

    DSKProtoConversationIdBuilder *conversationBuilder = [DSKProtoConversationId builder];
    conversationBuilder.number = self.unreadEntity.covnersation.number;
    [conversationBuilder setGroupID:self.unreadEntity.covnersation.groupId];
    DSKProtoConversationId *conversation = [conversationBuilder buildAndReturnError:nil];
    
    markAsUnreadBuilder.conversation = conversation;
    markAsUnreadBuilder.flag = self.unreadEntity.unreadFlag;
    
    DSKProtoSyncMessageMarkAsUnread *markAsUnread = [markAsUnreadBuilder buildAndReturnError:nil];
    [syncMessageBuilder setMarkAsUnread:markAsUnread];
    return syncMessageBuilder;
}


// TODO: messageSender 里取该值判断，但对于此不可见消息类没用, 此类消息的发送失败需要单独处理
- (TSOutgoingMessageState)messageState {
    return TSOutgoingMessageStateSent;
}

@end
