//
//  DTServerNotifyMessageHandler.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import "DTServerNotifyMessageHandler.h"
#import "DTContactsUpdateMessageProcessor.h"
#import "DTConversationUpdateMessageProcessor.h"
#import "DTServerNotifyEntity.h"
#import "DTGroupNotifyEntity.h"
#import "DTParamsBaseUtils.h"
#import "TSGroupThread.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTConversationNotifyEntity.h"
#import "DTFetchThreadConfigAPI.h"
#import "DTCoWorkerApprovedNotifyEntity.h"
#import "DTScreenLockEntity.h"
#import "DTAddContactsEntity.h"

NSNotificationName const NSNotificationNameNotifyScheduleListRefresh = @"NSNotificationNameNotifyScheduleListRefresh";
NSNotificationName const NSNotificationNameNotifyCallEnd = @"NSNotificationNameNotifyCallEnd";

NSString * const NotifyCallEndRoomIdKey = @"roomId";

@interface DTServerNotifyMessageHandler ()

@property (nonatomic, strong) DTContactsUpdateMessageProcessor *contactsUpdateMessageProcessor;

@property (nonatomic, strong) DTConversationUpdateMessageProcessor *conversationUpdateMessageProcessor;

@end

@implementation DTServerNotifyMessageHandler

- (DTConversationUpdateMessageProcessor *)conversationUpdateMessageProcessor {
    if (!_conversationUpdateMessageProcessor) {
        _conversationUpdateMessageProcessor = [DTConversationUpdateMessageProcessor new];
    }
    return _conversationUpdateMessageProcessor;
}

- (DTGroupUpdateMessageProcessor *)groupUpdateMessageProcessor{
    if(!_groupUpdateMessageProcessor){
        _groupUpdateMessageProcessor = [DTGroupUpdateMessageProcessor new];
    }
    return _groupUpdateMessageProcessor;
}

- (DTContactsUpdateMessageProcessor *)contactsUpdateMessageProcessor{
    if(!_contactsUpdateMessageProcessor){
        _contactsUpdateMessageProcessor = [DTContactsUpdateMessageProcessor new];
    }
    return _contactsUpdateMessageProcessor;
}

- (BOOL)needIgnoreSourceOfServer:(DTServerNotifyEntity *)serverNotifyEntity
                     groupNotify:(DTGroupNotifyEntity *)groupNotifyEntity
                     transaction:(SDSAnyWriteTransaction *)transaction {
    NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:groupNotifyEntity.gid];
    BOOL conversationExists = NO;
    if(groupId.length && [TSGroupThread threadWithGroupId:groupId transaction:transaction]){
        conversationExists = YES;
    }
    
    return (!serverNotifyEntity.display && !conversationExists);
    
}

- (void)handleNotifyDataWithEnvelope:(DSKProtoEnvelope *)envelope
                       plaintextData:(NSData *)plaintextData
                         transaction:(SDSAnyWriteTransaction *)transaction {
    
    NSError *error;
    NSDictionary *notifyInfo = [NSJSONSerialization JSONObjectWithData:plaintextData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
    if(error){
        OWSProdError(@"json error!");
        return;
    }
    
    DTServerNotifyEntity *serverNotifyEntity = [MTLJSONAdapter modelOfClass:[DTServerNotifyEntity class]
                                                         fromJSONDictionary:notifyInfo
                                                                      error:&error];
//    OWSLogInfo(@"notifyInfo = %@ \n",notifyInfo);
    if(!DTParamsUtils.validateDictionary(serverNotifyEntity.data)){
        OWSProdError(@"serverNotifyEntity.data is invalid!");
        return;
    }
    
    switch (serverNotifyEntity.notifyType) {
        case DTServerNotifyTypeGroupUpdate:
        {
            DTGroupNotifyEntity * groupNotifyEntity = [MTLJSONAdapter modelOfClass:[DTGroupNotifyEntity class]
                                                                fromJSONDictionary:serverNotifyEntity.data
                                                                             error:&error];
            
            if(groupNotifyEntity && ![self needIgnoreSourceOfServer:serverNotifyEntity groupNotify:groupNotifyEntity transaction:transaction]){
                
                OWSLogInfo(@"handle notify groupNotifyType: %lu, groupVersion:%ld", (unsigned long)groupNotifyEntity.groupNotifyType, (long)groupNotifyEntity.groupVersion);
                
                [self.groupUpdateMessageProcessor handleGroupUpdateMessageWithEnvelope:envelope
                                                                               display:serverNotifyEntity.display
                                                                     groupNotifyEntity:groupNotifyEntity
                                                                           transaction:transaction];
            }else{
                OWSProdError(@"groupNotifyEntity == nil!");
            }
        }
            break;
        case DTServerNotifyTypeContactsUpdate:
        {
            DTContactsNotifyEntity * contactsNotifyEntity = [MTLJSONAdapter modelOfClass:[DTContactsNotifyEntity class]
                                                                      fromJSONDictionary:serverNotifyEntity.data
                                                                                   error:&error];
            if(contactsNotifyEntity){
                [self.contactsUpdateMessageProcessor handleContactsUpdateMessageWithContactsNotifyEntity:contactsNotifyEntity transaction:transaction];
                [[TextSecureKitEnv sharedEnv].settingsManager syncRemoteProfileInfo];
                
            }else{
                OWSProdError(@"contactsNotifyEntity == nil!");
            }
        }
            break;
        case DTServerNotifyTypeLightTaskUpdate:
        {
            //kris rm
        }
            break;
        case DTServerNotifyTypeVoteUpdate:
        {
            //kris rm
        }
            break;
        case DTServerNotifyTypeConversationUpdate:
        {
            DTConversationNotifyEntity *conversationNotifyEntity = [MTLJSONAdapter modelOfClass:[DTConversationNotifyEntity class] fromJSONDictionary:serverNotifyEntity.data error:&error];
            
            if (conversationNotifyEntity) {
                [self.conversationUpdateMessageProcessor handleConversationUpdateMessageWithEnvelope:envelope display:serverNotifyEntity.display conversationNotifyEntity:conversationNotifyEntity transaction:transaction];
                
            } else {
                OWSProdError(@"conversationNotifyEntity == nil!");
            }
        }
            break;
        case DTServerNotifyTypeConversationSharedConfiguration:
        {
            DTThreadConfigEntity *conversationNotifyEntity = [MTLJSONAdapter modelOfClass:[DTThreadConfigEntity class] fromJSONDictionary:serverNotifyEntity.data error:&error];
            if (conversationNotifyEntity) {
                [self.conversationUpdateMessageProcessor handleConversationSharingConfiguration:envelope display:serverNotifyEntity.display conversationNotifyEntity:conversationNotifyEntity transaction:transaction];
            } else {
                OWSProdError(@"conversationNotifyEntity == nil!");
            }
        }
            break;
        case DTServerNotifyTypeAddContacts: {
            NSDictionary *addContactsData = serverNotifyEntity.data;
            if ([addContactsData isKindOfClass:NSDictionary.class] && addContactsData[@"operatorInfo"] && DTParamsUtils.validateDictionary(addContactsData[@"operatorInfo"])) {
                NSDictionary *operatorInfo = addContactsData[@"operatorInfo"];
                NSString *avatarJson = operatorInfo[@"avatar"];
                NSDictionary *dict = [NSObject signal_dictionaryWithJSON:avatarJson];
                serverNotifyEntity.data[@"operatorInfo"][@"avatar"] = dict;
            }
            
            DTAddContactsEntity * addContactsEntity = [MTLJSONAdapter modelOfClass:[DTAddContactsEntity class]
                                                                fromJSONDictionary:serverNotifyEntity.data
                                                                             error:&error];
            
            if(addContactsEntity){
                [self.contactsUpdateMessageProcessor handleAddContactMessageWithEnvelope:envelope contactsNotifyEntity:addContactsEntity transaction:transaction];
            }else{
                OWSProdError(@"addContactsEntity == nil!");
            }
        }
            break;
        case DTServerNotifyTypeCardUpdate:
        {
            DTCardMessageEntity *cardEntity = [MTLJSONAdapter modelOfClass:[DTCardMessageEntity class] fromJSONDictionary:serverNotifyEntity.data error:&error];
            if(!cardEntity ||
               !DTParamsUtils.validateString(cardEntity.content)){
                DDLogError(@"card content is empty.");
                return;
            }
            NSString *source = cardEntity.source;
            NSString *conversationId = cardEntity.conversationId;
            NSString *cardUniqueId = [cardEntity generateUniqueIdWithSource:source conversationId:conversationId];
            if(envelope.msgExtra && envelope.msgExtra.latestCard){
                DTCardMessageEntity *extraCardEntity = [DTCardMessageEntity cardEntityWithProto:envelope.msgExtra.latestCard];
                NSString *extraCardUniqueId = [extraCardEntity generateUniqueIdWithSource:source conversationId:conversationId];
                if(DTParamsUtils.validateString(extraCardUniqueId) &&
                   extraCardEntity.version > cardEntity.version){
                    cardEntity = extraCardEntity;
                }
            }
            [cardEntity updateDataWithCardUniqueId:cardUniqueId receivedCardType:DTReceivedCardTypeRefresh transaction:transaction updateAction:^{
                NSError *error;
                [InteractionFinder enumerateCardRelatedInteractionsWithCardUniqueId:cardUniqueId
                                                                        transaction:transaction
                                                                              error:&error
                                                                              block:^(TSInteraction *interaction, BOOL *stop) {
                    if([interaction isKindOfClass:[TSMessage class]]){
                        [((TSMessage *)interaction) anyUpdateMessageWithTransaction:transaction block:^(TSMessage * instance) {
                            instance.cardVersion = cardEntity.version;
                        }];
                    }
                }];
                if(error){
                    DDLogError(@"enumerateCardRelatedInteractions error: %@!", error.description);
                }
            }];
        }
            break;
        case DTServerNotifyTypeCalendarVersion: {
            NSDictionary *data = serverNotifyEntity.data;
            if (!DTParamsUtils.validateDictionary(data)) { return; }
            NSNumber *version = data[@"version"];
            if (!DTParamsUtils.validateNumber(version)) { return; }
            OWSLogInfo(@"%@ calendar version: %@", self.logTag, version ?: @(-1));
            BOOL isMainApp = CurrentAppContext().isMainApp;
            if (isMainApp) {
                [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameNotifyScheduleListRefresh object:nil userInfo:@{@"version" : version}];
            }
        }
            break;
            
        case DTServerNotifyTypeTopicTrack: {
            //
        }
            break;
            
        case DTServerNotifyTypeMessageArchive: {
            
            NSDictionary *data = serverNotifyEntity.data;
            if (!DTParamsUtils.validateDictionary(data)) { return; }
            
            DTMessageArchiveEntity *messageArchiveEntity  = [MTLJSONAdapter modelOfClass:[DTMessageArchiveEntity class] fromJSONDictionary:serverNotifyEntity.data error:&error];
            
            [DTMessageArchiveProcessor processNotifyArchiveMessageWithArchiveMessage:messageArchiveEntity transaction:transaction];
        }
            break;
            
        case DTServerNotifyTypeCoWorkerApproved: {
            
            NSDictionary *data = serverNotifyEntity.data;
            if (!DTParamsUtils.validateDictionary(data)) { return; }
            
            DTCoWorkerApprovedNotifyEntity *entity = [MTLJSONAdapter modelOfClass:[DTCoWorkerApprovedNotifyEntity class] fromJSONDictionary:serverNotifyEntity.data error:&error];
            if (entity == nil || error != nil) {
                OWSLogError(@"format DTCoWorkerApprovedNotifyEntity failed");
                return;
            }
            
            NSString *localNumber = [TSAccountManager shared].localNumber;
            if (localNumber == nil) {
                OWSLogError(@"missing localNumber");
                return;
            }
            
            // 获取会话
            TSContactThread *thread = nil;
            if ([localNumber isEqual:entity.inviteeId]) { // 当前用户是被邀请人
                thread = [TSContactThread getOrCreateThreadWithContactId:entity.invitorId transaction:transaction];
            } else if ([localNumber isEqual:entity.invitorId]) { // 当前用户是邀请人
                thread = [TSContactThread getOrCreateThreadWithContactId:entity.inviteeId transaction:transaction];
            } else {
                thread = nil;
            }
            if (thread == nil) {
                OWSLogError(@"current user is not invitor or invitee");
                return;
            }
            
            // 发送通知消息
            NSString *notification = [NSString stringWithFormat:Localized(@"CO_WORKER_APPROVED_NOTIFICATION", @""), entity.inviteeName];
            [[[TSInfoMessage alloc] initWithTimestamp:serverNotifyEntity.notifyTime
                                             inThread:thread
                                          messageType:TSInfoMessageCoWorkerApproved
                                        customMessage:notification] anyInsertWithTransaction:transaction];
            
            // 标记未读
            DTUnreadEntity *unreadEntity = [[DTUnreadEntity alloc] init];
            unreadEntity.unreadFlag = 1;
            DTConversationInfoEntity *infoEntity = [[DTConversationInfoEntity alloc] init];
            infoEntity.number = thread.contactIdentifier;
            unreadEntity.covnersation = infoEntity;
            
            DTOutgoingUnreadSyncMessage *unreadMessage = [[DTOutgoingUnreadSyncMessage alloc] initOutgoingMessageWithUnReadEntity:unreadEntity];
            unreadMessage.associatedUniqueThreadId = thread.uniqueId;
            
            @weakify(self)
            [self.messageSender enqueueMessage:unreadMessage success:^{
                @strongify(self)
                DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    [thread anyUpdateWithTransaction:writeTransaction block:^(TSThread * _Nonnull instance) {
                        instance.unreadTimeStimeStamp = unreadMessage.serverTimestamp;
                        instance.unreadFlag = 1;
                    }];
                });
            } failure:^(NSError * _Nonnull error) {
                OWSLogError(@"%@", error.localizedDescription);
            }];
        }
            break;
        case DTServerNotifyTypeScreenLock: {
            OWSLogInfo(@"servernotify screenlock do nothing.");
        }
        case DTServerNotifyTypeCallEnd: {
            NSDictionary *callEndData = serverNotifyEntity.data;
            
            if (DTParamsUtils.validateDictionary(callEndData)) {
                NSString *roomId = callEndData[NotifyCallEndRoomIdKey];
                
                if (DTParamsUtils.validateString(roomId)) {
                    OWSLogInfo(@"roomId DTServerNotifyTypeCallEnd");
                    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationNameNotifyCallEnd object:nil userInfo:callEndData];
                } else {
                    OWSLogError(@"data:%@ error!", callEndData);
                }
            } else {
                OWSLogError(@"data:%@ error!", notifyInfo);
            }
        }
            break;
        case DTServerNotifyTypeResetIdentityKey: {
            NSDictionary *data = serverNotifyEntity.data;
            if (!DTParamsUtils.validateDictionary(data)) { return; }
            // 操作人
            NSString *operator = data[@"operator"];
            // 清理的时间
            NSNumber *timestampNum = data[@"resetIdentityKeyTime"];
            long long resetIdentityKeyTime = [timestampNum longLongValue];
            [[TextSecureKitEnv sharedEnv].settingsManager deleteResetIdentityKeyThreadsWithOperatorId:operator resetIdentityKeyTime:resetIdentityKeyTime];
            break;
        }
        default:
            OWSLogError(@"Notify type that does not exist \n%lu", serverNotifyEntity.notifyType);
            break;
    }
}
    
    

@end
