//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "UIUtil.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import "SVProgressHUD.h"
#import <TTServiceKit/AppContext.h>
#import <TTMessaging/TTMessaging-Swift.h>

#define CONTACT_PICTURE_VIEW_BORDER_WIDTH 0.5f

@implementation UIUtil

+ (void)applyRoundedBorderToImageView:(UIImageView *)imageView
{
    imageView.layer.borderWidth = CONTACT_PICTURE_VIEW_BORDER_WIDTH;
    imageView.layer.borderColor = [UIColor clearColor].CGColor;
    imageView.layer.cornerRadius = CGRectGetWidth(imageView.frame) / 2;
    imageView.layer.masksToBounds = YES;
}

+ (void)removeRoundedBorderToImageView:(UIImageView *__strong *)imageView
{
    [[*imageView layer] setBorderWidth:0];
    [[*imageView layer] setCornerRadius:0];
}

+ (void)setupSignalAppearence
{
    UINavigationBar.appearance.barTintColor = Theme.bg1Color; // Theme.bg1Color;
    UINavigationBar.appearance.tintColor = Theme.iconColor;
    UITabBar.appearance.barTintColor = Theme.bg1Color;
    UITabBar.appearance.tintColor = Theme.tinfoColor;
    UIToolbar.appearance.barTintColor = Theme.bg1Color;
    UIToolbar.appearance.tintColor = UIColor.ows_accentBlueColor;

    [[UISwitch appearance] setOnTintColor:UIColor.ows_themeBlueColor];
    [[UISwitch appearance] setTintColor:Theme.lineColor];

    // 设置导航栏按钮（包括返回按钮）的字体，使用固定大小（忽略系统 Dynamic Type）
    UIFont *barButtonFont = [[UIFont ows_regularFontWithSize:17.0] scaledWithShouldScale:YES];
    NSDictionary *barButtonAttributes = @{
        NSFontAttributeName: barButtonFont
    };

    // 为所有状态设置字体
    [[UIBarButtonItem appearance] setTitleTextAttributes:barButtonAttributes forState:UIControlStateNormal];
    [[UIBarButtonItem appearance] setTitleTextAttributes:barButtonAttributes forState:UIControlStateHighlighted];
    [[UIBarButtonItem appearance] setTitleTextAttributes:barButtonAttributes forState:UIControlStateDisabled];

    // iOS 15+ 需要额外设置 UINavigationBarAppearance
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.backgroundColor = Theme.bg1Color;

        // 设置导航栏标题字体
        UIFont *navBarTitleFont = [[UIFont ows_semiboldFontWithSize:17.0] scaledWithShouldScale:YES];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: Theme.tprimaryColor,
            NSFontAttributeName: navBarTitleFont
        };

        // 设置返回按钮字体
        UIBarButtonItemAppearance *buttonAppearance = [[UIBarButtonItemAppearance alloc] init];
        buttonAppearance.normal.titleTextAttributes = barButtonAttributes;
        buttonAppearance.highlighted.titleTextAttributes = barButtonAttributes;
        buttonAppearance.disabled.titleTextAttributes = barButtonAttributes;
        appearance.buttonAppearance = buttonAppearance;
        appearance.backButtonAppearance = buttonAppearance;

        UINavigationBar.appearance.standardAppearance = appearance;
        UINavigationBar.appearance.scrollEdgeAppearance = appearance;
        UINavigationBar.appearance.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            UINavigationBar.appearance.compactScrollEdgeAppearance = appearance;
        }
    }

    // We do _not_ specifiy BarButton.appearance.tintColor because it is sufficient to specify
    // UINavigationBar.appearance.tintColor. Furthermore, specifying the BarButtonItem's
    // apearence makes it more difficult to override the navbar theme, e.g. how we _always_
    // use dark theme in the media send flow and gallery views. If we were specifying
    // barButton.appearence.tintColor we would then have to manually override each BarButtonItem's
    // tint, rather than just the navbars.
    //
    // UIBarButtonItem.appearance.tintColor = Theme.iconColor;

    // Using the keyboardAppearance causes crashes due to a bug in UIKit.
    //    UITextField.appearance.keyboardAppearance = (Theme.isDarkThemeEnabled
    //                                                 ? UIKeyboardAppearanceDark
    //                                                 : UIKeyboardAppearanceDefault);
    //    UITextView.appearance.keyboardAppearance = (Theme.isDarkThemeEnabled
    //                                                 ? UIKeyboardAppearanceDark
    //                                                 : UIKeyboardAppearanceDefault);

    [[UITableViewCell appearance] setTintColor:Theme.iconColor];

    // 设置导航栏标题字体（iOS 14 及以下）
    UIFont *navBarTitleFont = [[UIFont ows_semiboldFontWithSize:17.0] scaledWithShouldScale:YES];
    UINavigationBar.appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName : Theme.tprimaryColor,
        NSFontAttributeName : navBarTitleFont
    };

    [DTToastHelper setupSVProgressHUDAppearence];
}

@end
