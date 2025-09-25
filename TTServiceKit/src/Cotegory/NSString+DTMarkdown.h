//
//  NSString+DTMarkdown.h
//  Signal
//
//  Created by Jaymin on 2024/01/23.
//  Copyright © 2024 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * _Nonnull (^ReplaceStringBlock)(NSString *pattern, NSString *replacement);

@interface NSString (DTMarkdown)

- (ReplaceStringBlock)replace;

- (NSString *)removeMarkdownStyle;

@end

NS_ASSUME_NONNULL_END
