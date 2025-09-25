//
//  DTAlertCallView.m
//  Signal
//
//  Created by Felix on 2021/9/3.
//

#import "DTAlertCallView.h"
#import "DTCallModel.h"
#import <TTMessaging/TTMessaging.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import <TTMessaging/DateUtil.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>
#import <TTServiceKit/TSIncomingMessage.h>
#import <TTServiceKit/DTCardMessageEntity.h>
#import <TTServiceKit/NSString+DTMarkdown.h>
#import "TempTalk-Swift.h"

@interface DTAlertCallView ()

@property (nonatomic, strong) DTCallModel *callModel;

@property (nonatomic, strong) UIView *contrainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic) AvatarImageView *avatarView;
@property (nonatomic, strong) UIButton *leftButton;
@property (nonatomic, strong) UIButton *rightButton;
@property (nonatomic, assign) DTAlertCallType alertType;
@property (nonatomic, strong) UIView *spacer;
@property (nonatomic, strong) UIView *verticalSeparator;

@end

@implementation DTAlertCallView

- (void)configAlertCall:(DTCallModel *)callModel
              alertType:(DTAlertCallType)alertType {
    _callModel = callModel;
    _alertType = alertType;
    
    OWSContactsManager *contactManager = Environment.shared.contactsManager;
    NSString *recipientId = callModel.callerRecipientId;
    NSString *recipientName = nil;
    if ([recipientId isEqualToString:@"Unknown"]) {
        recipientName = callModel.hostEmail ?: recipientId;
    } else {
        recipientName = [contactManager displayNameForPhoneIdentifier:recipientId];
    }
    
    if (alertType == DTAlertCallTypeCall) {
        
        UIColor *leftButtonTitleColor = [UIColor colorWithRgbHex:0xD9271E];
        [self.leftButton setTitleColor:leftButtonTitleColor forState:UIControlStateNormal];
        [self.leftButton setTitleColor:leftButtonTitleColor forState:UIControlStateHighlighted];

        if (callModel.callType == DTCallType1v1) {
            
            [self.avatarView setImageWithRecipientId:recipientId];
            self.titleLabel.text = recipientName;
            self.subTitleLabel.text = Localized(@"CALL_INCOMING_ALERT_INVITE_CALL", nil);
            [self.leftButton setTitle:Localized(@"CALL_INCOMING_ALERT_REFUSE", nil) forState:UIControlStateNormal];
            [self.rightButton setTitle:Localized(@"CALL_INCOMING_ALERT_ACCEPT", nil) forState:UIControlStateNormal];
        } else if (callModel.isMultiPersonMeeting) {
            
            self.titleLabel.text = callModel.meetingName ? : @"";
            NSString *subTitle = [NSString stringWithFormat:@"%@ %@", recipientName, Localized(@"CALL_INCOMING_ALERT_INVITE_CALL", nil)];
            self.subTitleLabel.text = subTitle;
            [self.leftButton setTitle:Localized(@"CALL_INCOMING_ALERT_IGNORE", nil) forState:UIControlStateNormal];
            [self.rightButton setTitle:Localized(@"CALL_INCOMING_ALERT_ACCEPT", nil) forState:UIControlStateNormal];
            
            [self updateAvatarImageWithContactsManager:contactManager];
        }
    } else if (alertType == DTAlertCallTypeSchedule) {
        
        [self.avatarView setImageWithRecipientId:DTBotConfig.meetingBotId];
        self.titleLabel.text = callModel.meetingName ?: @"";
        self.subTitleLabel.text = recipientName;
        
        [self.leftButton setTitle:@"Not now" forState:UIControlStateNormal];
        [self.rightButton setTitle:@"Join" forState:UIControlStateNormal];
        UIColor *notNowColor = [UIColor colorWithRgbHex:0xEAECEF];
        [self.leftButton setTitleColor:notNowColor forState:UIControlStateNormal];
        [self.leftButton setTitleColor:notNowColor forState:UIControlStateHighlighted];
    } else if (alertType == DTAlertCallTypeEvent) {
        
        self.avatarView.hidden = YES;
        self.spacer.hidden = NO;
        self.titleLabel.text = callModel.meetingName ?: @"topic";
        self.subTitleLabel.text = @"Now";

        [self.leftButton setTitle:@"OK" forState:UIControlStateNormal];
        [self.rightButton setTitle:@"View" forState:UIControlStateNormal];
        UIColor *leftColor = [UIColor colorWithRgbHex:0xEAECEF];
        [self.leftButton setTitleColor:leftColor forState:UIControlStateNormal];
        [self.leftButton setTitleColor:leftColor forState:UIControlStateHighlighted];

    } else if (alertType == DTAlertCallTypeCritical) {
        
        //MARK: 需要id展示bot头像
        [self.avatarView setImageWithRecipientId:recipientId];
        self.titleLabel.text = recipientName;
        self.leftButton.hidden = YES;
        self.verticalSeparator.hidden = YES;
        
        TSIncomingMessage *incomingMessage = callModel.incomingMessage;
        NSString *detail = nil;
        if (incomingMessage.card) {
            NSString *content = incomingMessage.card.content.removeMarkdownStyle;
            if ([content containsString:@"$FORMAT-LOCAL-TIME"]) {
                detail = [DateUtil replacingFormatTimeWithBody:content pattern:kBotTimeIntervalPattern];
            } else {
                detail = content;
            }
        } else {
            detail = incomingMessage.body ?: @"[critical alert]";
        }
        self.subTitleLabel.text = detail;
        
        [self.rightButton setTitle:@"Go to Message" forState:UIControlStateNormal];
    }
    
}


#pragma mark - action

- (void)leftButtonAction {
    if (self.delegate && [self.delegate respondsToSelector:@selector(alertCallView:leftButtonClickWithCallModel:alertType:)]) {
        [self.delegate alertCallView:self
        leftButtonClickWithCallModel:self.callModel
                           alertType:self.alertType];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(leftButtonAction:)]) {
        [self.delegate leftButtonAction:self.liveKitCall];
    }
    
    if (self.superview) {
        [self removeFromSuperview];
    }
}

- (void)rightButtonAction {
    if (self.delegate && [self.delegate respondsToSelector:@selector(alertCallView:rightButtonClickWithCallModel:alertType:)]) {
        [self.delegate alertCallView:self
       rightButtonClickWithCallModel:self.callModel
                           alertType:self.alertType];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(rightButtonAction:)]) {
        [self.delegate rightButtonAction:self.liveKitCall];
    }
}

- (void)topSwipGestureAction {
    if (self.delegate && [self.delegate respondsToSelector:@selector(alertCallView:topSwipActionWithCallModel:alertType:)]) {
        [self.delegate alertCallView:self
          topSwipActionWithCallModel:self.callModel
                           alertType:self.alertType];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeAction:)]) {
        [self.delegate swipeAction:self.liveKitCall];
    }
    
    if (self.superview) {
        [self removeFromSuperview];
    }
}

- (void)updateAvatarImageWithContactsManager:(OWSContactsManager *)contactsManager {
    if (self.callModel.thread) {
        
        self.avatarView.image = [OWSAvatarBuilder buildImageForThread:self.callModel.thread
                                                      diameter:self.avatarSize
                                               contactsManager:contactsManager];
    } else {
        
        self.avatarView.image = [UIImage imageNamed:@"empty-group-avatar"];
    }
}

#pragma mark - init

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        [self initUI];
        [self addPanGesture];
    }
    return self;
}

- (void)addPanGesture {
    UISwipeGestureRecognizer *topSwip = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(topSwipGestureAction)];
    topSwip.direction = UISwipeGestureRecognizerDirectionUp;
    [self.contrainer addGestureRecognizer:topSwip];
}

- (void)initUI {
    self.backgroundColor = [UIColor clearColor];
    
    self.contrainer = [UIView new];
    self.contrainer.backgroundColor = [[UIColor colorWithRGBHex:0x1E2329] colorWithAlphaComponent:0.95];
    self.contrainer.layer.cornerRadius = 8;
    self.contrainer.layer.masksToBounds = YES;
    self.contrainer.layer.borderColor = [[UIColor colorWithRgbHex:0x474D57] colorWithAlphaComponent:0.5].CGColor;
    self.contrainer.layer.borderWidth = 1 / UIScreen.mainScreen.scale;

    [self addSubview:self.contrainer];
    [self.contrainer autoPinEdgesToSuperviewEdges];
        
    self.avatarView = [[AvatarImageView alloc] init];
    [self.avatarView autoSetDimensionsToSize:CGSizeMake(self.avatarSize, self.avatarSize)];

    self.titleLabel = [UILabel new];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.font = self.nameFont;
    self.titleLabel.textColor = self.nameColor;
    [self.titleLabel setContentHuggingHorizontalLow];
    [self.titleLabel setCompressionResistanceHorizontalLow];
    
    self.subTitleLabel = [UILabel new];
    self.subTitleLabel.font = self.subTitleFont;
    self.subTitleLabel.textColor = self.subTitleColor;
    self.subTitleLabel.numberOfLines = 1;
    self.subTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.subTitleLabel setContentHuggingHorizontalLow];
    [self.subTitleLabel setCompressionResistanceHorizontalLow];
    
    UIStackView *vStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.subTitleLabel,
    ]];
    vStackView.axis = UILayoutConstraintAxisVertical;
    vStackView.spacing = 4;
    
    self.spacer = [UIView new];
    self.spacer.hidden = YES;
    [self.spacer autoSetDimension:ALDimensionWidth toSize:15];
    
    UIStackView *hStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.avatarView,
        self.spacer,
        vStackView
    ]];
    hStackView.axis = UILayoutConstraintAxisHorizontal;
    hStackView.spacing = 16;
    hStackView.layoutMarginsRelativeArrangement = YES;
    hStackView.layoutMargins = UIEdgeInsetsMake(19, 16, 19, 16);

    self.leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.leftButton.titleLabel.font = self.buttonTitleFont;
    [self.leftButton addTarget:self action:@selector(leftButtonAction) forControlEvents:UIControlEventTouchUpInside];
    
    [self.leftButton autoSetDimension:ALDimensionWidth toSize:(MIN(kScreenWidth, kScreenHeight) - 16) / 2];
    
    UIColor *rightButtonTitleColor = [UIColor colorWithRGBHex:0x82C1FC];
    self.rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.rightButton.titleLabel.font = self.buttonTitleFont;
    [self.rightButton setTitleColor:rightButtonTitleColor forState:UIControlStateNormal];
    [self.rightButton setTitleColor:rightButtonTitleColor forState:UIControlStateHighlighted];
    [self.rightButton addTarget:self action:@selector(rightButtonAction) forControlEvents:UIControlEventTouchUpInside];
        
    self.verticalSeparator = [UIView new];
    self.verticalSeparator.backgroundColor = [UIColor colorWithRgbHex:0x474D57];
    [self.verticalSeparator autoSetDimension:ALDimensionWidth toSize:1 / UIScreen.mainScreen.scale];
    
    UIStackView *buttonHStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.leftButton,
        self.verticalSeparator,
        self.rightButton,
    ]];
    buttonHStackView.axis = UILayoutConstraintAxisHorizontal;
    [buttonHStackView autoSetDimension:ALDimensionHeight toSize:self.buttonHeight];
    
    UIView *horizontalSeparator = [UIView new];
    horizontalSeparator.backgroundColor = [UIColor colorWithRgbHex:0x474D57];
    [horizontalSeparator autoSetDimension:ALDimensionHeight toSize:1 / UIScreen.mainScreen.scale];
    
    UIStackView *mainVStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        hStackView,
        horizontalSeparator,
        buttonHStackView,
    ]];
    mainVStackView.axis = UILayoutConstraintAxisVertical;
    
    [self.contrainer addSubview:mainVStackView];
    [mainVStackView autoPinEdgesToSuperviewEdges];
}

#pragma mark - layout constant

- (UIFont *)subTitleFont
{
    return [UIFont systemFontOfSize:14];
}

- (UIColor *)subTitleColor
{
    return [UIColor ows_whiteColor];
}

- (UIFont *)nameFont
{
    return [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
}

- (UIColor *)nameColor {
    return [UIColor ows_whiteColor];
}

- (NSUInteger)avatarSize
{
    return 48.f;
}

- (NSUInteger)buttonHeight
{
    return 44.f;
}

- (UIFont *)buttonTitleFont {
    return [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
}

@end
