//
//  DTPinnedDataSource.m
//  TTServiceKit
//
//  Created by Ethan on 2022/3/26.
//

#import "DTPinnedDataSource.h"
//
#import "DTPinnedMessageEntity.h"
#import "DTPinnedMessage.h"
//
#import "DTGroupPinAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTPinnedDataSource()

@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, strong) DTGroupPinAPI *pinAPI;

@end

@implementation DTPinnedDataSource

+ (instancetype)shared {
    
    static DTPinnedDataSource *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DTPinnedDataSource alloc] init];
    });
    return instance;
}

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create("org.difft.pin.syncpinmessage", DISPATCH_QUEUE_SERIAL);
    });
    
    return _serialQueue;
}

- (void)removeAllPinnedMessage:(NSString *)groupId {
    
    dispatch_async(self.serialQueue, ^{
        NSArray <DTPinnedMessage *> *localPinned = [self localPinnedMessagesWithGroupId:groupId];
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [localPinned enumerateObjectsUsingBlock:^(DTPinnedMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj anyRemoveWithTransaction:transaction];
            }];
        });
    });
}

- (nullable NSArray <DTPinnedMessage *> *)localPinnedMessagesWithGroupId:(nullable NSString *)groupId {
    
    if (!groupId) return nil;
    
    _groupId = groupId;
    
    NSMutableArray <DTPinnedMessage *> *pinnedMessages = @[].mutableCopy;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        
        AnyPinnedMessageFinder *finder = [[AnyPinnedMessageFinder alloc] init];
        NSError *error;
        [finder enumeratePinnedMessagesWithGroupId:self.groupId
                                       transaction:transaction
                                             error:&error
                                             block:^(DTPinnedMessage * object) {
            if (object && [object isKindOfClass:DTPinnedMessage.class]) {
                TSMessage *message = object.contentMessage;
                NSString *source = nil;
                if(message.card){
                    if ([message isKindOfClass:[TSOutgoingMessage class]]) {
                        source = [[TSAccountManager shared] localNumberWithTransaction:transaction];
                    } else {
                        source = ((TSIncomingMessage *)message).authorId;
                    }
                    message.cardUniqueId = [object.contentMessage.card generateUniqueIdWithSource:source conversationId:groupId];
                }
                [pinnedMessages addObject:object];
            }
        }];
        
    }];
    
    return pinnedMessages.copy;
}

- (DTGroupPinAPI *)pinAPI {
    
    if (!_pinAPI) {
        _pinAPI = [DTGroupPinAPI new];
    }
    return _pinAPI;
}

- (void)syncPinnedMessageWithServer:(NSString *)serverGroupId {
    
    NSArray <DTPinnedMessage *> *localPinned = [self localPinnedMessagesWithGroupId:serverGroupId];
    
    @weakify(self);
    [self.pinAPI getPinnedMessagesWithGid:serverGroupId page:1 size:100 success:^(NSArray<DTPinnedMessageEntity *> * _Nonnull serverPinnedEntities) {
        
        @strongify(self);
        NSMutableArray <NSString *> *localPinIds = [NSMutableArray new];
        NSMutableArray <NSString *> *serverPinIds = [NSMutableArray new];
        [localPinned enumerateObjectsUsingBlock:^(DTPinnedMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [localPinIds addObject:obj.pinId];
        }];
        [serverPinnedEntities enumerateObjectsUsingBlock:^(DTPinnedMessageEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!obj.pinId) return;
            [serverPinIds addObject:obj.pinId];
        }];
        
        NSSet *localPinIdSet = [NSSet setWithArray:localPinIds];
        NSSet *serverPinIdSet = [NSSet setWithArray:serverPinIds];
        
        //deletedPinIdSet: 应该删除但没删的
        NSMutableSet <NSString *> *deletedPinIdSet = [NSMutableSet setWithArray:localPinIds];
        [deletedPinIdSet minusSet:serverPinIdSet];

        //newPinIdSet: 新增
        NSMutableSet <NSString *> *newPinIdSet = [NSMutableSet setWithArray:serverPinIds];
        [newPinIdSet minusSet:localPinIdSet];
        
        // 先改为异步
        dispatch_async(self.serialQueue, ^{
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                
                [deletedPinIdSet enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                    DTPinnedMessage *shouldDeleteMessage = [DTPinnedMessage anyFetchWithUniqueId:obj transaction:transaction];
                    [shouldDeleteMessage anyRemoveWithTransaction:transaction];
                }];
                
                [serverPinnedEntities enumerateObjectsUsingBlock:^(DTPinnedMessageEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([newPinIdSet containsObject:obj.pinId]) {
                        DTPinnedMessage *pinnedMessage = [DTPinnedMessage parseBase64StringToPinnedMessage:obj groupId:obj.groupId transaction:transaction];
                        pinnedMessage.pinId = obj.pinId;
                        [pinnedMessage anyInsertWithTransaction:transaction];
                        [pinnedMessage downloadAllAttachmentWithTransaction:transaction success:nil failure:nil];
                    }
                }];
            });
        });
        
    } failure:^(NSError * _Nonnull error) {
        
    }];
    
}

@end
