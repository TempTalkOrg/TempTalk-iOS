//
//  DTRecallMessagesJob.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTRecallMessagesJob : NSObject

+ (instancetype)sharedJob;

- (void)startIfNecessary;

@end

NS_ASSUME_NONNULL_END
