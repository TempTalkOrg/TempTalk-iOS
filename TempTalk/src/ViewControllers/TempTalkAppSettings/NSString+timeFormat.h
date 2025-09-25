//
//  NSString+timeFormat.h
//  TTServiceKit
//
//  Created by Kris.s on 2024/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (timeFormat)

+ (NSString *)formatDurationSeconds:(uint32_t)durationSeconds useShortFormat:(BOOL)useShortFormat;

@end

NS_ASSUME_NONNULL_END
