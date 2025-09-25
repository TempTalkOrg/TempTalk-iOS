//
//  DTTokenKeychainStore.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTTokenKeychainStore : NSObject

+ (void)setPassword:(NSString *)password forAccount:(NSString *)key;

+ (nullable NSString *)loadPasswordWithAccountKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
