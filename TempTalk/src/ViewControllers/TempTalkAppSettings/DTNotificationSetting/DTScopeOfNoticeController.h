//
//  DTScopeOfNoticeController.h
//  Wea
//
//  Created by hornet on 2021/12/27.
//

#import <TTMessaging/TTMessaging.h>

// 通话类型
typedef NS_ENUM(NSInteger, DTScopeOfViewType) {
    DTScopeOfViewType_GlobleSwitch,// 含开关
    DTScopeOfViewType_GlobleConfig,//不含开关，仅用作我的页面的全局配置
};

NS_ASSUME_NONNULL_BEGIN

@interface DTScopeOfNoticeController : OWSTableViewController
@end

NS_ASSUME_NONNULL_END
