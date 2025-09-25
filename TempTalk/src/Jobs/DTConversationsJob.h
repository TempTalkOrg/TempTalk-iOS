//
//  DTConversationsJob.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTConversationsJob : NSObject

+ (instancetype)sharedJob;

- (void)startIfNecessary;

@end

NS_ASSUME_NONNULL_END
