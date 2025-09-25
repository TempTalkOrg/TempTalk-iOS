//
//  DTGroupMangerViewController.h
//  Wea
//
//  Created by hornet on 2021/12/31.
//

#import <TTMessaging/TTMessaging.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupMangerViewController : OWSTableViewController
- (void)configWithThread:(TSGroupThread *)thread;
@end

NS_ASSUME_NONNULL_END
