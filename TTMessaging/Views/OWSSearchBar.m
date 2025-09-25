//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSSearchBar.h"
#import "Theme.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSSearchBar ()<UITextFieldDelegate>

@property (nonatomic, strong) NSMutableArray <NSLayoutConstraint *> *textFieldConstraints;
@property (nonatomic, assign) UIEdgeInsets edgeInsets;
@end

@implementation OWSSearchBar

- (instancetype)init {
    
    if (self = [super init]) {
        self.edgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        self.searchBarStyle = UISearchBarStyleMinimal;
        [self configureWithShowsCancel:NO];
        [self applyTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(themeDidChange:)
                                                     name:ThemeDidChangeNotification
                                                   object:nil];

    }

    return self;
}

- (instancetype)initWithShowsCancel:(BOOL)showsCancel {
    if (self = [super init]) {
        self.edgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        self.searchBarStyle = UISearchBarStyleMinimal;
        [self configureWithShowsCancel:showsCancel];
        [self applyTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(themeDidChange:)
                                                     name:ThemeDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (instancetype)initWithShowsCancel:(BOOL)showsCancel edgeInset:(UIEdgeInsets) edgeInset {
    if (self = [super init]) {
        self.edgeInsets = edgeInset;
        self.searchBarStyle = UISearchBarStyleMinimal;
        [self configureWithShowsCancel:showsCancel];
        [self applyTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(themeDidChange:)
                                                     name:ThemeDidChangeNotification
                                                   object:nil];

    }
    return self;

}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    if (self = [super initWithCoder:aDecoder]) {
        [self configureWithShowsCancel:NO];
        [self applyTheme];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(themeDidChange:)
                                                     name:ThemeDidChangeNotification
                                                   object:nil];
    }

    return self;
}

- (void)configureWithShowsCancel:(BOOL)showsCancel {
    self.showsCancelButton = showsCancel;
    
    [self setImage:[UIImage imageNamed:@"ic_search"] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
    [self setPositionAdjustment:UIOffsetMake(4, 0) forSearchBarIcon:UISearchBarIconSearch];
    [self setValue:@"取消00" forKey:@"cancelButtonText"];
    self.textField.delegate = self;
    self.textField.layer.cornerRadius = 8;
    self.textField.layer.masksToBounds = YES;
    self.textField.font = [UIFont systemFontOfSize:14];
    if (!showsCancel) {
        [self.textField autoSetDimension:ALDimensionHeight toSize:36];
        [self.textField autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:self.edgeInsets.left];
        [self.textField autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:self.edgeInsets.right];
        [self.textField autoCenterInSuperview];
    }
    [self traverseViewHierarchyDownwardWithVisitor:^(UIView *view) {
        if ([view isKindOfClass:NSClassFromString(@"UIButtonLabel")]) {
            UILabel *lbCancel = (UILabel *)view;
            if ([lbCancel.text isEqualToString:@"Cancel"] || [lbCancel.text isEqualToString:@"取消"]) {
                lbCancel.textColor = Theme.alertCancelColor;
                lbCancel.font = [UIFont systemFontOfSize:15];
            }
        }
    }];
    UIButton *cancelButton = [self valueForKey:@"cancelButton"];
    [cancelButton setTitle:Localized(@"CANCEL", @"") forState:UIControlStateNormal];
}

- (void)setCustomPlaceholder:(NSString *)customPlaceholder {
    _customPlaceholder = customPlaceholder;
    
    [self setAttributePlaceholder:customPlaceholder];
}

- (void)setAttributePlaceholder:(NSString *)placeholder API_AVAILABLE(ios(13.0)) {
    self.searchTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:14], NSForegroundColorAttributeName : Theme.thirdTextAndIconColor}];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeDidChange:(NSNotification *)noti {
    
    OWSAssertIsOnMainThread();
    NSDictionary *userInfo = noti.userInfo;
    NSNumber *windowLevel = userInfo[@"windowLevel"];
    if (userInfo != nil && windowLevel.floatValue != 0.0) return;

    [self applyTheme];
}

- (void)applyTheme
{
    self.backgroundColor = Theme.backgroundColor;
    self.barTintColor = Theme.primaryTextColor;
    self.textField.tintColor = Theme.primaryTextColor;
    self.textField.textColor = Theme.primaryTextColor;
    if (self.customPlaceholder) {
        [self setAttributePlaceholder:self.customPlaceholder];
    }
    UIImage *backgroundImage = [UIImage imageWithColor:Theme.stickBackgroundColor size:CGSizeMake(kScreenWidth - 70, 36)];
    [self setSearchFieldBackgroundImage:backgroundImage forState:UIControlStateNormal];
}

+ (void)applyThemeToSearchBar:(UISearchBar *)searchBar style:(OWSSearchBarStyle)style
{
    OWSAssertIsOnMainThread();

//    UIColor *foregroundColor = Theme.secondaryTextAndIconColor;
//    searchBar.tintColor = Theme.secondaryTextAndIconColor;
    searchBar.barStyle = Theme.barStyle;
//    searchBar.barTintColor = Theme.backgroundColor;

    // Hide searchBar border.
    // Alternatively we could hide the border by using `UISearchBarStyleMinimal`, but that causes an issue when toggling
    // from light -> dark -> light theme wherein the textField background color appears darker than it should
    // (regardless of our re-setting textfield.backgroundColor below).
    
//    searchBar.backgroundImage = [UIImage new];

    /*
    if (Theme.isDarkThemeEnabled) {
        UIImage *clearImage = [UIImage imageNamed:@"searchbar_clear"];
        [searchBar setImage:[clearImage asTintedImageWithColor:foregroundColor]
            forSearchBarIcon:UISearchBarIconClear
                       state:UIControlStateNormal];

        UIImage *searchImage = [UIImage imageNamed:@"searchbar_search"];
        [searchBar setImage:[searchImage asTintedImageWithColor:foregroundColor]
            forSearchBarIcon:UISearchBarIconSearch
                       state:UIControlStateNormal];
    } else {
        [searchBar setImage:nil forSearchBarIcon:UISearchBarIconClear state:UIControlStateNormal];

        [searchBar setImage:nil forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
    }

    UIColor *searchFieldBackgroundColor = Theme.searchFieldBackgroundColor;
    if (style == OWSSearchBarStyle_SecondaryBar) {
        searchFieldBackgroundColor = Theme.isDarkThemeEnabled ? UIColor.ows_gray95Color : UIColor.ows_gray05Color;
    } else if ([searchBar isKindOfClass:[OWSSearchBar class]]
        && ((OWSSearchBar *)searchBar).searchFieldBackgroundColorOverride) {
        searchFieldBackgroundColor = ((OWSSearchBar *)searchBar).searchFieldBackgroundColorOverride;
    }
*/
    [searchBar traverseViewHierarchyDownwardWithVisitor:^(UIView *view) {
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
//            textField.backgroundColor = searchFieldBackgroundColor;
//            textField.textColor = Theme.primaryTextColor;
//            textField.keyboardAppearance = Theme.keyboardAppearance;
            [textField autoPinEdgesToSuperviewMargins];
        }
    }];
}

@end

NS_ASSUME_NONNULL_END
