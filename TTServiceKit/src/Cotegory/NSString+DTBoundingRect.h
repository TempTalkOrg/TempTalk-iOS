//
//  NSString+DTBoundingRect.h
//  TTServiceKit
//
//  Created by hornet on 2022/7/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (DTBoundingRect)
- (CGSize)sizeForFont:(UIFont *)font size:(CGSize)size mode:(NSLineBreakMode)lineBreakMode;
@end

NS_ASSUME_NONNULL_END
