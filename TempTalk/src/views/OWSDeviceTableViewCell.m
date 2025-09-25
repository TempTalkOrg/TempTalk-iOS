//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSDeviceTableViewCell.h"
#import "DateUtil.h"
#import <TTMessaging/Theme.h>
#import <TTServiceKit/Localize_Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSDeviceTableViewCell

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.nameLabel.textColor = Theme.primaryTextColor;
    self.linkedLabel.textColor = Theme.secondaryTextAndIconColor;
    self.lastSeenLabel.textColor = Theme.ternaryTextColor;
}


- (void)configureWithDevice:(OWSDevice *)device
{
    self.nameLabel.textColor = Theme.primaryTextColor;
    self.linkedLabel.textColor = Theme.secondaryTextAndIconColor;
    self.lastSeenLabel.textColor = Theme.ternaryTextColor;
    
    self.nameLabel.text = device.displayName;

    NSString *linkedFormatString
        = Localized(@"DEVICE_LINKED_AT_LABEL", @"{{Short Date}} when device was linked.");
    self.linkedLabel.text =
        [NSString stringWithFormat:linkedFormatString, [DateUtil.dateFormatter stringFromDate:device.createdAt]];

    NSString *lastSeenFormatString = Localized(
        @"DEVICE_LAST_ACTIVE_AT_LABEL", @"{{Short Date}} when device last communicated with Signal Server.");

    NSDate *displayedLastSeenAt;
    // lastSeenAt is stored at day granularity. At midnight UTC.
    // Making it likely that when you first link a device it will
    // be "last seen" the day before it was created, which looks broken.
    if ([device.lastSeenAt compare:device.createdAt] == NSOrderedDescending) {
        displayedLastSeenAt = device.lastSeenAt;
    } else {
        displayedLastSeenAt = device.createdAt;
    }

    self.lastSeenLabel.text =
        [NSString stringWithFormat:lastSeenFormatString, [DateUtil.dateFormatter stringFromDate:displayedLastSeenAt]];
}

@end

NS_ASSUME_NONNULL_END
