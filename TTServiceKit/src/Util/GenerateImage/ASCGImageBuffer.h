//
//  ASCGImageBuffer.h
//  TTServiceKit
//
//  Created by Jaymin on 2024/6/4.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCGImageBuffer : NSObject

@property (readonly) void *mutableBytes NS_RETURNS_INNER_POINTER;

/// Init a zero-filled buffer with the given length.
- (instancetype)initWithLength:(NSUInteger)length;

/// Don't do any drawing or call any methods after calling this.
- (CGDataProviderRef)createDataProviderAndInvalidate CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
