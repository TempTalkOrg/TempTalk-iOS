//
//  DTGroupNoticeSettingController.h
//  Wea
//
//  Created by hornet on 2021/12/29.
//

#import <TTMessaging/TTMessaging.h>
#import <TTServiceKit/TSGroupThread.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupNoticeSettingController : OWSTableViewController

- (void)configureWithThread:(TSThread *)thread ;

@end

NS_ASSUME_NONNULL_END
