//
//  DTTokenHelper.m
//  TTServiceKit
//
//  Created by hornet on 2021/11/11.
//

#import "DTConversationSettingHelper.h"
#import "DTGetConversationApi.h"
#import "DTSetConversationApi.h"
#import "DTFetchThreadConfigAPI.h"
#import "DTChatFolderManager.h"
#import "DTConversationNotifyEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "Threading.h"

NSString *const kConversationDidChangeNotification = @"kConversationDidChangeNotification";

extern NSString *const TSThreadDatabaseViewExtensionName;
extern NSString *const TSInboxGroup;

//主要用于在频繁切换前后台的时候控制拉取requestAllActive 的频率
#define kDiffTimeInterval  30

@interface DTConversationSettingHelper()
@property (nonatomic, strong) DTGetConversationApi *muteStatuesApi;
@property (nonatomic, strong) DTSetConversationApi *configApi;
@property (nonatomic, strong) NSDate *lastTimeDate;
@property (nonatomic, strong, readwrite) NSMutableArray *loadedActiveSettingThreadIds;

@property (nonatomic, strong) DTFetchThreadConfigAPI *conversationShareConfigApi;
@property (nonatomic, strong) NSDate *lastRequestconversationShareTimeDate;
@property (nonatomic, strong, readwrite) NSMutableArray *loadedConversationShareThreadIds;
@end

@implementation DTConversationSettingHelper

#pragma mark public
// TODO: conversationSetting 如果调用频率不搞不要搞成单例
+ (instancetype)sharedInstance {
    static DTConversationSettingHelper *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)requestAllActiveThreadsConversationSettingAndSaveResult {
    __block NSMutableArray *conversationIds = [NSMutableArray array];
    __block NSMutableArray *conversationStringIds = [NSMutableArray array];
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        NSMutableArray *activeThreadArr = [NSMutableArray array];
        
        AnyThreadFinder *finder = [[AnyThreadFinder alloc] init];
        NSError *error;
        [finder enumerateVisibleThreadsWithIsArchived:NO
                                                limit:500
                                          transaction:transaction
                                                error:&error
                                                block:^(TSThread * thread) {
            if (thread && [thread isKindOfClass:TSThread.class]) {
                [activeThreadArr addObject:thread];
                if ([thread serverThreadId]) {
                    [conversationIds addObject:[thread serverThreadId]];
                    
                    if([thread isKindOfClass:[TSContactThread class]]){
                        NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
                        if([localNumber compare:[thread serverThreadId] options:NSCaseInsensitiveSearch | NSNumericSearch] == NSOrderedAscending){
                            NSString *conversationIdString = [NSString stringWithFormat:@"%@:%@",localNumber,[thread serverThreadId]];
                            [conversationStringIds addObject:conversationIdString];
                        } else if([localNumber compare:[thread serverThreadId] options:NSCaseInsensitiveSearch | NSNumericSearch] == NSOrderedDescending){
                            NSString *conversationIdString = [NSString stringWithFormat:@"%@:%@",[thread serverThreadId],localNumber];
                            [conversationStringIds addObject:conversationIdString];
                        } else {
                            //ignore
                        }
                    }
                    
                }
            }
        }];
        
    } completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0) completion:^{
        
        if (conversationIds.count) {
            [self dealMuteStatusSettingWith:conversationIds];
        }
        
        if(conversationStringIds.count){
            [self dealConversationShareSettingWith:conversationStringIds];
        }
        
    }];
}

- (void)dealMuteStatusSettingWith:(NSArray *)conversationIds {
    if (!self.lastTimeDate ) {//冷启动
        [self requestConversationSettingAndSaveResultWithConversationIds:conversationIds];
        return;
    }
    NSDate *now = [NSDate date];
    if (self.lastTimeDate && ([now timeIntervalSinceDate:self.lastTimeDate] > kDiffTimeInterval)) {
        @synchronized (self) {
            if (self.loadedActiveSettingThreadIds.count) {
                [self.loadedActiveSettingThreadIds removeAllObjects];
            }
        }
        [self requestConversationSettingAndSaveResultWithConversationIds:conversationIds];
    }
}

- (void)dealConversationShareSettingWith:(NSArray *)conversationIds {
    if (!self.lastRequestconversationShareTimeDate){
        [self requestConversationSharingConfigurationStatesAndSaveResultWithConversationIds:conversationIds saveResult:true success:nil failure:nil];
        return;
        
    }
    NSDate *now = [NSDate date];
    if (self.lastRequestconversationShareTimeDate && ([now timeIntervalSinceDate:self.lastRequestconversationShareTimeDate] > kDiffTimeInterval)) {
        @synchronized (self) {
            if (self.loadedConversationShareThreadIds.count) {
                [self.loadedConversationShareThreadIds removeAllObjects];
            }
        }
        [self requestConversationSharingConfigurationStatesAndSaveResultWithConversationIds:conversationIds saveResult:true success:nil failure:nil];
    }
}

- (void)requestConversationSettingAndSaveResultWithConversationId:(NSString *)conversationId {
    NSArray *params = @[conversationId];
    [self requestConversationSettingAndSaveResultWithConversationIds:params];
}

- (void)requestConversationSettingAndSaveResultWithConversationIds:(NSArray *)conversationIds {
    [self requestMuteStatusAndSaveResultWithConversationIds:conversationIds saveResult:true success:nil failure:nil];
}

- (void)requestConversationSharingConfigurationStatesAndSaveResultWithConversationIds:(NSArray *)conversationIds
                                                                           saveResult:(BOOL)isSave
                                                                              success:(void(^)(NSArray<DTThreadConfigEntity*>*)) sucessBlock
                                                                              failure:(void(^)(NSError*))failure  {
    @weakify(self);
    [self.conversationShareConfigApi fetchThreadConfigRequestWithConversationIds:conversationIds
                                                                         success:^(NSArray<DTThreadConfigEntity *> * __nullable entities) {
        @strongify(self);
        if (sucessBlock) {
            sucessBlock(entities);
        }
        if (!isSave) {return;}
        
        if (!DTParamsUtils.validateArray(entities)) {
            self.lastRequestconversationShareTimeDate = [NSDate date];
            return;
        }
        
        NSInteger batchSize = 30;
        if (entities.count > batchSize) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSMutableArray <DTThreadConfigEntity *> *unhandleEntitysArr = entities.mutableCopy;
                while (unhandleEntitysArr.count > 0) {
                    __block NSInteger loopBatchIndex = 0;
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                        [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                            DTThreadConfigEntity *entity = unhandleEntitysArr.lastObject;
                            if (loopBatchIndex == batchSize ||
                                entity == nil) {
                                *stop = YES;
                                return;
                            }
                            
                            [unhandleEntitysArr removeLastObject];
                            NSMutableArray *tmpConversationArr = [[entity.conversation componentsSeparatedByString:@":"] mutableCopy];
                            if(!DTParamsUtils.validateArray(tmpConversationArr) || tmpConversationArr.count < 2){
                                return;
                            }
                            NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
                            if([entity.conversation containsString:[TSAccountManager sharedInstance].localNumber]){
                                [tmpConversationArr removeObject:localNumber];
                            }
                            NSString *remoteConversationID = tmpConversationArr.lastObject;
                            TSContactThread *thread = (TSContactThread *)[DTChatFolderManager getOrCreateThreadWithThreadId:remoteConversationID transaction:writeTransaction];
                            if ((thread && !thread.threadConfig) || (thread.threadConfig && ![thread.threadConfig isEqual:entity])) {
                                [thread anyUpdateWithTransaction:writeTransaction
                                                           block:^(TSThread * instance) {
                                    instance.threadConfig = entity;
                                    
                                    [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                                               expireTime:entity.messageExpiry
                                                                       messageClearAnchor:@(entity.messageClearAnchor)];
                                }];
                            }
                            
                            if (entity.askedVersion > 0) {
                                [TSContactThread updateWithRecipientId:thread.contactIdentifier
                                                  friendContactVersion:entity.askedVersion
                                                     receivedFriendReq:true
                                                updateAtTheSameVersion:false
                                                           transaction:writeTransaction];
                            }
                            
                            if (![self.loadedActiveSettingThreadIds containsObject:entity.conversation]) {
                                [self.loadedActiveSettingThreadIds addObject:entity.conversation];
                            }
                            loopBatchIndex += 1;
                        }];
                    });
                    
                    
                }
                
                self.lastRequestconversationShareTimeDate = [NSDate date];
                //kConversationUpdateFromSocketMessageNotification 这个地方暂时使用和socket的一个通知
                //待调整
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kConversationUpdateFromSocketMessageNotification object:nil];
                });
                
                
            });
            
        } else {
            NSMutableArray <DTThreadConfigEntity *> *unhandleEntitysArr = entities.mutableCopy;
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                    DTThreadConfigEntity *entity = unhandleEntitysArr.lastObject;
                    if (entity == nil) {
                        *stop = YES;
                        return;
                    }
                    [unhandleEntitysArr removeLastObject];
                    NSMutableArray *tmpConversationArr = [[entity.conversation componentsSeparatedByString:@":"] mutableCopy];
                    if(!DTParamsUtils.validateArray(tmpConversationArr) || tmpConversationArr.count < 2){
                        return;
                    }
                    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
                    if([entity.conversation containsString:[TSAccountManager sharedInstance].localNumber]){
                        [tmpConversationArr removeObject:localNumber];
                    }
                    NSString *remoteConversationID = tmpConversationArr.lastObject;
                    TSContactThread *thread = (TSContactThread *)[DTChatFolderManager getOrCreateThreadWithThreadId:remoteConversationID transaction:writeTransaction];
                    if ((thread && !thread.threadConfig) || (thread.threadConfig && ![thread.threadConfig isEqual:entity])) {
                        [thread anyUpdateWithTransaction:writeTransaction
                                                   block:^(TSThread * instance) {
                            instance.threadConfig = entity;
                            
                            [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                                       expireTime:entity.messageExpiry
                                                               messageClearAnchor:@(entity.messageClearAnchor)];
                        }];
                    }
                    
                    if (entity.askedVersion > 0) {
                        [TSContactThread updateWithRecipientId:thread.contactIdentifier
                                          friendContactVersion:entity.askedVersion
                                             receivedFriendReq:true
                                        updateAtTheSameVersion:false
                                                   transaction:writeTransaction];
                    }
                    
                    if (![self.loadedActiveSettingThreadIds containsObject:entity.conversation]) {
                        [self.loadedActiveSettingThreadIds addObject:entity.conversation];
                    }
                }];
                
                self.lastRequestconversationShareTimeDate = [NSDate date];
                //kConversationUpdateFromSocketMessageNotification 这个地方暂时使用和socket的一个通知
                //待调整
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kConversationUpdateFromSocketMessageNotification object:nil];
                });
            });
        }
        
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
    
}

- (void)requestMuteStatusAndSaveResultWithConversationIds:(NSArray *)conversationIds
                                               saveResult:(BOOL)isSave
                                                  success:(void(^)(NSArray<DTConversationEntity*>*)) sucessBlock
                                                  failure:(void(^)(NSError*))failure  {
    OWSLogInfo(@"requestMuteStatusAndSaveResultWithConversationIds isSave = %d",isSave);
    @weakify(self);
    [self.muteStatuesApi requestMuteStatusWithConversationIds:conversationIds success:^(NSArray<DTConversationEntity *> * _Nonnull entitysArr) {
        @strongify(self);
        if (sucessBlock) {
            sucessBlock(entitysArr);
        }
        if (!isSave) {return;}
        if (!DTParamsUtils.validateArray(entitysArr)) {
            self.lastTimeDate = [NSDate date];
            return;
        }
        
        NSInteger batchSize = 30;
        if (entitysArr.count > batchSize) {
            
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSMutableArray <DTConversationEntity *> *unhandleEntitysArr = entitysArr.mutableCopy;
                
                while (unhandleEntitysArr.count > 0) {
                    
                    __block NSInteger loopBatchIndex = 0;
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                        [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                            DTConversationEntity *entity = unhandleEntitysArr.lastObject;
                            if (loopBatchIndex == batchSize ||
                                entity == nil) {
                                *stop = YES;
                                return;
                            }
                            
                            [unhandleEntitysArr removeLastObject];
                            
                            TSThread *thread = [DTChatFolderManager getOrCreateThreadWithThreadId:entity.conversation transaction:writeTransaction];
                            if ((thread && !thread.conversationEntity) ||
                                (thread.conversationEntity && ![thread.conversationEntity isEqual:entity])) {
                                [thread anyUpdateWithTransaction:writeTransaction
                                                           block:^(TSThread * instance) {
                                    instance.conversationEntity = entity;
                                    
                                    // 拉取所有会话的设置 大于分页
                                    [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                                               expireTime:entity.messageExpiry
                                                                       messageClearAnchor:@(entity.messageClearAnchor)];
                                }];
                            }
                            
                            if (![self.loadedActiveSettingThreadIds containsObject:entity.conversation]) {
                                [self.loadedActiveSettingThreadIds addObject:entity.conversation];
                            }
                            
                            if([thread isKindOfClass:[TSContactThread class]]){
                                TSContactThread *contactThread = (TSContactThread *)thread;
                                SignalAccount *account = [SignalAccount anyFetchWithUniqueId:contactThread.contactIdentifier transaction:writeTransaction];
                                if(!account){ OWSLogInfo(@"requestMuteStatus account = nil");}
                                Contact *contact = account.contact;
                                if(!DTParamsUtils.validateString(entity.remark)){return;}
                                NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:contact.remark receptid:contactThread.contactIdentifier];
                                if(![contact.remark isEqualToString:remark]){
                                    contact.remark = remark;
                                    account.contact = contact;
                                    id<ContactsManagerProtocol> contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
                                    [contactsManager updateSignalAccountWithRecipientId:account.recipientId withNewSignalAccount:account withTransaction:writeTransaction];
                                }
                            }
                            
                            loopBatchIndex += 1;
                        }];
                    });
                }
                
                self.lastTimeDate = [NSDate date];
                //kConversationUpdateFromSocketMessageNotification 这个地方暂时使用和socket的一个通知
                //待调整
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kConversationUpdateFromSocketMessageNotification object:nil];
                });
            });
        } else {
            
            NSMutableArray <DTConversationEntity *> *unhandleEntitysArr = entitysArr.mutableCopy;
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                    DTConversationEntity *entity = unhandleEntitysArr.lastObject;
                    if (entity == nil) {
                        *stop = YES;
                        return;
                    }
                    
                    [unhandleEntitysArr removeLastObject];
                    
                    TSThread *thread = [DTChatFolderManager getOrCreateThreadWithThreadId:entity.conversation transaction:writeTransaction];
                    if ((thread && !thread.conversationEntity) ||
                        (thread.conversationEntity && ![thread.conversationEntity isEqual:entity])) {
                        [thread anyUpdateWithTransaction:writeTransaction
                                                   block:^(TSThread * instance) {
                            instance.conversationEntity = entity;
                            // 拉取所有会话的设置 小于分页
                            [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                                       expireTime:entity.messageExpiry
                                                               messageClearAnchor:@(entity.messageClearAnchor)];
                            
                        }];
                    }
                    
                    if (![self.loadedActiveSettingThreadIds containsObject:entity.conversation]) {
                        [self.loadedActiveSettingThreadIds addObject:entity.conversation];
                    }
                    
                    if([thread isKindOfClass:[TSContactThread class]]){
                        TSContactThread *contactThread = (TSContactThread *)thread;
                        SignalAccount *account = [SignalAccount anyFetchWithUniqueId:contactThread.contactIdentifier transaction:writeTransaction];
                        if(!account){ OWSLogInfo(@"requestMuteStatus account = nil");}
                        Contact *contact = account.contact;
                        if(!DTParamsUtils.validateString(entity.remark)){return;}
                        NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:contact.remark receptid:contactThread.contactIdentifier];
                        if(![contact.remark isEqualToString:remark]){
                            contact.remark = remark;
                            account.contact = contact;
                            id<ContactsManagerProtocol> contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
                            [contactsManager updateSignalAccountWithRecipientId:account.recipientId withNewSignalAccount:account withTransaction:writeTransaction];
                        }
                    }
                    
                }];
                
                [writeTransaction addAsyncCompletionOnMain:^{
                    self.lastTimeDate = [NSDate date];
                    //kConversationUpdateFromSocketMessageNotification 这个地方暂时使用和socket的一个通知
                    //待调整
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:kConversationUpdateFromSocketMessageNotification object:nil];
                    });
                }];
            });
        }
    } failure:^(NSError * _Nonnull error) {
        if (failure) {
            failure(error);
        }
    }];
}


- (void)configMuteStatusWithConversationID:(NSString *)gid
                                muteStatus:(NSNumber *) muteStatus
                                   success:(void(^)(void)) successBlock
                                   failure:(void(^)(void)) failureBlock {
    
    [self.configApi requestConfigMuteStatusWithConversationID:gid muteStatus:muteStatus success:^(DTConversationEntity * _Nonnull conversationEntity) {
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            TSThread *thread = [DTChatFolderManager getOrCreateThreadWithThreadId:conversationEntity.conversation transaction:writeTransaction];
            [thread anyUpdateWithTransaction:writeTransaction
                                       block:^(TSThread * instance) {
                instance.conversationEntity = conversationEntity;
                
                [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                           expireTime:conversationEntity.messageExpiry
                                                   messageClearAnchor:@(conversationEntity.messageClearAnchor)];
                
            }];
            [writeTransaction addAsyncCompletionOnMain:^{
                DispatchMainThreadSafe(^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kConversationDidChangeNotification object:nil];
                });
            }];
        });
        if (successBlock) {
            successBlock();
        }
    } failure:^(NSError * _Nonnull error) {
        if (failureBlock) {
            failureBlock();
        }
    }];
}


- (void)configBlockStatusWithConversationID:(NSString *)gid
                                blockStatus:(NSNumber *) blockStatus
                                    success:(void(^)(void)) successBlock
                                    failure:(void(^)(void)) failureBlock {
    
    [self.configApi requestConfigBlockStatusWithConversationID:gid blockStatus:blockStatus success:^(DTConversationEntity * _Nonnull conversationEntity) {
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            TSThread *thread = [DTChatFolderManager getOrCreateThreadWithThreadId:conversationEntity.conversation transaction:writeTransaction];
            [thread anyUpdateWithTransaction:writeTransaction
                                       block:^(TSThread * instance) {
                instance.conversationEntity = conversationEntity;
                
                [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                           expireTime:conversationEntity.messageExpiry
                                                   messageClearAnchor:@(conversationEntity.messageClearAnchor)];
            }];
            [writeTransaction addAsyncCompletionOnMain:^{
                [[NSNotificationCenter defaultCenter] postNotificationNameAsync:kConversationDidChangeNotification object:nil];
            }];
        });
        
        if (successBlock) {
            successBlock();
        }
    } failure:^(NSError * _Nonnull error) {
        if (failureBlock) {
            failureBlock();
        }
    }];
}

- (DTGetConversationApi *)muteStatuesApi {
    if (!_muteStatuesApi) {
        _muteStatuesApi = [DTGetConversationApi new];
    }
    return _muteStatuesApi;
}

- (DTFetchThreadConfigAPI *)conversationShareConfigApi {
    if (!_conversationShareConfigApi) {
        _conversationShareConfigApi = [DTFetchThreadConfigAPI new];
    }
    return _conversationShareConfigApi;
}

- (DTSetConversationApi *)configApi {
    if (!_configApi) {
        _configApi = [DTSetConversationApi new];
    }
    return _configApi;
}

- (NSMutableArray *)loadedActiveSettingThreadIds {
    if (!_loadedActiveSettingThreadIds) {
        _loadedActiveSettingThreadIds = [NSMutableArray array];
    }
    return _loadedActiveSettingThreadIds;
}

- (NSMutableArray *)loadedConversationShareThreadIds {
    if (!_loadedConversationShareThreadIds) {
        _loadedConversationShareThreadIds = [NSMutableArray array];
    }
    return _loadedConversationShareThreadIds;
}

- (nullable NSString *)encryptRemarkString:( NSString * _Nonnull )remarkName receptid:(NSString * _Nonnull)receptid {
    OWSAssertDebug(receptid.length);
    NSData *remarkData =[remarkName dataUsingEncoding:NSUTF8StringEncoding];
    NSData *remark = [self encryptRemarkData:remarkData receptid:receptid];
    NSString *aesString = [remark base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    return aesString;
}

- (nullable NSString *)decryptRemarkString:( NSString * _Nonnull )remarkName receptid:(NSString * _Nonnull)receptid {
    OWSAssertDebug(receptid.length);
    
    if(!DTParamsUtils.validateString(remarkName) ||
       !DTParamsUtils.validateString(receptid)) {
        OWSLogError(@"decryptRemarkString remarkName or receptid is empty!");
        return nil;
    }
    
    NSArray *separatedArr = [remarkName componentsSeparatedByString:@"|"];
    if([separatedArr.firstObject isEqualToString:@"V1"]){
        NSString *remoteRemarkNameAesString = separatedArr.lastObject;
        NSData *decryptData = [[NSData alloc] initWithBase64EncodedString:remoteRemarkNameAesString options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSData *aesData = [self decryptRemarkData:decryptData receptid:receptid];
        NSString *decryptString = [[NSString alloc] initWithData:aesData encoding:NSUTF8StringEncoding];
        return decryptString;
    } else {
        return remarkName;
    }
}

- (BOOL)isEncryptedRemarkString:(NSString *) remark {
    NSArray *separatedArr = [remark componentsSeparatedByString:@"|"];
    if([separatedArr.firstObject isEqualToString:@"V1"]){
        return true;
    }
    return false;
}

- (nullable NSData *)encryptRemarkData:(nullable NSData *)encryptedData receptid:(NSString *)receptid {
    SSKAES256Key *remarkKey = [self getAESKeyFromReceptid:receptid];
    OWSAssertDebug(remarkKey.keyData.length == kAES256_KeyByteLength);
    
    if (!encryptedData) {
        return nil;
    }
    
    return [SSKCryptography encryptAESGCMWithData:encryptedData key:remarkKey];
}

- (nullable NSData *)decryptRemarkData:(nullable NSData *)encryptedData receptid:(NSString *)receptid
{
    SSKAES256Key *remarkKey = [self getAESKeyFromReceptid:receptid];
    OWSAssertDebug(remarkKey.keyData.length == kAES256_KeyByteLength);
    
    if (!encryptedData) {
        return nil;
    }
    
    return [SSKCryptography decryptAESGCMWithData:encryptedData key:remarkKey];
}

- (SSKAES256Key *)getAESKeyFromReceptid:(NSString *)receptid {
    NSString *stripedReceptid = [receptid ows_stripped];
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@%@%@",stripedReceptid,stripedReceptid,stripedReceptid];
    
    // 如果长度不足 32，则用 `+` 补齐
    while (string.length < 32) {
        [string appendString:@"+"];
    }

    NSData *data = [[string dataUsingEncoding:NSUTF8StringEncoding] subdataWithRange:NSMakeRange(0, 32)];
    SSKAES256Key *key = [SSKAES256Key keyWithData:data];
    return key;
}


@end
