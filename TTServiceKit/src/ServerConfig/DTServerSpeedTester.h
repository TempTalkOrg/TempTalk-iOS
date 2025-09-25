//
//  DTServerSpeedTester.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Foundation/Foundation.h>
#import "DTServerStatusEntity.h"
#import "TSConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTServerSpeedTester : NSOperation

- (instancetype)initWithServerStatusEntity:(DTServerStatusEntity *)serverStatusEntity serverType:(DTServToType)serverType;

@end

NS_ASSUME_NONNULL_END
