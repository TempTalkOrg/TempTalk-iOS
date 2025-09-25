//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ContactTableViewCell.h"
#import "ContactCellView.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTMessaging/Theme.h>
#import "Environment.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContactTableViewCell ()

@property (nonatomic,strong,readwrite) ContactCellView *cellView;
@property (nonatomic,strong,readwrite) SignalAccount *signalAccount;
@property (nonatomic,strong,readwrite) TSThread *thread;
@end

#pragma mark -

@implementation ContactTableViewCell

- (void)setSelectionStatus:(ContactCellSelectionStatus)selectionStatus{
    self.cellView.selectionStatus = selectionStatus;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self configure];
    }
    return self;
}

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self.class);
}

- (void)setAccessoryView:(nullable UIView *)accessoryView
{
    OWSFailDebug(@"%@ use ows_setAccessoryView instead.", self.logTag);
}

- (void)configure
{
    OWSAssertDebug(!self.cellView);

    self.backgroundColor = Theme.tableCellBackgroundColor;
    self.contentView.backgroundColor = Theme.tableCellBackgroundColor;
    self.selectedBackgroundView = ({
        UIView *selectedBackgroundView = [UIView new];
        selectedBackgroundView.backgroundColor = Theme.tableCellBackgroundColor;
        selectedBackgroundView;
    });
    
    self.preservesSuperviewLayoutMargins = YES;
    self.contentView.preservesSuperviewLayoutMargins = YES;

    self.cellView = [ContactCellView new];
    [self.contentView addSubview:self.cellView];
    [self.cellView autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [self.cellView autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:16];
    [self.cellView autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:16];
    self.cellView.userInteractionEnabled = NO;
}

- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount{
    [self configureWithSpecialAccount:signalAccount thread:nil];
}

- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount thread:(nullable TSThread *)thread {
    self.signalAccount = signalAccount;
    _thread = thread;
    [self.cellView configureWithSpecialAccount:signalAccount thread:thread];
    [self layoutSubviews];
}

- (void)configureWithSignalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager
{
    [self configureWithThread:nil signalAccount:signalAccount contactsManager:contactsManager];
}

- (void)configureWithRecipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager {
    [self configureWithThread:nil recipientId:recipientId contactsManager:contactsManager];
}

- (void)configureWithThread:(nullable TSThread *)thread recipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager {
    
    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
    self.signalAccount = account;
    _thread = thread;
    [self.cellView configureWithThread:thread recipientId:recipientId contactsManager:contactsManager];

    // Force layout, since imageView isn't being initally rendered on App Store optimized build.
    [self layoutSubviews];
}

- (void)configureWithThread:(nullable TSThread *)thread signalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager {
    self.signalAccount = signalAccount;
    _thread = thread;
    [self.cellView configureWithThread:thread recipientId:signalAccount.recipientId contactsManager:contactsManager];
}

- (void)configureWithThread:(TSThread *)thread contactsManager:(OWSContactsManager *)contactsManager
{
    if ([thread isKindOfClass:TSContactThread.class]) {
        TSContactThread *tmpThread = (TSContactThread *)thread;
        self.signalAccount = [contactsManager signalAccountForRecipientId:tmpThread.contactIdentifier];
    }
    _thread = thread;
    OWSAssertDebug(thread);
    [self.cellView configureWithThread:thread contactsManager:contactsManager];
    
    // Force layout, since imageView isn't being initally rendered on App Store optimized build.
    [self layoutSubviews];
}

- (void)setAccessoryMessage:(nullable NSString *)accessoryMessage
{
    OWSAssertDebug(self.cellView);

    self.accessoryType = UITableViewCellAccessoryNone;
    self.cellView.accessoryMessage = accessoryMessage;
}

- (void)setAccessoryType:(UITableViewCellAccessoryType)accessoryType {
    [super setAccessoryType:accessoryType];
    self.cellView.accessoryMessage = nil;
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    [self.cellView prepareForReuse];
    self.backgroundColor = Theme.tableCellBackgroundColor;
    self.contentView.backgroundColor = Theme.tableCellBackgroundColor;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.selected = NO;
}

- (BOOL)hasAccessoryText
{
    return [self.cellView hasAccessoryText];
}

- (void)ows_setAccessoryView:(UIView *)accessoryView
{
    return [self.cellView setAccessoryView:accessoryView];
}

@end

NS_ASSUME_NONNULL_END
