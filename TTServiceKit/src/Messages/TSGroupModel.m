//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSGroupModel.h"
#import "FunctionalUtil.h"
#import "NSString+SSK.h"
#import "TSAccountManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "SignalAccount.h"
#import "Contact.h"
#import "TextSecureKitEnv.h"
#import <SignalCoreKit/NSDate+OWS.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSGroupModel ()

//@property (nullable, nonatomic) NSString *groupName;

@end

#pragma mark -

@implementation TSGroupModel

#if TARGET_OS_IOS
- (instancetype)initWithTitle:(nullable NSString *)title
                    memberIds:(NSArray<NSString *> *)memberIds
                        image:(nullable UIImage *)image
                      groupId:(NSData *)groupId
                   groupOwner:(nullable NSString *)groupOwner
                   groupAdmin:(nullable NSArray<NSString *> *)groupAdmin {
    
    _groupName              = title;
    _groupMemberIds         = [memberIds copy];
    _groupImage = image; // image is stored in DB
    _groupId                = groupId;
    _groupOwner             = groupOwner;
    _groupAdmin             = groupAdmin;
    
    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
    
    if (DTParamsUtils.validateString(localNumber)) {
        
        id<ContactsManagerProtocol> contactsManager = TextSecureKitEnv.sharedEnv.contactsManager;
        __block SignalAccount *localAccount = [contactsManager signalAccountForRecipientId:localNumber];
        
        __block NSNumber * globalNotification = nil;
        if (!localAccount) {
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
                localAccount = [SignalAccount signalAccountWithRecipientId:localNumber transaction:transaction];
                Contact *contact = localAccount.contact;
                globalNotification = contact.privateConfigs.globalNotification;
            }];
        }        
        
        DTGlobalNotificationType type = [self getGlobalNotificationTypeWith:globalNotification];

        TSGroupNotificationType groupNotificationType = [self convertGlobalNotificationTypeToGroupNotificationTypeWith:type];
        _notificationType = @(groupNotificationType);
    }
    
    return self;
}

- (instancetype)initWithTitle:(nullable NSString *)title
                    memberIds:(NSArray<NSString *> *)memberIds
                        image:(nullable UIImage *)image
                      groupId:(NSData *)groupId
                   groupOwner:(nullable NSString *)groupOwner
                   groupAdmin:(nullable NSArray<NSString *> *)groupAdmin
                  transaction:(SDSAnyReadTransaction *)transaction {
    
    _groupName              = title;
    _groupMemberIds         = [memberIds copy];
    _groupImage = image; // image is stored in DB
    _groupId                = groupId;
    _groupOwner             = groupOwner;
    _groupAdmin             = groupAdmin;
    
    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
    if (localNumber) {
        id<ContactsManagerProtocol> contactsManager = TextSecureKitEnv.sharedEnv.contactsManager;
        SignalAccount *localAccount = [contactsManager signalAccountForRecipientId:localNumber];
        
        if (!localAccount) {
            localAccount = [contactsManager signalAccountForRecipientId:localNumber transaction:transaction];
        }
        
        Contact *localContact = localAccount.contact;
        NSNumber *globalNotification = localContact.privateConfigs.globalNotification;
        DTGlobalNotificationType type = [self getGlobalNotificationTypeWith:globalNotification];
        TSGroupNotificationType groupNotificationType = [self convertGlobalNotificationTypeToGroupNotificationTypeWith:type];
        _notificationType = @(groupNotificationType);
    }

    return self;
}

- (DTGlobalNotificationType)defaultNotificationType {
    __block NSNumber * globalNotification = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
        SignalAccount *account = [SignalAccount signalAccountWithRecipientId:[TSAccountManager sharedInstance].localNumber transaction:transation];
        Contact *contact = account.contact;
        globalNotification = contact.privateConfigs.globalNotification;
    }];
    DTGlobalNotificationType type = [self getGlobalNotificationTypeWith:globalNotification];
    return type;
}

- (DTGlobalNotificationType)getGlobalNotificationTypeWith:(NSNumber *)globalNotification {
    if ([globalNotification intValue] == 0 ) {
        return DTGlobalNotificationTypeALL;
    }else if([globalNotification intValue] == 1 ){
        return DTGlobalNotificationTypeMENTION;
    }else if([globalNotification intValue] == 2 ){
        return DTGlobalNotificationTypeOFF;
    }else {
        return DTGlobalNotificationTypeALL;
    }
}

- (TSGroupNotificationType)convertGlobalNotificationTypeToGroupNotificationTypeWith:(DTGlobalNotificationType)type {
    switch (type) {
        case DTGlobalNotificationTypeALL: return TSGroupNotificationTypeAll;
        case DTGlobalNotificationTypeMENTION: return TSGroupNotificationTypeAtMe;
        case DTGlobalNotificationTypeOFF: return TSGroupNotificationTypeOff;
        default: return TSGroupNotificationTypeAll;
    }
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    // Occasionally seeing this as nil in legacy data,
    // which causes crashes.
    if (_groupMemberIds == nil) {
        _groupMemberIds = [NSArray new];
    }
    
    if (_notificationType == nil ) {
        _notificationType = @(TSGroupNotificationTypeAtMe);
    }

    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (!other || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToGroupModel:other];
}

- (BOOL)isEqualToGroupModel:(TSGroupModel *)other {
    
    if (![self isEqualToGroupBaseInfo:other]) {
        return NO;
    }
    
    NSMutableArray *compareMyGroupMemberIds = [NSMutableArray arrayWithArray:_groupMemberIds];
    [compareMyGroupMemberIds removeObjectsInArray:other.groupMemberIds];
    if ([compareMyGroupMemberIds count] > 0) {
        return NO;
    }
    return YES;
}

- (BOOL)isEqualToGroupBaseInfo:(TSGroupModel *)other {
    
    if (self == other)
        return YES;
    if (![_groupId isEqualToData:other.groupId]) {
        return NO;
    }
    if (![_groupName isEqual:other.groupName]) {
        return NO;
    }
    if (![_remindCycle isEqual:other.remindCycle]) {
        return NO;
    }
    if (![_invitationRule isEqual:other.invitationRule]) {
        return NO;
    }
    if (_anyoneRemove != other.anyoneRemove) {
        return NO;
    }
    if (_rejoin != other.rejoin) {
        return NO;
    }
    if (![_messageExpiry isEqualToNumber:other.messageExpiry]) {
        return NO;
    }
    if (_ext != other.ext) {
        return NO;
    }
    if (_publishRule != other.publishRule) {
        return NO;
    }
    if (_privateChat != other.privateChat) {
        return NO;
    }
    
    if (_anyoneChangeName != other.anyoneChangeName) {
        return NO;
    }
    
    if (_anyoneChangeAutoClear != other.anyoneChangeAutoClear) {
        return NO;
    }
    
    if (_autoClear != other.autoClear) {
        return NO;
    }
    
    if (_privilegeConfidential != other.privilegeConfidential) {
        return NO;
    }
    
    return YES;
}

/// 当前用户是否可以在当前群组发言
/// - Parameter thread: 会话
- (BOOL)isSelfCanSpeak {
    
    if (!self.publishRule) {
        return true;
    }
    
    if ([self.publishRule intValue] == 1 && ![self isSelfGroupOwner] && ![self isSelfGroupModerator]) {
        return false;
    }
    if([self.publishRule intValue] == 0 && ![self isSelfGroupOwner]){
        return false;
    }
    return true;
}

#endif

- (nullable NSString *)groupName
{
    return _groupName.filterStringForDisplay;
}

- (BOOL)isSelfGroupOwner {
    NSString *localNumber = [TSAccountManager localNumber];
    return [localNumber isEqualToString:self.groupOwner];
}

- (BOOL)isSelfGroupModerator {
    NSString *localNumber = [TSAccountManager localNumber];
    return [self.groupAdmin containsObject:localNumber];
}

- (DTGroupRAPIDRole)rapidRoleFor:(NSString *)memberId {
    
    if ([self.recommendRoles containsObject:memberId]) {
        return DTGroupRAPIDRoleRecommend;
    }
    if ([self.agreeRoles containsObject:memberId]) {
        return DTGroupRAPIDRoleAgree;
    }
    if ([self.performRoles containsObject:memberId]) {
        return DTGroupRAPIDRolePerform;
    }
    if ([self.inputRoles containsObject:memberId]) {
        return DTGroupRAPIDRoleInput;
    }
    if ([self.deciderRoles containsObject:memberId]) {
        return DTGroupRAPIDRoleDecider;
    }
    if ([self.observerRoles containsObject:memberId]) {
        return DTGroupRAPIDRoleObserver;
    }
    
    return DTGroupRAPIDRoleNone;
}

- (void)addRapidRole:(DTGroupRAPIDRole)rapidRole memberId:(NSString *)memberId {
    
    [self removeRapidRole:memberId];
    
    switch (rapidRole) {
        case DTGroupRAPIDRoleRecommend:
            self.recommendRoles = [self newRapidRolesFromOldRapidRoles:self.recommendRoles addMember:memberId];
            break;
        case DTGroupRAPIDRoleAgree:
            self.agreeRoles = [self newRapidRolesFromOldRapidRoles:self.agreeRoles addMember:memberId];
            break;
        case DTGroupRAPIDRolePerform:
            self.performRoles = [self newRapidRolesFromOldRapidRoles:self.performRoles addMember:memberId];
            break;
        case DTGroupRAPIDRoleInput:
            self.inputRoles = [self newRapidRolesFromOldRapidRoles:self.inputRoles addMember:memberId];
            break;
        case DTGroupRAPIDRoleDecider:
            self.deciderRoles = [self newRapidRolesFromOldRapidRoles:self.deciderRoles addMember:memberId];
            break;
        case DTGroupRAPIDRoleObserver:
            self.observerRoles = [self newRapidRolesFromOldRapidRoles:self.observerRoles addMember:memberId];
            break;
        case DTGroupRAPIDRoleNone:
        default:
            break;
    }
    
}

- (void)removeRapidRole:(NSString *)memberId {
        
    self.recommendRoles = [self newRapidRolesFromOldRapidRoles:self.recommendRoles removeMember:memberId];
    self.agreeRoles = [self newRapidRolesFromOldRapidRoles:self.agreeRoles removeMember:memberId];
    self.performRoles = [self newRapidRolesFromOldRapidRoles:self.performRoles removeMember:memberId];
    self.inputRoles = [self newRapidRolesFromOldRapidRoles:self.inputRoles removeMember:memberId];
    self.deciderRoles = [self newRapidRolesFromOldRapidRoles:self.deciderRoles removeMember:memberId];
    self.observerRoles = [self newRapidRolesFromOldRapidRoles:self.observerRoles removeMember:memberId];
}

- (NSArray *)newRapidRolesFromOldRapidRoles:(NSArray *)oldRoles addMember:(NSString *)memberId {
  
    NSMutableArray *newRoles = oldRoles ? [oldRoles mutableCopy] : @[].mutableCopy;
    if (![oldRoles containsObject:memberId]) {
        [newRoles addObject:memberId];
    }

    return [newRoles copy];
}

- (NSArray *)newRapidRolesFromOldRapidRoles:(NSArray *)oldRoles removeMember:(NSString *)memberId {
  
    NSMutableArray *newRoles = oldRoles ? [oldRoles mutableCopy] : @[].mutableCopy;
    if ([oldRoles containsObject:memberId]) {
        [newRoles removeObject:memberId];
    }

    return [newRoles copy];
}


@end

NS_ASSUME_NONNULL_END
