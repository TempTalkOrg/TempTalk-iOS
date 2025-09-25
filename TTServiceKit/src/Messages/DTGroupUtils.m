//
//  DTGroupUtils.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/29.
//

#import "DTGroupUtils.h"
#import "TextSecureKitEnv.h"
#import "FunctionalUtil.h"
#import "ContactsManagerProtocol.h"
#import "TSGroupModel.h"
#import "TSGroupThread.h"
#import "TSMessage.h"
#import "DTGetMyGroupsAPI.h"
#import "DTChatFolderManager.h"
#import "DTPinnedMessage.h"
#import "TSInfoMessage.h"
#import "NSDate+OWS.h"
#import "DTGroupConfig.h"
#import "DTServerConfigManager.h"
#import "DTThreadHelper.h"
#import "NSNotificationCenter+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTParamsBaseUtils.h"
#import "DTGroupNotifyEntity.h"

NSString *const DTGroupPeriodicRemindNotification = @"DTGroupPeriodicRemindNotification";
NSString *const DTGroupMemberRapidRoleChangedNotification = @"DTGroupMemberRapidRoleChangedNotification";
NSString *const DTGroupExternalChangedNotification = @"DTGroupExternalChangedNotification";
NSString *const DTGroupBaseInfoChangedNotification = @"DTGroupBaseInfoChangedNotification";

NSString *const DTRapidRolesKey = @"DTRapidRolesKey";

@interface DTGroupUtils()

@property (class, nonatomic, readonly) NSString *localNumber;

@end

@implementation DTGroupUtils

+ (TSGroupModel *)createNewGroupModelWithGroupModel:(TSGroupModel *)groupModel{
    TSGroupModel *newGroupModel = [groupModel copy];
        
    return newGroupModel;
}

+ (id<ContactsManagerProtocol>)contactsManager{
    return [TextSecureKitEnv sharedEnv].contactsManager;
}

+ (NSString *)getMemberChangedInfoStringWithTransferOwer:(NSString *_Nullable)receptid
                               shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                             transaction:(SDSAnyReadTransaction *)transaction {
    NSString *updatedGroupInfoString = @"";
    NSArray *owerIdArr = @[receptid];
    __block BOOL tmpShouldAffectSorting = NO;
    NSArray *owerIdArrNames = [owerIdArr map:^NSString*(NSString* item) {
        if([item isEqualToString:self.localNumber]){
            tmpShouldAffectSorting = YES;
            return Localized(@"YOU", nil);
        }
        return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
    }];
    *shouldAffectThreadSorting = tmpShouldAffectSorting;
    updatedGroupInfoString = [NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_BECOME_OWER", @""),owerIdArrNames.firstObject];
    
    return updatedGroupInfoString;
}

//新增和删除群成员的信息
+ (NSString *)getMemberChangedInfoStringWithAddedAdminIds:(NSArray *_Nullable)addedAdminIds//添加的管理员
                                               removedIds:(NSArray *_Nullable)removedAdminsIds
                                              transaction:(SDSAnyReadTransaction *)transaction{
    NSString *updatedGroupInfoString = @"";
    if (addedAdminIds.count) {
        NSArray *addedAdminNames = [addedAdminIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]){
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        
        if (addedAdminIds.count == 1) {
            updatedGroupInfoString = [NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_BECOME_ADMIN", @""),addedAdminNames.firstObject];
           
        }else {
            [updatedGroupInfoString stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_BECOME_ADMIN", @""),
                                                               [addedAdminNames componentsJoinedByString:@", "]]];
        }
    }
    
    if (removedAdminsIds.count) {
        NSArray *removedAdminsNames = [removedAdminsIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]){
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        if (removedAdminsIds.count == 1) {
            NSString *tipString = [NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_DELETE_ADMIN", @""),removedAdminsNames.firstObject];
            updatedGroupInfoString = tipString;
           
        }else {
            [updatedGroupInfoString stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_DELETE_ADMIN", @""),
                                                               [removedAdminsNames componentsJoinedByString:@", "]]];
        }
    }
    
    return updatedGroupInfoString;
}

+ (NSString *)getMemberChangedInfoStringWithJoinedMemberIds:(NSArray *)joinedMemberIds
                                           removedMemberIds:(NSArray *)removedMemberIds
                                              leftMemberIds:(NSArray *)leftMemberIds
                                            updateMemberIds:(NSArray *)updateMemberIds
                                              oldGroupModel:(TSGroupModel *)oldGroupModel
                                              newGroupModel:(TSGroupModel *)newGroupModel
                                  shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                                transaction:(SDSAnyReadTransaction *)transaction{
    NSString *updatedGroupInfoString = @"";
    BOOL tmpShouldAffectSorting = NO;
    if (updateMemberIds.count) {
        NSArray *updateMemberNames = [updateMemberIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]){
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        //群主不一样默认是更新了群主
        if (![oldGroupModel.groupOwner isEqualToString:newGroupModel.groupOwner]) {
            [updatedGroupInfoString stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_BECOME_ADMIN", @""),
                                                               [updateMemberNames componentsJoinedByString:@", "]]];
            return updatedGroupInfoString;
        }
        
        NSMutableSet *oldAdminSet = [[NSMutableSet alloc] initWithArray:oldGroupModel.groupAdmin];//老的群管理员的集
        NSMutableSet *newAdminSet = [[NSMutableSet alloc] initWithArray:newGroupModel.groupAdmin];//新的群管理的集合
        
        //获取两个集合的交集
        NSMutableSet *intersectSet = [oldAdminSet mutableCopy];
        [intersectSet intersectSet:newAdminSet];
        
        //删除的用户id集合
        NSMutableSet *removeedSet = [oldAdminSet mutableCopy];
        [removeedSet minusSet:intersectSet];
        
        //增加的用户id集合
        NSMutableSet *addedSet = [newAdminSet mutableCopy];
        [addedSet minusSet:intersectSet];
        
        
        // 群主是一样的
        updatedGroupInfoString = [updatedGroupInfoString
                                  stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_MEMBER_INFO_UPDATE_BECOME_ADMIN", @""),
                                                           [updateMemberNames componentsJoinedByString:@", "]]];
    }
    if (updatedGroupInfoString.length == 0) {
        NSString *tmpInfoString = [self getMemberChangedInfoStringWithJoinedMemberIds:joinedMemberIds
                                                                     removedMemberIds:removedMemberIds
                                                                        leftMemberIds:leftMemberIds
                                                            shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                          transaction:transaction];
        *shouldAffectThreadSorting = tmpShouldAffectSorting;
        return tmpInfoString;
    }else {
        return updatedGroupInfoString;
    }
}

+ (NSString *)getMemberChangedInfoStringWithJoinedMemberIds:(NSArray *)joinedMemberIds
                                           removedMemberIds:(NSArray *)removedMemberIds
                                              leftMemberIds:(NSArray *)leftMemberIds
                                  shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                                transaction:(SDSAnyReadTransaction *)transaction {
    
    NSString *updatedGroupInfoString = @"";
    __block BOOL tmpShouldAffectSorting = NO;
    if(joinedMemberIds.count){
        NSArray *newMembersNames = [joinedMemberIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]) {
                tmpShouldAffectSorting = YES;
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        if (newMembersNames.count > 0) {
            updatedGroupInfoString = [updatedGroupInfoString
                                      stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_MEMBER_JOINED", @""),
                                                               [newMembersNames componentsJoinedByString:@", "]]];
        }
    }
    if (removedMemberIds.count){
        NSArray<NSString *> *oldMembersNames = [removedMemberIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]){
                tmpShouldAffectSorting = YES;
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        if (oldMembersNames.count == 1) {
            if ([oldMembersNames.firstObject isEqualToString:Localized(@"YOU", nil)]) {
                updatedGroupInfoString = [updatedGroupInfoString
                                          stringByAppendingString:[NSString
                                                                   stringWithFormat:Localized(@"UPDATE_GROUP_MESSAGE_BODY_REMOVE_MEMBERS", @""),
                                                                   [oldMembersNames componentsJoinedByString:@", "]]];
            } else {
                updatedGroupInfoString = [updatedGroupInfoString
                                          stringByAppendingString:[NSString
                                                                   stringWithFormat:Localized(@"UPDATE_GROUP_MESSAGE_BODY_REMOVE_MEMBER", @""),
                                                                   [oldMembersNames componentsJoinedByString:@", "]]];
            }
        } else {
            updatedGroupInfoString = [updatedGroupInfoString
                                      stringByAppendingString:[NSString
                                                               stringWithFormat:Localized(@"UPDATE_GROUP_MESSAGE_BODY_REMOVE_MEMBERS", @""),
                                                               [oldMembersNames componentsJoinedByString:@", "]]];
        }
    }
    if (leftMemberIds.count){
        NSArray *oldMembersNames = [leftMemberIds map:^NSString*(NSString* item) {
            if([item isEqualToString:self.localNumber]){
                return Localized(@"YOU", nil);
            }
            return [self.contactsManager displayNameForPhoneIdentifier:item transaction:transaction];
        }];
        updatedGroupInfoString = [updatedGroupInfoString
                                  stringByAppendingString:[NSString
                                                           stringWithFormat:Localized(@"GROUP_MEMBER_LEFT", @""),
                                                           [oldMembersNames componentsJoinedByString:@", "]]];
    }
    *shouldAffectThreadSorting = tmpShouldAffectSorting;
    
    return updatedGroupInfoString;
    
}


+ (NSString *)getBaseInfoStringWithOldGroupModel:(TSGroupModel *)oldGroupModel
                                        newModel:(TSGroupModel *)newModel
                                          source:(NSString *)source
                       shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting {
    NSString *updatedGroupInfoString = @"";

    if (![oldGroupModel.groupName isEqual:newModel.groupName]) {
        *shouldAffectThreadSorting = YES;
        NSString *displayName = nil;
        if(source.length){
            displayName = [self.contactsManager displayNameForPhoneIdentifier:source];
        }
        if(displayName.length){
            updatedGroupInfoString = [updatedGroupInfoString
                                      stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_NAME_CHANGED_SYSTEM_MSG", @""),
                                                               displayName ,newModel.groupName]];
        }else{
            updatedGroupInfoString = [updatedGroupInfoString
                                      stringByAppendingString:[NSString stringWithFormat:Localized(@"GROUP_TITLE_CHANGED", @""),
                                                               newModel.groupName]];
        }
    }
    if ((!oldGroupModel.groupImage && newModel.groupImage) ||
        (oldGroupModel.groupImage && !newModel.groupImage) ||
        (oldGroupModel.groupImage != nil && newModel.groupImage != nil &&
        !([UIImagePNGRepresentation(oldGroupModel.groupImage) isEqualToData:UIImagePNGRepresentation(newModel.groupImage)]))) {
        updatedGroupInfoString =
            [updatedGroupInfoString stringByAppendingString:Localized(@"GROUP_AVATAR_CHANGED", @"")];
    }

    return updatedGroupInfoString;
}

+ (BOOL)isChangedArchiveMessageStringWithOldGroupModel:(TSGroupModel *)oldGroupModel
                                              newModel:(TSGroupModel *)newModel{
    
    if (!oldGroupModel.messageExpiry ||
       ([oldGroupModel.messageExpiry doubleValue] == [newModel.messageExpiry doubleValue])) {
        return NO;
    }
    
    return YES;
    
}

+ (NSString *)getTranslateSettingChangedInfoStringWithUserChangeType:(DTTranslateMessageType )type {
    NSString * updatedGroupInfoString;
    switch (type) {
        case DTTranslateMessageTypeChinese:{
            updatedGroupInfoString = Localized(@"TRANSLATE_SETTINGS_SELECTED_CHINISE_LANGUAGE",@"");
        }
            break;
        case DTTranslateMessageTypeEnglish:{
            updatedGroupInfoString = Localized(@"TRANSLATE_SETTINGS_SELECTED_ENGLISH_LANGUAGE",@"");
            break;
        }
        case DTTranslateMessageTypeOriginal:{
            updatedGroupInfoString = Localized(@"TRANSLATE_SETTINGS_SELECTED_ORIGINAL",@"");
            break;
        }
        default:
            updatedGroupInfoString = nil;
            break;
    }
    return updatedGroupInfoString;
}

+ (void)syncMyGroupsBaseInfoSuccess:(void(^)(void))success failure:(void(^)(NSError *error))failure {
    
    DTGetMyGroupsAPI *getMyGroupsApi = [DTGetMyGroupsAPI new];
    [getMyGroupsApi sendRequestWithSuccess:^(NSArray<DTGroupBaseInfoEntity *> * _Nonnull groups) {
        NSMutableSet <NSString *> *serverGids = [NSMutableSet new];
        NSMutableSet <NSString *> *localGids = [NSMutableSet new];
        for (DTGroupBaseInfoEntity *baseInfo in groups) {
            [serverGids addObject:baseInfo.gid];
        }
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            
            [DTGroupBaseInfoEntity anyEnumerateWithTransaction:transaction
                                                       batched:YES
                                                         block:^(DTGroupBaseInfoEntity * object, BOOL * stop) {
                if ([object isKindOfClass:DTGroupBaseInfoEntity.class]) {
                    [localGids addObject:object.gid];
                }
            }];
        } completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) completion:^{
            if (serverGids.count == 0 && localGids.count == 0) {
                success();
                return;
            }
            [localGids minusSet:serverGids];
            [self removeLocalDiscardGids:[localGids.allObjects copy]];
            [self updateGroupBaseInfoWith:groups successCallBack:success];
        }];
    } failure:^(NSError * _Nonnull error) {
        if (failure) failure(error);
    }];
}

+ (void)removeLocalDiscardGids:(NSArray <NSString *>*)localGids {
    
    if (!localGids.count) {
        return;
    }
    
    NSInteger batchSize = 30;
    if (localGids.count > batchSize) {
            ///本地的废弃的群
            NSMutableArray *unHandleLocalDiscardGids = [localGids mutableCopy];
            while (unHandleLocalDiscardGids.count > 0) {
                __block NSInteger loopBatchIndex = 0;
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTtransaction) {
                    [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                        NSString * obj  = unHandleLocalDiscardGids.lastObject;
                        if (loopBatchIndex == batchSize || obj == nil) {*stop = YES;return;}
                        [unHandleLocalDiscardGids removeLastObject];
                        
                        DTGroupBaseInfoEntity *baseInfo = [DTGroupBaseInfoEntity anyFetchWithUniqueId:obj transaction:writeTtransaction];
                        [baseInfo anyRemoveWithTransaction:writeTtransaction];
                        loopBatchIndex += 1;
                    }];
                });
            }
        
    } else {
        NSMutableArray *unHandleLocalDiscardGids = [localGids mutableCopy];
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTtransaction) {
            [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                NSString * obj  = unHandleLocalDiscardGids.lastObject;
                if (obj == nil) {*stop = YES;return;}
                [unHandleLocalDiscardGids removeLastObject];
                DTGroupBaseInfoEntity *baseInfo = [DTGroupBaseInfoEntity anyFetchWithUniqueId:obj transaction:writeTtransaction];
                [baseInfo anyRemoveWithTransaction:writeTtransaction];
            }];
        });
    }
}

+ (void)updateGroupBaseInfoWith:(NSArray *)groups successCallBack:(void(^)(void))successCallBack {
    
    void (^newGroupModelBlock)(TSGroupModel *, DTGroupBaseInfoEntity *) = ^(TSGroupModel *groupModel, DTGroupBaseInfoEntity *baseInfo) {
        groupModel.remindCycle = baseInfo.remindCycle;
        groupModel.anyoneRemove = baseInfo.anyoneRemove;
        groupModel.rejoin = baseInfo.rejoin;
        groupModel.ext = baseInfo.ext;
        groupModel.invitationRule = baseInfo.invitationRule;
        groupModel.messageExpiry = baseInfo.messageExpiry;
        groupModel.publishRule = baseInfo.publishRule;
        groupModel.anyoneChangeName = baseInfo.anyoneChangeName;
        groupModel.anyoneChangeAutoClear = baseInfo.anyoneChangeAutoClear;
        groupModel.autoClear = baseInfo.autoClear;
        groupModel.privilegeConfidential = baseInfo.privilegeConfidential;
    };
    
    void (^saveNewThreadBlock)(DTGroupBaseInfoEntity *, SDSAnyWriteTransaction *) = ^(DTGroupBaseInfoEntity *baseInfo, SDSAnyWriteTransaction *transaction) {
        DTGroupBaseInfoEntity *localGroupInfo = [DTGroupBaseInfoEntity anyFetchWithUniqueId:baseInfo.uniqueId transaction:transaction];
        if (!localGroupInfo || ![localGroupInfo isEqual:baseInfo]) {
            
            [baseInfo anyUpsertWithTransaction:transaction];
            
            NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:baseInfo.gid];
            TSGroupThread *groupThread = [TSGroupThread threadWithGroupId:groupId
                                                              transaction:transaction];
            NSArray *memberIds = self.localNumber ? @[self.localNumber] : @[];
            TSGroupModel *newGroupModel = nil;
            if (!groupThread) {
                newGroupModel = [[TSGroupModel alloc] initWithTitle:baseInfo.name memberIds:memberIds image:nil groupId:groupId groupOwner:nil groupAdmin:nil transaction:transaction];
                newGroupModelBlock(newGroupModel, baseInfo);
                groupThread = [[TSGroupThread alloc] initWithGroupModel:newGroupModel];
                [groupThread anyInsertWithTransaction:transaction];
            } else {
                newGroupModel = [groupThread.groupModel copy];
                newGroupModelBlock(newGroupModel, baseInfo);
                if (![groupThread.groupModel isEqualToGroupBaseInfo:newGroupModel]) {
                    OWSLogDebug(@">>>>>%@", newGroupModel.groupName);
                    [groupThread anyUpdateWithTransaction:transaction
                                                    block:^(TSThread * instance) {
                        groupThread.groupModel = newGroupModel;
                    }];
                }
            }
        }
    };
    
    NSInteger batchSize = 30;
    if (groups.count > batchSize) {
            NSMutableArray *unhandleGroupIds = [groups mutableCopy];
            while (unhandleGroupIds.count > 0) {
                __block NSInteger loopBatchIndex = 0;
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTtransaction) {
                    [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                        DTGroupBaseInfoEntity * obj  = unhandleGroupIds.lastObject;
                        if (loopBatchIndex == batchSize || obj == nil) {*stop = YES;return;}
                        [unhandleGroupIds removeLastObject];
                        saveNewThreadBlock(obj, writeTtransaction);
                        loopBatchIndex += 1;
                    }];
                });
            }
            if (successCallBack) successCallBack();
    } else {
        NSMutableArray *unhandleGroupIds = [groups mutableCopy];
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTtransaction) {
            [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                DTGroupBaseInfoEntity * obj  = unhandleGroupIds.lastObject;
                if (obj == nil) {*stop = YES;return;}
                [unhandleGroupIds removeLastObject];
                
                saveNewThreadBlock(obj, writeTtransaction);
            }];
            
        });
        if (successCallBack) {
            successCallBack();
        }
    }
}

+ (NSAttributedString *)getPinnedMessageInfoWithSource:(NSString *)source
                                               message:(TSMessage *)message
                                           transaction:(SDSAnyReadTransaction *)transaction {
    
    NSString *sourceName = @"";
    if ([source isEqualToString:self.localNumber]) {
        sourceName = Localized(@"YOU", @"");
    } else {
        sourceName = [self.contactsManager displayNameForPhoneIdentifier:source transaction:transaction];
    }
    
    NSMutableAttributedString *infoString = [[NSMutableAttributedString alloc] initWithString:sourceName];
    
    [infoString appendAttributedString:[[NSAttributedString alloc] initWithString:Localized(@"PINNED_SYSTEM_INFO_MESSAGE", @"")]];
    __block NSString *messagePreview = @"";
    if ([message conformsToProtocol:@protocol(OWSPreviewText)]) {
        id<OWSPreviewText> previewable = (id<OWSPreviewText>)message;
     
        messagePreview = [previewable previewTextWithTransaction:transaction].filterStringForDisplay;
        //MARK: 消息预览保留16个字符
        NSInteger leftLength = 16;
        if (messagePreview.length > leftLength) {
            messagePreview = [messagePreview stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            messagePreview = [messagePreview stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
            messagePreview = [[messagePreview substringToIndex:leftLength] stringByAppendingString:@"..."];
        }
        messagePreview = [@"\"" stringByAppendingString:[messagePreview stringByAppendingString:@"\""]];
        NSAttributedString *attributePreview = [[NSAttributedString alloc] initWithString:messagePreview attributes:@{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor}];
        [infoString appendAttributedString:attributePreview];
    }
    
    return infoString;
}


+ (NSString *)getFullUpdateStringWithOldGroupModel:(TSGroupModel * _Nullable)oldGroupModel
                                         whoJoined:(NSMutableSet * _Nullable)whoJoined
                                          newModel:(TSGroupModel * _Nullable)newGroupModel
                         shouldAffectThreadSorting:(nonnull BOOL *)shouldAffectThreadSorting
                                       transaction:(SDSAnyReadTransaction *)transaction{
    
    NSMutableArray *infos = @[].mutableCopy;
    BOOL tmpShouldAffectSorting = NO;
    NSString *baseUpdateInfo = [self getBaseInfoStringWithOldGroupModel:oldGroupModel
                                                               newModel:newGroupModel
                                                                 source:@""
                                              shouldAffectThreadSorting:&tmpShouldAffectSorting];
    if(baseUpdateInfo.length){
        [infos addObject:baseUpdateInfo];
    }
    
    //
    NSSet *oldMembers = [NSSet setWithArray:oldGroupModel.groupMemberIds];
    NSSet *newMembers = [NSSet setWithArray:newGroupModel.groupMemberIds];
    
    NSMutableSet *membersWhoJoined = [NSMutableSet setWithSet:newMembers];
    [membersWhoJoined minusSet:oldMembers];
    NSMutableSet *membersWhoLeft = [NSMutableSet setWithSet:oldMembers];
    [membersWhoLeft minusSet:newMembers];
    [whoJoined unionSet:membersWhoJoined];
    NSString *memberUpdateInfo = [DTGroupUtils getMemberChangedInfoStringWithJoinedMemberIds:membersWhoJoined.allObjects
                                                                            removedMemberIds:nil
                                                                               leftMemberIds:membersWhoLeft.allObjects
                                                                   shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                                 transaction:transaction];
    
    if(memberUpdateInfo.length){
        [infos addObject:memberUpdateInfo];
    }
    //
    
    if (DTParamsUtils.validateString(newGroupModel.groupOwner) &&
        ![oldGroupModel.groupOwner isEqualToString:newGroupModel.groupOwner]) {
        NSString *groupOwnerUpdateInfo = [DTGroupUtils getMemberChangedInfoStringWithTransferOwer:newGroupModel.groupOwner
                                                                        shouldAffectThreadSorting:&tmpShouldAffectSorting
                                                                                      transaction:transaction];
        if(groupOwnerUpdateInfo.length){
            [infos addObject:groupOwnerUpdateInfo];
        }
    }
    
    //
    
    NSMutableSet *oldAdminSet = [[NSMutableSet alloc] initWithArray:oldGroupModel.groupAdmin];//老的群管理员的集
    NSMutableSet *newAdminSet = [[NSMutableSet alloc] initWithArray:newGroupModel.groupAdmin];//新的群管理的集合
    
    //获取两个集合的交集
    NSMutableSet *intersectSet = [oldAdminSet mutableCopy];
    [intersectSet intersectSet:newAdminSet];
    
    //删除的用户id集合
    NSMutableSet *removedSet = [oldAdminSet mutableCopy];
    [removedSet minusSet:intersectSet];
    if(DTParamsUtils.validateString(newGroupModel.groupOwner)){
        [removedSet removeObject:newGroupModel.groupOwner];
    }
    
    //增加的用户id集合
    NSMutableSet *addedSet = [newAdminSet mutableCopy];
    [addedSet minusSet:intersectSet];
    NSString *adminUpdateInfo = [self getMemberChangedInfoStringWithAddedAdminIds:addedSet.allObjects removedIds:removedSet.allObjects transaction:transaction];
    
    if(adminUpdateInfo.length){
        [infos addObject:adminUpdateInfo];
    }
        
    *shouldAffectThreadSorting = tmpShouldAffectSorting;
    if(infos.count){
        return [infos componentsJoinedByString:@"\n"];
    }else{
        return @"";
    }
    
}

+ (void)postRapidRoleChangeNotificationWithGroupModel:(TSGroupModel *)groupModel
                                      targedMemberIds:(NSArray <NSString *> *)targetMemberIds {
    
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTGroupMemberRapidRoleChangedNotification
                                                             object:groupModel
                                                           userInfo:@{DTRapidRolesKey : (targetMemberIds ?: @[])}];
}

+ (void)postExternalChangeNotificationWithTargetIds:(NSDictionary <NSString *, NSNumber *> *)targetIds {
    if (targetIds.allKeys.count == 0) return;
    
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTGroupExternalChangedNotification
                                                             object:nil
                                                           userInfo:targetIds];
}

//TODO: 增加serverTimestamp
+ (void)sendPinSystemMessageWithSource:(NSString *)source
                       serverTimestamp:(uint64_t)serverTimestamp
                                thread:(TSThread *)thread
                         pinnedMessage:(DTPinnedMessage *)pinnedMessage
                           transaction:(SDSAnyWriteTransaction *)transaction {
    
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    serverTimestamp = serverTimestamp > 0 ? serverTimestamp : now;
    
    NSAttributedString *customMessage = [DTGroupUtils getPinnedMessageInfoWithSource:source
                                                                             message:pinnedMessage.contentMessage
                                                                         transaction:transaction];
    
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessagePinMessage
                                                                            timestamp:now
                                                                      serverTimestamp:serverTimestamp
                                                                             inThread:thread
                                                                        customMessage:customMessage];
    infoMessage.realSource = pinnedMessage.realSource;
    [infoMessage anyInsertWithTransaction:transaction];
}

+ (void)sendGroupReminderMessageWithSource:(NSString *)source
                           serverTimestamp:(uint64_t)serverTimestamp
                                 isChanged:(BOOL)isChanged
                                    thread:(TSThread *)thread
                               remindCycle:(NSString *)remindCycle
                               transaction:(SDSAnyWriteTransaction *)transaction {
    
    DTGroupReminderConfig *reminderConfig = [DTGroupConfig fetchGroupConfig].groupRemind;
    
    NSString *none = @"none";
    NSString *daily = @"daily";
    NSString *weekly = @"weekly";
    NSString *monthly = @"monthly";
    
    NSString *sourceName = @"";
    if ([source isEqualToString:self.localNumber]) {
        sourceName = Localized(@"YOU", @"");
    } else {
        sourceName = [self.contactsManager displayNameForPhoneIdentifier:source transaction:transaction];
    }
    
    NSDictionary *colorAttribute = @{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor};
    
    NSMutableAttributedString *customMessage = nil;
    if (isChanged) {
        if (!reminderConfig) {
            customMessage = [[NSMutableAttributedString alloc] initWithString:sourceName attributes:colorAttribute];
            NSAttributedString *modifyMsg = [[NSAttributedString alloc] initWithString:Localized(@"GROUP_REMINDER_MODIFY_DEFAULT_TIPS", @"")];
            [customMessage appendAttributedString:modifyMsg];
        } else {
            if ([remindCycle isEqualToString:none]) {
                customMessage = [[NSMutableAttributedString alloc] initWithString:sourceName attributes:colorAttribute];
                NSAttributedString *offMsg = [[NSAttributedString alloc] initWithString:Localized(@"GROUP_REMINDER_OFF_TIPS", @"")];
                [customMessage appendAttributedString:offMsg];
            } else {
                NSString *ampm = reminderConfig.remindTime > 12 ? Localized(@"GROUP_REMINDER_TIME_PM", @"") : Localized(@"GROUP_REMINDER_TIME_AM", @"");
                NSInteger hour = reminderConfig.remindTime > 12 ? reminderConfig.remindTime - 12 : reminderConfig.remindTime;
                NSString *reminderTime = nil;
                NSString *succeedTips = nil;
                if ([remindCycle isEqualToString:weekly]) {
                    NSString *weekday = [DTGroupUtils weekdayWithRemindWeekDay:reminderConfig.remindWeekDay];
                    reminderTime = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_TIME_FORMAT_WEEKLY", @""), weekday, ampm, hour];
                    succeedTips = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_SET_SUCCEED_WEEKLY_TIPS", @""), sourceName, reminderConfig.remindDescription, reminderTime];
                } else if ([remindCycle isEqualToString:monthly]) {
                    NSString *monthDay = [DTGroupUtils monthDayWithRemindMonthDay:reminderConfig.remindMonthDay];
                    reminderTime = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_TIME_FORMAT_MONTHLY", @""), monthDay, ampm, hour];
                    succeedTips = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_SET_SUCCEED_MONTHLY_TIPS", @""), sourceName, reminderConfig.remindDescription, reminderTime];
                } else if ([remindCycle isEqualToString:daily]) {
                    reminderTime = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_TIME_FORMAT_DAILY", @""), ampm, hour];
                    succeedTips = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_SET_SUCCEED_DAILY_TIPS", @""), sourceName, reminderConfig.remindDescription, reminderTime];
                }
                NSRange nameRange = [succeedTips rangeOfString:sourceName];
                NSRange descriptionRange = [succeedTips rangeOfString:reminderConfig.remindDescription];
                NSRange timeRange = [succeedTips rangeOfString:reminderTime];
                customMessage = [[NSMutableAttributedString alloc] initWithString:succeedTips];
                [customMessage addAttributes:colorAttribute range:nameRange];
                [customMessage addAttributes:colorAttribute range:descriptionRange];
                [customMessage addAttributes:colorAttribute range:timeRange];
            }
        }
    } else {
        NSString *prefix = nil;
        NSString *remindDescription = nil;
        if (!reminderConfig) {
            prefix = Localized(@"GROUP_REMINDER_CYCLE_DEFAULT", @"");
            remindDescription = @"Don't forget to update!";
        } else {
            if ([remindCycle isEqualToString:weekly]) {
                prefix = Localized(@"GROUP_REMINDER_CYCLE_WEEKLY", @"");
            } else if ([remindCycle isEqualToString:monthly]) {
                prefix = Localized(@"GROUP_REMINDER_CYCLE_MONTHLY", @"");
            } else if ([remindCycle isEqualToString:daily]) {
                prefix = Localized(@"GROUP_REMINDER_CYCLE_DAILY", @"");
            }
            remindDescription = reminderConfig.remindDescription;
        }
        customMessage = [[NSMutableAttributedString alloc] initWithString:prefix];
        NSAttributedString *remindedMsg = [[NSAttributedString alloc] initWithString:remindDescription attributes:colorAttribute];
        [customMessage appendAttributedString:remindedMsg];
    }
    
    uint64_t now = [NSDate ows_millisecondTimeStamp];
        
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageGroupReminder
                                                                            timestamp:now
                                                                      serverTimestamp:serverTimestamp
                                                                             inThread:thread
                                                                        customMessage:customMessage.copy];
    infoMessage.shouldAffectThreadSorting = !isChanged;
    [infoMessage anyInsertWithTransaction:transaction];
    
    // Try to avoid infomessage.uniqueId == syncUnreadMessage.uniqueId, If there is high frequency notify，this alse happends
    [transaction addAsyncCompletionOffMain:^{
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTGroupPeriodicRemindNotification
                                                                 object:thread
                                                               userInfo:@{@"isChanged" : @(isChanged)}];
    }];
}

// xxx/YOU scheduled a meeting on Jun 20,8:40-9:10 PM (UTC+8). View details
// xxx/YOU scheduled a repeated meeting on Jun 20,8:40-9:10 PM (UTC+8). View details
// The group meeting will start in 10 min. Join
// xxx/YOU canceled a meeting on Jun 20,8:40-9:10 PM (UTC+8).
+ (void)sendMeetingReminderInfoMessageGroupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                                        serverTimestamp:(uint64_t)serverTimestamp
                                                 thread:(TSGroupThread *)groupThread
                                            transaction:(SDSAnyWriteTransaction *)transaction {
    
    NSMutableAttributedString *customMessage = nil;
    
    DTMeetingReminderType meetingReminderType = groupNotifyEntity.type;
    
    if (DTMeetingReminderTypeCreate == meetingReminderType) { // 会议创建
        
        NSString *startAt = groupNotifyEntity.startAt;
        if (!DTParamsUtils.validateString(startAt)) { // 无开始时间认为异常，不提醒
            
            OWSLogError(@"meeting start reminder error: no startAt time.");
            return;
        }
        
        NSString *organizer = groupNotifyEntity.organizer;
        NSString *sourceName = @"";
        if ([organizer isEqualToString:self.localNumber]) {
            sourceName = Localized(@"YOU", @"");
        } else {
            sourceName = [self.contactsManager displayNameForPhoneIdentifier:organizer transaction:transaction];
        }
        
        NSString *startInfo = nil;
        BOOL isRecurrence = groupNotifyEntity.isRecurrence;
        if (isRecurrence) {
            startInfo = [NSString stringWithFormat:@"%@ scheduled a repeated meeting on %@.", sourceName, startAt];
        } else {
            startInfo = [NSString stringWithFormat:@"%@ scheduled a meeting on %@.", sourceName, startAt];
        }
        
        customMessage = [[NSMutableAttributedString alloc] initWithString:startInfo];
        
        NSDictionary *viewDetailAttribute = @{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor};
        NSAttributedString *viewDetail = [[NSAttributedString alloc] initWithString:@" View details" attributes:viewDetailAttribute];
        [customMessage appendAttributedString:viewDetail];
    } else if (DTMeetingReminderTypeRemind == meetingReminderType) { // 会前提醒
        
        NSString *reminder = groupNotifyEntity.reminder;
        if (!DTParamsUtils.validateString(reminder)) { // 无开始时间认为异常，不提醒
            
            OWSLogError(@"meeting reminder error: no reminder time.");
            return;
        }
        
        customMessage = [[NSMutableAttributedString alloc] initWithString:@"The group meeting will"];
        
        NSDictionary *startInfoAttribute = @{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageOrangeColor};
        NSString *startInfo = [NSString stringWithFormat:@" start in %@.", reminder];
        NSAttributedString *startInfoAttr = [[NSAttributedString alloc] initWithString:startInfo attributes:startInfoAttribute];
        [customMessage appendAttributedString:startInfoAttr];
        
        NSDictionary *viewDetailAttribute = @{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor};
        NSAttributedString *viewDetail = [[NSAttributedString alloc] initWithString:@" Join" attributes:viewDetailAttribute];
        [customMessage appendAttributedString:viewDetail];
    } else if (DTMeetingReminderTypeCancel == meetingReminderType) { // 会前取消
        
        NSString *startAt = groupNotifyEntity.startAt;
        if (!DTParamsUtils.validateString(startAt)) { // 无开始时间认为异常，不提醒
            
            OWSLogError(@"meeting cancel reminder error: no startAt time.");
            return;
        }
        
        NSString *organizer = groupNotifyEntity.organizer;
        NSString *sourceName = @"";
        if ([organizer isEqualToString:self.localNumber]) {
            sourceName = Localized(@"YOU", @"");
        } else {
            sourceName = [self.contactsManager displayNameForPhoneIdentifier:organizer transaction:transaction];
        }
        
        NSString *startInfo = [NSString stringWithFormat:@"%@ canceled a meeting on %@.", sourceName, startAt];
        customMessage = [[NSMutableAttributedString alloc] initWithString:startInfo];
    }
    
    if (customMessage) {
        uint64_t now = [NSDate ows_millisecondTimeStamp];
        TSInfoMessage *infoMessage = [[TSInfoMessage alloc]
                                      initMeetingInfoMessageWithType:TSInfoMessageMeetingReminder
                                      timestamp:now
                                      serverTimestamp:serverTimestamp
                                      meetingReminderType:meetingReminderType
                                      meetingDetailUrl:groupNotifyEntity.link
                                      meetingName:groupNotifyEntity.meetingName
//                                      meetingId:groupNotifyEntity.meetingId
                                      inThread:groupThread
                                      customMessage:customMessage];
        
        [infoMessage anyInsertWithTransaction:transaction];
    }
}

+ (void)sendGroupRejoinMessageWithInviteCode:(NSString *)inviteCode
                                  updateInfo:(NSString *)updateInfo
                                      thread:(TSGroupThread *)thread
                                 transaction:(SDSAnyWriteTransaction *)transaction {
    
    NSString *finalInfo = [updateInfo stringByAppendingString:@". "];
    NSMutableAttributedString *attributedInfo = [[NSMutableAttributedString alloc] initWithString:finalInfo];
    NSAttributedString *undo = [[NSAttributedString alloc] initWithString:Localized(@"GROUP_REMOVE_MEMBER_REJOIN", @"") attributes:@{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor}];
    [attributedInfo appendAttributedString:undo];
    
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    TSInfoMessage *actionSystemMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageGroupRemoveMember
                                                                                    timestamp:now
                                                                              serverTimestamp:0
                                                                                     inThread:thread
                                                                                customMessage:attributedInfo.copy];
    actionSystemMessage.shouldAffectThreadSorting = YES;
    actionSystemMessage.inviteCode = inviteCode;

    [actionSystemMessage anyInsertWithTransaction:transaction];
}

+ (void)sendRAPIDRoleChangedMessageWithOperatorId:(NSString *)operatorId
                                    otherMemberId:(NSString *)otherMemberId
                                        rapidRole:(NSString *)rapidRole
                                  serverTimestamp:(uint64_t)serverTimestamp
                                           thread:(TSThread *)thread
                                      transaction:(SDSAnyWriteTransaction *)transaction {
    
    NSString *operatorName = @"";
//    if ([source isEqualToString:self.localNumber]) {
//        sourceName = Localized(@"YOU", @"");
//    } else {
    operatorName = [self.contactsManager displayNameForPhoneIdentifier:operatorId transaction:transaction];
//    }
    NSString *otherName = [self.contactsManager displayNameForPhoneIdentifier:otherMemberId transaction:transaction];
    NSString *info = [rapidRole isEqualToString:@"None"] ? [NSString stringWithFormat:Localized(@"RAPID_REMOVE_SYSTEM_MESSAGE", @""), operatorName, otherName] : [NSString stringWithFormat:Localized(@"RAPID_SET_SYSTEM_MESSAGE", @""), operatorName, otherName, rapidRole];
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    TSInfoMessage *systemMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                   inThread:thread
                                                                messageType:TSInfoMessageTypeGroupUpdate
                                                              customMessage:info];
    [systemMessage anyInsertWithTransaction:transaction];
}

+ (NSString *)weekdayWithRemindWeekDay:(NSInteger)remindWeekDay {
    
    NSString *weekday = nil;
    if (remindWeekDay == 1) {
        weekday = Localized(@"MONDAY", @"");
    } else if (remindWeekDay == 2) {
        weekday = Localized(@"TUESDAY", @"");
    } else if (remindWeekDay == 3) {
        weekday = Localized(@"WEDNESDAY", @"");
    } else if (remindWeekDay == 4) {
        weekday = Localized(@"THURSDAY", @"");
    } else if (remindWeekDay == 5) {
        weekday = Localized(@"FRIDAY", @"");
    } else if (remindWeekDay == 6) {
        weekday = Localized(@"SATURDAY", @"");
    } else if (remindWeekDay == 7) {
        weekday = Localized(@"SUNDAY", @"");
    }
    
    return weekday;
}

+ (NSString *)monthDayWithRemindMonthDay:(NSInteger)remindMonthDay {
    
    NSString *monthDay = nil;
    if (remindMonthDay == -1) {
        monthDay = Localized(@"LAST_DAY_OF_MONTH", @"");
    } else {
        if (remindMonthDay == 1) {
            monthDay = Localized(@"GROUP_REMINDER_FIRST_DAY", @"");
        } else if (remindMonthDay == 2) {
            monthDay = Localized(@"GROUP_REMINDER_SECOND_DAY", @"");
        } else if (remindMonthDay == 3) {
            monthDay = Localized(@"GROUP_REMINDER_THIRD_DAY", @"");
        } else {
            monthDay = [NSString stringWithFormat:Localized(@"GROUP_REMINDER_SUFFIX_TH", @""), remindMonthDay];
        }
    }
    
    return monthDay;
}

#pragma mark - private

+ (NSString *)localNumber
{
    return TSAccountManager.localNumber;
}

+ (UIColor *)attributeInfoMessageHighlightColor {
    return [UIColor colorWithRed:76.0/255 green:97.0/255 blue:140.0/255 alpha:1.0];
}

+ (UIColor *)attributeInfoMessageOrangeColor {
    return [UIColor colorWithRed:222.0/255 green:120.0/255 blue:0.0/255 alpha:1.0];
}

+ (void)addGroupBaseInfo:(DTGroupBaseInfoEntity *)baseInfo
             transaction:(SDSAnyWriteTransaction *)transaction {
    
    [baseInfo anyInsertWithTransaction:transaction];
    [DTGroupUtils postGroupBaseInfoChangeWith:baseInfo remove:NO];
}

+ (void)removeGroupBaseInfoWithGid:(NSString *)gid
                       transaction:(SDSAnyWriteTransaction *)transaction {
    
    DTGroupBaseInfoEntity *baseInfo = [DTGroupBaseInfoEntity anyFetchWithUniqueId:gid transaction:transaction];
    if (baseInfo) {
        [baseInfo anyRemoveWithTransaction:transaction];
        [DTGroupUtils postGroupBaseInfoChangeWith:baseInfo remove:YES];
    }
}

+ (void)upsertGroupBaseInfo:(DTGroupBaseInfoEntity *)baseInfo
                transaction:(SDSAnyWriteTransaction *)transaction {
    
    [baseInfo anyUpsertWithTransaction:transaction];
    [DTGroupUtils postGroupBaseInfoChangeWith:baseInfo remove:NO];
}

+ (void)postGroupBaseInfoChangeWith:(DTGroupBaseInfoEntity *)baseInfo
                             remove:(BOOL)remove {
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:DTGroupBaseInfoChangedNotification
                                                             object:nil
                                                           userInfo:@{@(remove) : baseInfo}];
}

@end
