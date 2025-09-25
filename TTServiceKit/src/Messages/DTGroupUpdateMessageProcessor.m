//
//  DTGroupUpdateMessageProcessor.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import "DTGroupUpdateMessageProcessor.h"
#import "TSGroupThread.h"
#import "DTGetGroupInfoAPI.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "FunctionalUtil.h"
#import "TSInfoMessage.h"
#import "OWSDevice.h"
#import "DTGetGroupPersonalConfigAPI.h"
#import "TextSecureKitEnv.h"
#import "DTGroupUtils.h"
#import "DTGroupAvatarUpdateProcessor.h"
#import "TSAttachmentStream.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "SignalAccount.h"
#import "Contact.h"
#import "DTPinnedMessage.h"
#import "DTPinnedDataSource.h"
#import "DTGroupMeetingRecord.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "OWSDisappearingMessagesConfiguration.h"
#import "NSNotificationCenter+OWS.h"
#import "DTGroupUpdateInfoMessageHelper.h"

NSString *const DTPersonalGroupConfigChangedNotification = @"TappedStatusBarNotification";
NSString *const DTGroupMessageExpiryConfigChangedNotification = @"kGroupMessageExpiryConfigChangedNotification";

@interface DTGroupUpdateMessageProcessor ()

@property (nonatomic, strong) id<ContactsManagerProtocol> contactsManager;

@property (nonatomic, strong) DTGetGroupInfoAPI *getGroupInfoAPI;

@property (nonatomic, strong) DTGetGroupPersonalConfigAPI *getPersonalConfigAPI;

@property (nonatomic, strong) DTGroupAvatarUpdateProcessor *groupAvatarUpdateProcessor;

//@property (nonatomic, copy) NSString *localNumber;

@end

@implementation DTGroupUpdateMessageProcessor

- (DTGetGroupInfoAPI *)getGroupInfoAPI{
    if(!_getGroupInfoAPI){
        _getGroupInfoAPI = [DTGetGroupInfoAPI new];
        _getGroupInfoAPI.frequencyLimitEnable = YES;
//        _getGroupInfoAPI.isSyncRequest = YES;
    }
    return _getGroupInfoAPI;
}

- (DTGetGroupPersonalConfigAPI *)getPersonalConfigAPI{
    if(!_getPersonalConfigAPI){
        _getPersonalConfigAPI = [DTGetGroupPersonalConfigAPI new];
    }
    return _getPersonalConfigAPI;
}

- (DTGroupAvatarUpdateProcessor *)groupAvatarUpdateProcessor{
    if(!_groupAvatarUpdateProcessor){
        _groupAvatarUpdateProcessor = [[DTGroupAvatarUpdateProcessor alloc] initWithGroupThread:nil];
    }
    return _groupAvatarUpdateProcessor;
}

- (instancetype)init{
    if(self = [super init]){
        self.contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
    }
    return self;
}

+ (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("org.difft.pin.DTGroupUpdateMessageProcessor", DISPATCH_QUEUE_SERIAL);
    });
    
    return _serialQueue;
}

- (void)requestGroupInfoWithGroupId:(NSData *)groupId
                      targetVersion:(NSInteger)targetVersion
                        needSystemMessage:(BOOL)needSystemMessage
                           generate:(BOOL)gnerate
                           envelope:(DSKProtoEnvelope *)envelope
                        transaction:(SDSAnyWriteTransaction *)transaction
                         completion:(void (^)(SDSAnyWriteTransaction *))completion {
    [self requestGroupInfoWithGroupId:groupId
                        targetVersion:targetVersion
                    needSystemMessage:needSystemMessage
                             generate:gnerate
                             envelope:envelope
                    groupNotifyEntity:nil
                          transaction:transaction
                           completion:completion];
}

- (void)requestGroupInfoWithGroupId:(NSData *)groupId
                      targetVersion:(NSInteger)targetVersion
                  needSystemMessage:(BOOL)needSystemMessage
                           generate:(BOOL)generate
                           envelope:(DSKProtoEnvelope *)envelope
                  groupNotifyEntity:(DTGroupNotifyEntity * _Nullable)groupNotifyEntity
                        transaction:(SDSAnyWriteTransaction *)transaction
                         completion:(void (^)(SDSAnyWriteTransaction *))completion{
    NSString *localNumber = [self localNumber:transaction];
    if(!groupId.length){
        OWSProdError(@"groupId length <= 0");
        return;
    }
    
    NSString *serverGId = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupId];
    // serverGid 异常，不需要创建新群。判断逻辑从网络请求里挪出来，会有直接走 failure 逻辑，造成 YapDatabase thread deadlock
    if(!DTParamsUtils.validateString(serverGId)){
        return;
    }
    
    @weakify(self)
    [self.getGroupInfoAPI sendRequestWithGroupId:serverGId
                                   targetVersion:targetVersion
                                         success:^(DTGetGroupInfoDataEntity * _Nonnull entity) {
        @strongify(self)
        if(entity){
            
            dispatch_async(self.class.serialQueue, ^{
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    [self generateOrUpdateConverationWithGroupId:groupId
                                               needSystemMessage:needSystemMessage
                                                        generate:generate
                                                        envelope:envelope
                                                       groupInfo:entity
                                               groupNotifyEntity:groupNotifyEntity
                                                     transaction:writeTransaction];
                })
            });
        }else{
            OWSProdError(@"groupInfoDataEntity is nil");
        }
    } failure:^(NSError * _Nonnull error) {
        
        @strongify(self)
        dispatch_async(self.class.serialQueue, ^{
            DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *writeTransaction) {
                
                TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:groupId transaction:writeTransaction];
                if(!groupThread){
                    return;
                }
                
                NSString *updateGroupInfo = nil;
                BOOL tmpShouldAffectSorting = NO;
                if(error.code == DTAPIRequestResponseStatusNoSuchGroup){
                    tmpShouldAffectSorting = YES;
                    updateGroupInfo = Localized(@"GROUP_DISMISSED", nil);
                    OWSLogError(@"no such group!");
                }else if (error.code == DTAPIRequestResponseStatusNoPermission){
                    updateGroupInfo = [NSString stringWithFormat:Localized(@"GROUP_MEMBER_LEFT", @""), Localized(@"YOU", nil)];
                    OWSLogError(@"No Permission group!");
                }else{
                    //TODO: Kris save to retry
                    OWSProdError(@"requestError");
                }
                
                if(updateGroupInfo.length){
                    [DTGroupUtils removeGroupBaseInfoWithGid:serverGId transaction:transaction];
                    [groupThread anyRemoveWithTransaction:transaction];
                }
            }));
        });
        
    }];
    
    
    [self generateOrUpdateConverationWithGroupId:groupId
                               needSystemMessage:needSystemMessage
                                        generate:generate
                                        envelope:envelope
                                       groupInfo:nil
                               groupNotifyEntity:groupNotifyEntity
                                     transaction:transaction];
    
    completion(transaction);
    
}

- (TSGroupThread * _Nullable)generateOrUpdateConverationWithGroupId:(NSData *)groupId
                                        needSystemMessage:(BOOL)needSystemMessage
                                                 generate:(BOOL)generate
                                                 envelope:(DSKProtoEnvelope * _Nullable)envelope
                                                groupInfo:(DTGetGroupInfoDataEntity * _Nullable)groupInfo
                                        groupNotifyEntity:(DTGroupNotifyEntity * _Nullable)groupNotifyEntity
                                              transaction:(SDSAnyWriteTransaction *)transaction{
    NSString *localNumber = [self localNumber:transaction];
    TSGroupThread *newGroupThread =
        [TSGroupThread getOrCreateThreadWithGroupId:groupId transaction:transaction];
    //MARK: 数据库取到异常数据导致crash，原因仍需排查
    if (![newGroupThread isKindOfClass:[TSGroupThread class]]) {
        return nil;
    }
    TSGroupModel *oldGroupModel = newGroupThread.groupModel;
    
    if(!groupInfo){
        return newGroupThread;
    }
    
    // 更新群信息, 检查过期时间配置
    NSNumber *messageExpiry = groupInfo.messageExpiry;

    NSMutableArray *newMemberIds = @[].mutableCopy;
    __block NSMutableArray<NSString *> *groupAdmin = [NSMutableArray array];
    __block NSString *groupOwner = @"";
    __block NSNumber *notificationType = @(TSGroupNotificationTypeAtMe);
    __block NSNumber *useGlobal=@(1);//默认全局配置打开
    NSMutableArray *signalAccounts = @[].mutableCopy;
    
    NSMutableArray *recommendRoles = @[].mutableCopy;
    NSMutableArray *agreeRoles = @[].mutableCopy;
    NSMutableArray *performRoles = @[].mutableCopy;
    NSMutableArray *inputRoles = @[].mutableCopy;
    NSMutableArray *deciderRoles = @[].mutableCopy;
    NSMutableArray *observerRoles = @[].mutableCopy;
    
    [groupInfo.members enumerateObjectsUsingBlock:^(DTGroupMemberEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *uid = obj.uid;
        if (!obj.uid) return;
        
        if (uid && [uid isKindOfClass:NSString.class]) {
            [newMemberIds addObject:uid];
//            BOOL isExternal = NO;
            SignalAccount *account = [self.class saveExternalMemberWithMember:obj transaction:transaction];

            if (account) {
                [signalAccounts addObject:account];
            }
        }

        if(obj.role == DTGroupMemberRoleOwner){
            groupOwner = obj.uid;
        }
        if (obj.role == DTGroupMemberRoleAdmin) {
            [groupAdmin addObject:obj.uid];
        }
        if([obj.uid isEqualToString:localNumber]){
            notificationType = @(obj.notification);
            //获取用户是否开启全局配置并赋值
            useGlobal=obj.useGlobal;
        }
        
        switch (obj.rapidRole) {
            case DTGroupRAPIDRoleRecommend:
                [recommendRoles addObject:uid];
                break;
            case DTGroupRAPIDRoleAgree:
                [agreeRoles addObject:uid];
                break;
            case DTGroupRAPIDRolePerform:
                [performRoles addObject:uid];
                break;
            case DTGroupRAPIDRoleInput:
                [inputRoles addObject:uid];
                break;
            case DTGroupRAPIDRoleDecider:
                [deciderRoles addObject:uid];
                break;
            case DTGroupRAPIDRoleObserver:
                [observerRoles addObject:uid];
                break;
            case DTGroupRAPIDRoleNone:
            default:
                break;
        }
    }];
    
    if(signalAccounts.count){
        [self.contactsManager updateWithSignalAccounts:signalAccounts];
    }
    
    TSGroupModel *newGroupModel = [[TSGroupModel alloc] initWithTitle:groupInfo.name
                                                            memberIds:newMemberIds.copy
                                                                image:oldGroupModel.groupImage
                                                              groupId:groupId
                                                           groupOwner:groupOwner
                                                           groupAdmin:groupAdmin
                                                          transaction:transaction];
    newGroupModel.notificationType = notificationType;
    newGroupModel.useGlobal = useGlobal;
    newGroupModel.version = groupInfo.version;
    newGroupModel.invitationRule = groupInfo.invitationRule;
    newGroupModel.messageExpiry = messageExpiry;
    newGroupModel.remindCycle = groupInfo.remindCycle && groupInfo.remindCycle.length > 0 ? groupInfo.remindCycle : @"none";
    newGroupModel.anyoneRemove = groupInfo.anyoneRemove;
    newGroupModel.rejoin = groupInfo.rejoin;
    newGroupModel.publishRule = groupInfo.publishRule;
    newGroupModel.ext = groupInfo.ext;
    
    newGroupModel.anyoneChangeName = groupInfo.anyoneChangeName;
    newGroupModel.anyoneChangeAutoClear = groupInfo.anyoneChangeAutoClear;
    newGroupModel.autoClear = groupInfo.autoClear;
    newGroupModel.privilegeConfidential = groupInfo.privilegeConfidential;

    
    newGroupModel.recommendRoles = [recommendRoles copy];
    newGroupModel.agreeRoles = [agreeRoles copy];
    newGroupModel.performRoles = [performRoles copy];
    newGroupModel.inputRoles = [inputRoles copy];
    newGroupModel.deciderRoles = [deciderRoles copy];
    newGroupModel.observerRoles = [observerRoles copy];
    
    [newGroupThread anyUpdateGroupThreadWithTransaction:transaction
                                                  block:^(TSGroupThread * instance) {
        instance.groupModel = newGroupModel;
        // 全量跟更新的thread信息（查询也在使用）
        [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                   expireTime:groupNotifyEntity.group.messageExpiry
                                           messageClearAnchor:@(groupNotifyEntity.group.messageClearAnchor)];
    }];
    
    DTGroupBaseInfoEntity *baseInfo = [DTGroupBaseInfoEntity new];
    baseInfo.gid = newGroupThread.serverThreadId;
    baseInfo.name = newGroupModel.groupName;
    // 全量跟更新的baseInfo
    [[DataUpdateUtil shared] updateConversationWithBaseInfo:baseInfo
                                                     thread:newGroupThread
                                                 expireTime:groupNotifyEntity.group.messageExpiry
                                         messageClearAnchor:@(groupNotifyEntity.group.messageClearAnchor)];
    
    [DTGroupUtils upsertGroupBaseInfo:baseInfo transaction:transaction];
        
    OWSLogInfo(@"%@ 主动拉取 ------ invitationRule=%@",groupInfo.name, groupInfo.invitationRule);
    
    NSString *updateGroupInfo = nil;
    BOOL tmpShouldAffectSorting = NO;
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    if(envelope.hasSystemShowTimestamp && envelope.systemShowTimestamp > 0){
        timestamp = envelope.systemShowTimestamp;
    } else if (envelope.hasTimestamp && envelope.timestamp > 0) {
        timestamp = envelope.timestamp;
    }
    NSMutableSet *whoJoined = [NSMutableSet set];
    if(generate){
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:newGroupModel.groupMemberIds
                                                                     removedMemberIds:nil
                                                                        leftMemberIds:nil
                                                            shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                          transaction:transaction];
        
    }else{
        updateGroupInfo = [DTGroupUtils getFullUpdateStringWithOldGroupModel:oldGroupModel whoJoined:whoJoined
                                                                    newModel:newGroupModel
                                                   shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                 transaction:transaction];
        
        [self handleGroupMessageArchiveChangedWithOldGroupModel:oldGroupModel
                                                  newGroupModel:newGroupModel
                                                 newGroupThread:newGroupThread
                                                      timestamp:timestamp + 1
                                                    transaction:transaction];
    }
    
    if(needSystemMessage && updateGroupInfo.length){
        
        TSInfoMessage *systemMsg = [[TSInfoMessage alloc] initWithTimestamp:timestamp
                                         inThread:newGroupThread
                                      messageType:TSInfoMessageTypeGroupUpdate
                                   customMessage:updateGroupInfo];
        systemMsg.shouldAffectThreadSorting = tmpShouldAffectSorting;
        [systemMsg anyInsertWithTransaction:transaction];
        if([whoJoined containsObject:[TSAccountManager sharedInstance].localNumber] && DTParamsUtils.validateNumber(newGroupModel.publishRule) && ([newGroupModel.publishRule intValue] == 0 || [newGroupModel.publishRule intValue] == 1)){
            TSInfoMessage * publishRuleUpdateInfoMessage  = [DTGroupUpdateInfoMessageHelper groupUpdatePublishRuleInfoMessage:newGroupModel.publishRule timestamp:[NSDate ows_millisecondTimeStamp] serverTimestamp:envelope.systemShowTimestamp inThread:newGroupThread];
            if(publishRuleUpdateInfoMessage){
                [publishRuleUpdateInfoMessage anyInsertWithTransaction:transaction];
            }
        }
    }
    
//        if((generate && envelope && needSystemMessage) || [whoJoined containsObject:[TSAccountManager sharedInstance].localNumber]){
//            TSInfoMessage * publishRuleUpdateInfoMessage  = [DTGroupUpdateInfoMessageHelper groupUpdatePublishRuleInfoMessage:newGroupModel.publishRule timestamp:[NSDate ows_millisecondTimeStamp] serverTimestamp:envelope.systemShowTimestamp inThread:newGroupThread];
//            if(publishRuleUpdateInfoMessage){
//                [publishRuleUpdateInfoMessage saveWithTransaction:transaction];
//            }
//        }
    if(DTParamsUtils.validateString(groupInfo.avatar)){
        [self avatarUpdate:groupInfo.avatar
                   version:newGroupModel.version
                   groupId:groupId
                  envelope:envelope
              needSystemMessage:needSystemMessage
               groupThread:newGroupThread
           completionBlock:^{
            
        }];
    }
    
    return newGroupThread;
}

/// 自己被拉进群：DTGroupNotifyTypeMemberChanged，members只有自己,group为nil
/// 别人创建群组有自己：DTGroupNotifyActionAdd，members和group全量（待确认）
- (void)handleGroupUpdateMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                     display:(BOOL)display
                           groupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                                 transaction:(SDSAnyWriteTransaction *)transaction {
    
    NSString *localNumber = [self localNumber:transaction];
    
    if(!groupNotifyEntity.gid.length){
        OWSProdError(@"groupNotifyEntity.gid.length <= 0")
        return;
    }
    
    //本地退群、解散群，无需处理
    if ([groupNotifyEntity.source isEqualToString:localNumber] &&
        groupNotifyEntity.sourceDeviceId == OWSDevice.currentDeviceId) {
        if (groupNotifyEntity.groupNotifyDetailedType == DTGroupNotifyDetailTypeLeaveGroup ||
            groupNotifyEntity.groupNotifyDetailedType == DTGroupNotifyDetailTypeDismissGroup) {
            return;
        }
    }
    
    NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:groupNotifyEntity.gid];
    BOOL isNewGroupThread = false;
    TSGroupThread *newGroupThread = [TSGroupThread getOrCreateThreadWithGroupId:groupId generate:&isNewGroupThread transaction:transaction];
    TSGroupModel *oldGroupModel = newGroupThread.groupModel;
    BOOL needSystemMessage = YES;
    
    if ([groupNotifyEntity.source isEqualToString:localNumber] &&
        groupNotifyEntity.sourceDeviceId == OWSDevice.currentDeviceId) {
        
        uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
        TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:oldGroupModel];
        [self processGroupUpdateDetailNotifyForSelfHandlerWithEnvelope:envelope
                                                     groupNotifyEntity:groupNotifyEntity
                                                               display:display
                                                         oldGroupModel:oldGroupModel
                                                         newGroupModel:newGroupModel
                                                        newGroupThread:newGroupThread
                                                             timeStamp:timestamp
                                                           transaction:transaction];
        
        //drop
        return;
    }
    
    // 1.不依赖群组版本号变更:
    //  DTGroupNotifyTypeCallEndFeedback
    //  DTGroupNotifyTypeGroupCycleReminder
    //  DTGroupNotifyTypeMeetingReminder
    //  DTGroupNotifyDetailTypeGroupInactive
    //  DTGroupNotifyDetailTypeArchive
    
    if (![self isNeedTrackVersionWithGroupNotifyEntity:groupNotifyEntity]) {
        [self handleDonotTrackVersioWithEnvelope:envelope
                               groupNotifyEntity:groupNotifyEntity
                                   oldGroupModel:oldGroupModel
                                  newGroupThread:newGroupThread
                                     transaction:transaction];
        return;
    }
    
    // 2.依赖群组版本号变更
    if(groupNotifyEntity.groupNotifyType != DTGroupNotifyTypePersonalConfig){
        NSInteger diff = groupNotifyEntity.groupVersion - oldGroupModel.version;
        if(diff > 1){
            // 全量更新
            [self requestGroupInfoWithGroupId:groupId
                                targetVersion:groupNotifyEntity.groupVersion
                            needSystemMessage:needSystemMessage
                                     generate:isNewGroupThread
                                     envelope:envelope
                            groupNotifyEntity:groupNotifyEntity
                                  transaction:transaction
                                   completion:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                
            }];
            
            [[DTPinnedDataSource shared] syncPinnedMessageWithServer:groupNotifyEntity.gid];
            DTGroupBaseInfoEntity *baseInfo = [DTGroupBaseInfoEntity new];
            baseInfo.name = [newGroupThread nameWithTransaction:nil];
            baseInfo.gid = newGroupThread.serverThreadId;
            [DTGroupUtils addGroupBaseInfo:baseInfo transaction:transaction];
            return;
        }else if (diff < 1){
            //drop
            return;
        }
    }
    
    TSGroupModel *newGroupModel = [DTGroupUtils createNewGroupModelWithGroupModel:oldGroupModel];
    newGroupModel.version = groupNotifyEntity.groupVersion;
    // TODO: 搞清楚只有 DTGroupNotifyActionUpdate action 会触发时，移动到 action 处
    if (groupNotifyEntity.group) {
        if (DTParamsUtils.validateNumber(groupNotifyEntity.group.invitationRule)) {
            newGroupModel.invitationRule = groupNotifyEntity.group.invitationRule;
            OWSLogInfo(@"%@ notify ------ invitationRule=%@", groupNotifyEntity.group.name, groupNotifyEntity.group.invitationRule);
        }
        
        if (DTParamsUtils.validateNumber(groupNotifyEntity.group.messageExpiry)) {
            newGroupModel.messageExpiry = groupNotifyEntity.group.messageExpiry;
        }
        
        if (DTParamsUtils.validateString(groupNotifyEntity.group.remindCycle)) {
            newGroupModel.remindCycle = groupNotifyEntity.group.remindCycle;
        }
    }
    
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    if(envelope.hasSystemShowTimestamp && envelope.systemShowTimestamp > 0){
        timestamp = envelope.systemShowTimestamp;
    }
    
    [self processGroupUpdateDetailNotifyHandlerWithEnvelope:envelope
                                          groupNotifyEntity:groupNotifyEntity
                                                    display:display
                                              oldGroupModel:oldGroupModel
                                              newGroupModel:newGroupModel
                                             newGroupThread:newGroupThread
                                                  timeStamp:timestamp
                                                transaction:transaction];
    
}

- (void)handleGroupMessageArchiveChangedWithOldGroupModel:(TSGroupModel *)oldGroupModel
                                            newGroupModel:(TSGroupModel *)newGroupModel
                                           newGroupThread:(TSGroupThread *)newGroupThread
                                                timestamp:(uint64_t)timestamp
                                              transaction:(SDSAnyWriteTransaction *)transaction {
    
    if (DTParamsUtils.validateNumber(newGroupModel.messageExpiry) && [DTGroupUtils isChangedArchiveMessageStringWithOldGroupModel:oldGroupModel newModel:newGroupModel]) {
        
        [transaction addAsyncCompletionOnMain:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DTGroupMessageExpiryConfigChangedNotification object:nil];
        }];
    }
}

- (NSString *)baseInfoUpdate:(DTGroupNotifyEntity *)groupNotifyEntity
               oldGroupModel:(TSGroupModel *)oldGroupModel
               newGroupModel:(TSGroupModel *)newGroupModel
   shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                 transaction:(SDSAnyWriteTransaction *)transaction {
    if(!groupNotifyEntity.group){
        return nil;
    }
    newGroupModel.groupName = groupNotifyEntity.group.name;
    
    BOOL tmpShouldAffectSorting = NO;
    NSString *updateGroupInfo = [DTGroupUtils getBaseInfoStringWithOldGroupModel:oldGroupModel
                                                                        newModel:newGroupModel
                                                                          source:groupNotifyEntity.source
                                                       shouldAffectThreadSorting:&tmpShouldAffectSorting];
    *shouldAffectThreadSorting = tmpShouldAffectSorting;
    
    return updateGroupInfo;
}

- (void)avatarUpdate:(NSString *)avatar
             version:(NSInteger)version
             groupId:(NSData *)groupId
            envelope:(DSKProtoEnvelope *)envelope
        needSystemMessage:(BOOL)needSystemMessage
         groupThread:(TSGroupThread *)groupThread
     completionBlock:(void(^)(void))completionBlock
{
    if(!avatar.length || !groupId.length || !groupThread){
        return;
    }
    
    self.groupAvatarUpdateProcessor.groupThread = groupThread;
    
    [self.groupAvatarUpdateProcessor handleReceivedGroupAvatarUpdateWithAvatarUpdate:avatar
                                                                             success:^(TSAttachmentStream * _Nonnull attachmentStream) {
        dispatch_async(self.class.serialQueue, ^{
            UIImage *image = [attachmentStream image];
            if(image){
                
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    
                    TSGroupThread *newGroupThread = [TSGroupThread getOrCreateThreadWithGroupId:groupId transaction:writeTransaction];
                    if(version < newGroupThread.groupModel.groupAvatarVersion){
                        return;
                    }
                    BOOL tmpShouldAffectSorting = NO;
                    TSGroupModel *newGroupModel = [TSGroupModel new];
                    newGroupModel.groupImage = image;
                    newGroupModel.groupName = newGroupThread.groupModel.groupName;
                    NSString *updateGroupSting = [DTGroupUtils getBaseInfoStringWithOldGroupModel:newGroupThread.groupModel
                                                                                         newModel:newGroupModel
                                                                                           source:@""
                                                                        shouldAffectThreadSorting:&tmpShouldAffectSorting];
                    [newGroupThread anyUpdateGroupThreadWithTransaction:writeTransaction
                                                                  block:^(TSGroupThread * instance) {
                        instance.groupModel.groupImage = image;
                        instance.groupModel.groupAvatarVersion = version;
                    }];
                    
                    [newGroupThread fireAvatarChangedNotification];
                    
                    if(needSystemMessage && updateGroupSting.length){
                        uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                        if(envelope.hasSystemShowTimestamp && envelope.systemShowTimestamp > 0){
                            timestamp = envelope.systemShowTimestamp;
                        }
                        TSInfoMessage *systemMsg = [[TSInfoMessage alloc] initWithTimestamp:timestamp
                                                         inThread:newGroupThread
                                                      messageType:TSInfoMessageTypeGroupUpdate
                                                    customMessage:updateGroupSting];
                        systemMsg.shouldAffectThreadSorting = tmpShouldAffectSorting;
                        [systemMsg anyInsertWithTransaction:writeTransaction];
                    }
                    
                    [writeTransaction addAsyncCompletionOnMain:^{
                        if(completionBlock){
                            completionBlock();
                        }
                    }];
                });
            }else{
                DDLogInfo(@"update avatar data empty");
                OWSProdError(@"update avatar data empty");
                if(completionBlock){
                    completionBlock();
                }
            }
        });

    } failure:^(NSError * _Nonnull error) {
        DDLogInfo(@"update avatar data error");
        OWSProdError(@"update avatar data error");
        if(completionBlock){
            completionBlock();
        }
    }];
}

- (NSString *)membersUpdateWithMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                        thread:(TSGroupThread *)thread
                                  isNewGroupThread:(BOOL)isNewGroupThread
                                           members:(NSArray <DTGroupMemberNotifyEntity *> *)members
                                     oldGroupModel:(TSGroupModel *)oldGroupModel
                                     newGroupModel:(TSGroupModel *)newGroupModel
                         shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                       transaction:(SDSAnyWriteTransaction *)transaction {
    
    if(!members.count){
        return nil;
    }
    
    NSMutableArray *joinedMemberIds = @[].mutableCopy;
    NSMutableArray *removedMemberIds = @[].mutableCopy;
    NSMutableArray *leftMemberIds = @[].mutableCopy;
    NSMutableArray *admidsMemberIds = @[].mutableCopy;//新增的群管理人员 变成群管理角色
    NSMutableArray *normalMemberIds = @[].mutableCopy;//新移除的群管理人员 变成了member了
    __block NSString *groupOwner = @"";
    NSMutableArray *signalAccounts = @[].mutableCopy;
    
    [members enumerateObjectsUsingBlock:^(DTGroupMemberNotifyEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        BOOL isExternal = NO;
        switch (obj.action) {
            case DTGroupNotifyActionAdd:
            {
                if(![newGroupModel.groupMemberIds containsObject:obj.uid]){
                    [joinedMemberIds addObject:obj.uid];
                    SignalAccount *account = [self saveExternalMember:obj
                                                           isExternal:&isExternal
                                                          transaction:transaction];
                    if(account){
                        [signalAccounts addObject:account];
                    }
                }
                if(isNewGroupThread && ![joinedMemberIds containsObject:[TSAccountManager sharedInstance].localNumber]){
                    [joinedMemberIds addObject:[TSAccountManager sharedInstance].localNumber];
                }
            }
                break;
            case DTGroupNotifyActionUpdate:
            {
                if ([newGroupModel.groupMemberIds containsObject:obj.uid] ) {//更新群组成员信息
                    if (obj.role == DTGroupMemberRoleAdmin ) {//群管理员
                        [admidsMemberIds addObject:obj.uid];
                    }else if (obj.role == DTGroupMemberRoleMember){//群成员
                        [normalMemberIds addObject:obj.uid];
                        SignalAccount *account = [self saveExternalMember:obj
                                                               isExternal:&isExternal
                                                              transaction:transaction];
                        if(account){
                            [signalAccounts addObject:account];
                        }
                    }
                }
            }
                break;
            case DTGroupNotifyActionDelete:
            {
                NSString *uid = obj.uid;
                if([newGroupModel.groupMemberIds containsObject:uid]){
                    [removedMemberIds addObject:uid];
                    DTGroupRAPIDRole rapidRole = [oldGroupModel rapidRoleFor:uid];
                    if (rapidRole != DTGroupRAPIDRoleNone) {
                        [newGroupModel removeRapidRole:uid];
                        [DTGroupUtils postRapidRoleChangeNotificationWithGroupModel:newGroupModel
                                                                    targedMemberIds:@[uid]];
                    }
                }
            }
                break;
            case DTGroupNotifyActionLeave:
            {
                NSString *uid = obj.uid;

                if([newGroupModel.groupMemberIds containsObject:uid]){
                    [leftMemberIds addObject:uid];
                    DTGroupRAPIDRole rapidRole = [oldGroupModel rapidRoleFor:uid];
                    if (rapidRole != DTGroupRAPIDRoleNone) {
                        [newGroupModel removeRapidRole:uid];
                        [DTGroupUtils postRapidRoleChangeNotificationWithGroupModel:newGroupModel
                                                                    targedMemberIds:@[uid]];
                    }
                }
            }
                break;
            default:
                break;
        }
        
        if(obj.role == DTGroupMemberRoleOwner){
            groupOwner = obj.uid;
        }
    }];
    
    if(signalAccounts.count){
//        [self.contactsManager updateWithSignalAccounts:signalAccounts transaction:transaction];
        [self.contactsManager updateWithSignalAccounts:signalAccounts];
    }
    
    if(DTParamsUtils.validateString(groupOwner)){
        newGroupModel.groupOwner = groupOwner;
    }
    
    NSString *updateGroupInfo;
    BOOL tmpShouldAffectSorting = NO;
    if (![oldGroupModel.groupOwner isEqualToString:groupOwner] && ![groupOwner isEqualToString:@""] && oldGroupModel.groupOwner) {
        NSMutableSet *newGroupAddminIds = [[NSMutableSet alloc]initWithArray:newGroupModel.groupAdmin];
        if (newGroupAddminIds && [newGroupAddminIds containsObject:groupOwner]) {
            [newGroupAddminIds removeObject:groupOwner];
        }
        newGroupModel.groupAdmin = newGroupAddminIds.allObjects;
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithTransferOwer:groupOwner shouldAffectThreadSorting:&tmpShouldAffectSorting transaction:transaction];
    }else if(admidsMemberIds.count){
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithAddedAdminIds:admidsMemberIds removedIds:nil transaction:transaction];
    }else if(normalMemberIds.count){
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithAddedAdminIds:nil removedIds:normalMemberIds transaction:transaction];
    }else {
        updateGroupInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:joinedMemberIds
                                                                               removedMemberIds:removedMemberIds
                                                                                  leftMemberIds:leftMemberIds
                                                                      shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                                    transaction:transaction];
        if(!isNewGroupThread && [joinedMemberIds containsObject:[TSAccountManager sharedInstance].localNumber] && DTParamsUtils.validateNumber(newGroupModel.publishRule) && ([newGroupModel.publishRule intValue] == 0 || [newGroupModel.publishRule intValue] == 1)){
            TSInfoMessage * publishRuleUpdateInfoMessage  = [DTGroupUpdateInfoMessageHelper groupUpdatePublishRuleInfoMessage:newGroupModel.publishRule timestamp:[NSDate ows_millisecondTimeStamp] serverTimestamp:envelope.systemShowTimestamp inThread:thread];
            if(publishRuleUpdateInfoMessage){
                [publishRuleUpdateInfoMessage anyInsertWithTransaction:transaction];
            }
        }
    }
             
    *shouldAffectThreadSorting = tmpShouldAffectSorting;
    
    if (admidsMemberIds.count) {
        NSMutableSet *newGroupAddminIds = [NSMutableSet set];
        if (newGroupModel.groupAdmin && newGroupModel.groupAdmin.count) {
            [newGroupAddminIds addObjectsFromArray:newGroupModel.groupAdmin];
        }
        [newGroupAddminIds addObjectsFromArray:admidsMemberIds];
        newGroupModel.groupAdmin = newGroupAddminIds.allObjects;
    }
                  
    if(normalMemberIds.count){
        NSMutableSet *newAdminMemberIds = [NSMutableSet set];
        if(newGroupModel.groupAdmin && newGroupModel.groupAdmin.count){
            [newAdminMemberIds addObjectsFromArray:newGroupModel.groupAdmin];
        }
            for (NSString *receptied_uid in normalMemberIds) {
                if ([newAdminMemberIds containsObject:receptied_uid]) {
                    [newAdminMemberIds removeObject:receptied_uid];
                }
            }
           newGroupModel.groupAdmin = newAdminMemberIds.allObjects;
    }
                  
    if(joinedMemberIds.count){
        
        NSMutableSet *newMemberIds = [NSMutableSet set];
        if(newGroupModel.groupMemberIds.count){
            [newMemberIds addObjectsFromArray:newGroupModel.groupMemberIds];
        }
        if(joinedMemberIds.count){
            [newMemberIds addObjectsFromArray:joinedMemberIds];
        }
        newGroupModel.groupMemberIds = newMemberIds.allObjects;
    }
    
    if (removedMemberIds.count){ // TODO: 抽出方法
        NSMutableArray *newMemberIds = newGroupModel.groupMemberIds.mutableCopy;
        [newMemberIds removeObjectsInArray:removedMemberIds];
        newGroupModel.groupMemberIds = newMemberIds.copy;
        
        NSMutableArray *newAdminMemberIds = newGroupModel.groupAdmin.mutableCopy;
        [removedMemberIds enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (DTParamsUtils.validateString(obj)) {
                if ([newAdminMemberIds containsObject:obj]) {
                    [newAdminMemberIds removeObject:obj];
                }
            }
        }];
        newGroupModel.groupAdmin = newAdminMemberIds.copy;
    }
    
    if (leftMemberIds.count){ // TODO: 抽出方法
        NSMutableArray *newMemberIds = newGroupModel.groupMemberIds.mutableCopy;
        [newMemberIds removeObjectsInArray:leftMemberIds];
        newGroupModel.groupMemberIds = newMemberIds.copy;
        
        NSMutableArray *newAdminMemberIds = newGroupModel.groupAdmin.mutableCopy;
        [leftMemberIds enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (DTParamsUtils.validateString(obj)) {
                if ([newAdminMemberIds containsObject:obj]) {
                    [newAdminMemberIds removeObject:obj];
                }
            }
        }];
        newGroupModel.groupAdmin = newAdminMemberIds.copy;
    }
    
    return updateGroupInfo;
}

- (void)recieveGroupRapidRoleChangedWith:(DTGroupNotifyEntity *)groupNotifyEntity
                          newGroupThread:(TSGroupThread *)newGroupThread
                           oldGroupModel:(TSGroupModel *)oldGroupModel
                           newGroupModel:(TSGroupModel *)newGroupModel
                             transaction:(SDSAnyWriteTransaction *)transaction {
  
    if (groupNotifyEntity.groupNotifyDetailedType != DTGroupNotifyDetailTypeGroupRapidRoleChange) {
        return;
    }
    
    NSMutableArray <NSString *> *rapidChangedIds = @[].mutableCopy;
    
    NSArray <DTGroupMemberNotifyEntity *> *members = groupNotifyEntity.members;
    if (!DTParamsUtils.validateArray(members)) {
        return;
    }
    [members enumerateObjectsUsingBlock:^(DTGroupMemberNotifyEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {

        if (!obj.uid) return;
        NSString *uid = obj.uid;
        [rapidChangedIds addObject:uid];

        [newGroupModel addRapidRole:obj.rapidRole memberId:uid];
        [DTGroupUtils sendRAPIDRoleChangedMessageWithOperatorId:groupNotifyEntity.source
                                                  otherMemberId:uid
                                                      rapidRole:obj.rapidDescription
                                                serverTimestamp:0
                                                         thread:newGroupThread
                                                    transaction:transaction];
    }];
    
    NSArray <NSString *> *targetRapidChangedIds = [rapidChangedIds copy];
    
    [newGroupThread anyUpdateGroupThreadWithTransaction:transaction
                                                  block:^(TSGroupThread * instance) {
        instance.groupModel = newGroupModel;
    }];
    
    OWSLogInfo(@"[RAPID] old:\n%@\n--------\nnew:\n%@", oldGroupModel.description, newGroupModel.description);
    
    
    [transaction addAsyncCompletionOnMain:^{
        [DTGroupUtils postRapidRoleChangeNotificationWithGroupModel:newGroupModel
                                                    targedMemberIds:targetRapidChangedIds];
    }];
    
}

- (NSString *)dismissGroupWithGroupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                                  oldGroupModel:(TSGroupModel *)oldGroupModel
                                  newGroupModel:(TSGroupModel *)newGroupModel{
    
    newGroupModel.groupMemberIds = @[];
//    newGroupModel.memberJoinDateMap = @{};
    return Localized(@"GROUP_DISMISSED", nil);
}

- (void)announcementsUpdate:(NSArray <DTGroupAnnouncementNotifyEntity *> *)announcements
              oldGroupModel:(TSGroupModel *)oldGroupModel
              newGroupModel:(TSGroupModel *)newGroupModel{
    
    if(!announcements.count){
        return;
    }
    
    //TODO: kris
    
}

- (void)personalConfigWithGroupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                              oldGroupModel:(TSGroupModel *)oldGroupModel
                              newGroupModel:(TSGroupModel *)newGroupModel
                            completionBlock:(void(^)(void))completionBlock{
    
    @weakify(self);
    [self.getPersonalConfigAPI sendRequestWithWithGroupId:groupNotifyEntity.gid
                                                  success:^(DTGroupMemberEntity * _Nonnull entity) {
        @strongify(self);
        dispatch_async(self.class.serialQueue, ^{
           
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                
                NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:groupNotifyEntity.gid];
                TSGroupThread *newGroupThread = [TSGroupThread getOrCreateThreadWithGroupId:groupId transaction:writeTransaction];
                [newGroupThread anyUpdateGroupThreadWithTransaction:writeTransaction
                                                              block:^(TSGroupThread * instance) {
                    instance.groupModel.notificationType = @(entity.notification);
                    instance.groupModel.useGlobal = entity.useGlobal;
                }];
                
                [writeTransaction addAsyncCompletionOnMain:^{
                    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTPersonalGroupConfigChangedNotification object:nil];
                    completionBlock();
                }];
            })
        });
        
    } failure:^(NSError * _Nonnull error) {
        OWSProdError(@"personalConfig");
    }];
}

- (void)pinMessageUpdateWithGroupNotify:(DTGroupNotifyEntity *)groupNotify
                            transaction:(SDSAnyWriteTransaction *)transaction {
    
    if (!DTParamsUtils.validateArray(groupNotify.groupPins)) {
        return;
    }
    NSArray <DTPinnedMessageNotifyEntity *> *notityPinnedMessages = groupNotify.groupPins;
    [notityPinnedMessages enumerateObjectsUsingBlock:^(DTPinnedMessageNotifyEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (obj.action == 0) {
            //MARK: 新增pin
            DTPinnedMessage *newPinned = [DTPinnedMessage parseBase64StringToPinnedMessage:obj groupId:groupNotify.gid transaction:transaction];
            newPinned.pinId = obj.pinId;
            [newPinned anyInsertWithTransaction:transaction];
        
            NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:groupNotify.gid];
            TSGroupThread *groupThread = [TSGroupThread getOrCreateThreadWithGroupId:groupId transaction:transaction];
            [DTGroupUtils sendPinSystemMessageWithSource:obj.creator serverTimestamp:0 thread:groupThread pinnedMessage:newPinned transaction:transaction];
            [newPinned downloadAllAttachmentWithTransaction:transaction success:nil failure:nil];
        } else if (obj.action == 3) {
            //MARK: 移除pin
            DTPinnedMessage *localPinned = [DTPinnedMessage anyFetchWithUniqueId:obj.pinId transaction:transaction];
            [localPinned removePinMessageWithTransaction:transaction];
        }
    }];
}

- (TSGroupThread *)generateConverationByInviteWithGroupId:(NSData *)groupId
                                                groupInfo:(DTGetGroupInfoDataEntity *)groupInfo
                                              transaction:(SDSAnyWriteTransaction *)transaction {
    TSGroupThread *newGroupThread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
    BOOL isNewGroupThread = false;
    if(!newGroupThread){
        isNewGroupThread = true;
    }
    [self generateOrUpdateConverationWithGroupId:groupId
                               needSystemMessage:NO
                                        generate:isNewGroupThread
                                        envelope:nil
                                       groupInfo:groupInfo
                               groupNotifyEntity:nil
                                     transaction:transaction];
    
    uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
    NSString *customMessage = [NSString stringWithFormat:Localized(@"GROUP_MEMBER_JOINED", @""), Localized(@"YOU", @"")];

    TSInfoMessage *systemMsg = [[TSInfoMessage alloc] initWithTimestamp:timestamp
                                                               inThread:newGroupThread
                                                            messageType:TSInfoMessageTypeGroupUpdate
                                                          customMessage:customMessage];
    systemMsg.shouldAffectThreadSorting = YES;
    [systemMsg anyInsertWithTransaction:transaction];
    
    return newGroupThread;
}

- (SignalAccount *)saveExternalMember:(DTGroupMemberEntity *)member
                           isExternal:(BOOL *)isExternal
                          transaction:(SDSAnyWriteTransaction *)transaction {
    
    *isExternal = NO;
    SignalAccount *signalAccount = [SignalAccount signalAccountWithRecipientId:member.uid transaction:transaction];
    if (signalAccount && [signalAccount isKindOfClass:[SignalAccount class]]) {
        *isExternal = signalAccount.contact.isExternal;
        if (!signalAccount.contact.isExternal || (signalAccount.contact.isExternal && [signalAccount.contact.groupDisplayName isEqualToString:member.displayName] && [signalAccount.contact.extId isEqualToNumber:member.extId])) {
            return nil;
        }
    }
    
    *isExternal = YES;
    SignalAccount *newAccount = nil;
    if (signalAccount) {
        newAccount = signalAccount;
        newAccount.contact.groupDisplayName = member.displayName;
        newAccount.contact.extId = member.extId;
        newAccount.contact.external = YES;
    } else {
        newAccount = [[SignalAccount alloc] initWithRecipientId:member.uid];
        newAccount.isManualEdited = YES;
        Contact *contact = [Contact new];
        contact.groupDisplayName = member.displayName;
        contact.number = member.uid;
        contact.extId = member.extId;
        contact.external = YES;
        newAccount.contact = contact;
    }
    
    return newAccount;

//    [self.contactsManager updateSignalAccountWithRecipientId:member.uid withNewSignalAccount:newAccount transaction:transaction];
}

- (NSString *)localNumber:(SDSAnyWriteTransaction *) transaction{

    return [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
}

@end
