//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "Theme.h"
#import "UIUtil.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/AppReadiness.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const ThemeDidChangeNotification = @"ThemeDidChangeNotification";

NSString *const ThemeCollection = @"ThemeCollection";
NSString *const ThemeKeyCurrentMode = @"ThemeKeyCurrentMode";


@interface Theme ()

@property (nonatomic) NSNumber *isDarkThemeEnabledNumber;
@property (nonatomic) NSNumber *cachedCurrentThemeNumber;

#if TESTABLE_BUILD
@property (nonatomic, nullable) NSNumber *isDarkThemeEnabledForTests;
#endif

@end

@implementation Theme

+ (SDSKeyValueStore *)keyValueStore
{
    return [[SDSKeyValueStore alloc] initWithCollection:ThemeCollection];
}

#pragma mark -

+ (Theme *)shared
{
    static dispatch_once_t onceToken;
    static Theme *instance;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] initDefault]; });

    return instance;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        // IOS-782: +[Theme shared] re-enterant initialization
        // AppReadiness will invoke the block synchronously if the app is already ready.
        // This doesn't work here, because we'll end up reenterantly calling +shared
        // if the app is in dark mode and the first call to +[Theme shared] happens
        // after the app is ready.
        //
        // It looks like that pattern is only hit in the share extension, but we're better off
        // asyncing always to ensure the dependency chain is broken. We're okay waiting, since
        // there's no guarantee that this block in synchronously executed anyway.
        dispatch_async(dispatch_get_main_queue(), ^{ [self notifyIfThemeModeIsNotDefault]; });
    });

    return self;
}

- (void)notifyIfThemeModeIsNotDefault
{
    if (self.isDarkThemeEnabled || self.defaultTheme != self.getOrFetchCurrentTheme) {
        [self themeDidChange:nil];
    }
}

#pragma mark -

+ (BOOL)isDarkThemeEnabled
{
    return [self.shared isDarkThemeEnabled];
}

- (BOOL)isDarkThemeEnabled
{
    //    OWSAssertIsOnMainThread();

#if TESTABLE_BUILD
    if (self.isDarkThemeEnabledForTests != nil) {
        return self.isDarkThemeEnabledForTests.boolValue;
    }
#endif

    if (!AppReadiness.isAppReady) {
        // Don't cache this value until it reflects the data store.
        return self.isSystemDarkThemeEnabled;
    }

    if (self.isDarkThemeEnabledNumber == nil) {
        BOOL isDarkThemeEnabled;

        if (!CurrentAppContext().isMainApp) {
            // Always respect the system theme in extensions
            isDarkThemeEnabled = self.isSystemDarkThemeEnabled;
        } else {
            switch ([self getOrFetchCurrentTheme]) {
                case ThemeMode_System:
                    isDarkThemeEnabled = self.isSystemDarkThemeEnabled;
                    break;
                case ThemeMode_Dark:
                    isDarkThemeEnabled = YES;
                    break;
                case ThemeMode_Light:
                    isDarkThemeEnabled = NO;
                    break;
            }
        }

        self.isDarkThemeEnabledNumber = @(isDarkThemeEnabled);
    }

    return self.isDarkThemeEnabledNumber.boolValue;
}

#if TESTABLE_BUILD
+ (void)setIsDarkThemeEnabledForTests:(BOOL)value
{
    self.shared.isDarkThemeEnabledForTests = @(value);
}
#endif

+ (ThemeMode)getOrFetchCurrentTheme
{
    return [self.shared getOrFetchCurrentTheme];
}

- (ThemeMode)getOrFetchCurrentTheme
{
    if (self.cachedCurrentThemeNumber) {
        return self.cachedCurrentThemeNumber.unsignedIntegerValue;
    }

    if (!AppReadiness.isAppReady) {
        return self.defaultTheme;
    }
    
    ThemeMode defaultmode = ThemeMode_Light;
    if (@available(iOS 13, *)) {
        defaultmode = ThemeMode_System;
    }
    
    __block ThemeMode currentMode;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        currentMode = (NSUInteger)[Theme.keyValueStore getDouble:ThemeKeyCurrentMode defaultValue:defaultmode transaction:transaction];
    }];

    self.cachedCurrentThemeNumber = @(currentMode);
    return currentMode;
}

+ (void)setCurrentTheme:(ThemeMode)mode
{
    [self.shared setCurrentTheme:mode];
}

- (void)setCurrentTheme:(ThemeMode)mode
{
    OWSAssertIsOnMainThread();
    
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [Theme.keyValueStore setUInt:mode key:ThemeKeyCurrentMode transaction:transaction];
    });

    NSNumber *previousMode = self.isDarkThemeEnabledNumber;

    switch (mode) {
        case ThemeMode_Light:
            self.isDarkThemeEnabledNumber = @(NO);
            break;
        case ThemeMode_Dark:
            self.isDarkThemeEnabledNumber = @(YES);
            break;
        case ThemeMode_System:
            self.isDarkThemeEnabledNumber = @(self.isSystemDarkThemeEnabled);
            break;
    }

    self.cachedCurrentThemeNumber = @(mode);

    if (![previousMode isEqual:self.isDarkThemeEnabledNumber]) {
        [self themeDidChange:nil];
    }
}

- (BOOL)isSystemDarkThemeEnabled
{
    BOOL enable = NO;
    if (@available(iOS 13, *)) {
        enable = UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    
    OWSLogInfo(@"%d", enable);
    
    return enable;
}

- (ThemeMode)defaultTheme
{
    if (@available(iOS 13, *)) {
        return ThemeMode_System;
    }

    return ThemeMode_Light;
}

#pragma mark -

+ (void)systemThemeChanged:(NSNumber *)windowLevel
{
    [self.shared systemThemeChanged:windowLevel];
}

- (void)systemThemeChanged:(NSNumber *)windowLevel
{
    // Do nothing, since we haven't setup the theme yet.
    if (self.isDarkThemeEnabledNumber == nil) {
        return;
    }

    // Theme can only be changed externally when in system mode.
    if ([self getOrFetchCurrentTheme] != ThemeMode_System) {
        return;
    }

    // The system theme has changed since the user was last in the app.
    self.isDarkThemeEnabledNumber = @(self.isSystemDarkThemeEnabled);
    [self themeDidChange:windowLevel];
}

- (void)themeDidChange:(nullable NSNumber *)windowLevel
{
    [UIUtil setupSignalAppearence];
    
    NSDictionary *userInfo = windowLevel ? @{@"windowLevel" : @(windowLevel.floatValue)} : nil;
    [UIView performWithoutAnimation:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ThemeDidChangeNotification object:nil userInfo:userInfo];
    }];
}

#pragma mark -

+ (UIColor *)defaultBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFAFAFA]);
}

+ (UIColor *)backgroundColor
{
    return (Theme.isDarkThemeEnabled ? Theme.darkThemeBackgroundColor : UIColor.ows_whiteColor);
}

+ (UIColor *)secondaryBackgroundColor
{
    // return (Theme.isDarkThemeEnabled ? UIColor.ows_gray80Color : UIColor.ows_gray02Color);
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x191919] : UIColor.ows_gray02Color);
}

+ (UIColor *)washColor
{
    return (Theme.isDarkThemeEnabled ? self.darkThemeWashColor : UIColor.ows_gray05Color);
}

+ (UIColor *)buttonDisableColor
{
    return (Theme.isDarkThemeEnabled ? self.darkThemeWashColor : UIColor.ows_lightGray02Color);
}

+ (UIColor *)darkThemeWashColor
{
    return UIColor.ows_gray75Color;
}

+ (UIColor *)primaryTextColor
{
    return (Theme.isDarkThemeEnabled ? Theme.darkThemePrimaryColor : Theme.lightThemePrimaryColor);
}

+ (UIColor *)primaryIconColor
{
    return (Theme.isDarkThemeEnabled ? self.darkThemeNavbarIconColor : UIColor.ows_gray75Color);
}

+ (UIColor *)secondaryTextColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x474D57]);
}

+ (UIColor *)secondaryTextAndIconColor
{
    return (Theme.isDarkThemeEnabled ? Theme.darkThemeSecondaryTextAndIconColor : UIColor.ows_gray60Color);
}
+ (UIColor *)thirdTextAndIconColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xB7BDC6]);
}

+ (UIColor *)darkThemeSecondaryTextAndIconColor
{
    return UIColor.ows_gray25Color;
}

+ (UIColor *)ternaryTextColor
{
    return UIColor.ows_gray45Color;
}

+ (UIColor *)boldColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_whiteColor : UIColor.blackColor);
}

+ (UIColor *)middleGrayColor
{
    return [UIColor colorWithWhite:0.5f alpha:1.f];
}

+ (UIColor *)placeholderColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray45Color : UIColor.ows_gray45Color);
}

+ (UIColor *)hairlineColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF]);
}

+ (UIColor *)outlineColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray75Color : UIColor.ows_gray15Color;
}

+ (UIColor *)backdropColor
{
    return UIColor.ows_blackAlpha40Color;
}

+ (UIColor *)stickBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xFAFAFA]);
}

+ (UIColor *)blankBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xF0F0F0]);
}
+ (UIColor *)redBgroundColor
{
    return [UIColor colorWithRGBHex:0xF84135];
}


#pragma mark - Global App Colors

+ (UIColor *)navbarBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? self.darkThemeNavbarBackgroundColor : UIColor.ows_whiteColor);
}

+ (UIColor *)darkThemeNavbarBackgroundColor
{
    return [UIColor colorWithRGBHex:0x111111];//UIColor.ows_blackColor;
}

+ (UIColor *)tabbarBackgroundColor {
    return (Theme.isDarkThemeEnabled ? self.darkThemeTabbarBackgroundColor : UIColor.ows_whiteColor);
}

+ (UIColor *)darkThemeTabbarBackgroundColor {
    return UIColor.ows_blackColor;//[UIColor colorWithRGBHex:0x1C1D1E];
}

+ (UIColor *)darkThemeNavbarIconColor
{
    return UIColor.ows_gray15Color;
}

+ (UIColor *)navbarTitleColor
{
    return Theme.primaryTextColor;
}

+ (UIColor *)tabbarTitleNormalColor {
    return Theme.isDarkThemeEnabled ? UIColor.ows_tabbarNormalDarkColor : UIColor.ows_tabbarNormalColor;
}

+ (UIColor *)tabbarTitleSelectedColor {
    return Theme.isDarkThemeEnabled ? UIColor.ows_themeBlueDarkColor : UIColor.ows_themeBlueColor;
}

+ (UIColor *)toolbarBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? self.darkThemeNavbarBackgroundColor : UIColor.ows_whiteColor);
//    return self.navbarBackgroundColor;
}

+ (UIColor *)conversationInputBackgroundColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xF5F5F5];
}
+ (UIColor *)translateBackgroundColor
{
//    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray181818Color : UIColor.whiteColor);
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray85Color : UIColor.ows_gray05Color);
//    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray90Color : UIColor.whiteColor);
    
//    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray75Color : UIColor.ows_gray05Color);
}

+ (UIColor *)attachmentKeyboardItemBackgroundColor
{
    return self.conversationInputBackgroundColor;
}

+ (UIColor *)bubleOutgoingBackgroundColor {
    
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x003366] : [UIColor colorWithRGBHex:0xEBF7FF];
}

+ (UIColor *)attachmentKeyboardItemImageColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xd8d8d9] : [UIColor colorWithRGBHex:0x636467]);
}

+ (UIColor *)cellSelectedColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithWhite:0.2 alpha:1] : [UIColor colorWithWhite:0.92 alpha:1]);
}

+ (UIColor *)cellSeparatorColor
{
    return [Theme.hairlineColor colorWithAlphaComponent:0.2];
}

+ (UIColor *)indicatorLineColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x82C1FC] : [UIColor colorWithRGBHex:0x056FFA];
}

+ (UIColor *)cursorColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_whiteColor : UIColor.ows_accentBlueColor;
}

+ (UIColor *)hyperLinkColor {
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x7f90a6] : [UIColor colorWithRGBHex:0x596b92];
}

+ (UIColor *)accentBlueColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_accentBlueDarkColor : UIColor.ows_accentBlueColor;
}

+ (UIColor *)themeBlueColor {
    return Theme.isDarkThemeEnabled ? UIColor.ows_themeBlueDarkColor : UIColor.ows_themeBlueColor;
}

+ (UIColor *)themeBlueColor2 {
    return Theme.isDarkThemeEnabled ? UIColor.ows_themeBlueDark2Color : UIColor.ows_themeBlueColor;
}

+ (UIColor *)defaultTableCellBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xFFFFFF]);
}

+ (UIColor *)tableCellBackgroundColor
{
    return Theme.backgroundColor;
}

+ (UIColor *)tableSettingCellBackgroundColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor whiteColor];
}

+ (UIColor *)tableViewBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFAFAFA]);
}

+ (UIColor *)tableCell2BackgroundColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray90Color : UIColor.ows_whiteColor;
}

+ (UIColor *)tableCell2PresentedBackgroundColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray80Color : UIColor.ows_whiteColor;
}

+ (UIColor *)tableCellSelectedBackgroundColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x1E2329] : [UIColor colorWithRGBHex:0xECECEC];
}

+ (UIColor *)tableCell2SelectedBackgroundColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray80Color : UIColor.ows_gray15Color;
}

+ (UIColor *)tableCell2PresentedSelectedBackgroundColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray75Color : UIColor.ows_gray15Color;
}

+ (UIColor *)tableView2BackgroundColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_blackColor : UIColor.ows_gray10Color);
}

+ (UIColor *)tableView2PresentedBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray90Color : UIColor.ows_gray10Color);
}

+ (UIColor *)tableView2SeparatorColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray75Color : UIColor.ows_gray20Color);
}

+ (UIColor *)tableView2PresentedSeparatorColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray65Color : UIColor.ows_gray20Color);
}

+ (UIColor *)darkThemeBackgroundColor
{
    return [UIColor colorWithRGBHex:0x181A20];//UIColor.ows_blackColor;
}

+ (UIColor *)darkThemePrimaryColor
{
    return [UIColor colorWithRGBHex:0xEAECEF];//UIColor.ows_gray02Color;
}

+ (UIColor *)lightThemePrimaryColor
{
    return [UIColor colorWithRGBHex:0x1E2329];
}

+ (UIColor *)galleryHighlightColor
{
    return [UIColor colorWithRGBHex:0x1f8fe8];
}

+ (UIColor *)conversationButtonBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray80Color : UIColor.ows_gray02Color);
}

+ (UIColor *)conversationButtonTextColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray05Color : UIColor.ows_accentBlueColor);
}


+ (UIBlurEffect *)barBlurEffect
{
    return Theme.isDarkThemeEnabled ? self.darkThemeBarBlurEffect
                                    : [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

+ (UIBlurEffect *)darkThemeBarBlurEffect
{
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
}

+ (UIKeyboardAppearance)keyboardAppearance
{
    return Theme.isDarkThemeEnabled ? self.darkThemeKeyboardAppearance : UIKeyboardAppearanceDefault;
}

+ (UIColor *)keyboardBackgroundColor
{
    return Theme.isDarkThemeEnabled ? UIColor.ows_gray90Color : UIColor.ows_gray02Color;
}

+ (UIKeyboardAppearance)darkThemeKeyboardAppearance
{
    return UIKeyboardAppearanceDark;
}

#pragma mark - Search Bar

+ (UIBarStyle)barStyle
{
    return Theme.isDarkThemeEnabled ? UIBarStyleBlack : UIBarStyleDefault;
}

+ (UIColor *)searchFieldBackgroundColor
{
    return Theme.washColor;
}

#pragma mark -

+ (UIColor *)toastForegroundColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_whiteColor : UIColor.ows_whiteColor);
}

+ (UIColor *)toastBackgroundColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_gray75Color : UIColor.ows_gray60Color);
}

+ (UIColor *)scrollButtonBackgroundColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithWhite:0.25f alpha:1.f]
                                    : [UIColor colorWithWhite:0.95f alpha:1.f];
}

+ (UIColor *)alertConfirmColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_alertConfirmDarkBlueColor : UIColor.ows_alertConfirmLightBlueColor);
}

+ (UIColor *)alertCancelColor
{
    return (Theme.isDarkThemeEnabled ? UIColor.ows_alertCancelDarkColor : UIColor.ows_alertCancelLightColor);
}

+ (UIColor *)destructiveRed {
    return (Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xF84035] : [UIColor colorWithRGBHex:0xD9271E]);
}

@end

NS_ASSUME_NONNULL_END
