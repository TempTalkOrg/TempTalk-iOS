//
//  NSString+DTMarkdown.m
//  Signal
//
//  Created by Jaymin on 2024/01/23.
//  Copyright © 2024 Difft. All rights reserved.
//

#import "NSString+DTMarkdown.h"
#import "DTParamsBaseUtils.h"

@implementation NSString (DTMarkdown)

- (NSString *)removeMarkdownStyle {
    return self;
}

- (ReplaceStringBlock)replace {
    ReplaceStringBlock block = ^(NSString *pattern, NSString *replacement) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
        if (error) {
            return self;
        }
        NSMutableString *mutableString = [self mutableCopy];
        [regex replaceMatchesInString:mutableString options:0 range:NSMakeRange(0, mutableString.length) withTemplate:replacement];
        NSString *result = [mutableString copy];
        return result;
    };
    return block;
}

@end
