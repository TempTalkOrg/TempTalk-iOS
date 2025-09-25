//
//  DTDisappearanceTimeIntervalConfig.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import <Foundation/Foundation.h>
#import "DTDisappearanceTimeIntervalEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTDisappearanceTimeIntervalConfig : NSObject

+ (void)fetchConfigWithCompletion:(void (^)(DTDisappearanceTimeIntervalEntity *entity, NSError *error))completion;

+ (DTDisappearanceTimeIntervalEntity *)fetchDisappearanceTimeInterval;

@end

NS_ASSUME_NONNULL_END
