//
//  DTModifyBindedInfoController.h
//  Signal
//
//  Created by hornet on 2023/6/12.
//  Copyright © 2023 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TTMessaging/TTMessaging.h>
#import "DTChativeMacro.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    DTModifyTypeChangeEmail = 0,//修改邮箱
    DTModifyTypeChangePhoneNumber = 1,//修改手机号
} DTModifyType;

///修改手机号/邮箱
@interface DTModifyBindedInfoController : OWSViewController
@property (nonatomic, strong) NSString *titleString;
@property (nonatomic, assign) DTModifyType modifyType;
@end

NS_ASSUME_NONNULL_END
