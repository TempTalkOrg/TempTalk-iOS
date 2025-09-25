//
//  DTOutgoingSyncArchiveMessage.m
//  TTServiceKit
//
//  Created by Felix on 2023/5/25.
//

#import "DTOutgoingSyncArchiveMessage.h"
#import "DTConversationArchiveEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTOutgoingSyncArchiveMessage()

@property (nonatomic, strong) DTConversationArchiveEntity *archiveEntity;

@end

@implementation DTOutgoingSyncArchiveMessage

- (instancetype)initWithArchiveEntity:(DTConversationArchiveEntity *)archiveEntity {
    if (self = [super initSyncMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]]) {
        
        self.archiveEntity = archiveEntity;
    }
    
    return self;
}

- (nullable DSKProtoSyncMessageBuilder *)syncMessageBuilder  {
    
    DSKProtoSyncMessageConversationArchiveBuilder *syncArchiveMessageBuilder = [DSKProtoSyncMessageConversationArchive builder];
    
    DSKProtoConversationIdBuilder *conversationIDBuilder = [DSKProtoConversationId builder];
    [conversationIDBuilder setNumber:self.archiveEntity.covnersation.number];
    [conversationIDBuilder setGroupID:self.archiveEntity.covnersation.groupId];
    DSKProtoConversationId *conversationId = [conversationIDBuilder buildAndReturnError:nil];
    [syncArchiveMessageBuilder setConversation:conversationId];
    
    [syncArchiveMessageBuilder setFlag:self.archiveEntity.flag];
    DSKProtoSyncMessageConversationArchive *conversationArchive = [syncArchiveMessageBuilder buildAndReturnError:nil];
    
    
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    [syncMessageBuilder setConversationArchive:conversationArchive];
    
    return syncMessageBuilder;
}

@end
