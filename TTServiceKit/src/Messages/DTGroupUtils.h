//
//  DTGroupUtils.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/29.
//

#import <Foundation/Foundation.h>
#import "DTTranslateProcessor.h"

@class TSMessage;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class TSThread;
@class TSGroupThread;
@class DTPinnedMessage;
@class TSGroupModel;
@class DTGroupNotifyEntity;
@class DTGroupBaseInfoEntity;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DTGroupPeriodicRemindNotification;
extern NSString *const DTGroupMemberRapidRoleChangedNotification;
extern NSString *const DTGroupExternalChangedNotification;
extern NSString *const DTGroupBaseInfoChangedNotification;
extern NSString *const DTRapidRolesKey;

@interface DTGroupUtils : NSObject

// NOTICE: TSGroupModel 如有新增数据需要再次构造方法中进行同步
+ (TSGroupModel *)createNewGroupModelWithGroupModel:(TSGroupModel *)groupModel;

+ (NSString *)getMemberChangedInfoStringWithJoinedMemberIds:(NSArray * _Nullable)joinedMemberIds
                                           removedMemberIds:(NSArray * _Nullable)removedMemberIds
                                              leftMemberIds:(NSArray * _Nullable)leftMemberIds
                                  shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                                transaction:(SDSAnyReadTransaction *)transaction;

+ (NSString *)getBaseInfoStringWithOldGroupModel:(TSGroupModel * _Nullable)oldGroupModel
                                        newModel:(TSGroupModel * _Nullable)newModel
                                          source:(NSString *)source
                       shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting;

+ (NSString *)getMemberChangedInfoStringWithJoinedMemberIds:(NSArray *_Nullable)joinedMemberIds
                                           removedMemberIds:(NSArray *_Nullable)removedMemberIds
                                              leftMemberIds:(NSArray *_Nullable)leftMemberIds
                                            updateMemberIds:(NSArray *_Nullable)updateMemberIds
                                               oldGroupModel:(TSGroupModel *_Nullable)oldGroupModel
                                               newGroupModel:(TSGroupModel *_Nullable)newGroupModel
                                  shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                                transaction:(SDSAnyReadTransaction *)transaction;

//新增和删除群成员的信息
+ (NSString *)getMemberChangedInfoStringWithAddedAdminIds:(NSArray *_Nullable)addedAdminIds//添加的管理员
                                               removedIds:(NSArray *_Nullable)removedAdminsIds
                                              transaction:(SDSAnyReadTransaction *)transaction;

//新增和删除群成员的信息
+ (NSString *)getMemberChangedInfoStringWithTransferOwer:(NSString *_Nullable)receptid
                               shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting//转让群主
                                             transaction:(SDSAnyReadTransaction *)transaction;//转让群主

+ (NSString *)getTranslateSettingChangedInfoStringWithUserChangeType:(DTTranslateMessageType)type;

+ (NSAttributedString *)getPinnedMessageInfoWithSource:(NSString *)source
                                               message:(TSMessage *)message
                                           transaction:(SDSAnyReadTransaction *)transaction;

//full update info
+ (NSString *)getFullUpdateStringWithOldGroupModel:(TSGroupModel * _Nullable)oldGroupModel
                                            whoJoined:(NSMutableSet * _Nullable)whoJoined
                                          newModel:(TSGroupModel * _Nullable)newModel
                         shouldAffectThreadSorting:(BOOL *)shouldAffectThreadSorting
                                       transaction:(SDSAnyReadTransaction *)transaction;

///同步个人群列表基本消息
+ (void)syncMyGroupsBaseInfoSuccess:(void(^)(void))success
                            failure:(void(^)(NSError *error))failure;
+ (BOOL)isChangedArchiveMessageStringWithOldGroupModel:(TSGroupModel *)oldGroupModel
                                              newModel:(TSGroupModel *)newModel;

+ (void)postRapidRoleChangeNotificationWithGroupModel:(TSGroupModel *)groupModel
                                      targedMemberIds:(NSArray <NSString *> *)targetMemberIds;
+ (void)postExternalChangeNotificationWithTargetIds:(NSDictionary <NSString *, NSNumber *> *)targetIds;

+ (void)postGroupBaseInfoChangeWith:(DTGroupBaseInfoEntity *)baseInfo
                             remove:(BOOL)remove;

+ (void)sendPinSystemMessageWithSource:(NSString *)source
                       serverTimestamp:(uint64_t)serverTimestamp
                                thread:(TSThread *)thread
                         pinnedMessage:(DTPinnedMessage *)pinnedMessage
                           transaction:(SDSAnyWriteTransaction *)transaction;

+ (void)sendGroupReminderMessageWithSource:(NSString *)source
                           serverTimestamp:(uint64_t)serverTimestamp
                                 isChanged:(BOOL)isChanged
                                    thread:(TSThread *)thread
                               remindCycle:(NSString *)remindCycle
                               transaction:(SDSAnyWriteTransaction *)transaction;

+ (void)sendMeetingReminderInfoMessageGroupNotifyEntity:(DTGroupNotifyEntity *)groupNotifyEntity
                                        serverTimestamp:(uint64_t)serverTimestamp
                                                 thread:(TSGroupThread *)newGroupThread
                                            transaction:(SDSAnyWriteTransaction *)transaction;

/// 移除群成员系统消息
/// - Parameters:
///   - inviteCode: rejoin时使用
///   - updateInfo: getMemberChangedInfoStringWithJoinedMemberIds方法返回的移除消息
///   - thread: thread
///   - transaction: transaction
+ (void)sendGroupRejoinMessageWithInviteCode:(NSString *)inviteCode
                                  updateInfo:(NSString *)updateInfo
                                      thread:(TSGroupThread *)thread
                                 transaction:(SDSAnyWriteTransaction *)transaction;

+ (void)sendRAPIDRoleChangedMessageWithOperatorId:(NSString *)operatorId
                                    otherMemberId:(NSString *)otherMemberId
                                        rapidRole:(NSString *)rapidRole
                                  serverTimestamp:(uint64_t)serverTimestamp
                                           thread:(TSThread *)thread
                                      transaction:(SDSAnyWriteTransaction *)transaction;

+ (UIColor *)attributeInfoMessageHighlightColor;
+ (NSString *)weekdayWithRemindWeekDay:(NSInteger)remindWeekDay;
+ (NSString *)monthDayWithRemindMonthDay:(NSInteger)remindMonthDay;

+ (void)addGroupBaseInfo:(DTGroupBaseInfoEntity *)baseInfo
             transaction:(SDSAnyWriteTransaction *)transaction;
+ (void)removeGroupBaseInfoWithGid:(NSString *)gid
                       transaction:(SDSAnyWriteTransaction *)transaction;
+ (void)upsertGroupBaseInfo:(DTGroupBaseInfoEntity *)baseInfo
                transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
