//
//  DTChatLoginUtils.h
//  Signal
//
//  Created by hornet on 2022/10/13.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTChatLoginUtils : NSObject
+ (void)checkOrResetTimeStampWith:(NSString *)email key:(NSString *)key;
+ (NSString *)accountWithEmail:(NSString *)email key:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
