//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContactsManager.h"
#import "ContactCellView.h"

NS_ASSUME_NONNULL_BEGIN

@class ContactCellView;
@class OWSContactsManager;
@class SignalAccount;
@class TSThread;

@interface ContactTableViewCell : UITableViewCell

@property (nonatomic, readonly) ContactCellView *cellView;
@property (nonatomic, readonly) SignalAccount *signalAccount;
@property (nonatomic, readonly) TSThread *thread;
@property (nonatomic, assign) ContactCellSelectionStatus selectionStatus;

+ (NSString *)reuseIdentifier;

- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount;
- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount thread:(nullable TSThread *)thread;

- (void)configureWithSignalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithRecipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(TSThread *)thread contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(nullable TSThread *)thread
              signalAccount:(SignalAccount *)signalAccount
            contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(nullable TSThread *)thread
                recipientId:(NSString *)recipientId
            contactsManager:(OWSContactsManager *)contactsManager;

// This method should be called _before_ the configure... methods.
- (void)setAccessoryMessage:(nullable NSString *)accessoryMessage;

- (BOOL)hasAccessoryText;

- (void)ows_setAccessoryView:(UIView *)accessoryView;


@end

NS_ASSUME_NONNULL_END
