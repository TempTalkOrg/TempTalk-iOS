//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern const NSUInteger kContactCellAvatarSize;
extern const CGFloat kContactCellAvatarTextMargin;

typedef NS_ENUM(NSUInteger, ContactCellSelectionStatus){
    ContactCellSelectionStatusNone,
    ContactCellSelectionStatusSelected,
    ContactCellSelectionStatusUnselected,
    ContactCellSelectionStatusDisabled,          // not selectable: dimmed empty square
    ContactCellSelectionStatusDisabledSelected   // already a member: gray filled square + check
};
typedef NS_ENUM(NSUInteger, UserOfSelfIconType){
    UserOfSelfIconTypeNoteToSelf,
    UserOfSelfIconTypeRealAvater,
};


@class OWSContactsManager;
@class SignalAccount;
@class TSThread;
@class DTAvatarImageView;

@interface ContactCellView : UIStackView

@property (nonatomic, nullable) NSString *accessoryMessage;
@property (nonatomic, assign) UserOfSelfIconType type;//此属性在configure方法调用之前有效
@property (nonatomic, assign) ContactCellSelectionStatus selectionStatus;
@property (nonatomic, readonly) DTAvatarImageView *avatarView;
@property (nonatomic, nullable) TSThread *thread;
@property (nonatomic, assign, getter=isNeedForwardTopic) BOOL needForwardTopic;//是否需要转发标识
@property (nonatomic, assign) BOOL isBotsUseSignature;
@property (nonatomic, assign) BOOL isMentionOtherContacts;

/// 仅用于AddToGroupViewController多个id/email输入搜索
@property (nonatomic, nullable, readonly) NSString *virtualUserId;

- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount thread:(nullable TSThread *)thread;

- (void)configureWithRecipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(TSThread *)thread contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(nullable TSThread *)thread
              signalAccount:(SignalAccount *)signalAccount
            contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(nullable TSThread *)thread
                recipientId:(NSString *)recipientId
            contactsManager:(OWSContactsManager *)contactsManager;

- (void)prepareForReuse;

- (void)setAvatar:(NSString *)recipientId displayName:(NSString *)displayName;
- (void)setUserName:(NSString *)userName isExt:(BOOL)isExt;

- (BOOL)hasAccessoryText;

- (void)setAccessoryView:(UIView *)accessoryView;

/// Weak contact (pending removal): show "Removed today" when removingToday, else
/// "Removed in X days" when days > 0, hide otherwise. Call after a configure... method.
- (void)applyWeakRemovalDays:(NSInteger)days removingToday:(BOOL)removingToday;

/// Disambiguation: show a base58 ID suffix under the name when two candidates
/// share the same display name. Call after a configure... method.
- (void)applyIdSuffix:(nullable NSString *)suffix;

@end

NS_ASSUME_NONNULL_END
