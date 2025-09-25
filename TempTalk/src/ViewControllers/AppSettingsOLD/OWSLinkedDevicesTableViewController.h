//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    DTLinkDeviceFromMe = 0,
    DTLinkDeviceFromScan = 1
} DTLinkDeviceFrom;

@interface OWSLinkedDevicesTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate>

/**
 * This is used to show the user there is a device provisioning in-progress.
 */
- (void)expectMoreDevices;

@property (assign, nonatomic) DTLinkDeviceFrom linkFrom;

@end
