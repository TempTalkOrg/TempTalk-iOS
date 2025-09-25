//
//  DTGroupUpdateInfoMessageHelper.h
//  TTServiceKit
//
//  Created by hornet on 2022/9/30.
//

#import <Foundation/Foundation.h>

@class TSInfoMessage;
@class TSGroupThread;

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupUpdateInfoMessageHelper : NSObject

+ (TSInfoMessage *)groupUpdatePublishRuleInfoMessage:(NSNumber *)publishRule timestamp:(uint64_t)timestamp serverTimestamp:(uint64_t)serverTimestamp
       inThread:(TSGroupThread *)thread;

+ (TSInfoMessage *)gOpenAutoClearSwitchInfoMessageWithThread:(TSGroupThread *)thread isOn:(BOOL)isOn;

+ (TSInfoMessage *)gPrivilegeConfidentialInfoMessageWithThread:(TSGroupThread *)thread
                                                  operatorName:(NSString *)operatorName;

@end

NS_ASSUME_NONNULL_END
