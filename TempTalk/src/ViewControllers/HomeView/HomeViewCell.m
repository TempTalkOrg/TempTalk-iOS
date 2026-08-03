//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "HomeViewCell.h"
#import "OWSAvatarBuilder.h"
#import "Yelling-Swift.h"
#import <TTServiceKit/OWSMath.h>
//#import <TTMessaging/OWSUserProfile.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/OWSMessageManager.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import <TTServiceKit/NSTimer+OWS.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTConversationNameView.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomeViewCell ()

@property (nonatomic) DTAvatarImageView *avatarView;
@property (nonatomic) UIStackView *topRowView;
@property (nonatomic) UIStackView *bottomRowView;
@property (nonatomic) DTConversationNameView *nameView;
@property (nonatomic) UILabel *snippetLabel;
@property (nonatomic) UILabel *dateTimeLabel;
@property (nonatomic) MessageStatusView *messageStatusView;
@property (nonatomic) UIView *groupSizeContainer;

@property (nonatomic) UILabel *lbGroupSize;

@property (nonatomic) UIView *unreadBadge;
@property (nonatomic) UILabel *unreadLabel;

@property (nonatomic) UILabel *callOnlineLabel;
//@property (nonatomic) UIImageView *callParticipateIconView;
@property (nonatomic) UILabel *callDurationLabel;
@property (nonatomic) UIView *callDurationContainer;
@property (nonatomic) UIView *callStateContainer;
@property (nonatomic) UIView *rightCallView;

@property (nonatomic, nullable) ThreadViewModel *thread;
@property (nonatomic, nullable) OWSContactsManager *contactsManager;

@property (nonatomic, readonly) NSMutableArray<NSLayoutConstraint *> *viewConstraints;

@property (nonatomic, strong) NSTimer * __nullable stickCallTimeTimer;

@property (nonatomic,strong) NSArray <Contact *>*searchedEamilcontacts;
@property (nonatomic,strong) NSArray <Contact *>*searchedFullNameContacts;
@property (nonatomic,strong) NSArray <Contact *>*searchedRemarkNameContacts;
@property (nonatomic,strong) NSArray *searchedReceptIds;
@property (nonatomic, assign) HomeViewCellStyle cellStyle;
@end

#pragma mark -

@implementation HomeViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self commontInit];
    }
    return self;
}

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commontInit];
    }

    return self;
}

- (void)commontInit
{
    OWSAssertDebug(!self.avatarView);

    _viewConstraints = [NSMutableArray new];

    self.selectedBackgroundView = [UIView new];

    self.avatarView = [DTAvatarImageView new];
    self.avatarView.avatarImageView.backgroundColor = [UIColor colorWithRGBHex:0x3784f7];
    [self.contentView addSubview:self.avatarView];
    [self.avatarView autoSetDimensionsToSize:CGSizeMake(self.avatarSize, self.avatarSize)];
    [self.avatarView autoPinLeadingToSuperviewMargin];
    [self.avatarView autoVCenterInSuperview];
    [self.avatarView setContentHuggingHigh];
    [self.avatarView setCompressionResistanceHigh];
    
    self.groupSizeContainer = [UIView new];
    self.groupSizeContainer.hidden = YES;
    self.groupSizeContainer.layer.borderWidth = 2;
    self.groupSizeContainer.layer.cornerRadius = 8;
    self.groupSizeContainer.layer.masksToBounds = YES;
    [self.groupSizeContainer setContentHuggingHorizontalLow];
    [self.groupSizeContainer setCompressionResistanceHorizontalHigh];
    [self.contentView addSubview:self.groupSizeContainer];
    [self.groupSizeContainer autoPinEdge:ALEdgeTrailing toEdge:ALEdgeTrailing ofView:self.avatarView];
    [self.groupSizeContainer autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.avatarView];
    [self.groupSizeContainer autoSetDimension:ALDimensionHeight toSize:16];
    [self.groupSizeContainer autoSetDimension:ALDimensionWidth toSize:16 relation:NSLayoutRelationGreaterThanOrEqual];

    self.lbGroupSize = [UILabel new];
    self.lbGroupSize.textAlignment = NSTextAlignmentCenter;
    self.lbGroupSize.lineBreakMode = NSLineBreakByTruncatingTail;
    self.lbGroupSize.font = [UIFont ows_dynamicTypeCaption2WithScaled:NO];  // 不缩放，保持默认大小 (11pt)
    [self.groupSizeContainer addSubview:self.lbGroupSize];
    [self.lbGroupSize autoCenterInSuperview];
    [self.groupSizeContainer autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.lbGroupSize withOffset:9];

    self.nameView = [DTConversationNameView new];
    self.nameView.nameFont = self.nameFont;
    // Middle truncation to match the chat screen nav title (ConversationHeaderView)
    self.nameView.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.nameView setContentHuggingLow];
    [self.nameView setCompressionResistanceHorizontalLow];
    [self.nameView setCompressionResistanceVerticalHigh];
    
    UIView *spacer = [UIView new];
    [spacer setContentHuggingLow];
    [spacer setCompressionResistanceLow];
    [self.nameView addArrangedSubview:spacer];

    self.dateTimeLabel = [UILabel new];
    [self.dateTimeLabel setContentHuggingHorizontalHigh];
    [self.dateTimeLabel setCompressionResistanceHorizontalHigh];

    self.messageStatusView = [MessageStatusView new];
    [self.messageStatusView setContentHuggingHorizontalHigh];
    [self.messageStatusView setCompressionResistanceHorizontalHigh];
    
    self.topRowView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.nameView,
        self.dateTimeLabel,
        self.messageStatusView,
    ]];
    self.topRowView.axis = UILayoutConstraintAxisHorizontal;
    self.topRowView.alignment = UIStackViewAlignmentLastBaseline;
    self.topRowView.spacing = 6.f;
    
    self.snippetLabel = [UILabel new];
    self.snippetLabel.font = [self snippetFont];
    self.snippetLabel.numberOfLines = 1;
    self.snippetLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.snippetLabel setContentHuggingHorizontalLow];
    [self.snippetLabel setCompressionResistanceHorizontalLow];
    [self.snippetLabel autoSetDimension:ALDimensionHeight toSize:14 relation:NSLayoutRelationGreaterThanOrEqual];
    
    self.unreadLabel = [UILabel new];
    self.unreadLabel.textColor = [UIColor ows_whiteColor];
    self.unreadLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.unreadLabel.textAlignment = NSTextAlignmentCenter;
    [self.unreadLabel setContentHuggingHorizontalHigh];
    [self.unreadLabel setCompressionResistanceHorizontalHigh];

    self.unreadBadge = [NeverClearView new];
//    self.unreadBadge.backgroundColor = [UIColor colorWithRGBHex:0xed5e32];
    [self.unreadBadge addSubview:self.unreadLabel];
    [self.unreadLabel autoCenterInSuperview];
    [self.unreadBadge setContentHuggingHorizontalHigh];
    [self.unreadBadge setCompressionResistanceHorizontalHigh];
    [self.unreadBadge autoSetDimension:ALDimensionWidth toSize:27 relation:NSLayoutRelationLessThanOrEqual];
    
    self.bottomRowView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.snippetLabel,
        self.unreadBadge,
    ]];
    self.bottomRowView.axis = UILayoutConstraintAxisHorizontal;
    self.bottomRowView.alignment = UIStackViewAlignmentLastBaseline;
    self.bottomRowView.spacing = 6.f;

    UIStackView *vStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.topRowView,
        self.bottomRowView,
    ]];
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.spacing = 3.f;
    
    self.callOnlineLabel = [UILabel new];
    self.callOnlineLabel.numberOfLines = 1;
    self.callOnlineLabel.font = [UIFont ows_dynamicTypeSubheadlineFont];  // 15pt 映射到 subheadline
    self.callOnlineLabel.textColor = Theme.tsecondaryColor;
    [self.callOnlineLabel setContentHuggingHorizontalHigh];
    [self.callOnlineLabel setCompressionResistanceHorizontalHigh];
    
    self.callDurationLabel = [UILabel new];
    self.callDurationLabel.text = @"Join";
    self.callDurationLabel.textColor = [UIColor ows_whiteColor];
    self.callDurationLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.callDurationLabel.textAlignment = NSTextAlignmentCenter;
    self.callDurationLabel.font = [UIFont ows_dynamicTypeCaption1Font];  // 12pt 映射到 caption1
    [self.callDurationLabel setContentHuggingHorizontalHigh];
    [self.callDurationLabel setCompressionResistanceHorizontalHigh];
    
    self.callDurationContainer = [UIView new];
    self.callDurationContainer.backgroundColor = [UIColor ows_themeBlueColor];
    self.callDurationContainer.layer.cornerRadius = 4;
    [self.callDurationContainer addSubview:self.callDurationLabel];
    [self.callDurationContainer setContentHuggingHigh];
    [self.callDurationContainer setCompressionResistanceHigh];
    
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:9];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:9];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
    [self.callDurationLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:5];
    
    self.rightCallView = [UIView containerView];
    self.rightCallView.hidden = YES;
    [self.rightCallView addSubview:self.callOnlineLabel];
    [self.rightCallView addSubview:self.callDurationContainer];
    [self.rightCallView setContentHuggingHigh];
    [self.rightCallView setCompressionResistanceHigh];
    
    [self.callOnlineLabel autoVCenterInSuperview];
    [self.callOnlineLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10];
        
    [self.callDurationContainer autoVCenterInSuperview];
    [self.callDurationContainer autoPinEdgeToSuperviewEdge:ALEdgeRight];
    [self.callDurationContainer autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:self.callOnlineLabel withOffset:5];
    
    UIStackView *hStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        vStackView,
        self.rightCallView
    ]];
    hStackView.axis = UILayoutConstraintAxisHorizontal;
    hStackView.spacing = 6.f;
    [self.contentView addSubview:hStackView];
    [hStackView autoPinLeadingToTrailingEdgeOfView:self.avatarView offset:self.avatarHSpacing];
    [hStackView autoVCenterInSuperview];
    // Ensure that the cell's contents never overflow the cell bounds.
    [hStackView autoPinEdgeToSuperviewMargin:ALEdgeTop relation:NSLayoutRelationLessThanOrEqual];
    [hStackView autoPinEdgeToSuperviewMargin:ALEdgeBottom relation:NSLayoutRelationLessThanOrEqual];
    [hStackView autoPinTrailingToSuperviewMargin];

//    [self.unreadBadge autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.nameLabel];

//    hStackView.userInteractionEnabled = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(callMsgAction)];
    [self.callDurationContainer addGestureRecognizer:tap];
}

- (void)resetUIForSearch:(NSString *)searchText thread:(TSThread *)thread cellStyle:(HomeViewCellStyle)cellStyle {
    self.cellStyle = cellStyle;
    self.snippetLabel.font = [UIFont systemFontOfSize:11];
    self.snippetLabel.textColor = Theme.tthirdColor;
    self.snippetLabel.hidden = YES;
    self.rightCallView.hidden = true;
    self.groupSizeContainer.hidden = YES;
    self.nameView.external = NO;
    
    if (cellStyle == HomeViewCellStyleTypeSearchNormal) {
        self.snippetLabel.hidden = false;
        return;
    }
    
    if(cellStyle == HomeViewCellStyleTypeSearchForConversations){
        if (!thread.isGroupThread) {
            self.snippetLabel.hidden = false;
            return;
        };
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        // 复用 configureWithThread: 时已解密缓存的群名,避免主线程同步读库阻塞搜索输入
        NSString *resolvedGroupName = self.thread.name ?: @"";
        if ([resolvedGroupName.lowercaseString containsString:searchText.lowercaseString]) {
            self.snippetLabel.hidden = true;
            return;
        }
        [self searchContactNameWithSearchText:searchText thread:groupThread];
        //SEARCH_SOMETHING_CONTAIN
        NSUInteger count = self.searchedFullNameContacts.count;
        if(self.searchedFullNameContacts && count >0 && count < 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            Contact *contact = self.searchedFullNameContacts.firstObject;
            NSString *string = [NSString stringWithFormat:@"%@%@",Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                      @"A label for conversations with blocked users."),contact.fullName];
//            NSMutableAttributedString *attributedString = [self dealSearchTextHighlightedWithOrifinString:string searchText:searchText];
//            self.snippetLabel.attributedText = attributedString;
            self.snippetLabel.text = string;
            return;
        }
        
        if (self.searchedFullNameContacts && count >= 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            
            NSMutableString *stringM = [NSMutableString stringWithString:Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                           @"A label for conversations with blocked users.")];
            [self.searchedFullNameContacts enumerateObjectsUsingBlock:^(Contact *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx <= 6) {
                    if (idx == count-1) {
                        [stringM appendString:obj.fullName];
                    } else {
                        [stringM appendString:[NSString stringWithFormat:@"%@, ", obj.fullName]];
                    }
                } else {
                    [stringM appendString:obj.fullName];
                    *stop = YES;
                }
            }];
//            NSMutableAttributedString *attributedString = [self dealSearchTextHighlightedWithOrifinString:string searchText:searchText];
//            self.snippetLabel.attributedText = attributedString;
            self.snippetLabel.text = stringM.copy;
            
            return;
        }
        
        NSUInteger recepectidsCount = self.searchedReceptIds.count;
        if(self.searchedReceptIds && recepectidsCount >0 && recepectidsCount < 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            __block NSString *string = @"";
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
                SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.searchedReceptIds.firstObject transaction:transation];
                
                if (account.contact.fullName.length) {
                    string = [NSString stringWithFormat:@"%@%@(%@)",Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                              @"A label for conversations with blocked users."),account.contact.fullName,self.searchedReceptIds.firstObject];
                } else {
                    string = [NSString stringWithFormat:@"%@%@",Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                              @"A label for conversations with blocked users."),self.searchedReceptIds.firstObject];
                }
            }];
        
            self.snippetLabel.text = string;
            return;
        }
        
        if(self.searchedReceptIds && recepectidsCount >= 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            NSMutableString *stringM = [NSMutableString stringWithString:Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                           @"A label for conversations with blocked users.")];
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
                [self.searchedReceptIds enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    SignalAccount *account = [self.contactsManager signalAccountForRecipientId:obj transaction:transation];
                    Contact *contact = account.contact;
                    if (idx <= 6) {
                        NSString * tmpString = @"";
                        if (idx == recepectidsCount-1) {
                            tmpString = [NSString stringWithFormat:@"%@(%@)",contact.fullName ? : @"",obj];
                            [stringM appendString:tmpString];
                        } else {
                            tmpString = [NSString stringWithFormat:@"%@(%@)",contact.fullName ? : @"",obj];
                            [stringM appendString:[NSString stringWithFormat:@"%@, ", tmpString]];
                        }
                    } else {
                        [stringM appendString:obj];
                        *stop = YES;
                    }
                }];
            }];
           
//            NSMutableAttributedString *attributedString = [self dealSearchTextHighlightedWithOrifinString:string searchText:searchText];
//            self.snippetLabel.attributedText = attributedString;
            self.snippetLabel.text = stringM.copy;
            return;
        }

        NSUInteger remarkNameCount = self.searchedRemarkNameContacts.count;
        if(self.searchedRemarkNameContacts && remarkNameCount >0 && remarkNameCount < 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            Contact *contact = self.searchedRemarkNameContacts.firstObject;
            NSString *string = [NSString stringWithFormat:@"%@%@",Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                      @"A label for conversations with blocked users."),contact.fullName];
            self.snippetLabel.text = string;
            return;
        }

        if (self.searchedRemarkNameContacts && remarkNameCount >= 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;

            NSMutableString *stringM = [NSMutableString stringWithString:Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                           @"A label for conversations with blocked users.")];
            [self.searchedRemarkNameContacts enumerateObjectsUsingBlock:^(Contact *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx <= 6) {
                    if (idx == remarkNameCount-1) {
                        [stringM appendString:obj.fullName];
                    } else {
                        [stringM appendString:[NSString stringWithFormat:@"%@, ", obj.fullName]];
                    }
                } else {
                    [stringM appendString:obj.fullName];
                    *stop = YES;
                }
            }];
            self.snippetLabel.text = stringM.copy;

            return;
        }

        NSUInteger searchedEamilContactCount = self.searchedEamilcontacts.count;
        if(self.searchedEamilcontacts && searchedEamilContactCount >0 && searchedEamilContactCount < 2){
            self.snippetLabel.hidden = false;
            self.snippetLabel.textColor = Theme.tthirdColor;
            NSString *string = [NSString stringWithFormat:@"%@%@",Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                      @"A label for conversations with blocked users."),self.searchedEamilcontacts.firstObject.email];
            
//            NSMutableAttributedString *attributedString = [self dealSearchTextHighlightedWithOrifinString:string searchText:searchText];
//            self.snippetLabel.attributedText = attributedString;
            self.snippetLabel.text = string;
            return;
        }
        
        if(self.searchedEamilcontacts && searchedEamilContactCount >= 2){
            self.snippetLabel.hidden = false;
            
            NSMutableString *stringM = [NSMutableString stringWithString:Localized(@"SEARCH_SOMETHING_CONTAIN",
                                                                                           @"A label for conversations with blocked users.")];
            [self.searchedEamilcontacts enumerateObjectsUsingBlock:^(Contact *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx <= 6) {
                    if (idx == searchedEamilContactCount-1) {
                        [stringM appendString:obj.email];
                    } else {
                        [stringM appendString:[NSString stringWithFormat:@"%@, ", obj.email]];
                    }
                } else {
                    [stringM appendString:obj.email];
                    *stop = YES;
                }
            }];
            
//            NSMutableAttributedString *attributedString = [self dealSearchTextHighlightedWithOrifinString:string searchText:searchText];
//            self.snippetLabel.attributedText = attributedString;
            self.snippetLabel.text = stringM.copy;
            return;
        }
    }
}

- (NSMutableAttributedString *)dealSearchTextHighlightedWithOrifinString:(NSString *)string searchText:(NSString *) searchText{
    __block NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string];
    [attributedString addAttribute:NSForegroundColorAttributeName value:Theme.tthirdColor range: NSMakeRange(0, attributedString.length)];
    [self getRangesWithOriginString:string patternString:searchText withCallBack:^(NSArray<NSTextCheckingResult *> * _Nonnull results) {
        if (results.count) {
            for (NSTextCheckingResult * checkingResult in results) {
                NSRange strResultRange = [checkingResult rangeAtIndex:0];
                [attributedString addAttribute:NSForegroundColorAttributeName value:Theme.tprimaryColor range: strResultRange];
            }
        }
    }];
    return attributedString;
}

- (void)getRangesWithOriginString:(NSString *)string patternString:(NSString *)patternString withCallBack:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:patternString
   options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSArray<NSTextCheckingResult *> * resultArr = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
           if(resultArr){
               if (callBack) {
                   callBack(resultArr);
               }
           }
       }
}

- (void)updateUnreadContentStyle{
    //通知所有人 不做处理 已经Muted
    if (!self.thread.threadRecord.isMuted) {
        self.unreadBadge.backgroundColor = Theme.errorColor;
        self.unreadLabel.textColor = [UIColor ows_whiteColor];
    }
//    else if (self.thread.threadRecord.isMuted && [self isManualUnread]) {
//        self.unreadBadge.backgroundColor = Theme.errorColor;
//        self.unreadLabel.textColor = [UIColor ows_whiteColor];
//    }
    else {
        self.unreadBadge.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x8B8B8B] : [UIColor colorWithRGBHex:0xcccccc];
        self.unreadLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor ows_blackColor] : [UIColor ows_whiteColor];
    }
}

- (void)searchContactNameWithSearchText:(NSString *)searchText thread:(TSGroupThread *)groupThread {
//    if (self.searchedEamilcontacts.count || self.searchedFullNameContacts.count || self.searchedReceptIds.count) return;
    __block NSMutableArray <Contact *> *contacts = [NSMutableArray array];
    __block NSMutableArray <Contact *> *searchEamilcontacts = [NSMutableArray array];
    __block NSMutableArray <Contact *> *searchRemarkNameContacts = [NSMutableArray array];
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull trasation) {
        for (NSString *recepectid in groupThread.groupModel.groupMemberIds) {
            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:recepectid transaction:trasation];
            Contact *contact = account.contact;
            if ([contact.fullName.lowercaseString containsString:searchText.lowercaseString]) {
                [contacts addObject:contact];
            }
            if ([contact.email.lowercaseString containsString:searchText.lowercaseString]) {
                [searchEamilcontacts addObject:contact];
            }
            if (account.remarkName && [account.remarkName.lowercaseString containsString:searchText.lowercaseString]) {
                [searchRemarkNameContacts addObject:contact];
            }
        }
    }];
    self.searchedEamilcontacts = searchEamilcontacts;
    self.searchedFullNameContacts = contacts;
    self.searchedRemarkNameContacts = searchRemarkNameContacts;
    self.searchedReceptIds = @[];
}

- (NSArray <Contact *>*)searchEmailWithSearchText:(NSString *)searchText thread:(TSGroupThread *)groupThread {
    __block NSMutableArray <Contact *> *contacts = [NSMutableArray array];
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull trasation) {
        for (NSString *recepectid in groupThread.groupModel.groupMemberIds) {
            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:recepectid transaction:trasation];
            Contact *contact = account.contact;
            if ([contact.fullName.lowercaseString containsString:searchText.lowercaseString]) {
                [contacts addObject:contact];
            }
        }
    }];
    return contacts.copy;
}



- (void)setCellStyle:(HomeViewCellStyle)cellStyle {
    _cellStyle = cellStyle;
    
    if (cellStyle == HomeViewCellStyleTypeSearchNormal ||
        cellStyle == HomeViewCellStyleTypeSearchForConversations ||
        cellStyle == HomeViewCellStyleTypeGroupInCommon) {
        self.unreadLabel.hidden = true;
        self.dateTimeLabel.hidden = true;
        self.messageStatusView.hidden = true;
        self.unreadBadge.hidden = true;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSString *)cellReuseIdentifier
{
    return NSStringFromClass([self class]);
}

- (void)initializeLayout
{
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (nullable NSString *)reuseIdentifier
{
    return NSStringFromClass(self.class);
}

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
{
    [self configureWithThread:thread
              contactsManager:contactsManager
        blockedPhoneNumberSet:blockedPhoneNumberSet
              overrideSnippet:nil
                 overrideDate:nil];
}

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
            overrideSnippet:(nullable NSAttributedString *)overrideSnippet
               overrideDate:(nullable NSDate *)overrideDate
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(thread);
    OWSAssertDebug(contactsManager);
    OWSAssertDebug(blockedPhoneNumberSet);

    self.thread = thread;
    self.contactsManager = contactsManager;
    
    BOOL hasUnreadMessages = thread.hasUnreadMessages;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationName_OtherUsersProfileDidChange
                                               object:nil];
    if (self.shouldObserveMeeting) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(configCallReleted)
                                                     name:DTStickMeetingManager.kMeetingDurationUpdateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateCellJoin:)
                                                     name:DTStickMeetingManager.kMeetingBarJoinNotification
                                                   object:nil];
    }
    
    [self updateNameLabel];
    [self updateAvatarView];
    
    if (self.isShowSticked) {
        BOOL useElevatedBackground = thread.isSticked || thread.isCallingSticked || thread.threadRecord.isNoteToSelf;
        self.contentView.backgroundColor = useElevatedBackground ? Theme.bg5Color : Theme.bgpagePrimaryColor;
    } else {
        self.contentView.backgroundColor = Theme.bgpagePrimaryColor;
    }
    
    self.selectedBackgroundView.backgroundColor = Theme.bg5Color;
    
    if (!thread.isGroupThread) {
        self.avatarView.stateBackgroundColor = self.contentView.backgroundColor;
    }
    
    // We update the fonts every time this cell is configured to ensure that
    // changes to the dynamic type settings are reflected.
    self.snippetLabel.font = [self snippetFont];

    if (overrideSnippet) {
        self.snippetLabel.attributedText = overrideSnippet;
    } else {
        self.snippetLabel.attributedText =
            [self attributedSnippetForThread:thread blockedPhoneNumberSet:blockedPhoneNumberSet];
    }
    
    NSDate *sendDate = overrideDate ? overrideDate : thread.lastMessageDate;
    if (sendDate) {
        self.dateTimeLabel.text = [DateUtil formatDateForConversationList: sendDate];
    } else {
        self.dateTimeLabel.text = @"";
    }

    self.dateTimeLabel.font = [UIFont ows_dynamicTypeCaption1Font];  // 使用缩放字体 (12pt)
    self.dateTimeLabel.textColor = Theme.tthirdColor;

    NSUInteger unreadCount = thread.unreadCount;
    //下面这个unreadCount的值 和 isUnread的结合判断主要用于处理当前会话的未读数的展示调整
    if (unreadCount <= 0 && [self isManualUnread] ) {
        unreadCount = 1;
    }
    if (overrideSnippet) {
        // If we're using the home view cell to render search results,
        // don't show "unread badge" or "message status" indicator.
        self.unreadBadge.hidden = YES;
        self.messageStatusView.hidden = YES;
    } else if (unreadCount > 0) {
        // If there are unread messages, show the "unread badge."
        // The "message status" indicators is redundant.
        self.unreadBadge.hidden = NO;
        self.messageStatusView.hidden = YES;

        self.unreadLabel.text = [OWSFormat formatIntMax99:(int)unreadCount];
        self.unreadLabel.font = self.unreadFont;
        const int unreadBadgeHeight = (int)ceil(self.unreadLabel.font.lineHeight * 1.2f);
        self.unreadBadge.layer.cornerRadius = unreadBadgeHeight / 2;

        [NSLayoutConstraint autoSetPriority:UILayoutPriorityDefaultHigh
                             forConstraints:^{
                                 // This is a bit arbitrary, but it should scale with the size of dynamic text
                                 CGFloat minMargin = CeilEven(unreadBadgeHeight * .5f);
                                 [self.viewConstraints addObjectsFromArray:@[
                                     [self.unreadBadge autoMatchDimension:ALDimensionWidth
                                                              toDimension:ALDimensionWidth
                                                                   ofView:self.unreadLabel
                                                               withOffset:minMargin],
                                     // badge sizing
                                     [self.unreadBadge autoSetDimension:ALDimensionWidth
                                                                 toSize:unreadBadgeHeight
                                                               relation:NSLayoutRelationGreaterThanOrEqual],
                                     [self.unreadBadge autoSetDimension:ALDimensionHeight toSize:unreadBadgeHeight],
                                 ]];
                             }];
    } else {
        UIImage *_Nullable statusIndicatorImage = nil;
        // TODO: Theme, Review with design.
        UIColor *messageStatusViewTintColor
            = (Theme.isDarkThemeEnabled ? [UIColor ows_dark30Color] : [UIColor ows_light35Color]);
        BOOL shouldAnimateStatusIcon = NO;
        /*
        if ([self.thread.lastMessageForInbox isKindOfClass:[TSOutgoingMessage class]]) {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)self.thread.lastMessageForInbox;

            MessageReceiptStatus messageStatus =
                [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
            switch (messageStatus) {
                case MessageReceiptStatusUploading:
                case MessageReceiptStatusSending:
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_sending"];
                    shouldAnimateStatusIcon = YES;
                    break;
                case MessageReceiptStatusSent:
                case MessageReceiptStatusSkipped:
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_sent"];
                    break;
                case MessageReceiptStatusDelivered:
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_delivered"];
                    break;
                case MessageReceiptStatusRead:
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_read"];
                    break;
                case MessageReceiptStatusFailed:
                    statusIndicatorImage = [UIImage imageNamed:@"message_status_failed"];
                    messageStatusViewTintColor = [UIColor ows_destructiveRedColor];
                    break;
            }
        }
         */
        statusIndicatorImage = nil;
        self.messageStatusView.image = [statusIndicatorImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.messageStatusView.tintColor = messageStatusViewTintColor;
        self.messageStatusView.hidden = statusIndicatorImage == nil;
        self.unreadBadge.hidden = YES;
        if (shouldAnimateStatusIcon) {
            CABasicAnimation *animation;
            animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            animation.toValue = @(M_PI * 2.0);
            const CGFloat kPeriodSeconds = 1.f;
            animation.duration = kPeriodSeconds;
            animation.cumulative = YES;
            animation.repeatCount = HUGE_VALF;
            [self.messageStatusView.layer addAnimation:animation forKey:@"animation"];
        } else {
            [self.messageStatusView.layer removeAllAnimations];
        }
    }
    
    [self configCallReleted];
    [self updateUnreadContentStyle];
}

- (BOOL)isManualUnread {
    return self.thread.threadRecord.isUnread && [self.thread.threadRecord.lastMessageDate ows_millisecondsSince1970] <= self.thread.threadRecord.unreadTimeStimeStamp && !self.thread.threadRecord.isArchived;
}

- (void)showMeetingBar {
    
    if (!self.messageStatusView.isHidden) {
        self.messageStatusView.hidden = YES;
    }
    if (!self.unreadBadge.isHidden) {
        self.unreadBadge.hidden = YES;
    }
    if (self.rightCallView.isHidden) {
        self.rightCallView.hidden = NO;
    }
    if (!self.dateTimeLabel.isHidden) {
        self.dateTimeLabel.hidden = YES;
    }
    self.callDurationLabel.hidden = NO;
}

- (void)updateAvatarView
{
    OWSContactsManager *contactsManager = self.contactsManager;
    if (contactsManager == nil) {
        OWSFailDebug(@"%@ contactsManager should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }

    ThreadViewModel *thread = self.thread;
    if (thread == nil) {
        OWSFailDebug(@"%@ thread should not be nil", self.logTag);
        self.avatarView.image = nil;
        return;
    }
    
    if (self.thread.threadRecord.isNoteToSelf) {
        [self.avatarView dt_setImageWith:nil placeholderImage:[[UIImage imageNamed:@"ic_saveNote" ] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] recipientId:[TSAccountManager sharedInstance].localNumber];
        self.avatarView.avatarImageView.contentMode = UIViewContentModeCenter;
        self.avatarView.avatarImageView.tintColor = [UIColor whiteColor];
    } else {
        self.avatarView.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        if (self.messageAuthorId) {
            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:self.messageAuthorId];
            // Use nickname for avatar, not remark name
            NSString *nicknameForAvatar = [self.contactsManager rawDisplayNameForPhoneIdentifier:self.messageAuthorId];
            [self.avatarView setImageWithSignalAccount:account displayName:nicknameForAvatar completion:nil];
            return;
        }

        if (thread.isGroupThread) {
            TSGroupThread *groupThread = (TSGroupThread *)thread.threadRecord;
            [self.avatarView setImageWithThread:groupThread contactsManager:contactsManager];
        } else {

            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:thread.contactIdentifier];
            // Use nickname for avatar, not remark name
            NSString *nicknameForAvatar = [self.contactsManager rawDisplayNameForPhoneIdentifier:thread.contactIdentifier];
            [self.avatarView setImageWithSignalAccount:account displayName:nicknameForAvatar completion:nil];
        }
    }
    
    [self updateGroupSize];
}

- (NSAttributedString *)attributedSnippetForThread:(ThreadViewModel *)thread
                             blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
{
    OWSAssertDebug(thread);

    BOOL isBlocked = NO;
    if (!thread.isGroupThread) {
        NSString *contactIdentifier = thread.contactIdentifier;
        isBlocked = [blockedPhoneNumberSet containsObject:contactIdentifier];
    }
    BOOL hasUnreadMessages = thread.hasUnreadMessages;

    NSMutableAttributedString *snippetText = [NSMutableAttributedString new];
    NSString *displayableText = thread.lastMessageText;
    if (displayableText) {
        __block NSString *draftString = nil;
        __block NSString *atPersonStrings = nil;
        __block BOOL hasCriticalAlertHighlight = NO;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
            draftString = [thread.threadRecord currentDraftWithTransaction:readTransaction];
            atPersonStrings = [thread.threadRecord atPersonsWithTransaction:readTransaction];
            hasCriticalAlertHighlight = [thread.threadRecord hasCriticalAlertHighlightWithTransaction:readTransaction];
        }];
        //TODO: 待优化
        if (!thread.isGroupThread && draftString.length) {//私聊 草稿展示优先
            
            if (hasUnreadMessages && hasCriticalAlertHighlight) {
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:Localized(@"SOMEONE_CRITICAL_ALERT_ALL_TEXT", @"")
                                                     attributes:@{
                    NSFontAttributeName : self.snippetFont.ows_semibold,
                    NSForegroundColorAttributeName : Theme.errorColor,
                }]];
                
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:displayableText
                                                     attributes:@{
                    NSFontAttributeName :
                        (hasUnreadMessages ? self.snippetFont
                        : self.snippetFont),
                    NSForegroundColorAttributeName :
                        (hasUnreadMessages ? Theme.tthirdColor
                        : Theme.tthirdColor),
                }]];
                return snippetText;
            }
            
            snippetText = [[NSMutableAttributedString alloc]
                           initWithAttributedString:
                               [[NSAttributedString alloc]initWithString:Localized(@"HOMEVIEWCELL_DRAFT",
                                                                                           @"A label for conversations with draft.")
                                                              attributes:@{
                                NSFontAttributeName :self.snippetFont.ows_semibold,
                                NSForegroundColorAttributeName :Theme.errorColor,
                               }]];
            [snippetText appendAttributedString:
             [[NSAttributedString alloc]
              initWithString:[NSString stringWithFormat:@" %@",draftString]
              attributes:@{
                NSFontAttributeName : self.snippetFont,
                NSForegroundColorAttributeName :
                    Theme.tthirdColor,
             }]];
            
        } else if (!thread.isGroupThread && !draftString.length) {
            if (hasUnreadMessages && hasCriticalAlertHighlight) {
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:Localized(@"SOMEONE_CRITICAL_ALERT_ALL_TEXT", @"")
                                                     attributes:@{
                    NSFontAttributeName : self.snippetFont.ows_semibold,
                    NSForegroundColorAttributeName : Theme.errorColor,
                }]];
                
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:displayableText
                                                     attributes:@{
                    NSFontAttributeName :
                        (hasUnreadMessages ? self.snippetFont
                        : self.snippetFont),
                    NSForegroundColorAttributeName :
                        (hasUnreadMessages ? Theme.tthirdColor
                        : Theme.tthirdColor),
                }]];
                return snippetText;
            }
            
            [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                 initWithString:displayableText
                                                 attributes:@{
                NSFontAttributeName :
                    (hasUnreadMessages ? self.snippetFont
                    : self.snippetFont),
                NSForegroundColorAttributeName :
                    (hasUnreadMessages ? Theme.tthirdColor
                    : Theme.tthirdColor),
            }]];
        } else if(thread.isGroupThread) {//群组中有草稿展示 优先级：Critical alert > @您 > @All > 草稿
            if (hasUnreadMessages && hasCriticalAlertHighlight) {
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:Localized(@"SOMEONE_CRITICAL_ALERT_ALL_TEXT", @"")
                                                     attributes:@{
                    NSFontAttributeName : self.snippetFont.ows_semibold,
                    NSForegroundColorAttributeName : Theme.errorColor,
                }]];
                
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:displayableText
                                                     attributes:@{
                    NSFontAttributeName :
                        (hasUnreadMessages ? self.snippetFont
                        : self.snippetFont),
                    NSForegroundColorAttributeName :
                        (hasUnreadMessages ? Theme.tthirdColor
                        : Theme.tthirdColor),
                }]];
                return snippetText;
            }
            if (hasUnreadMessages && atPersonStrings && ([TSAccountManager localNumber] && [atPersonStrings containsString:[TSAccountManager localNumber]])) {
                //@自己
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:Localized(@"SOMEONE_MENTION_YOU_TEXT", @"")
                                                     attributes:@{
                    NSFontAttributeName : self.snippetFont.ows_semibold,
                    NSForegroundColorAttributeName : Theme.errorColor,
                }]];
                
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:displayableText
                                                     attributes:@{
                    NSFontAttributeName :
                        (hasUnreadMessages ? self.snippetFont
                        : self.snippetFont),
                    NSForegroundColorAttributeName :
                        (hasUnreadMessages ? Theme.tthirdColor
                        : Theme.tthirdColor),
                }]];
                return snippetText;
                
            }
            if (hasUnreadMessages && atPersonStrings && [atPersonStrings containsString:MENTIONS_ALL]) {
                //@所有人
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:Localized(@"SOMEONE_MENTION_ALL_TEXT", @"")
                                                     attributes:@{
                    NSFontAttributeName : self.snippetFont.ows_semibold,
                    NSForegroundColorAttributeName : Theme.errorColor,
                }]];
                
                [snippetText appendAttributedString:[[NSAttributedString alloc]
                                                     initWithString:displayableText
                                                     attributes:@{
                    NSFontAttributeName :
                        (hasUnreadMessages ? self.snippetFont
                        : self.snippetFont),
                    NSForegroundColorAttributeName :
                        (hasUnreadMessages ? Theme.tthirdColor
                        : Theme.tthirdColor),
                }]];
                return snippetText;
            }
            
            if (draftString.length) {
                //草稿展示
                snippetText = [[NSMutableAttributedString alloc]
                               initWithAttributedString:
                                   [[NSAttributedString alloc]initWithString:Localized(@"HOMEVIEWCELL_DRAFT",
                                                                                               @"A label for conversations with draft.")
                                                                  attributes:@{
                                    NSFontAttributeName :self.snippetFont.ows_semibold,
                                    NSForegroundColorAttributeName :Theme.errorColor,
                                   }]];
                [snippetText appendAttributedString:
                 [[NSAttributedString alloc]
                  initWithString:[NSString stringWithFormat:@" %@",draftString]
                  attributes:@{
                    NSFontAttributeName : self.snippetFont,
                    NSForegroundColorAttributeName :
                        Theme.tthirdColor,
                 }]];
                
            } else {
                UIFont * snippetFont = hasUnreadMessages ? self.snippetFont : self.snippetFont;
                UIColor *foregroundColor = hasUnreadMessages ? Theme.tthirdColor : Theme.tthirdColor;
                [self snippetWithOriginString:snippetText AppendText:displayableText font:snippetFont textColor:foregroundColor];
            }
            return snippetText;
        }
    }
    return snippetText;
}

- (void)snippetWithOriginString:(NSMutableAttributedString *)originString AppendText:(NSString *)appendString font:(UIFont *)font textColor:(UIColor *)color {
    [originString appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:appendString
                                         attributes:@{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName :color,
    }]];
}

- (NSString *)criticalAlertIdentifierForThread:(ThreadViewModel *)thread {
    NSString *serverId = thread.threadRecord.serverThreadId;
    if (thread.isGroupThread) {
        return serverId;
    } else {
        return thread.contactIdentifier;
    }
    return serverId;
}

- (void)configInCommonGroupWithThread:(TSGroupThread *)groupThread
                    sortedMemberNames:(NSString *)memberNames
                      contactsManager:(OWSContactsManager *)contactsManager {
    
    OWSAssertIsOnMainThread();
    OWSAssertDebug(groupThread);
    
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wnonnull"
    // 加密群名在 nil transaction 下会拿到占位符,ThreadViewModel 初始化必须带 transaction
    __weak typeof(self) weakSelf = self;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        weakSelf.thread = [[ThreadViewModel alloc] initWithThread:groupThread transaction:transaction];
    }];
//#pragma clang diagnostic pop
    self.contentView.backgroundColor = Theme.bgpagePrimaryColor;
    self.selectedBackgroundView.backgroundColor = Theme.bg5Color;
    self.cellStyle = HomeViewCellStyleTypeGroupInCommon;
    self.contactsManager = contactsManager;
    [self updateAvatarView];
    [self updateNameLabel];

    self.snippetLabel.textColor = Theme.tthirdColor;
    self.snippetLabel.text = memberNames;
}

#pragma mark - action

- (void)callMsgAction {
    OWSLogInfo(@"%@ call callMsgAction", self.logTag);
    if (self.meetingBarDelegate && [self.meetingBarDelegate respondsToSelector:@selector(didTapMeetingBarWithThread:)]) {
        OWSLogInfo(@"%@ call callMsgAction threadRecord %@", self.logTag, self.thread.threadRecord.uniqueId);
        [self.meetingBarDelegate didTapMeetingBarWithThread:self.thread.threadRecord];
    }
}

#pragma mark - Date formatting

- (NSString *)stringForDate:(nullable NSDate *)date
{
    if (date == nil) {
        OWSFailDebug(@"%@ date was unexpectedly nil", self.logTag);
        return @"";
    }

    return [DateUtil formatDateShort:date];
}

#pragma mark - Constants

/// 通用字体缩放方法：根据自定义倍数缩放字体
/// @param baseFont 基础字体（不缩放的字体）
/// @param customScale 自定义缩放倍数（例如 1.2 表示放大 20%）
/// @return 缩放后的字体
- (UIFont *)scaledFont:(UIFont *)baseFont withCustomScale:(CGFloat)customScale
{
    CGFloat scaleFactor = [TextSizeManager currentScaleFactor];
    if (scaleFactor > 1.0) {
        // 如果当前是大字体模式，应用自定义缩放倍数
        return [baseFont fontWithSize:baseFont.pointSize * customScale];
    }
    return baseFont;
}

- (UIFont *)unreadFont
{
    // 获取基础字体（不缩放）
    UIFont *baseFont = [UIFont ows_dynamicTypeCaption1WithScaled:NO].ows_semibold;
    // 使用自定义的 1.2 倍缩放（而不是默认的 1.4 倍）
    return [self scaledFont:baseFont withCustomScale:1.2];
}

- (UIFont *)dateTimeFont
{
    return [UIFont ows_dynamicTypeCaption1Font];
}

- (UIFont *)snippetFont
{
    return [UIFont ows_dynamicTypeBody2Font];  // 16pt 映射到 body2 (等同于 subheadline),支持动态字体
}

- (UIFont *)nameFont
{
    return [UIFont ows_dynamicTypeBodyFont];
}

// Used for profile names.
- (UIFont *)nameSecondaryFont
{
    return [UIFont ows_dynamicTypeBodyFont].ows_italic;
}

- (NSUInteger)avatarSize
{
    return 48.f;
}


- (NSUInteger)avatarHSpacing
{
    return 12.f;
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];

    // 移除通知监听，避免重复监听和内存泄漏
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [NSLayoutConstraint deactivateConstraints:self.viewConstraints];
    [self.viewConstraints removeAllObjects];

    self.thread = nil;
    self.contactsManager = nil;
    [self.avatarView resetForReuse];
    self.groupSizeContainer.hidden = YES;
    self.rightCallView.hidden = YES;
    self.dateTimeLabel.hidden = NO;
    self.callOnlineLabel.textColor = Theme.tsecondaryColor;

    [self.nameView prepareForReuse];
}

#pragma mark - Name

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    if (recipientId.length == 0) {
        return;
    }

    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        return;
    }

    if (![self.thread.contactIdentifier isEqualToString:recipientId]) {
        return;
    }

    [self updateNameLabel];
    [self updateAvatarView];
}

- (void)updateNameLabel
{
    OWSAssertIsOnMainThread();

    self.nameView.nameFont = self.nameFont;
    self.nameView.nameColor = Theme.tprimaryColor;
    
    ThreadViewModel *thread = self.thread;
    if (thread == nil) {
        OWSFailDebug(@"%@ thread should not be nil", self.logTag);
        self.nameView.attributeName = nil;
        return;
    }

    OWSContactsManager *contactsManager = self.contactsManager;
    if (contactsManager == nil) {
        OWSFailDebug(@"%@ contacts manager should not be nil", self.logTag);
        self.nameView.attributeName = nil;
        return;
    }

    NSAttributedString *name;
    SignalAccount *account = nil;
    if (thread.isGroupThread) {
        if (thread.name.length == 0) {
            name = [[NSAttributedString alloc] initWithString:[MessageStrings newGroupDefaultTitle]];
        } else {
            if (self.messageAuthorId) {

                // TODO: grdb opt
                __block NSAttributedString *fetchedName = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
                    fetchedName = [contactsManager attributedContactOrProfileNameForPhoneIdentifier:self.messageAuthorId
                                                                                 primaryFont:self.nameFont
                                                                               secondaryFont:self.nameSecondaryFont
                                                                                 transaction:transaction];
                }];

                name = fetchedName;
            } else {
                name = [[NSAttributedString alloc] initWithString:thread.name];
            }
        }
        TSGroupThread *groupThread = (TSGroupThread *)thread.threadRecord;
        self.nameView.external = NO;
    } else {
        NSString *contactIdentifier = self.messageAuthorId ?: thread.contactIdentifier;
        // TODO: grdb opt
        __block NSAttributedString *fetchedName = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            fetchedName = [contactsManager attributedContactOrProfileNameForPhoneIdentifier:contactIdentifier
                                                                                primaryFont:self.nameFont
                                                                              secondaryFont:self.nameSecondaryFont
                                                                                transaction:transaction];
        }];
        name = fetchedName;
        
        NSDictionary <NSString *, SignalAccount *> *signalAccountMap = contactsManager.signalAccountMap;
        account = signalAccountMap[contactIdentifier];
        if (signalAccountMap.allKeys.count > 1) {
            if (self.thread.threadRecord.isNoteToSelf) {
                self.nameView.external = NO;
            } else {
                self.nameView.external = [SignalAccount isExt:contactIdentifier];
            }
        }
    }

    if (self.thread.threadRecord.isNoteToSelf) {
        self.nameView.name = MessageStrings.noteToSelf;
    } else {
        BOOL isBot = [account isBot];

        if (isBot) {
            name = [name appendingBotIconWithFont:self.nameFont];
        }

        if ([thread.threadRecord messageExpiresInSeconds] > 0) {
            name = [DTConversactionSettingUtils msgDisappearingTipsOnThreadWithMessageExpiry:thread.threadRecord.messageExpiresInSeconds threadName:name font:self.nameFont];
        }
        self.nameView.attributeName = name;
    }
}

- (void)updateGroupSize {
    
    if (!self.thread.isGroupThread) return;
    TSGroupThread *groupThread = (TSGroupThread *)self.thread.threadRecord;
    if (!groupThread.isLocalUserInGroup) {
        return;
    }
    TSGroupModel *groupModel = groupThread.groupModel;
    if (!DTParamsUtils.validateArray(groupModel.groupMemberIds)) {
        return;
    }
    NSUInteger memberCount = groupModel.groupMemberIds.count;
    if (memberCount < 1) return;

    BOOL isDarkTheme = NO;//Theme.isDarkThemeEnabled;
    self.groupSizeContainer.hidden = NO;
    self.groupSizeContainer.layer.borderColor = UIColor.ows_whiteColor.CGColor;//self.contentView.backgroundColor.CGColor;
    self.groupSizeContainer.backgroundColor = isDarkTheme ? [UIColor colorWithRGBHex:0x012C70] : [UIColor colorWithRGBHex:0xEBF7FF];
    self.lbGroupSize.textColor = [[Theme light] tinfoColor];
    
    self.lbGroupSize.text = [NSString stringWithFormat:@"%ld", memberCount];
}

// NOTE: iOS 13.0 以后，当 cell 被选中高亮时，不再修改 contentView 及其子视图的 backgroundColor 和 isOpaque 属性
// 这导致 selectedBackgroundView 被 contentView 颜色覆盖，而无法展示出高亮色
// 官方推荐做法是在 -setHighlighted:animated: 和 -setSelected:animated: 将 contentView backgroundColor 设置为 nil
// reference: https://stackoverflow.com/questions/58104474/uitableviewcell-selectedbackgroundviews-color-not-visible-when-building-on-ios
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (highlighted) {
        self.contentView.backgroundColor = nil;
    } else {
        if (self.isShowSticked) {
            self.contentView.backgroundColor = self.thread.isSticked || self.thread.isCallingSticked ? Theme.bg5Color : Theme.bgpagePrimaryColor;
        } else {
            self.contentView.backgroundColor = Theme.bgpagePrimaryColor;
        }
    }
    [super setHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (selected) {
        self.contentView.backgroundColor = nil;
    } else {
        if (self.isShowSticked) {
            self.contentView.backgroundColor = self.thread.isSticked || self.thread.isCallingSticked ? Theme.bg5Color : Theme.bgpagePrimaryColor;
        } else {
            self.contentView.backgroundColor = Theme.bgpagePrimaryColor;
        }
    }
    [super setSelected:selected animated:animated];
}

- (void)updateCellJoin:(NSNotification *)noti {
    
    if (!self.thread.threadRecord.isGroupThread) {
        return;
    }
    
    NSString *channelName = [DTCallManager generateGroupChannelNameBy:self.thread.threadRecord];
    
    BOOL inThisMeeting = DTMeetingManager.shared.inMeeting;
    if (inThisMeeting) { return; }
    
    NSArray <NSString *> *goingMeetings = DTStickMeetingManager.shared.allStickMeetingsDictory.allKeys;
    if ([goingMeetings containsObject:channelName]) {
        return;
    }
    
    BOOL showJoin = NO;
    NSSet <NSString *> *channelNames = nil;
    if (noti.object && [noti.object isKindOfClass:NSSet.class]) {
        channelNames = (NSSet *)noti.object;
        if (channelNames.count > 0 && [channelNames containsObject:channelName]) {
            showJoin = YES;
        }
    }
    
    if (showJoin || self.thread.threadRecord.isCallingSticked) {
        [self showMeetingBar];
        self.callOnlineLabel.hidden = YES;
        self.callDurationLabel.text = @"Join";
        return;
    }
    
    if (!self.rightCallView.isHidden) {
        self.rightCallView.hidden = YES;
    }
    if (self.dateTimeLabel.isHidden) {
        self.dateTimeLabel.hidden = NO;
    }
}

@end


NS_ASSUME_NONNULL_END
