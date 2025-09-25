//
//  DTGroupUpdateMessageProcessor.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import <Foundation/Foundation.h>
#import "DTGroupNotifyEntity.h"
#import "ContactsManagerProtocol.h"

@class DTGetGroupInfoDataEntity;
@class TSGroupThread;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class DSKProtoEnvelope;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DTPersonalGroupConfigChangedNotification;
extern NSString *const DTGroupMessageExpiryConfigChangedNotification;

@interface DTGroupUpdateMessageProcessor : NSObject
+ (dispatch_queue_t)serialQueue;
//full update
- (void)requestGroupInfoWithGroupId:(NSData *)groupId
                      targetVersion:(NSInteger)targetVersion
                        needSystemMessage:(BOOL)needSystemMessage
                           generate:(BOOL)gnerate
                           envelope:(DSKProtoEnvelope *)envelope
                        transaction:(SDSAnyWriteTransaction *)transaction
                         completion:(void (^)(SDSAnyWriteTransaction *))completion;

- (void)handleGroupUpdateMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                     display:(BOOL)display
                           groupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                                 transaction:(SDSAnyWriteTransaction *)transaction;

- (TSGroupThread * _Nullable)generateOrUpdateConverationWithGroupId:(NSData *)groupId
                                        needSystemMessage:(BOOL)needSystemMessage
                                                 generate:(BOOL)gnerate
                                                 envelope:(DSKProtoEnvelope * _Nullable)envelope
                                                groupInfo:(DTGetGroupInfoDataEntity * _Nullable)groupInfo
                                        groupNotifyEntity:(DTGroupNotifyEntity * _Nullable)groupNotifyEntity
                                              transaction:(SDSAnyWriteTransaction *)transaction;

- (TSGroupThread *)generateConverationByInviteWithGroupId:(NSData *)groupId
                                                  groupInfo:(DTGetGroupInfoDataEntity * _Nullable)groupInfo
                                                transaction:(SDSAnyWriteTransaction *)transaction;

- (void)requestGroupInfoWithGroupId:(NSData *)groupId
                      targetVersion:(NSInteger)targetVersion
                  needSystemMessage:(BOOL)needSystemMessage
                           generate:(BOOL)generate
                           envelope:(DSKProtoEnvelope *)envelope
                  groupNotifyEntity:(DTGroupNotifyEntity * _Nullable)groupNotifyEntity
                        transaction:(SDSAnyWriteTransaction *)transaction
                         completion:(void (^)(SDSAnyWriteTransaction *))completion;

@end

NS_ASSUME_NONNULL_END
