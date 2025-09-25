//
//  DTScreenShotOutgoingMessage.h
//  TTServiceKit
//
//  Created by User on 2023/2/13.
//

#import <TTServiceKit/TTServiceKit.h>
#import "DTRealSourceEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTScreenShotOutgoingMessage : TSOutgoingMessage

@property (nonatomic, strong) DTRealSourceEntity *realSource;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                       realSource:(DTRealSourceEntity *)realSource
                         inThread:(nullable TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
