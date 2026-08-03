//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContactsManager.h"
#import "Environment.h"
#import "OWSProfileManager.h"
#import "OWSUserProfile.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/UIFont+OWS.h>
#import <TTServiceKit/ContactsUpdater.h>
#import <TTServiceKit/NSNotificationCenter+OWS.h>
#import <TTServiceKit/NSString+SSK.h>
#import <TTServiceKit/OWSError.h>
//
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/SignalAccount.h>
#import <SDWebImage/SDWebImage.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import "Contact.h"
#import "DTContactsNotifyEntity.h"
#import <SignalCoreKit/Threading.h>

@import Contacts;

NSString *const OWSContactsManagerSignalAccountsDidChangeNotification
    = @"OWSContactsManagerSignalAccountsDidChangeNotification";
NSString *const kLoadedContactsKey = @"loadedContactsTag";

static const CGFloat kFullUpdateContactsFrequency = 0.05;
static const NSUInteger kFullUpdateContactsBatch = 30;

@interface OWSContactsManager () <SystemContactsFetcherDelegate>

@property (nonatomic) BOOL isContactsUpdateInFlight;
// This reflects the contents of the device phone book and includes
// contacts that do not correspond to any signal account.
@property (atomic) NSArray<Contact *> *allContacts;
@property (atomic) NSArray<Contact *> *nofityContacts;
@property (atomic) NSDictionary<NSString *, Contact *> *allContactsMap;
@property (atomic) NSArray<SignalAccount *> *signalAccounts;
@property (atomic) NSDictionary<NSString *, SignalAccount *> *signalAccountMap;
@property (atomic) NSArray <SignalAccount *> *allBots;
@property (nonatomic, readonly) SystemContactsFetcher *systemContactsFetcher;
@property (atomic, getter=isRequestingFullContacts) BOOL requestingFullContacts;

@property (nonatomic, strong) FullTextSearchFinder *finder;

@end

@implementation OWSContactsManager

- (id)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _avatarCache = [ImageCache new];
    SDImageCacheConfig *config = [SDImageCacheConfig defaultCacheConfig];
    config.maxDiskAge = 3 * kMonthInterval;
    config.maxDiskSize = 100 * 1024 * 1024;
    config.maxMemoryCost = 30 * 1024 * 1024;
    _sdAvatarCache = [[SDImageCache alloc] initWithNamespace:@"default" diskCacheDirectory:[OWSProfileManager sharedManager].profileAvatarsDirPath config:config];
    _imageManager = [[SDWebImageManager alloc] initWithCache:_sdAvatarCache loader:[SDWebImageDownloader sharedDownloader]];
    
    _allContacts = @[];
    _nofityContacts = @[];
    _allContactsMap = @{};
    _signalAccountMap = @{};
    _allBots = @[];
    _signalAccounts = @[];
    _systemContactsFetcher = [SystemContactsFetcher new];
    _systemContactsFetcher.delegate = self;

    OWSSingletonAssert();

    if (CurrentAppContext().isMainApp) {
        AppReadinessRunNowOrWhenAppWillBecomeReady(^{
            [self loadSignalAccountsFromCache];
            [self startObserving];
        });
    }
        
    return self;
}

- (void)loadSignalAccountsFromCache
{
    [BenchManager benchWithTitle:@"loadSignalAccountsFromCache" block:^{
        __block NSMutableArray<SignalAccount *> *signalAccounts;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            NSUInteger signalAccountCount = [SignalAccount anyCountWithTransaction:transaction];
            OWSLogInfo(@"%@ loading %lu signal accounts from cache.", self.logTag, (unsigned long)signalAccountCount);
            
            signalAccounts = [[NSMutableArray alloc] initWithCapacity:signalAccountCount];
            
            [SignalAccount anyEnumerateWithTransaction:transaction
                                               batched:YES
                                                 block:^(SignalAccount * signalAccount, BOOL * stop) {
                if ([signalAccount isKindOfClass:SignalAccount.class]) {
                    [signalAccounts addObject:signalAccount];
                } else {
                    OWSLogError(@"error instance, not SignalAccount class: %@", signalAccount);
                }
            }];
        }];
        
        DispatchMainThreadSafe(^{
            [self updateSignalAccounts:signalAccounts manualEditResult:@"" finished:YES manualEditSuccess:^(NSString *manualEditResult, BOOL finished) {
                OWSLogInfo(@"load cache finished status: %d", finished);
            }];
        });
    }];
}

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("org.difft.contacts.buildSignalAccount", DISPATCH_QUEUE_SERIAL);
    });

    return _serialQueue;
}

#pragma mark - System Contact Fetching
- (void)userRequestedSystemContactsRefreshWithIsUserRequested:(BOOL)isUserRequested completion:(void (^)(NSError *_Nullable error))completionHandler
{
    if(self.requestingFullContacts){
        OWSLogWarn(@"ignore duplicate request");
        if(completionHandler){
            completionHandler(nil);
        }
        return;
    }
    
    self.requestingFullContacts = YES;
    
    [self fetchAndUpdateContactInfoForRecipientId:TSConstants.officialBotId];

    [self.systemContactsFetcher userRequestedRefreshWithIsUserRequested:isUserRequested completion:^(NSError * error) {
        self.requestingFullContacts = NO;
        if(completionHandler){
            if (error) {
                OWSLogError(@"%@", error);
            }
            completionHandler(error);
        }
    }];
}

- (BOOL)systemContactsHaveBeenRequestedAtLeastOnce
{
    return self.systemContactsFetcher.systemContactsHaveBeenRequestedAtLeastOnce;
}

- (nullable UIImage*)localProfileAvatarImage
{
    return [self.profileManager localProfileAvatarImage];
}

- (nullable NSString *)localProfileNameWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [self.profileManager localProfileNameWithTransaction:transaction];
}

#pragma mark - SystemContactsFetcherDelegate

// 启动和 norify 全量拉通讯录逻辑汇聚在此
- (void)systemContactsFetcher:(SystemContactsFetcher *)systemsContactsFetcher
              updatedContacts:(NSArray<Contact *> *)contacts
              isUserRequested:(BOOL)isUserRequested
{
    __block OWSBackgroundTask *_Nullable backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];
    [self updateWithContacts:contacts manualEdited:NO notifyMessage:NO manualEditSuccess:^(NSString *manualEditTip, BOOL finished) {
        if (finished) {
            
            OWSLogInfo(@"full update contacts finished");
            NSString *localVersion = [AppVersion shared].currentAppReleaseVersion;
            [CurrentAppContext().appUserDefaults setObject:localVersion forKey:kLoadedContactsKey];
            [CurrentAppContext().appUserDefaults synchronize];
        } else {
            
            OWSLogError(@"full update contacts have not finished");
            [self clearShouldBeInitializedTag];
        }
        backgroundTask = nil;
    }];
}

- (void)addUnknownContact:(Contact *)contact addSuccess:(void (^)(NSString *))successHandler
{
//    NSArray<Contact *> *contacts = @[contact,];
//    [self updateWithContacts:contacts shouldClearStaleCache:NO manualEdited:YES notifyMessage:NO manualEditSuccess:successHandler];
}

- (void)handleNotifyMessageWithContacts:(NSArray<Contact *> *)contacts success:(void (^)(NSString *))success
{
    if(!DTParamsUtils.validateArray(contacts)) return;
    
    __block OWSBackgroundTask *_Nullable backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];
    [self updateWithContacts:contacts manualEdited:NO notifyMessage:YES manualEditSuccess:^(NSString *manualEditTip, BOOL finished) {
        backgroundTask = nil;
    }];
}

- (void)updateWithSignalAccounts:(NSArray<SignalAccount *> *)signalAccounts {
    dispatch_async(self.serialQueue, ^{

        if (!signalAccounts.count) {
            return;
        }
        __block NSMutableArray *accountsToSave = [NSMutableArray new];

        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            [signalAccounts enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj setIsManualEdited:NO];
                SignalAccount *_Nullable oldSignalAccount = [self signalAccountForRecipientId:obj.recipientId transaction:readTransaction];
                if (![oldSignalAccount isEqual:obj] || ![oldSignalAccount.contact isEqualToContact:obj.contact]) {
                    [accountsToSave addObject:obj];
                }
            }];
        }];
        if (!accountsToSave.count) {
            return;
        }
        OWSLogInfo(@"%@ Updating %lu SignalAccounts", self.logTag, (unsigned long)accountsToSave.count);
        
        NSMutableArray *unhandleSignalAccountsArr = [accountsToSave mutableCopy];
        NSUInteger kBatchSize = 30;
        
        void (^nextBlock)(void) = ^{
            
            if(!self.signalAccountMap){
                self.signalAccountMap = @{};
            }
            NSMutableDictionary *newMap = self.signalAccountMap.mutableCopy;
            for (SignalAccount *newSignalAccount in accountsToSave) {
                newMap[newSignalAccount.recipientId] = newSignalAccount;
            }
            self.signalAccountMap = newMap.copy;
            [[NSNotificationCenter defaultCenter] postNotificationNameAsync:OWSContactsManagerSignalAccountsDidChangeNotification object:nil];
            
        };
        
        if (unhandleSignalAccountsArr.count > kBatchSize) {
            [self slowlyInsertAccounts:unhandleSignalAccountsArr batchSize:kBatchSize completion:^(BOOL finished) {
                nextBlock();
            }];
        } else {
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTrasation) {
                [Batching loopObjcWithBatchSize:kBatchSize loopBlock:^(BOOL * _Nonnull stop) {
                    SignalAccount *lastSignalAccount = unhandleSignalAccountsArr.lastObject;
                    if (lastSignalAccount == nil) {*stop = YES;return;}
                    [lastSignalAccount anyInsertWithTransaction:writeTrasation];
                    [unhandleSignalAccountsArr removeLastObject];
                }];
            });
            nextBlock();
        }
        
        
    });
}

- (void)updateSignalAccountWithRecipientId:(NSString *)recipientId withNewSignalAccount:(SignalAccount *)signalAccount withTransaction:(SDSAnyWriteTransaction *)transaction {
    [self updateSignalAccountWithRecipientId:recipientId isManualEdited:false withNewSignalAccount:signalAccount withTransaction:transaction];
}

- (void)updateSignalAccountWithRecipientId:(NSString *)recipientId isManualEdited:(BOOL)isManualEdited withNewSignalAccount:(SignalAccount *)signalAccount withTransaction:(SDSAnyWriteTransaction *)transaction {
    if (!signalAccount || !recipientId) {
        return;
    }
    SignalAccount * newSignalAccount = signalAccount.copy;
    SignalAccount *oldSignalAccount = [SignalAccount anyFetchWithUniqueId:recipientId transaction:transaction ignoreCache:YES];
    if ([oldSignalAccount isEqualToSignalAccount:newSignalAccount]) return;
    if(oldSignalAccount){
        [newSignalAccount anyUpdateWithTransaction:transaction
                                             block:^(SignalAccount * instance) {
            [instance setIsManualEdited:isManualEdited];
            instance.contact = newSignalAccount.contact;
        }];
    }else{
        [newSignalAccount anyInsertWithTransaction:transaction];
    }
    
    [self.profileManager addUserToProfileWhitelist:recipientId transaction:transaction];
    
    if(!self.signalAccountMap){
        self.signalAccountMap = @{};
    }
    NSMutableDictionary *newMap = self.signalAccountMap.mutableCopy;
    newMap[newSignalAccount.recipientId] = newSignalAccount;
    self.signalAccountMap = newMap.copy;
    
    BOOL didReplace = NO;
    NSMutableArray *signalAccountMutableArr = [NSMutableArray array];
    NSArray *tmpSignalAccounts = self.signalAccounts.copy;
    for (SignalAccount *tmpSignalAccount in tmpSignalAccounts) {
        if ([tmpSignalAccount.uniqueId isEqual:newSignalAccount.uniqueId] && newSignalAccount) {
            [signalAccountMutableArr addObject:newSignalAccount];
            didReplace = YES;
        }else {
            [signalAccountMutableArr addObject:tmpSignalAccount];
        }
    }
    // Not in the array yet (e.g. weak demote re-add after action=2 delete) — append so it shows in the list.
    if (!didReplace && newSignalAccount) {
        [signalAccountMutableArr addObject:newSignalAccount];
    }
    self.signalAccounts = [signalAccountMutableArr copy];
    
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:OWSContactsManagerSignalAccountsDidChangeNotification object:nil];
    
}

- (void)removeAccountWithRecipientId:(NSString *)recipientId
                         transaction:(SDSAnyWriteTransaction *)transaction {
    if (!recipientId) {
        return;
    }
    SignalAccount *oldSignalAccount = [SignalAccount anyFetchWithUniqueId:recipientId transaction:transaction ignoreCache:YES];
    if (!oldSignalAccount) return;

    // Delete the persisted row too; in-memory removal alone leaves an orphan that
    // loadSignalAccountsFromCache resurrects on next launch.
    [oldSignalAccount anyRemoveWithTransaction:transaction];

    if(!self.signalAccountMap){
        self.signalAccountMap = @{};
    }
    NSMutableDictionary *newMap = self.signalAccountMap.mutableCopy;
    [newMap removeObjectForKey:recipientId];
    self.signalAccountMap = newMap.copy;
    
    NSMutableArray *newSignalAccounts = self.signalAccounts.mutableCopy;
    for (SignalAccount *tmpSignalAccount in self.signalAccounts) {
        if ([tmpSignalAccount.uniqueId isEqual:recipientId]) {
            [newSignalAccounts removeObject:tmpSignalAccount];
        }
    }
    self.signalAccounts = [newSignalAccounts copy];
    
    [[NSNotificationCenter defaultCenter] postNotificationNameAsync:OWSContactsManagerSignalAccountsDidChangeNotification object:nil];
    
}

#pragma mark - Intersection
- (void)startObserving
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contactsUpdateNotifyIncrement:)
                                                 name:kContactsUpdateNotifyIncrement
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contactsUpdateNotifyFull:)
                                                 name:kContactsUpdateNotifyFull
                                               object:nil];
    
}

- (void)otherUsersProfileWillChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    OWSAssertDebug(recipientId.length > 0);

    [self.avatarCache removeAllImagesForKey:recipientId];
}

- (void)contactsUpdateNotifyIncrement:(NSNotification *)notification{
    OWSLogInfo(@"handle contactsUpdateNotifyIncrement");
    [self handleNotifyMessageWithContacts:notification.userInfo[kContactsUpdateMembersKey] success:^(NSString * _Nonnull string) {
        
    }];
}

- (void)contactsUpdateNotifyFull:(NSNotification *)notification{
    OWSLogInfo(@"handle contactsUpdateNotifyFull");
    [self userRequestedSystemContactsRefreshWithIsUserRequested:NO completion:^(NSError * _Nullable error)  {
        if (error) {
            OWSLogError(@"Notify Full Update contacts failed with error: %@", error);
            return;
        }
        // Friend store refreshed — reconcile weak contacts.
        [[DTWeakContactManager shared] reconcileFromServer];
    }];
}

- (void)updateWithContacts:(NSArray<Contact *> *)contacts
              manualEdited:(BOOL)manualEdited
             notifyMessage:(BOOL)notifyMessage
         manualEditSuccess:(void (^)(NSString *manualEditTip, BOOL finished))successHandler
{
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary<NSString *, Contact *> *allContactsMap = [NSMutableDictionary new];
        for (Contact *contact in contacts) {
    
            [contact.userTextPhoneNumbers enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                allContactsMap[obj] = contact;
            }];
            
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if(notifyMessage){
                self.nofityContacts = contacts;
            }else{
                self.allContacts = contacts;
                self.allContactsMap = [allContactsMap copy];
                [self.avatarCache removeAllImages];
                [self deleteUserThreadNotInContacts];
            }
            
            if(notifyMessage){
                OWSLogInfo(@"build signal accounts for contactsUpdateNotifyIncrement");
                [self buildSignalAccountsForNotifyMessageWithSuccess:successHandler];
            }else{
                
                [self fullUpdateWithmanualEdited:manualEdited success:successHandler];
            }
        });
    });
}


/// 删除不在新通讯录里的老通讯录用户private chat datas
- (void)deleteUserThreadNotInContacts {
    
    NSMutableArray *needRemoveContactIds = @[].mutableCopy;
    NSArray *newContactIds = self.allContactsMap.allKeys;
    [self.signalAccountMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SignalAccount * _Nonnull obj, BOOL * _Nonnull stop) {
        if (!obj.isBot && !obj.contact.isExternal && ![newContactIds containsObject:key]) {
            [needRemoveContactIds addObject:key];
        }
    }];
    
    if (needRemoveContactIds.count){
        OWSLogInfo(@"will remove old friends.");
        [self slowlyDeleteThreads:needRemoveContactIds batchSize:30 completion:^(BOOL finished) {
            
        }];
    }
}

- (void)slowlyDeleteThreads:(NSMutableArray<NSString *> *)contactIds
                   batchSize:(NSUInteger)batchSize
                  completion:(void (^)(BOOL finished))completion{
    
    if(contactIds.count <= 0){
        !completion ?: completion(YES);
        return;
    }
    
    __block NSUInteger loopBatchIndex = 0;
    [BenchManager benchWithTitle:@"slowlyDeleteThreads" block:^{
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                NSString *lastContactId = contactIds.lastObject;
                if (loopBatchIndex == batchSize || lastContactId == nil) {*stop = YES;return;}
                [self deleteThreads:@[lastContactId] transaction:writeTransaction];
                OWSLogInfo(@"slowlyDeleteThreads remove thread");
                [contactIds removeObject:lastContactId];
                loopBatchIndex += 1;
            }];
        });
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self slowlyDeleteThreads:contactIds batchSize:batchSize completion:completion];
    });
    
}

- (void)deleteThreads:(NSArray<NSString *> *)contactIds transaction:(SDSAnyWriteTransaction *)transaction{
    for (NSString *contactId in contactIds) {
        TSContactThread *contactThread = [TSContactThread getThreadWithContactId:contactId transaction:transaction];
        if (!contactThread) {
            continue;;
        }
        [contactThread removeAllThreadInteractionsWithTransaction:transaction];
        [contactThread anyRemoveWithTransaction:transaction];
    }
}


- (void)buildSignalAccountsForNotifyMessageWithSuccess:(void (^)(NSString *, BOOL finished))success{
    dispatch_async(self.serialQueue, ^{
        NSArray<Contact *> *contacts = self.nofityContacts;
        
        OWSLogInfo(@"%@ notify update contacts count = %ld",self.logTag , contacts.count);
        
        __block NSMutableArray<SignalAccount *> *allSignalAccounts = [NSMutableArray new];
        __block NSMutableArray<SignalAccount *> *removedSignalAccounts = [NSMutableArray new];
        
        NSMutableDictionary *changeIds = @{}.mutableCopy;
        
        NSMutableDictionary<NSString *, Contact *> *allContactsMap = self.allContactsMap.mutableCopy;
        DatabaseStorageWrite(self.databaseStorage, (^(SDSAnyWriteTransaction *transaction) {
            
            NSMutableDictionary<NSString *, Contact *> *contactsMap = self.allContactsMap.mutableCopy;
            
            for (Contact *contact in contacts) {
                
                if(![contact isKindOfClass:[DTContactActionEntity class]]){
                    break;
                }
                
                NSMutableSet<NSString *> *abPhoneNumbers = [NSMutableSet set];
                
                for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
                    [abPhoneNumbers addObject:phoneNumber];
                }
                NSMutableArray<SignalAccount *> *signalAccounts = [NSMutableArray new];
                [abPhoneNumbers enumerateObjectsUsingBlock:^(NSString *rId, BOOL * _Nonnull aStop) {
                    SignalAccount *signalAccount = [[SignalAccount alloc] initWithRecipientId:rId];
                    signalAccount.contact = contact;
                    signalAccount.contact.external = NO;
                    if(DTParamsUtils.validateString(signalAccount.contact.remark) && [[DTConversationSettingHelper sharedInstance] isEncryptedRemarkString:signalAccount.contact.remark]){
                        signalAccount.contact.remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:signalAccount.contact.remark receptid:signalAccount.recipientId];
                    }
                    // Remark/remarkAvatar live in conversation config, not the contacts directory, so a
                    // notify-driven rebuild omits them. Preserve the locally-cached values when the server
                    // contact carries none, otherwise re-adding a weak contact as a friend wipes the remark.
                    SignalAccount *existingAccount = [self signalAccountForRecipientId:rId transaction:transaction];
                    if (existingAccount.contact) {
                        if (!DTParamsUtils.validateString(signalAccount.contact.remark) && DTParamsUtils.validateString(existingAccount.contact.remark)) {
                            signalAccount.contact.remark = existingAccount.contact.remark;
                        }
                        if (!signalAccount.contact.remarkAvatar && existingAccount.contact.remarkAvatar) {
                            signalAccount.contact.remarkAvatar = existingAccount.contact.remarkAvatar;
                        }
                    }
                    if (abPhoneNumbers.count > 1) {
                        signalAccount.hasMultipleAccountContact = YES;
                        signalAccount.multipleAccountLabelText =
                        [[self class] accountLabelForContact:contact recipientId:rId];
                    }
                    [signalAccount setIsManualEdited:NO];
                    
                    [signalAccounts addObject:signalAccount];
                }];
                
                DTContactActionEntity *contactActionEntity = (DTContactActionEntity *)contact;
                
                switch (contactActionEntity.action) {
                    case DTContactNotifyActionAdd:
                    {
                        for (SignalAccount *signalAccount in signalAccounts) {

                            [signalAccount anyInsertWithTransaction:transaction];
                            // Re-friended via notify: clear any weak placeholder so the countdown clears now (no-op when not weak).
                            [[DTWeakContactManager shared] clearWeakPlaceholderWithUid:signalAccount.recipientId transaction:transaction];
                            [allSignalAccounts addObject:signalAccount];
                        }
                        
                        for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
                            if (phoneNumber.length > 0) {
                                allContactsMap[phoneNumber] = contact;
                            }
                        }
                        
                    }
                        break;
                    case DTContactNotifyActionUpdate:
                    {
                        for (SignalAccount *signalAccount in signalAccounts) {
                            [signalAccount anyUpsertWithTransaction:transaction];
                            // Re-friended via notify: clear any weak placeholder (no-op when not weak).
                            [[DTWeakContactManager shared] clearWeakPlaceholderWithUid:signalAccount.recipientId transaction:transaction];
                            [allSignalAccounts addObject:signalAccount];
                        }
                        
                        for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
                            if (phoneNumber.length > 0) {
                                allContactsMap[phoneNumber] = contact;
                            }
                        }
                    }
                        break;
                    case DTContactNotifyActionDelete:
                    case DTContactNotifyActionPermanentDelete:
                    {
                        for (SignalAccount *signalAccount in signalAccounts) {

                            // Weak removal is owned by notify 25 — skip legacy action=2/3 delete (own active unfriend isn't weak, stays immediate).
                            if ([[DTWeakContactManager shared] isWeakContactWithRecipientId:signalAccount.recipientId
                                                                                transaction:transaction]) {
                                OWSLogInfo(@"[WeakContact] skip legacy action=%ld delete, owned by notify25", (long)contactActionEntity.action);
                                continue;
                            }

                            [signalAccount anyRemoveWithTransaction:transaction];

                            OWSLogInfo(@"contactsUpdateNotifyIncrement remove signalAccount %@", signalAccount.recipientId);
                            ///删除联系人的时候静默删除这个人所有的聊天记录
                            [self deleteThreads:@[signalAccount.recipientId] transaction:transaction];
                            
                            [removedSignalAccounts addObject:signalAccount];
                            
                            for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
                                if (phoneNumber.length > 0) {
                                    [allContactsMap removeObjectForKey:phoneNumber];
                                }
                            }
                            
                            changeIds[signalAccount.uniqueId] = @([SignalAccount isExt:signalAccount.uniqueId]);
                        }
                    }
                        break;
                        
                    default:
                        break;
                }
                
            }
            self.allContactsMap = contactsMap.copy;
        }));
        
//MARK: External_Hidden
        [DTGroupUtils postExternalChangeNotificationWithTargetIds:changeIds];
        
        if(!self.signalAccountMap){
            self.signalAccountMap = @{};
        }
        NSMutableDictionary *newMap = self.signalAccountMap.mutableCopy;
        [removedSignalAccounts enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [newMap removeObjectForKey:obj.recipientId];
        }];
        [allSignalAccounts enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            newMap[obj.recipientId] = obj;
        }];
        [self updateSignalAccounts:newMap.allValues manualEditResult:nil finished:YES manualEditSuccess:success];
    });
    
}

- (void)slowlyInsertAccounts:(NSMutableArray<SignalAccount *> *)signalAccounts 
                   batchSize:(NSUInteger)batchSize
                  completion:(void (^)(BOOL finished))completion {
    
    dispatch_async(self.serialQueue, ^{
        
        // order matters
        if(signalAccounts.count <= 0){
            !completion ?: completion(YES);
            return;
        }
        
        if(![self shouldHandelAccounts]){
            !completion ?: completion(NO);
            return;
        }
        
        __block NSUInteger loopBatchIndex = 0;
        __block BOOL normalFinished = YES;
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTrasation) {
            [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                SignalAccount *lastSignalAccount = signalAccounts.lastObject;
                if (loopBatchIndex == batchSize || lastSignalAccount == nil) {*stop = YES;return;}
                
                if (![self shouldHandelAccounts]) {
                    *stop = YES;
                    normalFinished = NO;
                    return;
                }
                
                [lastSignalAccount anyUpsertWithTransaction:writeTrasation];
                [signalAccounts removeLastObject];
                loopBatchIndex += 1;
            }];
        });
        
        if (normalFinished) {
            if([self contactsShouldBeInitialized]){
                [self slowlyInsertAccounts:signalAccounts batchSize:batchSize completion:completion];
            }else{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kFullUpdateContactsFrequency * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self slowlyInsertAccounts:signalAccounts batchSize:batchSize completion:completion];
                });
            }
        } else {
            
            !completion ?: completion(NO);
        }
    });
    
}

- (void)checkNeedDeletedAccounts:(NSArray<SignalAccount *> *)needRemoveOrUpdateArray
             newSignalAccountIds:(NSArray<NSString *> *)newSignalAccountIds
                 deletedAccounts:(NSMutableArray<SignalAccount *> *)deletedAccounts
              externalChangedIds:(NSMutableDictionary *)changeIds
                      completion:(void (^)(BOOL finished))completion{
    
    // order matters
    if(!needRemoveOrUpdateArray.count){
        !completion ?: completion(YES);
        return;
    }
    
    if(![self shouldHandelAccounts]){
        !completion ?: completion(NO);
        return;
    }
    
    [BenchManager benchWithTitle:@"checkNeedDeletedAccounts" block:^{
        
        [needRemoveOrUpdateArray enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull lastSignalAccount, NSUInteger idx, BOOL * _Nonnull stop) {
            BOOL needDelete = ![newSignalAccountIds containsObject:lastSignalAccount.recipientId] && !lastSignalAccount.contact.isExternal && !lastSignalAccount.isBot;
            if(needDelete){
                [deletedAccounts addObject:lastSignalAccount];
            }
        }];
        
        if (deletedAccounts.count) {
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
                [deletedAccounts enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull needDeletedAccount, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSNumber *isExt = @([SignalAccount isExt:needDeletedAccount.uniqueId transaction:readTransaction]);
                    changeIds[needDeletedAccount.uniqueId] = isExt;
                }];
            }];
        }
    }];
    
    !completion ?: completion(YES);
}

- (void)slowlyDeleteAccounts:(NSMutableArray<SignalAccount *> *)signalAccounts
                   batchSize:(NSUInteger)batchSize
                  completion:(void (^)(BOOL finished))completion{
    
    dispatch_async(self.serialQueue, ^{
        
        // order matters
        if(signalAccounts.count <= 0){
            !completion ?: completion(YES);
            return;
        }
        
        if(![self shouldHandelAccounts]){
            !completion ?: completion(NO);
            return;
        }
        
        __block NSUInteger loopBatchIndex = 0;
        __block BOOL normalFinished = YES;
        [BenchManager benchWithTitle:@"slowlyDeleteAccounts" block:^{
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                [Batching loopObjcWithBatchSize:batchSize loopBlock:^(BOOL * _Nonnull stop) {
                    
                    SignalAccount *lastSignalAccount = signalAccounts.lastObject;
                    if (loopBatchIndex == batchSize || lastSignalAccount == nil) {*stop = YES;return;}
                    
                    if (![self shouldHandelAccounts]) {
                        *stop = YES;
                        normalFinished = NO;
                        return;
                    }
                    
                    [lastSignalAccount anyRemoveWithTransaction:writeTransaction];
                    OWSLogInfo(@"slowlyDeleteAccounts remove signalAccount %@", lastSignalAccount.recipientId);
                    
                    [signalAccounts removeLastObject];
                    loopBatchIndex += 1;
                }];
            });
        }];
        
        if (normalFinished) {
            if([self contactsShouldBeInitialized]){
                [self slowlyDeleteAccounts:signalAccounts batchSize:batchSize completion:completion];
            }else{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kFullUpdateContactsFrequency * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self slowlyDeleteAccounts:signalAccounts batchSize:batchSize completion:completion];
                });
            }
        } else {
            
            !completion ?: completion(NO);
        }
    });
    
}

- (void)fullUpdateWithmanualEdited:(BOOL)manualEdited success:(void (^)(NSString *, BOOL finished))successHandler {
    
    dispatch_async(self.serialQueue, ^{
        
        NSMutableArray<SignalAccount *> *newSignalAccounts = [NSMutableArray new];
        NSArray<Contact *> *contacts = self.allContacts;
        
        NSMutableArray *newSignalAccountIds = @[].mutableCopy;
        
        [contacts enumerateObjectsUsingBlock:^(Contact * _Nonnull contact, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSMutableSet<NSString *> *abPhoneNumbers = [NSMutableSet set];
            
            for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
                [abPhoneNumbers addObject:phoneNumber];
            }
            
            [abPhoneNumbers enumerateObjectsUsingBlock:^(NSString *rId, BOOL * _Nonnull aStop) {
                SignalAccount *signalAccount = [[SignalAccount alloc] initWithRecipientId:rId];
                signalAccount.contact = contact;
                signalAccount.contact.external = NO;
                // Preserve locally-cached remark/remarkAvatar (conversation-config owned, absent from
                // the directory contact) across a full rebuild — mirrors the notify path at ~line 526.
                SignalAccount *existingAccount = [self signalAccountForRecipientId:rId];
                if (existingAccount.contact) {
                    if (!DTParamsUtils.validateString(signalAccount.contact.remark) && DTParamsUtils.validateString(existingAccount.contact.remark)) {
                        signalAccount.contact.remark = existingAccount.contact.remark;
                    }
                    // remarkAvatar is an NSDictionary, so use validateDictionary (validateString would
                    // always fail the kind check) — keeps the empty-value handling consistent with remark.
                    if (!DTParamsUtils.validateDictionary(signalAccount.contact.remarkAvatar) && DTParamsUtils.validateDictionary(existingAccount.contact.remarkAvatar)) {
                        signalAccount.contact.remarkAvatar = existingAccount.contact.remarkAvatar;
                    }
                }
                if (abPhoneNumbers.count > 1) {
                    signalAccount.hasMultipleAccountContact = YES;
                    signalAccount.multipleAccountLabelText =
                        [[self class] accountLabelForContact:contact recipientId:rId];
                }
                [signalAccount setIsManualEdited:manualEdited];
                
                [newSignalAccounts addObject:signalAccount];
                [newSignalAccountIds addObject:rId];
            }];
            
        }];
        
        NSSet<SignalAccount *> *oldAccountsSet = [[NSSet alloc] initWithArray:self.signalAccounts];
        NSSet<SignalAccount *> *newAccountsSet = [[NSSet alloc] initWithArray:newSignalAccounts];
        
        NSMutableSet<SignalAccount *> *needInsertOrUpdateSet = newAccountsSet.mutableCopy;
        [needInsertOrUpdateSet minusSet:oldAccountsSet];
        
        NSMutableSet<SignalAccount *> *needRemoveOrUpdateSet = oldAccountsSet.mutableCopy;
        [needRemoveOrUpdateSet minusSet:newAccountsSet];
        
        NSString *manualEditResult = nil;
        if (manualEdited) {
            if (newSignalAccounts.count > 0) {
                manualEditResult = @"ADD_CONTACT_ADD_SUCCESS";
            } else {
                manualEditResult = @"ADD_CONTACT_ADD_FAILED";
            }
        }
        
        BOOL initialLized = [self contactsShouldBeInitialized];
        OWSLogInfo(@"need slowlyDeleteAccounts count %lu, insertAccounts count %lu, initialLized %d.", needRemoveOrUpdateSet.count, needInsertOrUpdateSet.count, initialLized);
        
        NSMutableDictionary *externalChangedIds = @{}.mutableCopy;
        NSMutableArray *deletedAccounts = @[].mutableCopy;
        __block BOOL finished = YES;
        
        [self checkNeedDeletedAccounts:needRemoveOrUpdateSet.allObjects.copy
                   newSignalAccountIds:newSignalAccountIds.copy
                       deletedAccounts:deletedAccounts
                    externalChangedIds:externalChangedIds
                            completion:^(BOOL checkFinished) {
            finished = finished && checkFinished;
            [self slowlyDeleteAccounts:deletedAccounts.mutableCopy
                             batchSize:kFullUpdateContactsBatch
                            completion:^(BOOL deleteFinished) {
                finished = finished && deleteFinished;
                [self slowlyInsertAccounts:needInsertOrUpdateSet.allObjects.mutableCopy batchSize:kFullUpdateContactsBatch completion:^(BOOL insertFinished){
                    
                    finished = finished && insertFinished;
                    [DTGroupUtils postExternalChangeNotificationWithTargetIds:externalChangedIds];
                    if(!self.signalAccountMap){
                        self.signalAccountMap = @{};
                    }
                    NSMutableDictionary *newMap = self.signalAccountMap.mutableCopy;
                    [deletedAccounts enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        [newMap removeObjectForKey:obj.recipientId];
                    }];
                    OWSLogInfo(@"slowlyDeleteAccounts count %lu, initialLized %d.", deletedAccounts.count, initialLized);
                    [needInsertOrUpdateSet.allObjects enumerateObjectsUsingBlock:^(SignalAccount * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        newMap[obj.recipientId] = obj;
                    }];
                    OWSLogInfo(@"slowlyInsertAccounts count %lu, initialLized %d", needInsertOrUpdateSet.count, initialLized);
                    if(finished && 
                       (deletedAccounts.count != 0 || needInsertOrUpdateSet.count != 0)){
                        [self updateSignalAccounts:newMap.allValues manualEditResult:manualEditResult finished:finished manualEditSuccess:successHandler];
                    } else {
                        !successHandler ?: successHandler(manualEditResult, finished);
                    }
                }];
            }];
        }];
    });
    
}

- (void)updateSignalAccounts:(NSArray<SignalAccount *> *)signalAccounts
            manualEditResult:(NSString *)manualEditResult
                    finished:(BOOL)finished
           manualEditSuccess:(void (^)(NSString *, BOOL finished))successHandler
{

    if ([signalAccounts isEqual:self.signalAccounts]) {
        OWSLogDebug(@"%@ SignalAccounts unchanged.", self.logTag);
    } else {
        NSMutableDictionary<NSString *, SignalAccount *> *signalAccountMap = [NSMutableDictionary new];
        NSMutableArray <SignalAccount *> *allBots = [NSMutableArray new];
        for (SignalAccount *signalAccount in signalAccounts) {
            signalAccountMap[signalAccount.recipientId] = signalAccount;
            if (signalAccount.isBot) {
                [allBots addObject:signalAccount];
            }
        }

        self.signalAccountMap = [signalAccountMap copy];
        self.allBots = [allBots copy];
        NSMutableArray *finalSignalAccounts = signalAccounts.mutableCopy;
        [finalSignalAccounts sortUsingComparator:self.signalAccountComparator];
        self.signalAccounts = finalSignalAccounts.copy;

        [[NSNotificationCenter defaultCenter]
            postNotificationNameAsync:OWSContactsManagerSignalAccountsDidChangeNotification
                               object:nil];
    }
    
    if (!DTParamsUtils.validateString(manualEditResult)) {
        manualEditResult = @"no manualEditResult msg.";
    }
        
    !successHandler ?: successHandler(manualEditResult, finished);
}

- (OWSProfileManager *)profileManager
{
    return [OWSProfileManager sharedManager];
}

- (NSString *_Nullable)cachedContactNameForRecipientId:(NSString *)recipientId
                                      preferRemarkName:(BOOL)shouldPreferRemarkName
{
    OWSAssertDebug(recipientId.length > 0);

    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId];
    if (!signalAccount) {
        Contact *_Nullable nonSignalContact = self.allContactsMap[recipientId];
        if (!nonSignalContact) {
            return nil;
        }
        return nonSignalContact.fullName;
    }

    return [self cachedContactNameForRecipientId:recipientId
                                preferRemarkName:shouldPreferRemarkName
                                   signalAccount:signalAccount
                                     transaction:nil];
}

- (NSString *_Nullable)cachedContactNameForRecipientId:(NSString *)recipientId
                                      preferRemarkName:(BOOL)shouldPreferRemarkName
                                           transaction:(SDSAnyReadTransaction *)transaction {
    OWSAssertDebug(recipientId.length > 0);

    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId
                                                                   transaction:transaction];

    return [self cachedContactNameForRecipientId:recipientId
                                preferRemarkName:shouldPreferRemarkName
                                   signalAccount:signalAccount
                                     transaction:transaction];
}

- (NSString *_Nullable)cachedContactNameForRecipientId:(NSString *)recipientId
                                      preferRemarkName:(BOOL)shouldPreferRemarkName
                                         signalAccount:(SignalAccount *)signalAccount {
    return [self cachedContactNameForRecipientId:recipientId
                                preferRemarkName:shouldPreferRemarkName
                                   signalAccount:signalAccount
                                     transaction:nil];
}

- (NSString *_Nullable)cachedContactNameForRecipientId:(NSString *)recipientId
                                      preferRemarkName:(BOOL)shouldPreferRemarkName
                                         signalAccount:(SignalAccount *)signalAccount
                                           transaction:(SDSAnyReadTransaction *)transaction {
    if (!signalAccount) {
        Contact *_Nullable nonSignalContact = self.allContactsMap[recipientId];
        if (!nonSignalContact) {
            return nil;
        }
        return nonSignalContact.fullName;
    }

    if ([signalAccount isBot]) {
        if (shouldPreferRemarkName) {
            NSString *displayName = signalAccount.remarkName;
            if (!DTParamsUtils.validateString(displayName)) {
                displayName = signalAccount.contactFullName;
            }
            return displayName;
        } else {
            NSString *officialAccountText = Localized(@"PERSON_CARD_OFFICIAL_ACCOUNT", @"");

            if (DTParamsUtils.validateString(signalAccount.remarkName)) {
                NSString *nameLabel = Localized(@"CONTACT_PROFILE_NAME", @"");
                NSString *botName = signalAccount.contactFullName;

                if (DTParamsUtils.validateString(botName) && ![botName isEqualToString:recipientId]) {
                    return [NSString stringWithFormat:@"%@・%@: %@", officialAccountText, nameLabel, botName];
                }
            }

            return officialAccountText;
        }
    }

    NSString *name = signalAccount.remarkName;
    if (!shouldPreferRemarkName ||
        !DTParamsUtils.validateString(name)) {
        name = signalAccount.contactFullName;
        if (!DTParamsUtils.validateString(name)) {
            return nil;
        }
    }

    if ([name isEqualToString:recipientId]) {
        if (transaction) {
            name = [self displayIdWithRecipientId:recipientId transaction:transaction];
        } else {
            name = [self displayIdWithRecipientId:recipientId];
        }
    }

    NSString *multipleAccountLabelText = signalAccount.multipleAccountLabelText;
    if (multipleAccountLabelText.length == 0) {
        return name;
    }

    return [NSString stringWithFormat:@"%@ (%@)", name, multipleAccountLabelText];
}

- (NSString *_Nullable)cachedFirstNameForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId];
    return signalAccount.contact.firstName.filterStringForDisplay;
}

- (NSString *_Nullable)cachedLastNameForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId];
    return signalAccount.contact.lastName.filterStringForDisplay;
}

#pragma mark - View Helpers

// TODO move into Contact class.
+ (NSString *)accountLabelForContact:(Contact *)contact recipientId:(NSString *)recipientId
{
    OWSAssertDebug(contact);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug([contact.textSecureIdentifiers containsObject:recipientId]);

    if (contact.textSecureIdentifiers.count <= 1) {
        return nil;
    }

    // 1. Find the phone number type of this account.
    NSString *phoneNumberLabel = [contact nameForPhoneNumber:recipientId];

    // 2. Find all phone numbers for this contact of the same type.
    NSMutableArray *phoneNumbersWithTheSameName = [NSMutableArray new];
    for (NSString *textSecureIdentifier in contact.textSecureIdentifiers) {
        if ([phoneNumberLabel isEqualToString:[contact nameForPhoneNumber:textSecureIdentifier]]) {
            [phoneNumbersWithTheSameName addObject:textSecureIdentifier];
        }
    }

    OWSAssertDebug([phoneNumbersWithTheSameName containsObject:recipientId]);
    if (phoneNumbersWithTheSameName.count > 1) {
        NSUInteger index =
            [[phoneNumbersWithTheSameName sortedArrayUsingSelector:@selector((compare:))] indexOfObject:recipientId];
        NSString *indexText = [OWSFormat formatInt:(int)index + 1];
        phoneNumberLabel =
            [NSString stringWithFormat:Localized(@"PHONE_NUMBER_TYPE_AND_INDEX_NAME_FORMAT",
                                           @"Format for phone number label with an index. Embeds {{Phone number label "
                                           @"(e.g. 'home')}} and {{index, e.g. 2}}."),
                      phoneNumberLabel,
                      indexText];
    }

    return phoneNumberLabel.filterStringForDisplay;
}

#pragma mark - Whisper User Management

- (BOOL)isSystemContact:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    return self.allContactsMap[recipientId] != nil;
}

- (BOOL)isSystemContactWithSignalAccount:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    return [self hasSignalAccountForRecipientId:recipientId];
}

- (BOOL)hasNameInSystemContactsForRecipientId:(NSString *)recipientId
{
    return [self cachedContactNameForRecipientId:recipientId preferRemarkName:YES].length > 0;
}

- (NSString *)unknownContactName
{
    return Localized(
        @"UNKNOWN_CONTACT_NAME", @"Displayed if for some reason we can't determine a contacts phone number *or* name");
}

#pragma mark - profile

- (nullable NSString *)formattedProfileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction
{
    NSString *_Nullable profileName = [self.profileManager profileNameForRecipientId:recipientId transaction:transaction];
    if (profileName.length == 0) {
        return nil;
    }

    NSString *profileNameFormatString = Localized(@"PROFILE_NAME_LABEL_FORMAT",
        @"Prepend a simple marker to differentiate the profile name, embeds the contact's {{profile name}}.");

    return [NSString stringWithFormat:profileNameFormatString, profileName];
}

- (nullable NSString *)profileNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction
{
    return [self.profileManager profileNameForRecipientId:recipientId transaction:transaction];
}

- (nullable NSString *)nameFromSystemContactsForRecipientId:(NSString *)recipientId
{
    return [self cachedContactNameForRecipientId:recipientId preferRemarkName:YES];
}

- (nullable NSString *)nicknameForAvatarWithRecipientId:(NSString *)recipientId
{
    // For avatar generation, we always use the contact's nickname (full name) without remark name
    return [self cachedContactNameForRecipientId:recipientId preferRemarkName:NO];
}

- (NSString *)commonDisplayNameForPhoneIdentifier:(NSString *)recipientId
                                 preferRemarkName:(BOOL)shouldPreferRemarkName {
    NSString *result = [self commonDisplayNameCoreForRecipientId:recipientId
                                                    preferRemarkName:shouldPreferRemarkName];
    if (DTParamsUtils.validateString(result)) {
        return result;
    }
    
    // Fall back to just using their recipientId
    return [self displayIdWithRecipientId: recipientId];
}

- (NSString *)commonDisplayNameForPhoneIdentifier:(NSString *)recipientId
                                 preferRemarkName:(BOOL)shouldPreferRemarkName
                                      transaction:(SDSAnyReadTransaction *)transaction {
    if (!DTParamsUtils.validateString(recipientId)) {
        return self.unknownContactName;
    }

    NSString *result = [self commonDisplayNameCoreForRecipientId:recipientId
                                                preferRemarkName:shouldPreferRemarkName
                                                     transaction:transaction];
    if (DTParamsUtils.validateString(result)) {
        return result;
    }

    // 查 DB 获取
    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId
                                                                   transaction:transaction];

    NSString *_Nullable nameInDB = [self cachedContactNameForRecipientId:recipientId
                                                        preferRemarkName:shouldPreferRemarkName
                                                            signalAccount:signalAccount];
    if (DTParamsUtils.validateString(nameInDB)) {
        return nameInDB;
    }

    NSString *groupDisplayNameInDB = signalAccount.contact.groupDisplayName;
    if (DTParamsUtils.validateString(groupDisplayNameInDB)) {
        return groupDisplayNameInDB;
    }

    return [self displayIdWithRecipientId:recipientId transaction:transaction];
}

- (NSString *)commonDisplayNameCoreForRecipientId:(NSString *)recipientId
                                 preferRemarkName:(BOOL)shouldPreferRemarkName {
    if (!DTParamsUtils.validateString(recipientId)) {
        return @"";
    }

    // 优先使用缓存的名字
    NSString *_Nullable cacheName = [self cachedContactNameForRecipientId:recipientId
                                                         preferRemarkName:shouldPreferRemarkName];
    if (DTParamsUtils.validateString(cacheName)) {
        return [cacheName isEqualToString:recipientId] ? [self displayIdWithRecipientId:cacheName] : cacheName;
    }

    // 其次使用群组显示名
    NSString *groupDisplayName = [self groupDisplayNameForRecipientId:recipientId];
    if (DTParamsUtils.validateString(groupDisplayName)) {
        return [groupDisplayName isEqualToString:recipientId] ? [self displayIdWithRecipientId:groupDisplayName] : groupDisplayName;
    }

    return nil; // 没找到，交给调用方兜底
}

- (NSString *)commonDisplayNameCoreForRecipientId:(NSString *)recipientId
                                 preferRemarkName:(BOOL)shouldPreferRemarkName
                                      transaction:(SDSAnyReadTransaction *)transaction {
    if (!DTParamsUtils.validateString(recipientId)) {
        return @"";
    }

    // 优先使用缓存的名字
    NSString *_Nullable cacheName = [self cachedContactNameForRecipientId:recipientId
                                                         preferRemarkName:shouldPreferRemarkName
                                                              transaction:transaction];
    if (DTParamsUtils.validateString(cacheName)) {
        return [cacheName isEqualToString:recipientId] ? [self displayIdWithRecipientId:cacheName transaction:transaction] : cacheName;
    }

    // 其次使用群组显示名
    NSString *groupDisplayName = [self groupDisplayNameForRecipientId:recipientId transaction:transaction];
    if (DTParamsUtils.validateString(groupDisplayName)) {
        return [groupDisplayName isEqualToString:recipientId] ? [self displayIdWithRecipientId:groupDisplayName transaction:transaction] : groupDisplayName;
    }

    return nil; // 没找到，交给调用方兜底
}

- (NSString *_Nonnull)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
{
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:YES];
}

- (NSString *_Nonnull)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
                                        transaction:(SDSAnyReadTransaction *)transaction {
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:YES transaction:transaction];
}

//跳过 remark name，仅返回原始name或number
- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId {
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:NO];
}

- (NSString *)rawDisplayNameForPhoneIdentifier:(NSString *)recipientId
                                   transaction:(SDSAnyReadTransaction *)transaction {
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:NO transaction:transaction];
}

- (NSString *)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
                                       signalAccount:(SignalAccount *)signalAccount {
    return [self displayNameForPhoneIdentifier:recipientId
                                 signalAccount:signalAccount
                                   transaction:nil];
}

- (NSString *)displayNameForPhoneIdentifier:(NSString *_Nullable)recipientId
                                       signalAccount:(SignalAccount *)signalAccount
                                         transaction:(SDSAnyReadTransaction *)transaction {
    if (!recipientId || !signalAccount) {
        return self.unknownContactName;
    }

    NSString *_Nullable cacheName = [self cachedContactNameForRecipientId:recipientId
                                                         preferRemarkName:YES
                                                            signalAccount:signalAccount
                                                              transaction:transaction];

    if (cacheName && cacheName.length > 0) {
        if ([cacheName isEqualToString:recipientId]) {
            return transaction ? [self displayIdWithRecipientId:cacheName transaction:transaction] : [self displayIdWithRecipientId:cacheName];
        }
        return cacheName;
    }

    NSString *groupDisplayName = signalAccount.contact.groupDisplayName;
    if (DTParamsUtils.validateString(groupDisplayName)) {
        if ([groupDisplayName isEqualToString:recipientId]) {
            return transaction ? [self displayIdWithRecipientId:groupDisplayName transaction:transaction] : [self displayIdWithRecipientId:groupDisplayName];
        }
        return groupDisplayName;
    }

    return transaction ? [self displayIdWithRecipientId:recipientId transaction:transaction] : [self displayIdWithRecipientId:recipientId];
}


- (nullable NSString *)signatureForPhoneIdentifier:(NSString *_Nullable)phoneNumber transaction:(SDSAnyReadTransaction *)transaction {
    if (!phoneNumber) {
        return nil;
    }
    SignalAccount *account = [self signalAccountForRecipientId:phoneNumber transaction:transaction];
    if (account && account.contact) {
        return account.contact.signature;
    } else {
        return nil;
    }
}

- (nullable NSString *)emailForPhoneIdentifier:(NSString *_Nullable)phoneNumber transaction:(SDSAnyReadTransaction *)transaction {
    if (!phoneNumber) {
        return nil;
    }
    SignalAccount *account = [self signalAccountForRecipientId:phoneNumber transaction:transaction];
    if (account && account.contact) {
        return account.contact.email;
    } else {
        return nil;
    }
}


- (NSString *_Nonnull)displayNameForSignalAccount:(SignalAccount *)signalAccount
{
//    OWSAssertDebug(signalAccount);

    return [self displayNameForPhoneIdentifier:signalAccount.recipientId];
}

- (NSAttributedString *_Nonnull)formattedDisplayNameForSignalAccount:(SignalAccount *)signalAccount font:(UIFont *)font
{
    OWSAssertDebug(signalAccount);
    OWSAssertDebug(font);

    return [self formattedFullNameForRecipientId:signalAccount.recipientId font:font];
}

- (NSAttributedString *)formattedFullNameForRecipientId:(NSString *)recipientId font:(UIFont *)font {

    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(font);

    UIFont *boldFont = [UIFont ows_semiboldFontWithSize:font.pointSize];

    NSDictionary<NSString *, id> *boldFontAttributes =
        @{ NSFontAttributeName : boldFont, NSForegroundColorAttributeName : Theme.tprimaryColor };
    NSDictionary<NSString *, id> *normalFontAttributes =
        @{ NSFontAttributeName : font, NSForegroundColorAttributeName : Theme.tprimaryColor };
    NSDictionary<NSString *, id> *firstNameAttributes
        = (self.shouldSortByGivenName ? boldFontAttributes : normalFontAttributes);

    NSMutableAttributedString *formattedName = [NSMutableAttributedString new];
    NSString *firstName = [self formattedFullNameForRecipientId:recipientId];
    if (DTParamsUtils.validateString(firstName)) {
        [formattedName appendAttributedString:[[NSAttributedString alloc]
                                               initWithString:firstName
                                               attributes:firstNameAttributes]];
    } else {
        if (DTParamsUtils.validateString(recipientId)) {
            [formattedName appendAttributedString:[[NSAttributedString alloc] initWithString:recipientId
                                                                                  attributes:normalFontAttributes]];
            
            return formattedName;
        }
        
        return formattedName;
    }
        

    // Append unique label for contacts with multiple Signal accounts
    SignalAccount *signalAccount = [self signalAccountForRecipientId:recipientId];
    if (signalAccount && signalAccount.multipleAccountLabelText.length) {
        OWSAssertDebug(signalAccount.multipleAccountLabelText.length > 0);

        [formattedName
            appendAttributedString:[[NSAttributedString alloc] initWithString:@" (" attributes:normalFontAttributes]];
        [formattedName
            appendAttributedString:[[NSAttributedString alloc] initWithString:signalAccount.multipleAccountLabelText
                                                                   attributes:normalFontAttributes]];
        [formattedName
            appendAttributedString:[[NSAttributedString alloc] initWithString:@")" attributes:normalFontAttributes]];
    }

    return formattedName;
}

- (NSString *_Nullable)formattedFullNameForRecipientId:(NSString *)recipientId {
    NSString *displayName = [self formattedFirstNameForRecipientId:recipientId];
    if (DTParamsUtils.validateString(displayName)) {
        return displayName;
    } else {
        return recipientId;
    }
}

- (NSString *_Nullable)formattedFullNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction {
    NSString *displayName = [self formattedFirstNameForRecipientId:recipientId transaction:transaction];
    if (DTParamsUtils.validateString(displayName)) {
        return displayName;
    } else {
        return recipientId;
    }
}

- (NSString * _Nullable)formattedFirstNameForRecipientId:(NSString *)recipientId {
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:YES];
}

- (NSString * _Nullable)formattedFirstNameForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction {
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:YES transaction:transaction];
}

- (NSString *)contactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
{
    return [self commonDisplayNameForPhoneIdentifier:recipientId preferRemarkName:YES];
}

- (NSString *)displayNameForThread:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction
{
    if (thread.isNoteToSelf) {
        return MessageStrings.noteToSelf;
    } else if ([thread isKindOfClass:TSContactThread.class]) {
        TSContactThread *contactThread = (TSContactThread *)thread;
        return [self displayNameForPhoneIdentifier:contactThread.contactIdentifier transaction:transaction];
    } else if ([thread isKindOfClass:TSGroupThread.class]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        return [groupThread nameWithTransaction:transaction];
    } else {
        OWSFailDebug(@"unexpected thread: %@", thread);
        return @"";
    }
}

- (NSString *)contactOrProfileNameForPhoneIdentifier:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction {
    if (!recipientId.length) {
        return @"";
    }
    // Prefer a saved name from system contacts, if available
    NSString *_Nullable savedContactName = [self cachedContactNameForRecipientId:recipientId preferRemarkName:YES transaction:transaction];
    if (savedContactName.length > 0) {
        return [savedContactName isEqualToString:recipientId] ? [self displayIdWithRecipientId:savedContactName transaction:transaction] : savedContactName;
    }

    NSString *groupDisplayName = [self groupDisplayNameForRecipientId:recipientId transaction:transaction];
    if (DTParamsUtils.validateString(groupDisplayName)) {
        return [groupDisplayName isEqualToString:recipientId] ? [self displayIdWithRecipientId:groupDisplayName transaction:transaction] : groupDisplayName;
    }

    NSString *_Nullable profileName = [self.profileManager profileNameForRecipientId:recipientId transaction:transaction];

    if (profileName.length > 0) {
        NSString *numberAndProfileNameFormat = Localized(@"PROFILE_NAME_AND_PHONE_NUMBER_LABEL_FORMAT",
            @"Label text combining the phone number and profile name separated by a simple demarcation character. "
            @"Phone number should be most prominent. '%1$@' is replaced with {{phone number}} and '%2$@' is replaced "
            @"with {{profile name}}");

        NSString *numberAndProfileName =
            [NSString stringWithFormat:numberAndProfileNameFormat, recipientId, profileName];
        return numberAndProfileName;
    }

    // else fall back to recipient id
    return [self displayIdWithRecipientId:recipientId transaction:transaction];
}

- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
{
    return [[NSAttributedString alloc] initWithString:[self contactOrProfileNameForPhoneIdentifier:recipientId]];
}

- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
                                                             primaryFont:(UIFont *)primaryFont
                                                           secondaryFont:(UIFont *)secondaryFont
                                                             transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(primaryFont);
    OWSAssertDebug(secondaryFont);

    return [self attributedContactOrProfileNameForPhoneIdentifier:recipientId
                                                      primaryFont:primaryFont
                                                    secondaryFont:secondaryFont
                                                 primaryTextColor:nil
                                               secondaryTextColor:nil
                                                      transaction:transaction];
}

- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
                                                             primaryFont:(UIFont *)primaryFont
                                                           secondaryFont:(UIFont *)secondaryFont
                                                        primaryTextColor:(nullable UIColor *)primaryTextColor
                                                      secondaryTextColor:(nullable UIColor *)secondaryTextColor
                                                             transaction:(SDSAnyReadTransaction *)transaction
{
    NSMutableDictionary *primaryAttributes = @{NSFontAttributeName: primaryFont}.mutableCopy;
    if (primaryTextColor) {
        primaryAttributes[NSForegroundColorAttributeName] = primaryTextColor;
    }
    NSMutableDictionary *secondaryAttributes = @{NSFontAttributeName: secondaryFont}.mutableCopy;
    if (secondaryTextColor) {
        secondaryAttributes[NSForegroundColorAttributeName] = secondaryTextColor;
    }

    // Prefer a saved name from system contacts, if available
    NSString *_Nullable savedContactName = [self cachedContactNameForRecipientId:recipientId preferRemarkName:YES transaction:transaction];
    if (savedContactName.length > 0) {
        savedContactName = [savedContactName isEqualToString:recipientId] ? [self displayIdWithRecipientId:savedContactName transaction:transaction] : savedContactName;
        return [[NSAttributedString alloc] initWithString:savedContactName attributes:primaryAttributes];
    }

    NSString *groupDisplayName = [self groupDisplayNameForRecipientId:recipientId transaction:transaction];
    if (DTParamsUtils.validateString(groupDisplayName)) {
        groupDisplayName = [groupDisplayName isEqualToString:recipientId] ? [self displayIdWithRecipientId:groupDisplayName transaction:transaction] : groupDisplayName;
        return [[NSAttributedString alloc] initWithString:groupDisplayName attributes:primaryAttributes];;
    }

    NSString *_Nullable profileName = [self.profileManager profileNameForRecipientId:recipientId transaction:transaction];

    if (profileName.length > 0) {
        NSAttributedString *result =
            [[NSAttributedString alloc] initWithString:recipientId attributes:primaryAttributes];
        result = [result rtlSafeAppend:[[NSAttributedString alloc] initWithString:@" "]];
        result = [result rtlSafeAppend:[[NSAttributedString alloc] initWithString:@"~" attributes:secondaryAttributes]];
        result = [result
            rtlSafeAppend:[[NSAttributedString alloc] initWithString:profileName attributes:secondaryAttributes]];
        return [result copy];
    }

    // else fall back to recipient id
    return [[NSAttributedString alloc] initWithString:[self displayIdWithRecipientId:recipientId transaction:transaction] attributes:primaryAttributes];
}

- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId
{
    SignalAccount *signalAccount = self.signalAccountMap[recipientId];
    return signalAccount;
}

- (void)warmCacheWithSignalAccount:(SignalAccount *)signalAccount
{
    NSString *recipientId = signalAccount.recipientId;
    if (recipientId.length == 0 || self.signalAccountMap[recipientId]) {
        return;
    }
    NSMutableDictionary *map = self.signalAccountMap.mutableCopy ?: [NSMutableDictionary new];
    map[recipientId] = signalAccount;
    self.signalAccountMap = map.copy;
}

- (nullable SignalAccount *)signalAccountForRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction
{
    if (!DTParamsUtils.validateString(recipientId)) {
        return nil;
    }
    
    __block SignalAccount *signalAccount = self.signalAccountMap[recipientId];
    
    // If contact intersection hasn't completed, it might exist on disk
    // even if it doesn't exist in memory yet.
    if (!signalAccount) {
        signalAccount = [SignalAccount signalAccountWithRecipientId:recipientId transaction:transaction];
    }
    
    return signalAccount;
}

- (BOOL)hasSignalAccountForRecipientId:(NSString *)recipientId
{
    return [self signalAccountForRecipientId:recipientId] != nil;
}

- (nullable NSData *)profileImageDataForPhoneIdentifier:(nullable NSString *)identifier
{
    if (identifier.length == 0) {
        return nil;
    }
    
    return [self.profileManager profileAvatarDataForRecipientId:identifier];
}

- (NSComparisonResult)compareSignalAccount:(SignalAccount *)left withSignalAccount:(SignalAccount *)right
{
    return [self compareSignalAccount:left withSignalAccount:right transaction:nil];
}

- (NSComparisonResult)compareSignalAccount:(SignalAccount *)left
                         withSignalAccount:(SignalAccount *)right
                               transaction:(SDSAnyReadTransaction *)transaction
{
    NSString *leftName = [[self comparableNameForSignalAccount:left transaction:transaction] ows_stripped];
    NSString *rightName = [[self comparableNameForSignalAccount:right transaction:transaction] ows_stripped];
    NSComparisonResult nameComparison = [leftName localizedCaseInsensitiveCompare:rightName];
    if (nameComparison == NSOrderedSame) {
        return [left.recipientId compare:right.recipientId];
    }
    return nameComparison;
}

- (NSComparisonResult (^)(SignalAccount *left, SignalAccount *right))signalAccountComparator
{
    return ^NSComparisonResult(SignalAccount *left, SignalAccount *right) {
        NSString *leftName = [[self comparableNameForSignalAccount:left] ows_stripped];
        NSString *rightName = [[self comparableNameForSignalAccount:right] ows_stripped];
        NSComparisonResult nameComparison = [leftName localizedCaseInsensitiveCompare:rightName];
        if (nameComparison == NSOrderedSame) {
            return [left.recipientId compare:right.recipientId];
        }

        return nameComparison;
    };
}

- (BOOL)shouldSortByGivenName
{
    return [[CNContactsUserDefaults sharedDefaults] sortOrder] == CNContactSortOrderGivenName;
}

- (NSString *)comparableNameForSignalAccount:(SignalAccount *)signalAccount
{
    return [self comparableNameForSignalAccount:signalAccount transaction:nil];
}

- (NSString *)comparableNameForSignalAccount:(SignalAccount *)signalAccount
                                 transaction:(SDSAnyReadTransaction *)transaction
{
    NSString *_Nullable name;
    if (signalAccount.contact) {
        if (self.shouldSortByGivenName) {
            name = signalAccount.contact.comparableNameFirstLast.ows_stripped;
        } else {
            name = signalAccount.contact.comparableNameLastFirst.ows_stripped;
        }
        if (!DTParamsUtils.validateString(name)) {
            name = signalAccount.contact.groupDisplayName.ows_stripped;
        }
    }

    if (name.length < 1) {
        name = signalAccount.recipientId;
    }

    if ([name isEqualToString:signalAccount.recipientId]) {
        if (transaction) {
            name = [self displayIdWithRecipientId:name transaction:transaction];
        } else {
            name = [self displayIdWithRecipientId:name];
        }
    }

    return name;
}

- (void)loadInternalContactsSuccess:(void(^)(NSArray * _Nonnull contacts))successHandler
                            failure:(void (^)(NSError *_Nullable error))failureHandler
{
    [[TSAccountManager sharedInstance]
        getInternalContactSuccess:^(NSArray * _Nonnull array) {
                            OWSLogInfo(@"loadInternalContacts Success contact count = %ld", (long)array.count);
                            successHandler(array);
                        } failure:^(NSError *error){
                            OWSLogInfo(@"loadInternalContacts failure error = %@", error);
                            failureHandler(error);
                        }];
}

- (NSString * _Nullable)groupDisplayNameForRecipientId:(NSString *)recipientId {
    
    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId];
    return signalAccount.contact.groupDisplayName;
}

- (NSString * _Nullable)groupDisplayNameForRecipientId:(NSString *)recipientId
                                           transaction:(SDSAnyReadTransaction *)transaction{
    
    SignalAccount *_Nullable signalAccount = [self signalAccountForRecipientId:recipientId transaction:transaction];
    return signalAccount.contact.groupDisplayName;
}

- (FullTextSearchFinder *)finder {
    if (!_finder) {
        _finder = [FullTextSearchFinder new];
    }
    
    return _finder;
}

- (NSArray<SignalAccount *> *)bots {
    return [self.allBots sortedArrayUsingComparator:^NSComparisonResult(SignalAccount *left, SignalAccount *right) {
        return [self compareSignalAccount:left withSignalAccount:right];
    }];
}

#pragma mark - ShouldBeInitialized tag

- (BOOL)shouldHandelAccounts{
    return (CurrentAppContext().isMainApp && CurrentAppContext().isAppForegroundAndActive);
}

- (BOOL)contactsShouldBeInitialized{
    NSString *localVersion = [AppVersion shared].currentAppReleaseVersion;
    NSString *lastRequestContactsVersion = [CurrentAppContext().appUserDefaults stringForKey:kLoadedContactsKey];
    if(!lastRequestContactsVersion || ![lastRequestContactsVersion isEqualToString:localVersion] || YDBDataMigrator.shared.yapdatabaseRegister){
        return YES;
    }
    return NO;
}

- (void)clearShouldBeInitializedTag {
    [CurrentAppContext().appUserDefaults removeObjectForKey:kLoadedContactsKey];
    [CurrentAppContext().appUserDefaults synchronize];
}

- (NSString *)displayIdWithRecipientId:(NSString *)recipientId {
    // 如果没有 transaction，创建一个新的 read transaction
    __block NSString *result = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self displayIdWithRecipientId:recipientId transaction:transaction];
    }];
    return result;
}

- (NSString *)displayIdWithRecipientId:(NSString *)recipientId transaction:(SDSAnyReadTransaction *)transaction {
    // 尝试从 Contact 获取 customUid
    SignalAccount *signalAccount = [SignalAccount signalAccountWithRecipientId:recipientId transaction:transaction];
    NSString *customUid = signalAccount.contact.customUid;

    // 使用 displayUserIdWithCustomUid 方法，优先使用 customUid
    NSString *displayId = [NSString displayUserIdWithCustomUid:customUid recipientId:recipientId];
    return [NSString stringWithFormat:@"TT-%@", displayId];
}

@end
