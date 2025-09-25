//
//  DTSensitiveWordsConfig.h
//  TTServiceKit
//
//  Created by Ethan on 2022/5/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTSensitiveWordsConfig : NSObject

+ (NSArray <NSString *> *)fetchSensitiveWords;

+ (NSString * _Nullable)checkSensitiveWords:(NSString *)targetText;

@end

NS_ASSUME_NONNULL_END
