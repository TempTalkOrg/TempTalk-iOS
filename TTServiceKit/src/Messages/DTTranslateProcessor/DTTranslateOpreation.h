//
//  DTTranslateOpreation.h
//  TTServiceKit
//
//  Created by hornet on 2022/3/30.
//

#import <Foundation/Foundation.h>
#import "OWSOperation.h"
@class TSThread;
@class TSMessage;

NS_ASSUME_NONNULL_BEGIN

@interface DTTranslateOpreation : OWSOperation

- (instancetype)initWithThread:(TSThread *)thread message:(TSMessage *)message;

@end

NS_ASSUME_NONNULL_END
