//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ContactCellView.h"
#import "OWSContactAvatarBuilder.h"
#import "OWSContactsManager.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSThread.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import "DTConversationNameView.h"
#import "JSQMessagesAvatarImageFactory.h"

NS_ASSUME_NONNULL_BEGIN

const NSUInteger kContactCellAvatarSize = 48;
const CGFloat kContactCellAvatarTextMargin = 12;

@interface ContactCellView ()

@property (nonatomic) UIImageView *selectionImageView;
@property (nonatomic) DTConversationNameView *nameView;
@property (nonatomic) DTAvatarImageView *avatarView;
//@property (nonatomic) UIView *avatarContentView;
//@property (nonatomic) UILabel *subtitleLabel;
@property (nonatomic) UILabel *accessoryLabel;
@property (nonatomic) UIStackView *nameContainerView;
@property (nonatomic) UIView *accessoryViewContainer;

@property (nonatomic) OWSContactsManager *contactsManager;
@property (nonatomic) NSString *recipientId;
@property (nonatomic, strong) UIView *topicAccessoryView;
@end

#pragma mark -

@implementation ContactCellView

- (instancetype)init
{
    if (self = [super init]) {
        [self configure];
        self.selectionStatus = ContactCellSelectionStatusNone;
        self.type = UserOfSelfIconTypeNoteToSelf;
    }
    return self;
}

- (void)setSelectionStatus:(ContactCellSelectionStatus)selectionStatus{
    _selectionStatus = selectionStatus;
    switch (_selectionStatus) {
        case ContactCellSelectionStatusNone:
        {
            self.selectionImageView.hidden = YES;
        }
            break;
        case ContactCellSelectionStatusSelected:
        {
            self.selectionImageView.hidden = NO;
            self.selectionImageView.image = [UIImage imageNamed:@"icon_selected"];
        }
            break;
        case ContactCellSelectionStatusUnselected:
        {
            self.selectionImageView.hidden = NO;
            self.selectionImageView.image = [UIImage imageNamed:@"icon_unselected"];
        }
            break;
            
        default:
            break;
    }
}

- (void)configure
{
    OWSAssertDebug(!self.nameView);
    
    self.layoutMargins = UIEdgeInsetsZero;
    
    self.selectionImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon_unselected"]];
    
    _avatarView = [DTAvatarImageView new];
    _avatarView.avatarImageView.backgroundColor = [UIColor colorWithRGBHex:0x3784f7];
    
    self.nameView = [DTConversationNameView new];
    self.nameView.nameColor = Theme.primaryTextColor;
    [self.nameView setCompressionResistanceHigh];

    self.accessoryLabel = [[UILabel alloc] init];
    self.accessoryLabel.textAlignment = NSTextAlignmentRight;
    self.accessoryLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.f];

    self.accessoryViewContainer = [UIView containerView];

    self.nameContainerView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameView
    ]];
    self.nameContainerView.axis = UILayoutConstraintAxisVertical;
    self.nameContainerView.spacing = 3;
    self.nameContainerView.alignment = UIStackViewAlignmentLeading;
    
    [self.nameContainerView setContentHuggingHorizontalLow];
    [self.accessoryViewContainer setContentHuggingHorizontalHigh];

    self.axis = UILayoutConstraintAxisHorizontal;
    self.spacing = kContactCellAvatarTextMargin;
    self.alignment = UIStackViewAlignmentCenter;
    [self addArrangedSubview:self.selectionImageView];
    [self addArrangedSubview:self.avatarView];
    [self addArrangedSubview:self.nameContainerView];
    [self addArrangedSubview:self.accessoryViewContainer];
    [_avatarView autoSetDimensionsToSize:CGSizeMake(kContactCellAvatarSize, kContactCellAvatarSize)];

    [self configureFonts];
}

- (void)setNeedForwardTopic:(BOOL)needForwardTopic {
    if (self.topicAccessoryView && [self.accessoryViewContainer.subviews containsObject:self.topicAccessoryView]) {
        [self.topicAccessoryView removeFromSuperview];
        [self.topicAccessoryView removeAllSubviews];
    }
    
    UILabel *topicAccessoryLabel = [UILabel new];
    UIImageView *topicAccessoryImage = [UIImageView new];
    UIImage *image =  [[UIImage imageNamed:@"ic_forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    topicAccessoryImage.image = image;
    topicAccessoryImage.tintColor = Theme.secondaryTextAndIconColor;
    topicAccessoryLabel.text = @"Topic";
    topicAccessoryLabel.textColor = Theme.primaryTextColor;
    
    [_topicAccessoryView addSubview:topicAccessoryImage];
    [_topicAccessoryView addSubview:topicAccessoryLabel];
    
    [topicAccessoryImage autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:_topicAccessoryView];
    [topicAccessoryImage autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:_topicAccessoryView];
    [topicAccessoryImage autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:_topicAccessoryView];
    
    [topicAccessoryLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:topicAccessoryImage withOffset:5];
    [topicAccessoryLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:_topicAccessoryView];
    [topicAccessoryLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:_topicAccessoryView];
    [topicAccessoryLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:_topicAccessoryView];
    
    if (needForwardTopic && ![self.accessoryViewContainer.subviews containsObject:self.topicAccessoryView]) {
        [self.accessoryViewContainer addSubview:self.topicAccessoryView];
        [self.topicAccessoryView autoPinEdgesToSuperviewEdges];
    } else {
        [self.topicAccessoryView removeFromSuperview];
        [self.topicAccessoryView removeAllSubviews];
    }
}


- (UIView *)topicAccessoryView {
    if (!_topicAccessoryView) {
        _topicAccessoryView = [UIView new];
    }
    return _topicAccessoryView;
}

- (void)configureFonts
{
    self.nameView.nameFont = [UIFont ows_dynamicTypeBodyFont];
    self.accessoryLabel.font = [UIFont ows_semiboldFontWithSize:13.f];
}


- (void)configureWithSpecialAccount:(SignalAccount *)signalAccount thread:(nullable TSThread *)thread {
    OWSAssertDebug(signalAccount);

    // Update fonts to reflect changes to dynamic type.
    [self configureFonts];
    
    NSDictionary<NSString *, id> *normalFontAttributes =
        @{ NSFontAttributeName : self.nameView.nameFont, NSForegroundColorAttributeName : Theme.primaryTextColor };
    self.nameView.attributeName = [[NSAttributedString alloc] initWithString:[signalAccount contactFullName] attributes:normalFontAttributes];
    
    NSUInteger diameter = kContactCellAvatarSize;

    CGFloat fontSize = diameter/2;
    
    NSString *avatarTitle = nil;
    if([signalAccount.recipientId isEqualToString:MENTIONS_ALL]){
        avatarTitle = @"@";
    }else if ([signalAccount.recipientId isEqualToString:@"GROUP_ENTRY"]){
//        avatarTitle = @"G";
    }else if ([signalAccount.recipientId isEqualToString:@"HOME_ARCHIVE"]){
    }else if ([signalAccount.recipientId isEqualToString:@"GROUP_LIST"]){
    }else{
        avatarTitle = @".";
    }
    
    self.nameView.rapidRole = DTGroupRAPIDRoleNone;
    if (!thread) {
        self.nameView.external = NO;
    } else if ([thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        self.nameView.external = NO;
    }
    
    UIImage *image = nil;
    
    if (avatarTitle.length) {
        image = [[JSQMessagesAvatarImageFactory avatarImageWithUserInitials:avatarTitle
                                                                     backgroundColor:[UIColor ows_themeBlueColor]
                                                                           textColor:[UIColor whiteColor]
                                                                                font:[UIFont ows_semiboldFontWithSize:fontSize]
                                                                            diameter:diameter] avatarImage];
    } else {
        if ([signalAccount.recipientId isEqualToString:@"GROUP_ENTRY"]){
            image = [UIImage imageNamed:@"empty-group-avatar"];
        }else if ([signalAccount.recipientId isEqualToString:@"HOME_ARCHIVE"]){
            image = [UIImage imageNamed:@"home_cell_icon_archive"];
        }else if ([signalAccount.recipientId isEqualToString:@"GROUP_LIST"]){
            image = [UIImage imageNamed:@"empty-group-avatar"];
        }
    }
    
    self.avatarView.image = image;
    if (self.accessoryMessage) {
        self.accessoryLabel.text = self.accessoryMessage;
        [self setAccessoryView:self.accessoryLabel];
    }

    // Force layout, since imageView isn't being initally rendered on App Store optimized build.
    [self layoutSubviews];
}

- (void)configureWithSignalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager
{
    [self configureWithRecipientId:signalAccount.recipientId contactsManager:contactsManager];
}

- (void)configureWithThread:(nullable TSThread *)thread signalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager
{
    [self configureWithThread:thread recipientId:signalAccount.recipientId contactsManager:contactsManager];
}

- (void)configureWithRecipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager {
    [self configureWithThread:nil recipientId:recipientId contactsManager:contactsManager];
}

- (void)configureWithThread:(nullable TSThread *)thread recipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager {
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(contactsManager);
    self.thread = thread;
    // Update fonts to reflect changes to dynamic type.
    [self configureFonts];

    self.recipientId = recipientId;
    self.contactsManager = contactsManager;

    // modify: 当前用户标记为备忘录
    if ([recipientId isEqualToString:[TSAccountManager localNumber]]) {
        self.nameView.external = NO;
        self.nameView.name = MessageStrings.noteToSelf;
    } else {
        self.nameView.external = [SignalAccount isExt:recipientId];
        NSMutableAttributedString *attributeName = [[contactsManager formattedFullNameForRecipientId:recipientId font:self.nameView.nameFont] mutableCopy];
        if (self.isMentionOtherContacts) {
            NSAttributedString *otherContactsMentionSuffix = [[NSAttributedString alloc] initWithString:@"*" attributes:@{NSForegroundColorAttributeName : Theme.primaryTextColor, NSFontAttributeName : self.nameView.nameFont}];
            [attributeName appendAttributedString:otherContactsMentionSuffix];
        }
        self.nameView.attributeName = attributeName;
    }
    if (thread != nil && thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        self.nameView.identifier = recipientId;
        self.nameView.rapidRole = [groupThread.groupModel rapidRoleFor:recipientId];
//        self.nameView.external = groupThread.groupModel.isExt;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationName_OtherUsersProfileDidChange
                                               object:nil];
    [self updateAvatar];

    if (self.accessoryMessage) {
        self.accessoryLabel.text = self.accessoryMessage;
        [self setAccessoryView:self.accessoryLabel];
    }
    // Force layout, since imageView isn't being initally rendered on App Store optimized build.
    [self layoutSubviews];
}


- (void)configureWithThread:(TSThread *)thread contactsManager:(OWSContactsManager *)contactsManager {
    OWSAssertDebug(thread);
    self.thread = thread;
    
    // Update fonts to reflect changes to dynamic type.
    [self configureFonts];

    self.contactsManager = contactsManager;
    
    __block NSString * threadName = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        threadName = [thread nameWithTransaction:readTransaction];
    }];

    threadName = threadName ?: @"Unknown";
    if (thread.isNoteToSelf) {
        threadName = MessageStrings.noteToSelf;
    }
    if (threadName.length == 0 && [thread isKindOfClass:[TSGroupThread class]]) {
        threadName = MessageStrings.newGroupDefaultTitle;
    }

    NSAttributedString *attributedText =
        [[NSAttributedString alloc] initWithString:threadName
                                        attributes:@{
                                            NSForegroundColorAttributeName : Theme.primaryTextColor,
                                        }];
    self.nameView.attributeName = attributedText;

    if ([thread isKindOfClass:[TSContactThread class]]) {
        self.recipientId = thread.contactIdentifier;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(otherUsersProfileDidChange:)
                                                     name:kNSNotificationName_OtherUsersProfileDidChange
                                                   object:nil];
        
        if (thread.isNoteToSelf) {
            [self.avatarView dt_setImageWith:nil placeholderImage:[UIImage imageNamed:@"icon_note_to_self"] recipientId:[TSAccountManager sharedInstance].localNumber];
        } else {
            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.recipientId];
            [self.avatarView setImageWithAvatar:account.contact.avatar recipientId:self.recipientId displayName:account.contactFullName completion:nil];
        }
    } else {
        [self.avatarView setImageWithThread:(TSGroupThread *)thread  contactsManager:contactsManager];
    }

    if (self.accessoryMessage) {
        self.accessoryLabel.text = self.accessoryMessage;
        [self setAccessoryView:self.accessoryLabel];
    }
       
    // Force layout, since imageView isn't being initally rendered on App Store optimized build.
    [self layoutSubviews];
}

- (void)updateAvatar {
    OWSContactsManager *contactsManager = self.contactsManager;
    if (contactsManager == nil) {
        OWSFailDebug(@"%@ contactsManager should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }

    NSString *recipientId = self.recipientId;
    if (recipientId.length == 0) {
        OWSFailDebug(@"%@ recipientId should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }
    
    // modify: 当前用户标记为备忘录
    if ([recipientId isEqualToString:[TSAccountManager localNumber]]) {
        switch (self.type) {
            case UserOfSelfIconTypeRealAvater:{
                SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.recipientId];
                self.avatarView.imageForSelfType = DTAvatarImageForSelfTypeOriginal;
                [self.avatarView setImageWithAvatar:account.contact.avatar recipientId:self.recipientId displayName:account.contactFullName completion:nil];
                self.avatarView.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
                self.nameView.name = account.contactFullName;
            }
                break;
            default:
                [self.avatarView dt_setImageWith:nil placeholderImage:[[UIImage imageNamed:@"ic_saveNote" ] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] recipientId:self.recipientId];
                self.avatarView.avatarImageView.contentMode = UIViewContentModeCenter;
                self.avatarView.avatarImageView.tintColor = [UIColor whiteColor];
                self.avatarView.imageForSelfType = DTAvatarImageForSelfTypeNoteToSelf;
                break;
        }
    } else {
        SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.recipientId];
        [self.avatarView setImageWithAvatar:account.contact.avatar recipientId:self.recipientId displayName:[self.contactsManager displayNameForPhoneIdentifier:recipientId] completion:nil];
        self.avatarView.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    }
}

- (void)prepareForReuse
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.backgroundColor = Theme.tableCellBackgroundColor;

    self.thread = nil;
    self.accessoryMessage = nil;
//    self.subtitleLabel.text = nil;
    self.accessoryLabel.text = nil;
    [self.avatarView resetForReuse];
    self.avatarView.recipientId = nil;
    [self.nameView prepareForReuse];
    self.nameView.nameColor = Theme.primaryTextColor;
    for (UIView *subview in self.accessoryViewContainer.subviews) {
        [subview removeFromSuperview];
    }
}

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    OWSAssertDebug(recipientId.length > 0);

    if (recipientId.length > 0 && [self.recipientId isEqualToString:recipientId]) {
        [self updateAvatar];
    }
}

- (void)setAvatar:(NSString *)recipientId displayName:(NSString *)displayName {
    
    self.avatarView.imageForSelfType = DTAvatarImageForSelfTypeOriginal;
    [self.avatarView setImageWithRecipientId:recipientId displayName:displayName];
}

- (void)setUserName:(NSString *)userName isExt:(BOOL)isExt {
    
    _virtualUserId = userName;
    
    self.nameView.name = userName;
    self.nameView.external = isExt;
}

- (BOOL)hasAccessoryText
{
    return self.accessoryMessage.length > 0;
}

- (void)setAccessoryView:(UIView *)accessoryView
{
    OWSAssertDebug(accessoryView);
    OWSAssertDebug(self.accessoryViewContainer);
    OWSAssertDebug(self.accessoryViewContainer.subviews.count < 1);

    [self.accessoryViewContainer addSubview:accessoryView];

    // Trailing-align the accessory view.
    [accessoryView autoPinEdgeToSuperviewMargin:ALEdgeTop];
    [accessoryView autoPinEdgeToSuperviewMargin:ALEdgeBottom];
    [accessoryView autoPinEdgeToSuperviewMargin:ALEdgeTrailing];
    [accessoryView autoPinEdgeToSuperviewMargin:ALEdgeLeading relation:NSLayoutRelationGreaterThanOrEqual];
}

@end

NS_ASSUME_NONNULL_END
