//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSNavigationController;

@interface AppSettingsViewController : OWSTableViewController

+ (OWSNavigationController *)inModalNavigationController;

/// 初始化 push 全屏 vc
+ (OWSNavigationController *)inNormalNavigationController;
//- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
