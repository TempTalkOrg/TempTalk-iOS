//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTMessaging/OWSViewController.h>
#import <TTMessaging/OWSTableViewController.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SelectRecipientFrom) {
    SelectRecipientFrom_Default = 0,
    SelectRecipientFrom_Meeting,
};

@class SignalAccount;
@class TSGroupThread;

@protocol SelectRecipientViewControllerDelegate <NSObject>

- (NSString *)phoneNumberSectionTitle;
- (NSString *)phoneNumberButtonText;
- (NSString *)contactsSectionTitle;

- (void)phoneNumberWasSelected:(NSString *)phoneNumber;

- (BOOL)canSignalAccountBeSelected:(SignalAccount *)signalAccount;

//选中用户
- (void)signalAccountWasSelected:(SignalAccount *)signalAccount;

- (void)signalAccountWasSelected:(SignalAccount *)signalAccount withIndexPath:(NSIndexPath *)indexPath;

- (nullable NSString *)accessoryMessageForSignalAccount:(SignalAccount *)signalAccount;

- (BOOL)shouldHideLocalNumber;

- (BOOL)shouldHideContacts;

- (BOOL)shouldValidatePhoneNumbers;

@optional

- (BOOL)canMeetingMemberBeSelected:(SignalAccount *)signalAccount;
//取消选中的用户
- (void)signalAccountWasUnSelected:(SignalAccount *)signalAccount;
- (void)signalAccountWasUnSelected:(SignalAccount *)signalAccount withIndexPath:(NSIndexPath *)indexPath;

- (BOOL)customUserConditions:(NSString *)userIdOrEmail;
- (BOOL)canUserIdOrEmailBeSelected:(NSString *)userIdOrEmail;
- (void)userIdOrEmailWasSelected:(NSString *)userIdOrEmail;
- (void)userIdOrEmailWasUnselected:(NSString *)userIdOrEmail;

@end

#pragma mark -

@class ContactsViewHelper;

@interface SelectRecipientViewController : OWSViewController <OWSTableViewControllerDelegate>

@property (nonatomic, weak) id<SelectRecipientViewControllerDelegate> delegate;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;

@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;

@property (nonatomic) BOOL isPresentedInNavigationController;

@property (nonatomic, assign) SelectRecipientFrom from;

@property (nonatomic, strong) TSGroupThread *thread;

@end

NS_ASSUME_NONNULL_END
