//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NotificationSettingsOptionsViewController.h"
#import "Yelling-Swift.h"
#import "SignalApp.h"
#import <TTMessaging/Environment.h>
#import <TTMessaging/TTMessaging.h>
#import <TTServiceKit/Localize_Swift.h>

@interface NotificationSettingsOptionsViewController () <OWSNavigationChildController>

@end

@implementation NotificationSettingsOptionsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableView.backgroundColor = Theme.bgpageSecondaryColor;
    [self updateTableContents];
}

- (void)applyTheme {
    [super applyTheme];
    self.view.backgroundColor = Theme.bgpageSecondaryColor;
    self.tableView.backgroundColor = Theme.bgpageSecondaryColor;
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak NotificationSettingsOptionsViewController *weakSelf = self;

    OWSTableSection *section = [OWSTableSection new];
    section.footerTitle = Localized(@"NOTIFICATIONS_FOOTER_WARNING", nil);

    OWSPreferences *prefs = [Environment preferences];
    NotificationType selectedNotifType = [prefs notificationPreviewType];
    for (NSNumber *option in
        @[ @(NotificationNamePreview), @(NotificationNameNoPreview), @(NotificationNoNameNoPreview) ]) {
        NotificationType notificationType = (NotificationType)option.intValue;

        [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
            UITableViewCell *cell = [UITableViewCell new];
            [[cell textLabel] setText:[prefs nameForNotificationPreviewType:notificationType]];
            if (selectedNotifType == notificationType) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            return cell;
        }
                             actionBlock:^{
                                 [weakSelf setNotificationType:notificationType];
                             }]];
    }
    [contents addSection:section];

    self.contents = contents;
}

- (void)setNotificationType:(NotificationType)notificationType
{
    [Environment.preferences setNotificationPreviewType:notificationType];

    // rebuild callUIAdapter since notification configuration changed.
//    [SignalApp.sharedApp.callService createCallUIAdapter];

    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack {
    return false;
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    return Theme.bgpageSecondaryColor;
}

- (BOOL)prefersNavigationBarHidden {
    return NO;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
}
@end
