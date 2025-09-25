//
//  DTContactsUpdateMessageProcessor.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/10/25.
//

#import "DTContactsUpdateMessageProcessor.h"
#import "DTParamsBaseUtils.h"
#import "TSAccountManager.h"
#import "DTChatFolderManager.h"
#import "NSTimer+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTAddContactsEntity.h"

static NSString *const kDTContactsVersionKey = @"contactsVersionKey";
NSString *const kContactsUpdateNotifyIncrement = @"contactsUpdateNotifyIncrement";
NSString *const kContactsUpdateNotifyFull = @"contactsUpdateNotifyFull";
NSString *const kContactsUpdateMembersKey = @"contactsUpdateMembersKey";

@interface DTContactsUpdateMessageProcessor ()

@property (nonatomic, strong, nullable) NSDictionary<NSString * ,DTContactActionEntity *> *incrementContactMap;
@property (nonatomic, assign) NSInteger currentDirectoryVersion;
@property (nonatomic, nullable) NSTimer *fallbackTimer;

@end

@implementation DTContactsUpdateMessageProcessor

- (instancetype)init{
    if(self = [super init]){
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:OWSApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:OWSApplicationWillResignActiveNotification
                                                   object:nil];
        [self startIfNecessary];
    }
    return self;
}

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("org.difft.contactsUpdateMessageProcessor", DISPATCH_QUEUE_SERIAL);
    });

    return _serialQueue;
}

+ (NSInteger)currentContactsVersion{
    return [CurrentAppContext().appUserDefaults integerForKey:kDTContactsVersionKey];
}

+ (void)saveContactsVersion:(NSInteger)version{
    [CurrentAppContext().appUserDefaults setInteger:version forKey:kDTContactsVersionKey];
    [CurrentAppContext().appUserDefaults synchronize];
}

- (void)handleContactsUpdateMessageWithContactsNotifyEntity:(DTContactsNotifyEntity *)contactsNotifyEntity transaction:(SDSAnyWriteTransaction *)transaction {
    NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:transaction];
    if (contactsNotifyEntity.members.count == 1 && [contactsNotifyEntity.members[0].number isEqualToString:localNumber]) {
        Contact *contact = contactsNotifyEntity.members.firstObject;
        if (contact.privateConfigs.chatFolder != nil) {
            NSDictionary *chatFolder = contact.privateConfigs.chatFolder;
            NSError *error;
            NSArray <DTChatFolderEntity *> *chatFolders = [MTLJSONAdapter modelsOfClass:[DTChatFolderEntity class] fromJSONArray:chatFolder[@"value"] error:&error];
            NSInteger newVersion = [chatFolder[@"version"] integerValue];
            [DTChatFolderManager updateChatFolders:chatFolders forceUpdate:NO newVersion:newVersion success:nil transaction:transaction];
            OWSLogInfo(@"[DTChatFolderManager] sync with other device");
        }
    }
    
    NSInteger previousVersion = [[self class] currentContactsVersion];
    NSInteger diff = contactsNotifyEntity.directoryVersion - previousVersion;
    OWSLogInfo(@"[contacts]:%ld---%ld", contactsNotifyEntity.directoryVersion, previousVersion);
    if(diff > 1){
        //full update
        OWSLogInfo(@"send contactsUpdateNotifyFull, contacts version: %ld", contactsNotifyEntity.directoryVersion);
        [[NSNotificationCenter defaultCenter] postNotificationName:kContactsUpdateNotifyFull
                                                            object:nil
                                                          userInfo:nil];
    }else if (diff < 1){
        //drop
        return;
    }else{
        
        if(DTParamsUtils.validateArray(contactsNotifyEntity.members)){
            OWSLogInfo(@"handleIncrementContacts, members count = %ld", contactsNotifyEntity.members.count);
            [self handleIncrementContacts:contactsNotifyEntity.members directoryVersion:contactsNotifyEntity.directoryVersion];
        } else {
            OWSLogInfo(@"can not handleIncrementContacts, members is empty");
        }
    }
}

- (void)handleIncrementContacts:(NSArray<DTContactActionEntity *> *)contacts directoryVersion:(NSInteger)directoryVersion{
    if(!contacts.count) return;
    
    dispatch_async(self.serialQueue, ^{
        
        self.currentDirectoryVersion = directoryVersion;
        
        if(!self.incrementContactMap.count){
            NSMutableDictionary *newMap = @{}.mutableCopy;
            [contacts enumerateObjectsUsingBlock:^(DTContactActionEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.directoryVersion = directoryVersion;
                if(obj.number.length){
                    newMap[obj.number] = obj;
                }
            }];
            
            self.incrementContactMap = newMap.copy;
            
        } else {
            
            NSMutableDictionary *newMap = self.incrementContactMap.mutableCopy;
            
            [contacts enumerateObjectsUsingBlock:^(DTContactActionEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if(obj.number.length){
                    DTContactActionEntity *oldContact = newMap[obj.number];
                    if(oldContact){
                        if(directoryVersion > oldContact.directoryVersion){
                            newMap[obj.number] = obj;
                        }
                    }else{
                        newMap[obj.number] = obj;
                    }
                }
            }];
            
            self.incrementContactMap = newMap.copy;
            
        }
        
        OWSLogInfo(@"handleIncrementContacts, incrementContactMap count = %ld, current contacts version: %ld", self.incrementContactMap.count, self.currentDirectoryVersion);
    });
}


- (void)applicationDidBecomeActive:(NSNotification *)notify{
    OWSAssertIsOnMainThread();

    [self startIfNecessary];
}

- (void)applicationWillResignActive:(NSNotification *)notify{
    
    OWSAssertIsOnMainThread();
    
    [self stop];
}

- (void)startIfNecessary{
    // suspenders in case a deletion schedule is missed.
    
    NSTimeInterval kFallBackTimerInterval = 2;
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if (CurrentAppContext().isMainApp) {
            [self stop];
            self.fallbackTimer = [NSTimer weakScheduledTimerWithTimeInterval:kFallBackTimerInterval
                                                                      target:self
                                                                    selector:@selector(fallbackTimerDidFire)
                                                                    userInfo:nil
                                                                     repeats:YES];
        }
    });
    
}

- (void)stop{
    [self.fallbackTimer invalidate];
    self.fallbackTimer = nil;
}

- (void)fallbackTimerDidFire {
    
    if(!self.incrementContactMap.count) {
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        
        if(self.incrementContactMap.allValues){
            OWSLogInfo(@"send contactsUpdateNotifyIncrement, current contacts version: %ld", self.currentDirectoryVersion);
            [[NSNotificationCenter defaultCenter] postNotificationName:kContactsUpdateNotifyIncrement
                                                                object:nil
                                                              userInfo:@{kContactsUpdateMembersKey:self.incrementContactMap.allValues.copy}];
        }
        
        self.incrementContactMap = nil;
        
        if([[self class] currentContactsVersion] < self.currentDirectoryVersion){
            [[self class] saveContactsVersion:self.currentDirectoryVersion];
        }
        
    });
}

- (void)handleAddContactMessageWithEnvelope:(DSKProtoEnvelope *)envelope contactsNotifyEntity:(DTAddContactsEntity *)addContactsEntity transaction:(SDSAnyWriteTransaction *)transaction {
    OWSLogInfo(@"ContactsUpdate handleAddContactMessageWithEnvelope addContactsEntity = \n %@",[addContactsEntity signal_modelToJSONString]);
    
    DTAddContactsActionType actionType = addContactsEntity.actionType;
    NSString *askAuthorid = addContactsEntity.operatorInfo.source;
    if(!DTParamsUtils.validateString(askAuthorid)){return;}
    NSString *askAuthorName = addContactsEntity.operatorInfo.sourceName;
    if([askAuthorName ows_stripped].length == 0){
        askAuthorName = askAuthorid;
    }
    switch (actionType) {
        case DTAddContactsActionTypeRequest:{
            [TSContactThread updateWithRecipientId:askAuthorid
                              friendContactVersion:addContactsEntity.directoryVersion
                                 receivedFriendReq:YES
                            updateAtTheSameVersion:NO
                                       transaction:transaction];
        }
            break;
            
        case DTAddContactsActionTypeAccept: {
            
            [TSContactThread updateWithRecipientId:askAuthorid
                              friendContactVersion:addContactsEntity.directoryVersion
                                 receivedFriendReq:NO
                            updateAtTheSameVersion:YES
                                       transaction:transaction];
            
            NSInteger diff = addContactsEntity.directoryVersion - [[self class] currentContactsVersion];
            if(diff > 1){
                [[NSNotificationCenter defaultCenter] postNotificationName:kContactsUpdateNotifyFull
                                                                    object:nil
                                                                  userInfo:nil];
               
            } else if(diff < 1){///用户添加好友成功
                OWSLogInfo(@"server vontacts version = %ld,\n current contacts version = %ld", (long)addContactsEntity.directoryVersion, [[self class] currentContactsVersion]);
            } else { ///走通讯录更新的逻辑
                
                ///走通讯录更新的逻辑
                DTContactActionEntity * contactActionEntity = [[DTContactActionEntity alloc] initWithFullName:askAuthorName phoneNumber:askAuthorid];
                contactActionEntity.publicConfigs = addContactsEntity.operatorInfo.publicConfigs;
                contactActionEntity.avatar = addContactsEntity.operatorInfo.avatar;
                contactActionEntity.action = DTContactNotifyActionAdd;
                [[NSNotificationCenter defaultCenter] postNotificationName:kContactsUpdateNotifyIncrement
                                                                    object:nil
                                                                  userInfo:@{kContactsUpdateMembersKey:@[contactActionEntity]}];
                [[self class] saveContactsVersion:addContactsEntity.directoryVersion];
            }
        }
            break;
        default:
            break;
    }
    
}

@end
