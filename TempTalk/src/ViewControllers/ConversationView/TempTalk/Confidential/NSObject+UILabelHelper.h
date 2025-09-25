//
//  NSObject+UILabelHelper.h
//  TTServiceKit
//
//  Created by hornet on 2023/2/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (UILabelHelper)
+ (NSArray *)getSeparatedLinesFromLabel:(UILabel *)label;
@end

NS_ASSUME_NONNULL_END
