//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSQRCodeScanningViewController.h"
#import <TTMessaging/OWSViewController.h>

NS_ASSUME_NONNULL_BEGIN

@class OWSLinkedDevicesTableViewController;

@interface OWSLinkDeviceViewController : OWSViewController <OWSQRScannerDelegate>

@property OWSLinkedDevicesTableViewController *linkedDevicesTableViewController;

@end

NS_ASSUME_NONNULL_END
