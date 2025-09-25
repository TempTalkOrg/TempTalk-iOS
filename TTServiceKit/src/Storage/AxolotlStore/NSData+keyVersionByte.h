//
//  NSData+keyVersionByte.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/10/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (keyVersionByte)

- (instancetype)prependKeyType;

- (nullable instancetype)removeKeyTypeAndReturnError:(NSError **)outError;

- (instancetype)throws_removeKeyType;

@end

NS_ASSUME_NONNULL_END
