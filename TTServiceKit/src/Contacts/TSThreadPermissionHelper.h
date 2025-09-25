//
//  TSThreadPermissionHelper.h
//  TTServiceKit
//
//  Created by hornet on 2022/9/30.
//

#import <Foundation/Foundation.h>
@class TSThread;
NS_ASSUME_NONNULL_BEGIN

@interface TSThreadPermissionHelper : NSObject
+ (BOOL)checkCanSpeakAndToastTipMessage:(TSThread *)thread;
@end

NS_ASSUME_NONNULL_END
