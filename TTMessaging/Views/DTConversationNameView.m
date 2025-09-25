//
//  DTConversationNameView.m
//  Signal
//
//  Created by Ethan on 2022/8/30.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTConversationNameView.h"
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/DTGroupUtils.h>

@interface DTConversationNameView ()

@property (nonatomic, strong) UILabel *lbName;
@property (nonatomic, strong) UILabel *lbExt;
@property (nonatomic, strong) UILabel *lbGroupRole;

@end

@implementation DTConversationNameView

- (void)prepareForReuse {
    
    self.lbName.text = nil;
    self.lbName.attributedText = nil;
    self.lbExt.hidden = YES;
    self.lbGroupRole.hidden = YES;
    self.lbGroupRole.textColor = nil;
    self.lbGroupRole.backgroundColor = nil;
}

- (void)setExternal:(BOOL)external {
    
    _external = external;
    self.lbExt.hidden = !external;
}

- (void)setRapidRole:(DTGroupRAPIDRole)rapidRole {

    _rapidRole = rapidRole;

    NSString *rapidText = nil;
    BOOL isHidden = NO;
    UIColor *textColor = nil;
    switch (rapidRole) {
        case DTGroupRAPIDRoleRecommend: {
            rapidText = @"R";
            textColor = [self recommendColor];
        }
            break;
        case DTGroupRAPIDRoleAgree: {
            rapidText = @"A";
            textColor = [self agreeColor];
        }
            break;
        case DTGroupRAPIDRolePerform: {
            rapidText = @"P";
            textColor = [self performColor];
        }
            break;
        case DTGroupRAPIDRoleInput: {
            rapidText = @"I";
            textColor = [self inputColor];
        }
            break;
        case DTGroupRAPIDRoleDecider: {
            rapidText = @"D";
            textColor = [self deciderColor];
        }
            break;
        case DTGroupRAPIDRoleObserver: {
            rapidText = @"O";
            textColor = [self observerColor];
        }
            break;
        case DTGroupRAPIDRoleNone:
        default:
            isHidden = YES;
            break;
    }
    
    self.lbGroupRole.hidden = isHidden;
    self.lbGroupRole.text = rapidText;
    self.lbGroupRole.textColor = textColor;
    self.lbGroupRole.backgroundColor = [textColor colorWithAlphaComponent:0.2];
}

- (void)setName:(NSString *)name {
    _name = name;
    _attributeName = nil;
    self.lbName.text = name;
}

- (void)setAttributeName:(NSAttributedString *)attributeName {
    _attributeName = attributeName;
    _name = nil;
    self.lbName.attributedText = attributeName;
}

- (void)setNameFont:(UIFont *)nameFont {
    _nameFont = nameFont;
    self.lbName.font = nameFont;
}

- (void)setNameColor:(UIColor *)nameColor {
    _nameColor = nameColor;
    self.lbName.textColor = nameColor;
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    _lineBreakMode = lineBreakMode;
    self.lbName.lineBreakMode = lineBreakMode;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self observeNotifications];
    }
    return self;
}

- (void)setupUI {
    
    self.axis = UILayoutConstraintAxisHorizontal;
    self.alignment = UIStackViewAlignmentCenter;
    self.spacing = 5.f;
    
    [self addArrangedSubview:self.lbName];
    [self addArrangedSubview:self.lbExt];
    [self addArrangedSubview:self.lbGroupRole];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rapidRoleDidChange:)
                                                 name:DTGroupMemberRapidRoleChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalDidChange:)
                                                 name:DTGroupExternalChangedNotification
                                               object:nil];
}

- (void)rapidRoleDidChange:(NSNotification *)noti {
    
    OWSAssertIsOnMainThread();
    if (!noti.object) {
        return;
    }
    
    TSGroupModel *groupModel = (TSGroupModel *)noti.object;
    NSArray <NSString *> *rapidChangedIds = (NSArray *)noti.userInfo[DTRapidRolesKey];
    NSArray <NSString *> *groupMemberIds = groupModel.groupMemberIds;
    if (![groupMemberIds containsObject:self.identifier]) {
        self.rapidRole = DTGroupRAPIDRoleNone;
        return;
    }
    if (![rapidChangedIds containsObject:self.identifier]) {
        return;
    }
    OWSLogInfo(@"[RAPID] %@, changed ids:\n%@", self.identifier, rapidChangedIds);
    self.rapidRole = [groupModel rapidRoleFor:self.identifier];
}

- (void)externalDidChange:(NSNotification *)noti {
    
    OWSAssertIsOnMainThread();
    if (!noti.userInfo || noti.userInfo.allKeys.count == 0) {
        return;
    }
    NSArray <NSString *> *changedIds = noti.userInfo.allKeys;
    if (![changedIds containsObject:self.identifier]) {
        return;
    }
    
    NSNumber *isExternal = noti.userInfo[self.identifier];
    self.external = isExternal.boolValue;
}

- (UILabel *)lbName {
    if (!_lbName) {
        _lbName = [UILabel new];
        _lbName.adjustsFontForContentSizeCategory = YES;
        _lbName.textColor = Theme.primaryTextColor;
        _lbName.lineBreakMode = NSLineBreakByTruncatingTail;
        [_lbName setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_lbName setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_lbName setCompressionResistanceVerticalHigh];
        [_lbName setContentHuggingVerticalLow];
    }
    return _lbName;
}

- (UILabel *)lbExt {
    if (!_lbExt) {
        _lbExt = [UILabel new];
        _lbExt.hidden = YES;
        _lbExt.text = @"EXT";
        _lbExt.textAlignment = NSTextAlignmentCenter;
        _lbExt.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _lbExt.textColor = [self extColor];
        _lbExt.layer.borderColor = [[self extColor] colorWithAlphaComponent:0.4].CGColor;
        _lbExt.layer.borderWidth = 1.f;
        _lbExt.layer.cornerRadius = 2.f;
        _lbExt.layer.masksToBounds = YES;
        [_lbExt autoSetDimensionsToSize:CGSizeMake(28, 16)];
        [_lbExt setContentHuggingHigh];
        [_lbExt setCompressionResistanceHigh];
    }
    return _lbExt;
}

- (UILabel *)lbGroupRole {
    if (!_lbGroupRole) {
        _lbGroupRole = [UILabel new];
        _lbGroupRole.hidden = YES;
        _lbGroupRole.textAlignment = NSTextAlignmentCenter;
        _lbGroupRole.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        _lbGroupRole.layer.cornerRadius = 2.f;
        _lbGroupRole.layer.masksToBounds = YES;
        [_lbGroupRole autoSetDimensionsToSize:CGSizeMake(16, 16)];
        [_lbGroupRole setContentHuggingHigh];
        [_lbGroupRole setCompressionResistanceHigh];
    }
    return _lbGroupRole;
}

//MARK: RAPID label color
- (UIColor *)recommendColor {
    return [UIColor colorWithRGBHex:0x005AE0];
}

- (UIColor *)agreeColor {
    return [UIColor colorWithRGBHex:0x127878];
}

- (UIColor *)performColor {
    return [UIColor colorWithRGBHex:0x009659];
}

- (UIColor *)inputColor {
    return [UIColor colorWithRGBHex:0xB06D00];
}

- (UIColor *)deciderColor {
    return [UIColor colorWithRGBHex:0xD9271E];
}

- (UIColor *)observerColor {
    return [UIColor colorWithRGBHex:0x6F24C7];
}

//MARK: EXT label color
- (UIColor *)extColor {
    return [UIColor colorWithRGBHex:0xE16F00];
}

@end

