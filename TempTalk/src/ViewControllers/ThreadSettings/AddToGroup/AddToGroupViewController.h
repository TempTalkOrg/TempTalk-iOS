//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SelectRecipientViewController.h"
#import "OWSConversationSettingsViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AddToGroupMode) {
    AddToGroupMode_Default = 0,
    AddToGroupMode_DataBack
};

typedef NS_ENUM(NSUInteger, DTAddToGroupStyle) {
    DTAddToGroupStyleDefault = 0,//默认风格
    DTAddToGroupStyleShowSelectedPerson//选择之后展示选中人员
};

@protocol AddToGroupViewControllerDelegate <NSObject>

@optional
- (void)recipientIdWasAdded:(NSString *)recipientId;
- (void)recipientIdsWasAdded:(NSSet <NSString *> *)recipientIds;
- (void)recipientIdsWasAddedWithArr:(NSArray <NSString *> *)recipientIdsArr;
- (BOOL)isRecipientGroupMember:(NSString *)recipientId;
/// meeting 中是否可以邀请指定人
- (BOOL)canMeetingMemberBeSelected:(NSString *)recipientId;
/// meeting 中是否可以邀请指定人，并给出 toast 提示
- (BOOL)checkShouldToastCannnotBeSelected:(NSString *)recipientId;

/// Description
/// - Parameters:
///   - recipientIds: 通讯录用户recipientIds
///   - userIdOrEmails: 非本地通讯录recipientIds+email
- (void)recipientIdsWasAdded:(NSSet <NSString *> *)recipientIds
       virtualUserIdOrEmails:(NSSet <NSString *> *)userIdOrEmails;
- (BOOL)customUserConditions:(NSString *)userIdOrEmail;

- (BOOL)shouldHideLocalNumber;

@end

@class TSGroupThread;
#pragma mark -

@interface AddToGroupViewController : SelectRecipientViewController

// This property _must_ be set before the view is presented.

@property (nonatomic, weak) id<OWSConversationSettingsViewDelegate> conversationSettingsViewDelegate;

@property (nonatomic, weak) id<AddToGroupViewControllerDelegate> addToGroupDelegate;

@property (nonatomic) AddToGroupMode mode;

@property (nonatomic) BOOL hideContacts;

@property(nonatomic,assign) DTAddToGroupStyle addToGroupStyle;

@end

NS_ASSUME_NONNULL_END
