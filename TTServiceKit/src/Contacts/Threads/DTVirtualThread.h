//
//  DTVirtualThread.h
//  TTServiceKit
//
//  Created by Felix on 2022/5/13.
//

//#import <TTServiceKit/TTServiceKit.h>
#import "TSThread.h"

NS_ASSUME_NONNULL_BEGIN

@class SDSAnyReadTransaction;

@interface DTVirtualThread : TSThread

+ (nullable instancetype)getVirtualThreadWithId:(NSString *)virtualId
                                    transaction:(SDSAnyReadTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
