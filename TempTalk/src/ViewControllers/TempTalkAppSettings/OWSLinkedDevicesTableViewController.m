//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSLinkedDevicesTableViewController.h"
#import "OWSDeviceTableViewCell.h"
#import "OWSLinkDeviceViewController.h"
#import "TempTalk-Swift.h"
#import "UIViewController+Permissions.h"
#import <TTServiceKit/NSTimer+OWS.h>
#import <TTServiceKit/OWSDevice.h>
#import <TTServiceKit/OWSDevicesService.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSLinkedDevicesTableViewController ()

@property (nonatomic) NSArray<OWSDevice *> *items;
@property (nonatomic) NSTimer *pollingRefreshTimer;
@property (nonatomic) BOOL isExpectingMoreDevices;
@property (nonatomic) BOOL isLoadedBeforeDragingEnd;

@end

int const OWSLinkedDevicesTableViewControllerSectionExistingDevices = 0;
int const OWSLinkedDevicesTableViewControllerSectionAddDevice = 1;

@implementation OWSLinkedDevicesTableViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    OWSLogInfo(@"%s", __FUNCTION__);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = Localized(@"LINKED_DEVICES_TITLE", @"Menu item and navbar title for the device manager");
    self.editButtonItem.title = Localized(@"EDIT_TXT", @"");
    self.isExpectingMoreDevices = NO;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;

    [self.tableView applyScrollViewInsetsFix];


    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refreshDevices) forControlEvents:UIControlEventValueChanged];
    [self.refreshControl beginRefreshing];
    
    if (self.linkFrom == DTLinkDeviceFromScan) {
        [self expectMoreDevices];
    }
    
    [self setupEditButton];
    
    [self applyTheme];
}

- (void)applyTheme {
    
    self.view.backgroundColor = Theme.backgroundColor;
    self.tableView.backgroundColor = Theme.backgroundColor;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshDevices];

    NSIndexPath *_Nullable selectedPath = [self.tableView indexPathForSelectedRow];
    if (selectedPath) {
        // HACK to unselect rows when swiping back
        // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
        [self.tableView deselectRowAtIndexPath:selectedPath animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.pollingRefreshTimer invalidate];
}

// Don't show edit button for an empty table
- (void)setupEditButton
{
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        if ([OWSDevice hasSecondaryDevicesWithTransaction:transaction]) {
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
        } else {
            self.navigationItem.rightBarButtonItem = nil;
        }
    }];
}

- (void)expectMoreDevices
{
    OWSLogInfo(@"expectMoreDevices");
    self.isExpectingMoreDevices = YES;

    // When you delete and re-add a device, you will be returned to this view in editing mode, making your newly
    // added device appear with a delete icon. Probably not what you want.
    self.editing = NO;

    __weak typeof(self) wself = self;
    [self.pollingRefreshTimer invalidate];
    self.pollingRefreshTimer = [NSTimer weakScheduledTimerWithTimeInterval:(10.0)target:wself
                                                                  selector:@selector(refreshDevices)
                                                                  userInfo:nil
                                                                   repeats:YES];

    NSString *progressText = Localized(@"WAITING_TO_COMPLETE_DEVICE_LINK_TEXT",
        @"Activity indicator title, shown upon returning to the device "
        @"manager, until you complete the provisioning process on desktop");
    NSAttributedString *progressTitle = [[NSAttributedString alloc] initWithString:progressText];

    // HACK to get refreshControl title to align properly.

    DispatchMainThreadSafe(^{
        self.refreshControl.attributedTitle = progressTitle;
        [self.refreshControl endRefreshing];
        
        self.refreshControl.attributedTitle = progressTitle;
        [self.refreshControl beginRefreshing];
        // Needed to show refresh control programatically
        [self.tableView setContentOffset:CGPointMake(0, -self.refreshControl.frame.size.height) animated:NO];
    });
    
    // END HACK to get refreshControl title to align properly.
 }

- (void)refreshDevices
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [OWSDevicesService getDevicesWithSuccess:^(NSArray<OWSDevice *> *devices) {
            // If we have more than one device; we may have a linked device.
            if (devices.count > 1) {
                // Setting this flag here shouldn't be necessary, but we do so
                // because the "cost" is low and it will improve robustness.
                [OWSDeviceManager.sharedManager setMayHaveLinkedDevices];
            }
            // 目前只支持 link 一台设备，devices 大于等于数据库里存在的设备数就停止拉数据库
            __block NSUInteger deviceCount = 0;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                deviceCount = [OWSDevice anyCountWithTransaction:transaction];
            }];
            if (devices.count > deviceCount) {
                // Got our new device, we can stop refreshing.
                wself.isExpectingMoreDevices = NO;
                [wself.pollingRefreshTimer invalidate];
                wself.refreshControl.attributedTitle = nil;
            }
            [OWSDevice replaceAll:devices];

            if (!self.isExpectingMoreDevices) {
                if (![wself.tableView isTracking]) {
                    wself.isLoadedBeforeDragingEnd = NO;
                    [wself.refreshControl endRefreshing];
                } else {
                    wself.isLoadedBeforeDragingEnd = YES;
                }
            }
            
            [self setupEditButton];
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                self.items = [OWSDevice anyFetchAllWithTransaction:transaction];
            }];
            if(self.items.count){
                NSMutableArray *results = self.items.mutableCopy;
                [self.items enumerateObjectsUsingBlock:^(OWSDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if(obj.deviceId == [OWSDevice currentDeviceId]){
                        [results removeObject:obj];
                    }
                }];
                self.items = results.copy;
            }
            [self.tableView reloadData];
        }
            failure:^(NSError *error) {
                DDLogError(@"Failed to fetch devices in linkedDevices controller with error: %@", error);

                NSString *alertTitle = Localized(
                    @"DEVICE_LIST_UPDATE_FAILED_TITLE", @"Alert title that can occur when viewing device manager.");

                UIAlertController *alertController =
                    [UIAlertController alertControllerWithTitle:alertTitle
                                                        message:error.localizedDescription
                                                 preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *retryAction = [UIAlertAction actionWithTitle:[CommonStrings retryButton]
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction *action) {
                                                                        [wself refreshDevices];
                                                                    }];
                [alertController addAction:retryAction];

                UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:CommonStrings.dismissButton
                                                                        style:UIAlertActionStyleCancel
                                                                      handler:nil];
                [alertController addAction:dismissAction];

                
                if (![wself.tableView isTracking]) {
                    wself.isLoadedBeforeDragingEnd = NO;
                    
                    [wself.refreshControl endRefreshing];
                    [wself presentViewController:alertController animated:YES completion:nil];
                } else {
                    wself.isLoadedBeforeDragingEnd = YES;
                }
            }];
    });
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    if(editing){
        self.editButtonItem.title = Localized(@"BUTTON_DONE", @"Menu item and navbar title for the device manager");
    } else {
        self.editButtonItem.title = Localized(@"EDIT_TXT", @"Menu item and navbar title for the device manager");
    }
}

#pragma mark - Table view data source



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.linkFrom == DTLinkDeviceFromScan) {
        
        return 1;
    } else {
        
        return 2;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case OWSLinkedDevicesTableViewControllerSectionExistingDevices:
            return (NSInteger)self.items.count;
        case OWSLinkedDevicesTableViewControllerSectionAddDevice:
            return 1;
        default:
            DDLogError(@"Unknown section: %ld", (long)section);
            return 0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];

    if (indexPath.section == OWSLinkedDevicesTableViewControllerSectionAddDevice) {
        [self ows_askForCameraPermissions:^(BOOL granted) {
            if (!granted) {
                return;
            }
            [self performSegueWithIdentifier:@"LinkDeviceSegue" sender:self];
        }];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == OWSLinkedDevicesTableViewControllerSectionAddDevice) {
        UITableViewCell *addNewDeviceCell =
            [tableView dequeueReusableCellWithIdentifier:@"AddNewDevice" forIndexPath:indexPath];
        addNewDeviceCell.backgroundColor = Theme.tableCellBackgroundColor;
        addNewDeviceCell.contentView.backgroundColor = Theme.tableCellBackgroundColor;
        addNewDeviceCell.textLabel.textColor = Theme.primaryTextColor;
        addNewDeviceCell.textLabel.text
            = Localized(@"LINK_NEW_DEVICE_TITLE", @"Navigation title when scanning QR code to add new device.");
        addNewDeviceCell.detailTextLabel.textColor = Theme.secondaryTextAndIconColor;
        addNewDeviceCell.detailTextLabel.text
            = Localized(@"LINK_NEW_DEVICE_SUBTITLE", @"Subheading for 'Link New Device' navigation");
        
        addNewDeviceCell.backgroundColor = Theme.backgroundColor;
        
        return addNewDeviceCell;
    } else if (indexPath.section == OWSLinkedDevicesTableViewControllerSectionExistingDevices) {
        OWSDeviceTableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"ExistingDevice" forIndexPath:indexPath];
        OWSDevice *device = [self deviceForRowAtIndexPath:indexPath];
        [cell configureWithDevice:device];
        cell.backgroundColor = Theme.tableCellBackgroundColor;
        return cell;
    } else {
        DDLogError(@"Unknown section: %@", indexPath);
        return nil;
    }
}

- (nullable OWSDevice *)deviceForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == OWSLinkedDevicesTableViewControllerSectionExistingDevices) {
        
        return self.items[(NSUInteger)(indexPath.row)];
    }

    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == OWSLinkedDevicesTableViewControllerSectionExistingDevices;
}

- (nullable NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return Localized(@"UNLINK_ACTION", @"button title for unlinking a device");
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OWSDevice *device = [self deviceForRowAtIndexPath:indexPath];
        [self touchedUnlinkControlForDevice:device
                                    success:^{
            OWSLogInfo(@"Removing unlinked device with deviceId: %ld", (long)device.deviceId);
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [device anyRemoveWithTransaction:transaction];
                [self refreshDevices];
            });
        }];
    }
}

- (void)touchedUnlinkControlForDevice:(OWSDevice *)device success:(void (^)(void))successCallback
{
    NSString *confirmationTitleFormat
        = Localized(@"UNLINK_CONFIRMATION_ALERT_TITLE", @"Alert title for confirming device deletion");
    NSString *confirmationTitle = [NSString stringWithFormat:confirmationTitleFormat, device.displayName];
    NSString *confirmationMessage
        = Localized(@"UNLINK_CONFIRMATION_ALERT_BODY", @"Alert message to confirm unlinking a device");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:confirmationTitle
                                                                             message:confirmationMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[OWSAlerts cancelAction]];

    UIAlertAction *unlinkAction =
        [UIAlertAction actionWithTitle:Localized(@"UNLINK_ACTION", @"button title for unlinking a device")
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                       [self unlinkDevice:device success:successCallback];
                                   });
                               }];
    [alertController addAction:unlinkAction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)unlinkDevice:(OWSDevice *)device success:(void (^)(void))successCallback
{
    [OWSDevicesService unlinkDevice:device
                                  success:successCallback
                                  failure:^(NSError *error) {
                                      NSString *title = Localized(
                                          @"UNLINKING_FAILED_ALERT_TITLE", @"Alert title when unlinking device fails");
                                      UIAlertController *alertController =
                                          [UIAlertController alertControllerWithTitle:title
                                                                              message:error.localizedDescription
                                                                       preferredStyle:UIAlertControllerStyleAlert];

                                      UIAlertAction *retryAction =
                                          [UIAlertAction actionWithTitle:[CommonStrings retryButton]
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction *aaction) {
                                                                     [self unlinkDevice:device success:successCallback];
                                                                 }];
                                      [alertController addAction:retryAction];
                                      [alertController addAction:[OWSAlerts cancelAction]];

                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          [self presentViewController:alertController animated:YES completion:nil];
                                      });
                                  }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(nullable id)sender
{
    if ([segue.destinationViewController isKindOfClass:[OWSLinkDeviceViewController class]]) {
        OWSLinkDeviceViewController *controller = (OWSLinkDeviceViewController *)segue.destinationViewController;
        controller.linkedDevicesTableViewController = self;
    }
}

#pragma mark scrollviewdelegate
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.isLoadedBeforeDragingEnd)
    {
        [self.refreshControl endRefreshing];
        self.isLoadedBeforeDragingEnd = NO;
    }
}

@end

NS_ASSUME_NONNULL_END
