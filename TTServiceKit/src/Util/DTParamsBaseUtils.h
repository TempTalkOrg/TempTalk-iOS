//
//  DTParamsBaseUtils.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTParamsBaseUtils : NSObject

@end

NS_ASSUME_NONNULL_END

typedef struct {
    
    BOOL (*validateString)(NSString *string);
    BOOL (*validateNumber)(NSNumber *number);
    BOOL (*validateArray)(NSArray *array);
    BOOL (*validateDictionary)(NSDictionary *dictionary);
    
} DTParamsUtils_t;

extern DTParamsUtils_t DTParamsUtils;
