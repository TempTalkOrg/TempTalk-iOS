//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ContactsManagerProtocol.h"
#import <Mantle/Mantle.h>
#import "DTGroupMemberEntity.h"

@class SDSAnyReadTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface TSGroupModel : MTLModel

@property (nonatomic) NSArray<NSString *> *groupMemberIds;
@property (nullable, nonatomic) NSString *groupName;
@property (nonatomic) NSData *groupId;

@property (nonatomic, copy) NSString *groupOwner;
@property (nonatomic) NSArray<NSString *> *groupAdmin;
@property (nonatomic, strong) NSNumber *notificationType;
@property (nonatomic, strong) NSNumber *useGlobal;//组的全局配置开关属性
@property (nonatomic, strong) NSNumber *messageExpiry; // 群消息过期时间
@property (nonatomic, strong) NSNumber *invitationRule; // 2:全员允许, 1:管理员和群主, 0:群主
/// 是否允许任何人移出群成员 tt无效，默认只有管理员可以
@property (nonatomic, assign) BOOL anyoneRemove;
/// 被移除后是否允许重新加入
@property (nonatomic, assign) BOOL rejoin;

@property (nonatomic, assign) BOOL linkInviteSwitch;

///0是仅群主，1群主和管理员可发言， 2是所有人可发言（普通消息（除了reaction）和语音）
@property (nonatomic, strong) NSNumber *publishRule;

@property (nonatomic, assign) BOOL anyoneChangeName;
@property (nonatomic, assign) BOOL anyoneChangeAutoClear;
@property (nonatomic, assign) BOOL autoClear;
@property (nonatomic, assign) BOOL privilegeConfidential;
/// 是否开启允许私聊
@property (nonatomic, assign) BOOL privateChat;
/// 外部成员数量
//@property (nonatomic, assign) NSUInteger externalMemberCount;

/// 是否有外部成员
@property (nonatomic, assign, getter=isExt) BOOL ext;

/// weekly | monthly | none
@property (nonatomic, copy) NSString *remindCycle;

/// RAPID roles
@property (nonatomic, strong) NSArray <NSString *> *recommendRoles;
@property (nonatomic, strong) NSArray <NSString *> *agreeRoles;
@property (nonatomic, strong) NSArray <NSString *> *performRoles;
@property (nonatomic, strong) NSArray <NSString *> *inputRoles;
@property (nonatomic, strong) NSArray <NSString *> *deciderRoles;
@property (nonatomic, strong) NSArray <NSString *> *observerRoles;

@property (nonatomic, assign) NSInteger version;

#if TARGET_OS_IOS
@property (nullable, nonatomic, strong) UIImage *groupImage;
@property (nonatomic, assign) NSInteger groupAvatarVersion;

- (instancetype)initWithTitle:(nullable NSString *)title
                    memberIds:(NSArray<NSString *> *)memberIds
                        image:(nullable UIImage *)image
                      groupId:(NSData *)groupId
                   groupOwner:(nullable NSString *)groupOwner
                   groupAdmin:(nullable NSArray<NSString *> *)groupAdmin;

- (instancetype)initWithTitle:(nullable NSString *)title
                    memberIds:(NSArray<NSString *> *)memberIds
                        image:(nullable UIImage *)image
                      groupId:(NSData *)groupId
                   groupOwner:(nullable NSString *)groupOwner
                   groupAdmin:(nullable NSArray<NSString *> *)groupAdmin
                  transaction:(SDSAnyReadTransaction *)transaction;

- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToGroupModel:(TSGroupModel *)model;
- (BOOL)isEqualToGroupBaseInfo:(TSGroupModel *)other;

//- (NSString *)getInfoStringAboutUpdateTo:(TSGroupModel *)model contactsManager:(id<ContactsManagerProtocol>)contactsManager;
#endif

- (BOOL)isSelfGroupOwner;
- (BOOL)isSelfGroupModerator;
///自己是否可
- (BOOL)isSelfCanSpeak;

- (DTGroupRAPIDRole)rapidRoleFor:(NSString *)memberId;
- (void)removeRapidRole:(NSString *)memberId;
- (void)addRapidRole:(DTGroupRAPIDRole)rapidRole memberId:(NSString *)memberId;

@end

NS_ASSUME_NONNULL_END
