//
//  DFTabbarController.m
//  Signal
//
//  Created by Felix on 2021/7/12.
//

#import "DFTabbarController.h"
#import <TTMessaging/Theme.h>
#import "UIImage+OWS.h"
#import "UIColor+OWS.h"

#import <TTServiceKit/Localize_Swift.h>
#import <TTServiceKit/TTServiceKit-swift.h>
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/DTThreadHelper.h>
#import "TempTalk-Swift.h"
#import "UITabBar+BadgeCount.h"

NSString *const kTabBarItemDoubleClickNotification = @"kTabBarItemDoubleClickNotification";

@interface DFTabbarController ()<UITabBarControllerDelegate>
@property (strong, nonatomic) NSDate *lastDate;
@property (nonatomic, assign) NSUInteger allUnMutedUnreadCount;
@property (nonatomic, assign) NSUInteger allMutedUnReadCount;
@property (nonatomic, assign) NSUInteger allUnreadCount;
@property (nonatomic, assign) NSUInteger scheduleEventCount;

@end

@implementation DFTabbarController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange:)
                                                 name:ThemeDidChangeNotification
                                               object:nil];
    [[DTThreadHelper sharedManager] loadUnReadThread];
    [[DTThreadHelper sharedManager] observerAllUnReadMessageCount];
    [[DTThreadHelper sharedManager] addObserver:self forKeyPath:@"allUnMutedUnreadCount" options:NSKeyValueObservingOptionNew context:NULL];
    [[DTThreadHelper sharedManager] addObserver:self forKeyPath:@"allMutedUnReadCount" options:NSKeyValueObservingOptionNew context:NULL];
    [[DTThreadHelper sharedManager] addObserver:self forKeyPath:@"allUnreadCount" options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(languageDidChange:)
                                                 name:LCLLanguageChangeNotification
                                               object:nil];
    [self applyTheme];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self loadUnreadCount];
}

- (void)applicationDidBecomeActive {
    [self loadUnreadCount];
}

- (void)applicationWillResignActive {
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:(NSInteger)self.allUnMutedUnreadCount];
}

- (void)loadUnreadCount {
    [[DTThreadHelper sharedManager] loadUnReadThread];
    self.allUnMutedUnreadCount = [DTThreadHelper sharedManager].allUnMutedUnreadCount;
    self.allMutedUnReadCount = [DTThreadHelper sharedManager].allMutedUnReadCount;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqual:@"allUnMutedUnreadCount"]) {
        self.allUnMutedUnreadCount = [((NSNumber *)change[NSKeyValueChangeNewKey]) unsignedIntegerValue];
    } else if ([keyPath isEqual:@"allMutedUnReadCount"]){
        self.allMutedUnReadCount = [((NSNumber *)change[NSKeyValueChangeNewKey]) unsignedIntegerValue];
    } else if ([keyPath isEqual:@"allUnreadCount"]){
        self.allUnreadCount = [((NSNumber *)change[NSKeyValueChangeNewKey]) unsignedIntegerValue];
    }
}

- (void)setAllUnreadCount:(NSUInteger)allUnreadCount {
//    [UIApplication.sharedApplication setApplicationIconBadgeNumber:(NSInteger)allUnreadCount];
}

- (void)setAllMutedUnReadCount:(NSUInteger)allMutedUnReadCount {
    @synchronized (self) {
        _allMutedUnReadCount = allMutedUnReadCount;
        if(self.allUnMutedUnreadCount) {
            return;
        }
        if (![self.viewControllers.firstObject isKindOfClass:OWSNavigationController.class]) return;
        OWSNavigationController *homeNav = self.viewControllers.firstObject;
        if (![homeNav.viewControllers.firstObject isKindOfClass:NSClassFromString(@"DTHomeViewController")]) return;
        if (allMutedUnReadCount <= 0) {
            homeNav.tabBarItem.badgeValue = nil;
        } else if (allMutedUnReadCount > 0 && allMutedUnReadCount < 100) {
            homeNav.tabBarItem.badgeValue = [NSString stringWithFormat:@"%lu",(unsigned long)allMutedUnReadCount];
            [self setBadgeStyleWithBackgroundColorWithColor:[UIColor colorWithRGBHex:0x8B8B8B] lightBackgroundColor:[UIColor colorWithRGBHex:0xCCCCCC] darkThemeTextColor:UIColor.blackColor lightThemeTextColor:UIColor.whiteColor];
        } else {
            homeNav.tabBarItem.badgeValue = @"99+";
            [self setBadgeStyleWithBackgroundColorWithColor:[UIColor colorWithRGBHex:0x8B8B8B] lightBackgroundColor:[UIColor colorWithRGBHex:0xCCCCCC] darkThemeTextColor:UIColor.blackColor lightThemeTextColor:UIColor.whiteColor];
        }
    }
}

- (void)setAllUnMutedUnreadCount:(NSUInteger)allUnMutedUnreadCount {
    if (_allUnMutedUnreadCount == allUnMutedUnreadCount) {return;}
    @synchronized (self) {
        _allUnMutedUnreadCount = allUnMutedUnreadCount;
        [UIApplication sharedApplication].applicationIconBadgeNumber = (NSInteger)allUnMutedUnreadCount;
        if (![self.viewControllers.firstObject isKindOfClass:OWSNavigationController.class]) return;
        OWSNavigationController *homeNav = self.viewControllers.firstObject;
        if (![homeNav.viewControllers.firstObject isKindOfClass:NSClassFromString(@"DTHomeViewController")]) return;
        if (allUnMutedUnreadCount <= 0) {
            NSUInteger allMutedUnReadCount = self.allMutedUnReadCount;
            if (allMutedUnReadCount) {
                self.allMutedUnReadCount = allMutedUnReadCount;
            } else {
                homeNav.tabBarItem.badgeValue = nil;
            }
            
        } else if (allUnMutedUnreadCount > 0 && allUnMutedUnreadCount < 100) {
            homeNav.tabBarItem.badgeValue = [NSString stringWithFormat:@"%lu",(unsigned long)allUnMutedUnreadCount];
            [self setBadgeStyleWithBackgroundColorWithColor:Theme.redBgroundColor lightBackgroundColor:Theme.redBgroundColor darkThemeTextColor:UIColor.whiteColor lightThemeTextColor:UIColor.whiteColor];
        } else {
            homeNav.tabBarItem.badgeValue = @"99+";
            [self setBadgeStyleWithBackgroundColorWithColor:Theme.redBgroundColor lightBackgroundColor:Theme.redBgroundColor darkThemeTextColor:UIColor.whiteColor lightThemeTextColor:UIColor.whiteColor];
        }
        
    }
}

- (void)setBadgeStyleWithBackgroundColorWithColor:(UIColor *)darkBackgroundColor
                             lightBackgroundColor:(UIColor *) lightBackgroundColor
                               darkThemeTextColor:(UIColor *)darkThemeTextColor
                               lightThemeTextColor:(UIColor *)lightThemeTextColor {
    UIColor *badgeTextColor = Theme.isDarkThemeEnabled ? darkThemeTextColor : lightThemeTextColor;
    NSDictionary <NSAttributedStringKey,id> *badgeTextAttributes = @{NSForegroundColorAttributeName : badgeTextColor, NSFontAttributeName : [UIFont systemFontOfSize:13]};

    UITabBarAppearance *tabBarAppearance = [self getCurrentTabBarAppearance];
    UITabBarItemAppearance * tabBarItemAppearance = tabBarAppearance.stackedLayoutAppearance;
    tabBarItemAppearance.normal.badgeBackgroundColor = Theme.isDarkThemeEnabled ? darkBackgroundColor: lightBackgroundColor;
    tabBarItemAppearance.normal.badgeTextAttributes = badgeTextAttributes;
    if (@available(iOS 15.0, *)) {
        self.tabBar.scrollEdgeAppearance = tabBarAppearance;
    }
    self.tabBar.standardAppearance = tabBarAppearance;
}

- (void)reloadTodayScheduleEventCount:(NSUInteger)eventCount {
    @synchronized (self) {
        if(_scheduleEventCount == eventCount) {
            return;
        }
        _scheduleEventCount = eventCount;
        
        DispatchMainThreadSafe(^{
            [self.tabBar updateBadgeOnItem:1 badgeValue:eventCount];
        });
    }
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    OWSNavigationController *vc = tabBarController.selectedViewController;
    NSUInteger selectedIndex = tabBarController.selectedIndex;
    NSDate *date = [NSDate new];
    if ([vc isEqual:viewController]) {
        // 处理双击事件
        if (date.timeIntervalSince1970 - _lastDate.timeIntervalSince1970 <= 0.38) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kTabBarItemDoubleClickNotification object:nil userInfo:@{@"selectedIndex" : @(selectedIndex)}];
            if (selectedIndex == 1) {
                [self reloadTodayScheduleEventCount:0];
                DTCalendarManager.shared.isDisplayBadge = NO;
            }
        }
        _lastDate = date;
        
        return NO;
    }
    return YES;
}

- (void)dealloc {
    [[DTThreadHelper sharedManager] removeObserver:self forKeyPath:@"allUnMutedUnreadCount"];
    [[DTThreadHelper sharedManager] removeObserver:self forKeyPath:@"allMutedUnReadCount"];
    [[DTThreadHelper sharedManager] removeObserver:self forKeyPath:@"allUnreadCount"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - Theme

- (void)themeDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    NSDictionary *userInfo = notification.userInfo;
    NSNumber *windowLevel = userInfo[@"windowLevel"];
    if (userInfo != nil && windowLevel.floatValue != 0.0) return;

    [self applyTheme];
}

- (void)languageDidChange:(NSNotification *)notification {
    for (UIViewController *vc in self.viewControllers) {
        if([vc isKindOfClass:UINavigationController.class]){
            UINavigationController *nav = (UINavigationController *)vc;
            UIViewController *nav_root = nav.viewControllers.firstObject;
            if([nav_root isKindOfClass:NSClassFromString(@"DTHomeViewController")]){
                nav_root.tabBarItem.title = [Localize localized:@"TABBAR_HOME"];
            }
            if([nav_root isKindOfClass:NSClassFromString(@"DTMeetingListController")]){
                nav_root.tabBarItem.title = [Localize localized:@"TABBAR_CALENDARS"];
            }
            if([nav_root isKindOfClass:NSClassFromString(@"DTContactsViewController")]){
                nav_root.tabBarItem.title = [Localize localized:@"TABBAR_CONTACT"];
            }
            if([nav_root isKindOfClass: NSClassFromString(@"AppSettingsViewController")]){
                nav_root.tabBarItem.title = [Localize localized:@"TABBAR_ME"];
            }
        }
    }
}

- (UITabBarAppearance *)getCurrentTabBarAppearance {
    return self.tabBar.standardAppearance;
}

- (void)applyTheme {
    UITabBarAppearance *appearance = [UITabBarAppearance new];
    appearance.shadowColor = Theme.hairlineColor;
    appearance.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor whiteColor];
    UITabBarItemAppearance *tabBarItemAppearance = [UITabBarItemAppearance new];
    tabBarItemAppearance.normal.iconColor = Theme.tabbarTitleNormalColor;
    tabBarItemAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName : Theme.tabbarTitleNormalColor, NSFontAttributeName : [UIFont systemFontOfSize:13]};
    tabBarItemAppearance.selected.titleTextAttributes = @{NSForegroundColorAttributeName : Theme.tabbarTitleSelectedColor, NSFontAttributeName : [UIFont systemFontOfSize:13]};
    if (self.allUnMutedUnreadCount > 0) {
        NSDictionary <NSAttributedStringKey,id> *badgeTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName : [UIFont systemFontOfSize:13]};
        tabBarItemAppearance.normal.badgeTextAttributes = badgeTextAttributes;
        tabBarItemAppearance.normal.badgeBackgroundColor = Theme.redBgroundColor;
    } else if(self.allUnMutedUnreadCount <= 0 && self.allMutedUnReadCount > 0){
        UIColor *badgeTextColor = Theme.isDarkThemeEnabled ? UIColor.blackColor : UIColor.whiteColor;
        NSDictionary <NSAttributedStringKey,id> *badgeTextAttributes = @{NSForegroundColorAttributeName: badgeTextColor, NSFontAttributeName : [UIFont systemFontOfSize:13]};
        tabBarItemAppearance.normal.badgeTextAttributes = badgeTextAttributes;
        tabBarItemAppearance.normal.badgeBackgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x8B8B8B] : [UIColor colorWithRGBHex:0xCCCCCC];
    }
    appearance.stackedLayoutAppearance = tabBarItemAppearance;
    if (@available(iOS 15.0, *)) {
        self.tabBar.scrollEdgeAppearance = appearance;
    }
    self.tabBar.standardAppearance = appearance;
}

//是否自动旋转
-(BOOL)shouldAutorotate{
    return self.selectedViewController.shouldAutorotate;
}

//支持哪些屏幕方向
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return [self.selectedViewController supportedInterfaceOrientations];
}

//默认方向
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [self.selectedViewController preferredInterfaceOrientationForPresentation];
}

@end
