//
//  DTParamsBaseUtils.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import "DTParamsBaseUtils.h"

@implementation DTParamsBaseUtils

@end

static BOOL validateString(NSString *string)
{
    BOOL result = NO;
    if (string && [string isKindOfClass:[NSString class]] && [string length]) {
        result = YES;
    }
    return result;
}

static BOOL validateNumber(NSNumber *number)
{
    BOOL result = NO;
    if (number && [number isKindOfClass:[NSNumber class]]) {
        result = YES;
    }
    return result;
}


static BOOL validateArray(NSArray *array)
{
    
    BOOL result = NO;
    if (array && [array isKindOfClass:[NSArray class]] && [array count]) {
        result = YES;
    }
    return result;
}

static BOOL validateDictionary(NSDictionary *dictionary)
{
    BOOL result = NO;
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        result = YES;
    }
    return result;
}

DTParamsUtils_t DTParamsUtils = {
    validateString,
    validateNumber,
    validateArray,
    validateDictionary
};
