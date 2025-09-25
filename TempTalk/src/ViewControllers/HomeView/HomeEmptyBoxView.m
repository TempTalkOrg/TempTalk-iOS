//
//  HomeEmptyBoxView.m
//  Wea
//
//  Created by Ethan on 2021/11/11.
//

#import "HomeEmptyBoxView.h"
#import "UIView+SignalUI.h"
#import "UIFont+OWS.h"
#import "UIColor+OWS.h"
#import <TTMessaging/Theme.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface HomeEmptyBoxView ()

@property (nonatomic, strong) UIImageView *appIcon;
@property (nonatomic, strong) UILabel *lbEmptyBox;

@end

@implementation HomeEmptyBoxView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        [self addSubview:self.appIcon];
        [self addSubview:self.lbEmptyBox];
        
        [self.appIcon autoSetDimensionsToSize:CGSizeMake(80, 80)];
        [self.appIcon autoAlignAxisToSuperviewAxis:ALAxisVertical];
        [self.appIcon autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self withOffset:-50];
        
        [self.lbEmptyBox autoAlignAxisToSuperviewAxis:ALAxisVertical];
        [self.lbEmptyBox autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.appIcon withOffset:10];
    }
    
    return self;
}

- (void)setEmptyText:(NSString *)emptyText {
    
    self.lbEmptyBox.text = emptyText;
}

- (UIImageView *)appIcon {
    
    if (!_appIcon) {
        _appIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:TSConstants.appLogoName]];
        _appIcon.backgroundColor = UIColor.clearColor;
        _appIcon.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _appIcon;
}

- (UILabel *)lbEmptyBox {
    
    if (!_lbEmptyBox) {
        _lbEmptyBox = [UILabel new];
        _lbEmptyBox.numberOfLines = 0;
        _lbEmptyBox.textAlignment = NSTextAlignmentCenter;
        _lbEmptyBox.lineBreakMode = NSLineBreakByWordWrapping;
        _lbEmptyBox.font = [UIFont ows_semiboldFontWithSize:15.f];
        _lbEmptyBox.textColor = Theme.primaryTextColor;
    }
    return _lbEmptyBox;
}

- (void)applyTheme {
    
    self.lbEmptyBox.textColor = Theme.primaryTextColor;
}

@end
