//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AppUpdateNag.h"
#import "TempTalk-Swift.h"
#import <TTServiceKit/ATAppUpdater.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const OWSPrimaryStorageAppUpgradeNagCollection = @"TSStorageManagerAppUpgradeNagCollection";
NSString *const OWSPrimaryStorageAppUpgradeNagDate = @"TSStorageManagerAppUpgradeNagDate";

@interface AppUpdateNag () <ATAppUpdaterDelegate>

@property (nonatomic, strong) SDSKeyValueStore *store;

@end

#pragma mark -

@implementation AppUpdateNag

+ (instancetype)sharedInstance
{
    static AppUpdateNag *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }
    
    self.store = [[SDSKeyValueStore alloc] initWithCollection:OWSPrimaryStorageAppUpgradeNagCollection];

    OWSSingletonAssert();

    return self;
}

- (void)showAppUpgradeNagIfNecessary
{
    __block id lastNagDate = nil;
    
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        lastNagDate = [self.store getDate:OWSPrimaryStorageAppUpgradeNagDate transaction:transaction];
    }];
    
    BOOL canNag = NO;
    
    // changed: check everyday
    const NSTimeInterval kNagFrequency = kDayInterval * 1;
    // TODO: 几个版本之后移除此处兼容老版本存储的是 NSNumber 情况
    if (lastNagDate) {
        if ([lastNagDate isKindOfClass:NSNumber.class]) {
            NSTimeInterval lastPresentedDateTimeInterval = ((NSNumber *)lastNagDate).doubleValue;
            lastNagDate = [NSDate dateWithTimeIntervalSince1970:lastPresentedDateTimeInterval];
        } else if (![lastNagDate isKindOfClass:NSDate.class]) {
            canNag = NO;
        }
        
        canNag = (!lastNagDate || fabs(((NSDate *)lastNagDate).timeIntervalSinceNow) > kNagFrequency);
    } else {
        canNag = YES;
    }

    // comment: do update check, and show update window if update is needed.
    ATAppUpdater *updater = [ATAppUpdater sharedUpdater];
    [updater setAlertTitle:[NSString stringWithFormat:Localized(
                                                                        @"APP_UPDATE_NAG_ALERT_TITLE", @"Title for the 'new app version available' alert."), TSConstants.appDisplayName]];
    [updater setAlertMessage:Localized(@"APP_UPDATE_NAG_ALERT_MESSAGE_FORMAT",
                                 @"Message format for the 'new app version available' alert. Embeds: {{The latest app "
                                 @"version number.}}.")];
    [updater setAlertUpdateButtonTitle:Localized(@"APP_UPDATE_NAG_ALERT_UPDATE_BUTTON",
                                           @"Label for the 'update' button in the 'new app version available' alert.")];
    [updater setAlertCancelButtonTitle:[CommonStrings cancelButton]];
    
    // TODO: change: just comment it, do not understand why. delegate ?
    [updater setDelegate:self];

    [updater showUpdate:canNag];
}

#pragma mark - ATAppUpdaterDelegate

- (void)appUpdaterDidShowUpdateDialog
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.store setDate:[NSDate new] key:OWSPrimaryStorageAppUpgradeNagDate transaction:transaction];
    });
}

- (void)appUpdaterUserDidLaunchAppStore
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
}

- (void)appUpdaterUserDidCancel
{
    OWSLogInfo(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
}

@end
