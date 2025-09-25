//
//  YDBDataMigratorUtils.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YDBDataMigratorUtils : NSObject

+ (nullable id)unarchivedObject:(NSData *)object;

@end

NS_ASSUME_NONNULL_END
